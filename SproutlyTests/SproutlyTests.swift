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
    // The view model recomputes behind a hash signature rather than reactively,
    // so a field changing without the *count* changing has to be caught.
    //
    // The child is twelve months old rather than newborn: nothing is flagged
    // below `concernFloorMonths` at all now, so a newborn would have made this
    // pass for the wrong reason. See UIRegressionTests.
    func testUpdateRecomputesWhenMilestoneFieldsChangeWithoutCountChange() {
        let milestone = Milestone(title: "Walks", category: "Gross Motor", ageMonth: 12)
        let child = Child(
            birthDate: Calendar.current.date(byAdding: .month, value: -12, to: Date())!
        )
        let viewModel = DashboardViewModel()

        viewModel.update(milestones: [milestone], child: child)
        XCTAssertEqual(viewModel.domainConcerns.count, 0)

        // Same milestone, same count — only the expected age moves, which pulls
        // it inside the flagging window.
        milestone.ageMonth = 9
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

// MARK: - Catalog Shape

final class CatalogTests: XCTestCase {

    private let categories: Set<String> = Set(MilestoneCategory.allCases.map(\.rawValue))

    // An empty domain in a band makes DevelopmentObserver emit a DomainStatus
    // for a domain it has no evidence about.
    func testEveryBandCoversAllFiveCategories() {
        let byBand = Dictionary(grouping: DataSeeder.allMilestones, by: \.ageMonth)
        XCTAssertFalse(byBand.isEmpty)

        for (band, items) in byBand {
            let present = Set(items.map(\.category))
            XCTAssertEqual(
                present, categories,
                "band \(band) is missing \(categories.subtracting(present))"
            )
            XCTAssertGreaterThanOrEqual(items.count, 8, "band \(band) has only \(items.count)")
            XCTAssertLessThanOrEqual(items.count, 10, "band \(band) has \(items.count)")
        }
    }

    // A typo in a category string does not fail to compile — it silently falls
    // back to .grossMotor and quietly mis-scores a whole domain.
    func testNoCategoryStringFallsBackToGrossMotor() {
        for milestone in DataSeeder.allMilestones {
            XCTAssertTrue(
                categories.contains(milestone.category),
                "\"\(milestone.category)\" is not a MilestoneCategory raw value"
            )
            if milestone.category != MilestoneCategory.grossMotor.rawValue {
                XCTAssertNotEqual(
                    milestone.categoryType, .grossMotor,
                    "\(milestone.title) fell back to .grossMotor"
                )
            }
        }
    }

    func testCatalogIsAgeOrderedAndFullyTipped() {
        let ages = DataSeeder.allMilestones.map(\.ageMonth)
        XCTAssertEqual(ages, ages.sorted(), "allMilestones must be in age order")

        for milestone in DataSeeder.allMilestones {
            XCTAssertFalse(
                milestone.tips.trimmingCharacters(in: .whitespaces).isEmpty,
                "\(milestone.title) has no tips"
            )
        }
    }

    // Repair keys on (title, ageMonth). A title repeated across two bands would
    // make the pair ambiguous to a parent even where the code copes.
    func testTitlesAreUniqueAcrossTheWholeCatalog() {
        let titles = DataSeeder.allMilestones.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count)
    }

    func testTheFourNewBandsExist() {
        let bands = Set(DataSeeder.allMilestones.map(\.ageMonth))
        for band in [2, 4, 15, 30] {
            XCTAssertTrue(bands.contains(band), "missing the \(band)-month band")
        }
    }
}

// MARK: - Catalog Repair and Baseline

@MainActor
final class CatalogRepairTests: XCTestCase {

    private var container: ModelContainer!

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SproutlyCurrentSchema.self)
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return container.mainContext
    }

    /// A child shaped like an install from before the new bands shipped: seeded
    /// only from the bands the old catalog had.
    private func makeOldShapedChild(
        in context: ModelContext,
        ageMonths: Int,
        legacyBands: Set<Int> = [6, 9, 12, 18, 24, 36, 48, 60]
    ) -> Child {
        let birth = Calendar.current.date(byAdding: .month, value: -ageMonths, to: Date())!
        let child = Child(name: "Aanya", birthDate: birth)
        context.insert(child)

        for template in DataSeeder.allMilestones where legacyBands.contains(template.ageMonth) {
            template.child = child
            context.insert(template)
        }
        try? context.save()
        return child
    }

    override func tearDown() {
        for suite in UserDefaults.standard.dictionaryRepresentation().keys
        where suite.hasPrefix("sproutly_catalog_baseline_") {
            UserDefaults.standard.removeObject(forKey: suite)
        }
        super.tearDown()
    }

    // THE critical one. Growing the catalog must never cost a parent a single
    // thing they saved.
    func testRepairPreservesCompletionNotesAndPhotosOnAnOldShapedChild() throws {
        let context = try makeContext()
        let child = makeOldShapedChild(in: context, ageMonths: 20)

        let marked = child.milestones.filter { $0.ageMonth == 12 }
        XCTAssertEqual(marked.count, 10)
        let stamp = Date(timeIntervalSince1970: 1_600_000_000)
        for milestone in marked {
            milestone.isCompleted = true
            milestone.dateCompleted = stamp
            milestone.completionNote = "note for \(milestone.title)"
            milestone.photoFilename = "photo-\(milestone.ageMonth).jpg"
        }
        try context.save()

        let before = child.milestones.count
        DataSeeder.reseedIfIncomplete(for: child, in: context)

        // New bands arrived...
        XCTAssertGreaterThan(child.milestones.count, before)
        XCTAssertEqual(child.milestones.count, DataSeeder.allMilestones.count)

        // ...and nothing the parent saved changed.
        for milestone in child.milestones where milestone.ageMonth == 12 {
            XCTAssertTrue(milestone.isCompleted, "\(milestone.title) lost completion")
            XCTAssertEqual(milestone.dateCompleted, stamp)
            XCTAssertEqual(milestone.completionNote, "note for \(milestone.title)")
            XCTAssertEqual(milestone.photoFilename, "photo-12.jpg")
        }
    }

    func testRepairIsIdempotent() throws {
        let context = try makeContext()
        let child = makeOldShapedChild(in: context, ageMonths: 20)

        DataSeeder.reseedIfIncomplete(for: child, in: context)
        let afterFirst = child.milestones.count
        DataSeeder.reseedIfIncomplete(for: child, in: context)

        XCTAssertEqual(child.milestones.count, afterFirst)
        XCTAssertEqual(afterFirst, DataSeeder.allMilestones.count)
    }

    // A band shipped after the child was already older than it must never be
    // counted against them.
    func testBandsShippedTooLateAreExcludedFromScoring() throws {
        let context = try makeContext()
        let child = makeOldShapedChild(in: context, ageMonths: 20)

        DataSeeder.reseedIfIncomplete(for: child, in: context)
        let excluded = CatalogBaseline.excludedBands(for: child.id)

        // 2, 4 and 15 are behind a twenty-month-old; 30 and beyond are not.
        XCTAssertEqual(excluded, [2, 4, 15])
    }

    func testBandsNotYetReachedAreNotExcluded() throws {
        let context = try makeContext()
        let child = makeOldShapedChild(in: context, ageMonths: 7)

        DataSeeder.reseedIfIncomplete(for: child, in: context)
        let excluded = CatalogBaseline.excludedBands(for: child.id)

        // Only 2 and 4 are behind a seven-month-old. 15 and 30 lie ahead and
        // will be met in the ordinary way.
        XCTAssertEqual(excluded, [2, 4])
    }

    func testAFreshlySeededChildExcludesNothing() throws {
        let context = try makeContext()
        let store = ChildStore(context: context)
        let child = store.addChild(
            name: "Ravi",
            birthDate: Calendar.current.date(byAdding: .month, value: -20, to: Date())!
        )

        DataSeeder.reseedIfIncomplete(for: child, in: context)
        XCTAssertTrue(CatalogBaseline.excludedBands(for: child.id).isEmpty)
    }

    // The whole point: a diligent parent must not be downgraded, and must not be
    // handed a concern card, because we shipped content overnight.
    func testUpdatingTheCatalogNeverDowngradesAnExistingChild() throws {
        let context = try makeContext()
        let child = makeOldShapedChild(in: context, ageMonths: 20)

        // A parent who filled in everything the old catalog ever showed them.
        for milestone in child.milestones where milestone.ageMonth <= 20 {
            milestone.isCompleted = true
            milestone.dateCompleted = Date()
        }
        try context.save()

        let viewModel = DashboardViewModel()
        viewModel.update(milestones: child.sortedMilestones, child: child)
        XCTAssertFalse(viewModel.hasDevelopmentFocus)

        DataSeeder.reseedIfIncomplete(for: child, in: context)
        try context.save()
        viewModel.update(milestones: child.sortedMilestones, child: child)

        // No concern card, nothing flagged, and every domain still complete.
        XCTAssertTrue(viewModel.flaggedMilestones.isEmpty)
        XCTAssertFalse(viewModel.hasDevelopmentFocus)

        let observations = DevelopmentObserver.observe(
            milestones: child.sortedMilestones,
            correctedAge: 20,
            excludedBands: CatalogBaseline.excludedBands(for: child.id)
        )
        for observation in observations {
            XCTAssertEqual(observation.status, .onTrack, "\(observation.category) was downgraded")
            XCTAssertEqual(observation.ratio, 1.0, accuracy: 0.0001)
        }
    }

    // The same protection has to reach the artifact a pediatrician reads.
    func testReportDoesNotListLateBandsTheParentWasNeverShown() throws {
        let context = try makeContext()
        let child = makeOldShapedChild(in: context, ageMonths: 20)
        DataSeeder.reseedIfIncomplete(for: child, in: context)
        try context.save()

        let report = ReportBuilder.build(for: child)
        let flaggedBands = Set(report.notYetMet.map(\.ageMonth))

        XCTAssertTrue(
            flaggedBands.isDisjoint(with: [2, 4, 15]),
            "report surfaced bands the parent was never offered: \(flaggedBands)"
        )
    }
}

