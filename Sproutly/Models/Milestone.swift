//
//  Milestone.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/02/26.
//

import SwiftUI
import SwiftData

// MARK: - Milestone Model


@Model
final class Milestone: Identifiable {
    
    // MARK: - Properties
    
    var id: UUID
    var title: String
    

    var category: String
    

    var ageMonth: Int
    
    var isCompleted: Bool
    var dateCompleted: Date?
    

    var tips: String
    

    var completionNote: String
    
    // MARK: - Initializer
    
    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        ageMonth: Int,
        isCompleted: Bool = false,
        dateCompleted: Date? = nil,
        tips: String = "",
        completionNote: String = ""
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.ageMonth = ageMonth
        self.isCompleted = isCompleted
        self.dateCompleted = dateCompleted
        self.tips = tips
        self.completionNote = completionNote
    }
    
    // MARK: - Computed
    
    var categoryType: MilestoneCategory {
        MilestoneCategory(rawValue: category) ?? .grossMotor
    }
    
    var expectedAgeText: String {
        if ageMonth < 24 {
            return "\(ageMonth) months"
        } else {
            let years = ageMonth / 12
            let remainder = ageMonth % 12
            if remainder == 0 {
                return "\(years) year\(years == 1 ? "" : "s")"
            }
            return "\(years)y \(remainder)m"
        }
    }
}

// MARK: - Milestone Category

enum MilestoneCategory: String, CaseIterable {
    case grossMotor = "Gross Motor"
    case fineMotor = "Fine Motor"
    case language = "Language"
    case cognitive = "Cognitive"
    case socialEmotional = "Social-Emotional"
    
    var icon: String {
        switch self {
        case .grossMotor: return "figure.walk"
        case .fineMotor: return "hand.raised.fingers.spread"
        case .language: return "bubble.left.and.bubble.right"
        case .cognitive: return "brain.head.profile"
        case .socialEmotional: return "heart.circle"
        }
    }
    
    func color(for nightMode: Bool) -> Color {
        switch self {
        case .grossMotor: return Theme.grossMotorColor(for: nightMode)
        case .fineMotor: return Theme.fineMotorColor(for: nightMode)
        case .language: return Theme.languageColor(for: nightMode)
        case .cognitive: return Theme.cognitiveColor(for: nightMode)
        case .socialEmotional: return Theme.socialEmotionalColor(for: nightMode)
        }
    }
    
    var gentleLabel: String {
        switch self {
        case .grossMotor: return "Movement & Strength"
        case .fineMotor: return "Hands & Coordination"
        case .language: return "Communication"
        case .cognitive: return "Curiosity & Thinking"
        case .socialEmotional: return "Connection & Emotion"
        }
    }
    
    // language weighted 1.2x in focus scoring
    var focusWeight: Double {
        switch self {
        case .language: return 1.2
        default: return 1.0
        }
    }
}

// MARK: - Timing Status

enum TimingStatus: String {
    case celebrated = "Celebrated"
    case onTrack = "On Track"
    case exploring = "Still Exploring"
    case comingSoon = "Coming Soon"
    
    func color(for nightMode: Bool) -> Color {
        switch self {
        case .celebrated: return Theme.encourageYellow(for: nightMode)
        case .onTrack: return Theme.growthGreen(for: nightMode)
        case .exploring: return Theme.encourageYellow(for: nightMode)
        case .comingSoon: return Theme.textSecondary(for: nightMode)
        }
    }
    
    var icon: String {
        switch self {
        case .celebrated: return "heart.fill"
        case .onTrack: return "checkmark.circle.fill"
        case .exploring: return "heart.circle"
        case .comingSoon: return "clock.fill"
        }
    }
}

// MARK: - Timing Logic

extension Milestone {
    func getTimingStatus(childAgeMonths: Int) -> TimingStatus {
        if isCompleted {
            return childAgeMonths < ageMonth ? .celebrated : .onTrack
        }
        if childAgeMonths < ageMonth {
            return .comingSoon
        } else if childAgeMonths <= ageMonth + 2 {
            return .onTrack
        } else {
            return .exploring
        }
    }
    
    func isSignificantlyLate(childAgeMonths: Int) -> Bool {
        !isCompleted && childAgeMonths > ageMonth + 3
    }
}
