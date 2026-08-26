//
//  NotificationManager.swift
//  Sproutly
//

import Foundation
import Observation
import UserNotifications

// MARK: - Cancellation

/// Cancelling pending requests without needing the manager injected.
///
/// `ChildStore` deletes children and must clear their notifications, but it is
/// a plain model-layer type with no view environment to reach into. Kept
/// deliberately tiny — anything that *schedules* still goes through
/// `NotificationManager` so there is one planner and one place to reason about.
enum NotificationCancellation {
    static func cancelAllPending() {
        // Guarded: `UNUserNotificationCenter.current()` traps in a process with
        // no bundle identifier, which is how some test hosts run.
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - Notification Manager

/// Local notifications only.
///
/// No push, no remote, no entitlement, no server, and nothing here needs an
/// Info.plist usage string or a `PrivacyInfo.xcprivacy` entry — scheduling a
/// local notification accesses no API that requires a declared reason and moves
/// no data off the device. App Privacy stays Data Not Collected.
///
/// Everything that decides *what* to send lives in `NotificationPlanner`, which
/// is pure. This type only asks for permission, hands the plan to the system,
/// and keeps the small amount of state involved in `UserDefaults`.
@MainActor
@Observable
final class NotificationManager {

    // MARK: State

    private(set) var settings: NotificationSettings = .load()
    private(set) var authorizationDenied: Bool = UserDefaults.standard.bool(
        forKey: Keys.authorizationDenied
    )
    private(set) var hasAskedForPermission: Bool = UserDefaults.standard.bool(
        forKey: Keys.hasAsked
    )

    private let center: UNUserNotificationCenter?

    enum Keys {
        static let authorizationDenied = "sproutly_notify_authorization_denied"
        static let hasAsked = "sproutly_notify_has_asked"
        static let lastOpened = "sproutly_last_opened"
        static let promptDismissed = "sproutly_notify_prompt_dismissed"
        /// The parent has genuinely logged this many before we ask at all.
        static let promptAfterLogs = 3
    }

    // MARK: Init

    /// - Parameter center: nil in tests, so nothing touches the notification
    ///   system and no authorization is ever required to exercise the logic.
    init(center: UNUserNotificationCenter? = .current()) {
        self.center = center
    }

    // MARK: Opening

    /// Records that the parent opened the app today. Drives auto-quiet.
    func recordAppOpened(now: Date = Date()) {
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: Keys.lastOpened)
    }

    func daysSinceLastOpened(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let stored = UserDefaults.standard.double(forKey: Keys.lastOpened)
        guard stored > 0 else { return 0 }
        let last = Date(timeIntervalSince1970: stored)
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
    }

    // MARK: Permission

    /// Whether to offer the one soft dashboard prompt.
    ///
    /// Never at launch, never during onboarding, and only once the parent has
    /// saved three milestones with a date on them — by which point they have
    /// seen what the app is for and the offer means something. Declining, or
    /// dismissing the prompt, settles it permanently.
    var shouldOfferPermissionPrompt: Bool {
        guard !settings.masterEnabled else { return false }
        guard !hasAskedForPermission, !authorizationDenied else { return false }
        guard !UserDefaults.standard.bool(forKey: Keys.promptDismissed) else { return false }
        return MilestoneLogCounter.count >= Keys.promptAfterLogs
    }

    func dismissPermissionPrompt() {
        UserDefaults.standard.set(true, forKey: Keys.promptDismissed)
    }

    /// Only ever called from an explicit tap — the Settings toggle or the
    /// dashboard prompt's accept button.
    @discardableResult
    func requestAuthorization() async -> Bool {
        hasAskedForPermission = true
        UserDefaults.standard.set(true, forKey: Keys.hasAsked)

        guard let center else { return false }

        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if !granted {
            // Asked and declined. We do not ask again — the system settings are
            // theirs to change if they ever want to.
            authorizationDenied = true
            UserDefaults.standard.set(true, forKey: Keys.authorizationDenied)
        }
        return granted
    }

    // MARK: Settings

    func setMasterEnabled(_ enabled: Bool) {
        settings.masterEnabled = enabled
        if enabled && settings.enabledKinds.isEmpty {
            // Turning it on with nothing selected would be a switch that does
            // nothing. Daily and weekly on, anniversaries on — all quiet by design.
            settings.enabledKinds = Set(SproutlyNotificationKind.allCases)
        }
        settings.save()
    }

    func setKind(_ kind: SproutlyNotificationKind, enabled: Bool) {
        if enabled {
            settings.enabledKinds.insert(kind)
        } else {
            settings.enabledKinds.remove(kind)
        }
        settings.save()
    }

    // MARK: Scheduling

    /// Replaces everything pending with a freshly planned window.
    ///
    /// Called on child switch, add, delete, foreground, a logged milestone, and
    /// any settings change. Always a full replace: adding to what is already
    /// queued is how an app ends up sending two in a day.
    func reschedule(for child: Child?, now: Date = Date(), calendar: Calendar = .current) async {
        await cancelAll()

        guard let child, settings.masterEnabled else { return }

        let plan = NotificationPlanner.plan(
            childID: child.id,
            childName: child.displayName,
            correctedAge: max(0, child.calculateCorrectedAge()),
            milestones: child.sortedMilestones,
            excludedBands: CatalogBaseline.excludedBands(for: child.id),
            settings: settings,
            daysSinceLastOpened: daysSinceLastOpened(now: now, calendar: calendar),
            now: now,
            calendar: calendar
        )

        for planned in plan {
            await submit(planned, calendar: calendar)
        }
    }

    /// Cancels everything pending. Also the child-deleted path: a deleted
    /// child's name must never surface on a lock screen afterwards.
    func cancelAll() async {
        center?.removeAllPendingNotificationRequests()
    }

    private func submit(_ planned: PlannedNotification, calendar: Calendar) async {
        guard let center else { return }

        let content = UNMutableNotificationContent()
        content.title = planned.title
        content.body = planned.body
        content.sound = .default

        if let attachment = attachment(for: planned) {
            content.attachments = [attachment]
        }

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: planned.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        try? await center.add(
            UNNotificationRequest(
                identifier: planned.identifier,
                content: content,
                trigger: trigger
            )
        )
    }

    /// Attaches an anniversary photo.
    ///
    /// The file handed over is **always a temporary copy**. `UNNotificationAttachment`
    /// takes ownership of the URL it is given and moves it into the notification
    /// store — pointing it at the original in `MilestonePhotos` would relocate
    /// the parent's only copy of that photo out from under the milestone that
    /// references it.
    private func attachment(for planned: PlannedNotification) -> UNNotificationAttachment? {
        guard let filename = planned.photoFilename,
              let source = PhotoStore.url(for: filename),
              FileManager.default.fileExists(atPath: source.path)
        else { return nil }

        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("notify-\(UUID().uuidString)-\(filename)")

        do {
            try FileManager.default.copyItem(at: source, to: copy)
            return try UNNotificationAttachment(identifier: filename, url: copy, options: nil)
        } catch {
            sproutlyLog("could not attach anniversary photo — \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: copy)
            return nil
        }
    }
}