// MARK: - Before the First Band

@MainActor
final class YoungInfantTests: XCTestCase {

    private var container: ModelContainer!

    private func makeChild(ageWeeks: Int) throws -> Child {
        let schema = Schema(versionedSchema: SproutlyCurrentSchema.self)
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let birth = Calendar.current.date(byAdding: .day, value: -ageWeeks * 7, to: Date())!
        let child = Child(name: "Nia", birthDate: birth)
        container.mainContext.insert(child)
        DataSeeder.seed(for: child, in: container.mainContext)
        return child
    }

    // A three-week-old's parent must not be shown a ring at zero, a "0 of N",
    // or a concern of any kind.
    func testThreeWeekOldGetsTheForwardLookingStateAndNoConcern() throws {
        let child = try makeChild(ageWeeks: 3)
        let viewModel = DashboardViewModel()
        viewModel.update(milestones: child.sortedMilestones, child: child)

        XCTAssertEqual(child.calculateCorrectedAge(), 0)
        XCTAssertFalse(viewModel.hasReachedFirstBand)
        XCTAssertEqual(viewModel.currentStageTotal, 0)
        XCTAssertEqual(viewModel.currentStageCompleted, 0)
        XCTAssertEqual(viewModel.currentStageProgress, 0)
        XCTAssertTrue(viewModel.flaggedMilestones.isEmpty)
        XCTAssertFalse(viewModel.hasDevelopmentFocus)

        // And there is something warm to show instead.
        XCTAssertEqual(viewModel.upcomingBandMonth, 2)
        XCTAssertFalse(viewModel.upcomingMilestones.isEmpty)
    }

    // The observer must not divide by zero or invent a status.
    func testObserverIsSafeAndCalmWithNoEligibleMilestones() throws {
        let child = try makeChild(ageWeeks: 3)
        let observations = DevelopmentObserver.observe(
            milestones: child.sortedMilestones,
            correctedAge: 0
        )

        XCTAssertEqual(observations.count, MilestoneCategory.allCases.count)
        for observation in observations {
            XCTAssertEqual(observation.total, 0)
            XCTAssertEqual(observation.status, .onTrack)
            XCTAssertFalse(observation.ratio.isNaN)
        }
    }

    // At two months the app becomes a normal, full experience.
    func testTwoMonthOldGetsAFullDomainSet() throws {
        let child = try makeChild(ageWeeks: 9)
        let viewModel = DashboardViewModel()
        viewModel.update(milestones: child.sortedMilestones, child: child)

        XCTAssertEqual(child.calculateCorrectedAge(), 2)
        XCTAssertTrue(viewModel.hasReachedFirstBand)
        XCTAssertEqual(viewModel.targetAgeMonth, 2)
        XCTAssertGreaterThan(viewModel.currentStageTotal, 0)

        let observations = DevelopmentObserver.observe(
            milestones: child.sortedMilestones,
            correctedAge: 2
        )
        for observation in observations {
            XCTAssertGreaterThan(
                observation.total, 0,
                "\(observation.category) has nothing at two months"
            )
        }
    }
}

// MARK: - Onboarding Backfill

@MainActor
final class BackfillTests: XCTestCase {

