//
//  AssistantComposer.swift
//  Sproutly
//

import Foundation

// MARK: - Response

struct AssistantResponse: Equatable {
    let context: String
    let activities: [String]
    let pediatricNote: String?

    /// The milestones the answer was built from. Surfaced so a parent can see
    /// what the reply is grounded in, and so a test can assert an answer cites
    /// the right things rather than only that it returned some prose.
    let cited: [MilestoneReference]
    let domain: MilestoneCategory?

    /// Whether this was a question Sproutly is for. The view uses it to know an
    /// answer is a redirect rather than guidance.
    let scope: QuestionScope
    let kind: QuestionKind
}

// MARK: - Composer

/// Builds the reply out of retrieved milestones and the child's saved progress.
///
/// Two rules this follows that the previous engine did not.
///
/// **The same question gives the same answer.** The old responses picked their
/// context with `randomElement()` and their activities with `shuffled()`, and
/// for two of the five domains the activity array held exactly three items, so
/// `shuffled().prefix(3)` returned all of them in a new order every time. Asking
/// twice produced a reshuffle rather than a reply. Variety here comes from the
/// question changing, not from a die roll, which is also the only way a parent
/// can trust what they read.
///
/// **Nothing is asserted about the child.** Everything specific in a reply is
/// either catalog content or something the parent themselves saved.
enum AssistantComposer {

    static func compose(
        intent: AssistantIntent,
        retrieved: [MilestoneReference],
        observation: DomainObservation?,
        correctedAge: Int
    ) -> AssistantResponse {

        // A question outside milestones is answered as one, not scored against
        // five developmental domains until something sticks.
        guard intent.isDevelopmental else {
            return outOfScope(intent: intent, correctedAge: correctedAge)
        }

        let seed = deterministicSeed(for: intent)

        let context = composeContext(
            intent: intent,
            retrieved: retrieved,
            correctedAge: correctedAge,
            seed: seed
        )

        let activities = composeActivities(
            domain: intent.topDomain,
            retrieved: retrieved,
            correctedAge: correctedAge,
            seed: seed
        )

        let note = pediatricNote(
            intent: intent,
            observation: observation,
            correctedAge: correctedAge
        )

        return AssistantResponse(
            context: context,
            activities: activities,
            pediatricNote: note,
            cited: retrieved,
            domain: intent.topDomain,
            scope: intent.scope,
            kind: intent.kind
        )
    }

    // MARK: Out of scope

    /// Sproutly covers developmental milestones and nothing else, and the input
    /// invites anything. Saying so plainly is the whole feature here: a parent
    /// who gets an honest "not this, but here is who to ask" keeps trusting the
    /// app, and a parent who gets a paragraph about writing things down does not.
    private static func outOfScope(intent: AssistantIntent, correctedAge: Int) -> AssistantResponse {
        let context: String
        let note: String?

        switch intent.scope {
        case .urgentHealthSymptom:
            // Never named, never explained, only routed faster. This app is
            // Lifestyle and must not suggest what a sign means. What it can do
            // is not waste the moment.
            context = "Sproutly is about developmental milestones, so it cannot help with this one."
            note = "What you are describing is worth speaking to a doctor about today rather than waiting for the next visit. If you cannot reach your pediatrician, an urgent care service or your local emergency number is the right next step."

        case .healthSymptom:
            let subject = intent.scopeTerm.map { "questions about \($0) are" } ?? "this is"
            context = "Sproutly only covers developmental milestones, so \(subject) outside what it can answer."
            note = "Anything to do with how your child is physically doing is one for your pediatrician, and they would far rather hear about it early than late."

        case .parentingTopic:
            let subject = intent.scopeTerm.map { "\($0)" } ?? "that"
            context = "Sproutly does not cover \(subject). What it follows is the five areas of development: Movement & Strength, Hands & Coordination, Communication, Curiosity & Thinking, and Connection & Emotion. Ask about any of those and it can be specific about your own child."
            note = nil

        case .unclear, .developmental:
            // Still leaves them with something to do. An answer that is only a
            // request for more information is a dead end.
            // The standing note follows the same age floor as every other
            // judgement in the app: below the first band there is nothing to
            // weigh, and a prompt there is one nobody asked for. An urgent sign
            // is not a judgement and is never gated this way.
            return AssistantResponse(
                context: FramingBank.needsMore,
                activities: Array(ActivityBank.general.prefix(3)),
                pediatricNote: correctedAge >= 2 ? FramingBank.standingPediatricNote : nil,
                cited: [],
                domain: nil,
                scope: intent.scope,
                kind: intent.kind
            )
        }

        return AssistantResponse(
            context: context,
            activities: [],
            pediatricNote: note,
            cited: [],
            domain: nil,
            scope: intent.scope,
            kind: intent.kind
        )
    }

    // MARK: Determinism

    /// Stable across launches. `hashValue` is seeded per process and would give
    /// the same parent a different answer to the same question tomorrow.
    private static func deterministicSeed(for intent: AssistantIntent) -> Int {
        let basis = intent.lemmas.sorted().joined(separator: " ")
        var hash = 5381
        for byte in basis.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return abs(hash)
    }

    private static func pick<T>(_ options: [T], seed: Int, offset: Int = 0) -> T? {
        guard !options.isEmpty else { return nil }
        return options[(seed &+ offset) % options.count]
    }

    // MARK: Context

