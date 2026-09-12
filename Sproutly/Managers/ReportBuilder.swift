//
//  ReportBuilder.swift
//  Sproutly
//

import Foundation

// Plain data for the pediatrician report, built off the model layer so it can be
// tested without rendering anything.
struct MilestoneReport {

    struct DomainSection: Identifiable {
        let id = UUID()
        let category: MilestoneCategory
        let completed: [Milestone]
        let pending: [Milestone]

        var total: Int { completed.count + pending.count }
    }

    let childName: String
    let ageText: String
    let isCorrectedAge: Bool
    let gestationalWeeks: Int
    let isPremature: Bool
    let generatedOn: Date
    let sections: [DomainSection]
    let ownMoments: [Milestone]

    var totalCompleted: Int { sections.reduce(0) { $0 + $1.completed.count } }
    var totalExpected: Int { sections.reduce(0) { $0 + $1.total } }

    // Milestones a clinician would most want to see: well past the expected age
    // and still not met. Sproutly does not interpret these — it just surfaces them.
    let notYetMet: [Milestone]

    // MARK: Growth

    /// One measuring session as a report row. Values stay metric here and are
    /// converted by the document, the same way the app screens do it.
    struct GrowthRow: Identifiable, Equatable {
        let id: UUID
        let date: Date
        /// Corrected, matching the "ages shown are corrected" line in the header.
        let ageText: String
        let weightKg: Double?
        let lengthCm: Double?
        let headCm: Double?
    }

    /// The most recent sessions, oldest first so change reads down the page.
    let growth: [GrowthRow]
    /// The parent's units, fixed when the report is built.
    let growthUnits: GrowthUnitSystem
}

enum ReportBuilder {

    /// A report is for one visit, not a child's whole history. A dozen sessions
    /// covers well over a year of checkups and keeps growth to part of a page a
    /// clinician will actually read.
    static let growthRowLimit = 12

    static func build(
        for child: Child,
        on date: Date = Date(),
        units: GrowthUnitSystem = .current()
    ) -> MilestoneReport {
        let correctedAge = max(0, child.calculateCorrectedAge())
        let all = child.sortedMilestones
        let excludedBands = CatalogBaseline.excludedBands(for: child.id)

        // Only milestones the child is old enough for. Listing unreached future
        // ages would pad the report with noise a clinician has to filter out.
        let standard = all.filter { !$0.isUserCreated && $0.ageMonth <= correctedAge }

        let sections = MilestoneCategory.allCases.compactMap { category -> MilestoneReport.DomainSection? in
            let inDomain = standard.filter { $0.category == category.rawValue }
            guard !inDomain.isEmpty else { return nil }

            return MilestoneReport.DomainSection(
                category: category,
                completed: inDomain.filter(\.isCompleted),
                pending: inDomain.filter { !$0.isCompleted }
            )
        }

        return MilestoneReport(
            childName: child.displayName,
            ageText: child.ageText,
            isCorrectedAge: child.isCorrectedAge,
            gestationalWeeks: child.gestationalWeeks,
            isPremature: child.isPremature,
            generatedOn: date,
            sections: sections,
            ownMoments: all.filter { $0.isUserCreated && $0.isCompleted },
            // Bands this child was never shown in time are left out. This list
            // goes in front of a pediatrician, so putting content the parent was
            // never offered on it would be the most consequential version of the
            // same mistake the dashboard avoids. See CatalogBaseline.
            notYetMet: standard
                .filter {
                    $0.isSignificantlyLate(childAgeMonths: correctedAge)
                        && !excludedBands.contains($0.ageMonth)
                }
                .sorted { $0.ageMonth < $1.ageMonth },
            growth: child.sortedGrowthMeasurements
                .suffix(growthRowLimit)
                .map { measurement in
                    MilestoneReport.GrowthRow(
                        id: measurement.id,
                        date: measurement.date,
                        ageText: ageText(months: Child.correctedAgeMonths(
                            birthDate: child.birthDate,
                            isPremature: child.isPremature,
                            gestationalWeeks: child.gestationalWeeks,
                            now: measurement.date
                        )),
                        weightKg: measurement.weightKg,
                        lengthCm: measurement.lengthCm,
                        headCm: measurement.headCm
                    )
                },
            growthUnits: units
        )
    }

    /// "9 mo" under two, "2 y 3 mo" after. Compact because it sits in a table
    /// column beside a date, where "2 years and 3 months" would wrap.
    static func ageText(months: Int) -> String {
        guard months >= 24 else { return "\(months) mo" }
        let years = months / 12
        let remainder = months % 12
        return remainder == 0 ? "\(years) y" : "\(years) y \(remainder) mo"
    }
}