    private var container: ModelContainer!

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SproutlyCurrentSchema.self)
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return container.mainContext
    }

    private func makeChild(
        in context: ModelContext,
        name: String,
        ageMonths: Int,
        isPremature: Bool = false,
        gestationalWeeks: Int = 40
    ) -> Child {
        let birth = Calendar.current.date(byAdding: .month, value: -ageMonths, to: Date())!
        let child = Child(
            name: name,
            birthDate: birth,
            isPremature: isPremature,
            gestationalWeeks: gestationalWeeks
        )
        context.insert(child)
        DataSeeder.seed(for: child, in: context)
        return child
    }

    // MARK: Offering

    /// The bands the shipping catalog actually covers at or below an age.
    /// Derived rather than written down, so adding a band to `DataSeeder`
    /// doesn't fail these tests for a reason that isn't a regression.
    private func catalogBands(upTo age: Int) -> Set<Int> {
        Set(DataSeeder.allMilestones.map(\.ageMonth).filter { $0 <= age })
    }

    // Below the first band there is nothing to offer, so the step must not
    // appear at all. This is the case that makes the skip a list check rather
    // than an age check — the threshold moves whenever the catalog grows down.
    func testNothingIsOfferedBelowTheFirstMilestoneBracket() {
        let firstBand = try! XCTUnwrap(DataSeeder.allMilestones.map(\.ageMonth).min())
        XCTAssertGreaterThan(firstBand, 0, "a newborn must never be offered a list")

        XCTAssertTrue(BackfillCatalog.candidates(correctedAge: 0).isEmpty)
        XCTAssertTrue(BackfillCatalog.candidates(correctedAge: firstBand - 1).isEmpty)
        XCTAssertFalse(BackfillCatalog.candidates(correctedAge: firstBand).isEmpty)
    }

    func testOnlyMilestonesAtOrBelowCorrectedAgeAreOffered() {
        let candidates = BackfillCatalog.candidates(correctedAge: 12)

        XCTAssertFalse(candidates.isEmpty)
        XCTAssertTrue(candidates.allSatisfy { $0.ageMonth <= 12 })
        XCTAssertEqual(Set(candidates.map(\.ageMonth)), catalogBands(upTo: 12))
    }

    // A premature child must be offered against corrected age, not chronological.
    // Twelve months chronological at 30 weeks corrects to ten, which lands either
    // side of the twelve-month bracket — so the two ages give different lists and
    // the test can actually tell them apart.
    func testPrematureChildIsOfferedByCorrectedAgeNotChronological() throws {
        let context = try makeContext()
        let child = makeChild(
            in: context,
            name: "Ravi",
            ageMonths: 12,
            isPremature: true,
            gestationalWeeks: 30
        )

        XCTAssertEqual(child.chronologicalAgeMonths, 12)
        XCTAssertEqual(child.calculateCorrectedAge(), 10)

        let corrected = BackfillCatalog.candidates(correctedAge: child.calculateCorrectedAge())
        let chronological = BackfillCatalog.candidates(correctedAge: child.chronologicalAgeMonths)

        XCTAssertEqual(Set(corrected.map(\.ageMonth)), catalogBands(upTo: 10))
        XCTAssertEqual(Set(chronological.map(\.ageMonth)), catalogBands(upTo: 12))

        // The point of the test: the two ages genuinely disagree, and the
        // corrected one is what the parent is shown.
        XCTAssertLessThan(corrected.count, chronological.count)
        XCTAssertFalse(corrected.contains { $0.ageMonth == 12 })
    }

    // Parent-authored moments have no expected age and are inert everywhere that
    // judges progress. They must never be offered here either.
    func testUserCreatedMilestonesAreNeverOffered() throws {
        let context = try makeContext()
        let child = makeChild(in: context, name: "Aanya", ageMonths: 24)

        let ownMoment = Milestone(
            title: "First swim",
            category: MilestoneCategory.socialEmotional.rawValue,
            ageMonth: 24,
            tips: "",
            child: child,
            isUserCreated: true
        )
        context.insert(ownMoment)
        try context.save()

        let offered = Set(BackfillCatalog.candidates(correctedAge: 24).map(\.title))
        XCTAssertFalse(offered.contains("First swim"))

        // And even if a parent authored a moment whose title collides with a
        // catalog entry, applying must leave their moment alone.
        let collidingTitle = try XCTUnwrap(BackfillCatalog.candidates(correctedAge: 24).first).title
        let collision = Milestone(
            title: collidingTitle,
            category: MilestoneCategory.cognitive.rawValue,
            ageMonth: 24,
            child: child,
            isUserCreated: true
        )
        context.insert(collision)
        try context.save()

        BackfillCatalog.apply([collidingTitle], to: child)

        XCTAssertFalse(collision.isCompleted)
        let seeded = child.milestones.first { $0.title == collidingTitle && !$0.isUserCreated }
        XCTAssertEqual(seeded?.isCompleted, true)
    }

    // MARK: Applying

    func testBackfillMarksOnlyTheSelectedMilestonesAndLeavesSiblingsAlone() throws {
        let context = try makeContext()
        let aanya = makeChild(in: context, name: "Aanya", ageMonths: 14)
        let ravi = makeChild(in: context, name: "Ravi", ageMonths: 14)

        let selected = Set(BackfillCatalog.candidates(correctedAge: 14).prefix(3).map(\.title))
        XCTAssertEqual(selected.count, 3)

        BackfillCatalog.apply(selected, to: aanya)
        try context.save()

        let completed = aanya.milestones.filter(\.isCompleted)
        XCTAssertEqual(Set(completed.map(\.title)), selected)

        // Backfilled means "it happened, we don't know when".
        XCTAssertTrue(completed.allSatisfy { $0.dateCompleted == nil })
        XCTAssertTrue(completed.allSatisfy { $0.completionNote.isEmpty })

        // The sibling shares nothing.
        XCTAssertTrue(ravi.milestones.allSatisfy { !$0.isCompleted })
    }

    // "Skip for now" must be genuinely free: nothing marked, onboarding over.
    func testSkippingLeavesEverythingIncompleteAndStillEndsOnboarding() throws {
        let context = try makeContext()
        let store = ChildStore(context: context)
        XCTAssertTrue(store.needsOnboarding)

        let child = store.addChild(name: "Aanya", birthDate: Calendar.current.date(
            byAdding: .month, value: -14, to: Date()
        )!)
        BackfillCatalog.apply([], to: child)
        store.save()

        XCTAssertFalse(store.needsOnboarding)
        XCTAssertEqual(store.activeChild?.id, child.id)
        XCTAssertFalse(child.milestones.isEmpty)
        XCTAssertTrue(child.milestones.allSatisfy { !$0.isCompleted })
    }

    // MARK: Scoring

    // A bulk backfill has to move the domain scores, or the dashboard the parent
    // lands on still reads as though they had noticed nothing.
    func testDomainScoringReflectsABulkBackfill() throws {
        let context = try makeContext()
        let child = makeChild(in: context, name: "Aanya", ageMonths: 12)

        let grossMotorTitles = Set(
            BackfillCatalog.candidates(correctedAge: 12)
                .filter { $0.category == .grossMotor }
                .map(\.title)
        )
        XCTAssertFalse(grossMotorTitles.isEmpty)

        BackfillCatalog.apply(grossMotorTitles, to: child)
        try context.save()

        let observations = DevelopmentObserver.observe(
            milestones: child.sortedMilestones,
            correctedAge: 12
        )

        let grossMotor = try XCTUnwrap(observations.first { $0.category == .grossMotor })
        XCTAssertEqual(grossMotor.ratio, 1.0, accuracy: 0.0001)
        XCTAssertEqual(grossMotor.status, .onTrack)

        // An untouched domain must not have moved.
        let language = try XCTUnwrap(observations.first { $0.category == .language })
        XCTAssertEqual(language.ratio, 0.0, accuracy: 0.0001)
    }

    // The dashboard recomputes behind a hash signature rather than reactively, so
    // a backfill that changed no *count* the view model watches would leave the
    // ring stale. Completion is part of the signature — this pins that.
    func testDashboardRecomputesAfterABackfill() throws {
        let context = try makeContext()
        let child = makeChild(in: context, name: "Aanya", ageMonths: 12)
        let viewModel = DashboardViewModel()

        viewModel.update(milestones: child.sortedMilestones, child: child)
        XCTAssertTrue(viewModel.completedMilestones.isEmpty)

        let titles = Set(BackfillCatalog.candidates(correctedAge: 12).prefix(5).map(\.title))
        BackfillCatalog.apply(titles, to: child)
        try context.save()

        viewModel.update(milestones: child.sortedMilestones, child: child)
        XCTAssertEqual(Set(viewModel.completedMilestones.map(\.title)), titles)
    }

    // MARK: Ordering

    // Backfilled milestones carry no date. Sorting them as `.distantPast` sank
    // them below everything; sorting them as "now" would bury a moment the parent
    // saved five minutes ago. They go after the dated ones, in a fixed order.
    func testUndatedCompletionsSortAfterDatedOnesDeterministically() {
        let older = Milestone(
            title: "Rolls over", category: "Gross Motor", ageMonth: 6,
            isCompleted: true, dateCompleted: Date(timeIntervalSince1970: 1_000)
        )
        let newer = Milestone(
            title: "Waves bye", category: "Social-Emotional", ageMonth: 9,
            isCompleted: true, dateCompleted: Date(timeIntervalSince1970: 2_000)
        )
        let backfilledEarly = Milestone(
            title: "Sits up", category: "Gross Motor", ageMonth: 6, isCompleted: true
        )
        let backfilledLate = Milestone(
            title: "Walks", category: "Gross Motor", ageMonth: 12, isCompleted: true
        )

        let ordered = Milestone.recencyOrdered(
            [backfilledEarly, older, backfilledLate, newer]
        )

        XCTAssertEqual(
            ordered.map(\.title),
            ["Waves bye", "Rolls over", "Walks", "Sits up"]
        )

        // Deterministic: `sorted(by:)` is not stable, so a differently shuffled
        // input must still produce the same order.
        let reshuffled = Milestone.recencyOrdered(
            [newer, backfilledLate, backfilledEarly, older]
        )
        XCTAssertEqual(ordered.map(\.title), reshuffled.map(\.title))
    }

    // MARK: Sharing

    // The share card is the one artifact designed to leave the phone, and it used
    // to fall back to `Date()` — printing today as the day a backfilled milestone
    // happened, which was simply false.
    func testShareCardNeverInventsADateForABackfilledMilestone() {
        let dated = Date(timeIntervalSince1970: 1_700_000_000)

        let withDate = MilestoneShareCard.caption(childName: "Aanya", dateCompleted: dated)
        XCTAssertTrue(withDate.hasPrefix("Aanya · "))
        XCTAssertTrue(withDate.contains(dated.formatted(date: .long, time: .omitted)))

        let withoutDate = MilestoneShareCard.caption(childName: "Aanya", dateCompleted: nil)
        XCTAssertEqual(withoutDate, "Aanya")
        XCTAssertFalse(
            withoutDate.contains(Date().formatted(date: .long, time: .omitted))
        )
    }

    // And it still renders — an undated caption must not break the layout.
    func testShareCardRendersForABackfilledMilestone() throws {
        let context = try makeContext()
        let child = makeChild(in: context, name: "Aanya", ageMonths: 14)

        let title = try XCTUnwrap(BackfillCatalog.candidates(correctedAge: 14).first).title
        BackfillCatalog.apply([title], to: child)
        try context.save()

        let milestone = try XCTUnwrap(
            child.milestones.first { $0.title == title && !$0.isUserCreated }
        )
        XCTAssertNil(milestone.dateCompleted)

        let url = try XCTUnwrap(
            ShareRenderer.card(for: milestone, childName: "Aanya", nightMode: false)
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        XCTAssertNotNil(UIImage(data: data))
    }

    // The pediatrician report filters on isCompleted alone, so backfilled items
    // appear in it. They must appear without a fabricated date rather than not
    // appear at all — the clinician is reading what the parent has observed.
    func testReportListsBackfilledMilestonesWithoutADate() throws {
        let context = try makeContext()
        let child = makeChild(in: context, name: "Aanya", ageMonths: 12)

        let titles = Set(BackfillCatalog.candidates(correctedAge: 12).prefix(4).map(\.title))
        BackfillCatalog.apply(titles, to: child)
        try context.save()

        let report = ReportBuilder.build(for: child)
        let completed = report.sections.flatMap(\.completed)

        XCTAssertEqual(Set(completed.map(\.title)), titles)
        XCTAssertTrue(completed.allSatisfy { $0.dateCompleted == nil })
    }
}

