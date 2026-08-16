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
    if let container = try? ModelContainer(
        for: schema,
        migrationPlan: SproutlyMigrationPlan.self,
        configurations: [config]
    ) {
        return container
    }

    // 2. The store exists but cannot be opened — an incompatible pre-release store,
    //    or corruption. Move it aside rather than deleting it, so the data is still
    //    recoverable, and start clean instead of crash-looping on every launch.
    print("⚠️ Sproutly: store unreadable, archiving it and starting fresh")
    archiveExistingStore()

    if let container = try? ModelContainer(
        for: schema,
        migrationPlan: SproutlyMigrationPlan.self,
        configurations: [config]
    ) {
        return container
    }

    // 3. Disk is unusable entirely. Run in memory for this session rather than
    //    black-screening a parent who just opened the app.
    print("⚠️ Sproutly: on-disk store unavailable, using in-memory for this session")
    let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    guard let container = try? ModelContainer(for: schema, configurations: [fallback]) else {
        fatalError("Failed to build even an in-memory container")
    }
    return container
}()

// Renames SproutlyDB.store (and its -shm/-wal siblings) with a timestamp suffix.
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
    @State private var hasImported = false

    var body: some View {
        Group {
            if childStore.needsOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .transaction { $0.animation = nil }
        .task {
            guard !hasImported else { return }
            hasImported = true
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
}
