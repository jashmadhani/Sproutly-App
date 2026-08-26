//
//  OnboardingView.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/02/26.
//

import SwiftUI
import SwiftData

/// Onboarding flow: Welcome → How It Works → Reassurance → Disclaimer → Profile
/// → What they already do.
///
/// The last step only exists when there is something to offer. The seed catalog
/// starts at six months, so a child younger than that corrected has an empty
/// list and the flow is five steps — see `hasBackfillStep`.
struct OnboardingView: View {
    @Environment(ChildStore.self) private var childStore
    @Environment(ThemeManager.self) private var theme

    @State private var step = 0
    @State private var isProcessing = false

    // profile fields
    @State private var childName = ""
    @State private var birthDate = Calendar.current.date(byAdding: .month, value: -4, to: Date()) ?? Date()
    @State private var isPremature = false
    @State private var gestationalWeeks = 40

    // Titles of the milestones the parent says their child already does. Held
    // here rather than written as they tap, because the child — and therefore
    // the milestone rows — does not exist until the flow ends.
    @State private var backfillSelection: Set<String> = []

    @FocusState private var isNameFieldFocused: Bool

    private static let profileStepIndex = 4

    // Corrected age, computed from the profile fields alone. `Child` owns the
    // one implementation of the correction; this must never grow its own.
    private var correctedAge: Int {
        Child.correctedAgeMonths(
            birthDate: birthDate,
            isPremature: isPremature,
            gestationalWeeks: isPremature ? gestationalWeeks : 40
        )
    }

    private var backfillCandidates: [BackfillCandidate] {
        BackfillCatalog.candidates(correctedAge: correctedAge)
    }

    // Offering an empty list would be a step that asks a question with no
    // answers. This is a list check rather than an age check on purpose: the
    // catalog starts at six months today, and an age threshold would silently
    // become wrong the moment that changes.
    private var hasBackfillStep: Bool { !backfillCandidates.isEmpty }

    private var totalSteps: Int { hasBackfillStep ? 6 : 5 }

    private var isBackfillStep: Bool { step == Self.profileStepIndex + 1 }

    private var trimmedName: String {
        childName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // The name is required to *leave the profile step*, not merely to finish the
    // flow. Gating on "is this the last step" was wrong the moment a sixth step
    // existed: the profile step stopped being last, the check stopped firing,
    // and a parent could continue with an empty field — landing on a backfill
    // screen addressed to "your little one" with no way back.
    //
    // Trimmed, so a field holding only spaces doesn't pass.
    private var isNameMissing: Bool {
        step >= Self.profileStepIndex && trimmedName.isEmpty
    }

    var body: some View {
        ZStack {
            // Warm background — lightweight, no blur
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progressDots


                Group {
                    if step == 0 {
                        welcomeStep
                    } else if step == 1 {
                        howItWorksStep
                    } else if step == 2 {
                        reassuranceStep
                    } else if step == 3 {
                        disclaimerStep
                    } else if step == Self.profileStepIndex {
                        profileStep
                    } else {
                        backfillStep
                    }
                }
                .transition(.identity)

                navigationButtons
            }
        }
        // Without this, the keyboard's safe-area inset pushes the ENTIRE
        // VStack up — Back/Get Started included — while the profile step's
        // ScrollView separately auto-scrolls to keep the focused field
        // visible. Two independent adjustments fighting each other is what
        // produced the hard seam right above the buttons: the ScrollView's
        // rounded card got clipped flat at its shrunk bottom edge. Freezing
        // the outer layout in place means only the ScrollView reflows for
        // the keyboard, and Back/Get Started stay exactly where they always
        // are — same fix you proposed, the keyboard simply overlays instead
        // of shoving the chrome around.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onTapGesture { isNameFieldFocused = false }
    }
}

// MARK: - Progress Dots

private extension OnboardingView {
    var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(
                        i <= step
                            ? theme.blue
                            : theme.blue.opacity(0.25)
                    )
                    .frame(width: i == step ? 24 : 8, height: 8)
            }
        }
        .padding(.top, 60)
        .padding(.bottom, 20)
        .animation(.easeInOut(duration: 0.2), value: step)
    }
}

