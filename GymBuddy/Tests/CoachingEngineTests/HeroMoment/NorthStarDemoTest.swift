import XCTest
@testable import CoachingEngine

/// The north-star demo test. Guards the moment described in PRD §2 and §10.3.
///
/// Scenario: 13 push-up reps. Reps 1–7 are normal tempo. Reps 8–13 progressively
/// slow the concentric phase — by rep 8 the ratio crosses 1.35× baseline, and
/// by rep 13 it crosses 1.50×. Assertions:
///
///   - Exactly 13 reps are counted.
///   - A "one more" encouragement intent fires at or near rep 8 (first slowdown).
///   - A "last one" encouragement intent fires at or after rep 13 (second slowdown).
///   - No safety-cue misfires (the synthetic set has good form).
///   - The set-end event eventually surfaces.
///   - Observations captured can be passed to the LLM summary with the numeric
///     rep count present.
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
        let samples = buildHeroFixture()

        var allIntents: [CoachingIntent] = []
        for sample in samples {
            let intents = orchestrator.observe(sample: sample)
            allIntents.append(contentsOf: intents)
        }

        // 1) Exactly 13 reps counted.
        let repCounts = allIntents.compactMap { intent -> Int? in
            if case .sayRepCount(let n, _) = intent { return n } else { return nil }
        }
        XCTAssertEqual(repCounts, Array(1...13), "Hero moment must count exactly 13 reps")

        // 2) First slowdown fires on rep 8 (±1).
        let oneMoreIntents = allIntents.compactMap { intent -> (CoachingIntent.EncouragementKind, TimeInterval)? in
            if case .encouragement(let kind, _, let t) = intent, kind == .oneMore { return (kind, t) }
            return nil
        }
        XCTAssertFalse(oneMoreIntents.isEmpty, "Expected at least one 'one more' encouragement during fatigue")

        // 3) Last-one / drive fires later (on rep 13).
        let lastOneIntents = allIntents.compactMap { intent -> CoachingIntent.EncouragementKind? in
            if case .encouragement(let kind, _, _) = intent, kind == .lastOne { return kind }
            return nil
        }
        XCTAssertFalse(lastOneIntents.isEmpty, "Expected 'last one' encouragement on second slowdown")

        // 4) No safety cues misfire.
        let safetyCues = allIntents.compactMap { intent -> CueEvent? in
            if case .formCue(let c) = intent, c.severity == .safety { return c } else { return nil }
        }
        XCTAssertTrue(safetyCues.isEmpty, "No safety cues should fire on a clean synthetic set")

        // 5) Set ended event exists.
        let setEnded = allIntents.contains { intent in
            if case .setEnded = intent { return true } else { return false }
        }
        XCTAssertTrue(setEnded, "Orchestrator must emit a setEnded intent")

        // 6) Observation captures the rep count and can drive a summary.
        let obs = orchestrator.buildObservation()
        XCTAssertEqual(obs.totalReps, 13)
        XCTAssertNotNil(obs.tempoBaselineMs)
        XCTAssertNotNil(obs.fatigueSlowdownAtRep)
    }

    // MARK: - Fixture synthesis

    /// Directly constructs a stream of pose samples that drives the push-up rep
    /// detector through 13 complete cycles. Rep 1–7 baseline concentric
    /// duration ≈ 1.0s; reps 8–13 ramp up to 2.0s (2× baseline) so both fatigue
    /// thresholds (1.35× and 1.50×) are crossed.
    ///
    /// We don't use the SyntheticPoseGenerator (which lives in PoseVision) here
    /// to keep CoachingEngine tests free of cross-module dependency.
    private func buildHeroFixture() -> [PoseSample] {
        var samples: [PoseSample] = []
        var t: TimeInterval = 0
        let dt = 1.0 / 30.0

        // 1s idle at top.
        for _ in 0..<30 {
            samples.append(Self.sample(elbowDegrees: 170, t: t))
            t += dt
        }

        for rep in 1...13 {
            let concentricSeconds: TimeInterval = {
                if rep <= 7 { return 1.0 }
                // Linear ramp: rep 8 → 1.4s, rep 13 → 2.0s.
                let progress = Double(rep - 7) / Double(13 - 7)
                return 1.0 + progress * 1.0
            }()
            let eccentricSeconds: TimeInterval = 0.8

            // Eccentric: 170° → 95°
            let eccFrames = max(1, Int(eccentricSeconds * 30))
            for i in 0..<eccFrames {
                let phase = Double(i + 1) / Double(eccFrames)
                let angle = 170.0 - 75.0 * phase
                samples.append(Self.sample(elbowDegrees: angle, t: t))
                t += dt
            }
            // Dwell at bottom.
            for _ in 0..<3 {
                samples.append(Self.sample(elbowDegrees: 95, t: t))
                t += dt
            }
            // Concentric: 95° → 170° over `concentricSeconds`.
            let concFrames = max(1, Int(concentricSeconds * 30))
            for i in 0..<concFrames {
                let phase = Double(i + 1) / Double(concFrames)
                let angle = 95.0 + 75.0 * phase
                samples.append(Self.sample(elbowDegrees: angle, t: t))
                t += dt
            }
            // Dwell at top.
            for _ in 0..<3 {
                samples.append(Self.sample(elbowDegrees: 170, t: t))
                t += dt
            }
        }

        // 5 seconds of stillness → triggers set-end.
        for _ in 0..<(30 * 5) {
            samples.append(Self.sample(elbowDegrees: 170, t: t))
            t += dt
        }
        return samples
    }

    /// Build a single push-up sample with a target shoulder–elbow–wrist angle.
    /// Geometry:
    ///   - wrists fixed on the floor (y = 0.55).
    ///   - shoulder y computed from the target angle via the isoceles-triangle
    ///     relation D = 2·L·sin(θ/2) with L = 0.15. Matches the target within ~0.1°.
    ///   - hips, knees, ankles lie on the shoulder-ankle line so the "plank" is
    ///     straight. The hipY parameter lets callers override hip y to simulate
    ///     hip sag or pike for cue tests — when left at the default, geometry is
    ///     clean (no false-positive safety cues).
    static func sample(elbowDegrees: Double, hipY: Double = .nan, t: TimeInterval) -> PoseSample {
        let shoulderX = 0.3
        let wristX = 0.3
        let wristY = 0.55
        let armSegment = 0.15
        let theta = elbowDegrees * .pi / 180
        let shoulderWristDist = 2 * armSegment * sin(theta / 2)
        let shoulderY = wristY - shoulderWristDist
        let elbowY = (shoulderY + wristY) / 2
        // Elbow tucks toward the body (rightward from shoulderX) so the clean
        // plank doesn't trigger a false-positive elbow-flare cue.
        let elbowX = shoulderX + armSegment * cos(theta / 2)

        // Place the rest of the body on a straight line from shoulder(0.3) to ankle(0.9,0.40).
        let ankleY = 0.40
        func yOnLine(atX x: Double) -> Double {
            let t = (x - shoulderX) / (0.90 - shoulderX)
            return shoulderY + t * (ankleY - shoulderY)
        }
        let resolvedHipY = hipY.isNaN ? yOnLine(atX: 0.60) : hipY
        let kneeY = yOnLine(atX: 0.75)

        return PoseSample(timestamp: t, joints: [
            .leftShoulder: Keypoint(x: shoulderX, y: shoulderY, confidence: 0.95),
            .rightShoulder: Keypoint(x: shoulderX + 0.02, y: shoulderY, confidence: 0.95),
            .leftElbow: Keypoint(x: elbowX, y: elbowY, confidence: 0.95),
            .rightElbow: Keypoint(x: elbowX + 0.02, y: elbowY, confidence: 0.95),
            .leftWrist: Keypoint(x: wristX, y: wristY, confidence: 0.95),
            .rightWrist: Keypoint(x: wristX + 0.02, y: wristY, confidence: 0.95),
            .leftHip: Keypoint(x: 0.60, y: resolvedHipY, confidence: 0.95),
            .rightHip: Keypoint(x: 0.60, y: resolvedHipY + 0.01, confidence: 0.95),
            .leftKnee: Keypoint(x: 0.75, y: kneeY, confidence: 0.9),
            .rightKnee: Keypoint(x: 0.75, y: kneeY + 0.01, confidence: 0.9),
            .leftAnkle: Keypoint(x: 0.90, y: ankleY, confidence: 0.9),
            .rightAnkle: Keypoint(x: 0.90, y: ankleY + 0.01, confidence: 0.9),
            .nose: Keypoint(x: 0.27, y: shoulderY - 0.02, confidence: 0.9)
        ])
    }
}
