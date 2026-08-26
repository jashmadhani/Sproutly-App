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

    /// Label above a form field — "Name", "What happened?".
    ///
    /// Its own role on purpose. The forms previously labelled fields with
    /// `sproutlyMeta`, the same style used for explanatory sentences and toggle
    /// subtitles, so a label, a paragraph and a caption all rendered identically
    /// at 13pt — with the odd 17pt semibold row title between them. That is what
    /// made the sheets read as unstyled rather than calm. Same size as body copy,
    /// heavier, so the two never collide.
    static let sproutlyFieldLabel: Font = .system(.subheadline).weight(.semibold)

    /// Text the parent types or picks. Full body size — an input is the thing
    /// they are actually looking at, so it should not be smaller than the label
    /// above it.
    static let sproutlyFieldValue: Font = .system(.body)

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

    /// Soft sage background — #DFE9D8.
    ///
    /// LEVEL 0 of the surface ladder. Deepened from #E9F0E4 (same hue 95, same
    /// saturation 29, lightness 92 → 88) because the card above it is already
    /// at white: there was no headroom left to raise L1, so the only way to
    /// separate the two was to lower L0. Card-vs-background goes 1.16:1 →
    /// 1.21:1, and the floating dock, which was *identical* to the cards at
    /// 1.00:1, now clears the background at 1.25:1.
    static let dayBg = Color(hex: 0xDFE9D8)

    /// Warm ivory card background — #FDFBF7.
    ///
    /// LEVEL 1. Was pure white, which made the cards and the floating dock the
    /// same colour — the dock only read as separate because of its shadow, and
    /// under Reduce Transparency or Increase Contrast it had nothing left. Pure
    /// white is now reserved for the dock (see `dayNav`), so "brightest thing on
    /// screen" means one specific thing. Ivory rather than grey keeps the card
    /// on the same warm side as the espresso text.
    static let dayCard = Color(hex: 0xFDFBF7)

    /// LEVEL 4 — the floating tab dock, #FFFFFF. The only pure white surface in
    /// day mode, so it sits above the cards by luminance and not by shadow
    /// alone. The step over the ivory card is small (1.03:1) and deliberately
    /// so: the dock is separated primarily by shape, edge and shadow, and a
    /// dock bright enough to clear 1.2:1 over the cards would read as a glowing
    /// bar. What matters is that it is no longer *equal* to them.
    static let dayNav = Color.white

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

    /// Text-weight blue — #2B648A. Same hue family as `dayBlue`, darkened until
    /// it clears AA: 6.17:1 on the card, 4.81:1 on the background.
    ///
    /// Was #2F6E96. Two things pushed it down. Deepening the sage cost it
    /// 4.76:1 → 4.43:1, under AA — a background change is not free. And the
    /// remaining margin was measured against the flat `dayBg` token, which is
    /// not what ships: `AmbientBackground` lays blurred colour circles over it,
    /// and the darkest point a parent actually sees is #D6E3D8, not #DFE9D8.
    /// These three text accents are now solved against that sampled value.
    /// Everything a parent reads or taps as text uses this; large decorative
    /// glyphs sitting on a `dayBlue` tinted circle stay on `dayBlue`, since
    /// decoration paired with a real text label is exempt.
    static let dayBlueText = Color(hex: 0x2B648A)

    /// Leaf green — #6FA37A. Surface colour, like `dayBlue`: 2.92:1 on the white
    /// card, so it fills and tints but never carries text or a read glyph.
    static let dayGreen = Color(hex: 0x6FA37A)

    /// Text-weight green — #3C694B. 6.13:1 on the card, 4.78:1 on the darkest
    /// rendered background. Solved the same way as `dayBlueText`.
    static let dayGreenText = Color(hex: 0x3C694B)

    /// Gentle butter encouragement yellow — #F4DFA5. The most surface-only of the
    /// three: at 1.32:1 on white it is barely distinguishable from the card it
    /// sits on, which is exactly what it's for as a soft highlight fill — and
    /// exactly why it can't be a text colour.
    static let dayYellow = Color(hex: 0xF4DFA5)

    /// Text-weight amber — #785B17. 6.14:1 on the card, 4.79:1 on the darkest
    /// rendered background. The same soft-warning role as `dayYellow`, dark
    /// enough to read.
    static let dayYellowText = Color(hex: 0x785B17)
    
    // MARK: - Night Mode Palette (Nursery-Inspired)
    
    /// Deep navy background — #1C2733
    static let nightBg = Color(hex: 0x1C2733)
    
    /// Card background — #2A3D50.
    ///
    /// LEVEL 1. Was #243445, only 1.19:1 above the navy background — the same
    /// too-flat ladder as day mode. Now 1.36:1. Off-white text drops from
    /// 10.83:1 to 9.51:1 on it, which is still far past AA.
    static let nightCard = Color(hex: 0x2A3D50)

    /// LEVEL 4 — the floating tab dock, #344B63. 1.24:1 above the night card
    /// and 1.68:1 above the background. Night mode can afford a larger step
    /// than day here because there is real headroom above the card.
    static let nightNav = Color(hex: 0x344B63)
    
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

    // MARK: - Elevation Ladder
    //
    // LEVEL 0 background → LEVEL 1 card → LEVEL 2 tinted tile → LEVEL 4 dock.
    // (LEVEL 3, a card nested inside a card, does not occur in this app; the
    // numbering is kept aligned with the audit so the levels mean the same
    // thing in the code as they do in the notes.)
    //
    // The rule these all follow: a surface is separated from what it sits on by
    // *luminance first*, with shadow and shape as reinforcement. Before this,
    // several surfaces were separated by shadow alone — which disappears the
    // moment a reader turns on Increase Contrast or Reduce Transparency, the
    // two settings most likely to be on for someone who needs the separation
    // most.

    /// The floating tab dock. LEVEL 4 — the top of the ladder.
    /// - Parameter reduceTransparency: when the reader has asked for solid
    ///   surfaces, the dock drops its slight translucency entirely rather than
    ///   letting content ghost through behind it.
    static func navigationSurface(
        for nightMode: Bool,
        reduceTransparency: Bool = false
    ) -> Color {
        let base = nightMode ? nightNav : dayNav
        return reduceTransparency ? base : base.opacity(0.98)
    }

    /// Unfilled portion of a domain tile's progress bar.
    ///
    /// The first attempt here was `textPrimary.opacity(0.12)`, and on the
    /// simulator it reproduced, one level down, the exact bug this pass was
    /// fixing in the tiles themselves: a single alpha over five different tints
    /// composites to five different weights. Measured off the render, the empty
    /// track was 1.23:1 against the blue tile and 1.06:1 against the teal one —
    /// invisible on the teal, so that tile looked like it had no bar at all.
    ///
    /// So the track is not a tint at all: it is the *card* colour. The empty
    /// bar reads as a channel cut through the tile down to the surface below,
    /// which is both a truer description of what it is and, because every tile
    /// was solved to one luminance, automatically identical on all five —
    /// 1.57:1 in day mode, 1.25:1 in night, with no per-hue drift.
    static func progressTrack(
        for nightMode: Bool,
        increaseContrast: Bool = false
    ) -> Color {
        guard increaseContrast else { return cardBackground(for: nightMode) }
        // Cut the channel one plane further: to pure white in day, and all the
        // way down to the background in night, where the headroom is.
        return nightMode ? nightBg : dayNav
    }

    /// A recessed surface: a list row inside a card, a secondary button, a
    /// segmented track, an image placeholder.
    ///
    /// Was `fieldFill` at 0.12 — a weight chosen so a boxed input would read as
    /// an input. Fields no longer have a fill (see `fieldRule`), so that
    /// reasoning is gone and the weight came with real costs: on the Milestones
    /// screen the segmented track sits on the *page* rather than on a card, and
    /// espresso at 0.12 over sage composited to a muddy #C8D0BE that was the
    /// heaviest thing on the screen. At 0.06 a recess reads as a recess and
    /// nothing has to shout — the raised things above it (a card, the selected
    /// segment) carry their own luminance and shadow.
    static func recessedFill(
        for nightMode: Bool,
        increaseContrast: Bool = false
    ) -> Color {
        let alpha: Double = nightMode
            ? (increaseContrast ? 0.18 : 0.10)
            : (increaseContrast ? 0.12 : 0.06)
        return textPrimary(for: nightMode).opacity(alpha)
    }

    /// The fill behind a single milestone row.
    ///
    /// A row sits inside a card that has already paid its own padding, so this
    /// is the second surface in one level of hierarchy — it exists to make rows
    /// read as separate items, not to raise them. Completed rows carry the green
    /// instead, which is what makes a saved row legible at a glance without a
    /// second control.
    ///
    /// Named rather than inlined so the onboarding backfill list and the
    /// Milestones tab cannot drift apart: they are the same row, and a second
    /// copy of these alphas is how they would stop being the same row.
    static func milestoneRowFill(
        for nightMode: Bool,
        isCompleted: Bool = false
    ) -> Color {
        if isCompleted {
            return growthGreen(for: nightMode).opacity(nightMode ? 0.14 : 0.10)
        }
        return textPrimary(for: nightMode).opacity(nightMode ? 0.08 : 0.06)
    }

    /// The soft disc behind a card's leading glyph.
    ///
    /// Named rather than inlined because it appears on every Settings feature
    /// card and on the onboarding hero icons, and those had drifted to three
    /// different alphas of the same blue.
    static func iconHalo(for nightMode: Bool) -> Color {
        accentBlue(for: nightMode).opacity(nightMode ? 0.18 : 0.12)
    }

    /// The rule under a typed field.
    ///
    /// Fields used to be boxes: a tinted fill plus a 1px border. Measured on
    /// device that fill was #E6E2DD, and the *system* placeholder sitting on it
    /// came out at 1.67:1 — invisible. Lightening the fill does not fix that:
    /// at alpha 0.12/0.08/0.06/0.04 the placeholder measures 1.67/1.68/1.69/
    /// 1.71, and even on pure white it is 1.72, because SwiftUI's placeholder is
    /// a translucent grey that composites over whatever is behind it. The fill
    /// was never the fix. So the fill is gone, and the placeholder is ours (see
    /// `fieldPlaceholder`), which puts it at 5.13:1 on the card.
    ///
    /// Resting, this is *exactly* `dividerColor` — the same line as every row
    /// separator in the app. It had its own heavier weight (0.20 against the
    /// card's 0.08) and that was the mistake: at nearly twice the weight of
    /// every other rule, a field underline running the width of a card read as
    /// a line cutting the card in half rather than as one of the app's lines.
    /// A field does not need a heavier resting cue than a list row — it already
    /// carries a label above it and a placeholder inside it.
    ///
    /// Focused is where the boundary genuinely has to be unambiguous, and that
    /// is a state rather than decoration: the accent at 2pt, 5.75:1.
    static func fieldRule(
        for nightMode: Bool,
        isFocused: Bool = false,
        increaseContrast: Bool = false
    ) -> Color {
        if isFocused { return accentBlueText(for: nightMode) }
        return dividerColor(for: nightMode, increaseContrast: increaseContrast)
    }

    /// Placeholder text inside a field.
    ///
    /// Never the system placeholder. `textSecondary` is already tuned to clear
    /// AA on both the card and the background, so a placeholder reads as real
    /// text a parent can see rather than as a smudge.
    static func fieldPlaceholder(for nightMode: Bool) -> Color {
        // 0.85, not the 0.65 this started at. At 0.65 it measured 3.22:1 on the
        // card — a big gain on the system placeholder's 1.67, but still under
        // AA, and a placeholder is text a parent has to read to know what the
        // field wants. 0.85 gives 5.13:1 in day and 4.64:1 in night while
        // staying clearly lighter than a real value (13.2:1), so a hint still
        // reads as a hint and not as content already entered.
        textSecondary(for: nightMode).opacity(0.85)
    }

    /// OFF track of a switch. Warm, so it belongs to the ivory/sage family
    /// rather than to UIKit's neutral grey. Deliberately a touch heavier than
    /// `recessedFill` — a switch is a control whose off state has to be legible as
    /// a state, not just as a recess.
    static func toggleOffTrack(
        for nightMode: Bool,
        increaseContrast: Bool = false
    ) -> Color {
        let alpha: Double = nightMode
            ? (increaseContrast ? 0.34 : 0.22)
            : (increaseContrast ? 0.32 : 0.20)
        return textPrimary(for: nightMode).opacity(alpha)
    }

    /// The card shadow, as a colour. Reinforcement for the luminance step, not
    /// a substitute for it — before this pass, several surfaces had a shadow
    /// and no step at all.
    static func cardShadow(for nightMode: Bool) -> Color {
        nightMode ? Color.black.opacity(0.25) : dayText.opacity(0.05)
    }

    /// The dock's shadow. Deeper than a card's, because the dock floats over
    /// scrolling content rather than resting in it.
    static func navigationShadow(for nightMode: Bool) -> Color {
        nightMode ? Color.black.opacity(0.5) : dayText.opacity(0.16)
    }

    /// Hairline along the dock's top edge. The dock's step over the cards is
    /// intentionally small, so it gets the one border in the app — on the one
    /// surface that most needs to declare where it begins.
    static func navigationEdge(
        for nightMode: Bool,
        increaseContrast: Bool = false
    ) -> Color {
        let alpha: Double = nightMode
            ? (increaseContrast ? 0.28 : 0.14)
            : (increaseContrast ? 0.22 : 0.10)
        return textPrimary(for: nightMode).opacity(alpha)
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

    /// Gold that survives being read, rather than being a surface.
    ///
    /// Same split as `accentBlue` / `accentBlueText`, and for the same reason:
    /// measured on a render, the day bronze `#B8935A` is **2.76:1 on the card
    /// and 2.15:1 on the background** — below even the 3:1 WCAG asks of a
    /// meaningful non-text glyph, let alone the 4.5:1 for text. Every lock
    /// badge and Pro star was drawn in it.
    ///
    /// `#7C5E24` is the first step down the ramp that clears AA on both: 5.83:1
    /// on the card, 4.55:1 against `#D6E3D8` (the darkest point the ambient
    /// background produces). The night gold already measures 5.80:1 on
    /// `nightCard`, so it is unchanged.
    ///
    /// `proGold` itself stays for fills and gradients, where it is a surface
    /// and the contrast rule does not apply.
    static let proGoldTextDay = Color(hex: 0x7C5E24)

    static func proGoldText(for nightMode: Bool) -> Color {
        nightMode ? proGoldNight : proGoldTextDay
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

    // MARK: - Domain Tile Surfaces (LEVEL 2)
    //
    // The five tiles used to be built at the call site as `card + domainColor
    // .opacity(0.34)`. One shared opacity over five different hues does not
    // produce five surfaces of the same weight, because opacity composites in
    // *sRGB* while the eye reads *relative luminance*, and the two are not the
    // same curve. The result measured 1.115:1 (amber) to 1.194:1 (lavender)
    // against the sage background — every tile too close to the background to
    // read as a tile, and unevenly so, which is what made the grid look like it
    // was fighting the page rather than sitting on it.
    //
    // These are solved per hue instead: each is the colour at that hue and a
    // shared saturation whose relative luminance lands on one target. Day tiles
    // measure 1.29–1.30:1 against the flat background token and carry espresso
    // text at 8.4:1; night tiles measure 1.69–1.71:1 against the navy and carry
    // off-white at 7.5:1. Identical separation, identical legibility, five
    // different hues.
    //
    // Night runs at a lower saturation (0.20) than day (0.33) for the same
    // reason the old build looked wrong: chroma reads louder on a dark ground.
    // Solved at day's saturation, the night amber and lavender came out as a
    // strong olive and a vivid purple against a palette whose whole character is
    // muted. The old night tiles did land in roughly the right *place* — but by
    // accident and unevenly, at saturations from 0.06 to 0.30 across the five.
    //
    // They are opaque on purpose: a tint over AmbientBackground's blurred
    // circles picks up whatever is behind it, so no two tiles on the same
    // screen ever matched.

    static func grossMotorTile(for nightMode: Bool) -> Color {
        nightMode ? Color(hex: 0x3A4C56) : Color(hex: 0xB9CEDC)
    }

    static func fineMotorTile(for nightMode: Bool) -> Color {
        nightMode ? Color(hex: 0x514936) : Color(hex: 0xD6CAAE)
    }

    static func languageTile(for nightMode: Bool) -> Color {
        nightMode ? Color(hex: 0x344F49) : Color(hex: 0xA9D4CE)
    }

    static func cognitiveTile(for nightMode: Bool) -> Color {
        nightMode ? Color(hex: 0x4C4568) : Color(hex: 0xCDC7E3)
    }

    static func socialEmotionalTile(for nightMode: Bool) -> Color {
        nightMode ? Color(hex: 0x624242) : Color(hex: 0xE2C4C4)
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
    /// Was 14, which was off the 4pt grid entirely — every card in the app was
    /// inset by a value that lined up with nothing, including the 20pt screen
    /// margin outside it.
    static let cardPadding: CGFloat = 16
    static let padding: CGFloat = 16
    static let largePadding: CGFloat = 24

    /// Space between independent top-level cards/sections — Home's card
    /// stack, Settings' card groups, Milestones' domain cards.
    ///
    /// Was 28 and applied to *every* neighbour "full stop", which is what made
    /// the screens read as a column of disconnected slabs: whitespace is meant
    /// to encode relationship, and one value everywhere encodes none. Settings
    /// spent 280pt — a third of the screen — on gaps between rows that belong
    /// together. Cards now group related rows internally (see `divider`), so
    /// this separates real sections and can come down to a value on the 8pt
    /// grid.
    static let sectionSpacing: CGFloat = 24

    /// Space between closely-grouped sub-items living *inside* one card —
    /// the Growth Domains tiles, rows inside a domain card, Recent Moments
    /// rows. Tighter than sectionSpacing on purpose: these read as one group,
    /// not as separate cards.
    static let itemSpacing: CGFloat = 12

    /// Row separator for cards holding more than one row. Inset to the text
    /// column rather than run edge-to-edge, matching the system's grouped list.
    static func divider(nightMode: Bool) -> some View {
        DividerLine(nightMode: nightMode)
    }

    /// Colour of a row separator. Split out from `divider` so the value is
    /// reachable by callers that draw their own rule.
    static func dividerColor(
        for nightMode: Bool,
        increaseContrast: Bool = false
    ) -> Color {
        let alpha: Double = nightMode
            ? (increaseContrast ? 0.26 : 0.12)
            : (increaseContrast ? 0.18 : 0.08)
        return textPrimary(for: nightMode).opacity(alpha)
    }
    
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

    /// A card that supplies the surface but not the inset, for containers whose
    /// rows pad themselves — a grouped list needs its separators to run wider
    /// than the text, so the padding can't live on the card.
    func groupedCard(nightMode: Bool) -> some View {
        self
            .background(Theme.cardBackground(for: nightMode))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
            .cardShadow(nightMode: nightMode)
    }

    /// The one shadow a card gets. Unchanged in value — the elevation work was
    /// done in luminance, not by stacking more shadow on top of surfaces that
    /// were the same colour underneath.
    fileprivate func cardShadow(nightMode: Bool) -> some View {
        self.shadow(
            color: Theme.cardShadow(for: nightMode),
            radius: nightMode ? 6 : 10,
            x: 0,
            y: nightMode ? 3 : 4
        )
    }

    /// A typed field: no box, a rule underneath.
    ///
    /// Use this ONLY for something the parent types into. A date, a menu
    /// selection or a toggle is not a typed field and must not be wrapped in
    /// one — see `formRow`. Wrapping `DatePicker` in the old boxed version is
    /// what produced the box-in-box in Settings: UIKit draws the date its own
    /// #D8D3D0 pill, and our #E6E2DD fill sat directly behind it at 1.15:1.
    ///
    /// - Parameter isFocused: pass the field's own `@FocusState`. The resting
    ///   rule is deliberately quiet, so without this a tapped field looks
    ///   exactly like an untapped one.
    func underlineField(nightMode: Bool, isFocused: Bool = false) -> some View {
        modifier(UnderlineField(nightMode: nightMode, isFocused: isFocused))
    }

    /// Fades scrolling content out beneath the status bar.
    ///
    /// Settings and Assistant already did this; Dashboard and Milestones did
    /// not, so on those two a card's text collided with the clock at the top of
    /// the screen. Extracted rather than copied a third and fourth time so the
    /// four tabs cannot drift apart again.
    func scrollEdgeFade() -> some View {
        mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 80)
                Color.black
            }
            .ignoresSafeArea()
        )
    }

    func warmCard(nightMode: Bool) -> some View {
        self
            .padding(Theme.cardPadding)
            .background(Theme.cardBackground(for: nightMode))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
            .cardShadow(nightMode: nightMode)
    }
    

    func natureCard() -> some View {
        self.warmCard(nightMode: false)
    }
}

