//
//  PhotoStore.swift
//  Sproutly
//

import Foundation
import UIKit

// Milestone photos live as files in the app container, never as blobs in
// SwiftData — a store full of image data gets slow and fragile fast. The model
// keeps only a filename.
//
// Nothing here touches the network. Photos never leave the device, which is what
// keeps the App Privacy answer at "Data Not Collected".
enum PhotoStore {

    // Long edge cap. A milestone photo is displayed at thumbnail and card size, so
    // storing a 12MP original would waste hundreds of MB across a few years.
    private static let maxDimension: CGFloat = 1600
    private static let compressionQuality: CGFloat = 0.8

    // MARK: - Location

    private static var directory: URL? {
        guard let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }

        let folder = appSupport.appendingPathComponent("MilestonePhotos", isDirectory: true)

        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            // Photos are re-creatable only by the parent, so they must be backed up,
            // but they should not sit in iCloud Drive as loose files.
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = false
            var mutable = folder
            try? mutable.setResourceValues(resourceValues)
        }

        return folder
    }

    static func url(for filename: String) -> URL? {
        directory?.appendingPathComponent(filename)
    }

    // MARK: - Writing

    // Returns the generated filename, or nil if the image could not be stored.
    static func save(_ data: Data) -> String? {
        guard let image = UIImage(data: data),
              let resized = downscale(image),
              let jpeg = resized.jpegData(compressionQuality: compressionQuality),
              let destination = url(for: "\(UUID().uuidString).jpg") else { return nil }

        do {
            try jpeg.write(to: destination, options: .atomic)
            return destination.lastPathComponent
        } catch {
            print("⚠️ Sproutly: could not save milestone photo — \(error.localizedDescription)")
            return nil
        }
    }

    static func delete(_ filename: String?) {
        guard let filename, let target = url(for: filename) else { return }
        try? FileManager.default.removeItem(at: target)
    }

    // MARK: - Reading

    static func image(named filename: String?) -> UIImage? {
        guard let filename, let source = url(for: filename) else { return nil }
        return UIImage(contentsOfFile: source.path)
    }

    // MARK: - Private

    private static func downscale(_ image: UIImage) -> UIImage? {
        let longEdge = max(image.size.width, image.size.height)
        guard longEdge > maxDimension else { return image }

        let scale = maxDimension / longEdge
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
