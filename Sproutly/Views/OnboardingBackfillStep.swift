//
//  OnboardingBackfillStep.swift
//  Sproutly
//

import SwiftUI

// MARK: - Candidate

/// One offerable row in the backfill list.
///
/// Deliberately a plain value rather than a `Milestone`. At this point in
/// onboarding the child does not exist yet, so there are no milestone rows to
/// show — and `DataSeeder.allMilestones` builds eighty fresh `@Model` objects
/// on every access, which a view body must never do.
struct BackfillCandidate: Identifiable, Hashable {

    /// The milestone title. Every title in the seed catalog is unique, and title
    /// is already the identity `DataSeeder.reseedIfIncomplete` matches on, so it
    /// is what the selection carries across to the seeded rows.
    let id: String
    let category: MilestoneCategory
    let ageMonth: Int
    let expectedAgeText: String

    var title: String { id }
}

// MARK: - Catalog

enum BackfillCatalog {

    /// Derived once for the process from the seed catalog, which never changes
    /// at runtime.
    static let all: [BackfillCandidate] = DataSeeder.allMilestones
        .filter { !$0.isUserCreated }
        .map { milestone in
            BackfillCandidate(
                id: milestone.title,
                category: milestone.categoryType,
                ageMonth: milestone.ageMonth,
                expectedAgeText: milestone.expectedAgeText
            )
        }

    /// Everything the child is already old enough for, by corrected age.
    ///
    /// The seed catalog starts at six months, so this is empty for every child
    /// under six months corrected — which is why the caller skips the step on an
    /// empty list rather than on an age threshold.
    static func candidates(correctedAge: Int) -> [BackfillCandidate] {
        all
            .filter { $0.ageMonth <= correctedAge }
            .sorted { lhs, rhs in
                lhs.ageMonth == rhs.ageMonth
                    ? lhs.title < rhs.title
                    : lhs.ageMonth < rhs.ageMonth
            }
    }

    /// Marks the child's own milestone rows for the titles the parent selected.
    ///
    /// Scoped to one child's `milestones`, so a sibling is never touched, and
    /// skips parent-authored moments even on a title collision — those are inert
    /// everywhere else that judges progress and must stay inert here.
    ///
    /// The caller saves; this makes every mutation first so one save covers them.
    @MainActor
    static func apply(_ titles: Set<String>, to child: Child) {
        guard !titles.isEmpty else { return }

        for milestone in child.milestones
        where !milestone.isUserCreated && titles.contains(milestone.title) {
            milestone.isCompleted = true
            // No date on purpose. The parent told us it happened, not when, and
            // inventing today's date would be wrong everywhere it is later read
            // — the share card most of all. See Milestone.recencyOrdered.
            milestone.dateCompleted = nil
            milestone.completionNote = ""
        }
    }
}

// MARK: - Step

/// The last onboarding step: what the child already does.
///
/// A parent who finishes onboarding for a fourteen-month-old and lands on a
/// dashboard reading "0 of N" has been told something both wrong and quietly
/// discouraging. This is where they say what they have already seen.
struct OnboardingBackfillStep: View {

    let childName: String
    let candidates: [BackfillCandidate]
    @Binding var selection: Set<String>

    @Environment(ThemeManager.self) private var theme

    private var grouped: [(category: MilestoneCategory, items: [BackfillCandidate])] {
        let byCategory = Dictionary(grouping: candidates, by: \.category)
        return MilestoneCategory.allCases.compactMap { category in
            guard let items = byCategory[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.sectionSpacing) {
                header

                ForEach(grouped, id: \.category) { group in
                    domainSection(category: group.category, items: group.items)
                }
            }
            .padding()
            .padding(.bottom, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Header

private extension OnboardingBackfillStep {

    var header: some View {
        VStack(spacing: 8) {
            Text("What has \(childName) already done?")
                .font(.sproutlyDisplay(26))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tap anything you've already seen. You can change these any time.")
                .font(Theme.sproutlyBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }
}

// MARK: - Sections

private extension OnboardingBackfillStep {

    func domainSection(category: MilestoneCategory, items: [BackfillCandidate]) -> some View {
        VStack(alignment: .leading, spacing: Theme.itemSpacing) {
            HStack(spacing: 10) {
                // Decorative — the label beside it carries the meaning, which is
                // why a domain surface colour is legitimate here.
                Image(systemName: category.icon)
                    .sproutlyScaledFont(16, relativeTo: .subheadline)
                    .foregroundStyle(category.color(for: theme.isNightMode))
                    .frame(width: 24)

                Text(category.gentleLabel)
                    .font(Theme.sproutlyCardTitle)
                    .foregroundStyle(theme.text)

                Spacer(minLength: 0)
            }
            .accessibilityAddTraits(.isHeader)

            ForEach(items) { candidate in
                row(candidate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmCard(nightMode: theme.isNightMode)
    }

    func row(_ candidate: BackfillCandidate) -> some View {
        let isSelected = selection.contains(candidate.id)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Not dimmed or struck through when selected, unlike the
                // Milestones tab. There a completed row is an item leaving a
                // to-do list; here selecting means "yes, she does this", and
                // greying out the things the child can do says the opposite.
                // The green fill and the check carry the state instead.
                Text(candidate.title)
                    .font(Theme.sproutlyItemTitle)
                    .foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(candidate.expectedAgeText)
                    .font(Theme.sproutlyMeta)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer(minLength: 8)

            OneTapLogButton(
                isCompleted: isSelected,
                nightMode: theme.isNightMode,
                accessibilityTitle: candidate.title
            ) {
                toggle(candidate)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    Theme.milestoneRowFill(
                        for: theme.isNightMode,
                        isCompleted: isSelected
                    )
                )
        )
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityElement(children: .combine)
    }

    func toggle(_ candidate: BackfillCandidate) {
        if selection.contains(candidate.id) {
            selection.remove(candidate.id)
        } else {
            selection.insert(candidate.id)
        }
    }
}

#if DEBUG
#Preview {
    OnboardingBackfillStep(
        childName: "Aanya",
        candidates: BackfillCatalog.candidates(correctedAge: 14),
        selection: .constant(["Sits without support"])
    )
    .environment(ThemeManager())
}
#endif
