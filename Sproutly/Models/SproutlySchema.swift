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

    // GrowthMeasurement joined V1 before the first TestFlight build, which is the
    // last moment V1 can change for free. Once a tester has a V1 store on their
    // phone, editing this list makes the recovery path archive their data. Any
    // model added after that goes into a SproutlySchemaV2 with a migration stage.
    static var models: [any PersistentModel.Type] {
        [Child.self, Milestone.self, GrowthMeasurement.self]
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
