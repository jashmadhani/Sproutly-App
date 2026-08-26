//
//  ProLockBadge.swift
//  Sproutly
//

import SwiftUI

// MARK: - Pro Lock Badge

/// The one mark that says "this is Sproutly Pro".
///
/// There were five treatments before this: a 19pt gold lock on the report card,
/// a caption2 gold lock in Settings, a caption2 *blue* lock on "Add moment", a
/// footnote grey lock on the photo button, and a gold "Pro" text capsule on the
/// App Icon row. Three sizes and three colours for one meaning, which reads as
/// five unrelated states rather than one.
///
/// Gold is reserved for Pro across the app — the same `proGold` as the Pro
/// Features star — so the colour alone carries the meaning and the size stays
/// put next to whatever label it trails.
struct ProLockBadge: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        Image(systemName: "lock.fill")
            .font(Theme.sproutlyMeta.weight(.semibold))
            .foregroundStyle(theme.proGoldText)
            // The row or button around it already says what the feature is;
            // this only has to say that it's locked.
            .accessibilityLabel("Sproutly Pro")
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 8) {
        Text("Add a child")
        ProLockBadge()
    }
    .environment(ThemeManager())
}
#endif
