//
//  AssistantIntent.swift
//  Sproutly
//

import Foundation
import NaturalLanguage

// MARK: - Concern Level

/// How worried the wording itself sounds, independent of what the saved
/// milestones say. A parent can ask an anxious question about a domain that is
/// entirely on track, and can ask a neutral one about a domain that is not.
enum QuestionConcern: Int, Comparable {
    case none = 0
    case mild = 1
    case significant = 2

    static func < (lhs: QuestionConcern, rhs: QuestionConcern) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Parsed Question

struct AssistantIntent {
    /// Lemmatised content words, stopwords removed. The retrieval layer scores
    /// against these rather than against the raw string.
    let lemmas: [String]
    let domainScores: [MilestoneCategory: Double]
    let topDomain: MilestoneCategory?
    let concern: QuestionConcern

    /// True when nothing in the question named a domain or a topic we recognise.
    var isUnfocused: Bool { topDomain == nil }
}

// MARK: - Question Parser

/// Turns a parent's sentence into lemmas, a domain distribution, and a concern
/// level.
///
/// Replaces a `token.contains(keyword)` table. Substring matching routed
/// "appointment" to Language (it contains "point") and "visit" to Gross Motor
/// (it contains "sit"), and the previous tie-break read `Dictionary.max`, whose
/// order is not stable — the same sentence could score two domains equally and
/// pick a different one on the next launch.
enum QuestionParser {

    // MARK: Lexicon
    //
    // Curated rather than learned, on purpose. `NLEmbedding.wordEmbedding` was
    // tried here first and measured on device: related pairs came back at
    // walk~crawl 1.058, word~speak 1.051, meltdown~tantrum 1.090, but
    // point~gesture 1.272 — while unrelated pairs sat at visit~sit 1.196 and
    // appointment~walk 1.221. The two distributions overlap, so no threshold
    // separates them, and the nearest neighbours of "meltdown" are "imploding,
    // fallout, nosedive, woe". It is a general news-corpus embedding with no
    // notion of child development, and any setting loose enough to catch
    // point~gesture also reinstates the visit/sit false match this table exists
    // to remove. `NLContextualEmbedding` (iOS 17+, sentence level, needs an
    // async asset download) is a different API and is the one worth revisiting.

    /// Lemma forms, matched whole. Never substrings.
    static let domainLexicon: [MilestoneCategory: Set<String>] = [
        .grossMotor: [
            "walk", "crawl", "stand", "run", "sit", "roll", "step", "climb",
            "jump", "balance", "cruise", "scoot", "kick", "throw", "toddle",
            "leg", "knee", "foot", "posture", "wobble", "unsteady", "waddle",
            "stagger", "tumble", "hop", "skip", "pedal", "stair", "crawling",
            "upright", "steady", "clumsy", "trip", "fall"
        ],
        .fineMotor: [
            "grab", "grasp", "pinch", "stack", "draw", "scribble", "write",
            "scissors", "hand", "finger", "thumb", "spoon", "fork", "cup",
            "button", "zip", "block", "brick", "lego", "bead", "thread",
            "crayon", "pencil", "pen", "doodle", "grip", "cutlery", "feed",
            "dexterity", "fiddly", "peg", "sticker"
        ],
        .language: [
            "talk", "speak", "speech", "word", "babble", "language",
            "say", "sound", "sentence", "vocabulary", "name", "chat",
            "communicate", "gesture", "wave", "point", "sign", "verbal",
            "pronounce", "stutter", "mute", "silent", "vocal", "chatter",
            "jabber", "mumble", "mutter", "babbling", "talking", "express",
            "repeat", "phrase", "vocab", "speaking", "understandable"
        ],
        .cognitive: [
            "think", "learn", "count", "colour", "color", "shape", "pretend",
            "understand", "memory", "attention", "focus", "concentrate",
            "curious", "explore", "problem", "sort", "match", "letter",
            "number", "reason", "jigsaw", "remember", "recognise", "recognize",
            "imagine", "question", "concentration", "puzzled", "figure",
            "curiosity", "attentive"
        ],
        .socialEmotional: [
            "social", "friend", "emotion", "cry", "tantrum", "share", "anxious",
            "scared", "behaviour", "behavior", "aggressive", "hit", "shy",
            "angry", "bite", "tempered", "meltdown", "cuddle", "affection",
            "attach", "separation", "mood", "frustrated", "eye", "contact",
            "meltdown", "upset", "clingy", "cling", "whine", "whinge", "scream",
            "moody", "bossy", "jealous", "hug", "kiss", "comfort", "settle",
            "dropoff", "nursery", "daycare", "playgroup", "tempers", "sulk",
            "withdraw", "distress"
        ]
    ]

