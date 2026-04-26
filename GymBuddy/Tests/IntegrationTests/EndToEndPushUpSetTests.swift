import XCTest
@testable import CoachingEngine
@testable import PoseVision
@testable import VoiceIO
@testable import LLMClient
@testable import Persistence
@testable import Telemetry

/// Full pipeline: synthetic push-up pose stream → PoseVision FixtureDetector →
/// CoachingEngine SessionOrchestrator → IntentToVoiceMapper → MockVoicePlayer +
/// LLM summary via MockLLMClient + persist via InMemorySessionRepository.
final class EndToEndPushUpSetTests: XCTestCase {

    func testFullPipelineCountsReps_PlaysPhrases_PersistsSession() async throws {
        let samples = SyntheticPoseGenerator.pushUps(
            repCount: 10,
            baselineCycleSeconds: 1.6
        )

        let config = SessionConfig(exerciseId: .pushUp, setNumber: 1, targetReps: nil, tone: .standard)
        let context = SessionContext(userId: UUID(), tone: .standard)
        let orchestrator = SessionOrchestrator(config: config, context: context)

        let player = MockVoicePlayer()
        let repVariants: [PhraseID: [PhraseCache.Variant]] = Dictionary(
            uniqueKeysWithValues: (1...50).map {
                (PhraseID(kind: .repCount, tone: .standard, number: $0),
                 [PhraseCache.Variant(index: 0, assetName: "r\($0)")])
            }
        )
        let encourageVariants: [PhraseID: [PhraseCache.Variant]] = [
            PhraseID(kind: .encourageOneMore, tone: .standard): [PhraseCache.Variant(index: 0, assetName: "om")],
            PhraseID(kind: .encouragePush, tone: .standard): [PhraseCache.Variant(index: 0, assetName: "push")],
            PhraseID(kind: .encourageLastOne, tone: .standard): [PhraseCache.Variant(index: 0, assetName: "last")],
            PhraseID(kind: .encourageDrive, tone: .standard): [PhraseCache.Variant(index: 0, assetName: "drive")],
            PhraseID(kind: .safetyPainStop, tone: .standard): [PhraseCache.Variant(index: 0, assetName: "pain")]
        ]
        let cache = PhraseCache(variants: repVariants.merging(encourageVariants) { a, _ in a })
        let mapper = IntentToVoiceMapper(tone: .standard, cache: cache, voice: player)

        for sample in samples {
            let intents = orchestrator.observe(sample: sample)
            for intent in intents {
                _ = try? await mapper.route(intent)
            }
        }

        let hist = await player.cachedHistory()
        // At least some rep-count phrases should have been played.
        let repCountPlays = hist.filter { $0.kind == .repCount }.count
        XCTAssertGreaterThan(repCountPlays, 0, "At least one rep-count phrase should play")

        // Build observation, generate a summary via mock LLM, persist.
        let observation = orchestrator.buildObservation()
        let llm = MockLLMClient()
        let summaryPrompt = PromptRegistry.renderPostSetSummary(observation: observation, tone: .standard)
        let summaryResp = try await llm.complete(request: LLMRequest(
            promptId: summaryPrompt.id, promptVersion: summaryPrompt.version,
            system: summaryPrompt.system, user: summaryPrompt.user
        ))
        XCTAssertFalse(summaryResp.text.isEmpty)

        let session = WorkoutSessionRecord.build(from: [observation], painFlag: false, summary: summaryResp.text)
        let sessionRepo = InMemorySessionRepository()
        try await sessionRepo.record(session)
        let recent = try await sessionRepo.recent(limit: 5)
        XCTAssertEqual(recent.count, 1)
    }
}
