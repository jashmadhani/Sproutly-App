//
//  MyApp.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/02/26.
//

import SwiftUI
import SwiftData

// MARK: - Shared Container
// seed before first render so @Query gets data on initial render

@MainActor
let sharedAppContainer: ModelContainer = {
    let schema = Schema(versionedSchema: SproutlyCurrentSchema.self)

    // A named ModelConfiguration resolves to Library/Application Support/SproutlyDB.store,
    // but that directory does not exist in a freshly installed container and SwiftData
    // will not create it. Without this, the very first launch throws and the app dies
    // before rendering anything — a black screen.
    if let appSupport = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true
        )
    }

    let config = ModelConfiguration("SproutlyDB", schema: schema, isStoredInMemoryOnly: false)

    // 1. Normal path.
    do {
        return try ModelContainer(
            for: schema,
            migrationPlan: SproutlyMigrationPlan.self,
            configurations: [config]
        )
    } catch {
        // Deliberately not `try?`. Archiving is destructive from the parent's point
        // of view — every milestone, note, and photo disappears and they land back
        // in onboarding — so the reason is recorded rather than swallowed. The
        // overwhelmingly likely cause is a model change shipped without a matching
        // migration stage (SproutlyMigrationPlan.stages is still empty), which is a
        // build-time mistake, not a parent's corrupted disk.
        StoreRecovery.lastOpenFailure = String(describing: error)
        sproutlyLog("store could not be opened — \(error)")
    }

    // 2. The store exists but cannot be opened — an incompatible pre-release store,
    //    or corruption. Move it aside rather than deleting it, so the data is still
    //    recoverable, and start clean instead of crash-looping on every launch.
    sproutlyLog("archiving the unreadable store and starting fresh")
    archiveExistingStore()

    do {
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SproutlyMigrationPlan.self,
            configurations: [config]
        )
        // Only now is the loss real: a fresh store opened over an archived one.
        // ContentView surfaces this once so the parent isn't left silently
        // wondering where everything went.
        StoreRecovery.didArchiveStore = true
        return container
    } catch {
        sproutlyLog("fresh store also failed to open — \(error)")
    }

    // 3. Disk is unusable entirely. Run in memory for this session rather than
    //    black-screening a parent who just opened the app.
    sproutlyLog("on-disk store unavailable, using in-memory for this session")
    let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    guard let container = try? ModelContainer(for: schema, configurations: [fallback]) else {
        fatalError("Failed to build even an in-memory container")
    }
    return container
}()

// Records that the on-disk store had to be replaced, so the UI can say so once
// instead of the parent silently losing everything and landing in onboarding.
enum StoreRecovery {
    nonisolated(unsafe) static var didArchiveStore = false
    nonisolated(unsafe) static var lastOpenFailure: String?

    static let didShowNoticeKey = "sproutly_did_show_store_recovery_notice"
}

// Renames SproutlyDB.store (and its -shm/-wal siblings) with a timestamp suffix,
// and moves the photo folder aside with them so a recovered store still lines up
// with the images its rows reference.
private func archiveExistingStore() {
    let fileManager = FileManager.default
    guard let appSupport = fileManager
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

    let stamp = Int(Date().timeIntervalSince1970)
    for suffix in ["store", "store-shm", "store-wal"] {
        let source = appSupport.appendingPathComponent("SproutlyDB.\(suffix)")
        guard fileManager.fileExists(atPath: source.path) else { continue }

        let destination = appSupport
            .appendingPathComponent("SproutlyDB-backup-\(stamp).\(suffix)")
        try? fileManager.moveItem(at: source, to: destination)
    }

    // Photos are referenced only by filename from the archived rows. Left in place
    // they would be orphaned forever — no row points at them and nothing ever
    // cleans them up. Moved alongside, the pair stays internally consistent.
    let photos = appSupport.appendingPathComponent("MilestonePhotos", isDirectory: true)
    if fileManager.fileExists(atPath: photos.path) {
        let destination = appSupport
            .appendingPathComponent("MilestonePhotos-backup-\(stamp)", isDirectory: true)
        try? fileManager.moveItem(at: photos, to: destination)
    }

    pruneOldArchives(in: appSupport)
}

