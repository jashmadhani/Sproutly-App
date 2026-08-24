//
//  AddMilestoneSheet.swift
//  Sproutly
//

import SwiftUI
import SwiftData

// Lets a parent record their own moment — "said dada", "first swim" — alongside
// the standard set. Deliberately tiny: a title, a domain, and an optional note.
struct AddMilestoneSheet: View {
    let child: Child

    @Environment(ChildStore.self) private var childStore
    @Environment(ThemeManager.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var title: String = ""
    @State private var category: MilestoneCategory = .socialEmotional
    @State private var alreadyHappened: Bool = true
    @State private var note: String = ""
    @State private var ageMonth: Int
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNoteFocused: Bool

    init(child: Child) {
        self.child = child
        _ageMonth = State(initialValue: max(0, child.calculateCorrectedAge()))
    }

    private var ageMonthText: String {
        if ageMonth < 24 {
            return "\(ageMonth) month\(ageMonth == 1 ? "" : "s")"
        }
        let years = ageMonth / 12
        let remainder = ageMonth % 12
        return remainder == 0
            ? "\(years) year\(years == 1 ? "" : "s")"
            : "\(years)y \(remainder)m"
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground(nightMode: theme.isNightMode)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                        // What + where: one card, because choosing the area is
                        // part of describing the moment, not a separate step.
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("What happened?")
                                    .font(Theme.sproutlyFieldLabel)
                                    .foregroundStyle(theme.textSecondary)

                                TextField(
                                    "",
                                    text: $title,
                                    prompt: Text("First swim, said dada…")
                                        .foregroundColor(Theme.fieldPlaceholder(for: theme.isNightMode))
                                )
                                    .textFieldStyle(.plain)
                                    .font(Theme.sproutlyFieldValue)
                                    .foregroundStyle(theme.text)
                                    .submitLabel(.done)
                                    .focused($isTitleFocused)
                                    .underlineField(
                                        nightMode: theme.isNightMode,
                                        isFocused: isTitleFocused
                                    )
                                    // The visible label is the question; without
                                    // this VoiceOver would read the example
                                    // placeholder instead.
                                    .accessibilityLabel("What happened?")
                            }

                            VStack(alignment: .leading, spacing: 8) {

                                // A Menu with an explicit label rather than a bare
                                // .menu Picker: the plain picker rendered as a
                                // small tinted string with nothing around it, so
                                // the selected domain read as a stray link rather
                                // than as the value of a field. This matches the
                                // text field above it.
                                FormRow(
                                    label: "Area",
                                    systemImage: category.icon,
                                    nightMode: theme.isNightMode
                                ) {
                                    Menu {
                                        Picker("", selection: $category) {
                                            ForEach(MilestoneCategory.allCases, id: \.self) { option in
                                                Label(option.gentleLabel, systemImage: option.icon)
                                                    .tag(option)
                                            }
                                        }
                                    } label: {
                                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                                            Text(category.gentleLabel)
                                                .font(Theme.sproutlyFieldValue)
                                                .foregroundStyle(theme.blueText)
                                                .multilineTextAlignment(.trailing)
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.footnote.weight(.semibold))
                                                .foregroundStyle(theme.blueText.opacity(0.7))
                                        }
                                        .frame(minHeight: 44)
                                        .contentShape(Rectangle())
                                    }
                                }
                                .accessibilityLabel("Area")
                                .accessibilityValue(category.gentleLabel)

                                // Footnote, not body: this is a section footer,
                                // one step below the label above it. Three tiers
                                // — 15 semibold label, 17 value, 13 footer — is
                                // what gives the card a readable order.
                                Text("This is just for grouping — your own moments never affect how Sproutly reads your child's development.")
                                    .font(Theme.sproutlyMeta)
                                    .foregroundStyle(theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .warmCard(nightMode: theme.isNightMode)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("How old were they?")
                                .font(Theme.sproutlyFieldLabel)
                                .foregroundStyle(theme.textSecondary)

                            HStack(spacing: 12) {
                                Text(ageMonthText)
                                    .font(Theme.sproutlyFieldValue)
                                    .foregroundStyle(theme.text)

                                Spacer(minLength: 8)

                                SproutlyStepper(
                                    value: $ageMonth,
                                    range: 0...72,
                                    nightMode: theme.isNightMode
                                ) { _ in ageMonthText }
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("How old were they?")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .warmCard(nightMode: theme.isNightMode)

                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(isOn: $alreadyHappened) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Already happened")
                                        .font(Theme.sproutlyCardTitle)
                                        .foregroundStyle(theme.text)
                                    Text("Saves it straight away")
                                        .font(Theme.sproutlyBody)
                                        .foregroundStyle(theme.textSecondary)
                                }
                            }
                            .toggleStyle(SproutlyToggleStyle(nightMode: theme.isNightMode))

                            if alreadyHappened {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("A note, if you'd like")
                                        .font(Theme.sproutlyFieldLabel)
                                        .foregroundStyle(theme.textSecondary)

                                    TextField(
                                        "",
                                        text: $note,
                                        prompt: Text("Optional")
                                            .foregroundColor(Theme.fieldPlaceholder(for: theme.isNightMode)),
                                        axis: .vertical
                                    )
                                        .lineLimit(1...4)
                                        .textFieldStyle(.plain)
                                        .font(Theme.sproutlyFieldValue)
                                        .foregroundStyle(theme.text)
                                        .focused($isNoteFocused)
                                        .underlineField(
                                            nightMode: theme.isNightMode,
                                            isFocused: isNoteFocused
                                        )
                                        .accessibilityLabel("A note, if you'd like")
                                }
                                .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .warmCard(nightMode: theme.isNightMode)
                    }
                    .padding(20)
                    .animation(Theme.spring(0.4, reduceMotion: reduceMotion), value: alreadyHappened)
                }
            }
            .navigationTitle("Add a Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { isTitleFocused = true }
        }
    }

    private func save() {
        let milestone = Milestone(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.rawValue,
            // Parent-chosen, defaulting to the child's current age — lets a
            // moment recorded in retrospect sit at the right point on the
            // timeline. It is never treated as an expectation (isUserCreated).
            ageMonth: ageMonth,
            isCompleted: alreadyHappened,
            dateCompleted: alreadyHappened ? Date() : nil,
            completionNote: alreadyHappened
                ? note.trimmingCharacters(in: .whitespacesAndNewlines)
                : "",
            child: child,
            isUserCreated: true
        )

        modelContext.insert(milestone)
        childStore.save()
        dismiss()
    }
}

#if DEBUG
#Preview {
    AddMilestoneSheet(child: Child(name: "Aanya", birthDate: .now))
        .environment(previewChildStore)
        .environment(PurchaseManager())
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
#endif
