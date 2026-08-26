//
//  ProFeaturesView.swift
//  Sproutly
//

import SwiftUI

// Reachable from Settings once Pro is owned — the answer to "wait, what did
// I actually buy, and where do I use it." Same feature list as the paywall,
// no buy button, since there's nothing left to buy.
struct ProFeaturesView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground(nightMode: theme.isNightMode)

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        ProFeatureListView()
                            .warmCard(nightMode: theme.isNightMode)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Pro Features")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image("SproutMarkPro")
                .resizable()
                .interpolation(.high)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(theme.proGoldGradient, lineWidth: 2)
                )

            Text("You have Sproutly Pro")
                .font(.sproutlyDisplay(24))
                .foregroundStyle(theme.text)

            Text("Here is what it adds, and where to find each one.")
                .font(Theme.sproutlyBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.top, 8)
    }
}

#if DEBUG
#Preview {
    ProFeaturesView()
        .environment(ThemeManager())
}
#endif
