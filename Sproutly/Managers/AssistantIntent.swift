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

// MARK: - Question Kind

/// What the parent is asking *for*, as distinct from what they are asking
/// *about*.
///
/// The engine scored a domain and then gave every question the same three-part
/// answer: a framing sentence, a catalog tip, three activities. So "when should
/// she put words together", "what can I do to help her talk", and "should I be
/// worried she isn't talking" all came back in the same shape, and the first of
/// those never answered with a time at all, even though the catalog knows it.
enum QuestionKind: Equatable {
    /// "when should…", "at what age…", "how old before…"
    case when
    /// "what can I do…", "how do I help…", "any tips…"
    case howToHelp
    /// "should I be worried…", "is this a problem…"
    case shouldIWorry
    /// "is it normal that…", "is it ok that…"
    case isThisNormal
    /// "what comes next…", "what should I expect…"
    case whatsNext
    case general

    /// True when the question is about what the child is doing now rather than
    /// what is coming.
    ///
    /// A timing question about a four-month-old ("when should she start
    /// walking") is ordinary and forward-looking. A statement that a
    /// four-month-old walks is a contradiction worth surfacing. `howToHelp` is
    /// deliberately on the forward side: "what can I do to help him walk" asked
    /// early is answered well by the precursors to walking.
    var assertsPresentCapability: Bool {
        switch self {
        case .when, .whatsNext, .howToHelp: return false
        case .general, .shouldIWorry, .isThisNormal: return true
        }
    }
}

// MARK: - Parsed Question

struct AssistantIntent {
    /// Content words reduced by `QuestionParser.stem`, stopwords removed. The
    /// retrieval layer scores against these rather than against the raw string.
    /// They are lookup keys, not words — never show one to a parent.
    let stems: [String]
    let domainScores: [MilestoneCategory: Double]
    let topDomain: MilestoneCategory?
    let concern: QuestionConcern
    let kind: QuestionKind
    let scope: QuestionScope
    /// The word that decided an out-of-scope answer, so the reply can name the
    /// subject back rather than refusing in the abstract.
    let scopeTerm: String?

    /// True when nothing in the question named a domain or a topic we recognise.
    var isUnfocused: Bool { topDomain == nil }
    var isDevelopmental: Bool { scope == .developmental }
}

// MARK: - Question Parser

