//
//  AssistantRetriever.swift
//  Sproutly
//

import Foundation

// MARK: - Milestone Reference

/// A milestone flattened to a value, so a composed answer can be asserted in a
/// test without a SwiftData container.
struct MilestoneReference: Equatable {
    let title: String
    let category: MilestoneCategory
    let ageMonth: Int
    let isCompleted: Bool
    let tip: String

    init(_ milestone: Milestone) {
        self.title = milestone.title
        self.category = milestone.categoryType
        self.ageMonth = milestone.ageMonth
        self.isCompleted = milestone.isCompleted
        self.tip = milestone.tips
    }
}

// MARK: - Retriever

/// Finds the milestones a question is actually about.
///
/// This is the layer the previous engine had no equivalent of. It scored a
/// question into one of five domains and then discarded the text, so the answer
/// was a pure function of (domain, age band, concern flag) and the whole app
/// could produce roughly thirty distinct replies. Everything specific a parent
/// typed was thrown away before anything responded to it.
///
/// The catalog is 119 milestones, each with a title and a written tip,
/// paraphrased from CDC "Learn the Signs. Act Early." and cross-checked against
/// the WHO Motor Development Study. That is the knowledge base. This retrieves
/// from it.
enum AssistantRetriever {

    // MARK: Lemma cache

    /// Milestone text changes only when the catalog does, and titles are unique
    /// across it, so lemmatising each one more than once per launch is wasted
    /// work on the main thread while a parent waits.
    nonisolated(unsafe) private static var lemmaCache: [String: Set<String>] = [:]
    nonisolated(unsafe) private static let cacheLock = NSLock()

    private static func lemmas(for text: String) -> Set<String> {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cached = lemmaCache[text] { return cached }

        let computed = Set(
            QuestionParser.tokenize(text)
                .map(\.lemma)
                .filter { !QuestionParser.stopwords.contains($0) && $0.count > 1 }
        )
        lemmaCache[text] = computed
        return computed
    }

    #if DEBUG
    static func resetCache() {
        cacheLock.lock()
        lemmaCache.removeAll()
        cacheLock.unlock()
    }
    #endif

    // MARK: Retrieval

    /// Milestones relevant to the question, most relevant first.
    ///
    /// - Parameters:
    ///   - excludedBands: from `CatalogBaseline`. Bands this child was never
    ///     shown in time are left out for the same reason every other judging
    ///     surface leaves them out.
    static func retrieve(
        intent: AssistantIntent,
        milestones: [Milestone],
        correctedAge: Int,
        excludedBands: Set<Int> = [],
        limit: Int = 4
    ) -> [MilestoneReference] {

        // With no identified subject there is nothing to ground an answer in,
        // and citing the nearest few milestones anyway is how a reply starts
        // looking authoritative about something the parent never raised.
        guard let domain = intent.topDomain else { return [] }

        // Parent-authored moments carry no clinical expectation and are excluded
        // from every other surface that classifies progress. Citations also stay
        // inside the area asked about: a question about words that quotes a row
        // about tantrums has stopped answering the question.
        let candidates = milestones.filter {
            !$0.isUserCreated
                && !excludedBands.contains($0.ageMonth)
                && $0.categoryType == domain
        }
        guard !candidates.isEmpty else { return [] }

        let scored: [(milestone: Milestone, score: Double)] = candidates.compactMap { milestone in
            let score = relevance(
                of: milestone,
                intent: intent,
                correctedAge: correctedAge
            )
            return score > 0 ? (milestone, score) : nil
        }

        // Sort is fully specified. Score, then age closeness to the child, then
        // title, so equal candidates never reorder between runs.
        let ordered = scored.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            let lhsGap = abs(lhs.milestone.ageMonth - correctedAge)
            let rhsGap = abs(rhs.milestone.ageMonth - correctedAge)
            if lhsGap != rhsGap { return lhsGap < rhsGap }
            return lhs.milestone.title < rhs.milestone.title
        }

        return ordered.prefix(limit).map { MilestoneReference($0.milestone) }
    }

    // MARK: Scoring

    /// True when the question and the milestone share a subject, rather than
    /// merely landing in the same area of development.
    ///
    /// Used to decide whether a milestone's written line is worth quoting. A
    /// parent asking about drop-off meltdowns should not be read a note about
    /// following routines just because both are Social-Emotional.
    static func isTopical(_ reference: MilestoneReference, intent: AssistantIntent) -> Bool {
        guard !intent.lemmas.isEmpty else { return false }
        // The title only. A tip is written prose ("Helping tidy up or coming for
        // a bath when asked") whose everyday words match almost any question,
        // which is what let an answer about drop-off meltdowns quote a note
        // about following routines.
        let titleLemmas = lemmas(for: reference.title)
        return intent.lemmas.contains { titleLemmas.contains($0) }
    }

    private static func relevance(
        of milestone: Milestone,
        intent: AssistantIntent,
        correctedAge: Int
    ) -> Double {

        // Asymmetric on purpose. A band the child has already reached is
        // evidence; one still ahead of them is a preview, and answering a
        // 24-month-old's question out of the 30-month band reads as a warning
        // the parent did not ask for.
        let ageGap = milestone.ageMonth - correctedAge
        guard ageGap <= 6, ageGap >= -24 else { return 0 }

        // Two decay curves. Belonging to the right area is only interesting
        // near the child's own age, but a milestone that is genuinely about
        // what was asked stays relevant much further back: a parent asking
        // about tantrums at 30 months wants the 18-month entry on tantrums,
        // not the nearest Social-Emotional row of any subject.
        let ageFactor: Double
        let topicalAgeFactor: Double
        if ageGap > 0 {
            ageFactor = 1.0 - (Double(ageGap) / 8.0)
            topicalAgeFactor = ageFactor
        } else {
            ageFactor = max(0.35, 1.0 - (Double(-ageGap) / 24.0))
            topicalAgeFactor = max(0.75, 1.0 - (Double(-ageGap) / 60.0))
        }
        guard ageFactor > 0 else { return 0 }

        // Belonging to the area the question is about.
        var domainScore = 0.0
        if let top = intent.topDomain, milestone.categoryType == top {
            domainScore = 1.5
        } else if let score = intent.domainScores[milestone.categoryType], score > 0 {
            domainScore = 0.5
        }

        // Being about the same thing the question is about.
        let milestoneLemmas = lemmas(for: "\(milestone.title) \(milestone.tips)")
        var lexicalHits = 0
        for lemma in intent.lemmas where milestoneLemmas.contains(lemma) {
            lexicalHits += 1
        }
        let topicalScore = Double(lexicalHits) * 2.5

        let score = (topicalScore * topicalAgeFactor) + (domainScore * ageFactor)
        return score > 0 ? score : 0
    }
}
