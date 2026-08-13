//
//  AssistantView.swift
//  Sproutly
//
//  Created by Jash Madhani on 27/02/26.
//

import SwiftUI
import SwiftData


struct AssistantView: View {
    @Query(sort: \Milestone.ageMonth) private var milestones: [Milestone]
    @Environment(ChildProfile.self) private var childProfile
    @Environment(ThemeManager.self) private var theme

    @State private var scrollOffset: CGFloat = 0

    private var isCompactHeader: Bool { scrollOffset < -10 }
    private var correctedAge: Int { max(0, childProfile.calculateCorrectedAge()) }

    var body: some View {
        ZStack(alignment: .top) {
            AmbientBackground(nightMode: theme.isNightMode)

            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    assistantCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: geo.frame(in: .named("assistantScroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "assistantScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }
            .scrollDismissesKeyboard(.interactively)
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 80)
                    Color.black
                }
                .ignoresSafeArea()
            )

            // Compact sticky header
            VStack {
                HStack {
                    Text("Assistant")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(theme.text)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .opacity(isCompactHeader ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: isCompactHeader)
                Spacer()
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Assistant")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(theme.text)

            Text("Ask anything about your child's growth")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Assistant Card

    private var assistantCard: some View {
        SupportAssistantView(
            milestones: milestones,
            correctedAge: correctedAge,
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

    return AssistantView()
        .environment(profile)
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
