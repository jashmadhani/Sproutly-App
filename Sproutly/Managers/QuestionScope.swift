//
//  QuestionScope.swift
//  Sproutly
//

import Foundation

// MARK: - Scope

/// What kind of question this is, before working out what it is *about*.
///
/// Sproutly covers developmental milestones and nothing else. Parents do not
/// know that, and the input invites anything, so they ask about stool colour,
/// rashes, sleep training, and weaning. The engine used to score those against
/// five developmental domains, find nothing, and answer with a line about how
/// writing things down is useful.
///
/// That is bad product behaviour for a sleep question. For "why is my child's
/// poop grey" it is worse than that: pale or clay-coloured stool is a
/// recognised reason to have a baby seen, and answering it with a platitude
/// spends the parent's trust at the exact moment it matters most.
enum QuestionScope: Equatable {
    /// Milestones. The thing this app is for.
    case developmental
    /// Physical health. Out of scope, and a pediatrician question.
    case healthSymptom
    /// Physical health, and among the signs that are worth acting on promptly.
    /// Never named or diagnosed, only routed faster.
    case urgentHealthSymptom
    /// Real parenting questions this app does not track: sleep, feeding, potty.
    case parentingTopic
    /// Nothing recognised at all.
    case unclear
}

// MARK: - Detector

enum ScopeDetector {

    /// Signs that warrant being seen promptly rather than at the next visit.
    ///
    /// Deliberately a referral list, not a triage list. Sproutly is a Lifestyle
    /// app and must never suggest what a symptom means. All this does is change
    /// how quickly the answer says to call someone, which is the one useful
    /// thing an app in this position can do.
    ///
    /// Kept short and high-signal on purpose. A long list catches ordinary
    /// questions and turns every answer into an alarm, which trains parents to
    /// ignore it.
    static let urgentSingleTerms: Set<String> = [
        "seizure", "convulsion", "unresponsive", "limp", "floppy",
        "jaundice", "jaundiced", "dehydrated", "meningitis"
    ]

    /// Pairs, because the individual words are ordinary. "Grey" alone is a
    /// colour; "grey stool" is a reason to call someone.
    static let urgentPairs: [(Set<String>, Set<String>)] = [
        (["stool", "poop", "poo", "faeces", "feces", "nappy", "diaper", "motion"],
         ["grey", "gray", "pale", "white", "chalky", "clay", "blood", "bloody", "black", "red"]),
        (["lip", "lips", "skin", "face", "finger", "tongue"],
         ["blue", "bluish", "grey", "gray", "purple"]),
        (["breath", "breathing", "breathe"],
         ["not", "stop", "stopped", "struggling", "difficulty", "laboured", "labored", "fast"]),
        (["vomit", "vomiting", "sick"],
         ["blood", "bloody", "green", "bile", "projectile"]),
        (["rash"],
         ["fade", "fades", "spreading", "purple", "bruise"]),
        (["head"],
         ["injury", "bang", "banged", "knock", "knocked", "fell", "fall"]),
        (["fever", "temperature"],
         ["newborn", "weeks", "high", "stiff"]),
        (["wake", "waking", "rouse"],
         ["not", "won't", "cannot", "can't", "difficult"])
    ]

    /// Physical health generally. A pediatrician question, not an urgent one.
    static let healthTerms: Set<String> = [
        "poop", "poo", "stool", "nappy", "diaper", "constipated", "constipation",
        "diarrhoea", "diarrhea", "vomit", "vomiting", "reflux", "rash", "eczema",
        "fever", "temperature", "cough", "cold", "flu", "teething", "tooth",
        "teeth", "ear", "earache", "infection", "allergy", "allergic", "wheeze",
        "asthma", "snore", "snoring", "eye", "squint", "weight", "growth",
        "height", "vaccine", "vaccination", "jab", "medicine", "antibiotic",
        "colic", "hernia", "birthmark", "bruise", "swollen", "lump", "pain",
        "hurt", "sore", "bleeding", "burn", "choking"
    ]

    /// Genuine parenting questions this app does not cover. Answering them
    /// honestly is better than pretending, and better than silence.
    static let parentingTerms: Set<String> = [
        "sleep", "asleep", "nap", "napping", "bedtime", "cot", "crib", "swaddle",
        "dummy", "pacifier", "wean", "weaning", "breastfeed", "breastfeeding",
        "bottle", "formula", "milk", "solids", "puree", "snack", "mealtime",
        "fussy", "potty", "toilet", "training", "nappyfree", "discipline",
        "punishment", "timeout", "screen", "tv", "tablet", "ipad", "youtube",
        "sibling", "nursery", "daycare", "childminder", "school", "travel",
        "flight", "carseat", "safety", "vitamin", "supplement"
    ]

    /// Scope, plus the word that decided it so the reply can name the subject
    /// back to the parent rather than answering in the abstract.
    struct Result: Equatable {
        let scope: QuestionScope
        let matchedTerm: String?
    }

    static func detect(tokens: [QuestionParser.Token], hasDomain: Bool) -> Result {
        let surfaces = Set(tokens.map(\.surface))
        let lemmas = Set(tokens.map(\.lemma))
        let all = surfaces.union(lemmas)

        // Urgent wins outright, including over a developmental match. A question
        // that mentions both walking and blood in a nappy is not a walking
        // question.
        for term in urgentSingleTerms where all.contains(term) {
            return Result(scope: .urgentHealthSymptom, matchedTerm: term)
        }
        for (subjects, qualifiers) in urgentPairs {
            if let subject = subjects.first(where: { all.contains($0) }),
               !qualifiers.isDisjoint(with: all) {
                return Result(scope: .urgentHealthSymptom, matchedTerm: subject)
            }
        }

        // A developmental signal wins over the softer lists: "is she eating
        // enough to grow" scores Gross Motor on nothing, but "she points at
        // food instead of asking" is a language question that happens to
        // mention food.
        if hasDomain { return Result(scope: .developmental, matchedTerm: nil) }

        if let term = firstMatch(in: healthTerms, from: tokens) {
            return Result(scope: .healthSymptom, matchedTerm: term)
        }
        if let term = firstMatch(in: parentingTerms, from: tokens) {
            return Result(scope: .parentingTopic, matchedTerm: term)
        }
        return Result(scope: .unclear, matchedTerm: nil)
    }

    /// First in the order the parent wrote them, so the named subject is the one
    /// they led with.
    private static func firstMatch(in set: Set<String>, from tokens: [QuestionParser.Token]) -> String? {
        for token in tokens {
            if set.contains(token.lemma) { return token.lemma }
            if set.contains(token.surface) { return token.surface }
        }
        return nil
    }
}
