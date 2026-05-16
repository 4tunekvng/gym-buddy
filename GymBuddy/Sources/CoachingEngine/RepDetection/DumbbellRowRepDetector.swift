import Foundation

/// Rep detector for single-arm dumbbell rows (bent-over).
///
/// Primary signal: elbow-flexion angle of the working arm. We pick the arm by
/// which wrist travels more vertically over the initial observation window — if
/// only one side is reliable, we use that side.
///
/// State semantics for the row FSM:
///   - `top` phase = arm at bottom of the pull (wrist low, elbow extended)
///   - `bottom` phase = arm at top of the pull (wrist high, elbow flexed)
/// Naming keeps the FSM consistent across exercises: "descending" is always the
/// eccentric phase (returning to start), "ascending" is always the concentric
/// (driving phase). Tests cover this explicitly to prevent confusion.
public final class DumbbellRowRepDetector: RepDetector, @unchecked Sendable {
    public let exerciseId: ExerciseID = .dumbbellRow
    public private(set) var phase: RepPhase = .idle
    public private(set) var currentRepNumber: Int = 0

    private let tuning = ExerciseTuning.dumbbellRow
    private var workingSide: Side?
    private var sampleBufferForSideDetection: [(ts: TimeInterval, lWrist: Keypoint?, rWrist: Keypoint?)] = []
    private var repStartTimestamp: TimeInterval?
    private var pullTopTimestamp: TimeInterval?
    private var maxWristY: Double = -.infinity
    private var minWristY: Double = .infinity

    public enum Side { case left, right }

    public init() {}

    public func reset() {
        phase = .idle
        currentRepNumber = 0
        workingSide = nil
        sampleBufferForSideDetection.removeAll()
        repStartTimestamp = nil
        pullTopTimestamp = nil
        maxWristY = -.infinity
        minWristY = .infinity
    }

    public func observe(_ sample: PoseSample) -> RepEvent? {
        if workingSide == nil {
            establishSide(sample: sample)
            if workingSide == nil { return nil }
        }
        guard let side = workingSide else { return nil }
        guard let elbowAngle = elbowAngle(sample: sample, side: side) else { return nil }
        if let wrist = wrist(sample: sample, side: side) {
            maxWristY = max(maxWristY, wrist.y)
            minWristY = min(minWristY, wrist.y)
        }

        // Row is "inverted" in angle-vs-state mapping: the concentric (pulling
        // the dumbbell up) *reduces* the elbow angle, so "at top of pull" is
        // a small elbow angle. Our generic top/bottom names refer to rep-cycle
        // phases, not elbow positions — tests cover this mapping explicitly.
        switch phase {
        case .idle:
            if elbowAngle > tuning.repAtTop {
                phase = .top
            }
        case .top:
            if elbowAngle < tuning.repEnteringDescent {
                if repStartTimestamp == nil { repStartTimestamp = sample.timestamp }
                phase = .descending
            }
        case .descending:
            if elbowAngle < tuning.repAtBottom {
                pullTopTimestamp = sample.timestamp
                phase = .bottom
            }
        case .bottom:
            if elbowAngle > tuning.repExitingBottom {
                phase = .ascending
            }
        case .ascending:
            if elbowAngle > tuning.repAtTop {
                return finishRep(at: sample.timestamp)
            }
        }
        return nil
    }

    private func establishSide(sample: PoseSample) {
        sampleBufferForSideDetection.append((
            sample.timestamp,
            sample[.leftWrist],
            sample[.rightWrist]
        ))
        if sampleBufferForSideDetection.count < 10 { return }

        func travel(_ key: Side) -> Double {
            let values: [Double] = sampleBufferForSideDetection.compactMap {
                let k = (key == .left ? $0.lWrist : $0.rWrist)
                return (k?.isReliable ?? false) ? k?.y : nil
            }
            guard values.count >= 5, let lo = values.min(), let hi = values.max() else { return 0 }
            return hi - lo
        }

        let lt = travel(.left)
        let rt = travel(.right)
        if lt == 0 && rt == 0 { return }     // not enough reliable samples yet
        workingSide = lt >= rt ? .left : .right
    }

    private func elbowAngle(sample: PoseSample, side: Side) -> Angle? {
        let shoulder: JointName = side == .left ? .leftShoulder : .rightShoulder
        let elbow: JointName = side == .left ? .leftElbow : .rightElbow
        let wrist: JointName = side == .left ? .leftWrist : .rightWrist
        return PoseGeometry.angle(
            at: sample[elbow] ?? missing,
            between: sample[shoulder] ?? missing,
            and: sample[wrist] ?? missing
        )
    }

    private func wrist(sample: PoseSample, side: Side) -> Keypoint? {
        sample[side == .left ? .leftWrist : .rightWrist]
    }

    private func finishRep(at timestamp: TimeInterval) -> RepEvent {
        currentRepNumber += 1
        let started = repStartTimestamp ?? timestamp
        let pullTopAt = pullTopTimestamp ?? timestamp
        let concentric = max(0, pullTopAt - started)      // drive up
        let eccentric = max(0, timestamp - pullTopAt)     // lower under control
        let travel = maxWristY - minWristY
        let romScore = min(1.0, max(0.0, travel / 0.14))
        let event = RepEvent(
            exerciseId: exerciseId,
            repNumber: currentRepNumber,
            startedAt: started,
            endedAt: timestamp,
            concentricDuration: concentric,
            eccentricDuration: eccentric,
            rangeOfMotionScore: romScore,
            isPartial: romScore < tuning.partialRomThreshold
        )
        repStartTimestamp = nil
        pullTopTimestamp = nil
        maxWristY = -.infinity
        minWristY = .infinity
        phase = .top
        return event
    }

    private let missing = Keypoint(x: 0, y: 0, confidence: 0)
}
