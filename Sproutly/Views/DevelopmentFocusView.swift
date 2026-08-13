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
        "\(milestoneCount) skill\(milestoneCount == 1 ? "" : "s") developing"
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
                .fill(nightMode ? Theme.nightCard : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accentColor.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(
            color: nightMode
                ? Color.black.opacity(0.25)
                : Theme.dayText.opacity(0.05),
            radius: nightMode ? 10 : 16,
            x: 0,
            y: nightMode ? 4 : 6
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: concernLevel.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(concernLevel.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary(for: nightMode))

                Text("\(totalFlagged) earlier skill\(totalFlagged == 1 ? "" : "s") to revisit")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary(for: nightMode))
            }
        }
    }

    // MARK: - Body Text

    private var bodyText: some View {
        Text(primaryCopy)
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary(for: nightMode))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var primaryCopy: String {
        switch concernLevel {
        case .reviewSuggested:
            return "A few earlier milestones are still developing. This is very common \u{2014} every child grows at their own pace. Continue observing through everyday play and routines."
        case .needsAttention:
            return "Some milestones are missing or delayed. It’s important to talk with your child’s doctor to understand next steps — and how you can help."
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
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary(for: nightMode))

                    Spacer()

                    Text(concern.summary)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary(for: nightMode))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.textSecondary(for: nightMode).opacity(0.04))
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

            Text("Early support can make a meaningful difference. Pediatricians routinely screen for developmental milestones and welcome questions at any visit.")
                .font(.caption)
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
            withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                showEarlyIntervention.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.caption)
                    .foregroundStyle(Theme.accentBlue(for: nightMode))
                    .frame(width: 20)

                Text("What is Early Intervention?")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary(for: nightMode))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary(for: nightMode))
                    .rotationEffect(.degrees(showEarlyIntervention ? 90 : 0))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(showEarlyIntervention ? "Double tap to collapse" : "Double tap to expand")
    }

    // MARK: - Early Intervention Panel

    private var earlyInterventionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            interventionPoint(
                icon: "checkmark.seal",
                text: "You do not need a diagnosis to seek developmental support. Many programs accept referrals based on observation alone."
            )
            interventionPoint(
                icon: "stethoscope",
                text: "The AAP recommends developmental screening at 9 and 30 months. Your pediatrician can administer these during routine well-child visits."
            )
            interventionPoint(
                icon: "figure.2.and.child.holdinghands",
                text: "Early intervention programs focus on building skills through everyday interactions \u{2014} play, feeding, bath time, and shared routines."
            )
            interventionPoint(
                icon: "heart.fill",
                text: "Seeking support is a sign of attentive parenting, not a cause for worry. The earliest years offer the greatest opportunity for growth."
            )
        }
        .padding(.leading, 28)
        .transition(.opacity)
        .animation(.spring(response: 0.35, dampingFraction: 1.0), value: showEarlyIntervention)
    }

    private func interventionPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.accentBlue(for: nightMode))
                .frame(width: 16)

            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary(for: nightMode))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