// MARK: - Notifications

@MainActor
final class NotificationPlannerTests: XCTestCase {

    private var container: ModelContainer!
    private let childID = UUID()

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// A Monday, so weekday arithmetic in the tests is unambiguous.
    private var monday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 8))!
    }

    private func makeChild(ageMonths: Int) throws -> Child {
        let schema = Schema(versionedSchema: SproutlyCurrentSchema.self)
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let birth = calendar.date(byAdding: .month, value: -ageMonths, to: monday)!
        let child = Child(name: "Aanya", birthDate: birth)
        container.mainContext.insert(child)
        DataSeeder.seed(for: child, in: container.mainContext)
        return child
    }

    private var allOn: NotificationSettings {
        NotificationSettings(
            masterEnabled: true,
            enabledKinds: Set(SproutlyNotificationKind.allCases)
        )
    }

    private func plan(
        child: Child,
        correctedAge: Int,
        settings: NotificationSettings? = nil,
        daysAway: Int = 0,
        now: Date? = nil
    ) -> [PlannedNotification] {
        NotificationPlanner.plan(
            childID: child.id,
            childName: child.displayName,
            correctedAge: correctedAge,
            milestones: child.sortedMilestones,
            excludedBands: [],
            settings: settings ?? allOn,
            daysSinceLastOpened: daysAway,
            now: now ?? monday,
            calendar: calendar
        )
    }

    // MARK: The one-a-day cap

    func testNeverMoreThanOneNotificationOnACalendarDay() throws {
        let child = try makeChild(ageMonths: 14)

        // Give every day in the window an anniversary candidate as well as a
        // daily notice, so collisions are guaranteed.
        for milestone in child.sortedMilestones.prefix(8) {
            milestone.isCompleted = true
            milestone.dateCompleted = calendar.date(byAdding: .year, value: -1, to: monday)
        }

        let planned = plan(child: child, correctedAge: 14)
        let days = planned.map { DailyNoticePicker.dayNumber(for: $0.fireDate, calendar: calendar) }

        XCTAssertFalse(planned.isEmpty)
        XCTAssertEqual(Set(days).count, days.count, "two notifications landed on one day")
    }

    // MARK: The fire window

    func testNothingIsEverScheduledOutsideNineToSeven() throws {
        let child = try makeChild(ageMonths: 14)
        for milestone in child.sortedMilestones.prefix(4) {
            milestone.isCompleted = true
            milestone.dateCompleted = calendar.date(byAdding: .year, value: -1, to: monday)
        }

        let planned = plan(child: child, correctedAge: 14)
        XCTAssertFalse(planned.isEmpty)

        for notification in planned {
            let hour = calendar.component(.hour, from: notification.fireDate)
            XCTAssertGreaterThanOrEqual(hour, NotificationPlanner.earliestHour, "fires at \(hour):00")
            XCTAssertLessThan(hour, NotificationPlanner.latestHour, "fires at \(hour):00")
        }
    }

    // A mis-set constant must fail to schedule rather than fire at midnight.
    func testTimeBuilderRefusesHoursOutsideTheWindow() {
        XCTAssertNil(NotificationPlanner.time(3, 0, on: monday, calendar: calendar))
        XCTAssertNil(NotificationPlanner.time(22, 0, on: monday, calendar: calendar))
        XCTAssertNotNil(NotificationPlanner.time(9, 30, on: monday, calendar: calendar))
    }

    // MARK: Collision

    func testAnniversaryBeatsTheDailyNoticeOnTheSameDay() throws {
        let child = try makeChild(ageMonths: 14)
        let milestone = try XCTUnwrap(child.sortedMilestones.first)
        milestone.isCompleted = true
        // Exactly one year before tomorrow, so it lands inside the window.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: monday)!
        milestone.dateCompleted = calendar.date(byAdding: .year, value: -1, to: tomorrow)

        let planned = plan(child: child, correctedAge: 14)
        let tomorrowDay = DailyNoticePicker.dayNumber(for: tomorrow, calendar: calendar)
        let onThatDay = planned.filter {
            DailyNoticePicker.dayNumber(for: $0.fireDate, calendar: calendar) == tomorrowDay
        }

        XCTAssertEqual(onThatDay.count, 1)
        XCTAssertEqual(onThatDay.first?.kind, .anniversary)
    }

    // A backfilled milestone has no date, so it can never have an anniversary.
    // Celebrating a day that never happened would be a fabrication.
    func testBackfilledMilestonesNeverProduceAnAnniversary() throws {
        let child = try makeChild(ageMonths: 14)
        for milestone in child.sortedMilestones {
            milestone.isCompleted = true
            milestone.dateCompleted = nil
        }

        let planned = plan(child: child, correctedAge: 14)
        XCTAssertFalse(planned.contains { $0.kind == .anniversary })
    }

    // MARK: Weekly reflection

    func testWeeklyReflectionIsSkippedEntirelyWhenTheWeekHadNoLogs() throws {
        let child = try makeChild(ageMonths: 14)

        let planned = plan(child: child, correctedAge: 14)
        XCTAssertFalse(
            planned.contains { $0.kind == .weeklyReflection },
            "an empty week must pass in silence"
        )
    }

    func testWeeklyReflectionAppearsOnSundayWhenSomethingWasLogged() throws {
        let child = try makeChild(ageMonths: 14)
        let milestone = try XCTUnwrap(child.sortedMilestones.first)
        milestone.isCompleted = true
        milestone.dateCompleted = calendar.date(byAdding: .day, value: -1, to: monday)

        let planned = plan(
            child: child,
            correctedAge: 14,
            settings: NotificationSettings(masterEnabled: true, enabledKinds: [.weeklyReflection])
        )

        let weekly = planned.filter { $0.kind == .weeklyReflection }
        XCTAssertEqual(weekly.count, 1)
        for notification in weekly {
            XCTAssertEqual(calendar.component(.weekday, from: notification.fireDate), 1)
        }
    }

    // MARK: Auto-quiet

    func testAutoQuietDegradesAtFourteenDaysAndStopsAtThirty() throws {
        let child = try makeChild(ageMonths: 14)
        let milestone = try XCTUnwrap(child.sortedMilestones.first)
        milestone.isCompleted = true
        milestone.dateCompleted = calendar.date(byAdding: .day, value: -1, to: monday)

        XCTAssertEqual(QuietLevel.forDaysAway(0), .normal)
        XCTAssertEqual(QuietLevel.forDaysAway(13), .normal)
        XCTAssertEqual(QuietLevel.forDaysAway(14), .weeklyOnly)
        XCTAssertEqual(QuietLevel.forDaysAway(29), .weeklyOnly)
        XCTAssertEqual(QuietLevel.forDaysAway(30), .silent)

        // At fourteen days the daily notice is gone but the weekly survives.
        let quieted = plan(child: child, correctedAge: 14, daysAway: 14)
        XCTAssertFalse(quieted.contains { $0.kind == .dailyNotice })
        XCTAssertFalse(quieted.contains { $0.kind == .anniversary })

        // At thirty, nothing at all until they come back on their own.
        XCTAssertTrue(plan(child: child, correctedAge: 14, daysAway: 30).isEmpty)
        XCTAssertTrue(plan(child: child, correctedAge: 14, daysAway: 90).isEmpty)
    }

    // MARK: The youngest babies

    func testUnderTwoMonthsNeverExceedsTwoNotificationsAWeek() throws {
        let child = try makeChild(ageMonths: 0)

        let planned = plan(child: child, correctedAge: 0)

        XCTAssertTrue(NotificationPlanner.isYoungInfant(correctedAge: 0))
        XCTAssertLessThanOrEqual(
            planned.count, NotificationPlanner.youngInfantWeeklyCap,
            "a newborn's parent was sent \(planned.count) notifications in a week"
        )

        // And never on consecutive days at a daily cadence.
        XCTAssertLessThanOrEqual(planned.count, 2)
    }

    func testMasterSwitchOffMeansNothingAtAll() throws {
        let child = try makeChild(ageMonths: 14)
        let planned = plan(child: child, correctedAge: 14, settings: .allOff)
        XCTAssertTrue(planned.isEmpty)
    }

    // MARK: Copy

    // The lock screen is readable by anyone standing nearby, and a milestone
    // name there turns an invitation into a demand.
    func testDailyNoticeBodyNeverNamesTheMilestone() throws {
        let child = try makeChild(ageMonths: 14)
        let titles = Set(child.sortedMilestones.map(\.title))

        let planned = plan(child: child, correctedAge: 14)
        for notification in planned where notification.kind == .dailyNotice {
            for title in titles {
                XCTAssertFalse(
                    notification.body.contains(title),
                    "daily notice body named \"\(title)\""
                )
            }
        }
    }

    func testNoNotificationCopyUsesAlarmingLanguage() throws {
        let child = try makeChild(ageMonths: 14)
        for milestone in child.sortedMilestones.prefix(4) {
            milestone.isCompleted = true
            milestone.dateCompleted = calendar.date(byAdding: .day, value: -1, to: monday)
        }

        let banned = ["delayed", "behind", "late", "at risk", "failed", "missed",
                      "haven't", "streak", "don't forget", "hurry"]
        var copy = plan(child: child, correctedAge: 14).flatMap { [$0.title, $0.body] }
        copy += SproutlyNotificationKind.allCases.flatMap {
            [$0.settingsTitle, $0.settingsDescription]
        }

        for line in copy {
            let lowered = line.lowercased()
            for word in banned {
                XCTAssertFalse(lowered.contains(word), "\"\(line)\" contains \"\(word)\"")
            }
        }
    }
}

