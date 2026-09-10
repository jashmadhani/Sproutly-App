//
//  MilestoneStageTests.swift
//  SproutlyTests
//

import XCTest
@testable import Sproutly

/// The dashboard and the Milestones tab used to answer "what is this child
/// working on" with two different rules. These hold the single rule.
final class MilestoneStageTests: XCTestCase {

    private func catalog() -> [Milestone] {
        [2, 4, 6, 9, 12, 15, 18].flatMap { month in
            [
                Milestone(title: "Gross \(month)", category: "Gross Motor", ageMonth: month),
                Milestone(title: "Lang \(month)", category: "Language", ageMonth: month)
            ]
        }
    }

    /// A ten-day-old has reached nothing. The Milestones tab resolved forward to
    /// the two month band and listed it under "This Stage", immediately after
    /// onboarding promised Sproutly starts at two months.
    func testNewbornHasReachedNoBand() {
        let milestones = catalog()
        XCTAssertNil(
            MilestoneStage.resolveTargetAge(
                milestones: milestones,
                brackets: MilestoneStage.brackets(from: milestones),
                correctedAge: 0
            )
        )
    }

    func testFirstBandIsReachedExactlyOnTime() {
        let milestones = catalog()
        XCTAssertEqual(
            MilestoneStage.resolveTargetAge(
                milestones: milestones,
                brackets: MilestoneStage.brackets(from: milestones),
                correctedAge: 2
            ),
            2
        )
    }

    /// The old Milestones rule picked the *nearest* band, so a fourteen-month-old
    /// sat in the fifteen month band there and the twelve month band on the
    /// dashboard. It must never resolve to a band the child has not reached.
    func testNeverResolvesForwardToAnUnreachedBand() {
        let milestones = catalog()
        let resolved = MilestoneStage.resolveTargetAge(
            milestones: milestones,
            brackets: MilestoneStage.brackets(from: milestones),
            correctedAge: 14
        )
        XCTAssertEqual(resolved, 12)
        XCTAssertNotEqual(resolved, 15, "resolved forward to a band the child has not reached")
    }

    /// A band that is nearly finished hands back to the one before it, so
    /// "This Stage" is not empty while earlier work is outstanding.
    func testAWellCoveredBandHandsBackToAnEarlierOne() {
        let milestones = catalog()
        for milestone in milestones where milestone.ageMonth == 12 {
            milestone.isCompleted = true
        }
        XCTAssertEqual(
            MilestoneStage.resolveTargetAge(
                milestones: milestones,
                brackets: MilestoneStage.brackets(from: milestones),
                correctedAge: 12
            ),
            9
        )
    }

    /// Bands the child was never shown in time must not become the thing they
    /// are measured against.
    func testExcludedBandsAreNotTargeted() {
        let milestones = catalog()
        XCTAssertEqual(
            MilestoneStage.resolveTargetAge(
                milestones: milestones,
                brackets: MilestoneStage.brackets(from: milestones),
                correctedAge: 12,
                excludedBands: [12, 9]
            ),
            6
        )
    }

    /// Parent-authored moments are stamped with the child's current age and
    /// would drag the stage off the real bands.
    func testUserCreatedMomentsAreNotBands() {
        var milestones = catalog()
        milestones.append(
            Milestone(title: "First swim", category: "Gross Motor", ageMonth: 13, isUserCreated: true)
        )
        XCTAssertFalse(MilestoneStage.brackets(from: milestones).contains(13))
    }

    func testEmptyCatalogResolvesToNothing() {
        XCTAssertNil(
            MilestoneStage.resolveTargetAge(milestones: [], brackets: [], correctedAge: 12)
        )
    }
}
