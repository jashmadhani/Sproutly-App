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
    case blossom

    var id: String { rawValue }

    /// nil for the primary icon — this is what `setAlternateIconName` expects.
    var alternateName: String? {
        switch self {
        case .classic: return nil
        case .sprout:  return "AppIconSprout"
        case .twin:    return "AppIconTwin"
        case .night:   return "AppIconNight"
        case .blossom: return "AppIconBlossom"
        }
    }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .sprout:  return "Golden"
        case .twin:    return "Two Sprouts"
        case .night:   return "Night"
        case .blossom: return "Blossom"
        }
    }

    var subtitle: String {
        switch self {
        case .classic: return "The original"
        case .sprout:  return "Warm gold"
        case .twin:    return "For siblings and twins"
        case .night:   return "Deep navy"
        case .blossom: return "In full bloom"
        }
    }

    /// Preview asset. .appiconset entries are a distinct catalog category and
    /// are not resolvable by name through Image(_:)/UIImage(named:), so each
    /// icon has a matching plain imageset (same artwork) just for this picker.
    var previewAssetName: String {
        switch self {
        case .classic: return "AppIconClassicPreview"
        case .sprout:  return "AppIconSproutPreview"
        case .twin:    return "AppIconTwinPreview"
        case .night:   return "AppIconNightPreview"
        case .blossom: return "AppIconBlossomPreview"
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
