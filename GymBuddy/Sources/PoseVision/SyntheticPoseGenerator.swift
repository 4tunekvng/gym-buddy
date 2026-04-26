import Foundation
import CoachingEngine

/// Procedurally generates pose fixtures for the three MVP exercises.
///
/// Used by tests that want to drive the engine through precise tempo/fatigue
/// patterns (including the north-star demo test, where reps 8–13 progressively
/// slow). Production pose data comes from the camera; synthetic data here is
/// for deterministic test coverage.
public enum SyntheticPoseGenerator {

    // MARK: - Push-up

    /// Generate a sequence of `repCount` push-up reps.
    ///
    /// - Parameters:
    ///   - repCount: number of reps to generate.
    ///   - baselineCycleSeconds: rep cycle duration for reps 1–`fatigueStartsAt`.
    ///   - fatigueRamp: optional slowdown ramp applied starting at rep `start`
    ///     and multiplying concentric duration by `multiplier` linearly by `end`.
    ///   - partialReps: rep numbers where ROM should be reduced to "partial" depth.
    ///   - sampleRateHz: pose sample rate.
    public static func pushUps(
        repCount: Int,
        baselineCycleSeconds: TimeInterval = 2.0,
        fatigueRamp: (startRep: Int, endRep: Int, multiplier: Double)? = nil,
        partialReps: Set<Int> = [],
        sampleRateHz: Int = 30
    ) -> [PoseSample] {
        var samples: [PoseSample] = []
        var t: TimeInterval = 0
        let dt = 1.0 / TimeInterval(sampleRateHz)

        // Open the set with a brief idle period at the top pose.
        for _ in 0..<sampleRateHz { // ~1s of idle at top
            samples.append(pushUpSample(t: t, depthPhase: 0.0, isPartial: false))
            t += dt
        }

        for rep in 1...repCount {
            let ramp: Double = {
                guard let r = fatigueRamp, rep >= r.startRep else { return 1.0 }
                let progress = Double(rep - r.startRep) / Double(max(1, r.endRep - r.startRep))
                return 1.0 + (r.multiplier - 1.0) * min(1.0, max(0, progress))
            }()
            let eccentricDuration = baselineCycleSeconds * 0.45
            let concentricDuration = (baselineCycleSeconds * 0.55) * ramp
            let isPartial = partialReps.contains(rep)

            // Eccentric: depth 0 → 1
            let eccFrames = max(1, Int(eccentricDuration * Double(sampleRateHz)))
            for i in 0..<eccFrames {
                let phase = Double(i + 1) / Double(eccFrames)
                samples.append(pushUpSample(t: t, depthPhase: phase, isPartial: isPartial))
                t += dt
            }
            // Brief dwell at bottom
            for _ in 0..<3 {
                samples.append(pushUpSample(t: t, depthPhase: 1.0, isPartial: isPartial))
                t += dt
            }
            // Concentric: depth 1 → 0
            let concFrames = max(1, Int(concentricDuration * Double(sampleRateHz)))
            for i in 0..<concFrames {
                let phase = 1.0 - Double(i + 1) / Double(concFrames)
                samples.append(pushUpSample(t: t, depthPhase: phase, isPartial: isPartial))
                t += dt
            }
            // Brief dwell at top
            for _ in 0..<3 {
                samples.append(pushUpSample(t: t, depthPhase: 0.0, isPartial: isPartial))
                t += dt
            }
        }

        // Post-set: still at top for 4 seconds (triggers set-end stillness detector).
        for _ in 0..<(sampleRateHz * 4) {
            samples.append(pushUpSample(t: t, depthPhase: 0.0, isPartial: false))
            t += dt
        }

        // Then user stands up (stance change): hips rise significantly.
        for i in 0..<(sampleRateHz) {
            let riseProgress = Double(i + 1) / Double(sampleRateHz)
            samples.append(pushUpStanceChange(t: t, riseProgress: riseProgress))
            t += dt
        }
        return samples
    }

    private static func pushUpSample(t: TimeInterval, depthPhase: Double, isPartial: Bool) -> PoseSample {
        // Interpolate elbow angle from 170° (top) to 95° (bottom). Partial reps
        // reach only 60% of that range so isPartial=true rounds to ROM < threshold.
        let fullDepth = isPartial ? 0.6 : 1.0
        let depth = depthPhase * fullDepth
        let elbowDegrees = 170.0 - (170.0 - 95.0) * depth

        return pushUpPoseAt(elbowDegrees: elbowDegrees, t: t)
    }

