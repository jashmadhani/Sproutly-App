//
//  ChildProfile.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/02/26.
//

import SwiftUI

// MARK: - Child Profile


@Observable
final class ChildProfile {
    
    // MARK: - Properties
    
    var name: String
    var birthDate: Date
    var isPremature: Bool
    var gestationalWeeks: Int
    var hasCompletedOnboarding: Bool
    
    // MARK: - Initializer
    
    init(
        name: String = "",
        birthDate: Date = Date(),
        isPremature: Bool = false,
        gestationalWeeks: Int = 40,
        hasCompletedOnboarding: Bool = false
    ) {
        self.name = name
        self.birthDate = birthDate
        self.isPremature = isPremature
        self.gestationalWeeks = gestationalWeeks
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
    
    // MARK: - Age Calculation
    
    var chronologicalAgeMonths: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: birthDate, to: Date())
        return max(0, components.month ?? 0)
    }
    
    var chronologicalAgeWeeks: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: birthDate, to: Date()).day ?? 0
        return max(0, days / 7)
    }
    
    // accounts for prematurity using 4.33 weeks/month
    func calculateCorrectedAge() -> Int {
        guard isPremature else {
            return chronologicalAgeMonths
        }
        let missingWeeks = 40 - gestationalWeeks
        let missingMonths = Int(round(Double(missingWeeks) / 4.33))
        return max(0, chronologicalAgeMonths - missingMonths)
    }
    

    var humanReadableAge: String {
        let calendar = Calendar.current
        let months = chronologicalAgeMonths
        let monthAnchor = calendar.date(byAdding: .month, value: months, to: birthDate) ?? birthDate
        let remainingDays = calendar.dateComponents([.day], from: monthAnchor, to: Date()).day ?? 0
        let weeks = max(0, remainingDays / 7)
        
        if months == 0 && weeks == 0 {
            return "Just beginning this journey"
        } else if months >= 12 {
            let years = months / 12
            let rem = months % 12
            if rem == 0 {
                return "\(years) year\(years == 1 ? "" : "s") old"
            }
            return "\(years) year\(years == 1 ? "" : "s"), \(rem) month\(rem == 1 ? "" : "s") old"
        } else if months == 0 {
            return "\(weeks) week\(weeks == 1 ? "" : "s") old"
        } else if weeks == 0 {
            return "\(months) month\(months == 1 ? "" : "s") old"
        } else {
            return "\(months) month\(months == 1 ? "" : "s"), \(weeks) week\(weeks == 1 ? "" : "s") old"
        }
    }
    
    var ageText: String {
        let months = calculateCorrectedAge()
        if months < 12 {
            return "\(months) month\(months == 1 ? "" : "s")"
        }
        let years = months / 12
        let remainingMonths = months % 12
        if remainingMonths == 0 {
            return "\(years) year\(years == 1 ? "" : "s")"
        }
        return "\(years) year\(years == 1 ? "" : "s"), \(remainingMonths) month\(remainingMonths == 1 ? "" : "s")"
    }
    
    var isCorrectedAge: Bool {
        isPremature && gestationalWeeks < 40
    }
    
    // MARK: - Persistence
    
    private static let saveKey = "sproutly_profile"
    
    func save() {
        let data: [String: Any] = [
            "name": name,
            "birthDate": birthDate.timeIntervalSince1970,
            "isPremature": isPremature,
            "gestationalWeeks": gestationalWeeks,
            "hasCompletedOnboarding": hasCompletedOnboarding
        ]
        UserDefaults.standard.set(data, forKey: Self.saveKey)
    }
    
    static func load() -> ChildProfile {
        let data = UserDefaults.standard.dictionary(forKey: saveKey)
            ?? UserDefaults.standard.dictionary(forKey: "elitegrowth_profile")
        
        guard let data = data else { return ChildProfile() }
        
        return ChildProfile(
            name: data["name"] as? String ?? "",
            birthDate: Date(timeIntervalSince1970: data["birthDate"] as? Double ?? Date().timeIntervalSince1970),
            isPremature: data["isPremature"] as? Bool ?? false,
            gestationalWeeks: data["gestationalWeeks"] as? Int ?? 40,
            hasCompletedOnboarding: data["hasCompletedOnboarding"] as? Bool ?? false
        )
    }
    
    func reset() {
        name = ""
        birthDate = Date()
        isPremature = false
        gestationalWeeks = 40
        hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: Self.saveKey)
        UserDefaults.standard.removeObject(forKey: "elitegrowth_profile")
    }
}
