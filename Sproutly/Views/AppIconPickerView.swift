//
//  AppIconPickerView.swift
//  Sproutly
//

import SwiftUI

// Pro feature. Unlike the other gates this one has no free tier at all — there
// is nothing partially useful about half an icon set — so the whole screen is
// reachable only once isPro is true; SettingsView shows the paywall instead.
struct AppIconPickerView: View {

    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var icons = AppIconManager()

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground(nightMode: theme.isNightMode)

                if icons.isSupported {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(AppIconOption.allCases) { option in
                                row(for: option)
                            }

                            if let error = icons.lastError {
                                Text(error)
                                    .font(Theme.sproutlyMeta)
                                    .foregroundStyle(.red.opacity(0.8))
                                    .padding(.top, 4)
                            }

                            Text("Your icon changes on the Home Screen right away.")
                                .font(Theme.sproutlyMeta)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(theme.textSecondary)
                                .padding(.top, 8)
                        }
                        .padding(20)
                    }
                } else {
                    Text("This device doesn't support changing the app icon.")
                        .font(Theme.sproutlyBody)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.textSecondary)
                        .padding(32)
                }
            }
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.blueText)
                }
            }
        }
    }

    private func row(for option: AppIconOption) -> some View {
        let isSelected = icons.current == option

        return Button {
            Task { await icons.select(option) }
        } label: {
            HStack(spacing: 14) {
                Image(option.previewAssetName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(theme.text)
                    Text(option.subtitle)
                        .font(Theme.sproutlyMeta)
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(isSelected ? theme.green : theme.textSecondary.opacity(0.4))
            }
            .padding(14)
            .warmCard(nightMode: theme.isNightMode)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityHint(option.subtitle)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
