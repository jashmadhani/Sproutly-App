//
//  SproutlySchema.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/08/26.
//

import Foundation
import SwiftData

enum SproutlySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Milestone.self]
    }
}

enum SproutlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SproutlySchemaV1.self]
    }
    
    static var stages: [MigrationStage] {
        // No stages yet, as we are on V1
        []
    }
}
