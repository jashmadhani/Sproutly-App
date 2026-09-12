//
//  SproutlySegmentedControl.swift
//  Sproutly
//

import SwiftUI

/// The app's segmented control. Use it instead of `.pickerStyle(.segmented)`.
///
/// UIKit draws the system one on a #CCD8CC track — 1.13:1 against the page, so it
/// barely separates — and gives the selected segment a *pure white* pill. Pure
/// white is the floating dock and nothing else; a second pure-white surface
/// halfway up the screen breaks the luminance ladder every separation in the app
/// depends on. The selected pill here is the card colour, which is what every
/// other raised surface uses.
///
/// Extracted from the Milestones filter when Growth needed the same control, so
/// the two cannot drift into two slightly different pills.
struct SproutlySegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let accessibilityLabel: String
    let title: (Option) -> String

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? theme.text : theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(isSelected ? theme.card : Color.clear)
                                .shadow(
                                    color: isSelected ? theme.cardShadow : .clear,
                                    radius: 4, x: 0, y: 2
                                )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(theme.recessedFill)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}