// MARK: - Daily Notice Card Selection

@MainActor
final class DailyNoticeTests: XCTestCase {

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

    private let day = Date(timeIntervalSince1970: 1_756_000_000)

    // Same child, same day, same answer — no matter how many times the view
    // re-renders or the app is relaunched.
    func testSelectionIsDeterministicForAChildAndDay() throws {
        let child = try makeChild(ageMonths: 14)

        let picks = (0..<25).map { _ in
            DailyNoticePicker.pick(
                from: child.sortedMilestones,
                correctedAge: 14,
                childID: child.id,
                day: day
            )?.title
        }

        XCTAssertNotNil(picks.first ?? nil)
        XCTAssertEqual(Set(picks).count, 1, "the suggestion reshuffled between calls")
    }

    // The stable hash is the whole reason it holds across launches: Swift seeds
    // Hasher randomly per process, so hashValue would not.
    func testStableHashDoesNotDependOnProcessSeed() {
        XCTAssertEqual(
            DailyNoticePicker.stableHash("aanya|20321"),
            DailyNoticePicker.stableHash("aanya|20321")
        )
        XCTAssertNotEqual(
            DailyNoticePicker.stableHash("aanya|20321"),
            DailyNoticePicker.stableHash("aanya|20322")
        )
    }

    func testANewDayCanGiveANewSuggestion() throws {
        let child = try makeChild(ageMonths: 24)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: day)!

        let today = DailyNoticePicker.pick(
            from: child.sortedMilestones, correctedAge: 24, childID: child.id, day: day
        )
        let next = DailyNoticePicker.pick(
            from: child.sortedMilestones, correctedAge: 24, childID: child.id, day: tomorrow
        )

        XCTAssertNotNil(today)
        XCTAssertNotNil(next)
        // Both valid; the point is the seed changed, not that they must differ.
        XCTAssertEqual(
            DailyNoticePicker.dayNumber(for: tomorrow),
            DailyNoticePicker.dayNumber(for: day) + 1
        )
    }

    func testNeverSuggestsAParentAuthoredMoment() throws {
        let child = try makeChild(ageMonths: 14)
        // Everything standard already saved, so only the parent's own is left.
        for milestone in child.milestones where !milestone.isUserCreated {
            milestone.isCompleted = true
        }
        let own = Milestone(
            title: "First swim",
            category: MilestoneCategory.socialEmotional.rawValue,
            ageMonth: 14,
            child: child,
            isUserCreated: true
        )
        container.mainContext.insert(own)
        try container.mainContext.save()

        let pick = DailyNoticePicker.pick(
            from: child.sortedMilestones, correctedAge: 14, childID: child.id, day: day
        )
        XCTAssertNil(pick, "suggested the parent notice their own entry")
    }

    // With nothing left at or below their age it falls forward to the nearest
    // band ahead — which is what every baby under two months gets.
    func testFallsForwardWhenEverythingAtOrBelowAgeIsSaved() throws {
        let child = try makeChild(ageMonths: 14)
        for milestone in child.milestones where milestone.ageMonth <= 14 {
            milestone.isCompleted = true
        }

        let pick = try XCTUnwrap(
            DailyNoticePicker.pick(
                from: child.sortedMilestones, correctedAge: 14, childID: child.id, day: day
            )
        )
        XCTAssertGreaterThan(pick.ageMonth, 14)
        XCTAssertEqual(pick.ageMonth, 15, "should reach for the nearest band, not a distant one")
    }

    func testNewbornGetsTheNearestUpcomingBand() throws {
        let child = try makeChild(ageMonths: 0)
        let pick = try XCTUnwrap(
            DailyNoticePicker.pick(
                from: child.sortedMilestones, correctedAge: 0, childID: child.id, day: day
            )
        )
        XCTAssertEqual(pick.ageMonth, 2)
    }

    func testExcludedBandsAreNeverSuggested() throws {
        let child = try makeChild(ageMonths: 24)
        let pick = DailyNoticePicker.pick(
            from: child.sortedMilestones,
            correctedAge: 24,
            excludedBands: [2, 4, 6, 9, 12, 15, 18, 24],
            childID: child.id,
            day: day
        )
        XCTAssertNotNil(pick)
        XCTAssertGreaterThan(try XCTUnwrap(pick).ageMonth, 24)
    }

    func testNilOnlyWhenThereIsGenuinelyNothingLeft() throws {
        let child = try makeChild(ageMonths: 60)
        for milestone in child.milestones {
            milestone.isCompleted = true
        }
        XCTAssertNil(
            DailyNoticePicker.pick(
                from: child.sortedMilestones, correctedAge: 60, childID: child.id, day: day
            )
        )
    }

    // MARK: Dismissal

    func testDismissalPersistsForTheDayAndClearsTheNext() throws {
        let child = try makeChild(ageMonths: 14)
        defer { DailyCardDismissal.clear(for: child.id) }

        XCTAssertFalse(DailyCardDismissal.isDismissed(for: child.id, on: day))

        DailyCardDismissal.dismiss(for: child.id, on: day)
        XCTAssertTrue(DailyCardDismissal.isDismissed(for: child.id, on: day))

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        XCTAssertFalse(
            DailyCardDismissal.isDismissed(for: child.id, on: tomorrow),
            "\"Not yet\" must only hide today's card"
        )
    }
}

// MARK: - Log Counter

