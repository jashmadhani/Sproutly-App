//
//  SettingsView.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/02/26.
//

import SwiftUI
import SwiftData


struct SettingsView: View {
    @Environment(ChildStore.self) private var childStore
    @Environment(PurchaseManager.self) private var purchases

    private var child: Child { childStore.activeChild ?? Child() }
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var theme
    
    @State private var showResetAlert = false
    @State private var showDeleteAlert = false
    // One sheet binding rather than several. Stacking multiple `.sheet`
    // modifiers on the same view is unreliable in SwiftUI — presentations
    // compete and some silently never appear — so every modal this screen owns
    // goes through a single enum-driven presentation.
    private enum SettingsSheet: Identifiable {
        case addChild
        case aboutData
        case appIcon
        case proFeatures
        case paywall(PaywallReason)

        var id: String {
            switch self {
            case .addChild:          return "addChild"
            case .aboutData:         return "aboutData"
            case .appIcon:           return "appIcon"
            case .proFeatures:       return "proFeatures"
            case .paywall(let r):    return "paywall-\(r.id)"
            }
        }
    }

    @State private var activeSheet: SettingsSheet?
    @State private var showRemoveChildAlert = false
    @State private var childToDelete: Child?
    @State private var scrollOffset: CGFloat = 0
    
    private var isCompactHeader: Bool { scrollOffset < -10 }
    
    var body: some View {
        ZStack(alignment: .top) {   
            AmbientBackground(nightMode: theme.isNightMode)
            
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    headerSection
                    nightModeCard
                    childrenSection
                    profileSection
                    prematuritySection
                    if purchases.isPro {
                        proFeaturesSection
                    }
                    appIconSection
                    aboutSection
                    dataSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: geo.frame(in: .named("settingsScroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "settingsScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }
            .scrollDismissesKeyboard(.interactively)
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 80)
                    Color.black
                }
                .ignoresSafeArea()
            )
            
