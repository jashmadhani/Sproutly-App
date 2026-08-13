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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        isCompleted ? .white : Theme.accentBlue(for: nightMode)
                    )
            }
            .animation(.easeOut(duration: 0.15), value: isCompleted)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            accessibilityTitle.isEmpty
                ? (isCompleted ? "Completed" : "Mark as complete")
                : (isCompleted ? "Unmark \(accessibilityTitle) as complete" : "Mark \(accessibilityTitle) as complete")
        )
        .accessibilityHint(isCompleted ? "Double tap to unmark" : "Double tap to mark complete")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    ZStack {
        Color(hex: 0xFAF8F4).ignoresSafeArea()
        
        HStack(spacing: 30) {
            OneTapLogButton(isCompleted: false, action: {})
            OneTapLogButton(isCompleted: true, action: {})
        }
    }
}