    /// Build a geometrically consistent push-up pose sample for a target elbow
    /// angle. Wrists are on the floor at a fixed y; the shoulder rises/falls
    /// with the angle so the computed shoulder–elbow–wrist interior angle at the
    /// elbow matches the target to within ~0.1°. Hips, knees, and ankles lie on
    /// the straight line from shoulder to ankle so the plank is clean — no
    /// false-positive hip-sag or hip-pike cues on a clean synthetic set.
    public static func pushUpPoseAt(elbowDegrees: Double, t: TimeInterval) -> PoseSample {
        let shoulderX = 0.3
        let wristX = 0.3
        let wristY = 0.55
        let armSegment = 0.15
        let theta = elbowDegrees * .pi / 180
        let shoulderWristDistance = 2 * armSegment * sin(theta / 2)
        let shoulderY = wristY - shoulderWristDistance
        let elbowY = (shoulderY + wristY) / 2
        // Offset elbow toward the body (right of shoulder x) so the shoulder-
        // elbow-hip angle stays small — a clean push-up has tucked elbows, not
        // flared. Offset magnitude comes from the isoceles-triangle geometry:
        // elbow is `L·cos(θ/2)` perpendicular to the shoulder-wrist line.
        let elbowX = shoulderX + armSegment * cos(theta / 2)

        let ankleY: Double = 0.40
        func yOnLine(atX x: Double) -> Double {
            let tRatio = (x - shoulderX) / (0.90 - shoulderX)
            return shoulderY + tRatio * (ankleY - shoulderY)
        }
        let hipY = yOnLine(atX: 0.60)
        let kneeY = yOnLine(atX: 0.75)

        return PoseSample(timestamp: t, joints: [
            .leftShoulder: Keypoint(x: shoulderX, y: shoulderY, confidence: 0.95),
            .rightShoulder: Keypoint(x: shoulderX + 0.02, y: shoulderY, confidence: 0.95),
            .leftElbow: Keypoint(x: elbowX, y: elbowY, confidence: 0.93),
            .rightElbow: Keypoint(x: elbowX + 0.02, y: elbowY, confidence: 0.93),
            .leftWrist: Keypoint(x: wristX, y: wristY, confidence: 0.92),
            .rightWrist: Keypoint(x: wristX + 0.02, y: wristY, confidence: 0.92),
            .leftHip: Keypoint(x: 0.60, y: hipY, confidence: 0.95),
            .rightHip: Keypoint(x: 0.60, y: hipY + 0.01, confidence: 0.95),
            .leftKnee: Keypoint(x: 0.75, y: kneeY, confidence: 0.9),
            .rightKnee: Keypoint(x: 0.75, y: kneeY + 0.01, confidence: 0.9),
            .leftAnkle: Keypoint(x: 0.90, y: ankleY, confidence: 0.9),
            .rightAnkle: Keypoint(x: 0.90, y: ankleY + 0.01, confidence: 0.9),
            .nose: Keypoint(x: shoulderX - 0.03, y: shoulderY - 0.02, confidence: 0.9)
        ])
    }

    private static func pushUpStanceChange(t: TimeInterval, riseProgress: Double) -> PoseSample {
        // Lift hips from 0.40 to ~0.25 — user has stood up.
        let hipY = 0.40 - riseProgress * 0.15
        let shoulderY = 0.35 - riseProgress * 0.15
        let leftShoulder = Keypoint(x: 0.3, y: shoulderY, confidence: 0.95)
        let rightShoulder = Keypoint(x: 0.32, y: shoulderY, confidence: 0.95)
        let leftWrist = Keypoint(x: 0.3, y: 0.55, confidence: 0.5)
        let rightWrist = Keypoint(x: 0.32, y: 0.55, confidence: 0.5)
        let leftElbow = Keypoint(x: 0.28, y: shoulderY + 0.05, confidence: 0.5)
        let rightElbow = Keypoint(x: 0.34, y: shoulderY + 0.05, confidence: 0.5)
        let leftHip = Keypoint(x: 0.6, y: hipY, confidence: 0.95)
        let rightHip = Keypoint(x: 0.62, y: hipY, confidence: 0.95)
        let leftKnee = Keypoint(x: 0.75, y: hipY + 0.05, confidence: 0.9)
        let rightKnee = Keypoint(x: 0.77, y: hipY + 0.05, confidence: 0.9)
        let leftAnkle = Keypoint(x: 0.9, y: 0.40, confidence: 0.9)
        let rightAnkle = Keypoint(x: 0.92, y: 0.40, confidence: 0.9)
        let nose = Keypoint(x: 0.3, y: shoulderY - 0.05, confidence: 0.9)
        return PoseSample(timestamp: t, joints: [
            .leftShoulder: leftShoulder, .rightShoulder: rightShoulder,
            .leftElbow: leftElbow, .rightElbow: rightElbow,
            .leftWrist: leftWrist, .rightWrist: rightWrist,
            .leftHip: leftHip, .rightHip: rightHip,
            .leftKnee: leftKnee, .rightKnee: rightKnee,
            .leftAnkle: leftAnkle, .rightAnkle: rightAnkle,
            .nose: nose
        ])
    }

