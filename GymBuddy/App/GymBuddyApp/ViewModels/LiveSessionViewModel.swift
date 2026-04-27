import Foundation
import CoachingEngine
import PoseVision
import VoiceIO
import Persistence
import Telemetry
import DesignSystem

#if os(iOS)
import AVFoundation

@MainActor
final class LiveSessionViewModel: ObservableObject {

    enum SetupMode: Equatable {
        case loading
        case liveCamera
        case forcedDemo
        case fallbackDemo(message: String)
    }

    @Published var repCount: Int = 0
    @Published var cueText: String?
    @Published var isPartialRep: Bool = false
    @Published var isSetupComplete: Bool = false
    @Published var lastEncouragement: String?
    @Published var lastSpokenPhrase: String?
    @Published var isRunningDemoFixture: Bool = false
    @Published var setupChecks: [SetupOverlay.Check] = [
        .init(id: .angle, passing: false),
        .init(id: .distance, passing: false),
        .init(id: .lighting, passing: false),
        .init(id: .fullBody, passing: false)
    ]
    @Published var isFinished: Bool = false
    @Published var errorMessage: String?
    @Published var setupTitle: String = "Starting camera"
    @Published var setupSubtitle: String = "Loading the live coaching setup."
    @Published var setupActionTitle: String = "Waiting for camera"
    @Published var isSetupActionEnabled: Bool = false
    @Published var setupMode: SetupMode = .loading
    @Published var previewSession: AVCaptureSession?

    let exerciseId: ExerciseID
    let setNumber: Int
    let runtimeSummaryLines: [String]

    private let composition: AppComposition
    private let onFinishCallback: (SessionObservation) -> Void
    private let onCancelCallback: () -> Void
    private let sessionId = UUID()

    private var detector: PoseDetecting?
    private var consumeTask: Task<Void, Never>?
    private var mapper: IntentToVoiceMapper?
    private var orchestrator: SessionOrchestrator?
    private var didFinish = false
    private var didPrepareSetup = false

    private var resolvedTone: CoachingTone = .standard
    private var resolvedUserId = UUID()
    private var priorSessionBestReps: [ExerciseID: Int] = [:]
    private var memoryReferences: [String] = []
    private var activeInjuryNotes: [String] = []

    init(
        composition: AppComposition,
        exerciseId: ExerciseID,
        setNumber: Int,
        onFinish: @escaping (SessionObservation) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.composition = composition
        self.exerciseId = exerciseId
        self.setNumber = setNumber
        self.runtimeSummaryLines = composition.runtimeStatus.summaryLines
        self.onFinishCallback = onFinish
        self.onCancelCallback = onCancel
    }

    func prepareSetupIfNeeded() async {
        guard !didPrepareSetup else { return }
        didPrepareSetup = true
        await hydrateSessionContext()

        if composition.runtimeConfig.poseMode == .demo {
            configureForcedDemoSetup()
            return
        }

        let primary = composition.poseDetectorFactory()
        detector = primary
        if let previewProvider = primary as? CameraPreviewProviding {
            previewSession = previewProvider.previewSession
        }

        do {
            try await primary.start()
            setupMode = .liveCamera
            setupTitle = "Let's get you in frame"
            setupSubtitle = "I’ll unlock Start when your framing checks are green."
            setupActionTitle = "Start set"
            isSetupActionEnabled = false
            consume(stream: primary.bodyStateStream())
        } catch {
            await primary.stop()
            detector = nil
            previewSession = nil
            configureFallbackDemo(message: Self.fallbackErrorMessage(for: error))
        }
    }

    func completeSetupAndStart() async {
        if isSetupComplete { return }

        switch setupMode {
        case .loading:
            return
        case .liveCamera:
            guard setupChecks.allSatisfy(\.passing) else { return }
            startLiveCameraSession()
        case .forcedDemo, .fallbackDemo:
            await startDemoSession()
        }
    }

    func finishExplicitly() async {
        guard let orchestrator else { return }
        let intents = orchestrator.finishSetExplicitly(reason: .userTapped)
        for intent in intents { await handle(intent: intent) }
        await completeLifecycle()
    }

    func cancel() async {
        consumeTask?.cancel()
        await detector?.stop()
        onCancelCallback()
    }

    private func hydrateSessionContext() async {
        let profile = try? await composition.userProfileRepo.load()
        resolvedUserId = profile?.id ?? UUID()
        resolvedTone = profile?.tone ?? .standard

        if let best = try? await composition.sessionRepo.bestReps(for: exerciseId) {
            priorSessionBestReps = [exerciseId: best]
        } else {
            priorSessionBestReps = [:]
        }

        let tags = Self.memoryTags(for: exerciseId, profile: profile)
        let notes = (try? await composition.memoryRepo.recent(matching: tags, limit: 4)) ?? []
        memoryReferences = notes.map(\.content)
        activeInjuryNotes = notes
            .filter { note in note.tags.contains(MemoryTag.injury.rawValue) || note.tags.contains(where: { $0.hasPrefix("body-part:") }) }
            .map(\.content)

        if memoryReferences.isEmpty {
            memoryReferences = Self.seededReferences(from: profile)
        }
        if activeInjuryNotes.isEmpty {
            activeInjuryNotes = Self.seededInjuryReferences(from: profile)
        }
    }

    private func configureForcedDemoSetup() {
        setupMode = .forcedDemo
        setupTitle = "Scripted demo mode"
        setupSubtitle = "This run is explicitly using the deterministic pose fixture, not the camera."
        setupActionTitle = "Run scripted demo"
        isSetupActionEnabled = true
        setupChecks = Self.makeSetupChecks()
    }

