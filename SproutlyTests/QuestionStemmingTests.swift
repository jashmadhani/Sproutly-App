//
//  QuestionStemmingTests.swift
//  SproutlyTests
//

import XCTest
import NaturalLanguage
@testable import Sproutly

/// These exist because the assistant quietly stopped understanding inflected
/// words and nothing failed loudly enough to notice.
///
/// `NLTagger`'s `.lemma` scheme is never present on the simulator (measured nil
/// on 26.4, 26.5 and 27.0) and arrives *late* on real hardware: on an
/// iPhone17,1 running iOS 27.0 the first run after install returned nil for
/// every word, and later runs of the same binary returned "walks" -> "walk".
/// `QuestionParser.tokenize` fell back to the surface form when the lemma came
/// back nil, so "walks" never matched the lexicon entry "walk", every question
/// scored no domain, and the assistant answered everything with its unfocused
/// fallback paragraph. It did not crash and it did not log.
///
/// So the contract these tests hold is deliberately *not* "lemmatisation is
/// available" — that would be asserting a system asset is present, which is the
/// thing we cannot rely on. It is "inflected forms resolve, using only code we
/// ship". That holds on a stock simulator, on a device warm or cold, in CI, and
/// in any locale, because nothing in the path is an on-demand system asset.
final class QuestionStemmingTests: XCTestCase {

    // MARK: The stemmer itself

    /// Every inflection of a word must reduce to one key. The key is not
    /// required to be a dictionary word — only to be the same for every form.
    func testInflectionsOfAWordShareOneStem() {
        let families: [[String]] = [
            ["walk", "walks", "walking", "walked"],
            ["crawl", "crawls", "crawling", "crawled"],
            ["babble", "babbles", "babbling", "babbled"],
            ["point", "points", "pointing", "pointed"],
            ["say", "says", "saying", "said"],
            ["sit", "sits", "sitting", "sat"],
            ["stand", "stands", "standing", "stood"],
            ["run", "runs", "running", "ran"],
            ["fall", "falls", "falling", "fell"],
            ["worry", "worries", "worrying", "worried"],
            ["struggle", "struggles", "struggling", "struggled"],
            ["word", "words"],
            ["jabber", "jabbers", "jabbering"],
            ["child", "children"],
            ["foot", "feet"]
        ]
        for family in families {
            let stems = Set(family.map(QuestionParser.stem))
            XCTAssertEqual(
                stems.count, 1,
                "\(family) should share one stem, got \(stems.sorted())"
            )
        }
    }

    /// Unrelated words must not collapse together, or the lexicon starts
    /// matching questions it has no business matching.
    func testUnrelatedWordsKeepDistinctStems() {
        let pairs = [("walk", "talk"), ("sit", "set"), ("word", "world"),
                     ("hand", "head"), ("point", "paint"), ("crawl", "cry")]
        for (lhs, rhs) in pairs {
            XCTAssertNotEqual(
                QuestionParser.stem(lhs), QuestionParser.stem(rhs),
                "\(lhs) and \(rhs) must not share a stem"
            )
        }
    }

    /// Short words must survive intact rather than being stripped to nothing.
    func testShortWordsAreNotDestroyed() {
        for word in ["a", "i", "up", "no", "eye", "cup", "toe", "ear"] {
            XCTAssertFalse(
                QuestionParser.stem(word).isEmpty,
                "\(word) stemmed to an empty string"
            )
        }
    }

    /// Deterministic: same input, same output, no process-seeded or
    /// asset-dependent variation.
    func testStemmingIsDeterministic() {
        let words = ["walking", "children", "struggled", "worries", "jabbers"]
        let first = words.map(QuestionParser.stem)
        for _ in 0..<50 {
            XCTAssertEqual(words.map(QuestionParser.stem), first)
        }
    }

    // MARK: Independence from the system lemmatiser

    /// The regression guard. If someone reintroduces a dependency on `.lemma`,
    /// this fails on any iOS destination with a message that says why, rather
    /// than eighteen oblique failures across five other test classes.
    func testInflectedQuestionsResolveWithoutTheSystemLemmatiser() {
        let lemmaAvailable = NLTagger
            .availableTagSchemes(for: .word, language: .english)
            .contains(.lemma)

        // Not an assertion — it is a fact about the host, recorded so a future
        // reader of a CI log knows which side of the line they were on.
        print("NLTagger .lemma available on this destination: \(lemmaAvailable)")

        let cases: [(String, MilestoneCategory)] = [
            ("she is walking", .grossMotor),
            ("she walks", .grossMotor),
            ("she walked", .grossMotor),
            ("he jabbers but no real words", .language),
            ("he is babbling", .language),
            ("she crawled across the room", .grossMotor),
            ("he points at things", .language)
        ]
        for (question, expected) in cases {
            XCTAssertEqual(
                QuestionParser.parse(question).topDomain, expected,
                "'\(question)' must resolve to \(expected) whether or not the "
                + "system lemmatiser is present (it is \(lemmaAvailable) here)"
            )
        }
    }

    /// The lexicons must not have to spell out inflections by hand. Both sides
    /// of a comparison are reduced by the same function, so an entry written in
    /// its base form still catches the forms a parent actually types.
    func testLexiconEntriesMatchTheirInflections() {
        for stem in QuestionParser.domainLexiconStems[.grossMotor] ?? [] {
            XCTAssertFalse(stem.isEmpty, "empty stem in the gross motor lexicon")
        }
        XCTAssertTrue(
            QuestionParser.domainLexiconStems[.grossMotor]?
                .contains(QuestionParser.stem("walking")) == true,
            "'walking' should reach the gross motor lexicon entry 'walk'"
        )
        XCTAssertTrue(
            QuestionParser.concernStems.contains(QuestionParser.stem("worrying")),
            "'worrying' should reach the concern entry 'worry'"
        )
    }

    // MARK: Stems must never be read back to a parent

    /// A stem is a lookup key, not English. `scopeTerm` goes straight into the
    /// answer copy, so it has to be a word the parent actually wrote.
    func testScopeTermIsAParentsWordAndNeverAStem() {
        let questions = [
            "is he sleeping through the night",
            "she is teething",
            "he keeps vomiting",
            "how do I start weaning"
        ]
        for question in questions {
            let intent = QuestionParser.parse(question)
            guard let term = intent.scopeTerm else { continue }
            XCTAssertTrue(
                question.lowercased().contains(term.lowercased()),
                "scopeTerm '\(term)' is not a word the parent wrote in '\(question)'"
            )
        }
    }

    // MARK: Whole-question determinism

    /// The same question must give the same answer every time it is parsed.
    func testParsingTheSameQuestionTwiceAgrees() {
        let questions = [
            "is she walking yet", "he isn't saying many words",
            "why is my baby's poop grey", "when should she start crawling"
        ]
        for question in questions {
            let first = QuestionParser.parse(question)
            let second = QuestionParser.parse(question)
            XCTAssertEqual(first.topDomain, second.topDomain, question)
            XCTAssertEqual(first.scope, second.scope, question)
            XCTAssertEqual(first.concern, second.concern, question)
            XCTAssertEqual(first.stems, second.stems, question)
        }
    }
}
