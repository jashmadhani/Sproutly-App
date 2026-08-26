//
//  NotificationPlanner.swift
//  Sproutly
//

import Foundation

// MARK: - Kind

enum SproutlyNotificationKind: String, CaseIterable, Sendable {
    case dailyNotice
    case anniversary
    case weeklyReflection

    /// Higher wins when two land on the same calendar day. An anniversary is a
    /// gift and cannot be regenerated tomorrow; a daily notice can.
    var priority: Int {
        switch self {
        case .anniversary: return 3
        case .weeklyReflection: return 2
        case .dailyNotice: return 1
        }
    }

    var settingsKey: String { "sproutly_notify_\(rawValue)" }

    var settingsTitle: String {
        switch self {
        case .dailyNotice: return "Something to notice"
        case .anniversary: return "This time last year"
        case .weeklyReflection: return "Sunday look-back"
        }
    }

    var settingsIcon: String {
        switch self {
        case .dailyNotice: return "sparkles"
        case .anniversary: return "clock.arrow.circlepath"
        case .weeklyReflection: return "calendar"
        }
    }

    var settingsDescription: String {
        switch self {
        case .dailyNotice: return "One idea in the morning"
        case .anniversary: return "When a moment has its anniversary"
        case .weeklyReflection: return "Only when there's something to look back on"
        }
    }
}

// MARK: - Settings

/// Plain value so the planner stays pure and a test can hand it any shape.
struct NotificationSettings: Equatable, Sendable {

    var masterEnabled: Bool
    var enabledKinds: Set<SproutlyNotificationKind>

    static let allOff = NotificationSettings(masterEnabled: false, enabledKinds: [])

    func isOn(_ kind: SproutlyNotificationKind) -> Bool {
        masterEnabled && enabledKinds.contains(kind)
    }

    // MARK: Persistence

    private static let masterKey = "sproutly_notify_master"

    static func load() -> NotificationSettings {
        let defaults = UserDefaults.standard
        let kinds = SproutlyNotificationKind.allCases.filter {
            defaults.bool(forKey: $0.settingsKey)
        }
        return NotificationSettings(
            masterEnabled: defaults.bool(forKey: masterKey),
            enabledKinds: Set(kinds)
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(masterEnabled, forKey: Self.masterKey)
        for kind in SproutlyNotificationKind.allCases {
            defaults.set(enabledKinds.contains(kind), forKey: kind.settingsKey)
        }
    }
}

// MARK: - Quiet Level

/// Silence is a valid outcome. A parent who has stopped opening Sproutly is
/// telling us something, and the answer is fewer notifications rather than more.
enum QuietLevel: Equatable, Sendable {
    case normal
    case weeklyOnly
    case silent

    static func forDaysAway(_ days: Int) -> QuietLevel {
        if days >= 30 { return .silent }
        if days >= 14 { return .weeklyOnly }
        return .normal
    }
}

// MARK: - Planned Notification

struct PlannedNotification: Equatable, Sendable {
    let kind: SproutlyNotificationKind
    let childID: UUID
    let fireDate: Date
    let title: String
    let body: String
    /// Anniversary only. The file is copied before it is ever handed to
    /// `UNNotificationAttachment` — see `NotificationManager`.
    let photoFilename: String?

    var identifier: String {
        "\(kind.rawValue)|\(childID.uuidString)|\(Int(fireDate.timeIntervalSince1970))"
    }
}

// MARK: - Planner

/// Decides what to schedule. Deliberately pure — no `UNUserNotificationCenter`,
/// no authorization, no clock of its own — so every rule in the brief is
/// testable directly.
enum NotificationPlanner {

    /// Nothing may fire outside these hours. A parenting app that pings at
    /// 03:00 is uninstalled at 03:01.
    static let earliestHour = 9
    static let latestHour = 19

    /// How far ahead to schedule. Short on purpose: iOS keeps at most 64 pending
    /// local notifications, and a rolling window refreshed on foreground is both
    /// well inside that and easier to keep truthful than a long queue that
    /// slowly goes stale.
    static let windowDays = 7

