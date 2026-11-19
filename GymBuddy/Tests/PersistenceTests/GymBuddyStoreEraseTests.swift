#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import CoachingEngine
@testable import Persistence

/// `eraseAll` is how a debug build starts UI tests from an empty store, the
/// same state as a fresh install, so no test sees an earlier test's sessions.
@available(iOS 17.0, macOS 14.0, *)
final class GymBuddyStoreEraseTests: XCTestCase {

    func testEraseAllRemovesProfileAndSessions() async throws {
        let container = try GymBuddyStore.inMemoryContainer()
        let profiles = SwiftDataUserProfileRepository(container: container)
        let sessions = SwiftDataSessionRepository(container: container)
        try await profiles.save(UserProfile(
            displayName: "QA", tone: .standard,
            experience: .intermediate, goal: .hypertrophy,
            equipment: .dumbbells, sessionsPerWeek: 3
        ))
        try await sessions.record(WorkoutSessionRecord(
            startedAt: Date(), endedAt: Date(), performedExercises: []
        ))

        try GymBuddyStore.eraseAll(in: container)

        let profile = try await profiles.load()
        let recent = try await sessions.recent(limit: 10)
        XCTAssertNil(profile)
        XCTAssertEqual(recent.count, 0)
    }
}
#endif
