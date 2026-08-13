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
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
