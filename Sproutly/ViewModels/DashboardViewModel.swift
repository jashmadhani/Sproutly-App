//
//  DashboardViewModel.swift
//  Sproutly
//
//  Created by Jash Madhani on 28/02/26.
//

import SwiftUI


@Observable
final class DashboardViewModel {

    // MARK: - Published Derived State

    private(set) var correctedAge: Int = 0
    private(set) var targetAgeMonth: Int = 6
    private(set) var currentStageMilestones: [Milestone] = []
    private(set) var currentStageCompleted: Int = 0
    private(set) var currentStageTotal: Int = 0
    private(set) var currentStageProgress: Double = 0
    private(set) var completedMilestones: [Milestone] = []
    private(set) var flaggedMilestones: [Milestone] = []
    private(set) var hasDevelopmentFocus: Bool = false
    private(set) var concernLevel: ConcernLevel = .reviewSuggested
    private(set) var domainConcerns: [DomainConcern] = []

    // Age bands shipped after this child was already older than them. Held so
    // the domain tiles can leave them out of their denominators too.
    private(set) var excludedBands: Set<Int> = []

    // False until the child reaches the first band the catalog covers. Drives
    // the forward-looking dashboard state for the youngest babies.
    private(set) var hasReachedFirstBand: Bool = false
    private(set) var upcomingBandMonth: Int = 2
    private(set) var upcomingMilestones: [Milestone] = []

    /// No concern surfaces below this age, in any form.
    ///
    /// Matches the floor `DevelopmentObserver.classifyStatus` already applies to
    /// `.worthDiscussing`, and the age at which the AAP's own developmental
    /// screening begins. A younger baby has a wide, ordinary range of timing and
    /// nothing an app should be remarking on.
    static let concernFloorMonths = 9

    // skip only when all inputs that affect derived state are unchanged
    private var lastMilestoneSignature: Int?
    private var lastCorrectedAge: Int = -1

    // MARK: - Update

    // refreshes derived state, skips if inputs unchanged
    func update(milestones: [Milestone], child: Child) {
        let age = max(0, child.calculateCorrectedAge())

        // Bands this child was never shown in time. Nothing in them may count
        // against them — see CatalogBaseline.
        let excluded = CatalogBaseline.excludedBands(for: child.id)

        var hasher = Hasher()
        for milestone in milestones {
            hasher.combine(milestone.id)
            hasher.combine(milestone.title)
            hasher.combine(milestone.category)
            hasher.combine(milestone.ageMonth)
            hasher.combine(milestone.isCompleted)
            hasher.combine(milestone.dateCompleted)
        }
        // Part of the signature: a repair can change the excluded set without
        // touching a single milestone field, and the ring must not stay stale.
        hasher.combine(excluded.sorted())
        let milestoneSignature = hasher.finalize()

        guard milestoneSignature != lastMilestoneSignature || age != lastCorrectedAge else { return }

        lastMilestoneSignature = milestoneSignature
        lastCorrectedAge = age

        correctedAge = age
        excludedBands = excluded

        let brackets = Array(Set(milestones.filter { !$0.isUserCreated }.map(\.ageMonth))).sorted()
        let resolved = Self.resolveTargetAge(
            milestones: milestones,
            brackets: brackets,
            correctedAge: age,
            excludedBands: excluded
        )

        // Nil means the child has not reached the first band the catalog covers.
        // Sproutly starts at two months, so a three-week-old is not behind on
        // anything — there is simply nothing yet. The dashboard shows what is
        // coming instead of a ring at zero.
        hasReachedFirstBand = resolved != nil
        upcomingBandMonth = brackets.first ?? 2
        upcomingMilestones = hasReachedFirstBand
            ? []
            : milestones
                .filter { $0.ageMonth == upcomingBandMonth && !$0.isUserCreated }
                .sorted { $0.title < $1.title }

        targetAgeMonth = resolved ?? upcomingBandMonth
        currentStageMilestones = resolved.map { target in
            milestones.filter { $0.ageMonth == target }
        } ?? []
        currentStageCompleted = currentStageMilestones.filter(\.isCompleted).count
        currentStageTotal = currentStageMilestones.count
        currentStageProgress = currentStageTotal > 0
            ? Double(currentStageCompleted) / Double(currentStageTotal)
            : 0

        completedMilestones = Milestone.recencyOrdered(milestones.filter(\.isCompleted))

        // The list that raises the Development Focus card. An excluded band must
        // never reach it: shipping new content is not evidence about a child.
        //
        // Below the floor nothing is flagged at all. The `+ 2` window alone was
        // written when the catalog started at six months; once a two-month band
        // existed, a *four-month-old* satisfied `4 >= 2 + 2` and their parent —
        // days into the app, having saved three things — was shown a Development
        // Focus card offering Early Intervention. `DevelopmentObserver` already
        // refuses `.worthDiscussing` below nine months for exactly this reason,
        // and AAP screening starts there too; the two now agree.
        flaggedMilestones = age < Self.concernFloorMonths
            ? []
            : milestones.filter { m in
                !m.isCompleted
                    && age >= m.ageMonth + 2
                    && !excluded.contains(m.ageMonth)
            }

        hasDevelopmentFocus = flaggedMilestones.count >= 2

        let domainCount = Set(flaggedMilestones.map(\.category)).count
        concernLevel = (flaggedMilestones.count >= 3 || domainCount >= 2)
            ? .needsAttention
            : .reviewSuggested

        let grouped = Dictionary(grouping: flaggedMilestones, by: \.category)
        domainConcerns = grouped.compactMap { categoryRaw, items in
            guard let category = MilestoneCategory(rawValue: categoryRaw) else { return nil }
            return DomainConcern(
                id: categoryRaw,
                category: category,
                milestoneCount: items.count
            )
        }
        .sorted { $0.milestoneCount > $1.milestoneCount }
    }


    func categoryStats(_ category: MilestoneCategory, milestones: [Milestone]) -> (completed: Int, total: Int) {
        // Excluded bands are left out of the denominator as well as the
        // numerator. Counting them would make a diligent parent's tile read
        // worse the morning after an update.
        let cat = milestones.filter {
            $0.category == category.rawValue && !excludedBands.contains($0.ageMonth)
        }
        return (cat.filter(\.isCompleted).count, cat.count)
    }

    // MARK: - Private Helpers

    // The most recent band the child has actually reached and not yet filled in.
    //
    // Returns nil when they have reached none of them — a baby younger than the
    // first band the catalog covers. The previous version fell back to the
    // *nearest* bracket, which for a three-week-old resolved forward to a band
    // they had not arrived at and rendered "0 of 10" against it.
    private static func resolveTargetAge(
        milestones: [Milestone],
        brackets: [Int],
        correctedAge: Int,
        excludedBands: Set<Int>
    ) -> Int? {
        guard !milestones.isEmpty else { return nil }

        let reached = brackets.filter { $0 <= correctedAge && !excludedBands.contains($0) }
        guard !reached.isEmpty else { return nil }

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
}
