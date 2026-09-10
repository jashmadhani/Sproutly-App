//
//  MilestoneStage.swift
//  Sproutly
//

import Foundation

/// Which band counts as "now" for a child, in one place.
///
/// This was two implementations that disagreed. `DashboardViewModel` resolved
/// the most recent band the child had actually *reached*, and returned nil below
/// the first one. `MilestonesView` picked the band **nearest** the child's age,
/// which is a different question and gave a different answer:
///
/// - A ten-day-old has reached nothing, so the dashboard correctly showed "there
///   is nothing to save yet". The Milestones tab resolved forward to the two
///   month band and listed it under "This Stage", contradicting the promise
///   onboarding had just made that Sproutly starts at two months.
/// - A fourteen-month-old sat in the twelve month band on the dashboard and the
///   fifteen month band on Milestones, so the two tabs disagreed about what the
///   same child was working on.
///
/// The dashboard already carried the comment explaining why falling forward is
/// wrong. The rule now lives here so there is nothing to drift, the same way
/// `Child.correctedAgeMonths` is the single implementation of the age rule.
enum MilestoneStage {

    /// The band to treat as current, or nil when the child has not reached the
    /// first band the catalog covers.
    ///
    /// - Parameter excludedBands: from `CatalogBaseline`. A band this child was
    ///   never shown in time must not become the thing they are judged against.
    static func resolveTargetAge(
        milestones: [Milestone],
        brackets: [Int],
        correctedAge: Int,
        excludedBands: Set<Int> = []
    ) -> Int? {
        guard !milestones.isEmpty else { return nil }

        let reached = brackets.filter { $0 <= correctedAge && !excludedBands.contains($0) }
        guard !reached.isEmpty else { return nil }

        // The most recent band still worth working on. Walking backwards means a
        // band that is nearly finished hands over to the one before it rather
        // than leaving "This Stage" empty.
        for bracket in reached.reversed() {
            let items = milestones.filter { $0.ageMonth == bracket }
            guard !items.isEmpty else { continue }
            let done = items.filter(\.isCompleted).count
            if Double(done) / Double(items.count) <= 0.6 {
                return bracket
            }
        }

        // Everything reached is well covered — stay on the most recent band
        // rather than jumping forward to one they have not arrived at.
        return reached.last
    }

    /// The standard bands present in a child's own milestone set, in order.
    /// Parent-authored moments are stamped with the child's current age and
    /// would otherwise pull the stage away from the real bands.
    static func brackets(from milestones: [Milestone]) -> [Int] {
        Array(Set(milestones.filter { !$0.isUserCreated }.map(\.ageMonth))).sorted()
    }
}