    private static let dailyHour = 9
    private static let dailyMinute = 30
    private static let weeklyHour = 10
    private static let anniversaryHour = 10
    private static let anniversaryMinute = 30

    // MARK: Entry Point

    static func plan(
        childID: UUID,
        childName: String,
        correctedAge: Int,
        milestones: [Milestone],
        excludedBands: Set<Int>,
        settings: NotificationSettings,
        daysSinceLastOpened: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> [PlannedNotification] {

        guard settings.masterEnabled else { return [] }

        let quiet = QuietLevel.forDaysAway(daysSinceLastOpened)
        guard quiet != .silent else { return [] }

        let days = (0..<windowDays).compactMap {
            calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: now))
        }

        var candidates: [PlannedNotification] = []

        for day in days {
            if let anniversary = anniversaryNotice(
                childID: childID, childName: childName, milestones: milestones,
                settings: settings, quiet: quiet, day: day, calendar: calendar
            ) {
                candidates.append(anniversary)
            }

            if let weekly = weeklyNotice(
                childID: childID, childName: childName, milestones: milestones,
                settings: settings, day: day, calendar: calendar
            ) {
                candidates.append(weekly)
            }

            if let daily = dailyNotice(
                childID: childID, childName: childName, correctedAge: correctedAge,
                milestones: milestones, excludedBands: excludedBands,
                settings: settings, quiet: quiet, day: day, calendar: calendar
            ) {
                candidates.append(daily)
            }
        }

        return resolve(candidates, correctedAge: correctedAge, now: now, calendar: calendar)
    }

    // MARK: Collision and Cadence

