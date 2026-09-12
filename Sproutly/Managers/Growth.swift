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

    /// Only the US measures babies in pounds and inches. The UK's red book uses
    /// kilograms and centimetres, so this keys off the measurement system rather
    /// than language or region families.
    static func current(locale: Locale = .current) -> GrowthUnitSystem {
        locale.measurementSystem == .us ? .imperial : .metric
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

    /// A stored metric value, shown in this system: "7.25 kg", "26 in".
    ///
    /// Up to two decimals and never padded, so a clinic's 7.25 keeps its precision
    /// and a home scale's 7 does not grow a meaningless ".00".
    func formatted(_ metricValue: Double, metric: GrowthMetric, locale: Locale = .current) -> String {
        "\(number(metricValue, metric: metric, locale: locale)) \(unitSymbol(for: metric))"
    }

    /// The number alone, for a field being edited or a chart axis.
    func number(_ metricValue: Double, metric: GrowthMetric, locale: Locale = .current) -> String {
        fromMetric(metricValue, metric: metric)
            .formatted(.number.precision(.fractionLength(0...2)).locale(locale))
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
        }
    }

    var metric: GrowthMetric? {
        switch self {
        case .nothingEntered:            return nil
        case .unreadable(let metric),
             .outOfRange(let metric):    return metric
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
        length: String,
        head: String,
        system: GrowthUnitSystem,
        locale: Locale = .current
    ) -> Result<GrowthValues, GrowthEntryIssue> {
        let fields: [(GrowthMetric, String)] = [(.weight, weight), (.length, length), (.head, head)]
        var values = GrowthValues()
        var anyEntered = false

        for (metric, raw) in fields {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            anyEntered = true

            guard let typed = parse(text, locale: locale) else {
                return .failure(.unreadable(metric))
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
