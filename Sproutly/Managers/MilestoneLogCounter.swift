//
//  MilestoneLogCounter.swift
//  Sproutly
//

import Foundation

// MARK: - Milestone Log Counter

/// How many milestones this parent has genuinely logged.
///
/// Two separate one-time nudges key off this — the notification permission
/// prompt at three, the photo suggestion at five — and they must not disagree
/// about the count, so both read it here and every write path calls
/// `record(_:)` rather than incrementing its own tally.
///
/// "Genuinely logged" means the parent noticed something and saved it, with a
/// date. A milestone backfilled during onboarding carries no `dateCompleted`,
/// and `record(_:)` ignores it — which is structural rather than a rule someone
/// has to remember: there is no way to pass a backfilled milestone through here
/// and have it count.
enum MilestoneLogCounter {

    private static let countKey = "sproutly_logged_milestone_count"

    static var count: Int {
        UserDefaults.standard.integer(forKey: countKey)
    }

    /// Call from every path that marks a milestone complete with a date.
    static func record(_ milestone: Milestone) {
        guard milestone.isCompleted, milestone.dateCompleted != nil else { return }
        UserDefaults.standard.set(count + 1, forKey: countKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: countKey)
    }
}
