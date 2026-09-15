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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility text sizes three segments cannot share a line: a render
        // at the largest size split "Weight" into "Weig" / "ht". The segments
        // stack instead, the same reflow FormRow and FeatureCardHeader use. The
        // stadium radius comes down with it, since a 999pt radius on a tall stack
        // would round its corners into the labels.
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(spacing: 4))
        let pillRadius: CGFloat = stacked ? 18 : 999

        layout {
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
                            RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
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
            RoundedRectangle(cornerRadius: stacked ? pillRadius + 4 : 999, style: .continuous)
                .fill(theme.recessedFill)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}
