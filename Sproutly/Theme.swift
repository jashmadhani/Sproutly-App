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

    // MARK: - Motion
    //
    // Reduce Motion is a system setting a parent turns on because springs make
    // them queasy or disoriented, so honouring it in one screen and not the rest
    // is worse than not honouring it at all. Every spring in the app routes
    // through here. `nil` rather than a faster spring: the setting asks for the
    // movement to be removed, not hurried — the view still changes, it just
    // arrives instead of travelling. Fades are left alone; they carry no motion.

    static func spring(
        _ response: Double,
        damping: Double = 0.85,
        reduceMotion: Bool
    ) -> Animation? {
        reduceMotion ? nil : .spring(response: response, dampingFraction: damping)
    }

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

    /// Large numeric stat — the milestone-ring count. Exposed as the
    /// `.sproutlyStatNumber()` view modifier rather than a `Font` constant,
    /// because `.system(size:)` produces a fixed font that ignores the reader's
    /// text-size setting entirely. See `ScaledSystemFont`.

    /// Label directly under a large stat — "of 10 milestones".
    static let sproutlyStatLabel: Font = .system(.body).weight(.medium)

    /// Icon size for row-trailing affordance icons (share, chevron) that must
    /// read clearly at a glance, not just meet the 44pt tap target. Exposed as
    /// the `.sproutlyRowIcon()` view modifier — see `sproutlyStatNumber`.

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

    /// Soft warm sky blue accent — #6FAED9. A *surface* colour: tinted fills,
    /// icon backdrops, ring strokes. Measured against the two backgrounds it
    /// actually sits on it lands at 2.40:1 on the white card and 2.07:1 on the
    /// sage background — roughly half of WCAG AA's 4.5:1 — so it must never
    /// carry text or a UI-scale icon. Use `dayBlueText` for those.
    static let dayBlue = Color(hex: 0x6FAED9)

    /// Text-weight blue — #2F6E96. Same hue family as `dayBlue`, darkened until
    /// it clears AA on both surfaces: 5.54:1 on the white card, 4.76:1 on the
    /// sage background. Everything a parent reads or taps as text uses this;
    /// large decorative glyphs sitting on a `dayBlue` tinted circle stay on
    /// `dayBlue`, since decoration paired with a real text label is exempt.
    static let dayBlueText = Color(hex: 0x2F6E96)

    /// Leaf green — #6FA37A. Surface colour, like `dayBlue`: 2.92:1 on the white
    /// card, so it fills and tints but never carries text or a read glyph.
    static let dayGreen = Color(hex: 0x6FA37A)

    /// Text-weight green — #3F7050. 5.76:1 on the white card, 4.95:1 on sage.
    static let dayGreenText = Color(hex: 0x3F7050)

    /// Gentle butter encouragement yellow — #F4DFA5. The most surface-only of the
    /// three: at 1.32:1 on white it is barely distinguishable from the card it
    /// sits on, which is exactly what it's for as a soft highlight fill — and
    /// exactly why it can't be a text colour.
    static let dayYellow = Color(hex: 0xF4DFA5)

    /// Text-weight amber — #7D5F18. 5.96:1 on the white card, 5.12:1 on sage.
    /// The same "gentle warning" role as `dayYellow`, dark enough to read.
    static let dayYellowText = Color(hex: 0x7D5F18)
    
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

    /// The accent as used on text and UI-scale icons. Night mode needs no
    /// separate value — `nightBlue` already measures 6.64:1 on `nightCard` —
    /// so only the day side changes.
    static func accentBlueText(for nightMode: Bool) -> Color {
        nightMode ? nightBlue : dayBlueText
    }

    // MARK: - Purchase CTA
    //
    // The sage greens above are surface colours — white text on dayGreen lands at
    // about 2.1:1, well under the 4.5:1 WCAG AA needs, which is why the paywall
    // button reads as washed out rather than as a thing you press. These are the
    // only greens tuned to carry white text, so they belong to the purchase CTA
    // and nothing else. Deliberately kept out of the sage family's naming so they
    // don't get reached for as a general accent.

    /// Top stop of the unlock button gradient — #4A7A5C. Softened from the
    /// original #43815F/#2E5F44 pair, which read as a saturated "jewelry
    /// store" green sitting next to the gold mark — same purpose, quieter.
    static let ctaGreenTop = Color(hex: 0x4A7A5C)

    /// Bottom stop — #355F45. Darker, so the fill reads as lit from above.
    static let ctaGreenBottom = Color(hex: 0x355F45)

    static let ctaGreenTopNight = Color(hex: 0x4A9370)
    static let ctaGreenBottomNight = Color(hex: 0x3A7058)

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

    /// Muted bronze for day mode — #B8935A. Softened from the original
    /// #C9982F, which read as bright/high-chroma gold against the sage
    /// background rather than a quiet "this is special" cue.
    static let proGoldDay = Color(hex: 0xB8935A)

    /// Softened from the original nightGold #E6C977 to match the day
    /// bronze's lower saturation.
    static let proGoldNight = Color(hex: 0xD4B876)

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

    /// Green as used on text and read glyphs. Night needs no separate value —
    /// `nightGreen` measures 5.98:1 on `nightCard`.
    static func growthGreenText(for nightMode: Bool) -> Color {
        nightMode ? nightGreen : dayGreenText
    }

    /// Amber as used on text. `nightGold` already measures 7.86:1 on `nightCard`.
    static func encourageYellowText(for nightMode: Bool) -> Color {
        nightMode ? nightGold : dayYellowText
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

    /// Space between independent top-level cards/sections — Home's card
    /// stack, Settings' cards, Milestones' domain cards. Every full-width
    /// bento block on any screen is this far from its neighbor, full stop.
    static let sectionSpacing: CGFloat = 28

    /// Space between closely-grouped sub-items living *inside* one card —
    /// the Growth Domains tiles, rows inside a domain card, Recent Moments
    /// rows. Tighter than sectionSpacing on purpose: these read as one group,
    /// not as separate cards.
    static let itemSpacing: CGFloat = 12
    
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

// MARK: - Scalable System Font

/// A system font at a custom point size that still honours the reader's
/// text-size setting.
///
/// `Font.system(size:)` is frozen — it ignores Dynamic Type completely, so a
/// parent who has turned text up sees every other label grow while these stay
/// put, which breaks the hierarchy exactly where it matters most. `@ScaledMetric`
/// scales the point size against a named text style, and it works inside a
/// `ViewModifier` the same as in a `View`, so the scaling lives here instead of
/// being re-declared at every call site.
struct ScaledSystemFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    /// A system font at `size` that grows with the reader's text-size setting.
    func sproutlyScaledFont(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(ScaledSystemFont(
            size: size, relativeTo: textStyle, weight: weight, design: design
        ))
    }

    /// Large numeric stat — the milestone-ring count.
    func sproutlyStatNumber() -> some View {
        sproutlyScaledFont(40, relativeTo: .largeTitle, weight: .bold, design: .rounded)
    }

    /// Row-trailing affordance icons (share, chevron).
    func sproutlyRowIcon() -> some View {
        sproutlyScaledFont(20, relativeTo: .body, weight: .semibold)
    }
}

