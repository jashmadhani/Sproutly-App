import XCTest
import SwiftData
import PDFKit
@testable import Sproutly

final class MilestoneTests: XCTestCase {
    func testTimingStatusBoundaries() {
        let milestone = Milestone(title: "Walks", category: "Gross Motor", ageMonth: 12)

        XCTAssertEqual(milestone.getTimingStatus(childAgeMonths: 11), .comingSoon)
        XCTAssertEqual(milestone.getTimingStatus(childAgeMonths: 12), .onTrack)
        XCTAssertEqual(milestone.getTimingStatus(childAgeMonths: 14), .onTrack)
        XCTAssertEqual(milestone.getTimingStatus(childAgeMonths: 15), .exploring)
        XCTAssertTrue(milestone.isSignificantlyLate(childAgeMonths: 16))
    }

    func testCompletedMilestoneIsCelebratedWhenCompletedEarly() {
        let milestone = Milestone(
            title: "Sits",
            category: "Gross Motor",
            ageMonth: 6,
            isCompleted: true
        )

        XCTAssertEqual(milestone.getTimingStatus(childAgeMonths: 5), .celebrated)
        XCTAssertEqual(milestone.getTimingStatus(childAgeMonths: 6), .onTrack)
        XCTAssertFalse(milestone.isSignificantlyLate(childAgeMonths: 20))
    }
}

final class DevelopmentObserverTests: XCTestCase {
    func testFutureMilestonesDoNotAffectCurrentDomain() throws {
        let current = Milestone(title: "Babbles", category: "Language", ageMonth: 6)
        let future = Milestone(title: "Runs", category: "Gross Motor", ageMonth: 18)

        let observations = DevelopmentObserver.observe(
            milestones: [current, future],
            correctedAge: 6
        )

        let language = try XCTUnwrap(observations.first { $0.category == .language })
        let grossMotor = try XCTUnwrap(observations.first { $0.category == .grossMotor })
        XCTAssertEqual(language.total, 1)
        XCTAssertEqual(grossMotor.total, 0)
        XCTAssertEqual(grossMotor.status, .onTrack)
    }

    // Language carries a 1.2x focus weight, so the same completion ratio lands one
    // band lower than it would in any other domain.
    func testLanguageWeightIsStricterThanOtherDomainsAtSameRatio() throws {
        func observation(for category: MilestoneCategory) throws -> DomainObservation {
            let milestones = [
                Milestone(title: "Done", category: category.rawValue, ageMonth: 9, isCompleted: true),
                Milestone(title: "Not yet", category: category.rawValue, ageMonth: 9)
            ]
            let observations = DevelopmentObserver.observe(milestones: milestones, correctedAge: 9)
            return try XCTUnwrap(observations.first { $0.category == category })
        }

        let language = try observation(for: .language)
        let cognitive = try observation(for: .cognitive)

        // Identical raw ratios...
        XCTAssertEqual(language.ratio, 0.5, accuracy: 0.0001)
        XCTAssertEqual(cognitive.ratio, 0.5, accuracy: 0.0001)

        // ...but the weighting pushes language down a band (0.5 / 1.2 = 0.417).
        XCTAssertEqual(cognitive.status, .emerging)
        XCTAssertEqual(language.status, .needsSupport)
    }
}

final class DashboardViewModelTests: XCTestCase {
    func testUpdateRecomputesWhenMilestoneFieldsChangeWithoutCountChange() {
        let milestone = Milestone(title: "Walks", category: "Gross Motor", ageMonth: 0)
        let child = Child(birthDate: Date())
        let viewModel = DashboardViewModel()

        viewModel.update(milestones: [milestone], child: child)
        XCTAssertEqual(viewModel.domainConcerns.count, 0)

        milestone.ageMonth = -2
        viewModel.update(milestones: [milestone], child: child)

        XCTAssertEqual(viewModel.flaggedMilestones.count, 1)
        XCTAssertEqual(viewModel.domainConcerns.first?.category, .grossMotor)
    }
}

final class ChildTests: XCTestCase {
    func testChronologicalAgeWeeksUsesElapsedDays() {
        let birthDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        let child = Child(birthDate: birthDate)

        XCTAssertEqual(child.chronologicalAgeWeeks, 1)
        XCTAssertEqual(child.humanReadableAge, "1 week old")
    }
}

// MARK: - Multi-child

// Free function so it stays nonisolated and usable from XCTest's setUp/tearDown.
private func clearSproutlyDefaults() {
    UserDefaults.standard.removeObject(forKey: "sproutly_active_child_id")
    UserDefaults.standard.removeObject(forKey: "sproutly_profile")
    UserDefaults.standard.removeObject(forKey: "elitegrowth_profile")
}

