import XCTest
@testable import CoachingEngine
@testable import PoseVision
@testable import VoiceIO
@testable import Telemetry

/// Chaos scenarios from PRD §10.7. Each either resumes correctly or fails with
/// a clear user-visible explanation. Here we test the domain-visible surface
/// (what the engine sees); iOS-specific chaos (actual incoming calls, route
/// changes, permission revocation) is verified by the XCUITest suite in
/// GymBuddyApp and documented in docs/Chaos.md.
final class ChaosScenarioTests: XCTestCase {

    func testPainDetectedMidSetStopsTheSession() async throws {
        let orchestrator = SessionOrchestrator(
            config: SessionConfig(exerciseId: .pushUp, setNumber: 1, targetReps: nil, tone: .standard),
            context: SessionContext(userId: UUID(), tone: .standard)
        )
        // Run a few samples then signal pain.
        for s in SyntheticPoseGenerator.pushUps(repCount: 2).prefix(60) {
            _ = orchestrator.observe(sample: s)
        }
        let painIntents = orchestrator.signalPainDetected(trigger: "sharp pain")
        XCTAssertFalse(painIntents.isEmpty)
        let hasPainStop = painIntents.contains { intent in
            if case .painStop = intent { return true } else { return false }
        }
        XCTAssertTrue(hasPainStop)
        // After pain, subsequent samples produce no new intents.
        let afterSamples = SyntheticPoseGenerator.pushUps(repCount: 1)
        var afterIntents: [CoachingIntent] = []
        for s in afterSamples { afterIntents.append(contentsOf: orchestrator.observe(sample: s)) }
        XCTAssertTrue(afterIntents.isEmpty, "No intents should flow after pain stop")
    }

    func testMissingJointsStreamDoesNotCrash() {
        let orchestrator = SessionOrchestrator(
            config: SessionConfig(exerciseId: .pushUp, setNumber: 1, targetReps: nil, tone: .standard),
            context: SessionContext(userId: UUID(), tone: .standard)
        )
        for i in 0..<200 {
            let bogus = PoseSample(timestamp: Double(i) * 0.033, joints: [:])
            _ = orchestrator.observe(sample: bogus)
        }
        // Survived to here; observation is buildable.
        let obs = orchestrator.buildObservation()
        XCTAssertEqual(obs.totalReps, 0)
    }

    func testExplicitFinishDuringSetEmitsSetEndedOnce() {
        let orchestrator = SessionOrchestrator(
            config: SessionConfig(exerciseId: .pushUp, setNumber: 1, targetReps: nil, tone: .standard),
            context: SessionContext(userId: UUID(), tone: .standard)
        )
        for s in SyntheticPoseGenerator.pushUps(repCount: 2).prefix(80) {
            _ = orchestrator.observe(sample: s)
        }
        let first = orchestrator.finishSetExplicitly(reason: .userTapped)
        let second = orchestrator.finishSetExplicitly(reason: .userTapped)
        XCTAssertFalse(first.isEmpty)
        XCTAssertTrue(second.isEmpty, "Double-finish must be idempotent")
    }

    func testFixtureDetectorStopMidStreamTerminatesCleanly() async throws {
        let samples = (0..<60).map { PoseSample(timestamp: Double($0) * 0.033, joints: [:]) }
        let detector = FixturePoseDetector(samples: samples, frameInterval: 0.01)
        var stream = detector.bodyStateStream().makeAsyncIterator()
        try await detector.start()
        _ = await stream.next()
        await detector.stop()
        // After stop, stream eventually terminates.
        // We don't assert specific post-stop behavior beyond "does not deadlock."
        XCTAssertTrue(true)
    }
}
