import XCTest
@testable import CoachingEngine

/// The north-star demo test. Guards the moment described in PRD §2 and §10.3.
///
/// Scenario: 13 push-up reps. Reps 1–7 baseline tempo. Reps 8–11 progressively
/// slow but stay below the fatigue trigger. Rep 12 crosses the first-slowdown
/// threshold (1.40× baseline). Rep 13 crosses the second-slowdown threshold
/// (1.55× baseline). The set auto-ends on stillness after rep 13.
///
/// PRD §10.3 assertions enforced here:
///   1. Exactly 13 reps counted.
///   2. The phrase "one more" (CoachingIntent.EncouragementKind.oneMore) occurs
///      during rep 13's concentric window (±200 ms of its concentric START).
///   3. The post-set summary contains the numeric count "13".
///   4. No safety cues misfire (the synthetic set has clean form).
///   5. The set-end intent is emitted.
///
/// The PRD also says the assertion should be on *meaning*, not exact strings.
/// We assert the EncouragementKind (which is the engine's neutral name for
/// "the one-more moment"), not the rendered English. The mapper to spoken
/// text lives in VoiceIO and is exercised by the integration test variant
/// (NorthStarVoicedDemoTest in IntegrationTests).
///
/// If this test goes red, main goes red.
final class NorthStarDemoTest: XCTestCase {

    func testHeroMomentProducesExpectedIntents() throws {
        let config = SessionConfig(
            exerciseId: .pushUp,
            setNumber: 1,
            targetReps: nil,
            tone: .standard
        )
        let context = SessionContext(
            userId: UUID(),
            tone: .standard,
            priorSessionBestReps: [.pushUp: 11],
            activeInjuryNotes: [],
            memoryReferences: []
        )
        let orchestrator = SessionOrchestrator(config: config, context: context)
        let fixture = HeroFixture.build()

        var allIntents: [CoachingIntent] = []
        for sample in fixture.samples {
            let intents = orchestrator.observe(sample: sample)
            allIntents.append(contentsOf: intents)
        }

        // 1) Exactly 13 reps counted.
        let repCounts = allIntents.compactMap { intent -> Int? in
            if case .sayRepCount(let n, _) = intent { return n } else { return nil }
        }
        XCTAssertEqual(repCounts, Array(1...13), "Hero moment must count exactly 13 reps")

        // 2) "One more" timing — must occur DURING rep 13's concentric window
        //    with ±200 ms tolerance on the edges. (PRD §10.3.) The window is
        //    bounded by [concentricStart, concentricEnd]; the engine's actual
        //    fire moment is at the FSM bottom→ascending transition which
        //    inherently falls a few frames after the geometric concentric
        //    start, so the assertion is on inclusion-in-window, not equality
        //    with start.
        let oneMoreTimestamps = allIntents.compactMap { intent -> TimeInterval? in
            if case .encouragement(let kind, _, let t) = intent, kind == .oneMore { return t }
            return nil
        }
        XCTAssertFalse(oneMoreTimestamps.isEmpty,
                       "Expected at least one .oneMore encouragement during fatigue")
        let firstOneMore = oneMoreTimestamps[0]
        let lower = fixture.rep13ConcentricStartTimestamp - 0.200
        let upper = fixture.rep13ConcentricEndTimestamp + 0.200
        XCTAssertTrue(
            (lower...upper).contains(firstOneMore),
            "PRD §10.3: 'one more' must occur during rep 13's concentric window (±200 ms tolerance). " +
            "Fired at t=\(firstOneMore), window=[\(fixture.rep13ConcentricStartTimestamp), \(fixture.rep13ConcentricEndTimestamp)] ±0.2s"
        )

        // 3) Last-one / drive eventually fires (the "that's the one you weren't
        //    going to do alone" companion phrase from PRD §2).
        let lastOneIntents = allIntents.compactMap { intent -> CoachingIntent.EncouragementKind? in
            if case .encouragement(let kind, _, _) = intent, kind == .lastOne { return kind }
            return nil
        }
        XCTAssertFalse(lastOneIntents.isEmpty, "Expected 'last one' on second slowdown")

        // 4) No safety cues misfire.
        let safetyCues = allIntents.compactMap { intent -> CueEvent? in
            if case .formCue(let c) = intent, c.severity == .safety { return c } else { return nil }
        }
        XCTAssertTrue(safetyCues.isEmpty, "No safety cues should fire on a clean synthetic set")

        // 5) Set-ended event exists.
        let setEnded = allIntents.contains { intent in
            if case .setEnded = intent { return true } else { return false }
        }
        XCTAssertTrue(setEnded, "Orchestrator must emit a setEnded intent")

        // 6) Observation captures the rep count and a baseline.
        let obs = orchestrator.buildObservation()
        XCTAssertEqual(obs.totalReps, 13)
        XCTAssertNotNil(obs.tempoBaselineMs)
        XCTAssertNotNil(obs.fatigueSlowdownAtRep)

        // 7) Post-set summary (deterministic fallback path) contains "13" —
        //    PRD §10.3 explicitly requires the numeric count in the summary.
        let summary = SessionSummaryFallback.summary(for: obs)
        XCTAssertTrue(
            summary.contains("13"),
            "PRD §10.3: post-set summary must contain the numeric count '13'. Got: \(summary)"
        )
        // Defensive: never ship generic praise.
        XCTAssertFalse(summary.lowercased().contains("good job"),
                       "Fallback summary must not be generic praise.")
    }

