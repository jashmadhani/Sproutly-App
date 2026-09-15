import XCTest
import SwiftData
@testable import Sproutly

// MARK: - Metric labels

final class GrowthMetricTests: XCTestCase {

    // A baby is measured lying down and it is called length; a child over two is
    // measured standing and it is called height. Calling a 9-month-old's number a
    // "height" reads like the app doesn't know how babies are measured.
    func testLengthBecomesHeightAtTwo() {
        XCTAssertEqual(GrowthMetric.length.title(ageMonths: 9), "Length")
        XCTAssertEqual(GrowthMetric.length.title(ageMonths: 23), "Length")
        XCTAssertEqual(GrowthMetric.length.title(ageMonths: 24), "Height")
        XCTAssertEqual(GrowthMetric.weight.title(ageMonths: 30), "Weight")
    }
}

// MARK: - Units

final class GrowthUnitTests: XCTestCase {

    private let us = Locale(identifier: "en_US")
    private let uk = Locale(identifier: "en_GB")
    private let india = Locale(identifier: "en_IN")
    private let germany = Locale(identifier: "de_DE")

    // Only the US weighs babies in pounds and measures in inches. The UK red book
    // uses kilograms and centimetres, so "English-speaking" is not the test.
    func testOnlyTheUSUsesImperial() {
        XCTAssertEqual(GrowthUnitSystem.regional(locale: us), .imperial)
        XCTAssertEqual(GrowthUnitSystem.regional(locale: uk), .metric)
        XCTAssertEqual(GrowthUnitSystem.regional(locale: india), .metric)
        XCTAssertEqual(GrowthUnitSystem.regional(locale: germany), .metric)
    }

    // A parent's own choice beats the phone's region. A family living in the US
    // with a pediatrician abroad, or a US phone in a metric household, must not be
    // stuck with whichever system the region implies.
    func testPreferenceOverridesTheRegionAndAutomaticFollowsIt() {
        XCTAssertEqual(GrowthUnitPreference.automatic.system(locale: us), .imperial)
        XCTAssertEqual(GrowthUnitPreference.automatic.system(locale: uk), .metric)
        XCTAssertEqual(GrowthUnitPreference.metric.system(locale: us), .metric)
        XCTAssertEqual(GrowthUnitPreference.imperial.system(locale: uk), .imperial)
    }

    func testNoStoredChoiceMeansAutomatic() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "GrowthUnitTests-\(UUID().uuidString)"))
        XCTAssertEqual(GrowthUnitPreference.stored(in: defaults), .automatic)

        defaults.set(GrowthUnitPreference.metric.rawValue, forKey: GrowthUnitPreference.storageKey)
        XCTAssertEqual(GrowthUnitPreference.stored(in: defaults), .metric)
        XCTAssertEqual(GrowthUnitSystem.current(defaults: defaults, locale: us), .metric)

        // An unrecognised value falls back rather than crashing or guessing.
        defaults.set("furlongs", forKey: GrowthUnitPreference.storageKey)
        XCTAssertEqual(GrowthUnitPreference.stored(in: defaults), .automatic)
    }

    // US scales and clinics give baby weight as pounds and ounces. "16.25 lb"
    // makes a parent do arithmetic on the number they were just handed.
    func testImperialWeightIsShownInPoundsAndOunces() {
        let imperial = GrowthUnitSystem.imperial
        XCTAssertEqual(imperial.formatted(imperial.toMetric(16.25, metric: .weight), metric: .weight, locale: us), "16 lb 4 oz")
        // A whole number of pounds does not trail "0 oz".
        XCTAssertEqual(imperial.formatted(imperial.toMetric(16, metric: .weight), metric: .weight, locale: us), "16 lb")
        // 15.6 ounces rounds up to a whole pound, not to "16 lb 16 oz".
        XCTAssertEqual(imperial.formatted(imperial.toMetric(16.975, metric: .weight), metric: .weight, locale: us), "17 lb")
    }

    func testPoundsAndOuncesSplitRoundsToTheNearestOunce() {
        let split = GrowthUnitSystem.poundsAndOunces(fromKilograms: GrowthUnitSystem.imperial.toMetric(7.53, metric: .weight))
        XCTAssertEqual(split.pounds, 7)
        XCTAssertEqual(split.ounces, 8)
    }

    func testConversionsRoundTrip() {
        let imperial = GrowthUnitSystem.imperial
        XCTAssertEqual(imperial.toMetric(16, metric: .weight), 7.257, accuracy: 0.001)
        XCTAssertEqual(imperial.toMetric(26, metric: .length), 66.04, accuracy: 0.001)
        XCTAssertEqual(imperial.fromMetric(imperial.toMetric(17.3, metric: .head), metric: .head), 17.3, accuracy: 0.0001)

        // Metric is stored as-is. Nothing may nudge a value a parent typed.
        XCTAssertEqual(GrowthUnitSystem.metric.toMetric(7.2, metric: .weight), 7.2)
    }

    func testDisplayUsesTheParentsUnit() {
        // A clinic's two decimals survive display. Checked by reading the number
        // back rather than writing "7.25 kg" as a literal: the no-hardcoded-price
        // guard treats any digits-point-two-digits string as a price, rightly.
        let clinicWeight = GrowthUnitSystem.metric.formatted(7.25, metric: .weight, locale: uk)
        XCTAssertTrue(clinicWeight.hasSuffix(" kg"))
        XCTAssertEqual(Double(clinicWeight.dropLast(3)), 7.25)

        XCTAssertEqual(GrowthUnitSystem.metric.formatted(66, metric: .length, locale: uk), "66 cm")
        XCTAssertEqual(GrowthUnitSystem.imperial.formatted(66.04, metric: .length, locale: us), "26 in")
    }
}