    // MARK: - Goblet squat

    public static func gobletSquats(
        repCount: Int,
        cycleSeconds: TimeInterval = 2.5,
        sampleRateHz: Int = 30
    ) -> [PoseSample] {
        var samples: [PoseSample] = []
        var t: TimeInterval = 0
        let dt = 1.0 / TimeInterval(sampleRateHz)

        for _ in 0..<sampleRateHz {
            samples.append(squatSample(t: t, depthPhase: 0))
            t += dt
        }

        for _ in 1...repCount {
            let frames = max(1, Int(cycleSeconds * Double(sampleRateHz)))
            let half = frames / 2
            for i in 0..<half {
                let phase = Double(i + 1) / Double(half)
                samples.append(squatSample(t: t, depthPhase: phase))
                t += dt
            }
            for i in 0..<half {
                let phase = 1.0 - Double(i + 1) / Double(half)
                samples.append(squatSample(t: t, depthPhase: phase))
                t += dt
            }
        }
        // Stillness
        for _ in 0..<(sampleRateHz * 4) {
            samples.append(squatSample(t: t, depthPhase: 0))
            t += dt
        }
        return samples
    }

    private static func squatSample(t: TimeInterval, depthPhase: Double) -> PoseSample {
        let hipY = 0.5 + 0.20 * depthPhase   // hips descend
        let kneeY = 0.65                      // knees stay roughly constant in image
        let kneeAngleDeg = 170 - (170 - 80) * depthPhase
        let kneeAngle = kneeAngleDeg * .pi / 180.0

        // Shoulders above hips, following the descent roughly.
        let shoulderY = hipY - 0.28
        let ankleY = 0.78

        let leftShoulder = Keypoint(x: 0.48, y: shoulderY, confidence: 0.95)
        let rightShoulder = Keypoint(x: 0.52, y: shoulderY, confidence: 0.95)
        let leftHip = Keypoint(x: 0.48, y: hipY, confidence: 0.95)
        let rightHip = Keypoint(x: 0.52, y: hipY, confidence: 0.95)
        let leftKnee = Keypoint(x: 0.47, y: kneeY, confidence: 0.9)
        let rightKnee = Keypoint(x: 0.53, y: kneeY, confidence: 0.9)
        let leftAnkle = Keypoint(x: 0.48, y: ankleY, confidence: 0.88)
        let rightAnkle = Keypoint(x: 0.52, y: ankleY, confidence: 0.88)
        // Encode knee angle via the geometry of hip-knee-ankle (we already set y's).
        let leftElbow = Keypoint(x: 0.45, y: shoulderY + 0.1, confidence: 0.85)
        let rightElbow = Keypoint(x: 0.55, y: shoulderY + 0.1, confidence: 0.85)
        let leftWrist = Keypoint(x: 0.49, y: shoulderY + 0.15, confidence: 0.85)
        let rightWrist = Keypoint(x: 0.51, y: shoulderY + 0.15, confidence: 0.85)
        let nose = Keypoint(x: 0.50, y: shoulderY - 0.06, confidence: 0.9)
        _ = kneeAngle // documented for readers; angle is computed from keypoints in engine
        return PoseSample(timestamp: t, joints: [
            .leftShoulder: leftShoulder, .rightShoulder: rightShoulder,
            .leftElbow: leftElbow, .rightElbow: rightElbow,
            .leftWrist: leftWrist, .rightWrist: rightWrist,
            .leftHip: leftHip, .rightHip: rightHip,
            .leftKnee: leftKnee, .rightKnee: rightKnee,
            .leftAnkle: leftAnkle, .rightAnkle: rightAnkle,
            .nose: nose
        ])
    }