// Archives are a safety net, not a history. Without a cap, a device that fails to
// open the store on every launch accumulates a full copy of the database and photo
// library each time until it runs out of space.
private func pruneOldArchives(in directory: URL) {
    let fileManager = FileManager.default
    // Deliberately prefetches no resource keys. Asking for .creationDateKey put
    // the app in Apple's File Timestamp "required reason API" category, which
    // PrivacyInfo.xcprivacy would then have to declare — and nothing here ever
    // read the value, since pruning sorts on the timestamp baked into the
    // filename rather than on the file's own creation date.
    guard let entries = try? fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    ) else { return }

    // Group by the timestamp embedded in the name so a store and its photo folder
    // are pruned together.
    let stamps = Set(entries.compactMap { url -> Int? in
        let name = url.lastPathComponent
        guard name.hasPrefix("SproutlyDB-backup-") || name.hasPrefix("MilestonePhotos-backup-") else {
            return nil
        }
        let digits = name
            .replacingOccurrences(of: "SproutlyDB-backup-", with: "")
            .replacingOccurrences(of: "MilestonePhotos-backup-", with: "")
            .prefix { $0.isNumber }
        return Int(digits)
    })

    // Keep the two most recent generations; older ones are past any realistic
    // chance of being recovered by hand.
    let doomed = stamps.sorted(by: >).dropFirst(2)
    for stamp in doomed {
        for entry in entries where entry.lastPathComponent.contains("-backup-\(stamp)") {
            try? fileManager.removeItem(at: entry)
        }
    }
}

// MARK: - App Entry Point

@main
@MainActor
struct MyApp: App {
    @State private var childStore = ChildStore(context: sharedAppContainer.mainContext)
    @State private var themeManager = ThemeManager()
    @State private var purchases = PurchaseManager()

    init() {
        _ = SproutlyFont.didRegister
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(childStore)
                .environment(themeManager)
                .environment(purchases)
                .preferredColorScheme(themeManager.preferredColorScheme)
        }
        .modelContainer(sharedAppContainer)
    }
}

// MARK: - Root View

struct ContentView: View {
    @Environment(ChildStore.self) private var childStore
    @Environment(ThemeManager.self) private var theme
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.scenePhase) private var scenePhase
    // Read here and mirrored onto ThemeManager so the whole app resolves one
    // set of colours, rather than each view reading the environment and
    // deciding for itself. See ThemeManager's "Accessibility State".
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var hasImported = false
    @State private var showStoreRecoveryNotice = false

    var body: some View {
        Group {
            if childStore.needsOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .transaction { $0.animation = nil }
        .onAppear { syncAccessibilityState() }
        .onChange(of: colorSchemeContrast) { _, _ in syncAccessibilityState() }
        .onChange(of: reduceTransparency) { _, _ in syncAccessibilityState() }
        // Shown at most once per archive event. A parent who opens the app to find
        // it empty deserves an explanation and the knowledge that a copy still
        // exists, rather than concluding the app threw their child's history away.
        .alert("Starting Fresh", isPresented: $showStoreRecoveryNotice) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Sproutly couldn't open its saved data on this device, so it started a new library. A backup copy of the old one is kept on this device — please reach out before reinstalling if you'd like help recovering it.")
        }
        .task {
            guard !hasImported else { return }
            hasImported = true

            // The flag is set during container construction, before any view exists,
            // so it is read here rather than observed.
            if StoreRecovery.didArchiveStore,
               !UserDefaults.standard.bool(forKey: StoreRecovery.didShowNoticeKey) {
                UserDefaults.standard.set(true, forKey: StoreRecovery.didShowNoticeKey)
                showStoreRecoveryNotice = true
            }

            // Adopts any pre-multi-child data into a real Child.
            childStore.importLegacyProfileIfNeeded()

            // Silent restore: the second parent on Family Sharing, or anyone who
            // reinstalled, must never be shown a paywall for something already owned.
            await purchases.start()
        }
        // CLAUDE.md's own stated intent is "re-checked every launch" — but a
        // resume from background isn't a launch, and isPro was only ever set
        // at the initial .task above or after a transaction event. Re-checking
        // on every foreground transition closes that gap defensively.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, hasImported else { return }
            Task { await purchases.refreshEntitlements() }
        }
    }

    /// Guarded so an unchanged value doesn't publish an @Observable mutation
    /// and invalidate every view for nothing.
    private func syncAccessibilityState() {
        let increased = colorSchemeContrast == .increased
        if theme.increaseContrast != increased { theme.increaseContrast = increased }
        if theme.reduceTransparency != reduceTransparency {
            theme.reduceTransparency = reduceTransparency
        }
    }
}
