//
//  DevelopmentFocusView.swift
//  Sproutly
//
//  Created by Jash Madhani on 27/02/26.
//

import SwiftUI

// MARK: - Concern Level


// calm tone throughout, no alarming language
enum ConcernLevel {
    case reviewSuggested    // 1–2 milestones, single domain
    case needsAttention     // 3+ milestones OR multiple domains

    var title: String {
        switch self {
        case .reviewSuggested: return "Development Focus"
        case .needsAttention: return "Development Focus"
        }
    }

    var icon: String {
        switch self {
        case .reviewSuggested: return "eyes"
        case .needsAttention: return "hand.raised.fingers.spread"
        }
    }
}

// MARK: - Domain Concern


struct DomainConcern: Identifiable {
    let id: String
    let category: MilestoneCategory
    let milestoneCount: Int

    var summary: String {
        "Not saved yet: \(milestoneCount)"
    }
}

// MARK: - Development Focus View

// shows when earlier milestones are still incomplete
struct DevelopmentFocusView: View {
    let concernLevel: ConcernLevel
    let domainConcerns: [DomainConcern]
    let totalFlagged: Int
    let nightMode: Bool

    @State private var showEarlyIntervention = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Accent Color

    private var accentColor: Color {
        nightMode
            ? Color(red: 0.95, green: 0.78, blue: 0.45) // warm amber night
            : Color(red: 0.88, green: 0.65, blue: 0.30) // warm amber day
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            bodyText
            domainBreakdown
            if concernLevel == .needsAttention {
                escalatedGuidance
            }
            earlyInterventionToggle
            if showEarlyIntervention {
                earlyInterventionPanel
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.cardBackground(for: nightMode))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accentColor.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(
            color: Theme.cardShadow(for: nightMode),
            radius: nightMode ? 10 : 16,
            x: 0,
            y: nightMode ? 4 : 6
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            ScaledIconDisc(
                systemImage: concernLevel.icon,
                fill: accentColor.opacity(0.12),
                tint: accentColor,
                diameter: 36,
                glyphSize: 15
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(concernLevel.title)
                    .font(Theme.sproutlyCardTitle)
                    .foregroundStyle(Theme.textPrimary(for: nightMode))

                // Longer than the label it replaced, so it must be allowed to
                // wrap rather than truncate beside the glyph.
                Text("\(totalFlagged) thing\(totalFlagged == 1 ? "" : "s") from earlier ages you have not saved yet")
                    .font(Theme.sproutlyMeta)
                    .foregroundStyle(Theme.textSecondary(for: nightMode))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Body Text

    private var bodyText: some View {
        Text(primaryCopy)
            .font(Theme.sproutlyBody)
            .foregroundStyle(Theme.textSecondary(for: nightMode))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var primaryCopy: String {
        switch concernLevel {
        case .reviewSuggested:
            return "There are a few things from earlier ages you have not saved yet. That does not tell us whether your child can do them. Keep an eye out during everyday play and routines."
        case .needsAttention:
            // Deliberately observational. "Missing or delayed" plus "it's important to"
            // read as a finding about the child rather than as something noticed, which
            // is the one place the copy drifted from the tone rule the rest of the app
            // keeps. Says the same thing without handing the parent a verdict.
            return "There are a few things for this age that you have not saved yet. That does not tell us whether your child can do them. If you are wondering about any of them, bring your notes to your child's doctor. They can help you decide what to do next."
        }
    }


    // MARK: - Domain Breakdown

    private var domainBreakdown: some View {
        VStack(spacing: 8) {
            ForEach(domainConcerns) { concern in
                HStack(spacing: 10) {
                    Image(systemName: concern.category.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(concern.category.color(for: nightMode).opacity(0.8))
                        .frame(width: 20)

                    Text(concern.category.gentleLabel)
                        .font(Theme.sproutlyItemTitle)
                        .foregroundStyle(Theme.textPrimary(for: nightMode))

                    Spacer()

                    Text(concern.summary)
                        .font(Theme.sproutlyMeta)
                        .foregroundStyle(Theme.textSecondary(for: nightMode))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.recessedFill(for: nightMode))
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(concern.category.gentleLabel), \(concern.summary)")
            }
        }
    }

    // MARK: - Escalated Guidance

    private var escalatedGuidance: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.circle")
                .font(.system(size: 14))
                .foregroundStyle(accentColor)
                .padding(.top, 2)

            Text("If you have questions, asking early helps you find the right support. Pediatricians check milestones as a matter of routine and welcome questions at any visit.")
                .font(Theme.sproutlyBody)
                .foregroundStyle(Theme.textSecondary(for: nightMode))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accentColor.opacity(nightMode ? 0.08 : 0.05))
        )
    }

    // MARK: - Early Intervention Toggle

    private var earlyInterventionToggle: some View {
        Button {
            withAnimation(Theme.spring(0.35, damping: 1.0, reduceMotion: reduceMotion)) {
                showEarlyIntervention.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.caption)
                    .foregroundStyle(Theme.accentBlueText(for: nightMode))
                    .frame(width: 20)

                Text("What is Early Intervention?")
                    .font(Theme.sproutlyCardTitle)
                    .foregroundStyle(Theme.textPrimary(for: nightMode))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary(for: nightMode))
                    .rotationEffect(.degrees(showEarlyIntervention ? 90 : 0))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(showEarlyIntervention ? "Collapses this section" : "Expands this section")
    }

    // MARK: - Early Intervention Panel

    private var earlyInterventionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            interventionPoint(
                icon: "checkmark.seal",
                text: "You do not need a diagnosis to ask for support. Many programs accept referrals based on what a parent has noticed."
            )
            interventionPoint(
                icon: "stethoscope",
                text: "The AAP recommends developmental screening at 9 and 30 months. Your pediatrician can administer these during routine well-child visits."
            )
            interventionPoint(
                icon: "figure.2.and.child.holdinghands",
                text: "Early support programs work through everyday interactions: play, feeding, bath time, and shared routines."
            )
            interventionPoint(
                icon: "heart.fill",
                text: "Asking for support is a normal thing to do, not a cause for worry. The earliest years are when it makes the most difference."
            )
        }
        .padding(.leading, 28)
        .transition(.opacity)
        .animation(Theme.spring(0.35, damping: 1.0, reduceMotion: reduceMotion), value: showEarlyIntervention)
    }

    private func interventionPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.accentBlueText(for: nightMode))
                .frame(width: 16)

            Text(text)
                .font(Theme.sproutlyBody)
                .foregroundStyle(Theme.textSecondary(for: nightMode))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
