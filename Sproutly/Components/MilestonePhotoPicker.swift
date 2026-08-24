//
//  MilestonePhotoPicker.swift
//  Sproutly
//

import SwiftUI
import PhotosUI

// Photo chooser for the completion sheet. Its own view so PhotosPicker's label
// closure — which SwiftUI treats as Sendable — never captures main-actor state
// from the screen presenting it.
struct MilestonePhotoPicker: View {
    @Binding var imageData: Data?
    let nightMode: Bool

    @State private var selection: PhotosPickerItem?

    // Shown exactly once — a parent's first time in this sheet after Pro
    // unlocks the photo feature, so they notice it's here at all rather than
    // needing to already know to look. Never shown again after that.
    private static let hasSeenHintKey = "sproutly_has_seen_photo_hint"
    @State private var showNewHint = !UserDefaults.standard.bool(forKey: MilestonePhotoPicker.hasSeenHintKey)

    var body: some View {
        // Copied into locals first: Data and Bool are Sendable, so the label
        // closure below captures values rather than reaching back into self.
        let currentData = imageData
        let isNight = nightMode

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Add a photo", systemImage: "photo")
                    .font(Theme.sproutlyCardTitle)
                    .foregroundStyle(Theme.accentBlueText(for: isNight))

                if showNewHint {
                    Text("New")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.accentBlue(for: isNight)))
                }
            }

            PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                PickerLabel(imageData: currentData, nightMode: isNight)
            }
            .accessibilityLabel("Add a photo to this milestone")

            if imageData != nil {
                Button {
                    imageData = nil
                    selection = nil
                } label: {
                    Label("Remove photo", systemImage: "xmark.circle")
                        .font(Theme.sproutlyMeta)
                        .foregroundStyle(Theme.textSecondary(for: isNight))
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: selection) {
            guard let selection else { return }
            imageData = try? await selection.loadTransferable(type: Data.self)
        }
        .onAppear {
            UserDefaults.standard.set(true, forKey: Self.hasSeenHintKey)
        }
    }
}

private struct PickerLabel: View {
    let imageData: Data?
    let nightMode: Bool

    /// Width-over-height, clamped to keep the sheet's buttons reachable.
    /// 4:3 landscape at the wide end, 3:4 portrait at the tall end.
    private func previewAspect(for image: UIImage) -> CGFloat {
        guard image.size.height > 0 else { return 4.0 / 3.0 }
        let actual = image.size.width / image.size.height
        return min(max(actual, 3.0 / 4.0), 4.0 / 3.0)
    }

    var body: some View {
        if let imageData, let image = UIImage(data: imageData) {
            // The preview follows the photo's own shape instead of forcing every
            // image into a 120pt letterbox, which cropped the top and bottom off
            // anything portrait — i.e. most photos of a baby.
            //
            // Clamped rather than free: a very tall image left unbounded would
            // push the Skip / Save buttons off the bottom of the sheet. Inside
            // the clamp there is no crop at all; only an extreme panorama or a
            // very tall portrait gets trimmed, and only to the nearest bound.
            Color.clear
                .aspectRatio(previewAspect(for: image), contentMode: .fit)
                .overlay(
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                Text("Choose a photo")
                    .font(Theme.sproutlyBody)
            }
            .foregroundStyle(Theme.textSecondary(for: nightMode))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.recessedFill(for: nightMode))
            )
        }
    }
}
