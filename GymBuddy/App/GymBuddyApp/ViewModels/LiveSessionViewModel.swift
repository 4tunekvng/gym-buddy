import Foundation
import Combine
import CoachingEngine
import PoseVision
import VoiceIO
import Persistence
import Telemetry
import DesignSystem

#if os(iOS)

/// Drives a single live set. Bridges the async PoseVision stream into a
/// SwiftUI-observable model without exposing the engine types to views.
///
/// Lifecycle:
///   1. `init` — configure the orchestrator and remember the composition.
///   2. `completeSetupAndStart` — SetupOverlay is presented until this is called.
///      Flips the four setup checks green and tries the composition's pose
///      detector. If `start()` fails (always true in the Simulator since it
///      has no camera, also true if the user denied camera permission), we fall
///      back to a synthetic fixture stream so the user still sees the full
///      coaching flow. The failure reason is surfaced in `errorMessage`.
///   3. Pose frames arrive → orchestrator emits intents → we update UI state
///      (rep count, cue text, encouragement) and ask the voice mapper to play
///      the cached phrase.
///   4. `setEnded` fires (auto from stillness, or `finishExplicitly` from the
///      user tapping "End set") → we stop the detector, persist a
///      `WorkoutSessionRecord` so History reflects reality next launch, write
///      a `sessionEnded` telemetry event, and call `onFinish(observation)` so
///      the router can hand the observation to the post-session view.
///
/// Concurrency:
///   - Pose consumption runs on a detached Task.
///   - UI-bound @Published properties are mutated via MainActor.run.
@MainActor
final class LiveSessionViewModel: ObservableObject {

    // MARK: - Published UI state

    @Published var repCount: Int = 0
    @Published var cueText: String?
    @Published var isPartialRep: Bool = false
    @Published var isSetupComplete: Bool = false
    @Published var lastEncouragement: String?
    /// What the coach would have said audibly on the most recent intent. The
    /// MVP voice player is a mock (real ElevenLabs cache lands in M3), so the
    /// simulator path renders this on-screen as a "speech bubble" — that way
    /// the user can SEE the rep counts and encouragements that would otherwise
    /// be silent. On a real device with audio wired this just mirrors what's
    /// spoken aloud.
    @Published var lastSpokenPhrase: String?
    /// True when we're consuming the synthetic demo fixture (no real camera).
    /// The Live HUD shows a small banner so the user understands what they're
    /// watching is a scripted preview.
    @Published var isRunningDemoFixture: Bool = false
    // MVP: all four framing checks start green so the user can tap "Start set".
    // The real M2 work is pose-driven — each check will go red until the user is
    // actually framed correctly. For now we present them as already-passing so
    // the flow doesn't stall on a button the user can't enable.
    @Published var setupChecks: [SetupOverlay.Check] = [
        .init(id: .angle, passing: true),
        .init(id: .distance, passing: true),
        .init(id: .lighting, passing: true),
        .init(id: .fullBody, passing: true)
    ]
    @Published var isFinished: Bool = false
    @Published var errorMessage: String?

    // MARK: - Inputs

    let exerciseId: ExerciseID
    let setNumber: Int
    let tone: CoachingTone

    // MARK: - Collaborators

    private let composition: AppComposition
    private let onFinishCallback: (SessionObservation) -> Void
    private let onCancelCallback: () -> Void
    private let orchestrator: SessionOrchestrator
    private let sessionId = UUID()

    // MARK: - Runtime state

    private var detector: PoseDetecting?
    private var consumeTask: Task<Void, Never>?
    private var mapper: IntentToVoiceMapper?
    private var didFinish = false

    // MARK: - Init

