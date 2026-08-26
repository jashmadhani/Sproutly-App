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
