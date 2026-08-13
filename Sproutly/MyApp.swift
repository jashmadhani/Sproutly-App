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
    do {
        let schema = Schema(versionedSchema: SproutlySchemaV1.self)
        let config = ModelConfiguration("SproutlyDB", schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, migrationPlan: SproutlyMigrationPlan.self, configurations: [config])

        DataSeeder.seedIfNeeded(modelContext: container.mainContext)

        return container
    } catch {
        fatalError("Failed to build app container: \(error)")
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