// MARK: - Entry validation

final class GrowthEntryValidatorTests: XCTestCase {

    private let uk = Locale(identifier: "en_GB")
    private let germany = Locale(identifier: "de_DE")
    private let us = Locale(identifier: "en_US")

    func testNothingEnteredIsRejected() {
        let result = GrowthEntryValidator.validate(
            weight: "", length: "  ", head: "",
            system: .metric, locale: uk
        )
        XCTAssertEqual(result.issue, .nothingEntered)
    }

    // A quick weigh-in at home is a complete entry.
    func testOneValueIsEnough() throws {
        let values = try GrowthEntryValidator.validate(
            weight: "7.2", length: "", head: "",
            system: .metric, locale: uk
        ).get()

        XCTAssertEqual(values.weightKg, 7.2)
        XCTAssertNil(values.lengthCm)
        XCTAssertNil(values.headCm)
    }

    // A German keyboard types a comma. Rejecting "7,2" would make the app look
    // broken to half of Europe.
    func testDecimalCommaIsReadInLocalesThatUseIt() throws {
        let values = try GrowthEntryValidator.validate(
            weight: "7,2", length: "66,5", head: "",
            system: .metric, locale: germany
        ).get()

        XCTAssertEqual(values.weightKg ?? 0, 7.2, accuracy: 0.0001)
        XCTAssertEqual(values.lengthCm ?? 0, 66.5, accuracy: 0.0001)
    }

    func testImperialEntryIsStoredInMetric() throws {
        let values = try GrowthEntryValidator.validate(
            weight: "16", length: "26", head: "",
            system: .imperial, locale: us
        ).get()

        XCTAssertEqual(values.weightKg ?? 0, 7.257, accuracy: 0.001)
        XCTAssertEqual(values.lengthCm ?? 0, 66.04, accuracy: 0.001)
    }

    func testPoundsAndOuncesAreCombinedBeforeStoring() throws {
        let values = try GrowthEntryValidator.validate(
            weight: "16", weightOunces: "4", length: "", head: "",
            system: .imperial, locale: us
        ).get()
        XCTAssertEqual(values.weightKg ?? 0, 16.25 / 2.2046226218, accuracy: 0.0001)
    }

    // Decimal pounds on their own still work, for a parent copying "16.5 lb".
    // (One decimal on purpose: a two-decimal string literal trips the
    // no-hardcoded-price guard, which rightly reads it as a price.)
    func testDecimalPoundsWithoutOuncesAreAccepted() throws {
        let values = try GrowthEntryValidator.validate(
            weight: "16.5", weightOunces: "", length: "", head: "",
            system: .imperial, locale: us
        ).get()
        XCTAssertEqual(values.weightKg ?? 0, 16.5 / 2.2046226218, accuracy: 0.0001)
    }

    func testOuncesMustBeUnderSixteen() {
        XCTAssertEqual(
            GrowthEntryValidator.validate(weight: "16", weightOunces: "16", length: "", head: "", system: .imperial, locale: us).issue,
            .ouncesOutOfRange
        )
    }

