//
//  MilestoneShareCard.swift
//  Sproutly
//

import SwiftUI

// The card sent to grandparents. Warm, personal, and light on branding — this is
// a family photo with a caption, not an ad for the app.
struct MilestoneShareCard: View {
    let milestone: Milestone
    let childName: String
    let photo: UIImage?

    // A milestone the parent backfilled during onboarding is completed but has no
    // date — they told us it happened, not when. The previous `?? Date()` printed
    // today's date onto the one artifact designed to leave the phone, which was
    // simply untrue. With no date the caption is the child's name alone.
    //
    // Pulled out as a pure function so the rule is testable without a graphics
    // context, the same way ReportBuilder is separate from ShareRenderer.
    static func caption(childName: String, dateCompleted: Date?) -> String {
        guard let dateCompleted else { return childName }
        return "\(childName), \(dateCompleted.formatted(date: .long, time: .omitted))"
    }

    private var captionText: String {
        Self.caption(childName: childName, dateCompleted: milestone.dateCompleted)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 600, height: 600)
                    .clipped()
            } else {
                // Without a photo the card still has to look intentional.
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.80, green: 0.91, blue: 0.93),
                            Color(red: 0.93, green: 0.95, blue: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: milestone.categoryType.icon)
                        .font(.system(size: 120, weight: .light))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(width: 600, height: 600)
            }

            VStack(spacing: 10) {
                Text(milestone.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.13, green: 0.18, blue: 0.19))
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)

                Text(captionText)
                    .font(.system(size: 20, design: .rounded))
                    .foregroundStyle(Color(red: 0.42, green: 0.47, blue: 0.48))

                if !milestone.completionNote.isEmpty {
                    Text("\u{201C}\(milestone.completionNote)\u{201D}")
                        .font(.system(size: 18, design: .rounded))
                        .italic()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(red: 0.42, green: 0.47, blue: 0.48))
                        .lineLimit(3)
                        .padding(.top, 2)
                }

                Label("Sproutly", systemImage: "leaf.fill")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.36, green: 0.66, blue: 0.75))
                    .padding(.top, 10)
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 40)
            .frame(width: 600)
            .background(Color(red: 0.98, green: 0.98, blue: 0.96))
        }
        .frame(width: 600)
    }
}
