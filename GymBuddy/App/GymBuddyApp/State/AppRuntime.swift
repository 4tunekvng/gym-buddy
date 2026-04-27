import Foundation

#if os(iOS)

struct AppRuntimeConfiguration: Equatable {
    enum PoseMode: String, Equatable {
        case auto
        case demo
    }

    enum LLMMode: String, Equatable {
        case auto
        case mock
    }

    enum VoiceMode: String, Equatable {
        case system
        case mock
    }

    let poseMode: PoseMode
    let llmMode: LLMMode
    let voiceMode: VoiceMode
    let anthropicAPIKey: String?
    let scriptedDemoPlaybackRate: Double

    static func current(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) -> AppRuntimeConfiguration {
        AppRuntimeConfiguration(
            poseMode: PoseMode(rawValue: normalizedValue(
                environment["GYMBUDDY_POSE_MODE"] ??
                    stringValue(infoDictionary["GYMBUDDY_POSE_MODE"])
            ) ?? "") ?? .auto,
            llmMode: LLMMode(rawValue: normalizedValue(
                environment["GYMBUDDY_LLM_MODE"] ??
                    stringValue(infoDictionary["GYMBUDDY_LLM_MODE"])
            ) ?? "") ?? .auto,
            voiceMode: VoiceMode(rawValue: normalizedValue(
                environment["GYMBUDDY_VOICE_MODE"] ??
                    stringValue(infoDictionary["GYMBUDDY_VOICE_MODE"])
            ) ?? "") ?? .system,
            anthropicAPIKey: firstNonEmpty(
                environment["GYMBUDDY_ANTHROPIC_API_KEY"],
                environment["ANTHROPIC_API_KEY"],
                stringValue(infoDictionary["ANTHROPIC_API_KEY"])
            ),
            scriptedDemoPlaybackRate: playbackRateValue(
                environment["GYMBUDDY_SCRIPTED_DEMO_PLAYBACK_RATE"] ??
                    stringValue(infoDictionary["GYMBUDDY_SCRIPTED_DEMO_PLAYBACK_RATE"])
            )
        )
    }

    var usesLiveAnthropic: Bool {
        llmMode != .mock && !(anthropicAPIKey?.isEmpty ?? true)
    }

    private static func normalizedValue(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func stringValue(_ value: Any?) -> String? {
        value as? String
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func playbackRateValue(_ value: String?) -> Double {
        guard
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
            let parsed = Double(trimmed),
            parsed > 0
        else {
            return 1.0
        }
        return parsed
    }
}

struct AppRuntimeStatus: Equatable {
    enum PoseStatus: Equatable {
        case liveCamera
        case scriptedDemoForced
    }

    enum LLMStatus: Equatable {
        case liveClaude(modelId: String)
        case deterministicFallback
    }

    enum VoiceStatus: Equatable {
        case systemSynth
        case mock
    }

    let pose: PoseStatus
    let llm: LLMStatus
    let voice: VoiceStatus

    var hasFallbacks: Bool {
        pose != .liveCamera || llm == .deterministicFallback || voice != .systemSynth
    }

    var summaryLines: [String] {
        [
            "Pose: \(poseLabel)",
            "AI: \(llmLabel)",
            "Voice: \(voiceLabel)"
        ]
    }

    var poseLabel: String {
        switch pose {
        case .liveCamera:
            return "live camera when permission is granted"
        case .scriptedDemoForced:
            return "scripted demo (forced)"
        }
    }

    var llmLabel: String {
        switch llm {
        case .liveClaude(let modelId):
            return "Anthropic \(modelId)"
        case .deterministicFallback:
            return "deterministic fallback"
        }
    }

    var voiceLabel: String {
        switch voice {
        case .systemSynth:
            return "system speech synth"
        case .mock:
            return "mock / silent playback"
        }
    }
}

#endif
