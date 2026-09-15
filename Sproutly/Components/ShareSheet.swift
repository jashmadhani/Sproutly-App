//
//  ShareSheet.swift
//  Sproutly
//

import SwiftUI
import UIKit

// Wraps a generated file URL so it can drive .sheet(item:).
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// ShareLink needs its payload up front, but both the report and the card are
// rendered on demand — so the file is produced first, then handed to the system
// share sheet.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        // The file holds a child's name and their progress, or their photo. Once the
        // sheet is done with it there is no reason for it to stay on disk, and the
        // handler fires whether the parent shared it or backed out. Anything the
        // activity kept, it has already copied by this point.
        controller.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: url)
        }

        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