@MainActor
final class MilestoneLogCounterTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MilestoneLogCounter.reset()
    }

    override func tearDown() {
        MilestoneLogCounter.reset()
        super.tearDown()
    }

    func testOnlyDatedCompletionsCount() {
        let logged = Milestone(
            title: "Waves", category: "Language", ageMonth: 12,
            isCompleted: true, dateCompleted: Date()
        )
        let incomplete = Milestone(title: "Runs", category: "Gross Motor", ageMonth: 18)

        MilestoneLogCounter.record(logged)
        MilestoneLogCounter.record(incomplete)

        XCTAssertEqual(MilestoneLogCounter.count, 1)
    }

    // The gate for both one-time nudges. A parent who backfilled twelve
    // milestones during onboarding has not yet used the app, and must not be
    // treated as though they had.
    func testBackfilledMilestonesNeverAdvanceTheCounter() {
        for index in 0..<12 {
            let backfilled = Milestone(
                title: "Backfilled \(index)", category: "Cognitive", ageMonth: 6,
                isCompleted: true, dateCompleted: nil
            )
            MilestoneLogCounter.record(backfilled)
        }

        XCTAssertEqual(MilestoneLogCounter.count, 0)
    }

    func testPromptIsOfferedOnlyAfterThreeGenuineLogsAndOnlyOnce() {
        let defaults = UserDefaults.standard

        // Hermetic. The test bundle is hosted *by the app*, so it shares the
        // app's UserDefaults domain — anything a real run (or a `simctl
        // defaults write` while debugging) left behind is visible here. The
        // master switch in particular suppresses the prompt entirely.
        let ambient = [
            NotificationManager.Keys.promptDismissed,
            NotificationManager.Keys.hasAsked,
            NotificationManager.Keys.authorizationDenied,
            "sproutly_notify_master"
        ]
        for key in ambient { defaults.removeObject(forKey: key) }
        defer { for key in ambient { defaults.removeObject(forKey: key) } }

        // No notification system touched anywhere in this test.
        let manager = NotificationManager(center: nil)
        XCTAssertFalse(manager.shouldOfferPermissionPrompt)

        for index in 0..<NotificationManager.Keys.promptAfterLogs {
            MilestoneLogCounter.record(
                Milestone(
                    title: "Logged \(index)", category: "Language", ageMonth: 12,
                    isCompleted: true, dateCompleted: Date()
                )
            )
        }
        XCTAssertTrue(manager.shouldOfferPermissionPrompt)

        manager.dismissPermissionPrompt()
        XCTAssertFalse(manager.shouldOfferPermissionPrompt, "the prompt came back after dismissal")
    }
}

// MARK: - Pro Discoverability and Currency

@MainActor
final class ProDiscoverabilityTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MilestoneLogCounter.reset()
    }

    override func tearDown() {
        MilestoneLogCounter.reset()
        super.tearDown()
    }

    // Nothing may hardcode a price or a currency. Every figure a parent sees
    // comes from StoreKit's `displayPrice`, already formatted for their store.
    func testNoHardcodedCurrencyAnywhereInTheTarget() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // SproutlyTests
            .deletingLastPathComponent()   // repo root

        let scanned = ["Sproutly", "SproutlyTests"].map {
            sourceRoot.appendingPathComponent($0)
        }

        // Scoped to string literals — the only text that can reach a parent.
        // Scanning raw source instead would flag Swift's `$0` closure shorthand
        // and every `0.75` threshold in the scoring code, none of which is a
        // price. Comments are checked separately below.
        let literal = try NSRegularExpression(pattern: #""([^"\\]|\\.)*""#)
        let currencySymbol = try NSRegularExpression(pattern: #"[$€£¥₹]\s?\d"#)
        let interpolation = try NSRegularExpression(pattern: #"\\\([^)]*\)"#)
        let priceShaped = try NSRegularExpression(
            pattern: #"[$€£¥₹]\s?\d|\b\d+[.,]\d{2}\b"#
        )

        var offenders: [String] = []

        for root in scanned {
            guard let files = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: nil
            ) else { continue }

            for case let url as URL in files where url.pathExtension == "swift" {
                // This test's own patterns would match themselves.
                if url.lastPathComponent == "SproutlyTests.swift" { continue }
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }

                for (index, line) in text.components(separatedBy: .newlines).enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    let range = NSRange(line.startIndex..., in: line)

                    // A price written into a comment is a fact that will drift
                    // the moment per-territory pricing is set, so it counts too
                    // — but only an actual currency amount. Comments are full of
                    // legitimate decimals: contrast ratios, scoring thresholds,
                    // the 4.33 weeks-per-month constant.
                    if trimmed.hasPrefix("//") {
                        let commentRange = NSRange(trimmed.startIndex..., in: trimmed)
                        if currencySymbol.firstMatch(in: trimmed, range: commentRange) != nil {
                            offenders.append("\(url.lastPathComponent):\(index + 1) (comment) — \(trimmed)")
                        }
                        continue
                    }

                    for match in literal.matches(in: line, range: range) {
                        guard let matchRange = Range(match.range, in: line) else { continue }
                        // Interpolations are code, not displayed text, and
                        // `"\($0)"` would otherwise read as a dollar amount.
                        let content = interpolation.stringByReplacingMatches(
                            in: String(line[matchRange]),
                            range: NSRange(
                                String(line[matchRange]).startIndex...,
                                in: String(line[matchRange])
                            ),
                            withTemplate: ""
                        )
                        let contentRange = NSRange(content.startIndex..., in: content)
                        if priceShaped.firstMatch(in: content, range: contentRange) != nil {
                            offenders.append("\(url.lastPathComponent):\(index + 1) — \(content)")
                        }
                    }
                }
            }
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "hardcoded price or currency found:\n" + offenders.joined(separator: "\n")
        )
    }

    // Before the product resolves there must be a neutral placeholder and never
    // a stand-in number, which would be wrong in most of the world.
    func testPaywallShowsNoPriceUntilTheProductResolves() {
        let manager = PurchaseManager()

        XCTAssertNil(manager.product, "no product before StoreKit answers")
        XCTAssertFalse(manager.hasCheckedEntitlements)

        // Every price shown is derived from the product; with none there is
        // nothing to render and the view falls to its spinner branch.
        XCTAssertNil(manager.product?.displayPrice)
    }

    // MARK: The post-value nudge

    func testPhotoNudgeFiresOnceAndNeverAgainAfterDismissal() {
        XCTAssertFalse(MilestoneLogCounter.shouldShowPhotoNudge)

        for index in 0..<MilestoneLogCounter.photoNudgeAfterLogs {
            MilestoneLogCounter.record(
                Milestone(
                    title: "Logged \(index)", category: "Language", ageMonth: 12,
                    isCompleted: true, dateCompleted: Date()
                )
            )
        }

        XCTAssertTrue(MilestoneLogCounter.shouldShowPhotoNudge)

        MilestoneLogCounter.dismissPhotoNudge()
        XCTAssertFalse(MilestoneLogCounter.shouldShowPhotoNudge)

        // Logging more must not bring it back.
        for index in 0..<5 {
            MilestoneLogCounter.record(
                Milestone(
                    title: "More \(index)", category: "Cognitive", ageMonth: 12,
                    isCompleted: true, dateCompleted: Date()
                )
            )
        }
        XCTAssertFalse(MilestoneLogCounter.shouldShowPhotoNudge)
    }

    func testBackfilledMilestonesDoNotAdvanceTheNudgeCounter() {
        for index in 0..<20 {
            MilestoneLogCounter.record(
                Milestone(
                    title: "Backfilled \(index)", category: "Fine Motor", ageMonth: 6,
                    isCompleted: true, dateCompleted: nil
                )
            )
        }
        XCTAssertEqual(MilestoneLogCounter.count, 0)
        XCTAssertFalse(MilestoneLogCounter.shouldShowPhotoNudge)
    }

    // MARK: Reach-triggering

    // The paywall is reached by tapping a locked feature. Nothing may present
    // it from onboarding, from launch, or from a notification.
    func testNoPaywallIsPresentedFromOnboardingLaunchOrNotifications() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sproutly")

        let mustNotPresent = [
            "Views/OnboardingView.swift",
            "Views/OnboardingBackfillStep.swift",
            "Managers/NotificationManager.swift",
            "Managers/NotificationPlanner.swift",
            "Components/DailyNoticeCard.swift",
            "MyApp.swift"
        ]

        for path in mustNotPresent {
            let url = sourceRoot.appendingPathComponent(path)
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(text.contains("PaywallView("), "\(path) presents the paywall")
            XCTAssertFalse(text.contains("paywallReason ="), "\(path) triggers the paywall")
        }
    }

    // Every gated entry point must be visible with a lock rather than hidden —
    // a feature a free parent never sees converts at zero.
    func testEveryGatedEntryPointShowsALockAffordance() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sproutly/Views")

        for file in ["DashboardView.swift", "MilestonesView.swift", "SettingsView.swift"] {
            let text = try String(
                contentsOf: sourceRoot.appendingPathComponent(file), encoding: .utf8
            )
            // The shared badge, or the glyph inside the badge itself.
            XCTAssertTrue(
                text.contains("ProLockBadge()") || text.contains("lock.fill"),
                "\(file) gates a feature without showing a lock"
            )
        }
    }
}

