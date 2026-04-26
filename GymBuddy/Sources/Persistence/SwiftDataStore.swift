import Foundation

#if canImport(SwiftData)
import SwiftData

/// SwiftData-backed persistence. The production app composes these with the
/// repository protocols in `Repositories.swift`. SwiftData is only imported here;
/// CoachingEngine never sees a SwiftData type.
///
/// Migration strategy (ADR-0001): each schema version lives in a separate file
/// under `Schemas/`; `SchemaMigrationPlan` wires them together in chronological
/// order. Zero-downtime migrations are the bar. Never ship a destructive
/// migration without an explicit user-consent flow.

// MARK: - Schema V1
@available(iOS 17.0, macOS 14.0, *)
public enum GymBuddySchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [
            StoredUserProfile.self,
            StoredPlan.self,
            StoredWorkoutSession.self,
            StoredCoachMemoryNote.self,
            StoredReadinessCheck.self
        ]
    }

    @Model
    public final class StoredUserProfile {
        @Attribute(.unique) public var id: UUID
        public var payload: Data
        public var updatedAt: Date

        public init(id: UUID, payload: Data, updatedAt: Date) {
            self.id = id
            self.payload = payload
            self.updatedAt = updatedAt
        }
    }

    @Model
    public final class StoredPlan {
        @Attribute(.unique) public var id: UUID
        public var createdAt: Date
        public var payload: Data
        public var isActive: Bool

        public init(id: UUID, createdAt: Date, payload: Data, isActive: Bool) {
            self.id = id
            self.createdAt = createdAt
            self.payload = payload
            self.isActive = isActive
        }
    }

    @Model
    public final class StoredWorkoutSession {
        @Attribute(.unique) public var id: UUID
        public var startedAt: Date
        public var endedAt: Date
        public var payload: Data

        public init(id: UUID, startedAt: Date, endedAt: Date, payload: Data) {
            self.id = id
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.payload = payload
        }
    }

    @Model
    public final class StoredCoachMemoryNote {
        @Attribute(.unique) public var id: UUID
        public var content: String
        public var tagsCSV: String
        public var createdAt: Date

        public init(id: UUID, content: String, tagsCSV: String, createdAt: Date) {
            self.id = id
            self.content = content
            self.tagsCSV = tagsCSV
            self.createdAt = createdAt
        }
    }

    @Model
    public final class StoredReadinessCheck {
        @Attribute(.unique) public var id: UUID
        public var date: Date
        public var payload: Data

        public init(id: UUID, date: Date, payload: Data) {
            self.id = id
            self.date = date
            self.payload = payload
        }
    }
}

// MARK: - Migration plan

@available(iOS 17.0, macOS 14.0, *)
public enum GymBuddyMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [GymBuddySchemaV1.self]
    }
    public static var stages: [MigrationStage] {
        []
    }
}

// MARK: - Store factory

@available(iOS 17.0, macOS 14.0, *)
public enum GymBuddyStore {
    /// Create a container for production.
    public static func productionContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: GymBuddySchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, migrationPlan: GymBuddyMigrationPlan.self, configurations: configuration)
    }

    /// Create an in-memory container for previews and integration tests.
    public static func inMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: GymBuddySchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, migrationPlan: GymBuddyMigrationPlan.self, configurations: configuration)
    }
}

#endif
