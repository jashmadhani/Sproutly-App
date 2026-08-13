//
//  ReportDocumentView.swift
//  Sproutly
//

import SwiftUI

// The printed page. Deliberately plain: black on white, no app theming, no
// ambient background — this gets handed to a clinician or printed, and it should
// read like a document rather than a screenshot of an app.
struct ReportDocumentView: View {
    let report: MilestoneReport

    private var dateText: String {
        report.generatedOn.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            summary

            ForEach(report.sections) { section in
                domainBlock(section)
            }

            if !report.notYetMet.isEmpty {
                notYetMetBlock
            }

            if !report.ownMoments.isEmpty {
                ownMomentsBlock
            }

            disclaimer
        }
        .padding(40)
        .frame(width: 612, alignment: .leading)   // US Letter at 72dpi
        .background(Color.white)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Developmental Milestone Summary")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)

            Text("\(report.childName) · \(report.ageText)")
                .font(.system(size: 14))
                .foregroundStyle(.black)

            if report.isPremature {
                Text("Born at \(report.gestationalWeeks) weeks · ages shown are corrected")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Text("Prepared \(dateText) with Sproutly")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Rectangle()
                .fill(.black.opacity(0.15))
                .frame(height: 1)
                .padding(.top, 6)
        }
    }

    private var summary: some View {
        Text("\(report.totalCompleted) of \(report.totalExpected) milestones observed for this age.")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.black)
    }

    private func domainBlock(_ section: MilestoneReport.DomainSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(section.category.gentleLabel)  (\(section.completed.count)/\(section.total))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)

            ForEach(section.completed) { milestone in
                row(milestone.title, marker: "✓", dimmed: false, detail: completedDetail(milestone))
            }

            ForEach(section.pending) { milestone in
                row(milestone.title, marker: "○", dimmed: true, detail: "expected ~\(milestone.expectedAgeText)")
            }
        }
    }

    private var notYetMetBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Worth discussing")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)

            Text("Not yet observed, and typically expected some time ago:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            ForEach(report.notYetMet) { milestone in
                row(
                    milestone.title,
                    marker: "•",
                    dimmed: false,
                    detail: "\(milestone.categoryType.gentleLabel) · expected ~\(milestone.expectedAgeText)"
                )
            }
        }
    }

    private var ownMomentsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Family-recorded moments")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)

            ForEach(report.ownMoments) { milestone in
                row(milestone.title, marker: "♥", dimmed: false, detail: completedDetail(milestone))
            }
        }
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(.black.opacity(0.15))
                .frame(height: 1)

            Text("This summary reflects a parent's own observations recorded in Sproutly. It is not a screening result, a diagnosis, or medical advice, and it is not a substitute for professional developmental screening.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
    }

    // MARK: - Helpers

    private func completedDetail(_ milestone: Milestone) -> String {
        var parts: [String] = []
        if let date = milestone.dateCompleted {
            parts.append(date.formatted(date: .abbreviated, time: .omitted))
        }
        if !milestone.completionNote.isEmpty {
            parts.append("\"\(milestone.completionNote)\"")
        }
        return parts.joined(separator: " · ")
    }

    private func row(_ title: String, marker: String, dimmed: Bool, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(marker)
                .font(.system(size: 11))
                .foregroundStyle(dimmed ? Color.secondary : Color.black)
                .frame(width: 12, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(dimmed ? Color.secondary : Color.black)

                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }
}