// MARK: - Disclaimers, Attribution and Privacy

final class DisclaimerTests: XCTestCase {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private func allDisplayedStrings() -> [(file: String, text: String)] {
        let root = repoRoot.appendingPathComponent("Sproutly")
        guard let files = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil
        ) else { return [] }

        var found: [(String, String)] = []
        let literal = try? NSRegularExpression(pattern: #""([^"\\]|\\.)*""#)

        for case let url as URL in files where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in text.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("///") else { continue }
                let range = NSRange(line.startIndex..., in: line)
                for match in literal?.matches(in: line, range: range) ?? [] {
                    guard let r = Range(match.range, in: line) else { continue }
                    found.append((url.lastPathComponent, String(line[r])))
                }
            }
        }
        return found
    }

    // A parent who installs this for a two-week-old and finds nothing to track
    // writes the one-star review that says the app doesn't work.
    func testNoStringClaimsCoverageFromBirthOrAgeZero() {
        let claims = ["from birth", "birth to", "0-5", "0–5", "newborns",
                      "from day one", "0 to 5"]

        for (file, text) in allDisplayedStrings() {
            let lowered = text.lowercased()
            for claim in claims {
                XCTAssertFalse(
                    lowered.contains(claim),
                    "\(file) claims coverage \"\(claim)\": \(text)"
                )
            }
        }
    }

    func testTheRealAgeRangeIsStatedWhereItMatters() throws {
        for path in ["Sproutly/Views/OnboardingView.swift",
                     "Sproutly/Views/AboutDataView.swift",
                     "AppStore/LISTING.md"] {
            let text = try source(path)
            XCTAssertTrue(
                text.contains("2 months to 5 years"),
                "\(path) does not state the real age range"
            )
        }
    }

    // D.2 — where to look instead, for a baby younger than the app covers.
    func testYoungerInfantGuidancePointsToThePediatrician() throws {
        for path in ["Sproutly/Views/OnboardingView.swift",
                     "Sproutly/Views/AboutDataView.swift"] {
            let text = try source(path).lowercased()
            XCTAssertTrue(text.contains("pediatrician"), "\(path) omits the guidance")
            XCTAssertTrue(text.contains("well-visit"), "\(path) omits the well-visits")
        }
    }

    // D.3 — the notification disclaimer.
    func testNotificationDisclaimerIsPresentAndNotMedical() throws {
        let text = try source("Sproutly/Views/SettingsView.swift")
        XCTAssertTrue(text.contains("not medical guidance"))
        XCTAssertTrue(text.contains("not an assessment of your child"))
    }

    // D.4 — all three sources named, and no implied endorsement.
    func testAttributionNamesAllSourcesAndClaimsNoEndorsement() throws {
        let text = try source("Sproutly/Views/AboutDataView.swift")

        XCTAssertTrue(text.contains("Learn the Signs"))
        XCTAssertTrue(text.contains("World Health Organization"))
        XCTAssertTrue(text.contains("American Academy of Pediatrics"))

        XCTAssertTrue(text.contains("not affiliated with"))
        XCTAssertTrue(text.contains("endorsed by"))
        XCTAssertTrue(text.contains("reviewed by"))
    }

    // Disclaimers must obey the same tone rule as everything else.
    func testDisclaimerCopyUsesNoAlarmingLanguage() throws {
        let banned = ["delayed", "behind", "at risk", "failed", "abnormal", "disorder"]

        for path in ["Sproutly/Views/AboutDataView.swift",
                     "Sproutly/Views/OnboardingView.swift"] {
            let text = try source(path)
            let literal = try NSRegularExpression(pattern: #""([^"\\]|\\.)*""#)

            for line in text.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                let range = NSRange(line.startIndex..., in: line)
                for match in literal.matches(in: line, range: range) {
                    guard let r = Range(match.range, in: line) else { continue }
                    let content = String(line[r]).lowercased()
                    for word in banned {
                        XCTAssertFalse(content.contains(word), "\(path): \(content)")
                    }
                }
            }
        }
    }

    // D.6 — the privacy manifest must not have moved a byte this phase. Nothing
    // added here makes a network call or touches an API needing a declared
    // reason; local notifications need neither.
    func testPrivacyManifestDeclaresNoCollectionAndNoTracking() throws {
        let manifest = try source("Sproutly/Resources/PrivacyInfo.xcprivacy")

        XCTAssertTrue(manifest.contains("NSPrivacyTracking"))
        XCTAssertTrue(manifest.contains("CA92.1"), "the UserDefaults reason must remain")

        // Data Not Collected: the collected-types array is present and empty.
        XCTAssertTrue(manifest.contains("NSPrivacyCollectedDataTypes"))
        XCTAssertFalse(
            manifest.contains("NSPrivacyCollectedDataType<"),
            "a collected data type appeared — App Privacy is no longer Data Not Collected"
        )

        // And nothing anywhere makes a network call.
        for (file, _) in allDisplayedStrings() where file.hasSuffix(".swift") {
            continue
        }
        let root = repoRoot.appendingPathComponent("Sproutly")
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        for case let url as URL in files ?? .init() where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for banned in ["URLSession", "URLRequest", "NWConnection", "CFNetwork"] {
                XCTAssertFalse(
                    text.contains(banned),
                    "\(url.lastPathComponent) uses \(banned) — the app must make no network calls"
                )
            }
        }
    }

    // The listing reference exists and is outside the compiled target.
    func testListingReferenceExistsAndIsNotInTheTarget() throws {
        let listing = repoRoot.appendingPathComponent("AppStore/LISTING.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: listing.path))

        // project.yml sources only `- path: Sproutly`, so anything outside that
        // directory is excluded by construction rather than by a rule.
        let project = try source("project.yml")
        XCTAssertTrue(project.contains("- path: Sproutly"))
        XCTAssertFalse(project.contains("AppStore"))
    }
}

// MARK: - UI Regressions

@MainActor
final class UIRegressionTests: XCTestCase {

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

    // Adding the two-month band meant a four-month-old satisfied
    // `age >= ageMonth + 2` against it, and their parent — days into the app —
    // was shown a Development Focus card offering Early Intervention.
    func testNoConcernSurfacesForABabyBelowTheFloor() throws {
        for age in [2, 4, 6, 8] {
            let child = try makeChild(ageMonths: age)
            let viewModel = DashboardViewModel()
            viewModel.update(milestones: child.sortedMilestones, child: child)

            XCTAssertTrue(
                viewModel.flaggedMilestones.isEmpty,
                "a \(age)-month-old was flagged"
            )
            XCTAssertFalse(
                viewModel.hasDevelopmentFocus,
                "a \(age)-month-old's parent was shown Development Focus"
            )
        }
    }

    // The floor must not silence a genuine signal for an older child.
    func testConcernStillSurfacesAtAndAboveTheFloor() throws {
        let child = try makeChild(ageMonths: 14)
        let viewModel = DashboardViewModel()
        viewModel.update(milestones: child.sortedMilestones, child: child)

        XCTAssertGreaterThanOrEqual(DashboardViewModel.concernFloorMonths, 9)
        XCTAssertFalse(viewModel.flaggedMilestones.isEmpty)
        XCTAssertTrue(viewModel.hasDevelopmentFocus)
    }

