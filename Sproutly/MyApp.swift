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
    let schema = Schema(versionedSchema: SproutlySchemaV1.self)

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

    do {
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SproutlyMigrationPlan.self,
            configurations: [config]
        )
        DataSeeder.seedIfNeeded(modelContext: container.mainContext)
        return container
    } catch {
        // Never black-screen a parent who just opened the app. If the on-disk store is
        // unusable, fall back to an in-memory one so the UI still runs this session.
        print("⚠️ Sproutly: on-disk store unavailable, using in-memory — \(error)")

        let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [fallback]) else {
            fatalError("Failed to build even an in-memory container: \(error)")
        }
        DataSeeder.seedIfNeeded(modelContext: container.mainContext)
        return container
    }
}()

// MARK: - App Entry Point

@main
struct MyApp: App {
    @State private var childProfile = ChildProfile.load()
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(childProfile)
                .environment(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
        }
        .modelContainer(sharedAppContainer)
    }
}

// MARK: - Root View

struct ContentView: View {
    @Environment(ChildProfile.self) private var childProfile
    @Environment(ThemeManager.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @State private var hasSeeded = false
    
    var body: some View {
        Group {
            if !childProfile.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .transaction { $0.animation = nil }
        .task {
            guard !hasSeeded else { return }
            hasSeeded = true
            DataSeeder.seedIfNeeded(modelContext: modelContext)
        }
    }
}
