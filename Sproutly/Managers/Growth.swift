//
//  Growth.swift
//  Sproutly
//

import Foundation

// The pure core of the Growth feature, testable without a view the way
// DevelopmentObserver is: what each measurement is called, which units a parent
// sees, whether what they typed can be saved, and the points a chart draws.
//
// Nothing here judges a child. There are no percentiles, no "expected" values and
// no comparison with other children yet. The plausible ranges below exist only to
// catch a unit mistake before it draws a frightening spike on the chart. When the
// WHO comparison curves arrive, they belong in their own type, not in here.

// MARK: - Metric

enum GrowthMetric: String, CaseIterable, Identifiable, Sendable {
    case weight
    case length
    case head

    var id: String { rawValue }

    /// Length and height are the same value measured two ways. Under two a child
    /// lies down for it and it is called length; from two they stand and it is
    /// called height.
    func title(ageMonths: Int) -> String {
        switch self {
        case .weight: return "Weight"
        case .length: return ageMonths < 24 ? "Length" : "Height"
        case .head:   return "Head"
        }
    }

    /// The same word used mid-sentence, where "Head" alone reads wrong.
    func phrase(ageMonths: Int) -> String {
        switch self {
        case .weight: return "weight"
        case .length: return ageMonths < 24 ? "length" : "height"
        case .head:   return "head size"
        }
    }

    var systemImage: String {
        switch self {
        case .weight: return "scalemass"
        case .length: return "ruler"
        case .head:   return "circle.dashed"
        }
    }

    /// Wide on purpose. A preemie can weigh under 2 kg at a corrected two months,
    /// and some parents keep logging past five. These bounds only reject numbers
    /// that cannot be a young child's measurement in the unit shown, which in
    /// practice means the wrong unit or a slipped decimal point.
    var plausibleMetricRange: ClosedRange<Double> {
        switch self {
        case .weight: return 1.0...40.0
        case .length: return 35.0...130.0
        case .head:   return 28.0...58.0
        }
    }
}

// MARK: - Units

enum GrowthUnitSystem: Equatable, Sendable {
    case metric
    case imperial

    private static let poundsPerKilogram = 2.2046226218
    private static let centimetresPerInch = 2.54

    /// What the phone's region implies. Only the US measures babies in pounds and
    /// inches; the UK's red book uses kilograms and centimetres, so this keys off
    /// the measurement system rather than language or region families.
    ///
    /// This is the default, not the answer. Use `current()`, which lets a parent's
    /// own choice in Settings win.
    static func regional(locale: Locale = .current) -> GrowthUnitSystem {
        locale.measurementSystem == .us ? .imperial : .metric
    }

    /// The system every screen and the report should use: the parent's choice in
    /// Settings, or the region when they have left it on Automatic.
    ///
    /// Units used to follow the region with no way to change them, which stranded
    /// a US phone in a metric household on pounds.
    static func current(defaults: UserDefaults = .standard, locale: Locale = .current) -> GrowthUnitSystem {
        GrowthUnitPreference.stored(in: defaults).system(locale: locale)
    }

    func unitSymbol(for metric: GrowthMetric) -> String {
        switch (self, metric) {
        case (.metric, .weight):   return "kg"
        case (.metric, _):         return "cm"
        case (.imperial, .weight): return "lb"
        case (.imperial, _):       return "in"
        }
    }

    func toMetric(_ value: Double, metric: GrowthMetric) -> Double {
        guard self == .imperial else { return value }
        switch metric {
        case .weight:         return value / Self.poundsPerKilogram
        case .length, .head:  return value * Self.centimetresPerInch
        }
    }

    func fromMetric(_ value: Double, metric: GrowthMetric) -> Double {
        guard self == .imperial else { return value }
        switch metric {
        case .weight:         return value * Self.poundsPerKilogram
        case .length, .head:  return value / Self.centimetresPerInch
        }
    }

    /// A stored metric value, shown in this system: "7.25 kg", "26 in", "16 lb 4 oz".
    ///
    /// Up to two decimals and never padded, so a clinic's 7.25 keeps its precision
    /// and a home scale's 7 does not grow a meaningless ".00".
    ///
    /// Imperial weight is pounds and ounces, because that is what US scales and
    /// clinics hand a parent. "16.25 lb" would make them convert the number they
    /// were just given. A whole number of pounds does not trail "0 oz".
    func formatted(_ metricValue: Double, metric: GrowthMetric, locale: Locale = .current) -> String {
        if self == .imperial, metric == .weight {
            let split = Self.poundsAndOunces(fromKilograms: metricValue)
            return split.ounces == 0 ? "\(split.pounds) lb" : "\(split.pounds) lb \(split.ounces) oz"
        }
        return "\(number(metricValue, metric: metric, locale: locale)) \(unitSymbol(for: metric))"
    }

