import Foundation
import SwiftUI
import CoachingEngine
import PoseVision
import VoiceIO
import LLMClient
import Persistence
import HealthKitBridge
import Telemetry

#if os(iOS)
import SwiftData

/// Composition root. Holds strong references to the composed protocols so the
/// view layer can reach them through `@EnvironmentObject`. No singletons — this
/// object is created once in `GymBuddyApp` and injected down.
@MainActor
final class AppComposition: ObservableObject {
    let telemetry: TelemetryLog
    let runtimeConfig: AppRuntimeConfiguration
    let runtimeStatus: AppRuntimeStatus
    let poseDetectorFactory: () -> PoseDetecting
    let voicePlayer: VoicePlaying
    let phraseCache: PhraseCache
    let llmClient: LLMClientProtocol
    let health: HealthReader
    let userProfileRepo: UserProfileRepository
    let planRepo: PlanRepository
    let sessionRepo: SessionRepository
    let memoryRepo: MemoryRepository
    let readinessRepo: ReadinessRepository
    let modelContainer: ModelContainer

    init(
        telemetry: TelemetryLog,
        runtimeConfig: AppRuntimeConfiguration,
        runtimeStatus: AppRuntimeStatus,
        poseDetectorFactory: @escaping () -> PoseDetecting,
        voicePlayer: VoicePlaying,
        phraseCache: PhraseCache,
        llmClient: LLMClientProtocol,
        health: HealthReader,
        userProfileRepo: UserProfileRepository,
        planRepo: PlanRepository,
        sessionRepo: SessionRepository,
        memoryRepo: MemoryRepository,
        readinessRepo: ReadinessRepository,
        modelContainer: ModelContainer
    ) {
        self.telemetry = telemetry
        self.runtimeConfig = runtimeConfig
        self.runtimeStatus = runtimeStatus
        self.poseDetectorFactory = poseDetectorFactory
        self.voicePlayer = voicePlayer
        self.phraseCache = phraseCache
        self.llmClient = llmClient
        self.health = health
        self.userProfileRepo = userProfileRepo
        self.planRepo = planRepo
        self.sessionRepo = sessionRepo
        self.memoryRepo = memoryRepo
        self.readinessRepo = readinessRepo
        self.modelContainer = modelContainer
    }

    /// Production composition. API keys are read from `Info.plist` at runtime.
    static func makeProduction() -> AppComposition {
        let container = Self.openContainer()
        let runtimeConfig = AppRuntimeConfiguration.current()

        let userRepo = SwiftDataUserProfileRepository(container: container)
        let planRepo = SwiftDataPlanRepository(container: container)
        let sessionRepo = SwiftDataSessionRepository(container: container)
        let memoryRepo = SwiftDataMemoryRepository(container: container)
        let readinessRepo = SwiftDataReadinessRepository(container: container)

        let telemetry = InMemoryTelemetryLog()

        // Populate a minimal cache so the voice mapper can resolve every phrase
        // it might route to during a live set. When Tier-1 TTS audio assets
        // ship (ADR-0002), this becomes the bundle-loaded cache. Today the
        // placeholder asset names are enough for the mock voice player; the UI
        // runs without phrase-cache-miss errors.
        let phraseCache = Self.bootstrapPhraseCache()

        let llm: LLMClientProtocol = {
            if runtimeConfig.usesLiveAnthropic, let apiKey = runtimeConfig.anthropicAPIKey {
                return AnthropicClient(credentials: .init(apiKey: apiKey))
            }
            return MockLLMClient()
        }()

        let healthReader: HealthReader = {
            #if canImport(HealthKit) && !os(macOS)
            return AppleHealthReader()
            #else
            return MockHealthReader()
            #endif
        }()

        // Audible coach in the Simulator + on-device. The premium ElevenLabs
        // cache lands in M3 (per ADR-0002 + PRD §7.8); until then,
        // AVSpeechSynthesizer is a strictly better fallback than the silent
        // MockVoicePlayer because it lets the user actually HEAR the hero
        // moment ("one more — push") on their laptop or phone today.
        let voicePlayer: VoicePlaying = {
            switch runtimeConfig.voiceMode {
            case .system:
                return SpeechSynthesizerVoicePlayer()
            case .mock:
                return MockVoicePlayer()
            }
        }()

        let runtimeStatus = AppRuntimeStatus(
            pose: runtimeConfig.poseMode == .demo ? .scriptedDemoForced : .liveCamera,
            llm: runtimeConfig.usesLiveAnthropic ? .liveClaude(modelId: LLMConfiguration().modelId) : .deterministicFallback,
            voice: runtimeConfig.voiceMode == .mock ? .mock : .systemSynth
        )

        return AppComposition(
            telemetry: telemetry,
            runtimeConfig: runtimeConfig,
            runtimeStatus: runtimeStatus,
            poseDetectorFactory: {
                #if canImport(Vision) && !os(macOS)
                return VisionPoseDetector(cameraPosition: .front)
                #else
                return FixturePoseDetector(samples: [])
                #endif
            },
            voicePlayer: voicePlayer,
            phraseCache: phraseCache,
            llmClient: SafeLLMClient(inner: llm),
            health: healthReader,
            userProfileRepo: userRepo,
            planRepo: planRepo,
            sessionRepo: sessionRepo,
            memoryRepo: memoryRepo,
            readinessRepo: readinessRepo,
            modelContainer: container
        )
    }

