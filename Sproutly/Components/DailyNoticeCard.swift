//
//  DailyNoticeCard.swift
//  Sproutly
//

import SwiftUI

// MARK: - Daily Notice Card

/// One thing to notice today, at the top of the dashboard.
///
/// This exists to give the app a reason to be opened tomorrow without turning
/// it into a feed or adding a second place to log things. It suggests; it never
/// instructs and never assesses. The same suggestion stands all day and a new
/// one arrives tomorrow — see `DailyNoticePicker` for why that is deterministic
/// rather than random.
struct DailyNoticeCard: View {

    let child: Child
    let milestones: [Milestone]
    let correctedAge: Int
    let excludedBands: Set<Int>
    /// Injected so a preview or a test can pin the day.
    var today: Date = Date()
    let onLogged: (Milestone) -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var isDismissed = false

    private var suggestion: Milestone? {
        DailyNoticePicker.pick(
            from: milestones,
            correctedAge: correctedAge,
            excludedBands: excludedBands,
            childID: child.id,
            day: today
        )
    }

    var body: some View {
        Group {
            if isDismissed || DailyCardDismissal.isDismissed(for: child.id, on: today) {
                EmptyView()
            } else if let suggestion {
                card(for: suggestion)
            } else {
                completionCard
            }
        }
    }
}

// MARK: - Suggestion

private extension DailyNoticeCard {

    func card(for milestone: Milestone) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Something to notice today")
                .font(Theme.sproutlyMeta)
                .foregroundStyle(theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(milestone.title)
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(theme.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(milestone.categoryType.gentleLabel)
                        .font(Theme.sproutlyMeta)
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer(minLength: 8)

                OneTapLogButton(
                    isCompleted: false,
                    nightMode: theme.isNightMode,
                    accessibilityTitle: milestone.title
                ) {
                    log(milestone)
                }
            }

            if !milestone.tips.isEmpty {
                Text(milestone.tips)
                    .font(Theme.sproutlyBody)
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    DailyCardDismissal.dismiss(for: child.id, on: today)
                    isDismissed = true
                }
            } label: {
                Text("Not yet")
                    .font(Theme.sproutlyMeta)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Not yet")
            .accessibilityHint("Hides today's suggestion until tomorrow")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmCard(nightMode: theme.isNightMode)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Something to notice today")
        .accessibilityValue("\(milestone.title). \(milestone.categoryType.gentleLabel).")
    }

    // Never an empty card. A parent who has saved everything available should
    // meet something warm, not a blank space that reads as a bug.
    var completionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Something to notice today")
                .font(Theme.sproutlyMeta)
                .foregroundStyle(theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)

            Text("You've saved everything here for now")
                .font(Theme.sproutlyCardTitle)
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)

            Text("More arrives as \(child.displayName) grows. Anything you notice in the meantime can go in as your own moment.")
                .font(Theme.sproutlyBody)
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmCard(nightMode: theme.isNightMode)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Something to notice today")
        .accessibilityValue("You've saved everything here for now")
    }

    /// Unlike the onboarding backfill, this one *is* dated: the parent is
    /// telling us they noticed it today.
    func log(_ milestone: Milestone) {
        withAnimation(.easeOut(duration: 0.25)) {
            milestone.isCompleted = true
            milestone.dateCompleted = Date()
            isDismissed = true
        }
        MilestoneLogCounter.record(milestone)
        onLogged(milestone)
    }
}