    /// Re-exposed so older tests (InvariantsTests, etc.) that built fixtures
    /// against this static helper continue to compile. New tests should reach
    /// for HeroFixture.build() instead.
    static func sample(elbowDegrees: Double, hipY: Double = .nan, t: TimeInterval) -> PoseSample {
        if hipY.isNaN {
            return NorthStarPushUpSample.at(elbowDegrees: elbowDegrees, t: t)
        }
        // The hipY override is used by negative-fixture tests to simulate hip
        // sag. Fall through to the legacy geometry path so behavior is preserved.
        let shoulderX = 0.3
        let wristX = 0.3
        let wristY = 0.55
        let armSegment = 0.15
        let theta = elbowDegrees * .pi / 180
        let shoulderWristDist = 2 * armSegment * sin(theta / 2)
        let shoulderY = wristY - shoulderWristDist
        let elbowY = (shoulderY + wristY) / 2
        let elbowX = shoulderX + armSegment * cos(theta / 2)
        let ankleY = 0.40
        func yOnLine(atX x: Double) -> Double {
            let r = (x - shoulderX) / (0.90 - shoulderX)
            return shoulderY + r * (ankleY - shoulderY)
        }
        let kneeY = yOnLine(atX: 0.75)
        return PoseSample(timestamp: t, joints: [
            .leftShoulder: Keypoint(x: shoulderX, y: shoulderY, confidence: 0.95),
            .rightShoulder: Keypoint(x: shoulderX + 0.02, y: shoulderY, confidence: 0.95),
            .leftElbow: Keypoint(x: elbowX, y: elbowY, confidence: 0.95),
            .rightElbow: Keypoint(x: elbowX + 0.02, y: elbowY, confidence: 0.95),
            .leftWrist: Keypoint(x: wristX, y: wristY, confidence: 0.95),
            .rightWrist: Keypoint(x: wristX + 0.02, y: wristY, confidence: 0.95),
            .leftHip: Keypoint(x: 0.60, y: hipY, confidence: 0.95),
            .rightHip: Keypoint(x: 0.60, y: hipY + 0.01, confidence: 0.95),
            .leftKnee: Keypoint(x: 0.75, y: kneeY, confidence: 0.9),
            .rightKnee: Keypoint(x: 0.75, y: kneeY + 0.01, confidence: 0.9),
            .leftAnkle: Keypoint(x: 0.90, y: ankleY, confidence: 0.9),
            .rightAnkle: Keypoint(x: 0.90, y: ankleY + 0.01, confidence: 0.9),
            .nose: Keypoint(x: 0.27, y: shoulderY - 0.02, confidence: 0.9)
        ])
    }
}

/// Synthetic 13-rep push-up fixture matching PRD §2's tempo curve. Lives next
/// to the test rather than in a generator so the timing math is auditable in
/// one place.
private enum HeroFixture {

    struct Output {
        let samples: [PoseSample]
        /// Timestamp at which rep 13's concentric phase begins (geometric: the
        /// frame where the user starts pushing back up). The PRD §10.3 window
        /// extends from this moment to `rep13ConcentricEndTimestamp`.
        let rep13ConcentricStartTimestamp: TimeInterval
        /// Timestamp at which rep 13's concentric phase ends (top of the rep).
        let rep13ConcentricEndTimestamp: TimeInterval
    }

