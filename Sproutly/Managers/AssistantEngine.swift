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

        let retrieved = AssistantRetriever.retrieve(
            intent: intent,
            milestones: milestones,
            correctedAge: correctedAge,
            excludedBands: excludedBands
        )

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
