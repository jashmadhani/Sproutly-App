//
//  SettingsView.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/02/26.
//

import SwiftUI
import SwiftData


struct SettingsView: View {
    @Environment(ChildProfile.self) private var childProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var theme
    
    @State private var showResetAlert = false
    @State private var showDeleteAlert = false
    @State private var showAboutData = false
    @State private var scrollOffset: CGFloat = 0
    
    private var isCompactHeader: Bool { scrollOffset < -10 }
    
    var body: some View {
        ZStack(alignment: .top) {   
            AmbientBackground(nightMode: theme.isNightMode)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    nightModeCard
                    profileSection
                    prematuritySection
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
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
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
        .alert("Reset Progress", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) { resetProgress() }
        } message: {
            Text("This will unmark all milestones. Your child's profile will be kept.")
        }
        .alert("Delete All Data", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteAllData() }
        } message: {
            Text("This will remove all data and return to the welcome screen.")
        }
        .sheet(isPresented: $showAboutData) {
            AboutDataView()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(theme.text)
            
            Text("Adjust your experience")
                .font(.subheadline)
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
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.text)
                
                Text("Reduce brightness for quiet evenings")
                    .font(.caption)
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
    
    // MARK: - Profile
    
    private var profileSection: some View {
        @Bindable var profile = childProfile
        
        return VStack(alignment: .leading, spacing: 16) {
            Label("Your Little One", systemImage: "heart.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.blue)
            
            // Name
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                
                TextField("Child's name", text: $profile.name)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.text.opacity(0.04))
                    )
                    .foregroundStyle(theme.text)
                    .onChange(of: childProfile.name) { _, _ in
                        childProfile.save()
                    }
            }
            
            // Birth date
            VStack(alignment: .leading, spacing: 6) {
                Text("Birth Date")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                
                DatePicker("", selection: $profile.birthDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(theme.blue)
                    .onChange(of: childProfile.birthDate) { _, _ in
                        childProfile.save()
                    }
            }
        }
        .warmCard(nightMode: theme.isNightMode)
    }
    
    // MARK: - Prematurity
    
    private var prematuritySection: some View {
        @Bindable var profile = childProfile
        
        return VStack(alignment: .leading, spacing: 16) {
            Label("Adjusted Age", systemImage: "sparkles")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.blue)
            
            Toggle(isOn: $profile.isPremature) {
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
            .accessibilityLabel("Born Before 37 Weeks")
            .accessibilityHint("Adjusts milestones for premature birth")
            .onChange(of: childProfile.isPremature) { _, _ in
                childProfile.save()
            }
            
            if childProfile.isPremature {
                HStack {
                    Text("Gestational age:")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                    
                    Picker("", selection: $profile.gestationalWeeks) {
                        ForEach(24...36, id: \.self) { week in
                            Text("\(week) weeks").tag(week)
                        }
                    }
                    .tint(theme.blue)
                    .onChange(of: childProfile.gestationalWeeks) { _, _ in
                        childProfile.save()
                    }
                }
                .transition(.opacity)
            }
        }
        .warmCard(nightMode: theme.isNightMode)
        .animation(.spring(response: 0.4), value: childProfile.isPremature)
    }
    
    // MARK: - About
    
    private var aboutSection: some View {
        Button {
            showAboutData = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .foregroundStyle(theme.textSecondary)
                Text("About the Data")
                    .font(.subheadline)
                    .foregroundStyle(theme.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .warmCard(nightMode: theme.isNightMode)
    }
    
    // MARK: - Data Management
    
    private var dataSection: some View {
        VStack(spacing: 12) {
            Button {
                showResetAlert = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(theme.textSecondary)
                    Text("Reset Milestone Progress")
                        .font(.subheadline)
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
                        .font(.subheadline)
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
    
    private func resetProgress() {
        let descriptor = FetchDescriptor<Milestone>()
        if let allMilestones = try? modelContext.fetch(descriptor) {
            for milestone in allMilestones {
                milestone.isCompleted = false
                milestone.dateCompleted = nil
                milestone.completionNote = ""
            }
            try? modelContext.save()
        }
    }
    
    private func deleteAllData() {
        // Roll back to light mode (default mode)
        theme.isNightMode = false
        
        // Delete all milestones
        let descriptor = FetchDescriptor<Milestone>()
        if let allMilestones = try? modelContext.fetch(descriptor) {
            for milestone in allMilestones {
                modelContext.delete(milestone)
            }
            try? modelContext.save()
        }
        
        // Reset profile
        childProfile.reset()
    }
}

#Preview {
    SettingsView()
        .environment(ChildProfile())
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