    /// Kilograms as whole pounds and whole ounces, rounded to the nearest ounce.
    ///
    /// Rounded as a total of ounces first and then split, so 16 lb 15.6 oz becomes
    /// 17 lb 0 oz rather than the impossible "16 lb 16 oz".
    static func poundsAndOunces(fromKilograms kilograms: Double) -> (pounds: Int, ounces: Int) {
        let totalOunces = Int((kilograms * poundsPerKilogram * 16).rounded())
        return (totalOunces / 16, totalOunces % 16)
    }

    /// The number alone, for a field being edited or a chart axis.
    func number(_ metricValue: Double, metric: GrowthMetric, locale: Locale = .current) -> String {
        fromMetric(metricValue, metric: metric)
            .formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }
}

// MARK: - Unit preference

/// The parent's choice in Settings. Stored as a raw string so `@AppStorage` can
/// hold it and every view reading it redraws when it changes.
enum GrowthUnitPreference: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case metric
    case imperial

    static let storageKey = "sproutly_measurement_units"

    var id: String { rawValue }

    func system(locale: Locale = .current) -> GrowthUnitSystem {
        switch self {
        case .automatic: return .regional(locale: locale)
        case .metric:    return .metric
        case .imperial:  return .imperial
        }
    }

    /// Missing or unrecognised means Automatic, so a value from a future version
    /// or a typo never strands a parent in the wrong units.
    static func stored(in defaults: UserDefaults = .standard) -> GrowthUnitPreference {
        defaults.string(forKey: storageKey).flatMap(GrowthUnitPreference.init(rawValue:)) ?? .automatic
    }

    /// The short value shown on the Settings row.
    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .metric:    return "Metric"
        case .imperial:  return "Imperial"
        }
    }

    /// The menu choice, naming the actual units so a parent does not have to know
    /// which system uses which. Automatic names what the region resolves to.
    func menuTitle(locale: Locale = .current) -> String {
        switch self {
        case .automatic:
            let resolved = system(locale: locale)
            return "Automatic (\(resolved == .imperial ? "lb, oz, in" : "kg, cm"))"
        case .metric:
            return "Metric (kg, cm)"
        case .imperial:
            return "Imperial (lb, oz, in)"
        }
    }
}

// MARK: - Entry validation

struct GrowthValues: Equatable, Sendable {
    var weightKg: Double?
    var lengthCm: Double?
    var headCm: Double?
}

enum GrowthEntryIssue: Error, Equatable, Sendable {
    case nothingEntered
    case unreadable(GrowthMetric)
    case outOfRange(GrowthMetric)
    /// Sixteen or more ounces. Said separately, because "check the weight" does
    /// not tell a parent which of the two weight fields is wrong.
    case ouncesOutOfRange
    /// The ounces text cannot be read. Separate from `.unreadable(.weight)` so
    /// the ounces field is the one flagged and focused, not the pounds beside it.
    case ouncesUnreadable
    /// Decimal pounds typed alongside ounces ("16.5 lb 3 oz"). Its own case because
    /// the generic unreadable message suggests "like 7.2", the very decimal that
    /// was just refused.
    case poundsNotWhole

    /// What a parent reads under the field. It talks about the number and the
    /// unit, never about the child — a mistyped value is not a finding.
    func message(system: GrowthUnitSystem, ageMonths: Int) -> String {
        switch self {
        case .nothingEntered:
            return "Add at least one measurement to save."
        case .unreadable(let metric):
            return "That \(metric.phrase(ageMonths: ageMonths)) isn't a number we can read. Use digits, like 7.2."
        case .outOfRange(let metric):
            return "Check the \(metric.phrase(ageMonths: ageMonths)). It doesn't look like a measurement in \(system.unitSymbol(for: metric))."
        case .ouncesOutOfRange:
            return "Check the ounces. They go up to 15, then the next pound starts."
        case .ouncesUnreadable:
            return "Those ounces aren't a number we can read. Use digits, like 4."
        case .poundsNotWhole:
            return "Use whole pounds when you add ounces, like 16 lb 3 oz."
        }
    }

    var metric: GrowthMetric? {
        switch self {
        case .nothingEntered:            return nil
        case .unreadable(let metric),
             .outOfRange(let metric):    return metric
        case .ouncesOutOfRange,
             .ouncesUnreadable,
             .poundsNotWhole:            return .weight
        }
    }
}

