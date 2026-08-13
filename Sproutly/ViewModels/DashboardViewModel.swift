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
    private(set) var greetingText: String = "Good Morning"

    // skip only when all inputs that affect derived state are unchanged
    private var lastMilestoneSignature: Int?
    private var lastCorrectedAge: Int = -1

    // MARK: - Update

    // refreshes derived state, skips if inputs unchanged
    func update(milestones: [Milestone], childProfile: ChildProfile) {
        let age = max(0, childProfile.calculateCorrectedAge())
        var hasher = Hasher()
        for milestone in milestones {
            hasher.combine(milestone.id)
            hasher.combine(milestone.title)
            hasher.combine(milestone.category)
            hasher.combine(milestone.ageMonth)
            hasher.combine(milestone.isCompleted)
            hasher.combine(milestone.dateCompleted)
        }
        let milestoneSignature = hasher.finalize()

        guard milestoneSignature != lastMilestoneSignature || age != lastCorrectedAge else { return }

        lastMilestoneSignature = milestoneSignature
        lastCorrectedAge = age

        correctedAge = age
        greetingText = Self.resolveGreeting()

        let brackets = Array(Set(milestones.map(\.ageMonth))).sorted()
        targetAgeMonth = Self.resolveTargetAge(
            milestones: milestones,
            brackets: brackets,
            correctedAge: age
        )

        currentStageMilestones = milestones.filter { $0.ageMonth == targetAgeMonth }
        currentStageCompleted = currentStageMilestones.filter(\.isCompleted).count
        currentStageTotal = currentStageMilestones.count
        currentStageProgress = currentStageTotal > 0
            ? Double(currentStageCompleted) / Double(currentStageTotal)
            : 0

        completedMilestones = milestones
            .filter(\.isCompleted)
            .sorted { ($0.dateCompleted ?? .distantPast) > ($1.dateCompleted ?? .distantPast) }

        flaggedMilestones = milestones.filter { m in
            !m.isCompleted && age >= m.ageMonth + 2
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
        let cat = milestones.filter { $0.category == category.rawValue }
        return (cat.filter(\.isCompleted).count, cat.count)
    }

    // MARK: - Private Helpers

    private static func resolveGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default:      return "Good Night"
        }
    }

    // stay on most recent incomplete bracket the child has reached
    private static func resolveTargetAge(
        milestones: [Milestone],
        brackets: [Int],
        correctedAge: Int
    ) -> Int {
        guard !milestones.isEmpty else { return 6 }
        let reached = brackets.filter { $0 <= correctedAge }
        for bracket in reached.reversed() {
            let items = milestones.filter { $0.ageMonth == bracket }
            let done = items.filter(\.isCompleted).count
            guard items.count > 0 else { continue }
            if Double(done) / Double(items.count) <= 0.6 {
                return bracket
            }
        }
        return brackets.min(by: { abs($0 - correctedAge) < abs($1 - correctedAge) }) ?? 6
    }
}
