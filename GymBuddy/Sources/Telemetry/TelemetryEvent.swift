import Foundation

/// Structured event emitted by any module that wants to log for post-hoc debugging.
/// Payload is a tagged enum to keep the schema explicit — no free-form dictionaries.
public struct TelemetryEvent: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let kind: EventKind
    public let timestamp: Date
    public let sessionIdRef: UUID?
    public let schemaVersion: Int

    public init(
        id: UUID = UUID(),
        kind: EventKind,
        timestamp: Date = Date(),
        sessionIdRef: UUID? = nil,
        schemaVersion: Int = Self.currentSchemaVersion
    ) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.sessionIdRef = sessionIdRef
        self.schemaVersion = schemaVersion
    }

    public static let currentSchemaVersion = 1
}

public enum EventKind: Codable, Equatable, Sendable {
    // Session lifecycle
    case sessionStarted(exerciseId: String, setNumber: Int, plannedReps: Int?)
    case sessionEnded(exerciseId: String, setNumber: Int, actualReps: Int, duration_s: Double, endReason: String)

    // Coaching signal
    case repDetected(exerciseId: String, repNumber: Int, concentric_ms: Int, eccentric_ms: Int, romScore: Double)
    case cueFired(exerciseId: String, cueType: String, severity: Int, latency_ms: Int)
    case tempoSlowdownDetected(exerciseId: String, repNumber: Int, ratio: Double)
    case intentEmitted(intentKind: String, priority: Int)

    // Voice IO
    case voicePlayed(tier: Int, phraseId: String, variantIndex: Int, latency_ms: Int)
    case voiceCacheMiss(phraseId: String)
    case voiceTtsError(vendorErrorCode: String)
    case sttTranscribed(duration_ms: Int, onDevice: Bool)
    case vadSpeechDetected(duration_ms: Int)

    // LLM
    case llmCalled(promptId: String, promptVersion: Int, tokensIn: Int, tokensOut: Int, latency_ms: Int)
    case llmStreamFirstToken(latency_ms: Int)
    case llmSafetySubstitution(category: String)
    case llmError(httpStatus: Int, errorCode: String)

    // Permissions / chaos
    case permissionRequested(kind: String)
    case permissionGranted(kind: String)
    case permissionDenied(kind: String)
    case permissionRevoked(kind: String, midSession: Bool)
    case systemInterruption(kind: String)
    case networkChanged(reachable: Bool)

    // App lifecycle
    case appLaunched(coldStart: Bool, launchToFirstPaint_ms: Int)
    case appBackgrounded
    case appForegrounded
    case crashLogged(stackHash: String)

    // Safety
    case safetyPainDetected(source: String)
    case safetySessionPaused(reason: String)
}