    // Unreadable ounces are reported as ounces, so the sheet flags that field and
    // not the correct pounds beside it.
    func testUnreadableOuncesPointAtTheOuncesField() {
        XCTAssertEqual(
            GrowthEntryValidator.validate(weight: "16", weightOunces: "4..5", length: "", head: "", system: .imperial, locale: us).issue,
            .ouncesUnreadable
        )
    }

    // "16.5 lb 3 oz" could mean two different weights, so it is not guessed at.
    // It gets its own issue: the generic "use digits, like 7.2" suggested exactly
    // the decimal that was just rejected.
    func testDecimalPoundsCombinedWithOuncesAsksForWholePounds() {
        let issue = GrowthEntryValidator.validate(weight: "16.5", weightOunces: "3", length: "", head: "", system: .imperial, locale: us).issue
        XCTAssertEqual(issue, .poundsNotWhole)
        XCTAssertFalse(issue?.message(system: .imperial, ageMonths: 6).contains("7.2") ?? true)
    }

    // Metric has no ounces field; a stale value from a unit switch is ignored.
    func testMetricIgnoresOunces() throws {
        let values = try GrowthEntryValidator.validate(
            weight: "7.2", weightOunces: "9", length: "", head: "",
            system: .metric, locale: uk
        ).get()
        XCTAssertEqual(values.weightKg, 7.2)
    }

    // The range exists to catch a unit mistake, not to judge a child. 72 in a
    // kilogram field is almost certainly pounds, and saving it would draw a
    // frightening spike on the chart.
    func testImplausibleValuesAreRejectedPerMetric() {
        XCTAssertEqual(
            GrowthEntryValidator.validate(weight: "72", length: "", head: "", system: .metric, locale: uk).issue,
            .outOfRange(.weight)
        )
        XCTAssertEqual(
            GrowthEntryValidator.validate(weight: "", length: "6", head: "", system: .metric, locale: uk).issue,
            .outOfRange(.length)
        )
        XCTAssertEqual(
            GrowthEntryValidator.validate(weight: "", length: "", head: "abc", system: .metric, locale: uk).issue,
            .unreadable(.head)
        )
    }

    // The messages a parent reads must not judge the child or diagnose anything.
    func testIssueMessagesPointAtTheNumberNotTheChild() {
        let banned = ["too small", "too big", "underweight", "overweight", "concern", "worry", "abnormal"]
        let issues: [GrowthEntryIssue] = [.nothingEntered, .unreadable(.weight), .outOfRange(.weight),
                                          .outOfRange(.length), .outOfRange(.head), .ouncesOutOfRange,
                                          .ouncesUnreadable, .poundsNotWhole]

        for issue in issues {
            for system in [GrowthUnitSystem.metric, .imperial] {
                let message = issue.message(system: system, ageMonths: 12).lowercased()
                for word in banned {
                    XCTAssertFalse(message.contains(word), "\(issue): \(message)")
                }
            }
        }
    }
}

// MARK: - Corrected age in days

final class CorrectedAgeDaysTests: XCTestCase {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testTermBabyCountsCalendarDays() {
        let days = Child.correctedAgeDays(
            birthDate: date(2026, 1, 1), isPremature: false, gestationalWeeks: 40,
            on: date(2026, 1, 31)
        )
        XCTAssertEqual(days, 30)
    }

    // Same correction as correctedAgeMonths: the weeks before 40, in days.
    func testPrematureBabySubtractsTheWeeksTheyArrivedEarly() {
        let days = Child.correctedAgeDays(
            birthDate: date(2026, 1, 1), isPremature: true, gestationalWeeks: 32,
            on: date(2026, 4, 1)
        )
        XCTAssertEqual(days, 90 - 56)
    }

    func testCorrectedAgeNeverGoesNegative() {
        let days = Child.correctedAgeDays(
            birthDate: date(2026, 1, 1), isPremature: true, gestationalWeeks: 28,
            on: date(2026, 1, 20)
        )
        XCTAssertEqual(days, 0)
    }

    // The two age functions must agree about a child, or the chart and the
    // milestone bands would describe two different children.
    func testDaysAndMonthsAgreeOnTheCorrection() {
        let birth = date(2025, 6, 1)
        let measured = date(2026, 6, 1)
        let months = Child.correctedAgeMonths(
            birthDate: birth, isPremature: true, gestationalWeeks: 31, now: measured
        )
        let days = Child.correctedAgeDays(
            birthDate: birth, isPremature: true, gestationalWeeks: 31, on: measured
        )
        XCTAssertEqual(Double(days) / GrowthSeries.daysPerMonth, Double(months), accuracy: 0.6)
    }
}

