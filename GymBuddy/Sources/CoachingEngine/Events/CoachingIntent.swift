import Foundation

/// What the coach should do next.
///
/// The engine emits intents. Platform adapters (VoiceIO, UI layer) turn intents
/// into audio + visuals. This is the boundary that lets us add Watch haptics
/// (Chapter 4) and in-ear-only mode (Chapter 5) without engine changes.
public enum CoachingIntent: Equatable, Sendable {
    /// Speak the rep number aloud.
    case sayRepCount(number: Int, timestamp: TimeInterval)

    /// Fire a form cue (surfaces visually and possibly audibly).
    case formCue(CueEvent)

    /// Encouragement timed to a specific part of the rep cycle.
    case encouragement(kind: EncouragementKind, timing: Timing, timestamp: TimeInterval)

    /// Announce the set ended; downstream decides what to say.
    case setEnded(SetEndEvent)

    /// Start a rest timer for the configured duration.
    case startRest(seconds: TimeInterval)

    /// Contextual LLM-generated speech. The engine provides the intent + inputs;
    /// the LLM layer generates the text and the voice layer streams it.
    case contextualSpeech(ContextualSpeechRequest)

    /// Stop everything. Pain detected.
    case painStop(trigger: String)

    public enum EncouragementKind: String, Codable, Sendable {
        case pushThrough        // "push"
        case oneMore            // "one more"
        case drive              // "drive"
        case lastOne            // "last one"
        case steady             // "steady — control"
        case validate           // "there we go"
    }

    public enum Timing: String, Codable, Sendable {
        case bottomOfRep
        case topOfRep
        case duringConcentric
        case duringEccentric
        case betweenReps
    }
}

/// Inputs to generate a contextual (LLM-backed) phrase.
public struct ContextualSpeechRequest: Equatable, Sendable {
    public enum Purpose: String, Codable, Sendable {
        case postSetSummary
        case betweenSetResponse
        case morningReadiness
        case postSessionSummary
        case appOpenGreeting
        case onboardingPrompt
    }

    public let purpose: Purpose
    public let inputPayload: [String: String]   // simple kv to keep the engine vendor-pure

    public init(purpose: Purpose, inputPayload: [String: String]) {
        self.purpose = purpose
        self.inputPayload = inputPayload
    }
}
