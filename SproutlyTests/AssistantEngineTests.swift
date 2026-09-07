//
//  AssistantEngineTests.swift
//  SproutlyTests
//

import XCTest
@testable import Sproutly

// MARK: - Fixture

private func catalogFixture() -> [Milestone] {
    [
        Milestone(title: "Walks holding onto furniture (cruising)", category: "Gross Motor", ageMonth: 12,
                  tips: "Cruising along furniture is a confident step toward independence."),
        Milestone(title: "May take a few steps independently", category: "Gross Motor", ageMonth: 12,
                  tips: "Anywhere between 9 and 15 months is normal. Try not to compare."),
        Milestone(title: "Says 1-2 simple words like 'mama' or 'dada'", category: "Language", ageMonth: 12,
                  tips: "First words are unforgettable. Keep talking, reading, and singing."),
        Milestone(title: "Uses gestures like waving or pointing", category: "Language", ageMonth: 12,
                  tips: "A wave or point is early communication."),
        Milestone(title: "Puts objects into a container", category: "Fine Motor", ageMonth: 12,
                  tips: "In-and-out play teaches spatial relationships."),
        Milestone(title: "Finds hidden things easily", category: "Cognitive", ageMonth: 12,
                  tips: "Their memory is growing stronger."),
        Milestone(title: "Shows affection to familiar people", category: "Social-Emotional", ageMonth: 12,
                  tips: "Hugs are their way of saying it before they have words."),
        Milestone(title: "Runs with control", category: "Gross Motor", ageMonth: 30,
                  tips: "Stopping and turning is the harder half of running.")
    ]
}

// MARK: - Question parsing

final class QuestionParserTests: XCTestCase {

    /// The previous scorer used `token.contains(keyword)`, so "appointment"
    /// matched the Language keyword "point" and tied with the real Gross Motor
    /// signal from "walking".
    func testAppointmentIsNotReadAsLanguage() {
        let intent = QuestionParser.parse("Should I make an appointment about her walking?")
        XCTAssertEqual(intent.topDomain, .grossMotor)
        XCTAssertNil(intent.domainScores[.language])
    }

    /// "visit" contains "sit", which used to score Gross Motor.
    func testVisitIsNotReadAsGrossMotor() {
        let intent = QuestionParser.parse("Should I bring this up at our next visit?")
        XCTAssertNil(intent.domainScores[.grossMotor])
    }

    func testSubstringCollisionsDoNotScore() {
        // move/movie, hand/handle, run/runny, hit/white, know/known
        let intent = QuestionParser.parse("We watched a movie, I had to handle a runny nose, the white noise helps")
        XCTAssertNil(intent.domainScores[.grossMotor])
        XCTAssertNil(intent.domainScores[.fineMotor])
        XCTAssertNil(intent.domainScores[.socialEmotional])
    }

    /// Inflections should reach the same lexicon entry.
    func testLemmatisationMatchesInflectedForms() {
        for phrasing in ["she is walking", "she walks", "she walked"] {
            XCTAssertEqual(QuestionParser.parse(phrasing).topDomain, .grossMotor, "failed for: \(phrasing)")
        }
    }

    /// `Dictionary.max` has no stable order, so an equal score used to resolve
    /// differently between launches.
    func testTiesResolveDeterministically() {
        let question = "He is walking but not saying words"
        let first = QuestionParser.parse(question).topDomain
        for _ in 0..<50 {
            XCTAssertEqual(QuestionParser.parse(question).topDomain, first)
        }
    }

    func testNegationRaisesConcern() {
        XCTAssertEqual(QuestionParser.parse("She isn't walking yet").concern, .mild)
        XCTAssertEqual(QuestionParser.parse("I'm worried she isn't walking and seems behind").concern, .significant)
    }

    /// "still" reads as concern in "still isn't walking" and as delight in
    /// "still loves that book". The old list counted both.
    func testStillAloneIsNotConcern() {
        XCTAssertEqual(QuestionParser.parse("She still loves that book").concern, .none)
    }

    /// Parents do not write catalog language. These are the words they actually
    /// type, and they are carried by the curated lexicon rather than by a word
    /// embedding, which was measured on device and could not separate
    /// point~gesture from visit~sit.
    func testEverydayParentPhrasingResolves() {
        let cases: [(String, MilestoneCategory)] = [
            ("she isn't chatting much yet", .language),
            ("he jabbers but no real words", .language),
            ("huge meltdowns at nursery drop off", .socialEmotional),
            ("he gets so clingy when I leave", .socialEmotional),
            ("she still wobbles when she toddles about", .grossMotor),
            ("he can't grip a crayon properly", .fineMotor),
            ("she loves a jigsaw now", .cognitive)
        ]
        for (question, expected) in cases {
            XCTAssertEqual(QuestionParser.parse(question).topDomain, expected, "failed for: \(question)")
        }
    }

