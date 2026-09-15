//
//  GrowthMeasurement.swift
//  Sproutly
//

import Foundation
import SwiftData

// MARK: - Growth Measurement

// One measuring session: whatever a parent wrote down on a given day. Any of the
// three values may be missing, because a quick weigh-in at home produces a weight
// and nothing else.
//
// Values are stored in metric and only ever converted for display. A phone that
// changes region must never turn a stored 7.2 into a different number.
//
// Age is deliberately not stored. A parent can still correct a birth date or the
// weeks a child arrived early in Settings, and a saved age would silently keep the
// old answer. The chart asks `Child` instead, which owns the only correction.
//
// iCloud-ready from the start: every property has a default or is optional, and
// the link to `Child` is optional. Those are CloudKit's rules, and following them
// now means the two-parent sharing project does not have to reopen this model.
@Model
final class GrowthMeasurement: Identifiable {

    // MARK: - Properties

    var id: UUID = UUID()

    /// The day the measurement was taken, not the day it was typed in.
    var date: Date = Date()

    var weightKg: Double?

    /// Length and height are one value. Under two a child is measured lying down
    /// and it is called length; after two, standing, and it is called height. The
    /// label changes with age — see `GrowthMetric.length.title(ageMonths:)`.
    var lengthCm: Double?

    var headCm: Double?

    var note: String = ""

    var createdAt: Date = Date()

    var child: Child?

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        weightKg: Double? = nil,
        lengthCm: Double? = nil,
        headCm: Double? = nil,
        note: String = "",
        createdAt: Date = Date(),
        child: Child? = nil
    ) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.lengthCm = lengthCm
        self.headCm = headCm
        self.note = note
        self.createdAt = createdAt
        self.child = child
    }

    // MARK: - Reading values

    func value(for metric: GrowthMetric) -> Double? {
        switch metric {
        case .weight: return weightKg
        case .length: return lengthCm
        case .head:   return headCm
        }
    }
}
