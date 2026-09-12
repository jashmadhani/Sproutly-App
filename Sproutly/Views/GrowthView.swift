//
//  GrowthView.swift
//  Sproutly
//

import SwiftUI
import SwiftData

// A child's measurements over time: a chart per metric and the sessions behind it.
//
// Logging and the chart are free. The only Pro part of Growth is the section it
// adds to the PDF visit report, which is already behind the existing report gate,
// so nothing on this screen needs a lock.
struct GrowthView: View {
    let child: Child

    @Environment(ChildStore.self) private var childStore
    @Environment(ThemeManager.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // One sheet binding for this screen, like every other view that owns modals.
    private enum GrowthSheet: Identifiable {
        case add
        case edit(GrowthMeasurement)

        var id: String {
            switch self {
            case .add:                  return "add"
            case .edit(let measurement): return "edit-\(measurement.id)"
            }
        }
    }

    @State private var activeSheet: GrowthSheet?
    @State private var selectedMetric: GrowthMetric
    @State private var pendingDelete: GrowthMeasurement?

    /// Read once per appearance. A region change mid-session is not worth a
    /// chart that silently rescales under the parent's finger.
    private let system = GrowthUnitSystem.current()

    init(child: Child) {
        self.child = child
        // Open on a metric that has something to draw, so a parent who has only
        // ever logged length is not greeted by an empty weight chart.
        let first = GrowthMetric.allCases.first { metric in
            (child.growthMeasurements ?? []).contains { $0.value(for: metric) != nil }
        }
        _selectedMetric = State(initialValue: first ?? .weight)
    }

    private var measurements: [GrowthMeasurement] { child.sortedGrowthMeasurements }
    private var ageMonths: Int { max(0, child.calculateCorrectedAge()) }
    private var points: [GrowthPoint] { GrowthSeries.points(for: selectedMetric, child: child) }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground(nightMode: theme.isNightMode)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                        if measurements.isEmpty {
                            emptyCard
                        } else {
                            SproutlySegmentedControl(
                                options: GrowthMetric.allCases,
                                selection: $selectedMetric,
                                accessibilityLabel: "Measurement"
                            ) { $0.title(ageMonths: ageMonths) }
                            .padding(.horizontal, 4)

                            chartCard
                            historySection
                            aboutThisChart
                        }
                    }
                    .padding(20)
                }
                .scrollEdgeFade()
            }
            .navigationTitle("Growth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activeSheet = .add
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Measurement")
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add:
                    AddMeasurementSheet(child: child)
                case .edit(let measurement):
                    AddMeasurementSheet(child: child, existing: measurement)
                }
            }
            .alert(
                "Delete this measurement?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) { pendingDelete = nil }
                Button("Delete", role: .destructive) { deletePending() }
            } message: {
                if let pendingDelete {
                    Text("This removes what you saved on \(pendingDelete.date.formatted(date: .long, time: .omitted)).")
                }
            }
        }
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureCardHeader(
                title: "Keep track of growth",
                subtitle: "Add weight, length or head size from a checkup or from home, and see how \(child.displayName) changes over time.",
                systemImage: "ruler",
                nightMode: theme.isNightMode,
                diameter: 44,
                glyphSize: 19
            )

            Button {
                activeSheet = .add
            } label: {
                Label("Add a Measurement", systemImage: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.text)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftCapsuleStyle(baseColor: theme.blue, nightMode: theme.isNightMode))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmCard(nightMode: theme.isNightMode)
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let latest = points.last {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latest \(selectedMetric.phrase(ageMonths: ageMonths))")
                        .font(Theme.sproutlyFieldLabel)
                        .foregroundStyle(theme.textSecondary)

                    Text(system.formatted(latest.value, metric: selectedMetric))
                        .sproutlyScaledFont(30, relativeTo: .title, weight: .bold, design: .rounded)
                        .foregroundStyle(theme.text)

                    Text("Measured \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(Theme.sproutlyMeta)
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityElement(children: .combine)

                GrowthChartView(
                    points: points,
                    metric: selectedMetric,
                    system: system,
                    isCorrectedAge: child.isCorrectedAge
                )
            } else {
                // Other metrics have data, this one does not. Say so plainly rather
                // than drawing an empty plot area with axes and nothing on them.
                Label {
                    Text("No \(selectedMetric.phrase(ageMonths: ageMonths)) saved yet. Add one next time it's measured.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: selectedMetric.systemImage)
                        .foregroundStyle(theme.blueText)
                }
                .font(Theme.sproutlyBody)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmCard(nightMode: theme.isNightMode)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Measurements")
                .font(Theme.sproutlySectionHeader)
                .foregroundStyle(theme.text)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Newest first here, oldest first on the chart: a list is read for
                // "what did I last save", a chart for "how has it changed".
                let newestFirst = Array(measurements.reversed())
                ForEach(Array(newestFirst.enumerated()), id: \.element.id) { index, measurement in
                    if index > 0 {
                        Theme.divider(nightMode: theme.isNightMode)
                            .padding(.leading, Theme.cardPadding)
                    }
                    row(measurement)
                }
            }
            .groupedCard(nightMode: theme.isNightMode)
        }
    }

    private func row(_ measurement: GrowthMeasurement) -> some View {
        let age = Child.correctedAgeMonths(
            birthDate: child.birthDate,
            isPremature: child.isPremature,
            gestationalWeeks: child.gestationalWeeks,
            now: measurement.date
        )

        return HStack(spacing: 8) {
            Button {
                activeSheet = .edit(measurement)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(measurement.date.formatted(date: .abbreviated, time: .omitted))
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(theme.text)

                    Text(summary(of: measurement, ageMonths: age))
                        .font(Theme.sproutlyBody)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !measurement.note.isEmpty {
                        Text(measurement.note)
                            .font(Theme.sproutlyMeta)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens it to edit")

            Menu {
                Button {
                    activeSheet = .edit(measurement)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    pendingDelete = measurement
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .sproutlyRowIcon()
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More for \(measurement.date.formatted(date: .abbreviated, time: .omitted))")
        }
        .padding(.leading, Theme.cardPadding)
        .padding(.trailing, 6)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
    }

    /// "Weight 7.2 kg, length 66 cm, head 42 cm". A sentence rather than three
    /// columns, so it wraps instead of truncating at large text sizes and reads
    /// naturally to VoiceOver.
    private func summary(of measurement: GrowthMeasurement, ageMonths: Int) -> String {
        GrowthMetric.allCases.compactMap { metric in
            measurement.value(for: metric).map {
                "\(metric.phrase(ageMonths: ageMonths)) \(system.formatted($0, metric: metric))"
            }
        }
        .joined(separator: ", ")
        .capitalizingFirstLetter()
    }

    // MARK: - About

    // What this chart is, and what it is not. There are no comparison curves yet,
    // so there is nothing here that could tell a parent their child is behind, and
    // the copy says so rather than leaving a parent to wonder what they're missing.
    private var aboutThisChart: some View {
        Text("This shows how \(child.displayName)'s measurements change over time. It doesn't compare them with other children or say what they mean. Your pediatrician can help with that.")
            .font(Theme.sproutlyMeta)
            .foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    // MARK: - Actions

    private func deletePending() {
        guard let pendingDelete else { return }
        modelContext.delete(pendingDelete)
        childStore.save()
        self.pendingDelete = nil
    }
}

private extension String {
    func capitalizingFirstLetter() -> String {
        prefix(1).uppercased() + dropFirst()
    }
}

#if DEBUG
#Preview {
    GrowthView(child: Child(name: "Aanya", birthDate: .now.addingTimeInterval(-86_400 * 200)))
        .environment(previewChildStore)
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
#endif
