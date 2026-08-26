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
            // Sentence case, section-header weight, no tracking — the same
            // treatment as "What you've noticed" and "Five areas of growth"
            // directly below it. The uppercase, letter-spaced version this
            // replaced was the only such label in the app and read as though it
            // had been pasted in from a different product.
            Text("Something to notice today")
                .font(Theme.sproutlySectionHeader)
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)

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
                // Meta, not body. The tip is secondary to the milestone title
                // above it, and at body size it rendered larger than the domain
                // label it sits under — hierarchy inverted by two type steps.
                Text(milestone.tips)
                    .font(Theme.sproutlyMeta)
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // A real control. As a bare label this read as a stray caption
            // rather than the dismissal it is; every other quiet action in the
            // app carries the recessed capsule, so it wears one too.
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    DailyCardDismissal.dismiss(for: child.id, on: today)
                    isDismissed = true
                }
            } label: {
                Text("Not yet")
                    .font(Theme.sproutlyItemTitle)
                    .foregroundStyle(theme.text)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.recessedFill)
                    )
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
                .font(Theme.sproutlySectionHeader)
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)

            Text("You've saved everything here for now")
                .font(Theme.sproutlyCardTitle)
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)

            Text("More arrives as \(child.displayName) grows. Anything you notice in the meantime can go in as your own moment.")
                .font(Theme.sproutlyMeta)
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
