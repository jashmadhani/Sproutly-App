//
//  MilestonesView.swift
//  Sproutly
//
//  Created by Jash Madhani on 27/02/26.
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Filter Mode

enum MilestoneFilter: String, CaseIterable {
    case thisStage = "This Stage"
    case all = "All"
    case completed = "Completed"
}

// MARK: - Milestones View


struct MilestonesView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(ChildStore.self) private var childStore
    @Environment(PurchaseManager.self) private var purchases

    // MainTabView only renders once a child exists; the fallback keeps this view
    // total without threading an optional through every call site.
    private var child: Child { childStore.activeChild ?? Child() }
    private var milestones: [Milestone] { child.sortedMilestones }
    @Environment(ThemeManager.self) private var theme

    @State private var selectedFilter: MilestoneFilter = .thisStage
    @State private var expandedDomains: Set<String> = Set(MilestoneCategory.allCases.map(\.rawValue))
    @State private var milestoneForNote: Milestone? = nil
    @State private var noteText: String = ""
    @State private var milestoneToUncheck: Milestone? = nil
    @State private var showRemoveAlert: Bool = false
    @State private var showAddMilestone: Bool = false
    @State private var pendingPhotoData: Data? = nil
    @State private var milestoneToDelete: Milestone? = nil
    @State private var showDeleteMilestoneAlert: Bool = false
    @State private var shareItem: ShareItem? = nil
    @State private var paywallReason: PaywallReason? = nil
    @Namespace private var photoZoomNamespace
    @State private var expandedPhotoMilestone: Milestone? = nil
    @State private var expandedPhotoImage: UIImage? = nil

    // MARK: - Derived Data

    private var correctedAge: Int { max(0, child.calculateCorrectedAge()) }

    // Derived from the standard set only. A parent-authored moment is stamped with
    // the child's current age, and letting those into this calculation would pull
    // the stage away from the real milestone bands (6, 9, 12, …).
    private var targetAgeMonth: Int {
        let standardAges = Set(milestones.filter { !$0.isUserCreated }.map(\.ageMonth))
        guard !standardAges.isEmpty else { return 6 }
        return standardAges.min(by: { abs($0 - correctedAge) < abs($1 - correctedAge) }) ?? 6
    }

    private var filteredMilestones: [Milestone] {
        switch selectedFilter {
        case .thisStage:
            // Their own moments always show — a parent who just added one should
            // never have to hunt for it behind a filter. Completed ones move to
            // the Completed tab instead of lingering here struck through —
            // "This Stage" is the to-do list, not the full history.
            return milestones.filter {
                ($0.ageMonth == targetAgeMonth || $0.isUserCreated) && !$0.isCompleted
            }
        case .all:
            return milestones
        case .completed:
            return milestones
                .filter(\.isCompleted)
                .sorted { ($0.dateCompleted ?? .distantPast) > ($1.dateCompleted ?? .distantPast) }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            AmbientBackground(nightMode: theme.isNightMode)

            ScrollView {
                VStack(spacing: Theme.sectionSpacing) {
                    headerSection
                    filterPicker
                    domainGroups
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)

            // Full-screen photo zoom. Lives at this level, not inside the row,
            // because it needs to cover the whole screen — a matchedGeometryEffect
            // pair needs both ends visible in the same view hierarchy, which a
            // row nested in a ScrollView can't provide on its own.
            if let milestone = expandedPhotoMilestone {
                ZStack {
                    Color.black.opacity(0.92)
                        .ignoresSafeArea()
                        .onTapGesture { collapsePhoto() }

                    if let expandedPhotoImage {
                        Image(uiImage: expandedPhotoImage)
                            .resizable()
                            .scaledToFit()
                            .matchedGeometryEffect(id: milestone.id, in: photoZoomNamespace)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .padding(24)
                            .onTapGesture { collapsePhoto() }
                            .gesture(
                                DragGesture().onEnded { value in
                                    if value.translation.height > 80 { collapsePhoto() }
                                }
                            )
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .task(id: expandedPhotoMilestone?.photoFilename) {
            guard let filename = expandedPhotoMilestone?.photoFilename else {
                expandedPhotoImage = nil
                return
            }
            expandedPhotoImage = await Task.detached(priority: .userInitiated) {
                PhotoStore.image(named: filename)
            }.value
        }
        .sheet(item: $milestoneForNote) { milestone in
            completionNoteSheet(for: milestone)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.isNightMode ? Theme.nightCard : Color.white)
        }
        .alert("Remove Milestone?", isPresented: $showRemoveAlert, presenting: milestoneToUncheck) { milestone in
            Button("Cancel", role: .cancel) { milestoneToUncheck = nil }
            Button("Remove", role: .destructive) {
                milestone.isCompleted = false
                milestone.dateCompleted = nil
                milestone.completionNote = ""
                PhotoStore.delete(milestone.photoFilename)
                milestone.photoFilename = nil
                saveContext()
                milestoneToUncheck = nil
            }
        } message: { _ in
            Text("This will delete your saved memory, including any photo.")
        }
        .alert("Delete this moment?", isPresented: $showDeleteMilestoneAlert, presenting: milestoneToDelete) { milestone in
            Button("Cancel", role: .cancel) { milestoneToDelete = nil }
            Button("Delete", role: .destructive) {
                PhotoStore.delete(milestone.photoFilename)
                modelContext.delete(milestone)
                childStore.save()
                milestoneToDelete = nil
            }
        } message: { milestone in
            Text("\"\(milestone.title)\" will be removed permanently.")
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url)
        }
        .sheet(item: $paywallReason) { reason in
            PaywallView(reason: reason)
        }
        .sheet(isPresented: $showAddMilestone) {
            if let active = childStore.activeChild {
                AddMilestoneSheet(child: active)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Milestones")
                    .font(.sproutlyDisplay(30))
                    .foregroundStyle(theme.text)

                // Naming the child here is what stops a parent logging against the
                // wrong one after switching.
                Text("\(child.displayName) · \(ageDescription)")
                    .font(Theme.sproutlyBody)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            Button {
                if purchases.isPro {
                    showAddMilestone = true
                } else {
                    paywallReason = .customMilestone
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                    Text("Add moment")
                        .font(Theme.sproutlyMeta)
                        .fontWeight(.semibold)
                    // A free parent taps this and lands on the paywall — the
                    // lock says so up front instead of the tap being a
                    // surprise. Matches the "Pro" badge convention used on
                    // the App Icon row in Settings.
                    if !purchases.isPro {
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.semibold))
                    }
                }
                .foregroundStyle(theme.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(theme.blue.opacity(0.18))
                )
                .overlay(
                    Capsule().strokeBorder(theme.blue.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a moment")
            .accessibilityHint("Record your own milestone for \(child.displayName)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var ageDescription: String {
        let months = correctedAge
        if months < 24 {
            return "\(months) month\(months == 1 ? "" : "s") corrected age"
        } else {
            let years = months / 12
            let rem = months % 12
            if rem == 0 {
                return "\(years) year\(years == 1 ? "" : "s") corrected age"
            }
            return "\(years)y \(rem)m corrected age"
        }
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(MilestoneFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
        .accessibilityLabel("Milestone filter")
    }

    // MARK: - Domain Groups

    private var domainGroups: some View {
        // Computed once and reused — groupedMilestones and the emptiness
        // check were each independently re-filtering and re-sorting the
        // same milestone list.
        let filtered = filteredMilestones
        let grouped = Dictionary(grouping: filtered, by: \.category)
        let showAll = selectedFilter == .thisStage || selectedFilter == .all
        let isEmpty = filtered.isEmpty

        // LazyVStack, not VStack — with every domain expanded by default this
        // was building all ~80 milestone rows synchronously the instant the
        // tab appeared, which is what showed up as a brief hitch on tap.
        return LazyVStack(spacing: Theme.sectionSpacing) {
            ForEach(MilestoneCategory.allCases, id: \.self) { category in
                let domainMilestones = grouped[category.rawValue] ?? []
                let completedCount = domainMilestones.filter(\.isCompleted).count

                if !domainMilestones.isEmpty || showAll {
                    domainSection(
                        category: category,
                        milestones: domainMilestones,
                        stats: (completedCount, domainMilestones.count)
                    )
                }
            }

            if isEmpty {
                emptyState
            }
        }
    }

    private func domainSection(
        category: MilestoneCategory,
        milestones: [Milestone],
        stats: (completed: Int, total: Int)
    ) -> some View {
        let isExpanded = expandedDomains.contains(category.rawValue)

        return VStack(spacing: 0) {
            // Domain header
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    if isExpanded {
                        expandedDomains.remove(category.rawValue)
                    } else {
                        expandedDomains.insert(category.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(category.color(for: theme.isNightMode).opacity(0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: category.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(category.color(for: theme.isNightMode))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.gentleLabel)
                            .font(Theme.sproutlyCardTitle)
                            .foregroundStyle(theme.text)

                        Text("\(stats.completed) of \(stats.total)")
                            .font(Theme.sproutlyMeta)
                            .foregroundStyle(theme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeOut(duration: 0.2), value: isExpanded)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(category.gentleLabel), \(stats.completed) of \(stats.total)")
            .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")

            // Expanded milestone rows
            if isExpanded {
                VStack(spacing: Theme.itemSpacing) {
                    if milestones.isEmpty {
                        Text("No milestones in this filter.")
                            .font(Theme.sproutlyBody)
                            .foregroundStyle(theme.textSecondary)
                            .padding(.bottom, 12)
                    } else {
                        ForEach(milestones) { milestone in
                            milestoneRow(milestone)
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity)
            }
        }
        .warmCard(nightMode: theme.isNightMode)
    }

    // MARK: - Milestone Row

    private func milestoneRow(_ milestone: Milestone) -> some View {
        HStack(spacing: 12) {
            MilestoneThumbnail(
                milestone: milestone,
                namespace: photoZoomNamespace,
                isExpanded: expandedPhotoMilestone?.id == milestone.id
            ) {
                expandedPhotoImage = nil
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    expandedPhotoMilestone = milestone
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(Theme.sproutlyItemTitle)
                    .foregroundStyle(milestone.isCompleted ? theme.textSecondary : theme.text)
                    .strikethrough(milestone.isCompleted, color: theme.green.opacity(0.8))

                // A parent-authored moment has no expected age, so it gets a quiet
                // "Your moment" label instead of a clinical age band. Same row
                // styling otherwise — these are not a separate kind of thing.
                if milestone.isUserCreated {
                    Label("Your moment", systemImage: "heart.fill")
                        .font(Theme.sproutlyMeta)
                        .foregroundStyle(theme.blue.opacity(0.8))
                } else {
                    Text(milestone.expectedAgeText)
                        .font(Theme.sproutlyMeta)
                        .foregroundStyle(theme.textSecondary)
                }

                // Show completion note if present
                if milestone.isCompleted && !milestone.completionNote.isEmpty {
                    Text(milestone.completionNote)
                        .font(Theme.sproutlyMeta)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .italic()
                }
            }

            Spacer()

            OneTapLogButton(
                isCompleted: milestone.isCompleted,
                nightMode: theme.isNightMode,
                accessibilityTitle: milestone.title
            ) {
                handleToggle(milestone)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    milestone.isCompleted
                        ? theme.green.opacity(theme.isNightMode ? 0.14 : 0.10)
                        : theme.text.opacity(theme.isNightMode ? 0.08 : 0.06)
                )
        )
        .accessibilityElement(children: .combine)
        // Only parent-authored moments can be removed; the standard set is fixed.
        .contextMenu {
            if milestone.isCompleted {
                Button {
                    guard purchases.isPro else {
                        paywallReason = .shareCard
                        return
                    }
                    if let url = ShareRenderer.card(
                        for: milestone,
                        childName: child.displayName,
                        nightMode: theme.isNightMode
                    ) {
                        shareItem = ShareItem(url: url)
                    }
                } label: {
                    Label("Share this moment", systemImage: "square.and.arrow.up")
                }
            }

            if milestone.isUserCreated {
                Button(role: .destructive) {
                    milestoneToDelete = milestone
                    showDeleteMilestoneAlert = true
                } label: {
                    Label("Delete Moment", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(theme.textSecondary)

            Text(selectedFilter == .completed
                 ? "No milestones completed yet.\nTap + to celebrate a moment!"
                 : "No milestones available.")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Completion Note Sheet

    private func completionNoteSheet(for milestone: Milestone) -> some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(theme.green)

                Text("Moment Captured!")
                    .font(.sproutlyDisplay(24))
                    .foregroundStyle(theme.text)

                Text(milestone.title)
                    .font(Theme.sproutlyBody)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // Note field
            VStack(alignment: .leading, spacing: 8) {
                Label("Add a memory", systemImage: "pencil.line")
                    .font(Theme.sproutlyCardTitle)
                    .foregroundStyle(theme.blue)

                TextField("What made it special? (optional)", text: $noteText, axis: .vertical)
                    .lineLimit(1...3)
                    .font(Theme.sproutlyBody)
                    .foregroundStyle(theme.text)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.text.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(theme.blue.opacity(0.1), lineWidth: 1)
                    )
            }

            // Photo — offered, never required. The one-tap log stays one tap;
            // this sheet is already open, so nothing new interrupts the flow.
            if purchases.isPro {
                MilestonePhotoPicker(
                    imageData: $pendingPhotoData,
                    nightMode: theme.isNightMode
                )
            } else {
                Button {
                    // Presenting a second .sheet while this completion sheet
                    // is still on screen forces SwiftUI to dismiss-then-
                    // present sequentially — two full sheet animations
                    // chained is exactly what read as "takes a long time to
                    // appear." Dismissing first and presenting the paywall
                    // once that animation finishes is one clean transition
                    // instead of two stacked ones.
                    resetSheetState()
                    Task {
                        try? await Task.sleep(for: .seconds(0.35))
                        paywallReason = .photo
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                        Text("Add a photo")
                            .font(Theme.sproutlyCardTitle)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(Theme.sproutlyMeta)
                    }
                    .foregroundStyle(theme.textSecondary)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.text.opacity(0.04))
                    )
                }
                .buttonStyle(.plain)
            }

            // Buttons
            HStack(spacing: 14) {
                Button {
                    // Skip — complete without note
                    commitToggle(milestone, note: "")
                    resetSheetState()
                } label: {
                    Text("Skip")
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.text.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    // Save with note
                    if let data = pendingPhotoData, let filename = PhotoStore.save(data) {
                        PhotoStore.delete(milestone.photoFilename)
                        milestone.photoFilename = filename
                    }
                    commitToggle(milestone, note: noteText.trimmingCharacters(in: .whitespacesAndNewlines))
                    resetSheetState()
                } label: {
                    // A saturated white-on-solid-green button (the paywall's
                    // treatment) reads as a purchase CTA, not a save action —
                    // and put a second, different green next to the heart
                    // icon's theme.green a few lines up. This stays in the
                    // same pastel-on-light language as Skip and everything
                    // else in the app, just tinted to read as the affirmative
                    // choice — dark green text on a soft green tint, matching
                    // the low-contrast, low-drama visual language everywhere else.
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("Save Memory")
                    }
                    .font(Theme.sproutlyCardTitle)
                    .foregroundStyle(theme.isNightMode ? Theme.ctaGreenBottomNight : Theme.ctaGreenBottom)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.green.opacity(theme.isNightMode ? 0.24 : 0.16))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(theme.isNightMode ? Theme.nightCard : Color.white)
    }

    // MARK: - Actions

    // marking → show note sheet, unmarking → toggle immediately
    private func resetSheetState() {
        milestoneForNote = nil
        noteText = ""
        pendingPhotoData = nil
    }

    private func handleToggle(_ milestone: Milestone) {
        if milestone.isCompleted {
            if !milestone.completionNote.isEmpty {
                milestoneToUncheck = milestone
                showRemoveAlert = true
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    milestone.isCompleted = false
                    milestone.dateCompleted = nil
                    milestone.completionNote = ""
                }
                saveContext()
            }
        } else {
            milestoneForNote = milestone
        }
    }


    private func commitToggle(_ milestone: Milestone, note: String) {
        withAnimation(.easeOut(duration: 0.3)) {
            milestone.isCompleted = true
            milestone.dateCompleted = Date()
            milestone.completionNote = note
        }
        saveContext()
    }

    private func saveContext() {
        let ctx = modelContext
        Task.detached { @MainActor in
            try? ctx.save()
        }
    }

    private func collapsePhoto() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            expandedPhotoMilestone = nil
        }
    }
}

// MARK: - Milestone Thumbnail

// Decoding a JPEG off disk is real work — doing it synchronously inside a
// row's body (the previous approach) ran on the main thread on every render,
// which is exactly the kind of thing that's invisible on a Mac's SSD/CPU in
// Simulator but shows up as a stutter on an actual phone. Loaded async here
// instead, matching the pattern MilestonePhotoPicker already uses.
private struct MilestoneThumbnail: View {
    let milestone: Milestone
    let namespace: Namespace.ID
    let isExpanded: Bool
    let onTap: () -> Void
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Button(action: onTap) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                // Hidden while its full-screen counterpart is showing —
                // matchedGeometryEffect expects exactly one visible instance
                // of a given id at a time; leaving both visible causes the
                // effect to snap instead of animating smoothly.
                .opacity(isExpanded ? 0 : 1)
                .matchedGeometryEffect(id: milestone.id, in: namespace, isSource: !isExpanded)
                .accessibilityLabel("View photo for \(milestone.title)")
            }
        }
        .task(id: milestone.photoFilename) {
            guard let filename = milestone.photoFilename else { image = nil; return }
            image = await Task.detached(priority: .userInitiated) {
                PhotoStore.image(named: filename)
            }.value
        }
    }
}

// MARK: - Preview

#Preview {

    MilestonesView()
        .environment(previewChildStore)
        .environment(PurchaseManager())
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
