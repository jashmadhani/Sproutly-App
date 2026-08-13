//
//  Theme.swift
//  Sproutly
//
//  Created by Jash Madhani on 07/02/26.
//

import SwiftUI

// MARK: - Theme


enum Theme {
    
    // MARK: - Day Mode Palette
    
    /// Warm off-white background — #FAF8F4
    static let dayBg = Color(hex: 0xFAF8F4)
    
    /// Pure white card background — #FFFFFF
    static let dayCard = Color.white
    
    /// Deep slate primary text — #2F3A3F
    static let dayText = Color(hex: 0x2F3A3F)
    
    /// Muted gray-blue secondary text — #6B7C85
    static let dayTextSecondary = Color(hex: 0x6B7C85)
    
    /// Soft warm sky blue accent — #6FAED9
    static let dayBlue = Color(hex: 0x6FAED9)
    
    /// Muted sage growth green — #8DBF9F
    static let dayGreen = Color(hex: 0x8DBF9F)
    
    /// Gentle butter encouragement yellow — #F4DFA5
    static let dayYellow = Color(hex: 0xF4DFA5)
    
    // MARK: - Night Mode Palette (Nursery-Inspired)
    
    /// Deep navy background — #1C2733
    static let nightBg = Color(hex: 0x1C2733)
    
    /// Slightly lighter card background — #243445
    static let nightCard = Color(hex: 0x243445)
    
    /// Soft off-white primary text — #E6EEF3
    static let nightText = Color(hex: 0xE6EEF3)
    
    /// Muted secondary text — #A9BDC8
    static let nightTextSecondary = Color(hex: 0xA9BDC8)
    
    /// Night sky blue accent — #7FC4E8
    static let nightBlue = Color(hex: 0x7FC4E8)
    
    /// Muted sage green — #7FBFA2
    static let nightGreen = Color(hex: 0x7FBFA2)
    
    /// Warm golden accent — #E6C977
    static let nightGold = Color(hex: 0xE6C977)
    
    // MARK: - Resolved Semantic Colors
    // These resolve dynamically based on night mode state.
    
    static func background(for nightMode: Bool) -> Color {
        nightMode ? nightBg : dayBg
    }
    
    static func cardBackground(for nightMode: Bool) -> Color {
        nightMode ? nightCard : dayCard
    }
    
    static func textPrimary(for nightMode: Bool) -> Color {
        nightMode ? nightText : dayText
    }
    
    static func textSecondary(for nightMode: Bool) -> Color {
        nightMode ? nightTextSecondary : dayTextSecondary
    }
    
    static func accentBlue(for nightMode: Bool) -> Color {
        nightMode ? nightBlue : dayBlue
    }
    
    static func growthGreen(for nightMode: Bool) -> Color {
        nightMode ? nightGreen : dayGreen
    }
    
    static func encourageYellow(for nightMode: Bool) -> Color {
        nightMode ? nightGold : dayYellow
    }
    
    // MARK: - Static Aliases (Day Mode defaults for convenience)
    
    static let accentBlue = dayBlue
    static let growthGreen = dayGreen
    static let encourageYellow = dayYellow
    
    // MARK: - Domain Colors
    
    /// Gross Motor — Soft blue
    static func grossMotorColor(for nightMode: Bool) -> Color {
        accentBlue(for: nightMode)
    }
    
    /// Fine Motor — Warm amber
    static func fineMotorColor(for nightMode: Bool) -> Color {
        nightMode ? Color(hex: 0xD4B87B) : Color(hex: 0xC4A86B)
    }
    
    /// Language — Warm teal
    static func languageColor(for nightMode: Bool) -> Color {
        nightMode ? Color(hex: 0x8FC4B8) : Color(hex: 0x6BA8A0)
    }
    
    /// Cognitive — Muted lavender
    static func cognitiveColor(for nightMode: Bool) -> Color {
        nightMode ? Color(hex: 0xB0A8D0) : Color(hex: 0x9890B8)
    }
    
    /// Social-Emotional — Warm rose
    static func socialEmotionalColor(for nightMode: Bool) -> Color {
        nightMode ? Color(hex: 0xD4A0A0) : Color(hex: 0xC48888)
    }
    
    // MARK: - Ring Gradient
    

    static func ringGradient(for nightMode: Bool) -> AngularGradient {
        AngularGradient(
            colors: [
                accentBlue(for: nightMode),
                growthGreen(for: nightMode),
                accentBlue(for: nightMode)
            ],
            center: .center
        )
    }
    
    // MARK: - Layout Constants
    
    static let cardCornerRadius: CGFloat = 24
    static let padding: CGFloat = 16
    static let largePadding: CGFloat = 24
    
    // MARK: - Celebration Microcopy
    
    static let celebrationMessages: [String] = [
        "You noticed something wonderful today ✨",
        "Growth is happening 🌱",
        "A beautiful moment, captured 💛",
        "Every little step matters 🌿",
        "What a gentle discovery ✨"
    ]
    
    static func randomCelebration() -> String {
        celebrationMessages.randomElement() ?? celebrationMessages[0]
    }
    
    // MARK: - Late Milestone Messaging
    
    static func lateMilestoneMessage(ageMonth: Int) -> String {
        let rangeStart = max(0, ageMonth - 1)
        let rangeEnd = ageMonth + 2
        return "Most children explore this skill between \(rangeStart)–\(rangeEnd) months. If you haven't noticed it yet, that's okay. Here are a few gentle activities you can try."
    }
    
    static let pediatricianReassurance = "If you're ever unsure, your pediatrician can offer reassurance."
}

// MARK: - Color Hex Initializer

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Theme-Aware Card Modifier

extension View {

    func warmCard(nightMode: Bool) -> some View {
        self
            .padding(20)
            .background(Theme.cardBackground(for: nightMode))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
            .shadow(
                color: nightMode
                    ? Color.black.opacity(0.25)
                    : Theme.dayText.opacity(0.05),
                radius: nightMode ? 6 : 10,
                x: 0,
                y: nightMode ? 3 : 4
            )
    }
    

    func natureCard() -> some View {
        self.warmCard(nightMode: false)
    }
}

// MARK: - Gradient Button Style


struct SoftCapsuleStyle: ButtonStyle {
    var baseColor: Color
    var isAction: Bool = false
    var nightMode: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(minHeight: 50)
            .background(
                Capsule()
                    .fill(
                        isAction
                            ? AnyShapeStyle(baseColor)
                            : AnyShapeStyle(
                                nightMode
                                    ? Color.white.opacity(0.08)
                                    : Theme.dayText.opacity(0.06)
                            )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        isAction
                            ? Color.clear
                            : (nightMode ? Color.white.opacity(0.1) : Theme.dayText.opacity(0.08)),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Ambient Background

struct AmbientBackground: View {
    let nightMode: Bool

    var body: some View {
        ZStack {

            Theme.background(for: nightMode)
                .ignoresSafeArea()


            Circle()
                .fill(Theme.accentBlue(for: nightMode).opacity(nightMode ? 0.04 : 0.07))
                .frame(width: 400, height: 400)
                .offset(x: -115, y: -200)


            Circle()
                .fill(Theme.growthGreen(for: nightMode).opacity(nightMode ? 0.03 : 0.06))
                .frame(width: 420, height: 420)
                .offset(x: 125, y: 225)


            Circle()
                .fill(Theme.encourageYellow(for: nightMode).opacity(nightMode ? 0.02 : 0.05))
                .frame(width: 300, height: 300)
                .offset(x: 75, y: -10)
        }
        .ignoresSafeArea()
    }
}
