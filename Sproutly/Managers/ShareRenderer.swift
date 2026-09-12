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

    // MARK: - Where rendered files live

    // Everything rendered here is written into one directory under tmp rather than
    // loose in tmp itself, so the whole lot can be removed in a single call.
    //
    // This matters more than it looks: the PDF carries the child's name and their
    // not-yet-met list, and the card carries their photo. Both used to be written
    // straight into tmp under a predictable name and left there indefinitely, which
    // sits badly with an app whose entire promise is that nothing about a child
    // leaves the device. iOS reclaims tmp eventually, but on its own schedule.
    //
    // Filenames still read as the parent's own ("Aarav-milestones.pdf"), because
    // that is what the share sheet shows them and what lands in a pediatrician's
    // inbox. Only the containing folder changed.
    private static var directory: URL? {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SharedRenders", isDirectory: true)

        if !FileManager.default.fileExists(atPath: folder.path) {
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            } catch {
                sproutlyLog("could not create share directory — \(error.localizedDescription)")
                return nil
            }
        }

        return folder
    }

    /// Removes every rendered file.
    ///
    /// Called at launch to catch anything a crash or a force-quit stranded midway
    /// through sharing. `ShareSheet` also deletes its own file as soon as the sheet
    /// is finished with it, so in the ordinary case this finds nothing to do.
    static func clearRenderedFiles() {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - PDF

    // Renders the report to a paginated PDF in the temporary directory and returns
    // its URL, or nil if rendering failed.
    static func pdf(for report: MilestoneReport) -> URL? {
        let renderer = ImageRenderer(content: ReportDocumentView(report: report))
        renderer.proposedSize = ProposedViewSize(width: pageSize.width, height: nil)

        guard let directory else { return nil }
        let url = directory.appendingPathComponent("\(safeName(report.childName))-milestones.pdf")

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
              let data = image.pngData(),
              let directory else { return nil }

        let url = directory.appendingPathComponent("\(safeName(childName))-moment.png")

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
