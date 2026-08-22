//
//  ChildAvatar.swift
//  Sproutly
//

import SwiftUI

// Small initial-in-a-circle used by the switcher and the dashboard header.
struct ChildAvatar: View {
    let child: Child
    var isActive: Bool = true
    var size: CGFloat = 36
    var nightMode: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accentBlue(for: nightMode).opacity(isActive ? 0.18 : 0.08))
                .frame(width: size, height: size)

            Text(child.initial)
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    Theme.accentBlueText(for: nightMode).opacity(isActive ? 1 : 0.5)
                )
        }
        .accessibilityHidden(true)
    }
}
