//
//  AssistantEngine.swift
//  Sproutly
//

import Foundation

/// Ask Sproutly's core. Pure and testable, in the same shape as
/// `DevelopmentObserver`, and with no network call of any kind.
///
/// Pipeline: parse the question, retrieve the milestones it is about, read this
/// child's saved progress through the observer every other screen already uses,
/// and compose a reply from those three things.
enum AssistantEngine {

    static func respond(
        to question: String,
        milestones: [Milestone],
        correctedAge: Int,
        excludedBands: Set<Int> = []
    ) -> AssistantResponse {

        let intent = QuestionParser.parse(question)

        // "What comes next" is the one question asked about an age the child
        // has not reached, so the retrieval window moves with it.
        let retrievalAge = intent.kind == .whatsNext ? correctedAge + 6 : correctedAge

        var retrieved = AssistantRetriever.retrieve(
            intent: intent,
            milestones: milestones,
            correctedAge: retrievalAge,
            excludedBands: excludedBands
        )

        // "What comes after crawling" named crawling, so crawling matched best
        // and came back as the answer. A forward-looking question must not be
        // answered with the thing it was asked about.
        // Strict, with no fall back to the unfiltered list. If there is nothing
        // ahead in this area, citing what the child has already reached as
        // "next" is worse than citing nothing, and the composer handles an
        // empty anchor.
        if intent.kind == .whatsNext {
            retrieved = retrieved.filter { $0.ageMonth > correctedAge }
        }

        // Progress is read through `DevelopmentObserver` rather than recounted
        // here. The old engine kept its own ratio, and it disagreed with the
        // rest of the app in four ways: it counted parent-authored milestones,
        // it ignored `CatalogBaseline` exclusions, it used a `+2` month window
        // where the observer uses the child's actual age, and it had no age
        // floor. So a catalog update could leave the Dashboard saying a domain
        // was on track while this screen suggested seeing a pediatrician about
        // it, for the same child on the same day.
        let observation = intent.topDomain.flatMap { domain in
            DevelopmentObserver.observe(
                milestones: milestones,
                correctedAge: correctedAge,
                excludedBands: excludedBands
            ).first { $0.category == domain }
        }

        return AssistantComposer.compose(
            intent: intent,
            retrieved: retrieved,
            observation: observation,
            correctedAge: correctedAge
        )
    }
}
