import Foundation
import CoachingEngine

#if canImport(AVFoundation) && !os(macOS)
import AVFoundation

public protocol CameraPreviewProviding: AnyObject {
    var previewSession: AVCaptureSession { get }
}
#endif

public struct SetupEvaluation: Equatable, Sendable {
    public let angleOkay: Bool
    public let distanceOkay: Bool
    public let lightingOkay: Bool
    public let fullBodyOkay: Bool
    public let guidance: String?

    public init(
        angleOkay: Bool,
        distanceOkay: Bool,
        lightingOkay: Bool,
        fullBodyOkay: Bool,
        guidance: String?
    ) {
        self.angleOkay = angleOkay
        self.distanceOkay = distanceOkay
        self.lightingOkay = lightingOkay
        self.fullBodyOkay = fullBodyOkay
        self.guidance = guidance
    }

    public var allPassing: Bool {
        angleOkay && distanceOkay && lightingOkay && fullBodyOkay
    }
}

public enum SetupEvaluator {
    public static func evaluate(sample: PoseSample, exerciseId: ExerciseID) -> SetupEvaluation {
        let required = requiredJoints(for: exerciseId)
        let visiblePoints = required.compactMap { joint -> Keypoint? in
            guard let point = sample[joint], point.isReliable else { return nil }
            return point
        }

        let fullBodyOkay = visiblePoints.count == required.count && isInsideFrame(visiblePoints)
        let distanceOkay = fullBodyOkay && distanceLooksReasonable(visiblePoints, exerciseId: exerciseId)
        let lightingOkay = averageConfidence(visiblePoints) >= 0.72
        let angleOkay = fullBodyOkay && angleLooksReasonable(visiblePoints, sample: sample, exerciseId: exerciseId)

        return SetupEvaluation(
            angleOkay: angleOkay,
            distanceOkay: distanceOkay,
            lightingOkay: lightingOkay,
            fullBodyOkay: fullBodyOkay,
            guidance: guidance(
                angleOkay: angleOkay,
                distanceOkay: distanceOkay,
                lightingOkay: lightingOkay,
                fullBodyOkay: fullBodyOkay,
                exerciseId: exerciseId
            )
        )
    }

    private static func requiredJoints(for exerciseId: ExerciseID) -> [JointName] {
        switch exerciseId {
        case .pushUp:
            return [.nose, .leftShoulder, .leftHip, .leftKnee, .leftAnkle, .leftElbow, .leftWrist]
        case .gobletSquat, .dumbbellRow:
            return [.nose, .leftShoulder, .rightShoulder, .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle]
        }
    }

    private static func isInsideFrame(_ points: [Keypoint]) -> Bool {
        guard let bounds = bounds(for: points) else { return false }
        return bounds.minX >= 0.03 && bounds.maxX <= 0.97 && bounds.minY >= 0.03 && bounds.maxY <= 0.97
    }

    private static func distanceLooksReasonable(_ points: [Keypoint], exerciseId: ExerciseID) -> Bool {
        guard let bounds = bounds(for: points) else { return false }
        let width = bounds.maxX - bounds.minX
        let height = bounds.maxY - bounds.minY

        switch exerciseId {
        case .pushUp:
            return width >= 0.42 && width <= 0.92 && height >= 0.15 && height <= 0.55
        case .gobletSquat, .dumbbellRow:
            return height >= 0.40 && height <= 0.92 && width >= 0.04 && width <= 0.72
        }
    }

    private static func angleLooksReasonable(
        _ points: [Keypoint],
        sample: PoseSample,
        exerciseId: ExerciseID
    ) -> Bool {
        guard let bounds = bounds(for: points) else { return false }
        let width = bounds.maxX - bounds.minX
        let height = bounds.maxY - bounds.minY

        switch exerciseId {
        case .pushUp:
            return width > height * 1.2
        case .gobletSquat:
            guard
                let leftShoulder = sample[.leftShoulder],
                let rightShoulder = sample[.rightShoulder],
                leftShoulder.isReliable,
                rightShoulder.isReliable
            else {
                return false
            }
            return abs(leftShoulder.y - rightShoulder.y) <= 0.12 && height > width
        case .dumbbellRow:
            guard
                let leftShoulder = sample[.leftShoulder],
                let rightShoulder = sample[.rightShoulder],
                let leftHip = sample[.leftHip],
                let rightHip = sample[.rightHip],
                leftShoulder.isReliable,
                rightShoulder.isReliable,
                leftHip.isReliable,
                rightHip.isReliable
            else {
                return false
            }
            let shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2
            let hipMidY = (leftHip.y + rightHip.y) / 2
            return hipMidY - shoulderMidY <= 0.18 && height >= 0.28
        }
    }

    private static func averageConfidence(_ points: [Keypoint]) -> Double {
        guard !points.isEmpty else { return 0 }
        return points.map(\.confidence).reduce(0, +) / Double(points.count)
    }

    private static func bounds(for points: [Keypoint]) -> (minX: Double, maxX: Double, minY: Double, maxY: Double)? {
        guard !points.isEmpty else { return nil }
        return (
            minX: points.map(\.x).min() ?? 0,
            maxX: points.map(\.x).max() ?? 0,
            minY: points.map(\.y).min() ?? 0,
            maxY: points.map(\.y).max() ?? 0
        )
    }

    private static func guidance(
        angleOkay: Bool,
        distanceOkay: Bool,
        lightingOkay: Bool,
        fullBodyOkay: Bool,
        exerciseId: ExerciseID
    ) -> String? {
        if !fullBodyOkay {
            return "Shift until your head, shoulders, hips, knees, and ankles are all visible."
        }
        if !distanceOkay {
            switch exerciseId {
            case .pushUp:
                return "Slide the phone back a touch so your whole push-up fits in frame."
            case .gobletSquat, .dumbbellRow:
                return "Step back until your full body fits comfortably in the frame."
            }
        }
        if !lightingOkay {
            return "Move into brighter light so pose tracking can lock on."
        }
        if !angleOkay {
            switch exerciseId {
            case .pushUp:
                return "Turn the phone to your side so I get a clean side view of the push-up."
            case .gobletSquat:
                return "Keep the phone more level with your torso for a straighter squat view."
            case .dumbbellRow:
                return "Raise or level the phone a bit so I can see your torso position clearly."
            }
        }
        return "I can see you clearly. Start when you're ready."
    }
}