enum GrowthEntryValidator {

    /// Turns three typed strings into metric values, or the first problem found.
    ///
    /// Checked in the order the fields appear on screen, so the message a parent
    /// sees always refers to the topmost field that needs attention.
    static func validate(
        weight: String,
        weightOunces: String = "",
        length: String,
        head: String,
        system: GrowthUnitSystem,
        locale: Locale = .current
    ) -> Result<GrowthValues, GrowthEntryIssue> {
        let fields: [(GrowthMetric, String)] = [(.weight, weight), (.length, length), (.head, head)]
        var values = GrowthValues()
        var anyEntered = false

        // Ounces only exist in imperial. In metric a leftover value from before a
        // unit switch is ignored rather than added to a kilogram figure.
        let ounceText = system == .imperial
            ? weightOunces.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        for (metric, raw) in fields {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let usesOunces = metric == .weight && !ounceText.isEmpty
            guard !text.isEmpty || usesOunces else { continue }
            anyEntered = true

            let typed: Double
            if usesOunces {
                // Pounds with ounces must be whole pounds. "16.5 lb 3 oz" could
                // mean two different weights, so it is not guessed at. Empty
                // pounds with ounces is zero pounds.
                let pounds: Double
                if text.isEmpty {
                    pounds = 0
                } else {
                    guard let parsed = parse(text, locale: locale) else {
                        return .failure(.unreadable(.weight))
                    }
                    guard parsed.rounded() == parsed else {
                        return .failure(.poundsNotWhole)
                    }
                    pounds = parsed
                }
                guard let ounces = parse(ounceText, locale: locale) else {
                    return .failure(.ouncesUnreadable)
                }
                guard ounces < 16 else { return .failure(.ouncesOutOfRange) }
                typed = pounds + ounces / 16
            } else {
                guard let parsed = parse(text, locale: locale) else {
                    return .failure(.unreadable(metric))
                }
                typed = parsed
            }

            let stored = system.toMetric(typed, metric: metric)
            guard metric.plausibleMetricRange.contains(stored) else {
                return .failure(.outOfRange(metric))
            }

            switch metric {
            case .weight: values.weightKg = stored
            case .length: values.lengthCm = stored
            case .head:   values.headCm = stored
            }
        }

        return anyEntered ? .success(values) : .failure(.nothingEntered)
    }

    /// Reads a decimal whichever mark the parent used.
    ///
    /// A German keyboard's decimal pad types "7,2"; a parent copying "7.2" from a
    /// clinic letter types a point. Both mean the same thing here, because no
    /// child's measurement is large enough to need a thousands separator — the
    /// biggest plausible value is 130 — so either mark can safely be read as the
    /// decimal point in every locale. `locale` is kept so a future format with
    /// real grouping has somewhere to go.
    static func parse(_ text: String, locale: Locale) -> Double? {
        // Digits and one decimal mark only. "7kg", "7 1/2" and "abc" are all
        // unreadable rather than quietly read as something else.
        let allowed = CharacterSet(charactersIn: "0123456789.,")
        guard text.unicodeScalars.allSatisfy(allowed.contains) else { return nil }

        let normalised = text.replacingOccurrences(of: ",", with: ".")
        guard normalised.filter({ $0 == "." }).count <= 1 else { return nil }
        return Double(normalised)
    }
}

// MARK: - Series

struct GrowthPoint: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    /// Corrected age on the day of the measurement.
    let ageDays: Int
    /// Always metric. Converted for display at the edge.
    let value: Double

    var ageMonths: Double { Double(ageDays) / GrowthSeries.daysPerMonth }
}

enum GrowthSeries {

    /// The average Gregorian month. Used only to place a day count on a
    /// month-labelled axis, never to decide which milestone band a child is in.
    static let daysPerMonth = 30.4375

    /// Points for one metric, oldest first, skipping sessions that did not record
    /// it. A weight chart must not draw a point at zero for a day when only
    /// height was measured.
    static func points(for metric: GrowthMetric, child: Child) -> [GrowthPoint] {
        child.sortedGrowthMeasurements.compactMap { measurement in
            guard let value = measurement.value(for: metric) else { return nil }
            return GrowthPoint(
                id: measurement.id,
                date: measurement.date,
                ageDays: child.correctedAgeDays(on: measurement.date),
                value: value
            )
        }
    }

    static func latest(_ metric: GrowthMetric, child: Child) -> GrowthPoint? {
        points(for: metric, child: child).last
    }
}
