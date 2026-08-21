//
//  PreviewMocks.swift
//  Sproutly
//
//  Mock data for SwiftUI previews only. Gated so the seeded "Aanya" child and
//  its in-memory container are never compiled into a shipping binary — nothing
//  at runtime references them, but a release build has no reason to carry them.
//

#if DEBUG
import SwiftData
import SwiftUI

@MainActor
public let previewContainer: ModelContainer = {
    do {
        let schema = Schema(versionedSchema: SproutlyCurrentSchema.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        // in-memory container for previews — seed before any view renders
        let child = Child(name: "Aanya", birthDate: .now.addingTimeInterval(-60 * 60 * 24 * 400))
        container.mainContext.insert(child)
        DataSeeder.seed(for: child, in: container.mainContext)

        return container
    } catch {
        fatalError("Failed to build preview container: \(error)")
    }
}()

// Store backed by the preview container, for views that need the environment.
@MainActor
let previewChildStore = ChildStore(context: previewContainer.mainContext)

#endif