    /// Try to open the production SwiftData container. If that fails, fall
    /// back to in-memory (the user will see empty history / no saved profile
    /// but the app still runs). If BOTH fail — extremely rare; only possible
    /// when the device is out of memory or the SwiftData runtime is unavailable —
    /// we deliberately crash with a diagnostic message rather than silently
    /// handing back a broken container. Crashing once at launch is better
    /// than corrupting state later.
    private static func openContainer() -> ModelContainer {
        if let prod = try? GymBuddyStore.productionContainer() { return prod }
        if let memory = try? GymBuddyStore.inMemoryContainer() { return memory }
        fatalError("SwiftData could not open either a production or in-memory container.")
    }

    /// Build a phrase cache that has at least one variant for every ID the
    /// IntentToVoiceMapper might reach for a live set across all tones.
    /// Variants are placeholder asset names; real audio ships later (ADR-0002).
    static func bootstrapPhraseCache() -> PhraseCache {
        var variants: [PhraseID: [PhraseCache.Variant]] = [:]
        for tone in CoachingTone.allCases {
            for id in PhraseManifest.required(for: tone) {
                let variantCount = PhraseManifest.minimumVariantsByKind[id.kind] ?? 1
                variants[id] = (0..<variantCount).map {
                    PhraseCache.Variant(index: $0, assetName: "placeholder:\(id.assetName):\($0)")
                }
            }
        }
        return PhraseCache(variants: variants, windowSize: 3)
    }

    /// Preview/in-memory composition. Used by SwiftUI previews and the XCUITest
    /// target so UI flows run without touching real storage or vendor APIs.
    /// Same crash-on-both-fail policy as production (see `openContainer`) —
    /// if SwiftData can't open even an in-memory container, the app is
    /// fundamentally broken and there's nothing useful to degrade to.
    static func makePreview() -> AppComposition {
        guard let container = try? GymBuddyStore.inMemoryContainer() else {
            fatalError("SwiftData in-memory container unavailable — previews cannot run.")
        }
        return AppComposition(
            telemetry: NoOpTelemetryLog(),
            runtimeConfig: AppRuntimeConfiguration(
                poseMode: .demo,
                llmMode: .mock,
                voiceMode: .mock,
                anthropicAPIKey: nil,
                scriptedDemoPlaybackRate: 1.0
            ),
            runtimeStatus: AppRuntimeStatus(
                pose: .scriptedDemoForced,
                llm: .deterministicFallback,
                voice: .mock
            ),
            poseDetectorFactory: { FixturePoseDetector(samples: SyntheticPoseGenerator.pushUps(repCount: 5)) },
            voicePlayer: MockVoicePlayer(),
            phraseCache: bootstrapPhraseCache(),
            llmClient: MockLLMClient(),
            health: MockHealthReader(),
            userProfileRepo: InMemoryUserProfileRepository(),
            planRepo: InMemoryPlanRepository(),
            sessionRepo: InMemorySessionRepository(),
            memoryRepo: InMemoryMemoryRepository(),
            readinessRepo: InMemoryReadinessRepository(),
            modelContainer: container
        )
    }
}

#endif
