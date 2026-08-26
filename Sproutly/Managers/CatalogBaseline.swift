//
//  CatalogBaseline.swift
//  Sproutly
//

import Foundation

// MARK: - Catalog Baseline

/// The age bands a child was never given a fair chance at.
///
/// Sproutly ships new milestone bands over time. When one is added, every child
/// who is already older than that band has those rows inserted by
/// `DataSeeder.reseedIfIncomplete` — and they are, correctly, incomplete. Left
/// alone that is a quiet accusation: a parent who had filled in everything the
/// app ever showed them opens it after an update to find a domain downgraded and
/// a Development Focus card offering Early Intervention reading, purely because
/// we shipped content while they slept.
///
/// So those bands are recorded per child and excluded from everything that
/// judges progress — domain scoring, the flagged list that raises the focus
/// card, and the "not yet met" list handed to a pediatrician. They still appear
/// in the Milestones tab and can still be saved; they simply never count
/// against anyone.
///
/// A child seeded fresh records nothing. They meet the whole catalog during
/// onboarding and say for themselves what their child already does, which is
/// what the backfill step is for.
///
/// Bands rather than titles: a band is one integer, and every milestone inside
/// it shares the same answer to "was this child ever shown it in time".
enum CatalogBaseline {

    private static func key(for childID: UUID) -> String {
        "sproutly_catalog_baseline_\(childID.uuidString)"
    }

    /// Bands excluded from scoring for this child.
    static func excludedBands(for childID: UUID) -> Set<Int> {
        let stored = UserDefaults.standard.array(forKey: key(for: childID)) as? [Int] ?? []
        return Set(stored)
    }

    /// Additive — a later repair must not drop what an earlier one recorded.
    static func record(_ bands: Set<Int>, for childID: UUID) {
        guard !bands.isEmpty else { return }
        let merged = bands.union(excludedBands(for: childID))
        UserDefaults.standard.set(merged.sorted(), forKey: key(for: childID))
    }

    static func clear(for childID: UUID) {
        UserDefaults.standard.removeObject(forKey: key(for: childID))
    }

    /// Which of the bands about to be inserted must not count against this child.
    ///
    /// A band qualifies when the child has no rows in it at all — meaning it is
    /// new to them rather than a gap being repaired — and they are already older
    /// than it. A band they have not reached yet is left alone: they will meet it
    /// in time like any other child.
    ///
    /// Equal ages are deliberately not excluded. A child who turns fifteen months
    /// the day the band ships has genuinely arrived at it, and
    /// `DashboardViewModel` allows two further months before anything is flagged.
    static func bandsToExclude(
        inserting missing: [Milestone],
        existingBands: Set<Int>,
        correctedAge: Int
    ) -> Set<Int> {
        Set(
            missing
                .map(\.ageMonth)
                .filter { band in
                    !existingBands.contains(band) && correctedAge > band
                }
        )
    }
}
