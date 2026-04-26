import XCTest
@testable import CoachingEngine
@testable import PoseVision
@testable import LLMClient
@testable import Persistence

/// Covers the pain-stop and content-safety flows end-to-end at the domain
/// level. iOS UI tests verify the visual rendering; these tests verify the
/// behavior the view model relies on.
final class PainAndSafetyFlowTests: XCTestCase {

    /// A pain phrase in STT triggers a `SafetyAction.stopSet` via the pain detector,
    /// and the orchestrator emits a painStop intent + observation flag.
    func testPainKeywordTriggersSafeSessionEnd() async throws {
        let orchestrator = SessionOrchestrator(
            config: SessionConfig(exerciseId: .pushUp, setNumber: 1, targetReps: nil, tone: .standard),
            context: SessionContext(userId: UUID(), tone: .standard)
        )

        // Feed a few samples so there's an active session.
        let samples = SyntheticPoseGenerator.pushUps(repCount: 2).prefix(40)
        for s in samples { _ = orchestrator.observe(sample: s) }

        // User utterance is flagged as pain.
        let detector = PainDetector()
        XCTAssertEqual(detector.detect(in: "I felt a sharp pain in my shoulder"), "sharp pain")

        // Orchestrator stops the set in response.
        let intents = orchestrator.signalPainDetected(trigger: "sharp pain")
        XCTAssertTrue(intents.contains { intent in
            if case .painStop = intent { return true } else { return false }
        })

        // Further samples are ignored.
        let afterIntents = SyntheticPoseGenerator.pushUps(repCount: 1)
            .flatMap { orchestrator.observe(sample: $0) }
        XCTAssertTrue(afterIntents.isEmpty)

        // Observation carries the pain flag.
        let obs = orchestrator.buildObservation()
        XCTAssertEqual(obs.endEvent.reason, .painPause)

        // Persistence accepts the pain-flagged record.
        let record = WorkoutSessionRecord.build(from: [obs], painFlag: true, summary: nil)
        XCTAssertTrue(record.painFlag)
    }

    /// A malicious / drifting LLM response that tries to diagnose is caught by
    /// the SafeLLMClient and replaced with a safe-response marker. Downstream
    /// (PostSessionSummaryView) renders the specific-numeric fallback.
    func testSafetySubstitutionProducesFallbackText() async throws {
        let mock = MockLLMClient()
        mock.setScript(.fixed("It sounds like a rotator cuff tear."), for: PromptRegistry.postSetSummaryId)
        var substituted: SafetyCategory?
        let safe = SafeLLMClient(inner: mock, onSubstitution: { substituted = $0 })

        let obs = SessionObservation(
            exerciseId: .pushUp, setNumber: 1,
            repEvents: (1...10).map { n in
                RepEvent(exerciseId: .pushUp, repNumber: n,
                         startedAt: Double(n), endedAt: Double(n) + 1,
                         concentricDuration: 1, eccentricDuration: 0.5,
                         rangeOfMotionScore: 0.9, isPartial: false)
            },
            cueEvents: [],
            endEvent: SetEndEvent(
                exerciseId: .pushUp, setNumber: 1, reason: .autoDetectedStill,
                timestamp: 20, totalReps: 10, partialReps: 0
            ),
            tempoBaselineMs: 1000, fatigueSlowdownAtRep: nil,
            priorSessionBestReps: nil, memoryReferences: []
        )
        let rendered = PromptRegistry.renderPostSetSummary(observation: obs, tone: .standard)
        let response = try await safe.complete(request: LLMRequest(
            promptId: rendered.id, promptVersion: rendered.version,
            system: rendered.system, user: rendered.user
        ))

        XCTAssertEqual(substituted, .diagnosis)
        XCTAssertTrue(response.text.hasPrefix("safe:"))

        // Downstream fallback is deterministic, specific, never generic.
        let fallback = SessionSummaryFallback.summary(for: obs)
        XCTAssertTrue(fallback.contains("10"))
        XCTAssertTrue(fallback.contains("Push-up"))
        XCTAssertFalse(fallback.lowercased().contains("good job"))
    }
}
