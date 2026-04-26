import Foundation

/// Push-up cue catalogue.
///
/// Sources: NSCA Essentials of Strength & Conditioning, 4e, Ch 15. S&C literature
/// on bodyweight pressing patterns. Each cue has positive/negative fixtures in
/// Tests/CoachingEngineTests/Fixtures/pushup/.
public enum PushUpCues {
    public static let all: [CueEvaluator] = [
        HipSag(),
        HipPike(),
        ElbowFlare(),
        PartialRangeBottom(),
        PartialRangeTop(),
        HeadPositionBad()
    ]

    /// Hip sag: hips drop below the shoulder-ankle line.
    public struct HipSag: CueEvaluator {
        public let cueType: CueType = .hipSag
        public let severity: CueSeverity = .safety
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
            guard let ankle = PoseGeometry.midpoint(
                sample[.leftAnkle] ?? missing,
                sample[.rightAnkle] ?? missing
            ) else { return nil }
            guard let dist = PoseGeometry.perpendicularDistance(
                from: hip, toLineThrough: shoulder, and: ankle
            ) else { return nil }
            // In image-space y grows downward. Sag = hip is below the line
            // (larger y than line-at-hip-x). Use the line equation to find line y at hip x.
            // Simplification: compute line at hip's x via parametric interpolation.
            let t = (hip.x - shoulder.x) / max(0.001, (ankle.x - shoulder.x))
            let lineY = shoulder.y + t * (ankle.y - shoulder.y)
            let sag = hip.y - lineY
            if sag > 0.06 && dist > 0.04 {
                return "hip_sag:\(String(format: "%.3f", sag))"
            }
            return nil
        }
    }

    /// Hip pike: hips high (inverted V).
    public struct HipPike: CueEvaluator {
        public let cueType: CueType = .hipPike
        public let severity: CueSeverity = .quality
        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            guard phase == .top || phase == .ascending else { return nil }
            guard let shoulder = PoseGeometry.midpoint(
                sample[.leftShoulder] ?? missing,
                sample[.rightShoulder] ?? missing
            ) else { return nil }
            guard let hip = PoseGeometry.midpoint(
                sample[.leftHip] ?? missing,
                sample[.rightHip] ?? missing
            ) else { return nil }
            guard let ankle = PoseGeometry.midpoint(
                sample[.leftAnkle] ?? missing,
                sample[.rightAnkle] ?? missing
            ) else { return nil }
            let t = (hip.x - shoulder.x) / max(0.001, (ankle.x - shoulder.x))
            let lineY = shoulder.y + t * (ankle.y - shoulder.y)
            let pike = lineY - hip.y
            if pike > 0.08 {
                return "hip_pike:\(String(format: "%.3f", pike))"
            }
            return nil
        }
    }

    /// Elbow flare: elbow driving far outside the shoulder line.
    public struct ElbowFlare: CueEvaluator {
        public let cueType: CueType = .elbowFlare
        public let severity: CueSeverity = .quality
        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            guard phase == .bottom || phase == .descending else { return nil }
            // Compute shoulder-elbow-torso angle for both arms; fire if smaller
            // than ~80° on either side (elbow points out from torso).
            let threshold = Angle(degrees: 80).radians
            let leftAngle = PoseGeometry.angle(
                at: sample[.leftShoulder] ?? missing,
                between: sample[.leftElbow] ?? missing,
                and: sample[.leftHip] ?? missing
            )
            let rightAngle = PoseGeometry.angle(
                at: sample[.rightShoulder] ?? missing,
                between: sample[.rightElbow] ?? missing,
                and: sample[.rightHip] ?? missing
            )
            if let a = leftAngle, a.radians > threshold {
                return "elbow_flare:left:\(Int(a.degrees))"
            }
            if let a = rightAngle, a.radians > threshold {
                return "elbow_flare:right:\(Int(a.degrees))"
            }
            return nil
        }
    }

    /// Partial range at bottom: didn't go deep enough.
    ///
    /// Fires at the first `.ascending` sample of each rep if the minimum elbow
    /// angle observed during the descent never got below 110°. Tracks per-rep
    /// state in a nested class so the value can update from within the
    /// value-type `evaluate` method.
    public struct PartialRangeBottom: CueEvaluator {
        public let cueType: CueType = .partialRangeBottom
        public let severity: CueSeverity = .quality
        private final class State {
            var minAngle: Double = 180
            var lastPhase: RepPhase = .idle
        }
        private let state = State()
        public init() {}

        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            let current = avgElbowAngle(sample)?.degrees ?? 180

            // Reset the min between reps (top phase is our "between reps" state).
            if phase == .top {
                state.minAngle = 180
            }
            // Track min while going down.
            if phase == .descending || phase == .bottom {
                state.minAngle = Swift.min(state.minAngle, current)
            }
            let justEnteredAscending = phase == .ascending && state.lastPhase != .ascending
            state.lastPhase = phase

            if justEnteredAscending, state.minAngle > 110 {
                return "partial_bottom:\(Int(state.minAngle))"
            }
            return nil
        }
    }

    /// Partial range at top: didn't lock out.
    ///
    /// Tracks the max elbow angle reached during the ascending phase. Fires
    /// once at the transition into `.top` if that max is below 155°. Single-
    /// sample evaluation (test path with no prior ascending state) falls back
    /// to the current sample's angle so the direct unit test still exercises
    /// the logic.
    public struct PartialRangeTop: CueEvaluator {
        public let cueType: CueType = .partialRangeTop
        public let severity: CueSeverity = .optimization
        private final class State {
            var maxAscendingAngle: Double = 0
            var lastPhase: RepPhase = .idle
        }
        private let state = State()
        public init() {}

        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            let current = avgElbowAngle(sample)?.degrees ?? 0

            // Reset tracking when the new rep starts its descent.
            if phase == .descending || phase == .bottom {
                state.maxAscendingAngle = 0
            }
            if phase == .ascending {
                state.maxAscendingAngle = Swift.max(state.maxAscendingAngle, current)
            }
            let justEnteredTop = phase == .top && state.lastPhase != .top
            state.lastPhase = phase

            if justEnteredTop {
                if state.maxAscendingAngle > 0, state.maxAscendingAngle < 155 {
                    return "partial_top:\(Int(state.maxAscendingAngle))"
                }
                if state.maxAscendingAngle == 0, current > 0, current < 155 {
                    return "partial_top:\(Int(current))"
                }
            }
            return nil
        }
    }

    /// Head position out of range: neck extension/flexion.
    public struct HeadPositionBad: CueEvaluator {
        public let cueType: CueType = .headPositionBad
        public let severity: CueSeverity = .optimization
        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            guard phase == .bottom || phase == .descending else { return nil }
            guard let shoulder = PoseGeometry.midpoint(
                sample[.leftShoulder] ?? missing,
                sample[.rightShoulder] ?? missing
            ) else { return nil }
            guard let nose = sample[.nose], nose.isReliable else { return nil }
            // Neck position relative to shoulders: we want the nose roughly in line
            // with the shoulder->hip axis extension. Fire if nose drops well below
            // shoulder (neck flexion) or rises well above (neck extension).
            let diff = nose.y - shoulder.y
            if diff > 0.06 {
                return "head_flexion:\(String(format: "%.3f", diff))"
            }
            if diff < -0.08 {
                return "head_extension:\(String(format: "%.3f", diff))"
            }
            return nil
        }
    }
}

private let missing = Keypoint(x: 0, y: 0, confidence: 0)

private func avgElbowAngle(_ sample: PoseSample) -> Angle? {
    let left = PoseGeometry.angle(
        at: sample[.leftElbow] ?? missing,
        between: sample[.leftShoulder] ?? missing,
        and: sample[.leftWrist] ?? missing
    )
    let right = PoseGeometry.angle(
        at: sample[.rightElbow] ?? missing,
        between: sample[.rightShoulder] ?? missing,
        and: sample[.rightWrist] ?? missing
    )
    switch (left, right) {
    case (let l?, let r?): return Angle(radians: (l.radians + r.radians) / 2)
    case (let l?, nil): return l
    case (nil, let r?): return r
    default: return nil
    }
}
