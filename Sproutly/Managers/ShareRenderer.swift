//
//  ShareRenderer.swift
//  Sproutly
//

import SwiftUI
import UIKit

// Turns SwiftUI into shareable files. Both the pediatrician report (C) and the
// milestone card (D) render through here.
@MainActor
enum ShareRenderer {

    // US Letter at 72dpi, the coordinate space ImageRenderer works in.
    private static let pageSize = CGSize(width: 612, height: 792)

    // MARK: - PDF

    // Renders the report to a paginated PDF in the temporary directory and returns
    // its URL, or nil if rendering failed.
    static func pdf(for report: MilestoneReport) -> URL? {
        let renderer = ImageRenderer(content: ReportDocumentView(report: report))
        renderer.proposedSize = ProposedViewSize(width: pageSize.width, height: nil)

        let filename = "\(safeName(report.childName))-milestones.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        var success = false

        renderer.render { contentSize, renderContent in
            var box = CGRect(origin: .zero, size: pageSize)

            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }

            // The document is one tall column; slice it into pages by translating
            // the origin, so content taller than a page doesn't get clipped away.
            let pageCount = max(1, Int(ceil(contentSize.height / pageSize.height)))

            for page in 0..<pageCount {
                context.beginPDFPage(nil)
                context.saveGState()

                // ImageRenderer hands back an already-oriented context, so no flip
                // here — adding one renders the page upside down.
                //
                // The column is anchored to the bottom of the page box, so without
                // the contentSize offset page 1 would show the *end* of the report.
                // Shift down by the overflow first, then step back up one page at
                // a time so pages read top to bottom.
                let overflow = contentSize.height - pageSize.height
                context.translateBy(x: 0, y: CGFloat(page) * pageSize.height - overflow)

                renderContent(context)

                context.restoreGState()
                context.endPDFPage()
            }

            context.closePDF()
            success = true
        }

        return success ? url : nil
    }

    // MARK: - Share card

    // A square image for sending to family. Returns a temporary file URL so the
    // share sheet offers Messages/Mail/Photos rather than raw image data.
    static func card(for milestone: Milestone, childName: String, nightMode: Bool) -> URL? {
        let card = MilestoneShareCard(
            milestone: milestone,
            childName: childName,
            photo: PhotoStore.image(named: milestone.photoFilename)
        )

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3   // retina-quality when viewed full screen

        guard let image = renderer.uiImage,
              let data = image.pngData() else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName(childName))-moment.png")

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            sproutlyLog("could not write share card — \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Helpers

    private static func safeName(_ name: String) -> String {
        let allowed = name.filter { $0.isLetter || $0.isNumber }
        return allowed.isEmpty ? "Sproutly" : String(allowed.prefix(24))
    }
}
