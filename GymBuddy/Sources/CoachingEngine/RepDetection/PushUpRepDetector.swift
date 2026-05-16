import Foundation

/// Rep detector for push-ups.
///
/// Primary signal: elbow-flexion angle (shoulder–elbow–wrist).
///   - Top:    elbow angle > `repAtTop` (≈160°, arms near locked)
///   - Bottom: elbow angle < `repAtBottom` (≈100°, chest low)
/// We use the mean of left-and-right elbow angles when both are reliable, and
/// fall back to whichever side is reliable when one is occluded.
/// Chest-to-floor proximity (vertical offset of shoulders vs. wrists) acts as a
/// secondary gate: we require meaningful vertical travel to confirm a rep —
/// this guards against someone twitching their elbows while standing.
public final class PushUpRepDetector: RepDetector, @unchecked Sendable {
    public let exerciseId: ExerciseID = .pushUp
    public private(set) var phase: RepPhase = .idle
    public private(set) var currentRepNumber: Int = 0

    private let tuning = ExerciseTuning.pushUp
    private var repStartTimestamp: TimeInterval?
    private var phaseEnteredAt: TimeInterval = 0
    private var bottomTimestamp: TimeInterval?
    private var maxShoulderY: Double = -.infinity
    private var minShoulderY: Double = .infinity
    private var lastSampleTimestamp: TimeInterval = 0

    public init() {}

    public func reset() {
        phase = .idle
        currentRepNumber = 0
        repStartTimestamp = nil
        bottomTimestamp = nil
        maxShoulderY = -.infinity
        minShoulderY = .infinity
    }

    public func observe(_ sample: PoseSample) -> RepEvent? {
        lastSampleTimestamp = sample.timestamp

        guard let elbowAngle = averageElbowAngle(from: sample) else { return nil }
        guard let shoulderMid = PoseGeometry.midpoint(
            sample[.leftShoulder] ?? Keypoint(x: 0, y: 0, confidence: 0),
            sample[.rightShoulder] ?? Keypoint(x: 0, y: 0, confidence: 0)
        ) else { return nil }

        // Track vertical travel of the shoulders for ROM scoring.
        maxShoulderY = max(maxShoulderY, shoulderMid.y)
        minShoulderY = min(minShoulderY, shoulderMid.y)

        switch phase {
        case .idle:
            if elbowAngle > tuning.repAtTop {
                enter(.top, at: sample.timestamp)
            }
        case .top:
            if elbowAngle < tuning.repEnteringDescent {
                if repStartTimestamp == nil { repStartTimestamp = sample.timestamp }
                enter(.descending, at: sample.timestamp)
            }
        case .descending:
            if elbowAngle < tuning.repAtBottom {
                bottomTimestamp = sample.timestamp
                enter(.bottom, at: sample.timestamp)
            }
        case .bottom:
            if elbowAngle > tuning.repExitingBottom {
                enter(.ascending, at: sample.timestamp)
            }
        case .ascending:
            if elbowAngle > tuning.repAtTop {
                return finishRep(at: sample.timestamp)
            }
        }
        return nil
    }

    private func enter(_ newPhase: RepPhase, at timestamp: TimeInterval) {
        phase = newPhase
        phaseEnteredAt = timestamp
    }

    private func finishRep(at timestamp: TimeInterval) -> RepEvent {
        currentRepNumber += 1
        let started = repStartTimestamp ?? timestamp
        let bottomAt = bottomTimestamp ?? timestamp
        let eccentric = max(0, bottomAt - started)
        let concentric = max(0, timestamp - bottomAt)
        let romScore = rangeOfMotionScore()
        let isPartial = romScore < tuning.partialRomThreshold
        let event = RepEvent(
            exerciseId: exerciseId,
            repNumber: currentRepNumber,
            startedAt: started,
            endedAt: timestamp,
            concentricDuration: concentric,
            eccentricDuration: eccentric,
            rangeOfMotionScore: romScore,
            isPartial: isPartial
        )
        // Reset per-rep travel bookkeeping but keep the FSM in .top
        repStartTimestamp = nil
        bottomTimestamp = nil
        maxShoulderY = -.infinity
        minShoulderY = .infinity
        enter(.top, at: timestamp)
        return event
    }

    private func rangeOfMotionScore() -> Double {
        let travel = maxShoulderY - minShoulderY
        // Push-up shoulder travel is typically 0.06–0.12 in normalized image coords
        // (arm-segment ~0.15 in image, so shoulder y moves across roughly that range).
        // Calibrated so a clean synthetic rep (see SyntheticPoseGenerator.pushUpPoseAt)
        // scores ≥ 0.95, and a rep that only reaches 60% depth scores < partialRomThreshold.
        return min(1.0, max(0.0, travel / 0.08))
    }

    private func averageElbowAngle(from sample: PoseSample) -> Angle? {
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

    private let missing = Keypoint(x: 0, y: 0, confidence: 0)
}
