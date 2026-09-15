//
//  GrowthChartView.swift
//  Sproutly
//

import SwiftUI
import Charts

/// One child's own measurements over time, and nothing else.
///
/// There are deliberately no percentile curves and no reference lines yet. A line
/// with nothing to compare it against cannot tell a parent their child is behind,
/// which is the right starting point for an app that never diagnoses. The WHO
/// curves arrive later as a separate layer under this line, which is why the
/// x-axis is corrected age rather than calendar date — those curves are
/// tabulated by age, and switching axes then would move every point a parent has
/// already seen.
struct GrowthChartView: View {
    let points: [GrowthPoint]
    let metric: GrowthMetric
    let system: GrowthUnitSystem
    let isCorrectedAge: Bool

    @Environment(ThemeManager.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Grows with Dynamic Type, because the axis labels do. A fixed height left
    /// the plot area squeezed to a sliver at accessibility sizes. Capped, or at
    /// the largest size the plot outgrew the screen and the header scrolled away
    /// from the line it describes.
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 220

    /// Fewer ticks at accessibility sizes, where five month labels at that size
    /// run into each other across a phone's width.
    private var tickCount: Int { dynamicTypeSize.isAccessibilitySize ? 3 : 5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            chart

            // What the axes are, as ordinary text. It used to be the chart's own
            // axis titles, and those do not wrap: at the largest text size "Age in
            // months" was cut off at the card edge, and for a premature child the
            // longer "adjusted for arriving early" version would not fit at all.
            Text(caption)
                .font(Theme.sproutlyMeta)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var caption: String {
        let what = "\(metric.title(ageMonths: Int(points.last?.ageMonths ?? 0))) in \(system.unitSymbol(for: metric))"
        return isCorrectedAge
            ? "\(what), by age in months adjusted for arriving early."
            : "\(what), by age in months."
    }

    private var chart: some View {
        Chart(points) { point in
            let shown = system.fromMetric(point.value, metric: metric)

            LineMark(
                x: .value("Age", point.ageMonths),
                y: .value(metric.title(ageMonths: Int(point.ageMonths)), shown)
            )
            .foregroundStyle(theme.blueText)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Age", point.ageMonths),
                y: .value(metric.title(ageMonths: Int(point.ageMonths)), shown)
            )
            .foregroundStyle(theme.blueText)
            .symbolSize(48)
            .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .omitted))
            .accessibilityValue(system.formatted(point.value, metric: metric))
        }
        // Not from zero, and not shrunk to fit either. From zero, a weight line
        // flattens six months of change into a level line that reads as "not
        // growing". Fitted tightly to the data, a 250 g rise over three weeks filled
        // the whole chart top to bottom on a render, so ordinary day-to-day wobble
        // would look like a spike or a plunge. `yDomain` keeps a minimum span.
        .chartYScale(domain: yDomain)
        .chartXScale(domain: xDomain)
        .chartXAxis {
            // `.aligned` pulls the first and last labels inside the plot. Centred
            // labels on the edge ticks overflowed the chart's frame and were cut,
            // so a render showed "1" where the axis meant 10 months.
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: tickCount)) { value in
                AxisGridLine().foregroundStyle(theme.divider)
                AxisValueLabel {
                    // Whole months only. The two-month minimum window gets half-month
                    // ticks, and rounding those printed "29, 30, 30, 30, 31".
                    if let months = value.as(Double.self), months.rounded() == months {
                        Text(months.formatted(.number.precision(.fractionLength(0))))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading, values: .automatic(desiredCount: min(4, tickCount))) { value in
                AxisGridLine().foregroundStyle(theme.divider)
                AxisValueLabel {
                    // Two decimals, matching what the app shows elsewhere. Two
                    // weigh-ins close together get ticks a hundredth apart, which
                    // one decimal would print as the same number repeated.
                    if let number = value.as(Double.self) {
                        Text(number.formatted(.number.precision(.fractionLength(0...2))))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .frame(height: min(height, 380))
        .accessibilityLabel("\(metric.title(ageMonths: Int(points.last?.ageMonths ?? 0))) over time")
    }

    /// The value axis, in the units shown, never narrower than a span where normal
    /// variation stays visually small: about a kilogram (two pounds) of weight,
    /// four centimetres (an inch and a half) of length, two centimetres (an inch)
    /// of head size. Wider data gets a tenth of its span as margin either side.
    private var yDomain: ClosedRange<Double> {
        GrowthChartView.valueDomain(
            shown: points.map { system.fromMetric($0.value, metric: metric) },
            metric: metric,
            system: system
        )
    }

    static func valueDomain(shown: [Double], metric: GrowthMetric, system: GrowthUnitSystem) -> ClosedRange<Double> {
        guard let low = shown.min(), let high = shown.max() else { return 0...1 }

        let minimumSpan = GrowthChartView.minimumSpan(metric: metric, system: system)
        let span = high - low
        guard span < minimumSpan else {
            return max(0, low - span * 0.1)...(high + span * 0.1)
        }
        let centre = (low + high) / 2
        let lower = max(0, centre - minimumSpan / 2)
        return lower...(lower + minimumSpan)
    }

    static func minimumSpan(metric: GrowthMetric, system: GrowthUnitSystem) -> Double {
        switch (metric, system) {
        case (.weight, .metric):   return 1
        case (.weight, .imperial): return 2
        case (.length, .metric):   return 4
        case (.length, .imperial): return 1.5
        case (.head, .metric):     return 2
        case (.head, .imperial):   return 1
        }
    }

    /// A single measurement still needs a readable axis, and two taken a week
    /// apart should not stretch edge to edge as if months had passed. At least a
    /// two-month window, centred on what is there.
    private var xDomain: ClosedRange<Double> {
        let ages = points.map(\.ageMonths)
        guard let first = ages.min(), let last = ages.max() else { return 0...2 }
        let span = last - first
        // A little room either side, or the first and last points sit half off
        // the plot area.
        guard span < 2 else { return max(0, first - span * 0.05)...(last + span * 0.05) }
        let padding = (2 - span) / 2
        let lower = max(0, first - padding)
        return lower...(lower + max(2, span + padding * 2))
    }
}
