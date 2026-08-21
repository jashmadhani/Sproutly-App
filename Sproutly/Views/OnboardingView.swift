//
//  OnboardingView.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/02/26.
//

import SwiftUI
import SwiftData

/// Five-step onboarding flow: Welcome → How It Works → Reassurance → Disclaimer → Profile.
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

    @FocusState private var isNameFieldFocused: Bool

    private let totalSteps = 5

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
                    } else {
                        profileStep
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
                ZStack {
                    Circle()
                        .fill(theme.blue.opacity(0.12))
                        .frame(width: 130, height: 130)

                    Circle()
                        .fill(theme.blue.opacity(0.08))
                        .frame(width: 110, height: 110)

                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(theme.blue)
                }

                Text("Sproutly")
                    .font(.sproutlyDisplay(40))
                    .foregroundStyle(theme.text)

                VStack(spacing: 8) {
                    Text("Every small moment matters")
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(theme.text)

                    Text("Sproutly helps you notice the quiet,\nbeautiful growth happening every day.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.textSecondary)
                        .lineSpacing(4)
                }
            }
        }
    }

    // Step 2: How It Works — Observe → Log → Reflect
    var howItWorksStep: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)

            Text("How Sproutly Works")
                .font(.sproutlyDisplay(28))
                .foregroundStyle(theme.text)

            VStack(spacing: 12) {
                howItWorksRow(
                    icon: "eye",
                    title: "Observe",
                    subtitle: "Notice the little things your child does each day"
                )

                howItWorksRow(
                    icon: "square.and.pencil",
                    title: "Log",
                    subtitle: "Tap once to record a milestone — it takes a second"
                )

                howItWorksRow(
                    icon: "heart.text.square",
                    title: "Reflect",
                    subtitle: "Look back on your journey with warmth"
                )
            }
            .padding(.horizontal, 24)

            Text("That's it. Simple, gentle, yours.")
                .font(Theme.sproutlyBody)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer(minLength: 8)
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

                Text("Every child blooms in their own time.\nSproutly is here to support you,\nnot to score or compare.")
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

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Child's Name", systemImage: "heart.fill")


                        TextField("Enter name", text: $childName)
                            .focused($isNameFieldFocused)
                            .textFieldStyle(.plain)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(theme.text.opacity(0.05))
                            )
                            .foregroundStyle(theme.text)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onTapGesture {
                                isNameFieldFocused = true
                            }
                    }


                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Birth Date", systemImage: "calendar")

                        DatePicker("", selection: $birthDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(theme.blue)
                    }


                    Toggle(isOn: $isPremature) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Born Before 37 Weeks")
                                .font(Theme.sproutlyCardTitle)
                                .foregroundStyle(theme.text)
                            Text("We'll adjust milestones gently")
                                .font(Theme.sproutlyBody)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .tint(theme.green)

                    if isPremature {
                        VStack(alignment: .leading, spacing: 8) {
                            fieldLabel("Gestational Age at Birth", systemImage: "calendar.badge.clock")

                            Picker("Weeks", selection: $gestationalWeeks) {
                                ForEach(24...40, id: \.self) { week in
                                    Text("\(week) weeks").tag(week)
                                }
                            }
#if os(iOS)
                            .pickerStyle(.wheel)
#endif
                            .frame(height: 100)
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

    // Helper: form field label — icon carries the accent color, text stays
    // neutral. An all-blue label (icon + text) reads as unusually loud for a
    // form; every standard iOS form (Settings, Contacts) keeps labels neutral
    // and reserves color for the interactive/accent element only.
    func fieldLabel(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(theme.blue)
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
                    .font(.system(size: 18))
                    .foregroundStyle(theme.blue)
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
                .fill(theme.isNightMode ? Theme.nightCard : .white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
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
            .disabled((step == totalSteps - 1 && childName.isEmpty) || isProcessing)
            .opacity((step == totalSteps - 1 && childName.isEmpty) ? 0.5 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    // Creating the first child is what ends onboarding — ContentView switches over
    // as soon as the store has one.
    func completeOnboarding() {
        childStore.addChild(
            name: childName.trimmingCharacters(in: .whitespacesAndNewlines),
            birthDate: birthDate,
            isPremature: isPremature,
            gestationalWeeks: isPremature ? gestationalWeeks : 40
        )
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