    init(
        composition: AppComposition,
        exerciseId: ExerciseID,
        setNumber: Int,
        tone: CoachingTone,
        memoryReferences: [String],
        userId: UUID,
        onFinish: @escaping (SessionObservation) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.composition = composition
        self.exerciseId = exerciseId
        self.setNumber = setNumber
        self.tone = tone
        self.onFinishCallback = onFinish
        self.onCancelCallback = onCancel
        let context = SessionContext(
            userId: userId,
            tone: tone,
            priorSessionBestReps: [:],
            activeInjuryNotes: [],
            memoryReferences: memoryReferences
        )
        let config = SessionConfig(
            exerciseId: exerciseId,
            setNumber: setNumber,
            targetReps: nil,
            tone: tone
        )
        self.orchestrator = SessionOrchestrator(config: config, context: context)
    }

    // MARK: - User-driven events

    /// Called from the SetupOverlay's "Start set" button. In MVP the four checks
    /// are marked pass-through immediately; the real "framing OK?" logic lands
    /// in M2 when we have live pose. After flipping them green, we start the
    /// detector (with fallback) and begin consuming pose frames.
    func completeSetupAndStart() async {
        if isSetupComplete { return }
        setupChecks = setupChecks.map { SetupOverlay.Check(id: $0.id, passing: true) }
        isSetupComplete = true

        await logTelemetry(.sessionStarted(
            exerciseId: exerciseId.rawValue,
            setNumber: setNumber,
            plannedReps: nil
        ))

        await startDetectorWithFallback()
    }

    /// User tapped "End set" before the stillness detector auto-ended.
    func finishExplicitly() async {
        let intents = orchestrator.finishSetExplicitly(reason: .userTapped)
        for intent in intents { await handle(intent: intent) }
        await completeLifecycle()
    }

    /// User tapped cancel before the session could start. No observation saved.
    func cancel() async {
        consumeTask?.cancel()
        await detector?.stop()
        onCancelCallback()
    }

    // MARK: - Detector start with graceful fallback

    private func startDetectorWithFallback() async {
        mapper = IntentToVoiceMapper(
            tone: tone,
            cache: composition.phraseCache,
            voice: composition.voicePlayer
        )

        let primary = composition.poseDetectorFactory()
        // Composition routes to a FixturePoseDetector on the iOS Simulator
        // (no camera). Mark demo mode upfront so the UI shows a banner even
        // when we don't fall through the catch path below.
        if primary is FixturePoseDetector {
            isRunningDemoFixture = true
        }
        do {
            try await primary.start()
            self.detector = primary
            consume(stream: primary.bodyStateStream())
        } catch {
            await primary.stop()
            // Surface the real reason and continue with a demo stream so the
            // session still plays out. The user can retry on a real device.
            errorMessage = Self.fallbackErrorMessage(for: error)

            // Realtime playback (1/30s per frame). This used to run at 3× speed
            // for a snappy XCUITest demo, but a real user staring at the
            // Simulator wants to SEE the rep counter tick up and the
            // encouragements appear. 30 fps matches what the on-device camera
            // would feed.
            let fallback = FixturePoseDetector(
                samples: Self.demoFixture(for: exerciseId),
                frameInterval: 1.0 / 30.0
            )
            do {
                try await fallback.start()
                self.detector = fallback
                isRunningDemoFixture = true
                consume(stream: fallback.bodyStateStream())
            } catch {
                errorMessage = "Session failed to start: \(error.localizedDescription)"
            }
        }
    }

    private func consume(stream: BodyStateStream) {
        consumeTask = Task.detached { [weak self] in
            for await state in stream {
                guard let self else { break }
                guard case .pose(let sample) = state else { continue }
                let intents = await MainActor.run { self.orchestrator.observe(sample: sample) }
                for intent in intents {
                    await self.handle(intent: intent)
                }
            }
            // Stream finished. Fixture detector ends after the last sample; if
            // that happens without a set-end intent (edge case — fixture didn't
            // have enough stillness tail), we finalize ourselves so the UI
            // always progresses to the post-session summary.
            guard let self else { return }
            let finished = await MainActor.run { self.isFinished }
            if !finished {
                await self.completeLifecycle()
            }
        }
    }

    // MARK: - Intent handling

