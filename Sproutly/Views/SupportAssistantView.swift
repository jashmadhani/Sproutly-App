//
//  SupportAssistantView.swift
//  Sproutly
//
//  Created by Jash Madhani on 19/02/26.
//

import SwiftUI
import SwiftData

// Presentation only. The engine lives in Managers/AssistantEngine.swift so it
// can be tested without a view, the way DevelopmentObserver is. Still no network
// call anywhere in this feature.
struct SupportAssistantView: View {
    let milestones: [Milestone]
    let correctedAge: Int
    let excludedBands: Set<Int>
    let nightMode: Bool

    @State private var question: String = ""
    @State private var response: AssistantResponse? = nil
    @State private var responseOpacity: Double = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            // Same header as the Settings feature cards, so the disc scales with
            // its glyph and the whole thing stacks at accessibility sizes rather
            // than squeezing the title into a two-word column.
            FeatureCardHeader(
                title: "Ask Sproutly",
                subtitle: "A few things to try, and when to ask",
                systemImage: "sparkles",
                nightMode: nightMode,
                diameter: 36,
                glyphSize: 16,
                subtitleFont: Theme.sproutlyMeta
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Ask Sproutly. A few things to try, and when to ask")

            // Input field
            HStack(spacing: 10) {
                TextField(
                    "",
                    text: $question,
                    prompt: Text("What have you been wondering about?")
                        .foregroundColor(Theme.fieldPlaceholder(for: nightMode)),
                    axis: .vertical
                )
                    .lineLimit(1...4)
                    .font(Theme.sproutlyBody)
                    .foregroundStyle(Theme.textPrimary(for: nightMode))
                    .focused($isInputFocused)
                    .accessibilityLabel("Question input")
                    .accessibilityHint("Type a question about your child")

                if !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        generateResponse()
                        isInputFocused = false
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.accentBlueText(for: nightMode))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Send question")
                }
            }
            // Same rule as every other typed field in the app. This was the
            // last boxed one — a #E6E2DD slab whose placeholder measured 1.67:1
            // and which read as a component from another app.
            .underlineField(nightMode: nightMode, isFocused: isInputFocused)
            .animation(.easeInOut(duration: 0.25), value: question.isEmpty)

            // Before anything has been asked. A parent cannot guess that this
            // covers milestones and not stool colour or sleep training, and the
            // field invites anything. Showing what it answers well is the only
            // honest way to say so before they have typed.
            if response == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Try asking")
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(Theme.accentBlueText(for: nightMode))

                    ForEach(Self.starterQuestions, id: \.self) { starter in
                        Button {
                            question = starter
                            generateResponse()
                            isInputFocused = false
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "arrow.up.right")
                                    .font(Theme.sproutlyMeta)
                                    .foregroundStyle(Theme.growthGreenText(for: nightMode))
                                Text(starter)
                                    .font(Theme.sproutlyBody)
                                    .foregroundStyle(Theme.textSecondary(for: nightMode))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Asks this question")
                    }
                }
            }

            // Response area
            if let resp = response {
                VStack(alignment: .leading, spacing: 12) {
                    // What is ordinarily true at this age
                    Text(resp.context)
                        .font(Theme.sproutlyBody)
                        .foregroundStyle(Theme.textPrimary(for: nightMode))
                        .fixedSize(horizontal: false, vertical: true)

                    // Activity suggestions
                    if !resp.activities.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Things to try")
                                .font(Theme.sproutlyCardTitle)
                                .foregroundStyle(Theme.accentBlueText(for: nightMode))

                            ForEach(resp.activities, id: \.self) { activity in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(Theme.sproutlyBody)
                                        .foregroundStyle(Theme.growthGreenText(for: nightMode))
                                    Text(activity)
                                        .font(Theme.sproutlyBody)
                                        .foregroundStyle(Theme.textSecondary(for: nightMode))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    // What the answer was built from. Milestone titles are
                    // third-person labels, so they are listed rather than folded
                    // into the prose, which is also how every other screen shows
                    // them. The saved marker is the parent's own record.
                    if !resp.cited.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Related milestones")
                                .font(Theme.sproutlyCardTitle)
                                .foregroundStyle(Theme.accentBlueText(for: nightMode))

                            ForEach(resp.cited, id: \.title) { item in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(Theme.sproutlyMeta)
                                        .foregroundStyle(
                                            item.isCompleted
                                                ? Theme.growthGreenText(for: nightMode)
                                                : Theme.textSecondary(for: nightMode)
                                        )
                                    Text(item.title)
                                        .font(Theme.sproutlyBody)
                                        .foregroundStyle(Theme.textSecondary(for: nightMode))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(
                                    item.isCompleted
                                        ? "\(item.title). Saved."
                                        : "\(item.title). Not saved yet."
                                )
                            }
                        }
                    }

                    // Pediatric note (when appropriate)
                    if let pediatric = resp.pediatricNote {
                        // An urgent redirect is the most important thing on the
                        // screen, so it is not rendered in the quieter secondary
                        // weight the standing note uses.
                        Text(pediatric)
                            .font(Theme.sproutlyBody)
                            .foregroundStyle(
                                resp.scope == .urgentHealthSymptom
                                    ? Theme.textPrimary(for: nightMode)
                                    : Theme.textSecondary(for: nightMode).opacity(0.9)
                            )
                            .padding(.top, 4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.growthGreen(for: nightMode).opacity(nightMode ? 0.06 : 0.05))
                )
                .opacity(responseOpacity)
                .animation(.easeInOut(duration: 0.4), value: responseOpacity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Answer from Sproutly")
            }
        }
        .warmCard(nightMode: nightMode)
    }

    // MARK: - Starters

    /// One per shape the engine answers well: a timing question, a what-can-I-do
    /// question, and an is-this-ordinary question. They teach the range of what
    /// can be asked, not just three facts.
    private static let starterQuestions = [
        "When do children start putting words together?",
        "What can I do to help with her balance?",
        "Is it normal that he plays alongside other children rather than with them?"
    ]

    // MARK: - Response Generation

    private func generateResponse() {
        let asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !asked.isEmpty else { return }

        responseOpacity = 0
        response = AssistantEngine.respond(
            to: asked,
            milestones: milestones,
            correctedAge: correctedAge,
            excludedBands: excludedBands
        )

        withAnimation(.easeInOut(duration: 0.4)) {
            responseOpacity = 1
        }
    }
}
