import Foundation
import CoachingEngine
import PoseVision
import Persistence
import DesignSystem

#if os(iOS)

// Stateless helpers for `LiveSessionViewModel`, split out of the main file.
//
// Everything here is a pure `static` function — display copy, the scripted-demo
// fixtures, setup-check scaffolding, and the memory-tag / seeded-reference
// derivation. None of it reads or mutates the view model's instance state, so it
// lives cleanly in an extension. This keeps `LiveSessionViewModel.swift` focused on
// session state + lifecycle and under SwiftLint's type_body_length / file_length
// limits without disabling either rule. Per .swiftlint.yml, splitting cohesive
// lifecycle logic just to satisfy a line count would be busywork — but lifting out
// genuinely stateless helpers is a real separation, not that.
extension LiveSessionViewModel {

    static func fallbackErrorMessage(for error: Error) -> String {
        if let posed = error as? PoseDetectionError {
            switch posed {
            case .cameraPermissionDenied:
                return "Camera permission was denied."
            case .cameraUnavailable:
                return "No usable camera was found."
            case .sessionConfigurationFailed(let reason):
                return "Camera setup failed (\(reason))."
            case .alreadyStarted:
                return "Camera preview is already running."
            case .notStarted:
                return "Camera preview never started."
            }
        }
        return "The live camera path failed to start."
    }

    static func cueDisplayText(for cue: CueEvent) -> String {
        switch cue.cueType {
        case .hipSag: return "Flatten the hips"
        case .hipPike: return "Drop the hips"
        case .elbowFlare: return "Tuck the elbows"
        case .partialRangeBottom: return "Chest to the floor"
        case .partialRangeTop: return "Lock it out"
        case .headPositionBad: return "Keep the neck neutral"
        case .squatShallow: return "Hit depth"
        case .kneeValgusLeft, .kneeValgusRight: return "Drive the knees out"
        case .torsoForward: return "Chest up"
        case .heelLift: return "Heels down"
        case .dumbbellDrift: return "Dumbbell to sternum"
        case .lumbarFlexion: return "Flat back"
        case .elbowFlareRow: return "Elbow back, not out"
        case .torsoInstability: return "Steady torso"
        case .partialRangeRowTop: return "Pull past the torso"
        case .tempoJerkyRow: return "Control the lower"
        default: return "Hold the form"
        }
    }

    static func encouragementDisplayText(for kind: CoachingIntent.EncouragementKind) -> String {
        switch kind {
        case .pushThrough: return "Push through"
        case .oneMore: return "One more"
        case .drive: return "Drive"
        case .lastOne: return "Last one"
        case .steady: return "Steady"
        case .validate: return "There we go"
        }
    }

    static func demoFixture(for exerciseId: ExerciseID) -> [PoseSample] {
        switch exerciseId {
        case .pushUp:
            return SyntheticPoseGenerator.pushUps(
                repCount: 13,
                baselineCycleSeconds: 1.7,
                fatigueRamp: (startRep: 8, endRep: 13, multiplier: 1.9),
                partialReps: [],
                sampleRateHz: 30
            )
        case .gobletSquat:
            return SyntheticPoseGenerator.gobletSquats(repCount: 8, cycleSeconds: 2.4)
        case .dumbbellRow:
            return SyntheticPoseGenerator.dumbbellRows(repCount: 10, cycleSeconds: 2.2)
        }
    }

    static func makeSetupChecks() -> [SetupOverlay.Check] {
        [
            .init(id: .angle, passing: false),
            .init(id: .distance, passing: false),
            .init(id: .lighting, passing: false),
            .init(id: .fullBody, passing: false)
        ]
    }

    static func scriptedDemoFrameInterval(playbackRate: Double) -> TimeInterval {
        let clampedRate = max(0.25, min(playbackRate, 8.0))
        return (1.0 / 30.0) / clampedRate
    }

    static func memoryTags(for exerciseId: ExerciseID, profile: UserProfile?) -> Set<String> {
        var tags: Set<String> = [
            MemoryTag.preference.rawValue,
            MemoryTag.injury.rawValue
        ]

        switch exerciseId {
        case .pushUp:
            tags.formUnion([MemoryTag.bodyPartShoulder.rawValue, MemoryTag.bodyPartElbow.rawValue])
        case .gobletSquat:
            tags.formUnion([MemoryTag.bodyPartKnee.rawValue, MemoryTag.bodyPartBack.rawValue])
        case .dumbbellRow:
            tags.formUnion([MemoryTag.bodyPartBack.rawValue, MemoryTag.bodyPartShoulder.rawValue, MemoryTag.bodyPartElbow.rawValue])
        }

        if let profile {
            for tag in profile.injuryBodyParts {
                tags.insert(tag.rawValue)
            }
        }
        return tags
    }

    static func seededReferences(from profile: UserProfile?) -> [String] {
        guard let profile else { return [] }

        var notes: [String] = [
            "Goal: \(profile.goal.rawValue).",
            "Coaching tone: \(profile.tone.displayName)."
        ]
        notes.append(contentsOf: seededInjuryReferences(from: profile))
        return notes
    }

    static func seededInjuryReferences(from profile: UserProfile?) -> [String] {
        guard let profile else { return [] }
        return profile.injuryBodyParts.map {
            switch $0 {
            case .bodyPartKnee:
                return "Watch the knee and keep the reps honest."
            case .bodyPartShoulder:
                return "Shoulder history noted — keep the pressing clean."
            case .bodyPartBack:
                return "Back history noted — stay organized through the torso."
            case .bodyPartElbow:
                return "Elbow history noted — keep the arm path clean."
            default:
                return "Movement history noted."
            }
        }
    }
}

#endif
