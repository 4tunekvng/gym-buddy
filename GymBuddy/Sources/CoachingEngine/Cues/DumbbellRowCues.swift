import Foundation

/// Dumbbell row (single-arm, bent over) cue catalogue.
///
/// Sources: NSCA Essentials, Ch 14 (pulling patterns); Contreras on unilateral
/// loading and anti-rotation.
public enum DumbbellRowCues {
    public static let all: [CueEvaluator] = [
        LumbarFlexion(),
        ElbowFlareRow(),
        TorsoInstability(),
        PartialRangeRowTop(),
        TempoJerkyRow()
    ]

    /// Lumbar flexion: the back rounds under load.
    public struct LumbarFlexion: CueEvaluator {
        public let cueType: CueType = .lumbarFlexion
        public let severity: CueSeverity = .safety
        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            guard phase != .idle else { return nil }
            guard let shoulder = PoseGeometry.midpoint(
                sample[.leftShoulder] ?? missing,
                sample[.rightShoulder] ?? missing
            ) else { return nil }
            guard let hip = PoseGeometry.midpoint(
                sample[.leftHip] ?? missing,
                sample[.rightHip] ?? missing
            ) else { return nil }
            // Approximate lumbar position as a midpoint between shoulder and hip.
            // Perpendicular distance of that midpoint from the shoulder-hip line
            // is always ~0 (it's on the line) — so we instead use the vertical
            // sag of the shoulder relative to a straight hinge. Proxy: shoulder
            // is meaningfully below the hip in y when back rounds forward.
            //
            // For a proper bent-over row stance, shoulder y > hip y by a small
            // amount (shoulder is lower, body is horizontal). We flag if the
            // shoulder drops much more than expected relative to the torso line
            // angle to vertical — rounding proxy:
            let torsoLenY = shoulder.y - hip.y
            let torsoLenX = shoulder.x - hip.x
            let torsoLen = (torsoLenX * torsoLenX + torsoLenY * torsoLenY).squareRoot()
            // When rounding is severe, shoulders descend with very little x-travel.
            // Ratio of |y|/length rising above 0.93 implies near-vertical shoulder
            // drop which is inconsistent with a proper hinge.
            if torsoLen > 0.05 && abs(torsoLenY) / torsoLen > 0.93 {
                return "lumbar_flexion_proxy"
            }
            return nil
        }
    }

    /// Elbow flaring out to the side instead of driving back.
    public struct ElbowFlareRow: CueEvaluator {
        public let cueType: CueType = .elbowFlareRow
        public let severity: CueSeverity = .quality
        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            guard phase == .bottom || phase == .ascending else { return nil }
            // We fire if either elbow is meaningfully outside the shoulder line
            // horizontally (x-distance > 0.08 in normalized coords).
            let shoulderSides: [(JointName, JointName)] = [
                (.leftShoulder, .leftElbow),
                (.rightShoulder, .rightElbow)
            ]
            for (s, e) in shoulderSides {
                if let shoulder = sample[s], shoulder.isReliable,
                   let elbow = sample[e], elbow.isReliable {
                    if abs(elbow.x - shoulder.x) > 0.08 {
                        return "elbow_flare_row:\(s.rawValue)"
                    }
                }
            }
            return nil
        }
    }

    /// Torso swaying (anti-rotation broken) during the pull.
    public struct TorsoInstability: CueEvaluator {
        public let cueType: CueType = .torsoInstability
        public let severity: CueSeverity = .quality
        // We look at absolute movement of the hip midpoint during ascending phase.
        // A simple per-sample filter won't suffice; we need history. Keep a small
        // ring buffer via an actor-less simple approach using per-instance state.
        public init() {}
        public let cueTypeForFixtureNaming = "torso_instability"
        private final class History {
            var hipXs: [Double] = []
            func note(_ x: Double) {
                hipXs.append(x)
                if hipXs.count > 20 { hipXs.removeFirst() }
            }
            func spread() -> Double? {
                guard let lo = hipXs.min(), let hi = hipXs.max(), hipXs.count >= 5 else { return nil }
                return hi - lo
            }
        }
        private let history = History()

        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            guard phase == .ascending || phase == .bottom else { return nil }
            guard let hip = PoseGeometry.midpoint(
                sample[.leftHip] ?? missing,
                sample[.rightHip] ?? missing
            ) else { return nil }
            history.note(hip.x)
            if let s = history.spread(), s > 0.04 {
                return "torso_instability:\(String(format: "%.3f", s))"
            }
            return nil
        }
    }

    /// Partial range at top of pull (didn't bring elbow past torso).
    public struct PartialRangeRowTop: CueEvaluator {
        public let cueType: CueType = .partialRangeRowTop
        public let severity: CueSeverity = .quality
        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            guard phase == .bottom else { return nil }
            // At the top of the pull (our FSM's .bottom for row), we want the
            // elbow angle to be well below 95°. If it's still above, the pull
            // was partial.
            let leftAngle = PoseGeometry.angle(
                at: sample[.leftElbow] ?? missing,
                between: sample[.leftShoulder] ?? missing,
                and: sample[.leftWrist] ?? missing
            )
            let rightAngle = PoseGeometry.angle(
                at: sample[.rightElbow] ?? missing,
                between: sample[.rightShoulder] ?? missing,
                and: sample[.rightWrist] ?? missing
            )
            if let a = [leftAngle, rightAngle].compactMap({ $0 }).min(by: { $0.degrees < $1.degrees }) {
                if a.degrees > 95 {
                    return "partial_row_top:\(Int(a.degrees))"
                }
            }
            return nil
        }
    }

    /// Jerky/uncontrolled eccentric — explosive drop instead of controlled lower.
    public struct TempoJerkyRow: CueEvaluator {
        public let cueType: CueType = .tempoJerkyRow
        public let severity: CueSeverity = .optimization
        public init() {}
        // We can't fully judge this from a single sample — rep-level tempo check
        // happens in TempoTracker/Orchestrator. This evaluator is the per-sample
        // placeholder that always returns nil. Keeping the type here so the
        // catalogue is complete; integrated firing happens at rep-complete time.
        public func evaluate(sample: PoseSample, phase: RepPhase) -> String? {
            nil
        }
    }
}

private let missing = Keypoint(x: 0, y: 0, confidence: 0)
