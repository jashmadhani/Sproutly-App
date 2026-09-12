//
//  AddMeasurementSheet.swift
//  Sproutly
//

import SwiftUI
import SwiftData

// Records one measuring session, or corrects one already saved. Same form
// vocabulary as AddMilestoneSheet: typed values get a rule, the date is a row.
//
// Every value is optional because real life hands a parent partial data — a
// weight from the pharmacy scale, a length from the checkup letter — and a form
// that demanded all three would simply not get used.
struct AddMeasurementSheet: View {
    let child: Child
    /// Nil when adding. When set, the sheet edits this measurement in place.
    let existing: GrowthMeasurement?

    @Environment(ChildStore.self) private var childStore
    @Environment(ThemeManager.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var weight: String
    @State private var length: String
    @State private var head: String
    @State private var note: String
    @State private var issue: GrowthEntryIssue?

    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case metric(GrowthMetric)
        case note
    }

    /// Read once. A parent does not change region halfway through typing a weight.
    private let system = GrowthUnitSystem.current()

    init(child: Child, existing: GrowthMeasurement? = nil) {
        self.child = child
        self.existing = existing

        let system = GrowthUnitSystem.current()
        func text(_ value: Double?, _ metric: GrowthMetric) -> String {
            value.map { system.number($0, metric: metric) } ?? ""
        }

        _date = State(initialValue: existing?.date ?? Date())
        _weight = State(initialValue: text(existing?.weightKg, .weight))
        _length = State(initialValue: text(existing?.lengthCm, .length))
        _head = State(initialValue: text(existing?.headCm, .head))
        _note = State(initialValue: existing?.note ?? "")
    }

    /// Corrected age on the chosen date, so the length field says "Height" for a
    /// measurement taken after two even if it is being entered years later.
    private var ageMonths: Int {
        Child.correctedAgeMonths(
            birthDate: child.birthDate,
            isPremature: child.isPremature,
            gestationalWeeks: child.gestationalWeeks,
            now: date
        )
    }

    private var hasAnyValue: Bool {
        [weight, length, head].contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Nothing before birth and nothing in the future. Guarded, because a birth
    /// date corrected to a later day would otherwise build an inverted range.
    private var dateRange: ClosedRange<Date> {
        let now = Date()
        return min(child.birthDate, now)...now
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground(nightMode: theme.isNightMode)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                        FormRow(
                            label: "Measured on",
                            systemImage: "calendar",
                            nightMode: theme.isNightMode
                        ) {
                            DatePicker("", selection: $date, in: dateRange, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(theme.blueText)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Measured on")
                        .warmCard(nightMode: theme.isNightMode)

                        VStack(alignment: .leading, spacing: 16) {
                            measurementField(.weight, text: $weight)
                            measurementField(.length, text: $length)
                            measurementField(.head, text: $head)

                            if let issue {
                                Label {
                                    Text(issue.message(system: system, ageMonths: ageMonths))
                                        .fixedSize(horizontal: false, vertical: true)
                                } icon: {
                                    Image(systemName: "exclamationmark.circle")
                                        .foregroundStyle(theme.blueText)
                                }
                                .font(Theme.sproutlyMeta)
                                .foregroundStyle(theme.text)
                                .accessibilityElement(children: .combine)
                            } else {
                                Text("Fill in whichever you have. A weight on its own is fine.")
                                    .font(Theme.sproutlyMeta)
                                    .foregroundStyle(theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .warmCard(nightMode: theme.isNightMode)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add a note, if you want to remember more")
                                .font(Theme.sproutlyFieldLabel)
                                .foregroundStyle(theme.textSecondary)

                            TextField(
                                "",
                                text: $note,
                                prompt: Text("At the 6-month checkup")
                                    .foregroundColor(Theme.fieldPlaceholder(for: theme.isNightMode)),
                                axis: .vertical
                            )
                                .lineLimit(1...4)
                                .textFieldStyle(.plain)
                                .font(Theme.sproutlyFieldValue)
                                .foregroundStyle(theme.text)
                                .focused($focused, equals: .note)
                                .underlineField(
                                    nightMode: theme.isNightMode,
                                    isFocused: focused == .note
                                )
                                .accessibilityLabel("Add a note")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .warmCard(nightMode: theme.isNightMode)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(existing == nil ? "Add Measurement" : "Edit Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!hasAnyValue)
                }
                // The decimal pad has no return key, so without this there is no
                // way to put the keyboard away except scrolling.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = nil }
                }
            }
            .onAppear {
                if existing == nil { focused = .metric(.weight) }
            }
            // A message about a value the parent has since changed is stale.
            .onChange(of: [weight, length, head]) { issue = nil }
        }
    }

    // MARK: - Field

    private func measurementField(_ metric: GrowthMetric, text: Binding<String>) -> some View {
        let title = metric.title(ageMonths: ageMonths)
        let unit = system.unitSymbol(for: metric)
        let isFlagged = issue?.metric == metric

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.sproutlyFieldLabel)
                .foregroundStyle(theme.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField(
                    "",
                    text: text,
                    prompt: Text("Optional")
                        .foregroundColor(Theme.fieldPlaceholder(for: theme.isNightMode))
                )
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .font(Theme.sproutlyFieldValue)
                    .foregroundStyle(theme.text)
                    .focused($focused, equals: .metric(metric))

                Text(unit)
                    .font(Theme.sproutlyFieldValue)
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityHidden(true)
            }
            // The rule runs under the unit too, so "kg" reads as part of the field
            // rather than a label floating beside it. A flagged field shows the
            // focused rule weight, which is how the parent finds it.
            .underlineField(
                nightMode: theme.isNightMode,
                isFocused: focused == .metric(metric) || isFlagged
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), in \(unit)")
        }
    }

    // MARK: - Save

    private func save() {
        let result = GrowthEntryValidator.validate(
            weight: weight, length: length, head: head, system: system
        )

        switch result {
        case .failure(let found):
            issue = found
            if let metric = found.metric { focused = .metric(metric) }

        case .success(let values):
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

            if let existing {
                existing.date = date
                existing.weightKg = values.weightKg
                existing.lengthCm = values.lengthCm
                existing.headCm = values.headCm
                existing.note = trimmedNote
            } else {
                modelContext.insert(GrowthMeasurement(
                    date: date,
                    weightKg: values.weightKg,
                    lengthCm: values.lengthCm,
                    headCm: values.headCm,
                    note: trimmedNote,
                    child: child
                ))
            }

            childStore.save()
            dismiss()
        }
    }
}

#if DEBUG
#Preview {
    AddMeasurementSheet(child: Child(name: "Aanya", birthDate: .now.addingTimeInterval(-86_400 * 200)))
        .environment(previewChildStore)
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
#endif
