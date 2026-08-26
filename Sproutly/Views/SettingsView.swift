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
    @Environment(NotificationManager.self) private var notifications

    private var child: Child { childStore.activeChild ?? Child() }
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Reveals the per-row remove buttons. Resets on every appearance — an
    /// editing mode a parent left on last week should not be waiting for them.
    @State private var isEditingChildren = false
    
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
    @FocusState private var isProfileNameFocused: Bool
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
                    notificationsSection
                    if !purchases.isPro {
                        proSection
                    }
                    moreSection
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
            .scrollEdgeFade()
            
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
    /// - Parameter tint: overrides the accent for the one header that isn't
    ///   blue. Gold means Sproutly Pro everywhere else in the app — the lock
    ///   badges, the Pro Features row — so a blue star on the Pro card would
    ///   have been the only place the mark changed colour.
    private func fieldLabel(
        _ text: String,
        systemImage: String,
        tint: Color? = nil
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint ?? theme.blueText)
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
        
        return FeatureCardHeader(
            title: "Night Mode",
            subtitle: "Reduce brightness for quiet evenings",
            systemImage: theme.isNightMode ? "moon.stars.fill" : "moon.fill",
            nightMode: theme.isNightMode
        ) {
            SproutlySwitch(isOn: $tm.isNightMode, nightMode: theme.isNightMode)
                .accessibilityLabel("Night Mode")
                .accessibilityHint("Reduce brightness for quiet evenings")
        }
        .warmCard(nightMode: theme.isNightMode)
        .animation(.easeInOut(duration: 0.4), value: theme.isNightMode)
    }
    
    // MARK: - Pro

    // One quiet door, for the parent who never happens to tap a locked feature
    // and so would otherwise never learn Pro exists. Deliberately a Settings
    // row and nothing else: no badge, no banner, no tab-bar dot, nothing on the
    // dashboard.
    //
    // The feature list sits open underneath rather than behind the row, so the
    // offer can be read and judged without being sold to first. The price is
    // not repeated here — it lives on the paywall, where it comes from
    // StoreKit's own localised `displayPrice`.
    private var proSection: some View {
        // Same shape as every other feature card on this screen: a titled
        // header, then content. It used to be a chevron row that opened the
        // paywall — which lists these same features — with the list repeated
        // immediately beneath it, so the same content appeared twice one tap
        // apart. The list stays (that is the point of C.2: judge the offer
        // without being sold to) and there is now one way through.
        VStack(alignment: .leading, spacing: 16) {
            fieldLabel("Sproutly Pro", systemImage: "star.fill", tint: theme.proGoldText)

            Text("One payment, yours forever.")
                .font(Theme.sproutlyBody)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ProFeatureListView()

            Theme.divider(nightMode: theme.isNightMode)

            Button {
                activeSheet = .paywall(.secondChild)
            } label: {
                HStack(spacing: 10) {
                    Text("See Sproutly Pro")
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(theme.blueText)

                    Spacer(minLength: 0)

                    chevron
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("See Sproutly Pro")
            .accessibilityHint("Opens the purchase page")
        }
        .warmCard(nightMode: theme.isNightMode)
    }

    // MARK: - Notifications

    // Default off, and the master switch is the only thing that can ask for
    // permission. Turning it on is an explicit tap — Sproutly never requests
    // authorization at launch or during onboarding.
    // Every row here is a `settingsRow`, exactly like Pro Features / App Icon /
    // About the Data directly below. That is deliberate: the previous version
    // stacked a title, a subtitle, three sub-titles, three sub-descriptions and
    // a footnote — four type sizes shrinking down the card, in a container that
    // padded itself differently from its neighbours. One row shape, one title
    // size, one footnote. The cadence and the window live in that footnote
    // rather than as a subtitle under every switch.
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Deliberately the Night Mode card's exact shape — circled icon,
            // title, one explanatory line, switch — because it is the same kind
            // of thing: one feature, on or off, with a sentence saying what it
            // does. The previous version invented a fourth card idiom for this
            // screen, with its own padding and four shrinking type sizes.
            FeatureCardHeader(
                title: "Gentle reminders",
                subtitle: "At most one a day, in the morning",
                systemImage: "bell.fill",
                nightMode: theme.isNightMode
            ) {
                SproutlySwitch(
                    isOn: Binding(
                        get: { notifications.settings.masterEnabled },
                        set: { wanted in
                            Task { await setNotifications(enabled: wanted) }
                        }
                    ),
                    nightMode: theme.isNightMode
                )
                .accessibilityLabel("Gentle reminders")
                .accessibilityHint("At most one a day, in the morning")
            }

            // Rows, not a second tier of titled toggles — the same FormRow the
            // gestational-weeks picker uses when the prematurity switch opens.
            if notifications.settings.masterEnabled {
                VStack(spacing: 0) {
                    ForEach(SproutlyNotificationKind.allCases, id: \.self) { kind in
                        Theme.divider(nightMode: theme.isNightMode)

                        FormRow(
                            label: kind.settingsTitle,
                            systemImage: kind.settingsIcon,
                            nightMode: theme.isNightMode
                        ) {
                            SproutlySwitch(
                                isOn: Binding(
                                    get: { notifications.settings.enabledKinds.contains(kind) },
                                    set: { wanted in
                                        notifications.setKind(kind, enabled: wanted)
                                        Task {
                                            await notifications.reschedule(
                                                for: childStore.activeChild
                                            )
                                        }
                                    }
                                ),
                                nightMode: theme.isNightMode
                            )
                            .accessibilityLabel(kind.settingsTitle)
                            .accessibilityHint(kind.settingsDescription)
                        }
                    }
                }
                .transition(.opacity)
            }

            Theme.divider(nightMode: theme.isNightMode)

            // D.3, once, at the same weight as every other footnote.
            Text("These are reminders to look and remember. They aren't medical guidance, and they aren't an assessment of your child.")
                .font(Theme.sproutlyMeta)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .warmCard(nightMode: theme.isNightMode)
        .animation(
            Theme.spring(0.4, reduceMotion: reduceMotion),
            value: notifications.settings.masterEnabled
        )
    }

    private func setNotifications(enabled: Bool) async {
        if enabled {
            // The switch is the request. If they decline the system prompt the
            // switch goes back off and we never ask again.
            let granted = await notifications.requestAuthorization()
            guard granted else { return }
        }
        notifications.setMasterEnabled(enabled)
        await notifications.reschedule(for: childStore.activeChild)
    }

    // MARK: - Children

    // Roster + add. The list itself is only shown once a second child exists —
    // a parent with one child sees just "Add a child".
    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                fieldLabel("Children", systemImage: "figure.2.and.child.holdinghands")

                Spacer()

                // Removing a child deletes every milestone they own. A red
                // button sitting permanently on every row put that one mistap
                // away, on a screen a parent opens for ordinary reasons, in an
                // app whose stated requirement is calm and never alarming.
                //
                // Not `.swipeActions` — that only does anything inside a `List`,
                // and this roster is a VStack in a card, so it would have
                // silently removed the only way to delete a child. Edit mode is
                // the pattern iOS uses outside lists and stays discoverable.
                if childStore.hasMultipleChildren {
                    Button(isEditingChildren ? "Done" : "Edit") {
                        withAnimation(Theme.spring(0.3, reduceMotion: reduceMotion)) {
                            isEditingChildren.toggle()
                        }
                    }
                    .font(.subheadline.weight(isEditingChildren ? .semibold : .regular))
                    .foregroundStyle(theme.blueText)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .accessibilityLabel(isEditingChildren ? "Done editing children" : "Edit children")
                }
            }

            if childStore.hasMultipleChildren {
                ForEach(childStore.children) { entry in
                    let isActive = entry.id == childStore.activeChild?.id

                    HStack(spacing: 12) {
                        if isEditingChildren {
                            Button {
                                childToDelete = entry
                                showRemoveChildAlert = true
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red.opacity(0.8))
                                    .frame(width: 28, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(entry.displayName)")
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                        }

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

                                // "Showing" rather than a bare tick. A green
                                // check sitting immediately beside a red minus
                                // put a state indicator and a destructive action
                                // in one column, where the tick reads as a second
                                // button — a word cannot be mistaken for one.
                                if isActive {
                                    Text("Showing")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(theme.greenText)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule().fill(theme.green.opacity(0.16))
                                        )
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(entry.displayName), \(entry.ageText)")
                        .accessibilityHint(isActive ? "Currently showing" : "Switch to this child")
                    }
                    .padding(.vertical, 4)
                    // Reachable without entering Edit mode, so a VoiceOver user
                    // never has to find a mode to remove a child.
                    .accessibilityAction(named: "Remove \(entry.displayName)") {
                        childToDelete = entry
                        showRemoveChildAlert = true
                    }
                }
            }

            Button {
                // The first child is free; a second is where Pro begins.
                if childStore.children.isEmpty {
                    activeSheet = .addChild
                } else {
                    Task { @MainActor in
                        activeSheet = await purchases.isUnlocked()
                            ? .addChild
                            : .paywall(.secondChild)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    // Bare `plus`, matching the "Add moment" button on
                    // Milestones. These mean the same thing — create something —
                    // and were the only pair in the app using two different
                    // glyphs for one intent; the filled circle also sat heavier
                    // than anything around it.
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.blueText)
                        .frame(width: 22)
                    Text("Add a child")
                        .font(Theme.sproutlyCardTitle)
                        .foregroundStyle(theme.text)

                    // Beside the label it belongs to, not pinned to the far
                    // edge of the card where it read as an unrelated glyph.
                    // Only from the second child on — the first is free, so a
                    // lock there would claim something untrue.
                    if !purchases.isPro && !childStore.children.isEmpty {
                        ProLockBadge()
                    }

                    Spacer(minLength: 0)
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
            VStack(alignment: .leading, spacing: 8) {
                Text("What do you call your little one?")
                    .font(Theme.sproutlyFieldLabel)
                    .foregroundStyle(theme.textSecondary)
                
                TextField(
                    "",
                    text: $profile.name,
                    prompt: Text("Name or nickname")
                        .foregroundColor(Theme.fieldPlaceholder(for: theme.isNightMode))
                )
                    .textFieldStyle(.plain)
                    .font(Theme.sproutlyFieldValue)
                    .foregroundStyle(theme.text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isProfileNameFocused)
                    .underlineField(
                        nightMode: theme.isNightMode,
                        isFocused: isProfileNameFocused
                    )
                    .accessibilityLabel("Name")
                    .onChange(of: child.name) { _, _ in
                        childStore.save()
                    }
            }
            
            // Birth date — the same labelled row as AddChildSheet. These two
            // screens edit the identical fields, so they should not present them
            // two different ways.
            FormRow(label: "Birth Date", systemImage: "calendar", nightMode: theme.isNightMode) {
                DatePicker("", selection: $profile.birthDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(theme.blueText)
                    .onChange(of: child.birthDate) { _, _ in
                        childStore.save()
                    }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Birth Date")
        }
        .warmCard(nightMode: theme.isNightMode)
    }
    
    // MARK: - Prematurity
    
    private var prematuritySection: some View {
        @Bindable var profile = child
        
        return VStack(alignment: .leading, spacing: 16) {
            fieldLabel("Adjusted for arriving early", systemImage: "sparkles")
            
            Toggle(isOn: $profile.isPremature) {
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
            .accessibilityLabel("Arrived early")
            .accessibilityHint("Adjusts milestones for premature birth")
            .onChange(of: child.isPremature) { _, _ in
                childStore.save()
            }
            
            if child.isPremature {
                VStack(spacing: 0) {
                    Theme.divider(nightMode: theme.isNightMode)

                    FormRow(
                        label: "Weeks at birth",
                        systemImage: "calendar.badge.clock",
                        nightMode: theme.isNightMode
                    ) {
                        Picker("", selection: $profile.gestationalWeeks) {
                            ForEach(24...40, id: \.self) { week in
                                Text("\(week) weeks").tag(week)
                            }
                        }
                        .labelsHidden()
                        // blueText, not blue: `blue` is a surface tint that
                        // fails contrast as text on both day backgrounds.
                        .tint(theme.blueText)
                        .onChange(of: child.gestationalWeeks) { _, _ in
                            childStore.save()
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .warmCard(nightMode: theme.isNightMode)
        .animation(Theme.spring(0.4, reduceMotion: reduceMotion), value: child.isPremature)
    }
    
    // MARK: - Grouped Rows
    //
    // These seven rows used to be seven separate floating cards, each 28pt from
    // its neighbour. That cost roughly 280pt of dead space on this screen — a
    // third of an iPhone's height — and, worse, gave rows that plainly belong
    // together ("Privacy Policy" and "Support", "Reset" and "Delete") no visual
    // relationship at all. They are now two grouped cards with hairline
    // separators, which is the shape the system's own grouped list uses.

    private func settingsRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        title: String,
        titleColor: Color,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 22)

            Text(title)
                .font(Theme.sproutlyCardTitle)
                .foregroundStyle(titleColor)

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.horizontal, Theme.cardPadding)
        // Comfortably past the 44pt minimum, and the row's whole width is the
        // tap target rather than just the label.
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.textSecondary.opacity(0.6))
    }

    // Leaves the app, so it gets the system's outward arrow rather than the
    // chevron the in-app sheets use.
    private var externalArrow: some View {
        Image(systemName: "arrow.up.right")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.textSecondary.opacity(0.6))
    }

    private var rowDivider: some View {
        Theme.divider(nightMode: theme.isNightMode)
            .padding(.leading, Theme.cardPadding + 22 + 12)
    }

    // MARK: - More

    // Pro Features only appears once Pro is owned — the durable answer to "what
    // did I buy and where do I use it," reachable any time without hunting.
    //
    // Privacy Policy and Support also live on the paywall, but that screen is
    // reach-triggered and dismisses itself the moment `isPro` flips, so a parent
    // who has already bought Pro would otherwise have no way to open the privacy
    // policy from inside the app at all. Guideline 5.1.1(i) wants it reachable
    // in-app, not only in App Store Connect.
    private var moreSection: some View {
        VStack(spacing: 0) {
            if purchases.isPro {
                Button {
                    activeSheet = .proFeatures
                } label: {
                    settingsRow(
                        icon: "star.fill",
                        iconColor: theme.proGoldText,
                        title: "Pro Features",
                        titleColor: theme.text
                    ) { chevron }
                }
                .buttonStyle(.plain)

                rowDivider
            }

            // Reach-triggered like every other gate: a free parent taps this and
            // gets the paywall naming the feature, rather than a disabled row.
            Button {
                Task { @MainActor in
                    activeSheet = await purchases.isUnlocked() ? .appIcon : .paywall(.appIcon)
                }
            } label: {
                settingsRow(
                    icon: "app.badge",
                    iconColor: theme.textSecondary,
                    title: "App Icon",
                    titleColor: theme.text
                ) {
                    HStack(spacing: 8) {
                        // The same lock as every other gated row. A "Pro"
                        // capsule here was a fifth way of saying one thing.
                        if !purchases.isPro {
                            ProLockBadge()
                        }
                        chevron
                    }
                }
            }
            .buttonStyle(.plain)

            rowDivider

            Button {
                activeSheet = .aboutData
            } label: {
                settingsRow(
                    icon: "info.circle",
                    iconColor: theme.textSecondary,
                    title: "About the Data",
                    titleColor: theme.text
                ) { chevron }
            }
            .buttonStyle(.plain)

            rowDivider

            Link(destination: AppLinks.privacyPolicy) {
                settingsRow(
                    icon: "hand.raised",
                    iconColor: theme.textSecondary,
                    title: "Privacy Policy",
                    titleColor: theme.text
                ) { externalArrow }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Privacy Policy")
            .accessibilityHint("Opens in Safari")

            rowDivider

            Link(destination: AppLinks.support) {
                settingsRow(
                    icon: "questionmark.circle",
                    iconColor: theme.textSecondary,
                    title: "Support",
                    titleColor: theme.text
                ) { externalArrow }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Support")
            .accessibilityHint("Opens in Safari")
        }
        .groupedCard(nightMode: theme.isNightMode)
    }

    // MARK: - Data Management

    private var dataSection: some View {
        VStack(spacing: 0) {
            Button {
                showResetAlert = true
            } label: {
                settingsRow(
                    icon: "arrow.counterclockwise",
                    iconColor: theme.textSecondary,
                    title: "Reset Milestone Progress",
                    titleColor: theme.text
                ) { EmptyView() }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset Milestone Progress")
            .accessibilityHint("Clears everything saved for this child, keeps their profile")

            rowDivider

            Button {
                showDeleteAlert = true
            } label: {
                settingsRow(
                    icon: "trash",
                    iconColor: .red.opacity(0.7),
                    title: "Delete All Data",
                    titleColor: .red.opacity(0.7)
                ) { EmptyView() }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete All Data")
            .accessibilityHint("Removes all data and returns to welcome screen")
        }
        .groupedCard(nightMode: theme.isNightMode)
    }

    
    // MARK: - Actions
    
    // Scoped to the active child only — a sibling's progress is never touched.
    private func resetProgress() {
        guard let active = childStore.activeChild else { return }
        for milestone in active.milestones {
            milestone.isCompleted = false
            milestone.dateCompleted = nil
            milestone.completionNote = ""
            // The single-milestone "Remove" path already does this. Without it here,
            // resetting progress leaves the image on disk with nothing referencing
            // it, and the row still claiming a photo it no longer shows.
            PhotoStore.delete(milestone.photoFilename)
            milestone.photoFilename = nil
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

#if DEBUG
#Preview {
    SettingsView()
        .environment(previewChildStore)
        .environment(PurchaseManager())
        .environment(ThemeManager())
        .modelContainer(previewContainer)
}
#endif