    private static func composeContext(
        intent: AssistantIntent,
        retrieved: [MilestoneReference],
        correctedAge: Int,
        seed: Int
    ) -> String {

        guard let domain = intent.topDomain else {
            return pick(FramingBank.unfocused, seed: seed) ?? FramingBank.unfocused[0]
        }

        // Only quote a milestone that is actually about what was asked. A row
        // that merely shares a development area says nothing the framing line
        // has not already said, and reads as a non-sequitur.
        let topical = retrieved.first {
            !$0.tip.isEmpty && AssistantRetriever.isTopical($0, intent: intent)
        }
        let anchor = topical ?? retrieved.first
        let framing = pick(FramingBank.framing(domain: domain, band: band(for: correctedAge)), seed: seed)

        // Milestone titles are third-person labels ("Says 10-25 words"), so they
        // are listed by the view rather than folded into a sentence. The one
        // place a title is quoted is the timing answer, where naming the thing
        // is the answer.
        var sentences: [String] = []

        switch intent.kind {
        case .when:
            // The old engine never answered this. A parent asking when got a
            // paragraph about how ranges vary, which is true and useless.
            if let anchor {
                sentences.append("\(anchor.title) usually shows up around \(ageText(anchor.ageMonth)).")
                sentences.append("Ranges are wide here, so a few months either side of that is ordinary rather than late.")
            } else if let framing {
                sentences.append(framing)
            }

        case .howToHelp:
            // They asked what to do. The activities are the answer, so the prose
            // gets out of the way instead of restating the domain first.
            if let tip = topical?.tip {
                sentences.append(tip)
            } else if let framing {
                sentences.append(framing)
            }

        case .whatsNext:
            if let anchor {
                sentences.append("The next one along these lines is usually \(lowercasedFirst(anchor.title)), around \(ageText(anchor.ageMonth)).")
                if let framing { sentences.append(framing) }
            } else {
                // Nothing ahead in this area, either because the child has
                // reached the end of the catalog or the question was narrow.
                sentences.append("Sproutly does not list anything further in this area for your child's age yet.")
                if let framing { sentences.append(framing) }
            }

        case .shouldIWorry, .isThisNormal:
            if let framing { sentences.append(framing) }
            if let anchor {
                sentences.append("For what it is worth, \(lowercasedFirst(anchor.title)) sits at \(ageText(anchor.ageMonth)) in the usual range, and that range is wide.")
            }
            if let tip = topical?.tip { sentences.append(tip) }

        case .general:
            if let framing { sentences.append(framing) }
            if let tip = topical?.tip { sentences.append(tip) }
        }

        return sentences.isEmpty
            ? (pick(FramingBank.unfocused, seed: seed) ?? FramingBank.unfocused[0])
            : sentences.joined(separator: " ")
    }

    /// Prose form, not the compact `expectedAgeText` the milestone rows use.
    static func ageText(_ months: Int) -> String {
        if months < 24 { return "\(months) months" }
        let years = months / 12
        let remainder = months % 12
        if remainder == 0 { return years == 1 ? "a year" : "\(years) years" }
        return "\(years) and a half"
    }

    private static func lowercasedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }

    static func band(for correctedAge: Int) -> ActivityBank.Band {
        correctedAge < 12 ? .infant : correctedAge < 24 ? .toddler : .preschool
    }

    // MARK: Activities

    private static func composeActivities(
        domain: MilestoneCategory?,
        retrieved: [MilestoneReference],
        correctedAge: Int,
        seed: Int
    ) -> [String] {

        guard let domain else {
            return Array(ActivityBank.general.rotated(by: seed).prefix(3))
        }

        let pool = ActivityBank.activities(domain: domain, band: band(for: correctedAge))
        return Array(pool.rotated(by: seed).prefix(3))
    }

    // MARK: Pediatric note

    private static func pediatricNote(
        intent: AssistantIntent,
        observation: DomainObservation?,
        correctedAge: Int
    ) -> String? {

        // Below the first band there is nothing to judge against, and a note
        // here would be a prompt nobody asked for.
        guard correctedAge >= 2 else { return nil }

        let statusWarrants = observation.map {
            $0.status == .worthDiscussing || $0.status == .needsSupport
        } ?? false

        let shouldNote = intent.concern == .significant
            || (intent.concern == .mild && statusWarrants)
            || (observation?.status == .worthDiscussing)

        guard shouldNote else {
            return intent.isUnfocused
                ? "If anything is on your mind, your pediatrician is the right person to ask. Well-child visits are a good time for it, and you do not have to wait for one."
                : nil
        }

        switch intent.topDomain {
        case .language:
            return "If speech is on your mind, bring it to your pediatrician. Speech and hearing checks are routine, and you do not have to wait for a visit that is already booked."
        case .grossMotor:
            return "If how your child moves is on your mind, bring it to your pediatrician. Describing what you have seen at home is the useful part."
        case .fineMotor:
            return "If hand skills are on your mind, mention it at your next visit. Your pediatrician can suggest things to try, or refer you if that would help."
        case .cognitive:
            return "If how your child is working things out is on your mind, bring it to your pediatrician. Well-child visits are a good place for it, and you can ask sooner."
        case .socialEmotional:
            return "If a behavior is worrying you or happening often, describe it to your pediatrician: what happens, how often, and what usually comes before it. That detail is what helps."
        case .none:
            return "If anything is on your mind, your pediatrician is the right person to ask. Well-child visits are a good time for it, and you do not have to wait for one."
        }
    }

    // MARK: Phrasing helpers

}

// MARK: - Rotation

private extension Array {
    /// Deterministic reordering. Rotating rather than shuffling keeps the
    /// author's ordering intact within a reply while still letting two different
    /// questions open with different suggestions.
    func rotated(by amount: Int) -> [Element] {
        guard !isEmpty else { return self }
        let offset = amount % count
        return Array(self[offset...] + self[..<offset])
    }
}
