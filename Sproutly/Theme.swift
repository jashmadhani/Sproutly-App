//
//  Theme.swift
//  Sproutly
//
//  Created by Jash Madhani on 07/02/26.
//

import SwiftUI
import CoreText

// MARK: - Custom Fonts

enum SproutlyFont {
    /// Registers the bundled Fraunces weights with CoreText. Idempotent —
    /// CTFontManagerRegisterFontsForURL no-ops (with a benign "already
    /// registered" error we ignore) if called more than once.
    static let didRegister: Bool = {
        for name in ["Fraunces-Regular", "Fraunces-SemiBold", "Fraunces-Bold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()
}

extension Font {
    /// Large serif display heading — screen titles, the child's name on Home.
    /// Scales with Dynamic Type via `relativeTo`.
    static func sproutlyDisplay(_ size: CGFloat = 30, weight: Font.Weight = .bold) -> Font {
        _ = SproutlyFont.didRegister
        let psName = weight == .semibold ? "SproutlyFraunces-SemiBold" : "SproutlyFraunces-Bold"
        return .custom(psName, size: size, relativeTo: .title)
    }

    /// Compact serif heading — sticky/collapsed headers.
    static func sproutlyCompactHeading(_ size: CGFloat = 17) -> Font {
        _ = SproutlyFont.didRegister
        return .custom("SproutlyFraunces-SemiBold", size: size, relativeTo: .headline)
    }

}

// MARK: - Theme


enum Theme {

    // MARK: - Type Scale
    //
    // A fixed set of roles so every screen draws from the same ramp instead of
    // picking .callout/.subheadline/.caption ad hoc per call site. Card titles
    // are deliberately NOT paired with .minimumScaleFactor by convention —
    // shrinking silently makes same-role text render at different sizes
    // depending on string length, which is what made the domain tiles look
    // inconsistent despite sharing one font declaration.

    /// Section headers — "Growth Domains", "Recent Moments", "Growth Insights".
    /// Default (non-rounded) design — rounded read as oversized/soft at this weight.
    static let sproutlySectionHeader: Font = .system(.title3).weight(.bold)

    /// Card/row titles — domain tile labels, insight row titles, action-row
    /// titles like "Report for your visit". The dominant title in a card that
    /// has no items nested inside it.
    static let sproutlyCardTitle: Font = .system(.body).weight(.semibold)

    /// Item titles — one step below sproutlyCardTitle, for rows that live
    /// *inside* a card/section that already has its own cardTitle (e.g. a
    /// milestone row inside a domain section). Keeps a visible step between
    /// "this is the section" and "this is a thing in the section."
    static let sproutlyItemTitle: Font = .system(.subheadline).weight(.medium)

    /// Body copy meant to actually be read — insight paragraphs, subtitles under a heading,
    /// action-row descriptions.
    static let sproutlyBody: Font = .system(.subheadline)

    /// Meta text — dates, counts. Never primary reading content.
    static let sproutlyMeta: Font = .system(.footnote)

    /// Large numeric stat — the milestone-ring count.
    static let sproutlyStatNumber: Font = .system(size: 40, weight: .bold, design: .rounded)

    /// Label directly under a large stat — "of 10 milestones".
    static let sproutlyStatLabel: Font = .system(.body).weight(.medium)

    /// Icon size for row-trailing affordance icons (share, chevron) that must
    /// read clearly at a glance, not just meet the 44pt tap target.
    static let sproutlyRowIcon: Font = .system(size: 20, weight: .semibold)

    // MARK: - Day Mode Palette (Sage & Espresso)

    /// Soft sage background — #E9F0E4
    static let dayBg = Color(hex: 0xE9F0E4)

    /// Pure white card background — #FFFFFF
    static let dayCard = Color.white

    /// Espresso brown primary text — #3B2A20
    static let dayText = Color(hex: 0x3B2A20)

    /// Warm taupe secondary text — #5F4F42. Darkened from the original #7A6A5C,
    /// which landed at ~4.46:1 on the sage background — just under WCAG AA's
    /// 4.5:1 for normal text. This clears it with margin (~6.7:1).
    static let dayTextSecondary = Color(hex: 0x5F4F42)

    /// Soft warm sky blue accent — #6FAED9
    static let dayBlue = Color(hex: 0x6FAED9)

    /// Leaf green — #6FA37A
    static let dayGreen = Color(hex: 0x6FA37A)
    
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

    // MARK: - Purchase CTA
    //
    // The sage greens above are surface colours — white text on dayGreen lands at
    // about 2.1:1, well under the 4.5:1 WCAG AA needs, which is why the paywall
    // button reads as washed out rather than as a thing you press. These are the
    // only greens tuned to carry white text, so they belong to the purchase CTA
    // and nothing else. Deliberately kept out of the sage family's naming so they
    // don't get reached for as a general accent.

    /// Top stop of the unlock button gradient — #43815F, ~4.6:1 with white.
    static let ctaGreenTop = Color(hex: 0x43815F)

    /// Bottom stop — #2E5F44. Darker, so the fill reads as lit from above.
    static let ctaGreenBottom = Color(hex: 0x2E5F44)

    static let ctaGreenTopNight = Color(hex: 0x3E8F6A)
    static let ctaGreenBottomNight = Color(hex: 0x2C6B50)

    static func ctaGradient(for nightMode: Bool) -> LinearGradient {
        LinearGradient(
            colors: nightMode
                ? [ctaGreenTopNight, ctaGreenBottomNight]
                : [ctaGreenTop, ctaGreenBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Tinted rather than black, so the shadow reads as the button's own colour
    /// sitting above the card instead of a grey smudge under it.
    static func ctaShadow(for nightMode: Bool) -> Color {
        (nightMode ? ctaGreenBottomNight : ctaGreenBottom).opacity(nightMode ? 0.5 : 0.35)
    }

    // MARK: - Pro accent (gold)
    //
    // Gold appears ONLY on the paywall. Blue is the everyday accent — it sits on
    // every free feature row — so using it for Pro makes the upgrade read as more
    // of the same screen. Warm gold against the cool sage palette is a temperature
    // contrast, which is what actually reads as "valuable". The day value is
    // deliberately deeper than the night one: light gold on the cream background
    // has almost no contrast.

    /// Deep gold for day mode — #B8860B territory, legible on cream.
    static let proGoldDay = Color(hex: 0xC9982F)

    /// The existing nightGold, which already reads well on deep navy.
    static let proGoldNight = nightGold

    static func proGold(for nightMode: Bool) -> Color {
        nightMode ? proGoldNight : proGoldDay
    }

    static func proGoldGradient(for nightMode: Bool) -> LinearGradient {
        let base = proGold(for: nightMode)
        return LinearGradient(
            colors: [base, base.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Soft halo behind the mark. Blurred at the call site, so it reads as light
    /// coming off the icon rather than a hard second ring around it.
    static func proHaloGradient(for nightMode: Bool) -> RadialGradient {
        RadialGradient(
            colors: [proGold(for: nightMode).opacity(nightMode ? 0.34 : 0.22), .clear],
            center: .center,
            startRadius: 2,
            endRadius: 54
        )
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
    
    static let cardCornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 14
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
            .padding(Theme.cardPadding)
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

            // Blurred rather than flat-edged — at full opacity+sharp edges
            // these read as three overlapping discs with visible seams where
            // they cross; blurring dissolves that into soft ambient glow
            // while keeping the same playful multi-color "growing" concept.
            Circle()
                .fill(Theme.accentBlue(for: nightMode).opacity(nightMode ? 0.05 : 0.09))
                .frame(width: 400, height: 400)
                .offset(x: -115, y: -200)
                .blur(radius: 70)

            Circle()
                .fill(Theme.growthGreen(for: nightMode).opacity(nightMode ? 0.04 : 0.08))
                .frame(width: 420, height: 420)
                .offset(x: 125, y: 225)
                .blur(radius: 70)

            Circle()
                .fill(Theme.encourageYellow(for: nightMode).opacity(nightMode ? 0.03 : 0.07))
                .frame(width: 300, height: 300)
                .offset(x: 75, y: -10)
                .blur(radius: 70)
        }
        .ignoresSafeArea()
    }
}
