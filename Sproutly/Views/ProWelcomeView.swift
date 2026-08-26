//
//  ProWelcomeView.swift
//  Sproutly
//

import SwiftUI

// Shown exactly once, the first time isPro flips true (purchase or restore —
// see the trigger in MainTabView). Not a sales screen, nothing to buy here;
// just the answer to "okay, what did I just unlock and where do I use it."
struct ProWelcomeView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AmbientBackground(nightMode: theme.isNightMode)

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 20)

                    Image("SproutMarkPro")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(theme.proGoldGradient, lineWidth: 2.5)
                        )
                        .shadow(color: theme.proGold.opacity(0.28), radius: 10, y: 4)

                    VStack(spacing: 8) {
                        Text("You're all set!")
                            .font(.sproutlyDisplay(30))
                            .foregroundStyle(theme.text)

                        Text("Sproutly Pro is unlocked. Here is what it adds.")
                            .font(Theme.sproutlyBody)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.textSecondary)
                    }

                    ProFeatureListView()
                        .warmCard(nightMode: theme.isNightMode)

                    // Tells a parent exactly where to come back to this list —
                    // otherwise this sheet is the only place they ever see it.
                    Text("Find this again in Settings, under Pro Features.")
                        .font(Theme.sproutlyMeta)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        dismiss()
                    } label: {
                        Text("Got it")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftCapsuleStyle(baseColor: theme.blue, isAction: true, nightMode: theme.isNightMode))

                    Spacer(minLength: 12)
                }
                .padding(24)
            }
        }
    }
}

#if DEBUG
#Preview {
    ProWelcomeView()
        .environment(ThemeManager())
}
#endif
