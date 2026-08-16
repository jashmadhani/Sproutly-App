//
//  ProFeatureListView.swift
//  Sproutly
//

import SwiftUI

// Shared between PaywallView (with a buy button below) and ProFeaturesView
// (a plain reference screen for people who already own Pro) — one list of
// what Pro includes, so the two screens can never drift out of sync.
struct ProFeatureListView: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(PaywallReason.allFeatures, id: \.title) { feature in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 17))
                        .foregroundStyle(theme.blue)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.title)
                            .font(Theme.sproutlyCardTitle)
                            .foregroundStyle(theme.text)
                        Text(feature.detail)
                            .font(Theme.sproutlyMeta)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
