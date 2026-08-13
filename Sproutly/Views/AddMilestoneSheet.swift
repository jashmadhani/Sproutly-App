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
    @FocusState private var isTitleFocused: Bool

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
                                .font(.caption)
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
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)

                            Picker("", selection: $category) {
                                ForEach(MilestoneCategory.allCases, id: \.self) { option in
                                    Text(option.gentleLabel).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(theme.blue)

                            Text("This is just for grouping — your own moments never affect how Sproutly reads your child's development.")
                                .font(.caption2)
                                .foregroundStyle(theme.textSecondary.opacity(0.8))
                        }

                        Toggle(isOn: $alreadyHappened) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Already happened")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.text)
                                Text("Marks it complete right away")
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        .tint(theme.green)

                        if alreadyHappened {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("A note, if you'd like")
                                    .font(.caption)
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
            // Stamped with the child's age now, so it sits in the right place on
            // the timeline. It is never treated as an expectation.
            ageMonth: max(0, child.calculateCorrectedAge()),
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