    /// One per calendar day, highest priority wins, nothing in the past, and for
    /// the youngest babies no more than two in the whole week.
    private static func resolve(
        _ candidates: [PlannedNotification],
        correctedAge: Int,
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {

        var byDay: [Int: PlannedNotification] = [:]
        for candidate in candidates where candidate.fireDate > now {
            let day = DailyNoticePicker.dayNumber(for: candidate.fireDate, calendar: calendar)
            if let existing = byDay[day] {
                if candidate.kind.priority > existing.kind.priority {
                    byDay[day] = candidate
                }
            } else {
                byDay[day] = candidate
            }
        }

        var chosen = byDay.values.sorted { $0.fireDate < $1.fireDate }

        // The most fragile parent in the app. Two a week, never daily.
        if isYoungInfant(correctedAge: correctedAge) {
            chosen = Array(chosen.prefix(youngInfantWeeklyCap))
        }

        return chosen
    }

    static let youngInfantWeeklyCap = 2

    static func isYoungInfant(correctedAge: Int) -> Bool {
        correctedAge < firstBand
    }

    /// The youngest band the catalog covers.
    static var firstBand: Int {
        DataSeeder.allMilestones.map(\.ageMonth).min() ?? 2
    }

    // MARK: Daily Notice

    private static func dailyNotice(
        childID: UUID,
        childName: String,
        correctedAge: Int,
        milestones: [Milestone],
        excludedBands: Set<Int>,
        settings: NotificationSettings,
        quiet: QuietLevel,
        day: Date,
        calendar: Calendar
    ) -> PlannedNotification? {

        guard settings.isOn(.dailyNotice), quiet == .normal else { return nil }
        guard DailyNoticePicker.pick(
            from: milestones,
            correctedAge: correctedAge,
            excludedBands: excludedBands,
            childID: childID,
            day: day,
            calendar: calendar
        ) != nil else { return nil }

        guard let fire = time(dailyHour, dailyMinute, on: day, calendar: calendar) else { return nil }

        // The milestone's name is deliberately absent. This lands on a lock
        // screen a stranger can read over a shoulder, and "Does Aanya point at
        // things yet?" is a demand rather than an invitation. The name of the
        // thing lives inside the app, where there is room for the tip too.
        return PlannedNotification(
            kind: .dailyNotice,
            childID: childID,
            fireDate: fire,
            title: "Something to notice about \(childName) today",
            body: isYoungInfant(correctedAge: correctedAge)
                ? "A look at what's coming up, whenever you have a minute."
                : "One small thing, whenever you have a minute.",
            photoFilename: nil
        )
    }

    // MARK: Anniversary

    private static func anniversaryNotice(
        childID: UUID,
        childName: String,
        milestones: [Milestone],
        settings: NotificationSettings,
        quiet: QuietLevel,
        day: Date,
        calendar: Calendar
    ) -> PlannedNotification? {

        guard settings.isOn(.anniversary), quiet == .normal else { return nil }

        // Backfilled milestones carry no date — the parent told us it happened,
        // not when — so they can never have an anniversary. That is correct and
        // deliberate: inventing one would celebrate a day that never happened.
        let match = milestones
            .filter { !$0.isUserCreated }
            .compactMap { milestone -> (Milestone, Int)? in
                guard let completed = milestone.dateCompleted else { return nil }
                guard let years = yearsAgoToday(completed, day: day, calendar: calendar),
                      years == 1 || years == 2 else { return nil }
                return (milestone, years)
            }
            .sorted { $0.0.title < $1.0.title }
            .first

        guard let (milestone, years) = match,
              let fire = time(anniversaryHour, anniversaryMinute, on: day, calendar: calendar)
        else { return nil }

        // A sentence, not "Name — Thing." Catalog titles start capitalised
        // because they head a row; lowercased here they read as the rest of a
        // sentence about the child rather than a label with a value attached.
        let action = milestone.title.prefix(1).lowercased() + milestone.title.dropFirst()

        return PlannedNotification(
            kind: .anniversary,
            childID: childID,
            fireDate: fire,
            title: years == 1 ? "One year ago today" : "Two years ago today",
            body: "\(childName) \(action).",
            photoFilename: milestone.photoFilename
        )
    }

    /// Whole years between two dates when the month and day match exactly.
    private static func yearsAgoToday(_ date: Date, day: Date, calendar: Calendar) -> Int? {
        let then = calendar.dateComponents([.year, .month, .day], from: date)
        let now = calendar.dateComponents([.year, .month, .day], from: day)
        guard then.month == now.month, then.day == now.day,
              let thenYear = then.year, let nowYear = now.year else { return nil }
        let difference = nowYear - thenYear
        return difference > 0 ? difference : nil
    }

    // MARK: Weekly Reflection

    private static func weeklyNotice(
        childID: UUID,
        childName: String,
        milestones: [Milestone],
        settings: NotificationSettings,
        day: Date,
        calendar: Calendar
    ) -> PlannedNotification? {

        guard settings.isOn(.weeklyReflection) else { return nil }
        guard calendar.component(.weekday, from: day) == 1 else { return nil }  // Sunday

        // Skipped in silence when the week was empty. Never "you didn't log
        // anything" — an empty week is usually a hard week, and the app has no
        // business remarking on it.
        guard let weekStart = calendar.date(byAdding: .day, value: -7, to: day) else { return nil }
        let loggedThisWeek = milestones.contains { milestone in
            guard let completed = milestone.dateCompleted else { return false }
            return completed >= weekStart && completed < day
        }
        guard loggedThisWeek else { return nil }

        guard let fire = time(weeklyHour, 0, on: day, calendar: calendar) else { return nil }

        return PlannedNotification(
            kind: .weeklyReflection,
            childID: childID,
            fireDate: fire,
            title: "Look back on \(childName)'s week",
            body: "Here's what you noticed.",
            photoFilename: nil
        )
    }

    // MARK: Time

    /// Builds a fire time and refuses anything outside the allowed window, so a
    /// mis-set constant fails to schedule rather than firing at midnight.
    static func time(_ hour: Int, _ minute: Int, on day: Date, calendar: Calendar) -> Date? {
        guard hour >= earliestHour, hour < latestHour else { return nil }
        return calendar.date(
            bySettingHour: hour, minute: minute, second: 0,
            of: calendar.startOfDay(for: day)
        )
    }
}