@MainActor
final class ChildStoreTests: XCTestCase {

    // Fresh in-memory container per test so cases can't leak into each other.
    // Held as a property: a ModelContext does not keep its container alive, and a
    // context whose container has deallocated traps on the next fetch.
    private var container: ModelContainer!

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SproutlyCurrentSchema.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        return container.mainContext
    }

    override nonisolated func setUp() {
        super.setUp()
        clearSproutlyDefaults()
    }

    override nonisolated func tearDown() {
        clearSproutlyDefaults()
        super.tearDown()
    }


    func testEachChildIsSeededWithTheirOwnMilestones() throws {
        let store = ChildStore(context: try makeContext())

        let first = store.addChild(name: "Aanya", birthDate: Date())
        let second = store.addChild(name: "Vir", birthDate: Date())

        XCTAssertEqual(first.milestones.count, DataSeeder.allMilestones.count)
        XCTAssertEqual(second.milestones.count, DataSeeder.allMilestones.count)

        // No milestone object is shared between siblings.
        let firstIDs = Set(first.milestones.map(\.id))
        let secondIDs = Set(second.milestones.map(\.id))
        XCTAssertTrue(firstIDs.isDisjoint(with: secondIDs))
    }

    // The core multi-child guarantee: logging for one child must not touch a sibling.
    func testCompletingAMilestoneDoesNotAffectSibling() throws {
        let store = ChildStore(context: try makeContext())
        let first = store.addChild(name: "Aanya", birthDate: Date())
        let second = store.addChild(name: "Vir", birthDate: Date())

        let target = try XCTUnwrap(first.sortedMilestones.first)
        target.isCompleted = true
        store.save()

        XCTAssertEqual(first.milestones.filter(\.isCompleted).count, 1)
        XCTAssertEqual(second.milestones.filter(\.isCompleted).count, 0)
    }

    func testAddingAChildMakesItActiveAndPersistsSelection() throws {
        let store = ChildStore(context: try makeContext())
        let first = store.addChild(name: "Aanya", birthDate: Date())
        XCTAssertEqual(store.activeChild?.id, first.id)

        let second = store.addChild(name: "Vir", birthDate: Date())
        XCTAssertEqual(store.activeChild?.id, second.id)

        store.select(first)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "sproutly_active_child_id"),
            first.id.uuidString
        )
    }

    func testSwitcherStaysHiddenUntilASecondChildExists() throws {
        let store = ChildStore(context: try makeContext())
        XCTAssertTrue(store.needsOnboarding)

        store.addChild(name: "Aanya", birthDate: Date())
        XCTAssertFalse(store.needsOnboarding)
        XCTAssertFalse(store.hasMultipleChildren)

        store.addChild(name: "Vir", birthDate: Date())
        XCTAssertTrue(store.hasMultipleChildren)
    }

    func testDeletingAChildCascadesAndReassignsActive() throws {
        let context = try makeContext()
        let store = ChildStore(context: context)
        let first = store.addChild(name: "Aanya", birthDate: Date())
        let second = store.addChild(name: "Vir", birthDate: Date())

        store.delete(second)

        XCTAssertEqual(store.children.count, 1)
        XCTAssertEqual(store.activeChild?.id, first.id)

        // Cascade removed the deleted child's milestones, and only those.
        let remaining = try context.fetch(FetchDescriptor<Milestone>())
        XCTAssertEqual(remaining.count, DataSeeder.allMilestones.count)
    }

    // A pre-multi-child install has milestones with no owner plus a UserDefaults
    // profile; both must be adopted into one Child exactly once.
    func testLegacyProfileAndOrphanMilestonesAreAdopted() throws {
        let context = try makeContext()

        let orphan = Milestone(title: "Sits", category: "Gross Motor", ageMonth: 6, isCompleted: true)
        context.insert(orphan)
        try context.save()

        UserDefaults.standard.set(
            [
                "name": "Aanya",
                "birthDate": Date().timeIntervalSince1970,
                "isPremature": true,
                "gestationalWeeks": 32
            ],
            forKey: "sproutly_profile"
        )

        let store = ChildStore(context: context)
        store.importLegacyProfileIfNeeded()

        XCTAssertEqual(store.children.count, 1)
        let adopted = try XCTUnwrap(store.activeChild)
        XCTAssertEqual(adopted.name, "Aanya")
        XCTAssertTrue(adopted.isPremature)
        XCTAssertEqual(adopted.gestationalWeeks, 32)

        // The completed milestone survived with its progress intact.
        XCTAssertEqual(adopted.milestones.count, 1)
        XCTAssertTrue(adopted.milestones.first?.isCompleted == true)

        // Idempotent: a second pass must not create another child.
        store.importLegacyProfileIfNeeded()
        XCTAssertEqual(store.children.count, 1)
    }
}

