import Foundation

/// Rep detector for goblet squats.
///
/// Primary signal: knee-flexion angle (hip–knee–ankle), mean of both sides.
///   - Top:    knee angle > `repAtTop` (near standing, legs straight-ish)
///   - Bottom: knee angle < `repAtBottom` (deep squat)
/// ROM score uses vertical travel of the hip midpoint.
public final class GobletSquatRepDetector: RepDetector, @unchecked Sendable {
    public let exerciseId: ExerciseID = .gobletSquat
    public private(set) var phase: RepPhase = .idle
    public private(set) var currentRepNumber: Int = 0

    private let tuning = ExerciseTuning.gobletSquat
    private var repStartTimestamp: TimeInterval?
    private var bottomTimestamp: TimeInterval?
    private var maxHipY: Double = -.infinity
    private var minHipY: Double = .infinity

    public init() {}

    public func reset() {
        phase = .idle
        currentRepNumber = 0
        repStartTimestamp = nil
        bottomTimestamp = nil
        maxHipY = -.infinity
        minHipY = .infinity
    }

    public func observe(_ sample: PoseSample) -> RepEvent? {
        guard let kneeAngle = averageKneeAngle(from: sample) else { return nil }
        if let hip = hipMid(from: sample) {
            maxHipY = max(maxHipY, hip.y)
            minHipY = min(minHipY, hip.y)
        }

        switch phase {
        case .idle:
            if kneeAngle > tuning.repAtTop {
                phase = .top
            }
        case .top:
            if kneeAngle < tuning.repEnteringDescent {
                if repStartTimestamp == nil { repStartTimestamp = sample.timestamp }
                phase = .descending
            }
        case .descending:
            if kneeAngle < tuning.repAtBottom {
                bottomTimestamp = sample.timestamp
                phase = .bottom
            }
        case .bottom:
            if kneeAngle > tuning.repExitingBottom {
                phase = .ascending
            }
        case .ascending:
            if kneeAngle > tuning.repAtTop {
                return finishRep(at: sample.timestamp)
            }
        }
        return nil
    }

    private func finishRep(at timestamp: TimeInterval) -> RepEvent {
        currentRepNumber += 1
        let started = repStartTimestamp ?? timestamp
        let bottomAt = bottomTimestamp ?? timestamp
        let eccentric = max(0, bottomAt - started)
        let concentric = max(0, timestamp - bottomAt)
        let travel = maxHipY - minHipY
        let romScore = min(1.0, max(0.0, travel / 0.18))
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
        repStartTimestamp = timestamp
        bottomTimestamp = nil
        maxHipY = -.infinity
        minHipY = .infinity
        phase = .top
        return event
    }

    private func averageKneeAngle(from sample: PoseSample) -> Angle? {
        let left = PoseGeometry.angle(
            at: sample[.leftKnee] ?? missing,
            between: sample[.leftHip] ?? missing,
            and: sample[.leftAnkle] ?? missing
        )
        let right = PoseGeometry.angle(
            at: sample[.rightKnee] ?? missing,
            between: sample[.rightHip] ?? missing,
            and: sample[.rightAnkle] ?? missing
        )
        switch (left, right) {
        case (let l?, let r?): return Angle(radians: (l.radians + r.radians) / 2)
        case (let l?, nil): return l
        case (nil, let r?): return r
        default: return nil
        }
    }

    private func hipMid(from sample: PoseSample) -> Keypoint? {
        PoseGeometry.midpoint(
            sample[.leftHip] ?? missing,
            sample[.rightHip] ?? missing
        )
    }

    private let missing = Keypoint(x: 0, y: 0, confidence: 0)
}
