//
//  OneTapLogButton.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/02/26.
//

import SwiftUI


struct OneTapLogButton: View {
    var isCompleted: Bool
    var nightMode: Bool = false
    var accessibilityTitle: String = ""
    var action: () -> Void

    var body: some View {
        Button {
#if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        isCompleted
                            ? Theme.growthGreen(for: nightMode)
                            : Theme.accentBlue(for: nightMode).opacity(0.12)
                    )
                    .frame(width: 36, height: 36)

                Circle()
                    .stroke(
                        Theme.accentBlue(for: nightMode).opacity(isCompleted ? 0 : 0.3),
                        lineWidth: 1.5
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: isCompleted ? "checkmark" : "plus")
                    .sproutlyScaledFont(14, relativeTo: .footnote, weight: .semibold)
                    .foregroundStyle(
                        isCompleted ? .white : Theme.accentBlueText(for: nightMode)
                    )
            }
            .animation(.easeOut(duration: 0.15), value: isCompleted)
            // The circle stays 36pt visually — 44 would crowd the milestone row —
            // but the tap target is padded out to the 44x44 the HIG asks for.
            // This is the most-repeated control in the app, so it should be the
            // most forgiving one to hit, not the tightest.
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // Mirrors the visible mental model: the parent saves what they notice,
        // rather than marking items complete on a checklist. VoiceOver already
        // announces the double-tap mechanic, so the hint describes the result.
        .accessibilityLabel(
            accessibilityTitle.isEmpty
                ? (isCompleted ? "Saved" : "Save")
                : (isCompleted ? "Saved: \(accessibilityTitle)" : "Save: \(accessibilityTitle)")
        )
        .accessibilityHint(isCompleted ? "Removes it from what you've saved" : "Saves it to what you've noticed")
        .accessibilityAddTraits(.isButton)
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color(hex: 0xFAF8F4).ignoresSafeArea()
        
        HStack(spacing: 30) {
            OneTapLogButton(isCompleted: false, action: {})
            OneTapLogButton(isCompleted: true, action: {})
        }
    }
}
#endif
