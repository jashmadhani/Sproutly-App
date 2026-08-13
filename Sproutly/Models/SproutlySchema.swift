//
//  SproutlySchema.swift
//  Sproutly
//

import Foundation
import SwiftData

// MARK: - Current Schema

// Children own their milestones. This is the first schema to reach the App Store —
// the earlier Playgrounds-only shape was never released, so there is no shipped
// store to migrate from. Pre-release stores are handled by recovery in MyApp and
// by ChildStore.importLegacyProfileIfNeeded().
//
// When a future version changes the model, freeze a copy of the *current* models
// inside a SproutlySchemaV2 enum and add a stage below — never re-point an old
// VersionedSchema at edited model classes, which silently breaks migration.
enum SproutlySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Child.self, Milestone.self]
    }
}

typealias SproutlyCurrentSchema = SproutlySchemaV1

// MARK: - Migration

enum SproutlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SproutlySchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
