//
//  ScreeningCardView.swift
//  Sproutly
//
//  Created by Jash Madhani on 19/02/26.
//

import SwiftUI

// screening reminder cards — active and overdue windows
struct ScreeningCardView: View {
    let correctedAge: Int
    let nightMode: Bool
    

    private var activeScreenings: [ScreeningCheckpoint] {
        ScreeningCheckpoint.allCheckpoints.filter { cp in
            correctedAge >= cp.ageMonth && correctedAge <= cp.ageMonth + 4
        }
    }
    

    private var overdueScreenings: [ScreeningCheckpoint] {
        ScreeningCheckpoint.allCheckpoints.filter { cp in
            correctedAge > cp.ageMonth + 4 && correctedAge <= cp.ageMonth + 8
        }
    }
    
    var body: some View {
        // Active screenings — standard blue style
        ForEach(activeScreenings) { screening in
            screeningCard(screening, isOverdue: false)
        }
        
        // Overdue screenings — softer visual, "Worth discussing" tone
        ForEach(overdueScreenings) { screening in
            screeningCard(screening, isOverdue: true)
        }
    }
    
    private func screeningCard(_ screening: ScreeningCheckpoint, isOverdue: Bool) -> some View {
        let cardColor = isOverdue
            ? Theme.encourageYellow(for: nightMode)
            : Theme.accentBlue(for: nightMode)
        
        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(cardColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                Image(systemName: screening.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(cardColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(screening.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textPrimary(for: nightMode))
                    
                    if isOverdue {
                        Text("Past due")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.encourageYellow(for: nightMode))
                    }
                }
                
                Text(isOverdue
                     ? "Worth discussing at your next visit — it's never too late to bring this up with your pediatrician."
                     : screening.body)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary(for: nightMode))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(cardColor.opacity(isOverdue ? (nightMode ? 0.04 : 0.05) : (nightMode ? 0.06 : 0.08)))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .stroke(cardColor.opacity(isOverdue ? 0.15 : 0.1), lineWidth: 1)
        )
        .opacity(isOverdue ? 0.85 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isOverdue
            ? "Past due: \(screening.title). Worth discussing at your next visit."
            : screening.title)
    }
}

// MARK: - Screening Checkpoints

struct ScreeningCheckpoint: Identifiable {
    let id = UUID()
    let ageMonth: Int
    let title: String
    let body: String
    let icon: String
    
    static let allCheckpoints: [ScreeningCheckpoint] = [
        ScreeningCheckpoint(
            ageMonth: 9,
            title: "9-Month Developmental Check-In",
            body: "Around this age, the AAP recommends a brief developmental check-in with your pediatrician. These visits help celebrate progress and catch anything early — when support makes the biggest difference.",
            icon: "clipboard.fill"
        ),
        ScreeningCheckpoint(
            ageMonth: 30,
            title: "30-Month Developmental Check-In",
            body: "Another developmental check-in helps track your child's beautiful growth. These visits are a wonderful opportunity to discuss any questions and celebrate milestones together with your pediatrician.",
            icon: "clipboard.fill"
        ),
    ]
}
