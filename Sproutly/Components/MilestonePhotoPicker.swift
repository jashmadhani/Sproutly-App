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

    var body: some View {
        // Copied into locals first: Data and Bool are Sendable, so the label
        // closure below captures values rather than reaching back into self.
        let currentData = imageData
        let isNight = nightMode

        VStack(alignment: .leading, spacing: 8) {
            Label("Add a photo", systemImage: "photo")
                .font(Theme.sproutlyCardTitle)
                .foregroundStyle(Theme.accentBlue(for: isNight))

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
    }
}

private struct PickerLabel: View {
    let imageData: Data?
    let nightMode: Bool

    var body: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    .fill(Theme.textPrimary(for: nightMode).opacity(0.04))
            )
        }
    }
}