// MARK: - Gradient Button Style


struct SoftCapsuleStyle: ButtonStyle {
    var baseColor: Color
    var isAction: Bool = false
    var nightMode: Bool = false

    // A ButtonStyle reads the environment like any other view, so the press
    // spring can be gated here rather than at every call site.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
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
            .animation(Theme.spring(0.2, damping: 0.7, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

// MARK: - Ambient Background

struct AmbientBackground: View {
    let nightMode: Bool

    var body: some View {
        // Positions and sizes are fractions of the actual screen, computed via
        // GeometryReader, not fixed point offsets. The previous version was
        // tuned by eye against one simulator width — on a physically wider or
        // narrower iPhone (SE through Pro Max all ship in this app's supported
        // range), the same fixed offsets leave a different amount of flat,
        // un-shaded background on each side, which reads as asymmetric padding
        // even though every actual content .padding() is untouched and
        // symmetric. Scaling with geo.size fixes that regardless of device.
        GeometryReader { geo in
            ZStack {
                Theme.background(for: nightMode)

                // Blurred rather than flat-edged — at full opacity+sharp edges
                // these read as three overlapping discs with visible seams
                // where they cross; blurring dissolves that into soft ambient
                // glow while keeping the same playful multi-color concept.
                Circle()
                    .fill(Theme.accentBlue(for: nightMode).opacity(nightMode ? 0.05 : 0.09))
                    .frame(width: geo.size.width * 1.02, height: geo.size.width * 1.02)
                    .position(x: geo.size.width * 0.207, y: geo.size.height * 0.265)
                    .blur(radius: 70)

                Circle()
                    .fill(Theme.growthGreen(for: nightMode).opacity(nightMode ? 0.04 : 0.08))
                    .frame(width: geo.size.width * 1.07, height: geo.size.width * 1.07)
                    .position(x: geo.size.width * 0.818, y: geo.size.height * 0.764)
                    .blur(radius: 70)

                Circle()
                    .fill(Theme.encourageYellow(for: nightMode).opacity(nightMode ? 0.03 : 0.07))
                    .frame(width: geo.size.width * 0.76, height: geo.size.width * 0.76)
                    .position(x: geo.size.width * 0.691, y: geo.size.height * 0.488)
                    .blur(radius: 70)
            }
        }
        .ignoresSafeArea()
    }
}
