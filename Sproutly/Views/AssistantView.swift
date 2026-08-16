//
//  AssistantView.swift
//  Sproutly
//
//  Created by Jash Madhani on 27/02/26.
//

import SwiftUI
import SwiftData


struct AssistantView: View {
    
    @Environment(ChildStore.self) private var childStore

    // MainTabView only renders once a child exists; the fallback keeps this view
    // total without threading an optional through every call site.
    private var child: Child { childStore.activeChild ?? Child() }
    private var milestones: [Milestone] { child.sortedMilestones }
    @Environment(ThemeManager.self) private var theme

    @State private var scrollOffset: CGFloat = 0

    private var isCompactHeader: Bool { scrollOffset < -10 }
    private var correctedAge: Int { max(0, child.calculateCorrectedAge()) }

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
                        .font(.sproutlyCompactHeading(17))
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
                .font(.sproutlyDisplay(30))
                .foregroundStyle(theme.text)

            Text("Ask anything about your child's growth")
                .font(Theme.sproutlyBody)
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

    AssistantView()
        .environment(previewChildStore)
        .environment(PurchaseManager())
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
