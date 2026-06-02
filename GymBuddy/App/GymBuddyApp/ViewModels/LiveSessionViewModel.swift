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
        do {
            try await composition.sessionRepo.record(record)
        } catch {
            await MainActor.run { errorMessage = "Session save failed: \(error.localizedDescription)" }
        }

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
}

#endif