    /// Words that make a sentence sound worried. Matched as whole lemmas.
    static let concernLemmas: Set<String> = [
        "worried", "worry", "concerned", "concern", "delayed", "delay",
        "behind", "struggle", "struggling", "late", "slow", "lacking",
        "problem", "wrong", "abnormal", "regress", "lost", "stopped",
        "scared", "anxious", "afraid", "normal"
    ]

    /// Negators. "still" is deliberately absent: it reads as concern in "still
    /// isn't walking" but as delight in "still loves that book", and the
    /// previous engine counted both.
    static let negators: Set<String> = [
        "not", "n't", "never", "no", "cannot", "can't", "won't", "doesn't",
        "isn't", "hasn't", "didn't", "haven't", "without"
    ]

    static let stopwords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "if", "is", "are", "was", "were",
        "be", "been", "being", "do", "does", "did", "have", "has", "had", "i",
        "my", "me", "we", "our", "you", "your", "he", "she", "it", "they",
        "them", "his", "her", "its", "their", "this", "that", "these", "those",
        "to", "of", "in", "on", "at", "for", "with", "about", "as", "by",
        "from", "so", "than", "then", "there", "here", "what", "when", "where",
        "who", "how", "why", "which", "should", "would", "could", "will",
        "can", "just", "very", "much", "some", "any", "all", "only", "also",
        "get", "got", "go", "going", "yet", "up", "out", "one", "two", "old",
        "month", "months", "year", "years", "week", "weeks", "day", "days",
        "baby", "child", "kid", "son", "daughter", "toddler", "boy", "girl"
    ]

    // MARK: Tokenising

    /// A word plus its lemma. Both are kept: negation reads the surface form
    /// ("n't"), scoring reads the lemma ("walking" and "walks" both score once).
    struct Token {
        let surface: String
        let lemma: String
    }

    static func tokenize(_ text: String) -> [Token] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        var tokens: [Token] = []

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lemma,
            options: [.omitPunctuation, .omitWhitespace]
        ) { tag, range in
            let surface = text[range].lowercased()
            let lemma = tag?.rawValue.lowercased()
            tokens.append(Token(surface: surface, lemma: (lemma?.isEmpty == false) ? lemma! : surface))
            return true
        }
        return tokens
    }

    // MARK: Parsing

    static func parse(_ question: String) -> AssistantIntent {
        let tokens = tokenize(question)
        guard !tokens.isEmpty else {
            return AssistantIntent(lemmas: [], domainScores: [:], topDomain: nil, concern: .none)
        }

        var scores: [MilestoneCategory: Double] = [:]
        var negatedHit = false

        for (index, token) in tokens.enumerated() {
            // A negator within the three preceding words scopes this one. The
            // window is a clause approximation, not grammar: "isn't walking yet"
            // and "not saying many words" both land, "walks, but isn't eating"
            // does not carry the negation across the comma often enough to matter.
            let windowStart = max(0, index - 3)
            let negated = tokens[windowStart..<index].contains {
                negators.contains($0.surface) || negators.contains($0.lemma)
            }

            for (category, lexicon) in domainLexicon {
                guard lexicon.contains(token.lemma) || lexicon.contains(token.surface) else { continue }
                // A negated mention is a stronger signal of what the question is
                // about, not a weaker one. "isn't walking" is more about gross
                // motor than "walking" alone.
                scores[category, default: 0] += negated ? 3 : 2
                if negated { negatedHit = true }
            }
        }

        let concern = concernLevel(tokens: tokens, negatedDomainHit: negatedHit)

        let lemmas = tokens
            .map(\.lemma)
            .filter { !stopwords.contains($0) && $0.count > 1 }

        return AssistantIntent(
            lemmas: lemmas,
            domainScores: scores,
            topDomain: resolveTopDomain(scores),
            concern: concern
        )
    }

    /// Highest score wins; ties break on `MilestoneCategory.allCases` order so
    /// the same question always resolves to the same domain.
    static func resolveTopDomain(_ scores: [MilestoneCategory: Double]) -> MilestoneCategory? {
        guard !scores.isEmpty else { return nil }
        let ranked = MilestoneCategory.allCases
            .compactMap { category -> (MilestoneCategory, Double)? in
                guard let score = scores[category], score > 0 else { return nil }
                return (category, score)
            }
            .enumerated()
            .max { lhs, rhs in
                if lhs.element.1 != rhs.element.1 { return lhs.element.1 < rhs.element.1 }
                return lhs.offset > rhs.offset
            }
        return ranked?.element.0
    }

    private static func concernLevel(tokens: [Token], negatedDomainHit: Bool) -> QuestionConcern {
        var signals = 0
        for token in tokens where concernLemmas.contains(token.lemma) || concernLemmas.contains(token.surface) {
            signals += 1
        }
        // "isn't walking" carries worry without using a worry word.
        if negatedDomainHit { signals += 1 }

        switch signals {
        case 0:  return .none
        case 1:  return .mild
        default: return .significant
        }
    }
}
