import Foundation

/// Goblet squat cue catalogue.
///
/// Sources: NSCA Essentials, Ch 16; Kraemer & Fleck on lower-body biomechanics.
public enum GobletSquatCues {
    public static let all: [CueEvaluator] = [
        SquatShallow(),
        KneeValgusLeft(),
        KneeValgusRight(),
        TorsoForward(),
        HeelLift(),
        DumbbellDrift()
    ]

    /// Squat shallow: hip above parallel with knee.
    public struct SquatShallow: CueEvaluator {
        public let cueType: CueType = .squatShallow
        public let severity: CueSeverity = .quality
        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            guard phase == .ascending else { return nil }
            // Evaluate at the moment we exit the bottom phase — hip must have
            // been below knee line at deepest point. We compare hip y to knee y
            // here; ideally hip.y >= knee.y at bottom (below parallel).
            guard let hip = PoseGeometry.midpoint(
                sample[.leftHip] ?? missing,
                sample[.rightHip] ?? missing
            ) else { return nil }
            guard let knee = PoseGeometry.midpoint(
                sample[.leftKnee] ?? missing,
                sample[.rightKnee] ?? missing
            ) else { return nil }
            if knee.y - hip.y > 0.02 {
                return "shallow:\(String(format: "%.3f", knee.y - hip.y))"
            }
            return nil
        }
    }

    /// Left knee valgus: knee caving inward during the descent/bottom phase.
    public struct KneeValgusLeft: CueEvaluator {
        public let cueType: CueType = .kneeValgusLeft
        public let severity: CueSeverity = .safety
        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            guard phase == .bottom || phase == .descending else { return nil }
            guard let hip = sample[.leftHip], hip.isReliable,
                  let knee = sample[.leftKnee], knee.isReliable,
                  let ankle = sample[.leftAnkle], ankle.isReliable else { return nil }
            // Check whether knee x is inside (towards center) the hip-ankle line.
            let t = (knee.y - hip.y) / max(0.001, ankle.y - hip.y)
            let lineX = hip.x + t * (ankle.x - hip.x)
            let valgus = lineX - knee.x  // in image coords, right side means "positive x"
            // For left side, left of body is smaller x in camera-facing view.
            // Valgus = knee drifts toward right (centerline), so knee.x > lineX.
            if -valgus > 0.05 {
                return "valgus_left:\(String(format: "%.3f", -valgus))"
            }
            return nil
        }
    }

    /// Right knee valgus.
    public struct KneeValgusRight: CueEvaluator {
        public let cueType: CueType = .kneeValgusRight
        public let severity: CueSeverity = .safety
        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            guard phase == .bottom || phase == .descending else { return nil }
            guard let hip = sample[.rightHip], hip.isReliable,
                  let knee = sample[.rightKnee], knee.isReliable,
                  let ankle = sample[.rightAnkle], ankle.isReliable else { return nil }
            let t = (knee.y - hip.y) / max(0.001, ankle.y - hip.y)
            let lineX = hip.x + t * (ankle.x - hip.x)
            let valgus = knee.x - lineX
            if -valgus > 0.05 {
                return "valgus_right:\(String(format: "%.3f", -valgus))"
            }
            return nil
        }
    }

    /// Torso forward: trunk leaning forward past threshold.
    public struct TorsoForward: CueEvaluator {
        public let cueType: CueType = .torsoForward
        public let severity: CueSeverity = .quality
        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            guard phase == .bottom || phase == .descending else { return nil }
            guard let shoulder = PoseGeometry.midpoint(
                sample[.leftShoulder] ?? missing,
                sample[.rightShoulder] ?? missing
            ) else { return nil }
            guard let hip = PoseGeometry.midpoint(
                sample[.leftHip] ?? missing,
                sample[.rightHip] ?? missing
            ) else { return nil }
            // Angle of shoulder-hip line vs vertical.
            let dx = shoulder.x - hip.x
            let dy = shoulder.y - hip.y
            let angleFromVertical = atan2(abs(dx), abs(dy))
            if angleFromVertical > Angle(degrees: 45).radians {
                return "torso_forward:\(Int(angleFromVertical * 180 / .pi))"
            }
            return nil
        }
    }

    /// Heel lift: inferred from ankle dorsiflexion — a hack given we don't see
    /// the shoe, but shin angle relative to vertical plus excessive forward-shift
    /// of ankle approximates it.
    public struct HeelLift: CueEvaluator {
        public let cueType: CueType = .heelLift
        public let severity: CueSeverity = .quality
        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            guard phase == .bottom else { return nil }
            guard let knee = PoseGeometry.midpoint(
                sample[.leftKnee] ?? missing,
                sample[.rightKnee] ?? missing
            ) else { return nil }
            guard let ankle = PoseGeometry.midpoint(
                sample[.leftAnkle] ?? missing,
                sample[.rightAnkle] ?? missing
            ) else { return nil }
            // If knees are significantly forward of ankles (knee.x farther from
            // torso center than ankle.x, with a large horizontal gap), we take
            // that as a heel-lift proxy.
            let horizontalGap = abs(knee.x - ankle.x)
            if horizontalGap > 0.08 {
                return "heel_lift_proxy:\(String(format: "%.3f", horizontalGap))"
            }
            return nil
        }
    }

    /// Dumbbell drift: the goblet-held dumbbell leaves the sternum area.
    /// We use the midpoint of the wrists as a proxy for the dumbbell position.
    public struct DumbbellDrift: CueEvaluator {
        public let cueType: CueType = .dumbbellDrift
        public let severity: CueSeverity = .optimization
        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            guard phase == .descending || phase == .bottom || phase == .ascending else { return nil }
            guard let wrist = PoseGeometry.midpoint(
                sample[.leftWrist] ?? missing,
                sample[.rightWrist] ?? missing
            ) else { return nil }
            guard let shoulder = PoseGeometry.midpoint(
                sample[.leftShoulder] ?? missing,
                sample[.rightShoulder] ?? missing
            ) else { return nil }
            // Expected: wrists near sternum, just below shoulders.
            // Drift = horizontal distance from shoulder midline.
            let drift = abs(wrist.x - shoulder.x)
            if drift > 0.07 {
                return "dumbbell_drift:\(String(format: "%.3f", drift))"
            }
            return nil
        }
    }
}

private let missing = Keypoint(x: 0, y: 0, confidence: 0)
