import XCTest
@testable import CoachingEngine
@testable import PoseVision
@testable import VoiceIO
@testable import Persistence

/// Exercises the full in-memory session pipeline without the iOS view layer.
/// This is the unit-level guard that prevents regressions in the live-session
/// code path: if any of these break, the iOS LiveSession UI will also break.
final class SessionPipelineTests: XCTestCase {

    /// A fixture-driven set running through the orchestrator end-to-end:
    /// correct rep count, tempo baseline established, set-end emitted, and a
    /// record is persisted.
    func testFixtureDrivenSetProducesObservationAndRecord() async throws {
        let samples = SyntheticPoseGenerator.pushUps(
            repCount: 10,
            baselineCycleSeconds: 1.5,
            fatigueRamp: (startRep: 7, endRep: 10, multiplier: 1.6)
        )
        let orchestrator = makeOrchestrator()
        let intents = drive(orchestrator, with: samples)

        assertReps1Through10(in: intents)
        assertOneMoreFires(in: intents)
        assertSetEndedAndDiagFires(samples: samples, intents: intents)

        try await assertObservationPersists(orchestrator: orchestrator)
    }

    private func makeOrchestrator() -> SessionOrchestrator {
        let config = SessionConfig(exerciseId: .pushUp, setNumber: 1, targetReps: nil, tone: .standard)
        let context = SessionContext(userId: UUID(), tone: .standard)
        return SessionOrchestrator(config: config, context: context)
    }

    private func drive(_ orchestrator: SessionOrchestrator, with samples: [PoseSample]) -> [CoachingIntent] {
        var intents: [CoachingIntent] = []
        for sample in samples {
            intents.append(contentsOf: orchestrator.observe(sample: sample))
        }
        return intents
    }

    private func assertReps1Through10(in intents: [CoachingIntent]) {
        let repCounts = intents.compactMap { intent -> Int? in
            if case .sayRepCount(let n, _) = intent { return n }
            return nil
        }
        XCTAssertEqual(repCounts, Array(1...10))
    }

    private func assertOneMoreFires(in intents: [CoachingIntent]) {
        let kinds = intents.compactMap { intent -> CoachingIntent.EncouragementKind? in
            if case .encouragement(let kind, _, _) = intent { return kind }
            return nil
        }
        XCTAssertTrue(kinds.contains(.oneMore), "Expected 'one more' during fatigue")
    }

    /// Independently re-runs SetEndDetector on the same samples to localize a
    /// failure if the orchestrator-routed setEnded intent is missing.
    private func assertSetEndedAndDiagFires(samples: [PoseSample], intents: [CoachingIntent]) {
        let diagSetEnd = SetEndDetector(exerciseId: .pushUp)
        let diagRep = RepDetectorFactory.make(for: .pushUp)
        var diagFired = false
        for sample in samples {
            if diagRep.observe(sample) != nil { diagSetEnd.noteRepCompleted() }
            if diagSetEnd.observe(sample) != nil {
                diagFired = true
                break
            }
        }
        XCTAssertTrue(diagFired, "Fixture's stillness tail should trigger SetEndDetector on its own")
        XCTAssertTrue(
            intents.contains { intent in
                if case .setEnded = intent { return true }
                return false
            },
            "Orchestrator should emit setEnded. Diag independent detector fired: \(diagFired)"
        )
    }

    private func assertObservationPersists(orchestrator: SessionOrchestrator) async throws {
        let observation = orchestrator.buildObservation()
        XCTAssertEqual(observation.totalReps, 10)
        XCTAssertNotNil(observation.tempoBaselineMs)
        XCTAssertNotNil(observation.fatigueSlowdownAtRep)

        let repo = InMemorySessionRepository()
        let record = WorkoutSessionRecord.build(
            from: [observation],
            painFlag: false,
            summary: "test"
        )
        try await repo.record(record)
        let recent = try await repo.recent(limit: 10)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.performedExercises.first?.performedSets.first?.reps, 10)

        let best = try await repo.bestReps(for: .pushUp)
        XCTAssertEqual(best, 10)
    }

    /// Stream-driven variant: feeds samples through a FixturePoseDetector, the
    /// same way LiveSessionViewModel does on-device. Proves the detector →
    /// orchestrator wiring works in the async-stream model.
    func testFixtureDetectorFeedsOrchestratorOverStream() async throws {
        let samples = SyntheticPoseGenerator.pushUps(
            repCount: 5,
            baselineCycleSeconds: 1.0
        )
        let detector = FixturePoseDetector(samples: samples, frameInterval: 0)
        let stream = detector.bodyStateStream()
        try await detector.start()

        let config = SessionConfig(exerciseId: .pushUp, setNumber: 1, targetReps: nil, tone: .standard)
        let context = SessionContext(userId: UUID(), tone: .standard)
        let orchestrator = SessionOrchestrator(config: config, context: context)

        var repCounts: [Int] = []
        for await state in stream {
            guard case .pose(let sample) = state else { continue }
            for intent in orchestrator.observe(sample: sample) {
                if case .sayRepCount(let n, _) = intent {
                    repCounts.append(n)
                }
            }
        }

        XCTAssertEqual(repCounts, [1, 2, 3, 4, 5])
    }

    /// Regression guard for the start-before-subscribe race in FixturePoseDetector.
    /// Callers that call `start()` before `bodyStateStream()` must still get
    /// every sample (what the app's LiveSessionViewModel does in practice).
    func testStartBeforeSubscribeStillDelivers() async throws {
        let samples = (0..<5).map { i in
            PoseSample(timestamp: TimeInterval(i), joints: [:])
        }
        let detector = FixturePoseDetector(samples: samples, frameInterval: 0)
        try await detector.start()
        let stream = detector.bodyStateStream()

        var received: [BodyState] = []
        for await state in stream {
            received.append(state)
        }
        XCTAssertEqual(received.count, 5)
    }
}