    func testEmptyQuestionIsUnfocused() {
        let intent = QuestionParser.parse("   ")
        XCTAssertTrue(intent.isUnfocused)
        XCTAssertEqual(intent.concern, .none)
    }
}

// MARK: - Retrieval

final class AssistantRetrieverTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AssistantRetriever.resetCache()
    }

    func testRetrievesMilestonesMatchingTheQuestion() {
        let intent = QuestionParser.parse("When do babies start walking?")
        let hits = AssistantRetriever.retrieve(
            intent: intent, milestones: catalogFixture(), correctedAge: 12
        )
        XCTAssertFalse(hits.isEmpty)
        XCTAssertTrue(hits.allSatisfy { $0.category == .grossMotor })
    }

    /// Parent-authored moments carry no clinical expectation. Every other
    /// surface that classifies progress filters them out; this one did not.
    func testUserCreatedMilestonesAreNeverCited() {
        var milestones = catalogFixture()
        let own = Milestone(title: "First swim", category: "Gross Motor", ageMonth: 12, isUserCreated: true)
        milestones.append(own)

        let intent = QuestionParser.parse("How is her walking and swimming going?")
        let hits = AssistantRetriever.retrieve(intent: intent, milestones: milestones, correctedAge: 12)

        XCTAssertFalse(hits.contains { $0.title == "First swim" })
    }

    /// `CatalogBaseline` bands are excluded from every other judging surface.
    func testExcludedBandsAreNotCited() {
        let intent = QuestionParser.parse("Is she walking on time?")
        let hits = AssistantRetriever.retrieve(
            intent: intent, milestones: catalogFixture(), correctedAge: 12, excludedBands: [12]
        )
        XCTAssertFalse(hits.contains { $0.ageMonth == 12 })
    }

    /// A 12-month-old's question should not surface the 30-month band.
    func testFarFutureMilestonesAreNotCited() {
        let intent = QuestionParser.parse("Is she running yet?")
        let hits = AssistantRetriever.retrieve(intent: intent, milestones: catalogFixture(), correctedAge: 6)
        XCTAssertFalse(hits.contains { $0.ageMonth == 30 })
    }

    /// A question about words that quotes a row about tantrums has stopped
    /// answering the question. The semantic layer matched almost anything before
    /// citations were scoped to the identified area.
    func testCitationsStayInsideTheAskedDomain() {
        for (question, domain) in [
            ("She hasn't said any words yet", MilestoneCategory.language),
            ("what should we be doing with blocks", .fineMotor),
            ("is she walking on time", .grossMotor)
        ] {
            let intent = QuestionParser.parse(question)
            let hits = AssistantRetriever.retrieve(
                intent: intent, milestones: catalogFixture(), correctedAge: 12
            )
            XCTAssertFalse(hits.isEmpty, "no citations for: \(question)")
            XCTAssertTrue(
                hits.allSatisfy { $0.category == domain },
                "\(question) cited outside \(domain.rawValue): \(hits.map(\.title))"
            )
        }
    }

    /// Citing the nearest few milestones for a question with no subject is how a
    /// reply starts sounding authoritative about something never raised.
    func testUnfocusedQuestionCitesNothing() {
        let intent = QuestionParser.parse("I don't really know what to ask")
        XCTAssertTrue(intent.isUnfocused)
        XCTAssertTrue(
            AssistantRetriever.retrieve(intent: intent, milestones: catalogFixture(), correctedAge: 12).isEmpty
        )
    }

    func testRetrievalOrderIsStable() {
        let intent = QuestionParser.parse("Tell me about walking and words")
        let first = AssistantRetriever.retrieve(intent: intent, milestones: catalogFixture(), correctedAge: 12)
        for _ in 0..<20 {
            XCTAssertEqual(
                AssistantRetriever.retrieve(intent: intent, milestones: catalogFixture(), correctedAge: 12),
                first
            )
        }
    }
}

// MARK: - Engine

