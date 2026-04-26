import Foundation
import CoachingEngine

/// Protocol the iOS app conforms to for producing coaching audio.
///
/// Two surfaces:
///   - `playCached`: for Tier-1 phrases (rep counts, encouragement, safety).
///     Latency target: < 50 ms to start of audio.
///   - `speakStreaming`: for Tier-2 contextual LLM output. Streams TTS on a
///     latency budget of ~400 ms TTFB.
public protocol VoicePlaying: AnyObject, Sendable {
    /// Begin audio for a cached phrase. Returns when scheduling completes — the
    /// actual audio may still be playing. Call is cheap and safe from any actor.
    func playCached(_ phrase: PhraseID) async throws

    /// Stream contextual speech. Text flows in, audio plays out. Returns when
    /// playback is finished or cancelled.
    func speakStreaming(
        text: AsyncStream<String>,
        tone: CoachingTone
    ) async throws

    /// Stop whatever's currently playing.
    func stop() async
}

public enum VoicePlaybackError: Error, Equatable {
    case phraseNotInCache(PhraseID)
    case audioEngineError(String)
    case ttsNetworkError(String)
    case interrupted
}
