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
    @State private var selectedTab: Tab = .dashboard

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
        Group {
            switch selectedTab {
            case .dashboard:
                DashboardView()
            case .milestones:
                MilestonesView()
            case .assistant:
                AssistantView()
            case .settings:
                SettingsView()
            }
        }
        .transaction { $0.animation = nil }
        .safeAreaInset(edge: .bottom) {
            floatingDock
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
                    VStack(spacing: 5) {
                        Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 20))
                            .frame(width: 28, height: 24)

                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .rounded))
                    }
                    .foregroundStyle(
                        isSelected ? theme.blue : theme.textSecondary.opacity(0.7)
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
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    theme.isNightMode
                        ? Theme.nightCard.opacity(0.98)
                        : .white.opacity(0.98)
                )
                .shadow(
                    color: theme.isNightMode
                        ? Color.black.opacity(0.5)
                        : Theme.dayText.opacity(0.12),
                    radius: 24,
                    x: 0,
                    y: 10
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }
}

#Preview {
    let profile = ChildProfile()
    profile.birthDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    profile.name = "Preview"
    profile.hasCompletedOnboarding = true

    return MainTabView()
        .environment(profile)
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