final class AssistantEngineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AssistantRetriever.resetCache()
    }

    /// The reported symptom. The old engine picked its context with
    /// `randomElement()` and its activities with `shuffled()`, so pressing send
    /// again reshuffled the same words instead of answering.
    func testSameQuestionGivesSameAnswer() {
        let question = "Is it normal that she isn't walking at 12 months?"
        let first = AssistantEngine.respond(
            to: question, milestones: catalogFixture(), correctedAge: 12
        )
        for _ in 0..<25 {
            XCTAssertEqual(
                AssistantEngine.respond(to: question, milestones: catalogFixture(), correctedAge: 12),
                first
            )
        }
    }

    func testDifferentQuestionsGiveDifferentAnswers() {
        let walking = AssistantEngine.respond(
            to: "When should she start walking?", milestones: catalogFixture(), correctedAge: 12
        )
        let words = AssistantEngine.respond(
            to: "She hasn't said any words yet", milestones: catalogFixture(), correctedAge: 12
        )
        XCTAssertNotEqual(walking.context, words.context)
        XCTAssertNotEqual(walking.domain, words.domain)
    }

    /// The whole point of the retrieval layer: the reply names real catalog
    /// content rather than a canned paragraph about the domain.
    func testAnswerCitesRealMilestones() {
        let response = AssistantEngine.respond(
            to: "Should she be walking by now?", milestones: catalogFixture(), correctedAge: 12
        )
        XCTAssertFalse(response.cited.isEmpty)
        XCTAssertTrue(
            response.cited.contains { $0.title.contains("cruising") || $0.title.contains("steps") },
            "answer did not cite a walking milestone: \(response.cited.map(\.title))"
        )
        // The prose is grounded too: the matched milestone's written tip carries
        // through rather than a canned paragraph about the domain.
        XCTAssertTrue(response.context.contains("Cruising") || response.context.contains("9 and 15"))
    }

    func testSavedProgressIsReflectedInTheAnswer() {
        let milestones = catalogFixture()
        milestones.first { $0.title.contains("cruising") }?.isCompleted = true

        let response = AssistantEngine.respond(
            to: "How is her walking coming along?", milestones: milestones, correctedAge: 12
        )
        XCTAssertTrue(
            response.cited.contains { $0.title.contains("cruising") && $0.isCompleted },
            "answer did not carry the parent's saved progress: \(response.cited)"
        )
    }

    /// A calm question about a domain that is on track should not produce a
    /// pediatrician prompt.
    func testNoPediatricNoteWhenOnTrackAndUnworried() {
        let milestones = catalogFixture()
        milestones.forEach { $0.isCompleted = true }

        let response = AssistantEngine.respond(
            to: "What comes after walking?", milestones: milestones, correctedAge: 12
        )
        XCTAssertNil(response.pediatricNote)
    }

    func testWorriedQuestionAlwaysGetsAPediatricNote() {
        let milestones = catalogFixture()
        milestones.forEach { $0.isCompleted = true }

        let response = AssistantEngine.respond(
            to: "I'm really worried, she isn't walking and seems behind",
            milestones: milestones, correctedAge: 12
        )
        XCTAssertNotNil(response.pediatricNote)
    }

    /// The engine must not disagree with the Dashboard about the same child.
    /// The old one kept its own ratio, counted parent-authored milestones,
    /// ignored `CatalogBaseline`, and used a different age window.
    func testConcernAgreesWithDevelopmentObserver() {
        let milestones = catalogFixture()
        milestones.forEach { $0.isCompleted = true }

        let observed = DevelopmentObserver.observe(milestones: milestones, correctedAge: 12)
            .first { $0.category == .grossMotor }
        XCTAssertEqual(observed?.status, .onTrack)

        let response = AssistantEngine.respond(
            to: "How is her walking?", milestones: milestones, correctedAge: 12
        )
        XCTAssertNil(response.pediatricNote, "assistant flagged a domain the observer calls on track")
    }

    func testVagueQuestionStillAnswersUsefully() {
        let response = AssistantEngine.respond(
            to: "I don't really know what to ask", milestones: catalogFixture(), correctedAge: 12
        )
        XCTAssertFalse(response.context.isEmpty)
        XCTAssertEqual(response.activities.count, 3)
        XCTAssertNotNil(response.pediatricNote)
    }

    func testNoMilestonesDoesNotCrash() {
        let response = AssistantEngine.respond(to: "Is she walking?", milestones: [], correctedAge: 12)
        XCTAssertFalse(response.context.isEmpty)
        XCTAssertTrue(response.cited.isEmpty)
    }

    func testNewbornGetsNoPediatricPrompt() {
        let response = AssistantEngine.respond(to: "Is she moving enough?", milestones: [], correctedAge: 0)
        XCTAssertNil(response.pediatricNote)
    }
}

// MARK: - Activity bank

final class ActivityBankTests: XCTestCase {

    /// The structural cause of "it just reshuffles the bullets": gross motor and
    /// fine motor each held exactly three activities behind a
    /// `shuffled().prefix(3)`, which returns all three every time. Every pool
    /// must stay larger than the number shown.
    func testEveryPoolOffersMoreThanItShows() {
        let bands: [ActivityBank.Band] = [.infant, .toddler, .preschool]
        for category in MilestoneCategory.allCases {
            for band in bands {
                let pool = ActivityBank.activities(domain: category, band: band)
                XCTAssertGreaterThan(
                    pool.count, 3,
                    "\(category.rawValue) pool is not larger than the three shown"
                )
                XCTAssertEqual(Set(pool).count, pool.count, "\(category.rawValue) has a duplicate activity")
            }
        }
        XCTAssertGreaterThan(ActivityBank.general.count, 3)
    }
}
