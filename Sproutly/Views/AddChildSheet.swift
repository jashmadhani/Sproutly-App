//
//  AddChildSheet.swift
//  Sproutly
//

import SwiftUI

// Deliberately the shortest possible form: name and birth date, with prematurity
// tucked behind a toggle. Everything else can be edited later in Settings.
struct AddChildSheet: View {
    @Environment(ChildStore.self) private var childStore
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var birthDate: Date = Date()
    @State private var isPremature: Bool = false
    @State private var gestationalWeeks: Int = 40

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground(nightMode: theme.isNightMode)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)

                            TextField("Child's name", text: $name)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(theme.text.opacity(0.04))
                                )
                                .foregroundStyle(theme.text)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Birth Date")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)

                            DatePicker(
                                "",
                                selection: $birthDate,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(theme.blue)
                        }

                        Toggle(isOn: $isPremature) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Born Before 37 Weeks")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.text)
                                Text("Milestones will be gently adjusted")
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        .tint(theme.green)

                        if isPremature {
                            HStack {
                                Text("Gestational age:")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.textSecondary)

                                Picker("", selection: $gestationalWeeks) {
                                    ForEach(24...36, id: \.self) { week in
                                        Text("\(week) weeks").tag(week)
                                    }
                                }
                                .tint(theme.blue)
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(20)
                    .animation(.spring(response: 0.4), value: isPremature)
                }
            }
            .navigationTitle("Add a Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        childStore.addChild(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            birthDate: birthDate,
                            isPremature: isPremature,
                            gestationalWeeks: isPremature ? gestationalWeeks : 40
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    AddChildSheet()
        .environment(previewChildStore)
        .environment(PurchaseManager())
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
