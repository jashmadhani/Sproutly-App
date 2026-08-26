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
}

enum ReportBuilder {

    static func build(for child: Child, on date: Date = Date()) -> MilestoneReport {
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
                .sorted { $0.ageMonth < $1.ageMonth }
        )
    }
}
