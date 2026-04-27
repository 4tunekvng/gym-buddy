import Foundation
import CoachingEngine

/// Turns CoachingEngine intents into VoicePlaying calls.
///
/// This lives in VoiceIO — CoachingEngine stays abstract ("encouragement, kind
/// pushThrough"), VoiceIO knows which cached phrase corresponds to which kind.
/// The mapper also applies the "at most one phrase per rep" UX rule (rep count
/// vs. encouragement vs. cue) by emitting them as sequential scheduled events.
public struct IntentToVoiceMapper: Sendable {
    public let tone: CoachingTone
    private let cache: PhraseCache
    private let voice: VoicePlaying

    public init(tone: CoachingTone, cache: PhraseCache, voice: VoicePlaying) {
        self.tone = tone
        self.cache = cache
        self.voice = voice
    }

    /// Route one intent. Returns the PhraseID that was (or would have been)
    /// played for cache-based intents, and nil for non-cache intents.
    @discardableResult
    public func route(_ intent: CoachingIntent) async throws -> PhraseID? {
        switch intent {
        case .sayRepCount(let n, _):
            let phrase = PhraseID(kind: .repCount, tone: tone, number: n)
            let selection = try cache.select(phrase)
            try await voice.playCached(selection)
            return phrase

        case .encouragement(let kind, _, _):
            let phrase = PhraseID(kind: kind.phraseKind(), tone: tone, number: nil)
            let selection = try cache.select(phrase)
            try await voice.playCached(selection)
            return phrase

        case .formCue(let cueEvent):
            // Form cues in MVP render as on-screen text only (to preserve the
            // "at most one audio phrase per rep" rule, which is already used by
            // the rep count). If we decide to voice cues, it's a single switch
            // here. Leaving silent for now; orchestrator still surfaces on-screen.
            _ = cueEvent
            return nil

        case .setEnded, .startRest:
            // Handled by UI + rest-timer logic; no Tier-1 audio.
            return nil

        case .contextualSpeech:
            // Streaming branch is driven by LLMClient, not this mapper.
            return nil

        case .painStop(let trigger):
            _ = trigger
            let phrase = PhraseID(kind: .safetyPainStop, tone: tone, number: nil)
            let selection = try cache.select(phrase)
            try await voice.playCached(selection)
            return phrase
        }
    }
}