// MARK: - Custom milestones

final class CustomMilestoneTests: XCTestCase {

    // Parent-authored moments have no expected age, so they must never be flagged
    // late or scored against a developmental domain.
    // The design rule: a parent's own entries must not move a domain's status,
    // in either direction. Otherwise logging six personal language moments would
    // inflate Communication and mute the signal the observer exists to give.
    func testUserCreatedMilestonesAreExcludedFromDomainScoring() throws {
        let standard = [
            Milestone(title: "Babbles", category: "Language", ageMonth: 6, isCompleted: true),
            Milestone(title: "Points", category: "Language", ageMonth: 6)
        ]
        let baseline = try XCTUnwrap(
            DevelopmentObserver.observe(milestones: standard, correctedAge: 9)
                .first { $0.category == .language }
        )

        // Three completed personal moments in the same domain.
        let withCustom = standard + (1...3).map {
            Milestone(
                title: "Moment \($0)",
                category: "Language",
                ageMonth: 6,
                isCompleted: true,
                isUserCreated: true
            )
        }
        let observed = try XCTUnwrap(
            DevelopmentObserver.observe(milestones: withCustom, correctedAge: 9)
                .first { $0.category == .language }
        )

        XCTAssertEqual(observed.total, baseline.total)
        XCTAssertEqual(observed.completed, baseline.completed)
        XCTAssertEqual(observed.ratio, baseline.ratio, accuracy: 0.0001)
        XCTAssertEqual(observed.status, baseline.status)
    }

    func testUserCreatedMilestoneIsNeverLate() {
        let custom = Milestone(
            title: "First swim",
            category: "Gross Motor",
            ageMonth: 0,
            isUserCreated: true
        )

        XCTAssertFalse(custom.isSignificantlyLate(childAgeMonths: 48))
        XCTAssertEqual(custom.getTimingStatus(childAgeMonths: 48), .comingSoon)

        custom.isCompleted = true
        XCTAssertEqual(custom.getTimingStatus(childAgeMonths: 48), .celebrated)
    }
}

// MARK: - Photos

final class PhotoStoreTests: XCTestCase {

    private func makeImageData(width: Int, height: Int) -> Data {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 1)!
    }

    func testSaveRoundTripsAndDeleteRemovesFile() throws {
        let filename = try XCTUnwrap(PhotoStore.save(makeImageData(width: 400, height: 300)))
        addTeardownBlock { PhotoStore.delete(filename) }

        let loaded = try XCTUnwrap(PhotoStore.image(named: filename))
        XCTAssertEqual(loaded.size.width, 400, accuracy: 1)

        PhotoStore.delete(filename)
        XCTAssertNil(PhotoStore.image(named: filename))
    }

    // Storing originals would waste hundreds of MB over a few years of milestones.
    func testOversizeImagesAreDownscaled() throws {
        let filename = try XCTUnwrap(PhotoStore.save(makeImageData(width: 4000, height: 3000)))
        addTeardownBlock { PhotoStore.delete(filename) }

        let loaded = try XCTUnwrap(PhotoStore.image(named: filename))
        XCTAssertEqual(max(loaded.size.width, loaded.size.height), 1600, accuracy: 1)
        // Aspect ratio preserved.
        XCTAssertEqual(loaded.size.width / loaded.size.height, 4.0 / 3.0, accuracy: 0.01)
    }

    func testDeletingNilFilenameIsSafe() {
        PhotoStore.delete(nil)
        XCTAssertNil(PhotoStore.image(named: nil))
    }
}

// MARK: - Report & sharing

@MainActor
final class ReportTests: XCTestCase {

    private var container: ModelContainer!

    private func makeChild(ageMonths: Int) throws -> Child {
        let schema = Schema(versionedSchema: SproutlyCurrentSchema.self)
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let birth = Calendar.current.date(byAdding: .month, value: -ageMonths, to: Date())!
        let child = Child(name: "Aanya", birthDate: birth)
        container.mainContext.insert(child)
        DataSeeder.seed(for: child, in: container.mainContext)
        return child
    }