/// Turns a parent's sentence into stems, a domain distribution, and a concern
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

    /// Base forms, matched whole and never as substrings. Entries are written in
    /// their base form only: `stem` reduces both these and the question, so the
    /// inflections a parent types are reached without listing them here.
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

    // MARK: Question kind

    /// Matched on phrases rather than lemmas. These are grammatical shapes, not
    /// vocabulary, and "what can I" is not recoverable from a bag of words.
    static func kind(of question: String) -> QuestionKind {
        let text = " " + question.lowercased()
            .replacingOccurrences(of: "'", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'") + " "

        func any(_ phrases: [String]) -> Bool {
            phrases.contains { text.contains($0) }
        }

        // Order is deliberate. A worried question that opens "is it normal that
        // she still isn't walking, should I be concerned" is a worry question,
        // so worry is tested before normality.
        if any(["should i worry", "should i be worried", "should i be concerned",
                "am i right to worry", "is this a problem", "is that a problem",
                "red flag", "something wrong", "is something wrong"]) {
            return .shouldIWorry
        }
        if any(["what age", "at what age", "how old", "when should", "when will",
                "when do ", "when does", "by when", "how soon", "what point"]) {
            return .when
        }
        if any(["what can i", "what should i do", "how can i", "how do i",
                "what do i do", "any tips", "how to help", "help her", "help him",
                "help them", "encourage", "what activities", "things to try"]) {
            return .howToHelp
        }
        if any(["what next", "what's next", "whats next", "what comes next",
                "what comes after", "what should i expect", "what happens next",
                "after this", "what follows"]) {
            return .whatsNext
        }
        if any(["is it normal", "is this normal", "is that normal", "is it ok",
                "is that ok", "is it okay", "is that okay", "normal for",
                "common for", "usual for"]) {
            return .isThisNormal
        }
        return .general
    }

    // MARK: Tokenising

    /// A word plus its lemma. Both are kept: negation reads the surface form
    /// ("n't"), scoring reads the lemma ("walking" and "walks" both score once).
    struct Token {
        /// The word as the parent wrote it. Negation reads this ("n't"), and it
        /// is the only form ever shown back to them.
        let surface: String
        /// The matching key. Everything that compares against a lexicon uses
        /// this, and it is computed in-process on every platform. See `stem`.
        let stem: String
    }

    static func tokenize(_ text: String) -> [Token] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        // `.tokenType`, not `.lemma`. This call only needs word boundaries, and
        // tokenisation is one of the three schemes present on every iOS
        // destination; asking for `.lemma` here invited the silent degradation
        // documented on `stem` below.
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = text
        var tokens: [Token] = []

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .tokenType,
            options: [.omitPunctuation, .omitWhitespace]
        ) { _, range in
            let surface = text[range].lowercased()
            tokens.append(Token(surface: surface, stem: stem(surface)))
            return true
        }
        return tokens
    }

    // MARK: Stemming

    /// Why this exists, and why it is not `NLTagger`'s `.lemma`.
    ///
    /// `.lemma` is not dependable on iOS. Measured, not assumed:
    ///
    ///     NLTagger.availableTagSchemes(for: .word, language: .english)
    ///     simulator 26.4 / 26.5 / 27.0 -> ["Language", "Script", "TokenType"]
    ///     device, first cold run       -> ["Language", "Script", "TokenType"]
    ///     device, once warm            -> [..., "LexicalClass", "Lemma"]
    ///     macOS host                   -> [..., "LexicalClass", "Lemma"]
    ///
    /// On the simulator the lemma dictionary is simply never there: every tag
    /// is nil on every runtime, `setLanguage(.english,)` does not change it,
    /// and the older `NSLinguisticTagger` is nil too. On real hardware
    /// (iPhone17,1 / iOS 27.0) it is worse than absent — it is *late*. The
    /// first run after install returned nil for every word; a few runs later
    /// the same binary on the same phone returned "walks" -> "walk" and
    /// "ran" -> "run". The asset loads on demand.
    ///
    /// That is the whole bug. Nothing crashed and nothing logged; the parser
    /// just fell back to exact-word matching, so "walks" missed the lexicon
    /// entry "walk", no domain scored, and the assistant answered every
    /// question with its unfocused fallback. A parent's first questions after
    /// installing — the ones that decide whether they trust this app — got the
    /// degraded answers, and later ones silently got better.
    ///
    /// `availableTagSchemes` is no good as a guard either: on device it
    /// reported `LexicalClass` missing on one call and present seconds later.
    /// It describes what is loaded right now, not what is obtainable, so a
    /// check against it would be racing the same asset load.
    ///
    /// So matching does not depend on a lemma at all. This does the job in
    /// pure Swift, with the same answer on every platform, cold or warm. It is
    /// a matching key and not a dictionary word: "babble" and "babbling" both
    /// reduce to "babbl", which is meaningless to a reader and exactly right
    /// for a lookup. The only rule that matters is that both sides of a
    /// comparison go through this same function, so the lexicons below are
    /// stemmed too and never have to list inflections by hand.
    /// Never show a stem to a parent.
    static func stem(_ word: String) -> String {
        let lower = word.lowercased()
        guard lower.count > 2 else { return irregularStems[lower] ?? lower }

        var stripped = false
        var value: String

        if let irregular = irregularStems[lower] {
            value = irregular
        } else {
            (value, stripped) = stripInflection(lower)
        }

        // Undo the consonant a suffix doubled: "stopped" -> "stopp" -> "stop".
        // Only after a strip, and only for the consonants English actually
        // doubles, so a genuine double survives: "falling" -> "fall", not "fal".
        if stripped, value.count > 3 {
            let last = value.suffix(2)
            if last.count == 2, let char = last.first, last.first == last.last,
               "bdgmnprt".contains(char) {
                value = String(value.dropLast())
            }
        }

        // "babble" and "babbling" have to land together, so the silent "e" goes.
        if value.count > 3, value.hasSuffix("e") {
            value = String(value.dropLast())
        }
        return value
    }

    /// Strips one inflection. Returns the stem and whether anything came off.
    private static func stripInflection(_ word: String) -> (String, Bool) {
        func shorten(_ count: Int, adding suffix: String = "") -> String? {
            let result = String(word.dropLast(count)) + suffix
            return result.count >= 3 ? result : nil
        }

        if word.hasSuffix("ing"), let result = shorten(3) { return (result, true) }
        if word.hasSuffix("ied"), let result = shorten(3, adding: "y") { return (result, true) }
        if word.hasSuffix("ed"), let result = shorten(2) { return (result, true) }
        if word.hasSuffix("ies"), let result = shorten(3, adding: "y") { return (result, false) }
        for ending in ["sses", "shes", "ches", "xes", "zes"] where word.hasSuffix(ending) {
            if let result = shorten(2) { return (result, false) }
        }
        if word.hasSuffix("s"), !word.hasSuffix("ss"), !word.hasSuffix("us"),
           !word.hasSuffix("is"), let result = shorten(1) {
            return (result, false)
        }
        return (word, false)
    }

    /// Forms no suffix rule reaches. Kept to the ones a parent actually writes
    /// about a small child. Each value is run through the rest of `stem`, so it
    /// is spelled as an ordinary word rather than as a stem.
    static let irregularStems: [String: String] = [
        "is": "be", "are": "be", "was": "be", "were": "be", "am": "be",
        "been": "be", "being": "be", "has": "have", "had": "have",
        "does": "do", "did": "do", "went": "go", "gone": "go",
        "ran": "run", "run": "run", "fell": "fall", "fallen": "fall",
        "sat": "sit", "stood": "stand", "said": "say", "spoke": "speak",
        "spoken": "speak", "threw": "throw", "thrown": "throw",
        "drew": "draw", "drawn": "draw", "held": "hold", "fed": "feed",
        "took": "take", "taken": "take", "gave": "give", "given": "give",
        "ate": "eat", "eaten": "eat", "slept": "sleep", "built": "build",
        "caught": "catch", "taught": "teach", "brought": "bring",
        "thought": "think", "understood": "understand", "made": "make",
        "got": "get", "knew": "know", "known": "know", "grew": "grow",
        "grown": "grow", "began": "begin", "begun": "begin",
        "children": "child", "feet": "foot", "teeth": "tooth",
        "men": "man", "women": "woman", "mice": "mouse", "people": "person",
        "lost": "lose", "left": "leave", "heard": "hear", "kept": "keep",
        "slid": "slide", "woke": "wake", "woken": "wake", "bit": "bite",
        "bitten": "bite", "hid": "hide", "hidden": "hide"
    ]

    /// The lexicons above, reduced with `stem` so a question and a lexicon entry
    /// are compared on the same footing.
    static let domainLexiconStems: [MilestoneCategory: Set<String>] = domainLexicon
        .mapValues { Set($0.map(stem)) }
    static let concernStems: Set<String> = Set(concernLemmas.map(stem))
    static let stopwordStems: Set<String> = Set(stopwords.map(stem))

    // MARK: Parsing

    static func parse(_ question: String) -> AssistantIntent {
        let tokens = tokenize(question)
        guard !tokens.isEmpty else {
            return AssistantIntent(
                stems: [], domainScores: [:], topDomain: nil, concern: .none,
                kind: .general, scope: .unclear, scopeTerm: nil
            )
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
                negators.contains($0.surface) || negators.contains($0.stem)
            }

            for (category, lexicon) in domainLexicon {
                guard lexicon.contains(token.surface)
                        || domainLexiconStems[category]?.contains(token.stem) == true else { continue }
                // A negated mention is a stronger signal of what the question is
                // about, not a weaker one. "isn't walking" is more about gross
                // motor than "walking" alone.
                scores[category, default: 0] += negated ? 3 : 2
                if negated { negatedHit = true }
            }
        }

        let concern = concernLevel(tokens: tokens, negatedDomainHit: negatedHit)

        // Stems, not lemmas: retrieval compares these against milestone text run
        // through the same `stem`, so "is she walking" reaches a title that says
        // "Walks a few steps". Only ever used for matching and for the composer's
        // deterministic seed, never shown to a parent.
        let stems = tokens
            .map(\.stem)
            .filter { !stopwordStems.contains($0) && $0.count > 1 }

        let topDomain = resolveTopDomain(scores)

        // Scope is decided before anything else is used. An urgent sign
        // outranks a developmental match outright: a question mentioning both
        // walking and blood in a nappy is not a walking question.
        let scope = ScopeDetector.detect(tokens: tokens, hasDomain: topDomain != nil)

        return AssistantIntent(
            stems: stems,
            domainScores: scope.scope == .developmental ? scores : [:],
            topDomain: scope.scope == .developmental ? topDomain : nil,
            concern: concern,
            kind: kind(of: question),
            scope: scope.scope,
            scopeTerm: scope.matchedTerm
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
        for token in tokens where concernLemmas.contains(token.surface)
            || concernStems.contains(token.stem) {
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
