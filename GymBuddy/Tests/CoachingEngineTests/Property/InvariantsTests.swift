import XCTest
@testable import CoachingEngine

/// Property-style invariants: generate many random-ish pose streams and assert
/// that the engine never violates its core contracts.
///
/// Swift stdlib has no property-testing library, so we use deterministic
/// iteration count with seeded generators. Each test is fast (< 1s).
final class InvariantsTests: XCTestCase {

    func testRepNumbersAlwaysMonotonicallyIncrementByOne() {
        let orchestrator = SessionOrchestrator(
            config: SessionConfig(exerciseId: .pushUp, setNumber: 1, targetReps: nil, tone: .standard),
            context: SessionContext(userId: UUID(), tone: .standard)
        )
        var emittedNumbers: [Int] = []
        for sample in randomishPushUpStream(seed: 42, repCount: 15) {
            let intents = orchestrator.observe(sample: sample)
            for intent in intents {
                if case .sayRepCount(let n, _) = intent { emittedNumbers.append(n) }
            }
        }
        for (i, n) in emittedNumbers.enumerated() {
            XCTAssertEqual(n, i + 1, "Rep numbers must strictly increment by 1 each time")
        }
    }

    func testNoCueFiresWithoutObservation() {
        let orchestrator = SessionOrchestrator(
            config: SessionConfig(exerciseId: .pushUp, setNumber: 1, targetReps: nil, tone: .standard),
            context: SessionContext(userId: UUID(), tone: .standard)
        )
        // Observe a stream with no reliable joints — no cues should ever fire.
        for i in 0..<30 {
            let bogus = PoseSample(timestamp: Double(i) * 0.033, joints: [:])
            let intents = orchestrator.observe(sample: bogus)
            let hadCue = intents.contains(where: {
                if case .formCue = $0 { return true }; return false
            })
            XCTAssertFalse(hadCue, "A cue fired without any pose observation")
        }
    }

    func testRepEventDurationsAreNonNegative() {
        let orchestrator = SessionOrchestrator(
            config: SessionConfig(exerciseId: .pushUp, setNumber: 1, targetReps: nil, tone: .standard),
            context: SessionContext(userId: UUID(), tone: .standard)
        )
        for sample in randomishPushUpStream(seed: 7, repCount: 8) {
            _ = orchestrator.observe(sample: sample)
        }
        let obs = orchestrator.buildObservation()
        for rep in obs.repEvents {
            XCTAssertGreaterThanOrEqual(rep.concentricDuration, 0)
            XCTAssertGreaterThanOrEqual(rep.eccentricDuration, 0)
            XCTAssertGreaterThanOrEqual(rep.endedAt, rep.startedAt)
        }
    }

    func testCuePrioritySelectionIsAStableMax() {
        // For any mix of cue severities, the priority selector returns the max.
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<100 {
            let severities: [CueSeverity] = (0..<Int.random(in: 1...6, using: &rng)).map { _ in
                [.optimization, .quality, .safety].randomElement(using: &rng)!
            }
            let cues = severities.enumerated().map { i, s in
                CueEvent(exerciseId: .pushUp, cueType: .hipSag, severity: s, repNumber: i, timestamp: 0, observationCode: "x")
            }
            let picked = CueEngine.selectHighestPriority(cues)
            XCTAssertEqual(picked?.severity, severities.max())
        }
    }

    // MARK: - Helpers

    /// Deterministic push-up stream using `seed`. Not truly random — uses a
    /// simple LCG so the test output is stable per seed.
    private func randomishPushUpStream(seed: UInt64, repCount: Int) -> [PoseSample] {
        var state: UInt64 = seed
        func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 33) / Double(UInt32.max)
        }
        var samples: [PoseSample] = []
        var t: TimeInterval = 0
        // Idle.
        for _ in 0..<30 {
            samples.append(NorthStarDemoTest.sample(elbowDegrees: 170, hipY: 0.40, t: t))
            t += 1.0 / 30.0
        }
        for _ in 1...repCount {
            let jitter = (next() - 0.5) * 0.2
            let concentric = 1.0 + jitter
            let frames = max(5, Int(concentric * 30))
            for i in 0..<frames {
                let phase = Double(i + 1) / Double(frames)
                let angle = 170.0 - 75.0 * phase
                samples.append(NorthStarDemoTest.sample(elbowDegrees: angle, hipY: 0.40, t: t))
                t += 1.0 / 30.0
            }
            for _ in 0..<3 {
                samples.append(NorthStarDemoTest.sample(elbowDegrees: 95, hipY: 0.40, t: t))
                t += 1.0 / 30.0
            }
            for i in 0..<frames {
                let phase = 1.0 - Double(i + 1) / Double(frames)
                let angle = 95.0 + 75.0 * phase
                samples.append(NorthStarDemoTest.sample(elbowDegrees: angle, hipY: 0.40, t: t))
                t += 1.0 / 30.0
            }
            for _ in 0..<3 {
                samples.append(NorthStarDemoTest.sample(elbowDegrees: 170, hipY: 0.40, t: t))
                t += 1.0 / 30.0
            }
        }
        return samples
    }
}