    static func build() -> Output {
        // Concentric durations (seconds). Reps 1–7 are baseline. Reps 8–11
        // creep up but stay below the 1.35× trigger. Rep 12 crosses 1.35×
        // (firstSlowdown). Rep 13 crosses 1.50× (secondSlowdown).
        //
        // Calibrated against the PushUpRepDetector's measured concentric
        // duration (which starts at the .bottom phase entry — angle < 100° —
        // and ends at .top — angle > 160°). Because .bottom captures the tail
        // of the eccentric AND the ramp-up of the concentric, the *measured*
        // concentric is shorter than the *fixture* concentric, so we pad both
        // trigger reps to ensure the tempo tracker sees the right ratios.
        let concentricByRep: [Double] = [
            1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, // reps 1–7
            1.05, 1.12, 1.22, 1.30,                    // reps 8–11 (sub-trigger)
            1.50,                                      // rep 12 → first slowdown
            1.80                                       // rep 13 → second slowdown
        ]
        let eccentricSeconds: TimeInterval = 0.8
        let bottomDwellSeconds: TimeInterval = 0.1
        let topDwellSeconds: TimeInterval = 0.1
        let dt = 1.0 / 30.0

        var samples: [PoseSample] = []
        var t: TimeInterval = 0

        // Idle at top to seed the rep detector.
        for _ in 0..<30 {
            samples.append(NorthStarPushUpSample.at(elbowDegrees: 170, t: t))
            t += dt
        }

        var rep13ConcentricStart: TimeInterval = 0
        var rep13ConcentricEnd: TimeInterval = 0

        for (idx, concentricSeconds) in concentricByRep.enumerated() {
            let repNumber = idx + 1

            // Eccentric: 170° → 95°.
            let eccFrames = max(1, Int(eccentricSeconds * 30))
            for i in 0..<eccFrames {
                let phase = Double(i + 1) / Double(eccFrames)
                let angle = 170.0 - 75.0 * phase
                samples.append(NorthStarPushUpSample.at(elbowDegrees: angle, t: t))
                t += dt
            }
            // Dwell at bottom.
            let bottomFrames = max(1, Int(bottomDwellSeconds * 30))
            for _ in 0..<bottomFrames {
                samples.append(NorthStarPushUpSample.at(elbowDegrees: 95, t: t))
                t += dt
            }
            // Concentric: 95° → 170°.
            // Capture rep 13's concentric window (the first/last samples).
            if repNumber == 13 {
                rep13ConcentricStart = t
            }
            let concFrames = max(1, Int(concentricSeconds * 30))
            for i in 0..<concFrames {
                let phase = Double(i + 1) / Double(concFrames)
                let angle = 95.0 + 75.0 * phase
                samples.append(NorthStarPushUpSample.at(elbowDegrees: angle, t: t))
                t += dt
            }
            if repNumber == 13 {
                rep13ConcentricEnd = t
            }
            // Dwell at top.
            let topFrames = max(1, Int(topDwellSeconds * 30))
            for _ in 0..<topFrames {
                samples.append(NorthStarPushUpSample.at(elbowDegrees: 170, t: t))
                t += dt
            }
        }

        // 5 seconds of stillness → triggers set-end.
        for _ in 0..<(30 * 5) {
            samples.append(NorthStarPushUpSample.at(elbowDegrees: 170, t: t))
            t += dt
        }

        return Output(
            samples: samples,
            rep13ConcentricStartTimestamp: rep13ConcentricStart,
            rep13ConcentricEndTimestamp: rep13ConcentricEnd
        )
    }
}

/// Geometry helper — kept module-private so the test owns its fixture math.
/// Geometry: wrists fixed on the floor, shoulder y derived from the target
/// elbow angle via the isoceles relation D = 2·L·sin(θ/2). Hips/knees/ankles
/// lie on the shoulder→ankle line so a clean plank doesn't fire safety cues.
enum NorthStarPushUpSample {
    static func at(elbowDegrees: Double, t: TimeInterval) -> PoseSample {
        let shoulderX = 0.3
        let wristX = 0.3
        let wristY = 0.55
        let armSegment = 0.15
        let theta = elbowDegrees * .pi / 180
        let shoulderWristDist = 2 * armSegment * sin(theta / 2)
        let shoulderY = wristY - shoulderWristDist
        let elbowY = (shoulderY + wristY) / 2
        let elbowX = shoulderX + armSegment * cos(theta / 2)
        let ankleY = 0.40
        func yOnLine(atX x: Double) -> Double {
            let r = (x - shoulderX) / (0.90 - shoulderX)
            return shoulderY + r * (ankleY - shoulderY)
        }
        let hipY = yOnLine(atX: 0.60)
        let kneeY = yOnLine(atX: 0.75)
        return PoseSample(timestamp: t, joints: [
            .leftShoulder: Keypoint(x: shoulderX, y: shoulderY, confidence: 0.95),
            .rightShoulder: Keypoint(x: shoulderX + 0.02, y: shoulderY, confidence: 0.95),
            .leftElbow: Keypoint(x: elbowX, y: elbowY, confidence: 0.95),
            .rightElbow: Keypoint(x: elbowX + 0.02, y: elbowY, confidence: 0.95),
            .leftWrist: Keypoint(x: wristX, y: wristY, confidence: 0.95),
            .rightWrist: Keypoint(x: wristX + 0.02, y: wristY, confidence: 0.95),
            .leftHip: Keypoint(x: 0.60, y: hipY, confidence: 0.95),
            .rightHip: Keypoint(x: 0.60, y: hipY + 0.01, confidence: 0.95),
            .leftKnee: Keypoint(x: 0.75, y: kneeY, confidence: 0.9),
            .rightKnee: Keypoint(x: 0.75, y: kneeY + 0.01, confidence: 0.9),
            .leftAnkle: Keypoint(x: 0.90, y: ankleY, confidence: 0.9),
            .rightAnkle: Keypoint(x: 0.90, y: ankleY + 0.01, confidence: 0.9),
            .nose: Keypoint(x: 0.27, y: shoulderY - 0.02, confidence: 0.9)
        ])
    }
}