    // MARK: - Dumbbell row

    public static func dumbbellRows(
        repCount: Int,
        side: DumbbellRowRepDetector.Side = .right,
        cycleSeconds: TimeInterval = 2.2,
        sampleRateHz: Int = 30
    ) -> [PoseSample] {
        var samples: [PoseSample] = []
        var t: TimeInterval = 0
        let dt = 1.0 / TimeInterval(sampleRateHz)

        for _ in 0..<sampleRateHz {
            samples.append(rowSample(t: t, pullPhase: 0, side: side))
            t += dt
        }

        for _ in 1...repCount {
            let frames = max(1, Int(cycleSeconds * Double(sampleRateHz)))
            let half = frames / 2
            for i in 0..<half {
                let phase = Double(i + 1) / Double(half)
                samples.append(rowSample(t: t, pullPhase: phase, side: side))
                t += dt
            }
            for i in 0..<half {
                let phase = 1.0 - Double(i + 1) / Double(half)
                samples.append(rowSample(t: t, pullPhase: phase, side: side))
                t += dt
            }
        }
        for _ in 0..<(sampleRateHz * 4) {
            samples.append(rowSample(t: t, pullPhase: 0, side: side))
            t += dt
        }
        return samples
    }

    private static func rowSample(t: TimeInterval, pullPhase: Double, side: DumbbellRowRepDetector.Side) -> PoseSample {
        // Bent-over row stance: shoulders and hips nearly level (horizontal torso).
        // Working arm: wrist at bottom (y=0.75) when pullPhase=0, rises to y=0.5 at pullPhase=1.
        // Supporting arm: stays at ~0.75.
        let workingWristY = 0.75 - 0.25 * pullPhase
        let workingElbowY = 0.55 - 0.10 * pullPhase
        let supportWristY: Double = 0.75
        let supportElbowY: Double = 0.55

        let leftShoulder = Keypoint(x: 0.35, y: 0.55, confidence: 0.95)
        let rightShoulder = Keypoint(x: 0.45, y: 0.55, confidence: 0.95)
        let leftHip = Keypoint(x: 0.35, y: 0.6, confidence: 0.95)
        let rightHip = Keypoint(x: 0.45, y: 0.6, confidence: 0.95)
        let leftKnee = Keypoint(x: 0.33, y: 0.75, confidence: 0.9)
        let rightKnee = Keypoint(x: 0.47, y: 0.75, confidence: 0.9)
        let leftAnkle = Keypoint(x: 0.33, y: 0.9, confidence: 0.88)
        let rightAnkle = Keypoint(x: 0.47, y: 0.9, confidence: 0.88)

        let leftElbow: Keypoint
        let rightElbow: Keypoint
        let leftWrist: Keypoint
        let rightWrist: Keypoint

        switch side {
        case .left:
            leftElbow = Keypoint(x: 0.35, y: workingElbowY, confidence: 0.93)
            leftWrist = Keypoint(x: 0.35, y: workingWristY, confidence: 0.93)
            rightElbow = Keypoint(x: 0.45, y: supportElbowY, confidence: 0.93)
            rightWrist = Keypoint(x: 0.45, y: supportWristY, confidence: 0.93)
        case .right:
            rightElbow = Keypoint(x: 0.45, y: workingElbowY, confidence: 0.93)
            rightWrist = Keypoint(x: 0.45, y: workingWristY, confidence: 0.93)
            leftElbow = Keypoint(x: 0.35, y: supportElbowY, confidence: 0.93)
            leftWrist = Keypoint(x: 0.35, y: supportWristY, confidence: 0.93)
        }

        let nose = Keypoint(x: 0.33, y: 0.50, confidence: 0.9)
        return PoseSample(timestamp: t, joints: [
            .leftShoulder: leftShoulder, .rightShoulder: rightShoulder,
            .leftElbow: leftElbow, .rightElbow: rightElbow,
            .leftWrist: leftWrist, .rightWrist: rightWrist,
            .leftHip: leftHip, .rightHip: rightHip,
            .leftKnee: leftKnee, .rightKnee: rightKnee,
            .leftAnkle: leftAnkle, .rightAnkle: rightAnkle,
            .nose: nose
        ])
    }
}
