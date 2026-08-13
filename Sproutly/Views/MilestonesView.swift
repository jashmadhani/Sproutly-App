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
    
    @Environment(\.modelContext) private var modelContext
    @Environment(ChildStore.self) private var childStore

    // MainTabView only renders once a child exists; the fallback keeps this view
    // total without threading an optional through every call site.
    private var child: Child { childStore.activeChild ?? Child() }
    private var milestones: [Milestone] { child.sortedMilestones }
    @Environment(ThemeManager.self) private var theme

    @State private var selectedFilter: MilestoneFilter = .thisStage
    @State private var expandedDomains: Set<String> = Set(MilestoneCategory.allCases.map(\.rawValue))
    @State private var milestoneForNote: Milestone? = nil
    @State private var noteText: String = ""
    @State private var milestoneToUncheck: Milestone? = nil
    @State private var showRemoveAlert: Bool = false
    @State private var showAddMilestone: Bool = false
    @State private var milestoneToDelete: Milestone? = nil
    @State private var showDeleteMilestoneAlert: Bool = false

    // MARK: - Derived Data

    private var correctedAge: Int { max(0, child.calculateCorrectedAge()) }

    // Derived from the standard set only. A parent-authored moment is stamped with
    // the child's current age, and letting those into this calculation would pull
    // the stage away from the real milestone bands (6, 9, 12, …).
    private var targetAgeMonth: Int {
        let standardAges = Set(milestones.filter { !$0.isUserCreated }.map(\.ageMonth))
        guard !standardAges.isEmpty else { return 6 }
        return standardAges.min(by: { abs($0 - correctedAge) < abs($1 - correctedAge) }) ?? 6
    }

    private var filteredMilestones: [Milestone] {
        switch selectedFilter {
        case .thisStage:
            // Their own moments always show — a parent who just added one should
            // never have to hunt for it behind a filter.
            return milestones.filter { $0.ageMonth == targetAgeMonth || $0.isUserCreated }
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
        .alert("Delete this moment?", isPresented: $showDeleteMilestoneAlert, presenting: milestoneToDelete) { milestone in
            Button("Cancel", role: .cancel) { milestoneToDelete = nil }
            Button("Delete", role: .destructive) {
                modelContext.delete(milestone)
                childStore.save()
                milestoneToDelete = nil
            }
        } message: { milestone in
            Text("\"\(milestone.title)\" will be removed permanently.")
        }
        .sheet(isPresented: $showAddMilestone) {
            if let active = childStore.activeChild {
                AddMilestoneSheet(child: active)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Milestones")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(theme.text)

                // Naming the child here is what stops a parent logging against the
                // wrong one after switching.
                Text("\(child.displayName) · \(ageDescription)")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            Button {
                showAddMilestone = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.blue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a moment")
            .accessibilityHint("Record your own milestone for \(child.displayName)")
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

                // A parent-authored moment has no expected age, so it gets a quiet
                // "Your moment" label instead of a clinical age band. Same row
                // styling otherwise — these are not a separate kind of thing.
                if milestone.isUserCreated {
                    Label("Your moment", systemImage: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(theme.blue.opacity(0.8))
                } else {
                    Text(milestone.expectedAgeText)
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }

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
        // Only parent-authored moments can be removed; the standard set is fixed.
        .contextMenu {
            if milestone.isUserCreated {
                Button(role: .destructive) {
                    milestoneToDelete = milestone
                    showDeleteMilestoneAlert = true
                } label: {
                    Label("Delete Moment", systemImage: "trash")
                }
            }
        }
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

    MilestonesView()
        .environment(previewChildStore)
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
