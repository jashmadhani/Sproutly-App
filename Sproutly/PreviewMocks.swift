import SwiftData
import SwiftUI

@MainActor
public let previewContainer: ModelContainer = {
    do {
        let schema = Schema([Milestone.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        // in-memory container for previews — seed before any view renders
        let all = DataSeeder.allMilestones
        for m in all { container.mainContext.insert(m) }
        try container.mainContext.save()

        return container
    } catch {
        fatalError("Failed to build preview container: \(error)")
    }
}()
