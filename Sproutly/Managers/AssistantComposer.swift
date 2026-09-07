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
            domain: intent.topDomain
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
            // Nothing to work with is different from a broad question, and
            // answering confidently about nothing is how the old engine sounded
            // generic. Ask for one more detail instead.
            if intent.lemmas.isEmpty {
                return FramingBank.needsMore
            }
            return pick(FramingBank.unfocused, seed: seed) ?? FramingBank.unfocused[0]
        }

        var sentences: [String] = []

        if let framing = pick(FramingBank.framing(domain: domain, band: band(for: correctedAge)), seed: seed) {
            sentences.append(framing)
        }

        // The written line attached to the milestone this question actually
        // matched. This is what makes two questions about the same area read
        // differently, and it is catalog content rather than anything asserted
        // about the child.
        // Only quote a milestone that is actually about what was asked. A row
        // that merely shares a development area says nothing the framing line
        // has not already said, and reads as a non-sequitur.
        let topical = retrieved.first {
            !$0.tip.isEmpty && AssistantRetriever.isTopical($0, intent: intent)
        }
        if let tip = topical?.tip {
            sentences.append(tip)
        }

        // Milestone titles are third-person labels ("Says 10-25 words"), so they
        // do not survive being folded into a sentence. They are handed to the
        // view as `cited` and listed, which is also how the rest of the app
        // shows them.
        return sentences.isEmpty
            ? (pick(FramingBank.unfocused, seed: seed) ?? FramingBank.unfocused[0])
            : sentences.joined(separator: " ")
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
