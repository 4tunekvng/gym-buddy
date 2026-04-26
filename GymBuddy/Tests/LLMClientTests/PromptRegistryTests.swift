import XCTest
@testable import CoachingEngine
@testable import LLMClient

final class PromptRegistryTests: XCTestCase {

    func testPostSetSummaryIncludesSafetyPreamble() {
        let reps = (1...10).map { n in
            RepEvent(
                exerciseId: .pushUp, repNumber: n,
                startedAt: Double(n), endedAt: Double(n) + 1,
                concentricDuration: 1.0, eccentricDuration: 0.6,
                rangeOfMotionScore: 0.95, isPartial: false
            )
        }
        let observation = SessionObservation(
            exerciseId: .pushUp, setNumber: 1,
            repEvents: reps, cueEvents: [],
            endEvent: SetEndEvent(
                exerciseId: .pushUp, setNumber: 1, reason: .autoDetectedStill,
                timestamp: 20, totalReps: 10, partialReps: 0
            ),
            tempoBaselineMs: 1000, fatigueSlowdownAtRep: nil,
            priorSessionBestReps: 8, memoryReferences: []
        )
        let rendered = PromptRegistry.renderPostSetSummary(observation: observation, tone: .standard)
        XCTAssertTrue(rendered.system.contains("Gym Buddy"))
        XCTAssertTrue(rendered.system.contains("never"))
        XCTAssertTrue(rendered.user.contains("total_reps=10"))
    }

    func testBetweenSetQAIncludesUserQuestion() {
        let observation = SessionObservation(
            exerciseId: .pushUp, setNumber: 2,
            repEvents: [], cueEvents: [],
            endEvent: SetEndEvent(
                exerciseId: .pushUp, setNumber: 2, reason: .autoDetectedStill,
                timestamp: 0, totalReps: 10, partialReps: 0
            ),
            tempoBaselineMs: nil, fatigueSlowdownAtRep: nil,
            priorSessionBestReps: nil, memoryReferences: []
        )
        let rendered = PromptRegistry.renderBetweenSetQA(
            userQuestion: "should I add weight?",
            observation: observation,
            tone: .intense
        )
        XCTAssertTrue(rendered.user.contains("should I add weight"))
        XCTAssertTrue(rendered.system.contains("intense"))
    }

    func testMemoryExtractionPromptIsStrictJSON() {
        let rendered = PromptRegistry.renderMemoryExtraction(
            sourceKind: "onboarding",
            conversationText: "I've had a knee injury"
        )
        XCTAssertTrue(rendered.system.contains("JSON"))
        XCTAssertTrue(rendered.system.contains("body-part:knee"))
    }

    func testMorningReadinessReferencesTone() {
        let check = ReadinessCheck(soreness: 3, energy: 3, sleepHours: 7.5, hrvDeltaPct: 0)
        let rendered = PromptRegistry.renderMorningReadiness(
            check: check, memoryReferences: ["left knee clicks"], tone: .quiet
        )
        XCTAssertTrue(rendered.system.contains("quiet"))
        XCTAssertTrue(rendered.user.contains("left knee clicks"))
    }
}
