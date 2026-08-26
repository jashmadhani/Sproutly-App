//
//  DailyNoticePicker.swift
//  Sproutly
//

import Foundation

// MARK: - Daily Notice Picker

/// Chooses the one thing to suggest noticing today.
///
/// Pure and deterministic so the card, the notification, and the tests all
/// agree: the same child on the same day always gets the same milestone, no
/// matter how many times the view re-renders or the app is relaunched.
enum DailyNoticePicker {

    /// A stable hash.
    ///
    /// `Hashable.hashValue` is explicitly **not** usable here — Swift seeds its
    /// hasher randomly per process, so the card would pick a different milestone
    /// every time the app was launched, which is precisely the reshuffling this
    /// is meant to prevent. FNV-1a is small, stable, and good enough to spread a
    /// selection across a list.
    static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    /// Days since a fixed reference, so "the same day" means the same integer
    /// regardless of time of day.
    static func dayNumber(for date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        return Int(start.timeIntervalSince1970 / 86_400)
    }

    /// The milestone to suggest today, or nil when the child has nothing left.
    ///
    /// Preference is the first incomplete milestone at or below corrected age.
    /// With none of those left it falls forward to the nearest band ahead —
    /// which is what a child younger than the catalog's first band always gets,
    /// and is why the fallback is load-bearing rather than an edge case.
    ///
    /// Parent-authored moments are never suggested: they have no expected age
    /// and no tip, and suggesting a parent notice their own entry is absurd.
    /// Bands the child was never shown in time are skipped too — nudging about
    /// content they never had the chance to see is the same mistake the
    /// dashboard already avoids.
    static func pick(
        from milestones: [Milestone],
        correctedAge: Int,
        excludedBands: Set<Int> = [],
        childID: UUID,
        day: Date,
        calendar: Calendar = .current
    ) -> Milestone? {
        let eligible = milestones.filter {
            !$0.isUserCreated
                && !$0.isCompleted
                && !excludedBands.contains($0.ageMonth)
        }
        guard !eligible.isEmpty else { return nil }

        let reached = eligible.filter { $0.ageMonth <= correctedAge }
        let pool: [Milestone]

        if !reached.isEmpty {
            pool = reached
        } else {
            // Nearest band ahead of them, and only that band — suggesting
            // something two years out would read as nonsense.
            guard let nextBand = eligible.map(\.ageMonth).filter({ $0 > correctedAge }).min() else {
                return nil
            }
            pool = eligible.filter { $0.ageMonth == nextBand }
        }

        // Sorted first so the index means the same thing on every run; the
        // relationship array itself has no order.
        let ordered = pool.sorted { lhs, rhs in
            lhs.ageMonth == rhs.ageMonth
                ? lhs.title < rhs.title
                : lhs.ageMonth < rhs.ageMonth
        }

        let seed = stableHash("\(childID.uuidString)|\(dayNumber(for: day, calendar: calendar))")
        return ordered[Int(seed % UInt64(ordered.count))]
    }
}

// MARK: - Daily Card Dismissal

/// "Not yet" hides today's card until tomorrow. Stored as a day number rather
/// than a date so the comparison can't drift with the clock, and per child so
/// dismissing one sibling's card doesn't hide the other's.
enum DailyCardDismissal {

    private static func key(for childID: UUID) -> String {
        "sproutly_daily_card_dismissed_\(childID.uuidString)"
    }

    static func isDismissed(for childID: UUID, on day: Date, calendar: Calendar = .current) -> Bool {
        let stored = UserDefaults.standard.object(forKey: key(for: childID)) as? Int
        return stored == DailyNoticePicker.dayNumber(for: day, calendar: calendar)
    }

    static func dismiss(for childID: UUID, on day: Date, calendar: Calendar = .current) {
        UserDefaults.standard.set(
            DailyNoticePicker.dayNumber(for: day, calendar: calendar),
            forKey: key(for: childID)
        )
    }

    static func clear(for childID: UUID) {
        UserDefaults.standard.removeObject(forKey: key(for: childID))
    }
}
