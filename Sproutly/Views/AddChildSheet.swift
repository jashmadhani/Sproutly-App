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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var name: String = ""
    @State private var birthDate: Date = Date()
    @State private var isPremature: Bool = false
    @State private var gestationalWeeks: Int = 40
    @FocusState private var isNameFocused: Bool

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground(nightMode: theme.isNightMode)

                ScrollView {
                    // Grouped into cards so this reads as the same app as the
                    // Settings screen that edits the very same fields — the two
                    // used to share their field code but not their structure, so
                    // adding a child and editing one looked unrelated.
                    VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("What do you call your little one?")
                                    .font(Theme.sproutlyFieldLabel)
                                    .foregroundStyle(theme.textSecondary)

                                TextField(
                                    "",
                                    text: $name,
                                    prompt: Text("Name or nickname")
                                        .foregroundColor(Theme.fieldPlaceholder(for: theme.isNightMode))
                                )
                                    .textFieldStyle(.plain)
                                    .font(Theme.sproutlyFieldValue)
                                    .foregroundStyle(theme.text)
                                    // A name, not a sentence: capitalise it and
                                    // keep autocorrect away from proper nouns.
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .submitLabel(.done)
                                    .focused($isNameFocused)
                                    .underlineField(
                                        nightMode: theme.isNightMode,
                                        isFocused: isNameFocused
                                    )
                                    // Without this VoiceOver reads the
                                    // placeholder — "Child's name" — while the
                                    // visible label says "Name".
                                    .accessibilityLabel("Name")
                            }

                            // A labelled row rather than a label above a boxed
                            // control. The compact DatePicker draws its own pill,
                            // so wrapping it in `formField` nested one container
                            // inside another and left a wide dead gap beside it.
                            // As a row the pill becomes the value on the right,
                            // which is both the system's own pattern and the same
                            // shape as the Gestational Age row below.
                            //
                            // No divider above this row: `.underlineField` on the
                            // name already draws one, and a second rule 8pt below
                            // it read as a rendering fault rather than a
                            // separator. One line weight, one line — the row
                            // below still gets its own separator.
                            FormRow(
                                label: "Birth Date",
                                systemImage: "calendar",
                                nightMode: theme.isNightMode
                            ) {
                                DatePicker(
                                    "",
                                    selection: $birthDate,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(theme.blueText)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Birth Date")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .warmCard(nightMode: theme.isNightMode)

                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(isOn: $isPremature) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Did your baby arrive early?")
                                        .font(Theme.sproutlyCardTitle)
                                        .foregroundStyle(theme.text)
                                    Text("Before 37 weeks. We'll take that into account when showing milestones.")
                                        .font(Theme.sproutlyBody)
                                        .foregroundStyle(theme.textSecondary)
                                }
                            }
                            .toggleStyle(SproutlyToggleStyle(nightMode: theme.isNightMode))

                            if isPremature {
                                VStack(alignment: .leading, spacing: 0) {
                                    Theme.divider(nightMode: theme.isNightMode)

                                    FormRow(
                                        label: "Weeks at birth",
                                        systemImage: "calendar.badge.clock",
                                        nightMode: theme.isNightMode
                                    ) {
                                        Menu {
                                            Picker("", selection: $gestationalWeeks) {
                                                ForEach(24...40, id: \.self) { week in
                                                    Text("\(week) weeks").tag(week)
                                                }
                                            }
                                        } label: {
                                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                                Text("\(gestationalWeeks) weeks")
                                                    .font(Theme.sproutlyFieldValue)
                                                    .foregroundStyle(theme.blueText)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.footnote.weight(.semibold))
                                                    .foregroundStyle(theme.blueText.opacity(0.7))
                                            }
                                            .frame(minHeight: 44)
                                            .contentShape(Rectangle())
                                        }
                                    }
                                    .accessibilityLabel("Gestational age")
                                    .accessibilityValue("\(gestationalWeeks) weeks")
                                }
                                .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .warmCard(nightMode: theme.isNightMode)
                    }
                    .padding(20)
                    .animation(Theme.spring(0.4, reduceMotion: reduceMotion), value: isPremature)
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

#if DEBUG
#Preview {
    AddChildSheet()
        .environment(previewChildStore)
        .environment(PurchaseManager())
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
#endif