    // The name gate keyed on "is this the last step", which stopped being the
    // profile step the moment a sixth step existed — so a parent could continue
    // with an empty field and land on a screen addressed to "your little one".
    func testOnboardingRequiresANameBeforeLeavingTheProfileStep() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sproutly/Views/OnboardingView.swift"),
            encoding: .utf8
        )

        // Gated on reaching the profile step, and on the trimmed name.
        XCTAssertTrue(source.contains("step >= Self.profileStepIndex && trimmedName.isEmpty"))
        XCTAssertTrue(source.contains(".disabled(isNameMissing || isProcessing)"))

        // The old, broken shape must not come back.
        XCTAssertFalse(source.contains("step == totalSteps - 1 && childName.isEmpty"))

        // And the backfill step is no longer a one-way door.
        XCTAssertTrue(source.contains("goBack()"))
    }

    // A blank or whitespace-only name must never reach a Child.
    func testWhitespaceOnlyNameFallsBackRatherThanRenderingEmpty() {
        XCTAssertEqual(Child(name: "   ", birthDate: Date()).displayName, "Your little one")
        XCTAssertEqual(Child(name: "", birthDate: Date()).displayName, "Your little one")
        XCTAssertEqual(Child(name: " Aanya ", birthDate: Date()).displayName, "Aanya")
    }

    // Uppercase, letter-spaced labels appeared nowhere else in the app; the two
    // in the daily card read as though pasted in from another product.
    func testNoUppercaseTrackedLabelsAnywhere() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sproutly")

        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        for case let url as URL in files ?? .init() where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(
                text.contains("textCase(.uppercase)"),
                "\(url.lastPathComponent) uses an uppercase label"
            )
            XCTAssertFalse(
                text.contains(".tracking("),
                "\(url.lastPathComponent) overrides system tracking"
            )
        }
    }

    // There were five ways of saying "this is Pro": a 19pt gold lock, two
    // caption2 locks in different colours, a footnote grey lock, and a "Pro"
    // text capsule. One mark now, and no view may hand-roll another.
    func testEveryProAffordanceUsesTheSharedBadge() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sproutly")

        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        for case let url as URL in files ?? .init() where url.pathExtension == "swift" {
            // The badge itself is the one place the glyph may be named.
            if url.lastPathComponent == "ProLockBadge.swift" { continue }
            let text = try String(contentsOf: url, encoding: .utf8)

            for line in text.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                XCTAssertFalse(
                    line.contains("Image(systemName: \"lock.fill\")"),
                    "\(url.lastPathComponent) draws its own lock instead of ProLockBadge"
                )
            }
        }
    }

    // Stacking `.sheet` modifiers on one view makes SwiftUI's presentations
    // compete, and some silently never appear. MilestonesView had four and
    // DashboardView two; the former even carried a hand-timed `Task.sleep` to
    // work around two animations chaining. One enum-driven binding per screen.
    func testNoViewStacksSheetModifiers() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sproutly")

        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        for case let url as URL in files ?? .init() where url.pathExtension == "swift" {
            let lines = try String(contentsOf: url, encoding: .utf8)
                .components(separatedBy: .newlines)

            let sheets = lines.filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix(".sheet(") && !trimmed.hasPrefix("//")
            }

            XCTAssertLessThanOrEqual(
                sheets.count, 1,
                "\(url.lastPathComponent) stacks \(sheets.count) sheet modifiers — use one enum-driven binding"
            )
        }
    }

    // The workaround the stacking forced. With one binding the presentation
    // simply changes, so nothing has to be hand-timed.
    func testPhotoPaywallHandoffIsNotHandTimed() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sproutly/Views/MilestonesView.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(
            text.contains("Task.sleep"),
            "a sheet handoff is being timed by hand again"
        )
    }

    // Eight places drew a glyph on a disc; four pinned the disc with a fixed
    // `.frame(width:)` while the glyph used `sproutlyScaledFont`, so at
    // accessibility sizes the icon grew out of its own ornament. `ScaledIconDisc`
    // keeps them in step — nothing may hand-roll the pair again.
    func testNoViewPairsAScaledGlyphWithAFixedDisc() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sproutly")

        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        for case let url as URL in files ?? .init() where url.pathExtension == "swift" {
            // Theme owns ScaledIconDisc, which is the correct implementation.
            if url.lastPathComponent == "Theme.swift" { continue }
            let lines = try String(contentsOf: url, encoding: .utf8)
                .components(separatedBy: .newlines)

            for (index, line) in lines.enumerated() {
                guard line.contains(".frame(width:"),
                      line.range(of: #"\.frame\(width:\s*\d+"#, options: .regularExpression) != nil
                else { continue }

                let before = lines[max(0, index - 3)...index].joined(separator: "\n")
                let after = lines[index..<min(lines.count, index + 7)].joined(separator: "\n")
                guard before.contains("Circle()") || before.contains("RoundedRectangle") else { continue }
                guard after.contains("Image(systemName") else { continue }

                XCTAssertFalse(
                    after.contains("sproutlyScaledFont"),
                    "\(url.lastPathComponent):\(index + 1) — scaled glyph in a fixed disc; use ScaledIconDisc"
                )
            }
        }
    }

    // Measured on a render: the day bronze is 2.76:1 on the card and 2.15:1 on
    // the background — below even the 3:1 WCAG asks of a meaningful glyph. Any
    // gold a parent has to *see* must use the text variant.
    func testGoldMarksUseTheTextSafeVariant() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sproutly")

        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        for case let url as URL in files ?? .init() where url.pathExtension == "swift" {
            // Theme owns the definitions; the gradient is a surface.
            if url.lastPathComponent == "Theme.swift"
                || url.lastPathComponent == "ThemeManager.swift" { continue }
            let text = try String(contentsOf: url, encoding: .utf8)

            for (index, line) in text.components(separatedBy: .newlines).enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("///") else { continue }
                guard line.contains("foregroundStyle") || line.contains("iconColor:")
                    || line.contains("tint:") else { continue }
                // `proGoldText` legitimately contains "proGold" as a prefix.
                let usesSurfaceGold = line.contains("proGold")
                    && !line.contains("proGoldText")
                    && !line.contains("proGoldGradient")
                XCTAssertFalse(
                    usesSurfaceGold,
                    "\(url.lastPathComponent):\(index + 1) draws a gold mark in the surface tint"
                )
            }
        }
    }

    // Settings listed every Pro feature inline *and* opened a paywall that
    // lists the same features, one tap apart.
    func testSettingsDoesNotDuplicateThePaywallsFeatureList() throws {
        let settings = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sproutly/Views/SettingsView.swift"),
            encoding: .utf8
        )

        // The shared list appears exactly once on this screen...
        let occurrences = settings.components(separatedBy: "ProFeatureListView()").count - 1
        XCTAssertEqual(occurrences, 1, "the Pro feature list is rendered \(occurrences) times")

        // ...and there is one route to the paywall from the Pro card, not a
        // chevron row duplicating what sits directly beneath it.
        XCTAssertTrue(settings.contains("See Sproutly Pro"))
    }

    // Two of four tabs faded content under the status bar and two did not, so a
    // card's text collided with the clock on Dashboard and Milestones.
    func testEveryScrollingTabFadesContentUnderTheStatusBar() throws {
        let views = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sproutly/Views")

        for file in ["DashboardView.swift", "MilestonesView.swift",
                     "SettingsView.swift", "AssistantView.swift"] {
            let text = try String(
                contentsOf: views.appendingPathComponent(file), encoding: .utf8
            )
            XCTAssertTrue(
                text.contains("scrollEdgeFade()") || text.contains(".mask("),
                "\(file) has no scroll edge effect"
            )
        }
    }

    // `.underlineField` draws its own rule; a `Theme.divider` immediately after
    // it rendered two parallel lines 8pt apart.
    func testNoDividerImmediatelyFollowsAnUnderlinedField() throws {
        let views = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sproutly/Views")

        for file in ["AddChildSheet.swift", "OnboardingView.swift", "SettingsView.swift"] {
            let text = try String(
                contentsOf: views.appendingPathComponent(file), encoding: .utf8
            )
            let lines = text.components(separatedBy: .newlines)

            for (index, line) in lines.enumerated() where line.contains("underlineField(") {
                // Look at the next few meaningful lines for a divider before any
                // other content intervenes.
                let window = lines[index..<min(index + 10, lines.count)]
                var sawContent = false
                for next in window.dropFirst() {
                    let trimmed = next.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix(".") { continue }
                    if trimmed.contains("Theme.divider") && !sawContent {
                        XCTFail("\(file):\(index + 1) — divider directly under an underlined field")
                    }
                    sawContent = true
                }
            }
        }
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