    private func handle(intent: CoachingIntent) async {
        switch intent {
        case .sayRepCount(let n, _):
            await MainActor.run {
                repCount = n
                isPartialRep = false
                cueText = nil   // clear last rep's cue
                lastSpokenPhrase = "\(n)"
            }
            _ = try? await mapper?.route(intent)
            await logTelemetry(.voicePlayed(tier: 1, phraseId: "rep.\(n)", variantIndex: 0, latency_ms: 0))

        case .formCue(let cue):
            let text = Self.cueDisplayText(for: cue)
            await MainActor.run {
                cueText = text
                // Form cues are surfaced on-screen visually, not voiced in MVP
                // (PRD §5.1: at most one audio phrase per rep — already used by
                // the rep count). So we don't update lastSpokenPhrase here.
            }
            _ = try? await mapper?.route(intent)
            await logTelemetry(.cueFired(
                exerciseId: cue.exerciseId.rawValue,
                cueType: cue.cueType.rawValue,
                severity: cue.severity.rawValue,
                latency_ms: 0
            ))

        case .encouragement(let kind, _, _):
            let text = Self.encouragementDisplayText(for: kind)
            await MainActor.run {
                lastEncouragement = text
                lastSpokenPhrase = text
            }
            _ = try? await mapper?.route(intent)

        case .painStop(let trigger):
            _ = try? await mapper?.route(intent)
            await logTelemetry(.safetyPainDetected(source: trigger))
            await completeLifecycle()

        case .setEnded:
            await completeLifecycle()

        case .startRest, .contextualSpeech:
            break
        }
    }

    private func completeLifecycle() async {
        if didFinish { return }
        didFinish = true
        consumeTask?.cancel()
        await detector?.stop()
        let observation = orchestrator.buildObservation()

        // Persist immediately so History reflects reality on next load.
        let record = WorkoutSessionRecord.build(
            from: [observation],
            painFlag: observation.endEvent.reason == .painPause,
            summary: nil
        )
        try? await composition.sessionRepo.record(record)

        let duration: Double = {
            guard let first = observation.repEvents.first, let last = observation.repEvents.last
            else { return 0 }
            return last.endedAt - first.startedAt
        }()
        await logTelemetry(.sessionEnded(
            exerciseId: exerciseId.rawValue,
            setNumber: setNumber,
            actualReps: observation.totalReps,
            duration_s: duration,
            endReason: observation.endEvent.reason.rawValue
        ))

        isFinished = true
        onFinishCallback(observation)
    }

    private func logTelemetry(_ kind: EventKind) async {
        await composition.telemetry.log(
            TelemetryEvent(kind: kind, sessionIdRef: sessionId)
        )
    }

    // MARK: - Display helpers (static so tests don't need an instance)

    /// Friendly error message for when the primary pose detector fails to start.
    /// Pulled out so unit tests can exercise the branching without constructing
    /// a full view model.
    static func fallbackErrorMessage(for error: Error) -> String {
        if let posed = error as? PoseDetectionError, posed == .cameraPermissionDenied {
            return "Camera permission denied — running a demo stream."
        }
        return "Camera unavailable — running a demo stream."
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

    // MARK: - Demo fixture

    /// Fixture used when the real detector is unavailable (Simulator, permission
    /// denied). Generates a clean 10-rep set with a mild fatigue ramp so the
    /// "one more — push" moment still surfaces in the demo.
    static func demoFixture(for exerciseId: ExerciseID) -> [PoseSample] {
        switch exerciseId {
        case .pushUp:
            return SyntheticPoseGenerator.pushUps(
                repCount: 10,
                baselineCycleSeconds: 1.8,
                fatigueRamp: (startRep: 7, endRep: 10, multiplier: 1.6),
                partialReps: [],
                sampleRateHz: 30
            )
        case .gobletSquat:
            return SyntheticPoseGenerator.gobletSquats(repCount: 8, cycleSeconds: 2.4)
        case .dumbbellRow:
            return SyntheticPoseGenerator.dumbbellRows(repCount: 10, cycleSeconds: 2.2)
        }
    }
}

#endif
