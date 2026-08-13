//
//  MilestonesView.swift
//  Sproutly
//
//  Created by Jash Madhani on 27/02/26.
//

import SwiftUI
import SwiftData

// MARK: - Filter Mode

enum MilestoneFilter: String, CaseIterable {
    case thisStage = "This Stage"
    case all = "All"
    case completed = "Completed"
}

// MARK: - Milestones View


struct MilestonesView: View {
    @Query(sort: \Milestone.ageMonth) private var milestones: [Milestone]
    @Environment(\.modelContext) private var modelContext
    @Environment(ChildProfile.self) private var childProfile
    @Environment(ThemeManager.self) private var theme

    @State private var selectedFilter: MilestoneFilter = .thisStage
    @State private var expandedDomains: Set<String> = Set(MilestoneCategory.allCases.map(\.rawValue))
    @State private var milestoneForNote: Milestone? = nil
    @State private var noteText: String = ""
    @State private var milestoneToUncheck: Milestone? = nil
    @State private var showRemoveAlert: Bool = false

    // MARK: - Derived Data

    private var correctedAge: Int { max(0, childProfile.calculateCorrectedAge()) }

    private var targetAgeMonth: Int {
        guard !milestones.isEmpty else { return 6 }
        let allAges = Set(milestones.map(\.ageMonth))
        return allAges.min(by: { abs($0 - correctedAge) < abs($1 - correctedAge) }) ?? 6
    }

    private var filteredMilestones: [Milestone] {
        switch selectedFilter {
        case .thisStage:
            return milestones.filter { $0.ageMonth == targetAgeMonth }
        case .all:
            return milestones
        case .completed:
            return milestones
                .filter(\.isCompleted)
                .sorted { ($0.dateCompleted ?? .distantPast) > ($1.dateCompleted ?? .distantPast) }
        }
    }