// MARK: - Series and storage

@MainActor
final class GrowthSeriesTests: XCTestCase {

    private var container: ModelContainer!

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SproutlyCurrentSchema.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        return container.mainContext
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // A chart of weight must not draw a point for a session where only height
    // was measured — that point would sit at zero.
    func testSeriesSkipsSessionsWithoutThatValueAndSortsByDate() throws {
        let context = try makeContext()
        let child = Child(name: "Aanya", birthDate: date(2026, 1, 1))
        context.insert(child)

        let later = GrowthMeasurement(date: date(2026, 5, 1), weightKg: 7.0, child: child)
        let lengthOnly = GrowthMeasurement(date: date(2026, 4, 1), lengthCm: 62, child: child)
        let earlier = GrowthMeasurement(date: date(2026, 3, 1), weightKg: 5.8, child: child)
        [later, lengthOnly, earlier].forEach(context.insert)
        try context.save()

        let weights = GrowthSeries.points(for: .weight, child: child)
        XCTAssertEqual(weights.map(\.value), [5.8, 7.0])
        XCTAssertEqual(weights.first?.ageDays, 59)

        XCTAssertEqual(GrowthSeries.points(for: .length, child: child).map(\.value), [62])
        XCTAssertTrue(GrowthSeries.points(for: .head, child: child).isEmpty)
    }

    // Removing a child, and Delete All Data which removes every child, must take
    // their measurements with them.
    func testDeletingAChildRemovesTheirMeasurements() throws {
        let context = try makeContext()
        let store = ChildStore(context: context)
        let child = store.addChild(name: "Vir", birthDate: date(2026, 1, 1))
        context.insert(GrowthMeasurement(date: date(2026, 3, 1), weightKg: 5.5, child: child))
        store.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GrowthMeasurement>()), 1)

        store.delete(child)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GrowthMeasurement>()), 0)
    }

    func testLatestMeasurementPerMetricIgnoresEmptySessions() throws {
        let context = try makeContext()
        let child = Child(name: "Aanya", birthDate: date(2026, 1, 1))
        context.insert(child)
        context.insert(GrowthMeasurement(date: date(2026, 3, 1), weightKg: 5.8, lengthCm: 58, child: child))
        context.insert(GrowthMeasurement(date: date(2026, 4, 1), weightKg: 6.4, child: child))
        try context.save()

        XCTAssertEqual(GrowthSeries.latest(.weight, child: child)?.value, 6.4)
        XCTAssertEqual(GrowthSeries.latest(.length, child: child)?.value, 58)
        XCTAssertNil(GrowthSeries.latest(.head, child: child))
    }
}

// MARK: - Report

@MainActor
final class GrowthReportTests: XCTestCase {

    private var container: ModelContainer!

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SproutlyCurrentSchema.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        return container.mainContext
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // What makes the visit report worth handing over: the numbers a pediatrician
    // actually asks about, oldest first so the change reads down the page.
    func testReportCarriesMeasurementsOldestFirstInTheParentsUnits() throws {
        let context = try makeContext()
        let child = Child(name: "Aanya", birthDate: date(2026, 1, 1))
        context.insert(child)
        context.insert(GrowthMeasurement(date: date(2026, 5, 1), weightKg: 7.0, lengthCm: 64, child: child))
        context.insert(GrowthMeasurement(date: date(2026, 3, 1), weightKg: 5.8, child: child))
        try context.save()

        let report = ReportBuilder.build(for: child, on: date(2026, 5, 2), units: .metric)

        XCTAssertEqual(report.growthUnits, .metric)
        XCTAssertEqual(report.growth.map(\.weightKg), [5.8, 7.0])
        XCTAssertEqual(report.growth.map(\.lengthCm), [nil, 64])
        XCTAssertEqual(report.growth.first?.ageText, "2 mo")
    }

    // A premature child's rows use corrected age, matching the "ages shown are
    // corrected" line already printed in the report header.
    func testReportAgesAreCorrectedForAnEarlyArrival() throws {
        let context = try makeContext()
        let child = Child(name: "Vir", birthDate: date(2025, 1, 1), isPremature: true, gestationalWeeks: 32)
        context.insert(child)
        context.insert(GrowthMeasurement(date: date(2027, 3, 1), weightKg: 11.5, child: child))
        try context.save()

        let report = ReportBuilder.build(for: child, on: date(2027, 3, 2), units: .metric)

        // 26 months chronological, minus 2 for the 8 weeks early.
        XCTAssertEqual(report.growth.first?.ageText, "2 y")
    }