            // Compact header
            VStack {
                HStack {
                    Text("Settings")
                        .font(.sproutlyCompactHeading(17))
                        .foregroundStyle(theme.text)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .opacity(isCompactHeader ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: isCompactHeader)
                Spacer()
            }
            .ignoresSafeArea()
        }
        // Both alerts name the child. With siblings in the app, an unnamed
        // destructive confirmation is how a parent wipes the wrong one.
        .alert("Reset \(child.displayName)'s Progress", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) { resetProgress() }
        } message: {
            Text("This unmarks every milestone for \(child.displayName). Their profile is kept, and other children are not affected.")
        }
        .alert("Delete All Data", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteAllData() }
        } message: {
            Text("This removes every child and all their milestones, and returns to the welcome screen.")
        }
        .alert("Remove \(childToDelete?.displayName ?? "")?", isPresented: $showRemoveChildAlert) {
            Button("Cancel", role: .cancel) { childToDelete = nil }
            Button("Remove", role: .destructive) {
                if let target = childToDelete { childStore.delete(target) }
                childToDelete = nil
            }
        } message: {
            Text("This permanently removes \(childToDelete?.displayName ?? "this child") and their milestones. Other children are not affected.")
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addChild:       AddChildSheet()
            case .aboutData:      AboutDataView()
            case .appIcon:        AppIconPickerView()
            case .proFeatures:    ProFeaturesView()
            case .paywall(let r): PaywallView(reason: r)
            }
        }
    }
    
    // MARK: - Field Label

    // Icon carries the accent color, text stays neutral — an all-blue label
    // (icon + text) reads as unusually loud for a section header; matches the
    // same helper in OnboardingView so the two form-heavy screens agree.
    private func fieldLabel(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(theme.blue)
            Text(text)
                .foregroundStyle(theme.textSecondary)
        }
        .font(Theme.sproutlyCardTitle)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.sproutlyDisplay(30))
                .foregroundStyle(theme.text)
            
            Text("Adjust your experience")
                .font(Theme.sproutlyBody)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Night Mode
    
    private var nightModeCard: some View {
        @Bindable var tm = theme
        
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(theme.blue.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                Image(systemName: theme.isNightMode ? "moon.stars.fill" : "moon.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Night Mode")
                    .font(Theme.sproutlyCardTitle)
                    .foregroundStyle(theme.text)

                Text("Reduce brightness for quiet evenings")
                    .font(Theme.sproutlyBody)
                    .foregroundStyle(theme.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $tm.isNightMode)
                .labelsHidden()
                .tint(theme.blue)
                .accessibilityLabel("Night Mode")
                .accessibilityHint("Reduce brightness for quiet evenings")
        }
        .warmCard(nightMode: theme.isNightMode)
        .animation(.easeInOut(duration: 0.4), value: theme.isNightMode)
    }
    
    // MARK: - Children

    // Roster + add. The list itself is only shown once a second child exists —
    // a parent with one child sees just "Add a child".
    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldLabel("Children", systemImage: "figure.2.and.child.holdinghands")

            if childStore.hasMultipleChildren {
                ForEach(childStore.children) { entry in
                    let isActive = entry.id == childStore.activeChild?.id

                    HStack(spacing: 12) {
                        Button {
                            childStore.select(entry)
                        } label: {
                            HStack(spacing: 12) {
                                ChildAvatar(child: entry, isActive: isActive, nightMode: theme.isNightMode)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.displayName)
                                        .font(isActive ? Theme.sproutlyCardTitle : Font.system(.body).weight(.regular))
                                        .foregroundStyle(theme.text)
                                    Text(entry.ageText)
                                        .font(Theme.sproutlyMeta)
                                        .foregroundStyle(theme.textSecondary)
                                }

                                Spacer()

                                if isActive {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(theme.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(entry.displayName), \(entry.ageText)")
                        .accessibilityHint(isActive ? "Currently showing" : "Switch to this child")

                        Button {
                            childToDelete = entry
                            showRemoveChildAlert = true
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(entry.displayName)")
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                // The first child is free; a second is where Pro begins.
                if purchases.isPro || childStore.children.isEmpty {
                    activeSheet = .addChild
                } else {
                    activeSheet = .paywall(.secondChild)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(theme.blue)
                    Text("Add a child")
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(theme.text)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Adds another child with their own milestones")
        }
        .warmCard(nightMode: theme.isNightMode)
    }

    // MARK: - Profile

    private var profileSection: some View {
        @Bindable var profile = child
        
        return VStack(alignment: .leading, spacing: 16) {
            fieldLabel(child.displayName, systemImage: "heart.fill")
            
            // Name
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(Theme.sproutlyMeta)
                    .foregroundStyle(theme.textSecondary)
                
                TextField("Child's name", text: $profile.name)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.text.opacity(0.04))
                    )
                    .foregroundStyle(theme.text)
                    .onChange(of: child.name) { _, _ in
                        childStore.save()
                    }
            }
            
            // Birth date
            VStack(alignment: .leading, spacing: 6) {
                Text("Birth Date")
                    .font(Theme.sproutlyMeta)
                    .foregroundStyle(theme.textSecondary)
                
                DatePicker("", selection: $profile.birthDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(theme.blue)
                    .onChange(of: child.birthDate) { _, _ in
                        childStore.save()
                    }
            }
        }
        .warmCard(nightMode: theme.isNightMode)
    }
    
    // MARK: - Prematurity
    
    private var prematuritySection: some View {
        @Bindable var profile = child
        
        return VStack(alignment: .leading, spacing: 16) {
            fieldLabel("Adjusted Age", systemImage: "sparkles")
            
            Toggle(isOn: $profile.isPremature) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Born Before 37 Weeks")
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(theme.text)
                    Text("Milestones will be gently adjusted")
                        .font(Theme.sproutlyBody)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .tint(theme.green)
            .accessibilityLabel("Born Before 37 Weeks")
            .accessibilityHint("Adjusts milestones for premature birth")
            .onChange(of: child.isPremature) { _, _ in
                childStore.save()
            }
            
            if child.isPremature {
                HStack {
                    Text("Gestational age:")
                        .font(Theme.sproutlyBody)
                        .foregroundStyle(theme.textSecondary)
                    
                    Picker("", selection: $profile.gestationalWeeks) {
                        ForEach(24...40, id: \.self) { week in
                            Text("\(week) weeks").tag(week)
                        }
                    }
                    .tint(theme.blue)
                    .onChange(of: child.gestationalWeeks) { _, _ in
                        childStore.save()
                    }
                }
                .transition(.opacity)
            }
        }
        .warmCard(nightMode: theme.isNightMode)
        .animation(.spring(response: 0.4), value: child.isPremature)
    }
    
    // MARK: - Pro Features

    // Only shown once Pro is owned — the durable answer to "what did I buy
    // and where do I use it," reachable any time without hunting.
    private var proFeaturesSection: some View {
        Button {
            activeSheet = .proFeatures
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .foregroundStyle(theme.proGold)
                Text("Pro Features")
                    .font(Theme.sproutlyCardTitle)
                    .foregroundStyle(theme.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textSecondary.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .warmCard(nightMode: theme.isNightMode)
    }

    // MARK: - App Icon

    // Reach-triggered like every other gate: a free parent taps this and gets
    // the paywall naming the feature, rather than a disabled row.
    private var appIconSection: some View {
        Button {
            activeSheet = purchases.isPro ? .appIcon : .paywall(.appIcon)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "app.badge")
                    .foregroundStyle(theme.textSecondary)
                Text("App Icon")
                    .font(Theme.sproutlyCardTitle)
                    .foregroundStyle(theme.text)
                Spacer()
                if !purchases.isPro {
                    Text("Pro")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.proGold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(theme.proGold.opacity(0.14))
                        )
                }
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textSecondary.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .warmCard(nightMode: theme.isNightMode)
    }

    // MARK: - About

    private var aboutSection: some View {
        Button {
            activeSheet = .aboutData
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .foregroundStyle(theme.textSecondary)
                Text("About the Data")
                    .font(Theme.sproutlyCardTitle)
                    .foregroundStyle(theme.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textSecondary.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .warmCard(nightMode: theme.isNightMode)
    }
    
    // MARK: - Data Management
    
    private var dataSection: some View {
        // Reset and Delete are each their own full-width card, same visual
        // weight as every other card on this screen — they were the one
        // place still using itemSpacing, which is what made the gap here
        // read as tighter than everywhere else.
        VStack(spacing: Theme.sectionSpacing) {
            Button {
                showResetAlert = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(theme.textSecondary)
                    Text("Reset Milestone Progress")
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(theme.text)
                    Spacer()
                }
            }
            .warmCard(nightMode: theme.isNightMode)
            .accessibilityLabel("Reset Milestone Progress")
            .accessibilityHint("Unmarks all milestones, keeps profile")
            
            Button {
                showDeleteAlert = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.7))
                    Text("Delete All Data")
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(.red.opacity(0.7))
                    Spacer()
                }
            }
            .warmCard(nightMode: theme.isNightMode)
            .accessibilityLabel("Delete All Data")
            .accessibilityHint("Removes all data and returns to welcome screen")
        }
    }
    
    // MARK: - Actions
    
    // Scoped to the active child only — a sibling's progress is never touched.
    private func resetProgress() {
        guard let active = childStore.activeChild else { return }
        for milestone in active.milestones {
            milestone.isCompleted = false
            milestone.dateCompleted = nil
            milestone.completionNote = ""
        }
        childStore.save()
    }

    private func deleteAllData() {
        // Roll back to light mode (default mode)
        theme.isNightMode = false

        // Deleting each child cascades to their milestones.
        for child in childStore.children {
            childStore.delete(child)
        }

        LegacyProfile.clear()
        childStore.refresh()
    }
}

#Preview {
    SettingsView()
        .environment(previewChildStore)
        .environment(PurchaseManager())
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