// MARK: - Contrast-Aware Surface Modifiers
//
// These are `ViewModifier`s rather than plain `View` extensions for one reason:
// a modifier can read `@Environment(\.colorSchemeContrast)` itself. The
// alternative was threading an `increaseContrast` flag through every call site
// of `formField`, which is exactly the kind of per-view colour decision the
// theme is supposed to prevent.

/// The rule-under-the-value treatment for typed fields.
struct UnderlineField: ViewModifier {
    let nightMode: Bool
    let isFocused: Bool

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 10)
            // No horizontal inset. The old boxed field padded its text 14pt in
            // from the box edge, so a field's value hung off the card's text
            // column while its own label lined up with it. Without the box the
            // value sits on the column, which is the point.
            .frame(minHeight: 44, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.fieldRule(
                        for: nightMode,
                        isFocused: isFocused,
                        increaseContrast: contrast == .increased
                    ))
                    .frame(height: isFocused ? 2 : 1)
            }
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

/// One row of a grouped form: label on the left, value on the right.
///
/// The Apple Settings anatomy, and the answer to "why does this look like a
/// component we imported". A date, a menu and a toggle each already draw their
/// own control; giving them a second container of ours put one box inside
/// another. As rows they contribute their control as the row's value and
/// nothing is wrapped.
struct FormRow<Value: View>: View {
    let label: String
    var systemImage: String? = nil
    let nightMode: Bool
    @ViewBuilder let value: () -> Value

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility text sizes a label and its value cannot share a line
        // without one of them truncating, so the row becomes two lines.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(Theme.accentBlueText(for: nightMode))
                        .frame(width: 22)
                }
                Text(label)
                    .font(Theme.sproutlyFieldValue)
                    .foregroundStyle(Theme.textPrimary(for: nightMode))
            }

            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }

            value()
        }
        .frame(minHeight: 52)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// The header of a Settings feature card: circled glyph, title, one