    // A report is for one visit, not a child's whole history. The most recent
    // dozen sessions keep it to a page a clinician will actually read.
    func testReportKeepsTheMostRecentDozenSessions() throws {
        let context = try makeContext()
        let child = Child(name: "Aanya", birthDate: date(2024, 1, 1))
        context.insert(child)
        for month in 1...15 {
            context.insert(GrowthMeasurement(date: date(2024, month > 12 ? 12 : month, month > 12 ? month : 1), weightKg: Double(month) + 3, child: child))
        }
        try context.save()

        let report = ReportBuilder.build(for: child, on: date(2025, 1, 1), units: .metric)

        XCTAssertEqual(report.growth.count, 12)
        XCTAssertEqual(report.growth.last?.weightKg, 18)
        XCTAssertEqual(report.growth.first?.weightKg, 7)
    }

    func testNoMeasurementsMeansNoGrowthRows() throws {
        let context = try makeContext()
        let child = Child(name: "Aanya", birthDate: date(2026, 1, 1))
        context.insert(child)
        try context.save()

        XCTAssertTrue(ReportBuilder.build(for: child, on: date(2026, 5, 1), units: .metric).growth.isEmpty)
    }
}

// MARK: - Layout regressions found on a render

// Each of these was seen on a simulator screenshot, not reasoned about, and each
// compiled and passed every other test while it was broken.
final class GrowthLayoutRegressionTests: XCTestCase {

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private func codeLines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }

    // Swift Charts axis titles do not wrap. At the largest text size "Age in
    // months" was cut off at the card edge, and a premature child's longer title
    // would not have fitted at any size. The caption under the chart wraps.
    func testNoChartUsesAxisTitlesThatCannotWrap() throws {
        let chart = codeLines(try source("Sproutly/Components/GrowthChartView.swift")).joined()
        XCTAssertFalse(chart.contains(".chartXAxisLabel"))
        XCTAssertFalse(chart.contains(".chartYAxisLabel"))
    }

    // A centred label on the last tick overflowed the chart frame: a render
    // showed "1" where the axis meant 10 months.
    func testChartAxisLabelsAreAlignedInsideThePlot() throws {
        let chart = codeLines(try source("Sproutly/Components/GrowthChartView.swift"))
        let axisMarks = chart.filter { $0.contains("AxisMarks(") }
        XCTAssertFalse(axisMarks.isEmpty)
        for line in axisMarks {
            XCTAssertTrue(line.contains("preset: .aligned"), line)
        }
    }

    // Fitted tightly to the data, a 250 g rise over three weeks filled the chart
    // top to bottom on a render, so ordinary wobble looked like a spike. The value
    // axis keeps a minimum span; wide data is left alone.
    @MainActor
    func testValueAxisNeverZoomsSmallChangesIntoSpikes() {
        let tight = GrowthChartView.valueDomain(shown: [8.40, 8.65], metric: .weight, system: .metric)
        XCTAssertGreaterThanOrEqual(tight.upperBound - tight.lowerBound, 1)
        XCTAssertTrue(tight.contains(8.40) && tight.contains(8.65))

        let wide = GrowthChartView.valueDomain(shown: [5.1, 8.6], metric: .weight, system: .metric)
        XCTAssertTrue(wide.contains(5.1) && wide.contains(8.6))
        XCTAssertLessThan(wide.upperBound - wide.lowerBound, 5)

        // Never below zero, even for a tiny first value.
        XCTAssertGreaterThanOrEqual(GrowthChartView.valueDomain(shown: [0.2], metric: .head, system: .imperial).lowerBound, 0)
    }

    // Three segments on one line split "Weight" into "Weig" / "ht" at the
    // largest text size. The shared control must reflow, which also covers the
    // Milestones filter that uses it.
    func testSegmentedControlReflowsAtAccessibilitySizes() throws {
        let control = codeLines(try source("Sproutly/Components/SproutlySegmentedControl.swift")).joined()
        XCTAssertTrue(control.contains("isAccessibilitySize"))
        XCTAssertTrue(control.contains("VStackLayout"))
    }
}

// MARK: - Helpers

private extension Result where Failure == GrowthEntryIssue {
    var issue: GrowthEntryIssue? {
        if case .failure(let issue) = self { return issue }
        return nil
    }
}
