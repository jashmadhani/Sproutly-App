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

    @State private var title: String = ""
    @State private var category: MilestoneCategory = .socialEmotional
    @State private var alreadyHappened: Bool = true
    @State private var note: String = ""
    @State private var ageMonth: Int
    @FocusState private var isTitleFocused: Bool

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
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("What happened?")
                                .font(Theme.sproutlyMeta)
                                .foregroundStyle(theme.textSecondary)

                            TextField("First swim, said dada…", text: $title)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(theme.text.opacity(0.04))
                                )
                                .foregroundStyle(theme.text)
                                .focused($isTitleFocused)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Which area does it belong to?")
                                .font(Theme.sproutlyMeta)
                                .foregroundStyle(theme.textSecondary)

                            Picker("", selection: $category) {
                                ForEach(MilestoneCategory.allCases, id: \.self) { option in
                                    Text(option.gentleLabel).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(theme.blue)

                            Text("This is just for grouping — your own moments never affect how Sproutly reads your child's development.")
                                .font(Theme.sproutlyMeta)
                                .foregroundStyle(theme.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("How old were they?")
                                .font(Theme.sproutlyMeta)
                                .foregroundStyle(theme.textSecondary)

                            Stepper(value: $ageMonth, in: 0...72) {
                                Text(ageMonthText)
                                    .font(Theme.sproutlyCardTitle)
                                    .foregroundStyle(theme.text)
                            }
                            .tint(theme.green)
                        }

                        Toggle(isOn: $alreadyHappened) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Already happened")
                                    .font(Theme.sproutlyCardTitle)
                                    .foregroundStyle(theme.text)
                                Text("Marks it complete right away")
                                    .font(Theme.sproutlyMeta)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        .tint(theme.green)

                        if alreadyHappened {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("A note, if you'd like")
                                    .font(Theme.sproutlyMeta)
                                    .foregroundStyle(theme.textSecondary)

                                TextField("Optional", text: $note, axis: .vertical)
                                    .lineLimit(1...4)
                                    .textFieldStyle(.plain)
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(theme.text.opacity(0.04))
                                    )
                                    .foregroundStyle(theme.text)
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(20)
                    .animation(.spring(response: 0.4), value: alreadyHappened)
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

#Preview {
    AddMilestoneSheet(child: Child(name: "Aanya", birthDate: .now))
        .environment(previewChildStore)
        .environment(PurchaseManager())
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
