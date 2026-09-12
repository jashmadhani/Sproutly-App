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

    /// Grows with Dynamic Type, because the axis labels do. A fixed height left
    /// the plot area squeezed to a sliver at accessibility sizes.
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 220

    var body: some View {
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
        // Not from zero. A weight line drawn from 0 kg flattens six months of real
        // change into a nearly level line, which reads as "not growing".
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(theme.divider)
                AxisValueLabel {
                    if let months = value.as(Double.self) {
                        Text(months.formatted(.number.precision(.fractionLength(0))))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(theme.divider)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number.formatted(.number.precision(.fractionLength(0...1))))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .chartXAxisLabel(position: .bottom, alignment: .center) {
            Text(isCorrectedAge ? "Age in months, adjusted for arriving early" : "Age in months")
                .font(Theme.sproutlyMeta)
                .foregroundStyle(theme.textSecondary)
        }
        .chartYAxisLabel(position: .leading) {
            Text(system.unitSymbol(for: metric))
                .font(Theme.sproutlyMeta)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(height: height)
        .accessibilityLabel("\(metric.title(ageMonths: Int(points.last?.ageMonths ?? 0))) over time")
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