    // Listing milestones the child isn't old enough for would pad the report with
    // noise a clinician has to filter out.
    func testReportOnlyCoversMilestonesUpToCurrentAge() throws {
        let child = try makeChild(ageMonths: 9)
        let report = ReportBuilder.build(for: child)

        let ages = report.sections.flatMap { $0.completed + $0.pending }.map(\.ageMonth)
        XCTAssertFalse(ages.isEmpty)
        XCTAssertTrue(ages.allSatisfy { $0 <= 9 })
    }

    func testCustomMomentsAreListedSeparatelyNotAsExpectations() throws {
        let child = try makeChild(ageMonths: 12)

        let moment = Milestone(
            title: "First swim",
            category: "Gross Motor",
            ageMonth: 12,
            isCompleted: true,
            child: child,
            isUserCreated: true
        )
        container.mainContext.insert(moment)

        let report = ReportBuilder.build(for: child)

        XCTAssertEqual(report.ownMoments.count, 1)
        XCTAssertEqual(report.ownMoments.first?.title, "First swim")

        // Must not appear in the clinical domain counts.
        let clinicalTitles = report.sections.flatMap { $0.completed + $0.pending }.map(\.title)
        XCTAssertFalse(clinicalTitles.contains("First swim"))
    }

    func testNotYetMetSurfacesOnlySignificantlyLateMilestones() throws {
        let child = try makeChild(ageMonths: 24)
        let report = ReportBuilder.build(for: child)

        // Nothing is complete, so every milestone more than 3 months overdue lands here.
        XCTAssertFalse(report.notYetMet.isEmpty)
        XCTAssertTrue(report.notYetMet.allSatisfy { $0.ageMonth < 24 - 3 + 1 })
        XCTAssertTrue(report.notYetMet.allSatisfy { !$0.isUserCreated })
    }

    func testPDFRendersAsAValidMultiPageDocument() throws {
        let child = try makeChild(ageMonths: 36)
        let report = ReportBuilder.build(for: child)

        let url = try XCTUnwrap(ShareRenderer.pdf(for: report))
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }

        let document = try XCTUnwrap(PDFDocument(url: url))
        // A 36-month report is long; it must paginate rather than clip.
        XCTAssertGreaterThan(document.pageCount, 1)

        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined()
        XCTAssertTrue(text.contains("Aanya"))
        // The medical disclaimer must survive into the shared artifact.
        XCTAssertTrue(text.contains("not a screening result"))
    }

    func testShareCardRendersToAPNG() throws {
        let child = try makeChild(ageMonths: 12)
        let milestone = try XCTUnwrap(child.sortedMilestones.first)
        milestone.isCompleted = true
        milestone.dateCompleted = Date()

        let url = try XCTUnwrap(
            ShareRenderer.card(for: milestone, childName: "Aanya", nightMode: false)
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        XCTAssertFalse(data.isEmpty)
        XCTAssertNotNil(UIImage(data: data))
    }
}

// MARK: - Purchases

@MainActor
final class PurchaseManagerTests: XCTestCase {

    // The invariant that keeps a paying customer from seeing a paywall flash on
    // launch: entitlement state is unknown until the first check completes, and
    // gates must wait for it rather than reading isPro == false as "not bought".
    func testEntitlementStateStartsUnknownNotUnentitled() {
        let manager = PurchaseManager()

        XCTAssertFalse(manager.hasCheckedEntitlements)
        XCTAssertFalse(manager.isPro)
        XCTAssertEqual(manager.state, .idle)
    }

    func testProductIDMatchesTheStoreKitConfiguration() throws {
        // Guards against the ID drifting from Sproutly.storekit / App Store Connect,
        // which would silently break purchasing with no compile error.
        XCTAssertEqual(PurchaseManager.productID, "com.PLACEHOLDER.sproutly.pro")

        let url = try XCTUnwrap(Bundle(for: Self.self).url(
            forResource: "Sproutly", withExtension: "storekit"
        ) ?? nil)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let products = json?["products"] as? [[String: Any]] ?? []
        XCTAssertEqual(products.first?["productID"] as? String, PurchaseManager.productID)
        // Family Sharing on: a parenting app where the other parent can't unlock
        // it generates support mail and one-star reviews.
        XCTAssertEqual(products.first?["familyShareable"] as? Bool, true)
        XCTAssertEqual(products.first?["type"] as? String, "NonConsumable")
    }

    // Every gated surface must have copy; a blank paywall headline ships as a bug.
    func testEveryPaywallReasonHasCopy() {
        let reasons: [PaywallReason] = [.secondChild, .photo, .report, .shareCard, .customMilestone]
        for reason in reasons {
            XCTAssertFalse(reason.headline.isEmpty)
        }
        XCTAssertEqual(PaywallReason.allFeatures.count, 6)
    }
}
