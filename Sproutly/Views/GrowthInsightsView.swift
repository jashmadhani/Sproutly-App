//
//  GrowthInsightsView.swift
//  Sproutly
//
//  Created by Jash Madhani on 27/02/26.
//

import SwiftUI


struct GrowthInsightsView: View {
    let nightMode: Bool

    @State private var expandedSection: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // A card title, not a page-section header. This lives *inside* a
            // card, so its peers are "Report for your visit" and "Night Mode" —
            // sproutlySectionHeader is the style used by "Growth Domains" and
            // "Recent Moments", which sit on the page background one level up.
            // Matching them made this read as oversized for its container, and
            // as the only card title in the app rendered in blue.
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Theme.accentBlueText(for: nightMode))

                Text("Things worth knowing")
                    .font(Theme.sproutlyCardTitle)
                    .foregroundStyle(Theme.textPrimary(for: nightMode))
            }
            .accessibilityElement(children: .combine)

            // Collapsible educational rows
            insightRow(
                id: "domains",
                icon: "square.grid.3x3.fill",
                title: "Five areas of growth",
                // The parent-facing names, not the clinical ones. This list used
                // the raw `MilestoneCategory` values ("Gross Motor", "Cognitive")
                // while every other screen shows `gentleLabel`, so the one place
                // that explains the five areas named them differently from the
                // five tiles on the dashboard.
                //
                // The "Label — definition" dashes are gone too. Five of them
                // stacked read as a generated glossary rather than something a
                // person wrote.
                body: """
                    Children grow in five different ways, and Sproutly follows all of them.

                    Movement & Strength is the big stuff: rolling, walking, running, climbing.

                    Hands & Coordination is the small stuff: grasping, drawing, stacking, feeding themselves.

                    Communication covers understanding you and making themselves understood, in words, sounds and gestures.

                    Curiosity & Thinking is how they work things out: solving problems, remembering, exploring.

                    Connection & Emotion is how they relate to you and to other people, and how they handle feelings.

                    Every child grows in all five. They just don't grow in all five at the same speed, and that's ordinary.
                    """
            )

            insightRow(
                id: "surveillance",
                icon: "eye.fill",
                title: "What you notice, and what a doctor checks",
                body: """
                    Watching how your child grows, day to day, is something you already do. Sproutly is just somewhere to keep it.

                    Developmental screening uses brief, standardized tools at specific ages (9, 18, and 30 months) to check whether development is on track. Your pediatrician handles these.

                    The two work together. What you notice at home gives your pediatrician useful context.
                    """
            )

            insightRow(
                id: "early",
                icon: "heart.fill",
                title: "Why noticing early helps",
                body: """
                    Noticing something early tends to lead to better outcomes, because the brain is at its most adaptable in the first few years.

                    If something does come up, early support programs can help, and you don't need a diagnosis to be referred. They work through ordinary things: play, meals, bath time.

                    It isn't about labels. It's about giving your child a good start.
                    """
            )

            insightRow(
                id: "when",
                icon: "person.badge.plus",
                title: "When to ask",
                body: """
                    Trust your instincts. You know your child best. Some situations where a conversation with your pediatrician can be helpful:

                    • If speech development seems slower than expected, a hearing screening can rule out simple causes
                    • If you notice differences in social engagement, early evaluation can open doors to support
                    • Any time you're unsure. Pediatricians welcome these questions

                    Well-child visits are a good time to bring these up.
                    """
            )
        }
        .warmCard(nightMode: nightMode)
    }

    // MARK: - Insight Row

    private func insightRow(id: String, icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Theme.spring(0.35, damping: 1.0, reduceMotion: reduceMotion)) {
                    expandedSection = expandedSection == id ? nil : id
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(Theme.accentBlueText(for: nightMode))
                        .frame(width: 20)

                    Text(title)
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(Theme.textPrimary(for: nightMode))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary(for: nightMode))
                        .rotationEffect(.degrees(expandedSection == id ? 90 : 0))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(expandedSection == id ? "Collapses this section" : "Expands this section")

            if expandedSection == id {
                Text(body)
                    .font(Theme.sproutlyBody)
                    .foregroundStyle(Theme.textSecondary(for: nightMode))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .padding(.leading, 30)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 2)
        .clipped()
        .animation(Theme.spring(0.35, damping: 1.0, reduceMotion: reduceMotion), value: expandedSection)
    }
}