    private func configureFallbackDemo(message: String) {
        setupMode = .fallbackDemo(message: message)
        setupTitle = "Camera unavailable"
        setupSubtitle = "\(message) You can still run the scripted demo here."
        setupActionTitle = "Run scripted demo"
        isSetupActionEnabled = true
        setupChecks = Self.makeSetupChecks()
        errorMessage = message
    }

    private func startLiveCameraSession() {
        mapper = IntentToVoiceMapper(
            tone: resolvedTone,
            cache: composition.phraseCache,
            voice: composition.voicePlayer
        )
        orchestrator = makeOrchestrator()
        isSetupComplete = true
        isRunningDemoFixture = false
        setupSubtitle = "I can see you clearly. Start repping."
        Task { await logSessionStarted() }
    }

    private func startDemoSession() async {
        consumeTask?.cancel()
        await detector?.stop()

        mapper = IntentToVoiceMapper(
            tone: resolvedTone,
            cache: composition.phraseCache,
            voice: composition.voicePlayer
        )
        orchestrator = makeOrchestrator()

        let fallback = FixturePoseDetector(
            samples: Self.demoFixture(for: exerciseId),
            frameInterval: Self.scriptedDemoFrameInterval(
                playbackRate: composition.runtimeConfig.scriptedDemoPlaybackRate
            )
        )
        do {
            try await fallback.start()
            detector = fallback
            previewSession = nil
            isRunningDemoFixture = true
            isSetupComplete = true
            setupMode = .forcedDemo
            consume(stream: fallback.bodyStateStream())
            await logSessionStarted()
        } catch {
            errorMessage = "Session failed to start: \(error.localizedDescription)"
        }
    }

    private func consume(stream: BodyStateStream) {
        consumeTask = Task.detached { [weak self] in
            for await state in stream {
                guard let self else { break }
                guard case .pose(let sample) = state else { continue }

                if !(await MainActor.run { self.isSetupComplete }) {
                    let evaluation = SetupEvaluator.evaluate(sample: sample, exerciseId: await MainActor.run { self.exerciseId })
                    await MainActor.run {
                        self.apply(setupEvaluation: evaluation)
                    }
                    continue
                }

                let intents = await MainActor.run {
                    self.orchestrator?.observe(sample: sample) ?? []
                }
                for intent in intents {
                    await self.handle(intent: intent)
                }
            }

            guard let self else { return }
            let finished = await MainActor.run { self.isFinished }
            let started = await MainActor.run { self.isSetupComplete }
            if started && !finished {
                await self.completeLifecycle()
            }
        }
    }

    private func apply(setupEvaluation: SetupEvaluation) {
        setupMode = .liveCamera
        setupChecks = [
            .init(id: .angle, passing: setupEvaluation.angleOkay),
            .init(id: .distance, passing: setupEvaluation.distanceOkay),
            .init(id: .lighting, passing: setupEvaluation.lightingOkay),
            .init(id: .fullBody, passing: setupEvaluation.fullBodyOkay)
        ]
        setupTitle = "Let's get you in frame"
        setupSubtitle = setupEvaluation.guidance ?? "I’ll unlock Start when your framing checks are green."
        setupActionTitle = "Start set"
        isSetupActionEnabled = setupEvaluation.allPassing
    }

    private func makeOrchestrator() -> SessionOrchestrator {
        SessionOrchestrator(
            config: SessionConfig(
                exerciseId: exerciseId,
                setNumber: setNumber,
                targetReps: nil,
                tone: resolvedTone
            ),
            context: SessionContext(
                userId: resolvedUserId,
                tone: resolvedTone,
                priorSessionBestReps: priorSessionBestReps,
                activeInjuryNotes: activeInjuryNotes,
                memoryReferences: memoryReferences
            )
        )
    }

    private func handle(intent: CoachingIntent) async {
        switch intent {
        case .sayRepCount(let n, _):
            await MainActor.run {
                repCount = n
                isPartialRep = false
                cueText = nil
                lastSpokenPhrase = "\(n)"
            }
            _ = try? await mapper?.route(intent)
            await logTelemetry(.voicePlayed(tier: 1, phraseId: "rep.\(n)", variantIndex: 0, latency_ms: 0))

        case .formCue(let cue):
            let text = Self.cueDisplayText(for: cue)
            await MainActor.run {
                cueText = text
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
        guard let orchestrator else { return }
        let observation = orchestrator.buildObservation()

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

    private func logSessionStarted() async {
        await logTelemetry(.sessionStarted(
            exerciseId: exerciseId.rawValue,
            setNumber: setNumber,
            plannedReps: nil
        ))
    }

    private func logTelemetry(_ kind: EventKind) async {
        await composition.telemetry.log(
            TelemetryEvent(kind: kind, sessionIdRef: sessionId)
        )
    }

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

    private static func makeSetupChecks() -> [SetupOverlay.Check] {
        [
            .init(id: .angle, passing: false),
            .init(id: .distance, passing: false),
            .init(id: .lighting, passing: false),
            .init(id: .fullBody, passing: false)
        ]
    }

    private static func scriptedDemoFrameInterval(playbackRate: Double) -> TimeInterval {
        let clampedRate = max(0.25, min(playbackRate, 8.0))
        return (1.0 / 30.0) / clampedRate
    }

    private static func memoryTags(for exerciseId: ExerciseID, profile: UserProfile?) -> Set<String> {
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

    private static func seededReferences(from profile: UserProfile?) -> [String] {
        guard let profile else { return [] }

        var notes: [String] = [
            "Goal: \(profile.goal.rawValue).",
            "Coaching tone: \(profile.tone.displayName)."
        ]
        notes.append(contentsOf: seededInjuryReferences(from: profile))
        return notes
    }

    private static func seededInjuryReferences(from profile: UserProfile?) -> [String] {
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
