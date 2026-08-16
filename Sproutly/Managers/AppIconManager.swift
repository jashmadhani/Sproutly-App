//
//  AppIconManager.swift
//  Sproutly
//

import SwiftUI
import UIKit

// Alternate app icons. The icon names here must match the .appiconset folder
// names listed in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES in project.yml —
// a mismatch fails at runtime, not at build time.
enum AppIconOption: String, CaseIterable, Identifiable {

    /// The icon the app ships with. `alternateName` is nil because UIKit uses
    /// nil to mean "go back to the primary icon".
    case classic
    case sprout
    case twin
    case night
    case sage

    var id: String { rawValue }

    /// nil for the primary icon — this is what `setAlternateIconName` expects.
    var alternateName: String? {
        switch self {
        case .classic: return nil
        case .sprout:  return "AppIconSprout"
        case .twin:    return "AppIconTwin"
        case .night:   return "AppIconNight"
        case .sage:    return "AppIconSage"
        }
    }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .sprout:  return "Golden"
        case .twin:    return "Two Sprouts"
        case .night:   return "Night"
        case .sage:    return "Sage"
        }
    }

    var subtitle: String {
        switch self {
        case .classic: return "The original"
        case .sprout:  return "Warm gold"
        case .twin:    return "For siblings and twins"
        case .night:   return "Deep navy"
        case .sage:    return "Soft and quiet"
        }
    }

    /// Preview asset. ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS puts every
    /// .appiconset into the bundle as a loadable image, so the picker can preview
    /// the primary icon directly instead of keeping a duplicate imageset around.
    var previewAssetName: String {
        switch self {
        case .classic: return "AppIcon"
        case .sprout:  return "AppIconSprout"
        case .twin:    return "AppIconTwin"
        case .night:   return "AppIconNight"
        case .sage:    return "AppIconSage"
        }
    }
}

@MainActor
@Observable
final class AppIconManager {

    private(set) var current: AppIconOption

    /// Not every device supports alternate icons (and the simulator has been
    /// unreliable historically). Gate the whole section on this rather than
    /// letting the user tap into a feature that silently fails.
    let isSupported: Bool

    private(set) var lastError: String?

    init() {
        isSupported = UIApplication.shared.supportsAlternateIcons

        let active = UIApplication.shared.alternateIconName
        current = AppIconOption.allCases.first { $0.alternateName == active } ?? .classic
    }

    func select(_ option: AppIconOption) async {
        guard isSupported, option != current else { return }

        do {
            // Throws rather than returning false when the name isn't registered
            // in the generated plist, which is the usual symptom of a typo in
            // ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
            try await UIApplication.shared.setAlternateIconName(option.alternateName)
            current = option
            lastError = nil
        } catch {
            lastError = "Couldn't change the icon. Please try again."
        }
    }
}
