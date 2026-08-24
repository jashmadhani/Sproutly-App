//
//  MainTabView.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/02/26.
//

import SwiftUI
import SwiftData


struct MainTabView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(PurchaseManager.self) private var purchases
    @State private var selectedTab: Tab = .dashboard

    /// Measured, not guessed. The dock's height depends on the Dynamic Type size
    /// of its labels and on the device's bottom safe area, so a constant would be
    /// wrong on some phones and at some text sizes.
    @State private var dockHeight: CGFloat = 0
    @State private var showProWelcome = false

    private static let hasSeenProWelcomeKey = "sproutly_has_seen_pro_welcome"

    enum Tab: String, CaseIterable {
        case dashboard = "Home"
        case milestones = "Milestones"
        case assistant = "Assistant"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .dashboard: return "leaf.circle"
            case .milestones: return "list.bullet.circle"
            case .assistant: return "bubble.left.and.bubble.right"
            case .settings: return "gearshape"
            }
        }

        var selectedIcon: String {
            switch self {
            case .dashboard: return "leaf.circle.fill"
            case .milestones: return "list.bullet.circle.fill"
            case .assistant: return "bubble.left.and.bubble.right.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        // A real TabView rather than `switch selectedTab`, which built a
        // structurally different view per branch and so tore the outgoing tab
        // down on every switch — taking its @State with it. That silently reset
        // the Milestones filter and which domain sections were expanded, plus
        // every scroll position, each time a parent glanced at Home and came
        // back. TabView keeps all four alive and still fires .onAppear when a
        // tab becomes visible, so DashboardView's viewModel.update() safety net
        // survives unchanged. The system bar is hidden; the floating dock below
        // is still the only visible control.
        TabView(selection: $selectedTab) {
            DashboardView()
                .tag(Tab.dashboard)
                .toolbar(.hidden, for: .tabBar)
                .dockClearance(dockHeight)

            MilestonesView()
                .tag(Tab.milestones)
                .toolbar(.hidden, for: .tabBar)
                .dockClearance(dockHeight)

            AssistantView()
                .tag(Tab.assistant)
                .toolbar(.hidden, for: .tabBar)
                .dockClearance(dockHeight)

            SettingsView()
                .tag(Tab.settings)
                .toolbar(.hidden, for: .tabBar)
                .dockClearance(dockHeight)
        }
        // Kills the horizontal slide between tabs. The dock is a set of
        // destinations, not a pageable surface, and the slide also fought the
        // sticky-header animations inside each tab.
        .transaction { $0.animation = nil }
        // The dock is an overlay, and the space it occupies is reserved *inside*
        // each tab by `.dockClearance`, rather than by a `.safeAreaInset` on the
        // TabView itself.
        //
        // That inset looked correct — the dock sat in the right place — but a
        // TabView manages its children's safe areas itself and does not pass an
        // inset applied to it down into them. So every tab laid out as if the
        // dock weren't there: scrolling to the very bottom still left the last
        // card behind it, with no way to reach it. The clearance has to be
        // applied to each tab's own hierarchy for its ScrollView to see it.
        .overlay(alignment: .bottom) {
            floatingDock
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: DockHeightKey.self,
                            value: geo.size.height
                        )
                    }
                )
        }
        .onPreferenceChange(DockHeightKey.self) { dockHeight = $0 }
        .onChange(of: purchases.isPro) { wasPro, isPro in
            guard isPro, !wasPro else { return }
            guard !UserDefaults.standard.bool(forKey: Self.hasSeenProWelcomeKey) else { return }
            UserDefaults.standard.set(true, forKey: Self.hasSeenProWelcomeKey)
            // A beat after the paywall's own dismiss animation finishes,
            // rather than two sheets fighting to present at once.
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                showProWelcome = true
            }
        }
        .sheet(isPresented: $showProWelcome) {
            ProWelcomeView()
        }
    }

    // MARK: - Floating Dock

    private var floatingDock: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
#if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 25, weight: .medium))
                            .frame(width: 32, height: 28)

                        // 11pt is the platform floor for legible text; this sat at
                        // 10. Deliberately NOT scaled with Dynamic Type — tab
                        // titles are the one place the guidance says to hold
                        // size, since growing them pushes the bar into content.
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .rounded))
                    }
                    .foregroundStyle(
                        isSelected ? theme.blue : theme.textSecondary.opacity(0.8)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .transaction { $0.animation = nil }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(
            // LEVEL 4 of the surface ladder. The dock used to be the *same
            // colour* as the cards it floats over — pure white on pure white in
            // day mode — and read as separate only because of its shadow. It is
            // now the single brightest surface in day mode and a distinct step
            // above the card in night mode, with the shadow and the hairline
            // edge as reinforcement rather than as the whole separation.
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(theme.navigationSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(theme.navigationEdge, lineWidth: 1)
                )
                .shadow(
                    color: theme.navigationShadow,
                    radius: 24,
                    x: 0,
                    y: 10
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }
}

// MARK: - Dock Measurement

private struct DockHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    /// Reserves the dock's height at the bottom of this view's safe area, so the
    /// scroll views inside it can be scrolled clear of the dock instead of
    /// ending underneath it.
    func dockClearance(_ height: CGFloat) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: height)
        }
    }
}

#if DEBUG
#Preview {

    MainTabView()
        .environment(previewChildStore)
        .environment(PurchaseManager())
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
#endif
