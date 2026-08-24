//
//  Child.swift
//  Sproutly
//

import Foundation
import SwiftData

// MARK: - Child

// Replaces the single UserDefaults-backed ChildProfile. Each child owns its own
// set of milestones, so siblings never share progress.
@Model
final class Child {

    // MARK: - Properties

    var id: UUID
    var name: String
    var birthDate: Date
    var isPremature: Bool
    var gestationalWeeks: Int

    // Stable ordering for the switcher — creation order, not alphabetical, so the
    // list doesn't reshuffle when a parent corrects a spelling.
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Milestone.child)
    var milestones: [Milestone]

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        name: String = "",
        birthDate: Date = Date(),
        isPremature: Bool = false,
        gestationalWeeks: Int = 40,
        createdAt: Date = Date(),
        milestones: [Milestone] = []
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.isPremature = isPremature
        self.gestationalWeeks = gestationalWeeks
        self.createdAt = createdAt
        self.milestones = milestones
    }

    // MARK: - Milestones

    // Relationship arrays are unordered; every caller wants them by age.
    var sortedMilestones: [Milestone] {
        milestones.sorted { lhs, rhs in
            lhs.ageMonth == rhs.ageMonth
                ? lhs.title < rhs.title
                : lhs.ageMonth < rhs.ageMonth
        }
    }

    // MARK: - Age Calculation

    var chronologicalAgeMonths: Int {
        let components = Calendar.current.dateComponents([.month], from: birthDate, to: Date())
        return max(0, components.month ?? 0)
    }

    var chronologicalAgeWeeks: Int {
        let days = Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0
        return max(0, days / 7)
    }

    // accounts for prematurity using 4.33 weeks/month
    func calculateCorrectedAge() -> Int {
        guard isPremature else { return chronologicalAgeMonths }
        let missingWeeks = 40 - gestationalWeeks
        let missingMonths = Int(round(Double(missingWeeks) / 4.33))
        return max(0, chronologicalAgeMonths - missingMonths)
    }

    var isCorrectedAge: Bool {
        isPremature && gestationalWeeks < 40
    }

    var humanReadableAge: String {
        let calendar = Calendar.current
        let months = chronologicalAgeMonths
        let monthAnchor = calendar.date(byAdding: .month, value: months, to: birthDate) ?? birthDate
        let remainingDays = calendar.dateComponents([.day], from: monthAnchor, to: Date()).day ?? 0
        let weeks = max(0, remainingDays / 7)

        if months == 0 && weeks == 0 {
            return "Just arrived"
        } else if months >= 12 {
            let years = months / 12
            let rem = months % 12
            if rem == 0 {
                return "\(years) year\(years == 1 ? "" : "s") old"
            }
            return "\(years) year\(years == 1 ? "" : "s"), \(rem) month\(rem == 1 ? "" : "s") old"
        } else if months == 0 {
            return "\(weeks) week\(weeks == 1 ? "" : "s") old"
        } else if weeks == 0 {
            return "\(months) month\(months == 1 ? "" : "s") old"
        } else {
            return "\(months) month\(months == 1 ? "" : "s"), \(weeks) week\(weeks == 1 ? "" : "s") old"
        }
    }

    var ageText: String {
        let months = calculateCorrectedAge()
        if months < 12 {
            return "\(months) month\(months == 1 ? "" : "s")"
        }
        let years = months / 12
        let remainingMonths = months % 12
        if remainingMonths == 0 {
            return "\(years) year\(years == 1 ? "" : "s")"
        }
        return "\(years) year\(years == 1 ? "" : "s"), \(remainingMonths) month\(remainingMonths == 1 ? "" : "s")"
    }

    // First name only, for headers where space is tight.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your little one" : trimmed
    }

    var initial: String {
        String(displayName.prefix(1)).uppercased()
    }
}