// MARK: - Steps

private extension OnboardingView {

    // Vertically centers short intro content, but — unlike a bare Spacer()
    // pair inside a ScrollView, which has nothing to expand into and just
    // left content pinned near the top — still scrolls normally if the
    // content or a larger Dynamic Type size ever exceeds the screen height.
    func centeredIntroStep<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 0)
                    content()
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // Step 1: Welcome — "Every small moment matters"
    var welcomeStep: some View {
        centeredIntroStep {
            Group {
                // The real app mark, not a stand-in glyph: this is the first
                // screen after install, and the parent tapped this exact icon a
                // few seconds ago — showing it back is what makes the screen
                // read as "you're in the right place". Squircle rather than a
                // circle so the silhouette matches the home screen; a circle
                // re-crops it and clips the leaves, which reach for the corners.
                //
                // AppIconClassicPreview, not AppIcon: .appiconset entries can't
                // be resolved through Image(_:) at all — the parallel *Preview
                // imagesets exist for exactly this. Onboarding runs before the
                // icon picker is reachable, so the default mark is correct here.
                //
                // The stroke is load-bearing. The icon's own field is #E9F0E4,
                // the same value as Theme.dayBg, so with no edge it dissolves
                // into the page in day mode and reads as loose floating leaves.
                Image("AppIconClassicPreview")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(theme.text.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: theme.text.opacity(0.10), radius: 12, y: 5)
                    .accessibilityHidden(true)

                Text("Sproutly")
                    .font(.sproutlyDisplay(40))
                    .foregroundStyle(theme.text)

                VStack(spacing: 8) {
                    Text("Every small moment matters")
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(theme.text)

                    Text("Keep track of the small things your child does,\nso you can look back on them later.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.textSecondary)
                        .lineSpacing(4)
                }
            }
        }
    }

    // Step 2: How It Works — Notice → Save → Look back
    var howItWorksStep: some View {
        // Deliberately NOT centred like the other intro steps. Three cards plus a
        // caption is no longer "short content" — centring it left roughly 180pt
        // of void above the title and 135pt below the caption, which is what
        // made this step read as empty rather than calm. Top-aligned with a
        // fixed lead-in, so the whitespace sits in one place instead of two.
        VStack(spacing: 20) {
            Spacer(minLength: 0)
                .frame(height: 24)

            Text("How Sproutly Works")
                .font(.sproutlyDisplay(28))
                .foregroundStyle(theme.text)

            VStack(spacing: 12) {
                howItWorksRow(
                    icon: "eye",
                    title: "Notice",
                    subtitle: "The small things your child does each day"
                )

                howItWorksRow(
                    icon: "square.and.pencil",
                    title: "Save",
                    subtitle: "One tap saves it. That's the whole thing."
                )

                howItWorksRow(
                    icon: "heart.text.square",
                    title: "Look back",
                    subtitle: "See how much has changed since last month."
                )
            }
            .padding(.horizontal, 24)

            Text("Notice it. Save it. Come back to it.")
                .font(Theme.sproutlyBody)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer(minLength: 24)
        }
        .padding()
    }

    // Step 3: Reassurance — "There is no perfect timeline"
    var reassuranceStep: some View {
        centeredIntroStep {
            Group {
                ZStack {
                    Circle()
                        .fill(theme.green.opacity(0.12))
                        .frame(width: 120, height: 120)

                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 55))
                        .foregroundStyle(theme.green)
                }

                Text("There is no\nperfect timeline")
                    .font(.sproutlyDisplay(30))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.text)

                Text("Every child gets there in their own time.\nSproutly is here to help you keep track,\nnot to score or compare.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(4)
            }
        }
    }

    // Step 4: Medical Disclaimer
    var disclaimerStep: some View {
        centeredIntroStep {
            Group {
                ZStack {
                    Circle()
                        .fill(theme.blue.opacity(0.12))
                        .frame(width: 120, height: 120)

                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 55))
                        .foregroundStyle(theme.blue)
                }

                Text("Important Notice")
                    .font(.sproutlyDisplay(30))
                    .foregroundStyle(theme.text)

                // Kept to two sentences deliberately — both required disclaimers
                // (educational-only, not a substitute for professional care)
                // survive, just tightened. Never drop either claim.
                VStack(spacing: 16) {
                    Text("Sproutly is an educational tool — not a substitute for professional medical advice, diagnosis, or treatment.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.text)
                        .lineSpacing(4)

                    Text("Always seek your pediatrician's advice for questions about your child's development.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.textSecondary)
                        .lineSpacing(4)

                    // The real range, stated before the parent invests any time
                    // — along with where to look instead if their baby is
                    // younger than the app covers.
                    Text("Sproutly covers 2 months to 5 years. For a younger baby, your pediatrician and the newborn well-visits are the right place to look.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.textSecondary)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // Step 5: Quick Profile Setup
    var profileStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 16)

                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(theme.blue.opacity(0.12))
                            .frame(width: 60, height: 60)

                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(theme.blue)
                    }

                    Text("About Your Little One")
                        .font(.sproutlyDisplay(26))
                        .foregroundStyle(theme.text)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Typed text gets a rule; the date, the toggle and the weeks
                    // picker are rows. Each of those three already draws its own
                    // control, so a container of ours around them only ever
                    // produced a box inside a box.
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What do you call your little one?")
                            .font(Theme.sproutlyFieldLabel)
                            .foregroundStyle(theme.textSecondary)

                        TextField(
                            "",
                            text: $childName,
                            prompt: Text("Name or nickname")
                                .foregroundColor(Theme.fieldPlaceholder(for: theme.isNightMode))
                        )
                        .focused($isNameFieldFocused)
                        .textFieldStyle(.plain)
                        .font(Theme.sproutlyFieldValue)
                        .foregroundStyle(theme.text)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .underlineField(
                            nightMode: theme.isNightMode,
                            isFocused: isNameFieldFocused
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { isNameFieldFocused = true }
                    }
                    .padding(.bottom, 8)

                    FormRow(label: "Birth Date", systemImage: "calendar", nightMode: theme.isNightMode) {
                        DatePicker("", selection: $birthDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(theme.blueText)
                    }

                    Theme.divider(nightMode: theme.isNightMode)

                    Toggle(isOn: $isPremature) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Did your baby arrive early?")
                                .font(Theme.sproutlyFieldValue)
                                .foregroundStyle(theme.text)
                            Text("Before 37 weeks. We'll take that into account when showing milestones.")
                                .font(Theme.sproutlyBody)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .toggleStyle(SproutlyToggleStyle(nightMode: theme.isNightMode))
                    .padding(.vertical, 10)

                    if isPremature {
                        Theme.divider(nightMode: theme.isNightMode)

                        FormRow(
                            label: "Weeks at birth",
                            systemImage: "calendar.badge.clock",
                            nightMode: theme.isNightMode
                        ) {
                            Picker("", selection: $gestationalWeeks) {
                                ForEach(24...40, id: \.self) { week in
                                    Text("\(week) weeks").tag(week)
                                }
                            }
                            .labelsHidden()
                            .tint(theme.blueText)
                        }
                    }
                }
                .padding(24)
                .warmCard(nightMode: theme.isNightMode)

                Spacer(minLength: 24)
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
#if os(iOS)
        .scrollDismissesKeyboard(.interactively)
#endif
    }

    // Step 6: What they already do. Only reached when the list is non-empty.
    var backfillStep: some View {
        OnboardingBackfillStep(
            childName: trimmedName.isEmpty ? "your little one" : trimmedName,
            candidates: backfillCandidates,
            selection: $backfillSelection
        )
    }

    // Helper: form field label — icon carries the accent color, text stays
    // neutral. An all-blue label (icon + text) reads as unusually loud for a
    // form; every standard iOS form (Settings, Contacts) keeps labels neutral
    // and reserves color for the interactive/accent element only.
    func fieldLabel(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(theme.blueText)
            Text(text)
                .foregroundStyle(theme.textSecondary)
        }
        .font(Theme.sproutlyCardTitle)
    }

    // Helper: Compact How-It-Works row
    func howItWorksRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.blue.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .sproutlyScaledFont(18, relativeTo: .body)
                    .foregroundStyle(theme.blueText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.sproutlyCardTitle)
                    .foregroundStyle(theme.text)

                Text(subtitle)
                    .font(Theme.sproutlyBody)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.card)
                .shadow(color: theme.cardShadow, radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Navigation

private extension OnboardingView {


    func goBack() {
        isNameFieldFocused = false
        step = max(0, step - 1)
    }

    func goForward() {
        isNameFieldFocused = false
        step = min(totalSteps - 1, step + 1)
    }

    var navigationButtons: some View {
        Group {
            if isBackfillStep {
                backfillButtons
            } else {
                standardButtons
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    // Two exits, weighted the same. A parent who does not want to sit and tick
    // twelve boxes on their first minute in the app has not done anything wrong,
    // and the button that says so must not read as the lesser choice.
    var backfillButtons: some View {
        HStack(spacing: 12) {
            // Back belongs here like on every other step. Without it this screen
            // was a one-way door — a parent who mistyped the birth date could
            // only get out through Settings.
            Button {
#if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(SoftCapsuleStyle(baseColor: theme.blue, nightMode: theme.isNightMode))
            .disabled(isProcessing)
            .accessibilityLabel("Back")

            Button {
                guard !isProcessing else { return }
#if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                isProcessing = true
                completeOnboarding(applying: [])
            } label: {
                Text("Skip for now")
                    .fontWeight(.semibold)
                    .fixedSize()
                    .foregroundStyle(theme.text)
            }
            .buttonStyle(SoftCapsuleStyle(baseColor: theme.green, nightMode: theme.isNightMode))
            .disabled(isProcessing)

            Spacer(minLength: 0)

            Button {
                guard !isProcessing else { return }
#if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                isProcessing = true
                completeOnboarding(applying: backfillSelection)
            } label: {
                HStack(spacing: 8) {
                    Text("Done")
                        .fontWeight(.semibold)
                        .fixedSize()

                    Image(systemName: "heart.fill")
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(
                SoftCapsuleStyle(
                    baseColor: theme.blue,
                    isAction: true,
                    nightMode: theme.isNightMode
                )
            )
            .disabled(isProcessing)
        }
    }

    var standardButtons: some View {
        HStack(spacing: 16) {
            if step > 0 {
                Button {
#if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                    goBack()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(SoftCapsuleStyle(baseColor: theme.blue, nightMode: theme.isNightMode))
            }

            Spacer()

            Button {

                guard !isProcessing else { return }

#if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif

                if step == totalSteps - 1 {

                    isProcessing = true
                    completeOnboarding()
                } else {
                    goForward()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(step == totalSteps - 1 ? "Get Started" : "Continue")
                        .fontWeight(.semibold)
                        .fixedSize()

                    Image(systemName: step == totalSteps - 1 ? "heart.fill" : "chevron.right")
                }
                .foregroundStyle(step == totalSteps - 1 ? .white : theme.text)
            }
            .buttonStyle(
                SoftCapsuleStyle(
                    baseColor: step == totalSteps - 1 ? theme.blue : theme.green,
                    isAction: step == totalSteps - 1,
                    nightMode: theme.isNightMode
                )
            )
            .disabled(isNameMissing || isProcessing)
            .opacity(isNameMissing ? 0.5 : 1)
        }
    }

    // Creating the first child is what ends onboarding — ContentView switches over
    // as soon as the store has one.
    //
    // The backfill selection is applied here rather than as the parent taps,
    // because the milestone rows it marks are created by `addChild` on the line
    // above: until then there is nothing to mark. Titles are the join, which is
    // safe because every title in the seed catalog is unique.
    func completeOnboarding(applying backfilledTitles: Set<String> = []) {
        let child = childStore.addChild(
            name: trimmedName,
            birthDate: birthDate,
            isPremature: isPremature,
            gestationalWeeks: isPremature ? gestationalWeeks : 40
        )

        guard !backfilledTitles.isEmpty else { return }

        BackfillCatalog.apply(backfilledTitles, to: child)
        childStore.save()
    }
}

#if DEBUG
#Preview {
    OnboardingView()
        .environment(previewChildStore)
        .environment(PurchaseManager())
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
#endif