/// explanatory line, and a trailing control.
///
/// Extracted because Night Mode and Gentle reminders were hand-rolling the same
/// HStack, and it carried two accessibility faults at large text sizes:
///
/// - **The circle now scales with the glyph.** The icon used
///   `sproutlyScaledFont` while the disc behind it was pinned at 40pt, so at
///   accessibility sizes the glyph grew straight out of the ornament it was
///   meant to sit in. `@ScaledMetric` grows them together.
/// - **The row now reflows.** Icon, text and control could not share a line at
///   those sizes; the text column got narrow enough to hyphenate mid-word
///   ("Reduce bright-ness for quiet evenings"). Same `AnyLayout` switch
///   `FormRow` already uses.
struct SettingsFeatureHeader<Control: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let nightMode: Bool
    @ViewBuilder let control: () -> Control

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 40

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Everything stacks. The glyph gets its own line rather than
                // sharing one with the title: at these sizes the scaled disc is
                // wide enough that the remaining text column hyphenated
                // mid-word ("Reduce bright-ness"). Full width, no hyphens.
                VStack(alignment: .leading, spacing: 12) {
                    glyph
                    labels
                    control()
                }
            } else {
                HStack(spacing: 14) {
                    glyph
                    labels
                    Spacer(minLength: 8)
                    control()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var glyph: some View {
        ZStack {
            Circle()
                .fill(Theme.iconHalo(for: nightMode))
                .frame(width: circleSize, height: circleSize)

            Image(systemName: systemImage)
                .sproutlyScaledFont(18, relativeTo: .body)
                .foregroundStyle(Theme.accentBlueText(for: nightMode))
        }
        // Decorative: the title beside it already says what this is.
        .accessibilityHidden(true)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.sproutlyCardTitle)
                .foregroundStyle(Theme.textPrimary(for: nightMode))
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(Theme.sproutlyBody)
                .foregroundStyle(Theme.textSecondary(for: nightMode))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The switch itself, without a label.
///
/// UIKit draws an unchecked switch on a #C3C2C1 track — the only pure-neutral
/// grey anywhere in Sproutly, sitting in a card that is warm ivory on a sage
/// page. It was the most obviously-imported pixel on the Settings screen.
/// `.tint()` only recolours the ON state, so the OFF track can only be fixed by
/// drawing the control.
///
/// Geometry matches the system switch (51x31, 27pt knob) so it still reads as
/// an iOS switch rather than as a custom widget.
///
/// Exposed separately from `SproutlyToggleStyle` for rows that lay themselves
/// out — the night-mode row already has an icon, a two-line label and its own
/// `Spacer`, and a second `Spacer` inside the style split the free width with
/// the first, narrowing that label from two lines to three.
struct SproutlySwitch: View {
    @Binding var isOn: Bool
    let nightMode: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Capsule()
            .fill(
                isOn
                    ? Theme.growthGreenText(for: nightMode)
                    : Theme.toggleOffTrack(
                        for: nightMode,
                        increaseContrast: contrast == .increased
                    )
            )
            .frame(width: 51, height: 31)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: 27, height: 27)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 2)
            }
            .animation(
                Theme.spring(0.25, damping: 0.8, reduceMotion: reduceMotion),
                value: isOn
            )
            // The switch is 51x31; the row it sits in is at least 44 tall, but
            // the control itself must be too.
            .frame(minWidth: 51, minHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture { isOn.toggle() }
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// A labelled toggle drawn with `SproutlySwitch`.
struct SproutlyToggleStyle: ToggleStyle {
    let nightMode: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label

            Spacer(minLength: 8)

            SproutlySwitch(isOn: configuration.$isOn, nightMode: nightMode)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

/// A −/+ stepper drawn from this palette.
///
/// The last UIKit-drawn control in the forms. `Stepper` renders its own neutral
/// grey capsule with a hairline divider down the middle — the same "imported
/// from somewhere" problem as the switch, and `.tint()` does not reach it
/// either. Same 44pt targets and the same repeat-on-hold behaviour is not
/// reproduced here deliberately: these ranges are small enough to tap through,
/// and a custom press-and-hold repeat is a fiddly thing to get right for no
/// real gain.
struct SproutlyStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let nightMode: Bool
    /// Spoken after each step, e.g. "7 months".
    var announce: (Int) -> String = { "\($0)" }

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 0) {
            button(systemName: "minus", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - 1)
            }
            .accessibilityLabel("Decrease")

            Rectangle()
                .fill(Theme.dividerColor(
                    for: nightMode,
                    increaseContrast: contrast == .increased
                ))
                .frame(width: 1, height: 20)

            button(systemName: "plus", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + 1)
            }
            .accessibilityLabel("Increase")
        }
        .background(
            Capsule().fill(Theme.recessedFill(
                for: nightMode,
                increaseContrast: contrast == .increased
            ))
        )
        .accessibilityValue(announce(value))
    }

    private func button(
        systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(
                    enabled
                        ? Theme.accentBlueText(for: nightMode)
                        : Theme.textSecondary(for: nightMode).opacity(0.4)
                )
                .frame(width: 52, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// A row separator that deepens under Increase Contrast.
struct DividerLine: View {
    let nightMode: Bool

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Rectangle()
            .fill(Theme.dividerColor(for: nightMode, increaseContrast: contrast == .increased))
            .frame(height: 1)
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
