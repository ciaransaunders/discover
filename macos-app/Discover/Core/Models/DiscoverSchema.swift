import Foundation
import SwiftData

// MARK: - Versioned schema + explicit migration plan
//
// The owner chose an explicit `VersionedSchema` / `SchemaMigrationPlan` rather than relying on
// implicit lightweight migration. Every v1 → v2 change is **additive**:
//   • ArticleModel.content  (String?, new optional)
//   • ArticleModel.isStarred (Bool, defaulted false)
//   • FeedModel.createdAt   (Date?,  new optional)
//   • FolderModel           (new @Model type)
// Nothing is dropped, renamed, or retyped, so the migration stage is `.lightweight`.
//
// Historical-fidelity note: because all changes so far are additive/lightweight, v1 references the
// live model types rather than frozen snapshots — sufficient for lightweight migration, which
// reconciles the on-disk store against the current models. The *next* non-additive change
// (rename / retype / data transform) must add a `DiscoverSchemaV3` whose models are namespaced
// snapshots of the v2 shape plus a `.custom` stage — do NOT mutate v1/v2 in place.

enum DiscoverSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [ArticleModel.self, FeedModel.self, CategoryModel.self]
    }
}

enum DiscoverSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [ArticleModel.self, FeedModel.self, CategoryModel.self, FolderModel.self]
    }
}

/// The latest schema the app builds its container from.
typealias DiscoverCurrentSchema = DiscoverSchemaV2

enum DiscoverMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [DiscoverSchemaV1.self, DiscoverSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: DiscoverSchemaV1.self, toVersion: DiscoverSchemaV2.self)]
    }
}
