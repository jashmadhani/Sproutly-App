//
//  DashboardView.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/02/26.
//

import SwiftUI
import SwiftData

// MARK: - Scroll Offset Tracking

struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Dashboard View


struct DashboardView: View {
    @Query(sort: \Milestone.ageMonth) private var milestones: [Milestone]
    @Environment(\.modelContext) private var modelContext
    @Environment(ChildProfile.self) private var childProfile
    @Environment(ThemeManager.self) private var theme

    @State private var viewModel = DashboardViewModel()
    @State private var scrollOffset: CGFloat = 0

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            AmbientBackground(nightMode: theme.isNightMode)

            ScrollView {
                VStack(spacing: 28) {
                    headerCard
                    progressCard
                    if viewModel.hasDevelopmentFocus {
                        developmentFocusCard
                    }
                    categoryOverview
                    recentMomentsCard
                    screeningCards
                    growthInsightsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            if milestones.isEmpty {
                DataSeeder.seedIfNeeded(modelContext: modelContext)
            }
        }
        .onChange(of: milestones.count) {
            viewModel.update(milestones: milestones, childProfile: childProfile)
        }
        .onChange(of: milestones.filter(\.isCompleted).count) {
            viewModel.update(milestones: milestones, childProfile: childProfile)
        }
        .onAppear {
            viewModel.update(milestones: milestones, childProfile: childProfile)
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.greetingText)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)

            Text(childProfile.name.isEmpty ? "Little one" : childProfile.name)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(theme.text)

            Text("You're \(childProfile.humanReadableAge)!")
                .font(.callout)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    // MARK: - Progress Ring

    private var progressCard: some View {
        VStack(spacing: 20) {
            ZStack {
                MilestoneRingView(
                    progress: viewModel.currentStageProgress,
                    completedCount: viewModel.currentStageCompleted,
                    totalCount: viewModel.currentStageTotal,
                    nightMode: theme.isNightMode
                )
                .frame(width: 160, height: 160)

                VStack(spacing: 2) {
                    Text("\(viewModel.currentStageCompleted)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.text)

                    Text("of \(viewModel.currentStageTotal)")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)

                    Text("milestones")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Text("\(viewModel.targetAgeMonth)-month milestones")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Milestone progress")
        .accessibilityValue("\(viewModel.currentStageCompleted) of \(viewModel.currentStageTotal) milestones completed for \(viewModel.targetAgeMonth) months")
    }

    // MARK: - Category Overview (Bento Grid)

    private var categoryOverview: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]

        return VStack(alignment: .leading, spacing: 14) {
            Text("Growth Domains")
                .font(.callout.weight(.semibold))
                .foregroundStyle(theme.text)
                .padding(.leading, 4)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(MilestoneCategory.allCases, id: \.self) { category in
                    domainTile(category)
                }
            }
        }
    }

    private func domainTile(_ category: MilestoneCategory) -> some View {
        let stats = viewModel.categoryStats(category, milestones: milestones)
        let progress = stats.total > 0 ? Double(stats.completed) / Double(stats.total) : 0
        let domainColor = category.color(for: theme.isNightMode)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 17))
                    .foregroundStyle(domainColor)

                Spacer()

                Text("\(stats.completed)/\(stats.total)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.text.opacity(0.7))
                    .monospacedDigit()
            }

            Text(category.gentleLabel)
                .font(.callout.weight(.medium))
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.text.opacity(0.06))
                        .frame(height: 6)

                    Capsule()
                        .fill(domainColor)
                        .frame(width: max(0, geo.size.width * progress), height: 6)
                        .animation(.easeOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(domainColor.opacity(theme.isNightMode ? 0.25 : 0.22))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.gentleLabel), \(stats.completed) of \(stats.total) completed")
    }

    // MARK: - Recent Moments

    private var recentMomentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Moments")
                .font(.callout.weight(.semibold))
                .foregroundStyle(theme.text)
                .padding(.leading, 4)

            if viewModel.completedMilestones.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(theme.textSecondary)
                    Text("Moments you notice will appear here")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.isNightMode ? Theme.nightCard : .white)
                )
            } else {
                ForEach(viewModel.completedMilestones.prefix(3)) { milestone in
                    HStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.green)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(milestone.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.text)
                                .lineLimit(1)

                            if let date = milestone.dateCompleted {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                            }

                            if !milestone.completionNote.isEmpty {
                                Text(milestone.completionNote)
                                    .font(.caption2)
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(theme.isNightMode ? Theme.nightCard : .white)
                    )
                    .shadow(
                        color: theme.isNightMode
                            ? Color.black.opacity(0.2)
                            : Theme.dayText.opacity(0.04),
                        radius: 8,
                        x: 0,
                        y: 3
                    )
                }
            }
        }
    }

    // MARK: - Screening Cards

    private var screeningCards: some View {
        ScreeningCardView(
            correctedAge: viewModel.correctedAge,
            nightMode: theme.isNightMode
        )
    }

    // MARK: - Growth Insights

    private var growthInsightsSection: some View {
        GrowthInsightsView(nightMode: theme.isNightMode)
    }

    // MARK: - Development Focus Card

    private var developmentFocusCard: some View {
        DevelopmentFocusView(
            concernLevel: viewModel.concernLevel,
            domainConcerns: viewModel.domainConcerns,
            totalFlagged: viewModel.flaggedMilestones.count,
            nightMode: theme.isNightMode
        )
    }
}

// MARK: - Preview

#Preview {
    let profile = ChildProfile()
    profile.birthDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    profile.name = "Preview"
    profile.hasCompletedOnboarding = true

    return DashboardView()
        .environment(profile)
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