    private var groupedMilestones: [String: [Milestone]] {
        Dictionary(grouping: filteredMilestones, by: \.category)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            AmbientBackground(nightMode: theme.isNightMode)

            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    filterPicker
                    domainGroups
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(item: $milestoneForNote) { milestone in
            completionNoteSheet(for: milestone)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.isNightMode ? Theme.nightCard : Color.white)
        }
        .alert("Remove Milestone?", isPresented: $showRemoveAlert, presenting: milestoneToUncheck) { milestone in
            Button("Cancel", role: .cancel) { milestoneToUncheck = nil }
            Button("Remove", role: .destructive) {
                milestone.isCompleted = false
                milestone.dateCompleted = nil
                milestone.completionNote = ""
                saveContext()
                milestoneToUncheck = nil
            }
        } message: { _ in
            Text("This will delete your saved memory.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Milestones")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(theme.text)

            Text(ageDescription)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var ageDescription: String {
        let months = correctedAge
        if months < 24 {
            return "\(months) month\(months == 1 ? "" : "s") corrected age"
        } else {
            let years = months / 12
            let rem = months % 12
            if rem == 0 {
                return "\(years) year\(years == 1 ? "" : "s") corrected age"
            }
            return "\(years)y \(rem)m corrected age"
        }
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(MilestoneFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
        .accessibilityLabel("Milestone filter")
    }

    // MARK: - Domain Groups

    private var domainGroups: some View {
        let grouped = groupedMilestones
        let showAll = selectedFilter == .thisStage || selectedFilter == .all
        let isEmpty = filteredMilestones.isEmpty

        return VStack(spacing: 12) {
            ForEach(MilestoneCategory.allCases, id: \.self) { category in
                let domainMilestones = grouped[category.rawValue] ?? []
                let completedCount = domainMilestones.filter(\.isCompleted).count

                if !domainMilestones.isEmpty || showAll {
                    domainSection(
                        category: category,
                        milestones: domainMilestones,
                        stats: (completedCount, domainMilestones.count)
                    )
                }
            }

            if isEmpty {
                emptyState
            }
        }
    }

    private func domainSection(
        category: MilestoneCategory,
        milestones: [Milestone],
        stats: (completed: Int, total: Int)
    ) -> some View {
        let isExpanded = expandedDomains.contains(category.rawValue)

        return VStack(spacing: 0) {
            // Domain header
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    if isExpanded {
                        expandedDomains.remove(category.rawValue)
                    } else {
                        expandedDomains.insert(category.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(category.color(for: theme.isNightMode).opacity(0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: category.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(category.color(for: theme.isNightMode))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.gentleLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.text)

                        Text("\(stats.completed) of \(stats.total)")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeOut(duration: 0.2), value: isExpanded)
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(category.gentleLabel), \(stats.completed) of \(stats.total)")
            .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")

            // Expanded milestone rows
            if isExpanded {
                VStack(spacing: 8) {
                    if milestones.isEmpty {
                        Text("No milestones in this filter.")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                            .padding(.bottom, 12)
                    } else {
                        ForEach(milestones) { milestone in
                            milestoneRow(milestone)
                                .transaction { $0.animation = nil }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity)
            }
        }
        .warmCard(nightMode: theme.isNightMode)
    }

    // MARK: - Milestone Row

    private func milestoneRow(_ milestone: Milestone) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.subheadline)
                    .foregroundStyle(milestone.isCompleted ? theme.textSecondary : theme.text)
                    .strikethrough(milestone.isCompleted, color: theme.green.opacity(0.8))

                Text(milestone.expectedAgeText)
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)

                // Show completion note if present
                if milestone.isCompleted && !milestone.completionNote.isEmpty {
                    Text(milestone.completionNote)
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary.opacity(0.8))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .italic()
                }
            }

            Spacer()

            OneTapLogButton(
                isCompleted: milestone.isCompleted,
                nightMode: theme.isNightMode,
                accessibilityTitle: milestone.title
            ) {
                handleToggle(milestone)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    milestone.isCompleted
                        ? theme.green.opacity(theme.isNightMode ? 0.06 : 0.04)
                        : theme.text.opacity(0.02)
                )
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(theme.textSecondary)

            Text(selectedFilter == .completed
                 ? "No milestones completed yet.\nTap + to celebrate a moment!"
                 : "No milestones available.")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Completion Note Sheet

    private func completionNoteSheet(for milestone: Milestone) -> some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(theme.green)

                Text("Moment Captured!")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(theme.text)

                Text(milestone.title)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // Note field
            VStack(alignment: .leading, spacing: 8) {
                Label("Add a memory", systemImage: "pencil.line")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.blue)

                TextField("What made this moment special? (optional)", text: $noteText, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.subheadline)
                    .foregroundStyle(theme.text)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.text.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(theme.blue.opacity(0.1), lineWidth: 1)
                    )
            }

            // Buttons
            HStack(spacing: 14) {
                Button {
                    // Skip — complete without note
                    commitToggle(milestone, note: "")
                    milestoneForNote = nil
                    noteText = ""
                } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.text.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    // Save with note
                    commitToggle(milestone, note: noteText.trimmingCharacters(in: .whitespacesAndNewlines))
                    milestoneForNote = nil
                    noteText = ""
                } label: {
                    Text("Save Memory")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.green)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(theme.isNightMode ? Theme.nightCard : Color.white)
    }

    // MARK: - Actions

    // marking → show note sheet, unmarking → toggle immediately
    private func handleToggle(_ milestone: Milestone) {
        if milestone.isCompleted {
            if !milestone.completionNote.isEmpty {
                milestoneToUncheck = milestone
                showRemoveAlert = true
            } else {
                milestone.isCompleted = false
                milestone.dateCompleted = nil
                milestone.completionNote = ""
                saveContext()
            }
        } else {
            milestoneForNote = milestone
        }
    }


    private func commitToggle(_ milestone: Milestone, note: String) {
        milestone.isCompleted = true
        milestone.dateCompleted = Date()
        milestone.completionNote = note
        saveContext()
    }

    private func saveContext() {
        let ctx = modelContext
        Task.detached { @MainActor in
            try? ctx.save()
        }
    }
}

// MARK: - Preview

#Preview {
    let profile = ChildProfile()
    profile.birthDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    profile.name = "Preview"
    profile.hasCompletedOnboarding = true

    return MilestonesView()
        .environment(profile)
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
