//
//  ThemeManager.swift
//  Sproutly
//
//  Created by Jash Madhani on 19/02/26.
//

import SwiftUI


@Observable
final class ThemeManager {
    
    // MARK: - Night Mode State
    

    var isNightMode: Bool {
        didSet {
            UserDefaults.standard.set(isNightMode, forKey: "nightModeEnabled")
        }
    }
    
    // MARK: - Accessibility State
    //
    // Increase Contrast and Reduce Transparency are environment values, not
    // stored settings, so they can only be read from inside a view. They are
    // mirrored here — synced once from the root in `ContentView` — so that
    // every screen keeps reading plain `theme.card` / `theme.progressTrack`
    // and gets the right value, instead of each view separately reading the
    // environment and making its own colour decision. Deliberately *not*
    // persisted: these follow the system, and a stale copy in UserDefaults
    // would survive the reader turning the setting back off.

    /// Mirrors `\.colorSchemeContrast == .increased`.
    var increaseContrast: Bool = false

    /// Mirrors `\.accessibilityReduceTransparency`.
    var reduceTransparency: Bool = false

    init() {
        self.isNightMode = UserDefaults.standard.bool(forKey: "nightModeEnabled")
    }
    
    // MARK: - Resolved Colors
    
    var background: Color { Theme.background(for: isNightMode) }
    var card: Color { Theme.cardBackground(for: isNightMode) }
    var text: Color { Theme.textPrimary(for: isNightMode) }
    var textSecondary: Color { Theme.textSecondary(for: isNightMode) }
    var blue: Color { Theme.accentBlue(for: isNightMode) }
    /// Use for text and UI-scale icons; `blue` is a surface tint that fails
    /// contrast on both day backgrounds.
    var blueText: Color { Theme.accentBlueText(for: isNightMode) }
    var green: Color { Theme.growthGreen(for: isNightMode) }
    /// Use for text and read glyphs; `green` is a surface tint.
    var greenText: Color { Theme.growthGreenText(for: isNightMode) }
    var ctaGradient: LinearGradient { Theme.ctaGradient(for: isNightMode) }
    var ctaShadow: Color { Theme.ctaShadow(for: isNightMode) }
    var proGold: Color { Theme.proGold(for: isNightMode) }
    /// Use for any gold a parent has to actually see — locks, stars, labels.
    /// `proGold` is a surface and fails AA as a mark. See Theme.proGoldText.
    var proGoldText: Color { Theme.proGoldText(for: isNightMode) }
    var proGoldGradient: LinearGradient { Theme.proGoldGradient(for: isNightMode) }
    var proHaloGradient: RadialGradient { Theme.proHaloGradient(for: isNightMode) }
    var yellow: Color { Theme.encourageYellow(for: isNightMode) }

    // MARK: - Surface Ladder

    /// LEVEL 4 — the floating tab dock.
    var navigationSurface: Color {
        Theme.navigationSurface(for: isNightMode, reduceTransparency: reduceTransparency)
    }
    var navigationEdge: Color {
        Theme.navigationEdge(for: isNightMode, increaseContrast: increaseContrast)
    }
    var navigationShadow: Color { Theme.navigationShadow(for: isNightMode) }
    var cardShadow: Color { Theme.cardShadow(for: isNightMode) }

    /// Unfilled portion of a progress bar.
    var progressTrack: Color {
        Theme.progressTrack(for: isNightMode, increaseContrast: increaseContrast)
    }
    var recessedFill: Color {
        Theme.recessedFill(for: isNightMode, increaseContrast: increaseContrast)
    }
    var divider: Color {
        Theme.dividerColor(for: isNightMode, increaseContrast: increaseContrast)
    }
    
    // domain colors
    var grossMotorColor: Color { Theme.grossMotorColor(for: isNightMode) }
    var fineMotorColor: Color { Theme.fineMotorColor(for: isNightMode) }
    var languageColor: Color { Theme.languageColor(for: isNightMode) }
    var cognitiveColor: Color { Theme.cognitiveColor(for: isNightMode) }
    var socialEmotionalColor: Color { Theme.socialEmotionalColor(for: isNightMode) }

    // domain tile surfaces (LEVEL 2) — see Theme's "Domain Tile Surfaces" note
    // for why these are solved values rather than the accents at an opacity.
    var grossMotorTile: Color { Theme.grossMotorTile(for: isNightMode) }
    var fineMotorTile: Color { Theme.fineMotorTile(for: isNightMode) }
    var languageTile: Color { Theme.languageTile(for: isNightMode) }
    var cognitiveTile: Color { Theme.cognitiveTile(for: isNightMode) }
    var socialEmotionalTile: Color { Theme.socialEmotionalTile(for: isNightMode) }
    
    // MARK: - Color Scheme Override
    

    var preferredColorScheme: ColorScheme? {
        isNightMode ? .dark : .light
    }
}
