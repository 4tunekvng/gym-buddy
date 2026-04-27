import Foundation
import CoachingEngine

#if canImport(AVFoundation) && !os(macOS)
import AVFoundation

/// A `VoicePlaying` implementation backed by Apple's `AVSpeechSynthesizer`.
///
/// **Why this exists:** the PRD §7.8 explicitly says `AVSpeechSynthesizer` is
/// not acceptable as the *production* voice — voice quality is core to the
/// product, and the system synthesizer doesn't clear that bar. Real users get
/// the ElevenLabs phrase cache once it ships in M3.
///
/// In the meantime this is a *much better* fallback than the silent
/// `MockVoicePlayer`: in the Simulator (and on a real device until M3), the
/// user actually HEARS the coach count reps and call out "one more — push".
/// The hero moment from PRD §2 is now audibly demoable end-to-end without
/// waiting on the build-time TTS pipeline.
///
/// Tone preference (quiet/standard/intense) is mapped to `AVSpeechUtterance`
/// rate/pitch hints so the three tones at least *sound* meaningfully different.
@MainActor
public final class SpeechSynthesizerVoicePlayer: NSObject, VoicePlaying {

    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?
    private var sessionConfigured = false

    public override init() {
        // Pick the highest-quality English voice available. Apple sometimes
        // has a "premium" voice installed that's noticeably better; fall back
        // to the system default if not.
        let preferred = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { lhs, rhs in
                // Prefer "Enhanced" / "Premium" quality over standard.
                let order: (AVSpeechSynthesisVoiceQuality) -> Int = { quality in
                    switch quality {
                    case .premium: return 0
                    case .enhanced: return 1
                    default: return 2
                    }
                }
                return order(lhs.quality) < order(rhs.quality)
            }
            .first
        self.voice = preferred ?? AVSpeechSynthesisVoice(language: "en-US")
        super.init()
    }

    public func playCached(_ phrase: PhraseID) async throws {
        await ensureAudioSession()
        let text = Self.spokenText(for: phrase)
        let utterance = makeUtterance(text: text, tone: phrase.tone)
        synthesizer.speak(utterance)
    }

    public func speakStreaming(text: AsyncStream<String>, tone: CoachingTone) async throws {
        await ensureAudioSession()
        // Buffer incoming chunks into sentence boundaries so the synthesizer
        // gets natural prosody instead of choppy word-level utterances.
        var pending = ""
        for await chunk in text {
            pending += chunk
            while let dot = pending.firstIndex(where: { ".!?".contains($0) }) {
                let sentence = String(pending[...dot]).trimmingCharacters(in: .whitespaces)
                pending = String(pending[pending.index(after: dot)...])
                if !sentence.isEmpty {
                    synthesizer.speak(makeUtterance(text: sentence, tone: tone))
                }
            }
        }
        let tail = pending.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty {
            synthesizer.speak(makeUtterance(text: tail, tone: tone))
        }
    }

    public func stop() async {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Helpers

    /// Activate `.playback` so the audio is audible even on the iOS Simulator
    /// (which routes ambient mode to a muted output by default in some
    /// configurations). One-shot — re-activation is a no-op.
    private func ensureAudioSession() async {
        if sessionConfigured { return }
        sessionConfigured = true
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            // Best-effort. If we can't activate the session, the synthesizer
            // will still try to speak, just at the system default routing.
        }
    }

    private func makeUtterance(text: String, tone: CoachingTone) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        // Tone affects rate + pitch only — content is unchanged (PRD §6.4).
        switch tone {
        case .quiet:
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
            utterance.pitchMultiplier = 0.95
            utterance.volume = 0.85
        case .standard:
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0
        case .intense:
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.07
            utterance.pitchMultiplier = 1.05
            utterance.volume = 1.0
        }
        return utterance
    }

    /// Map a `PhraseID` to spoken English. The real ElevenLabs cache (M3) keys
    /// on these same IDs and ships pre-recorded audio with multiple variants —
    /// for now we synthesize on the fly so the user hears the right thing in
    /// the right moment.
    static func spokenText(for phrase: PhraseID) -> String {
        switch phrase.kind {
        case .repCount:
            // "1", "2", "3" — bare number is the standard counting cadence.
            return phrase.number.map { "\($0)" } ?? ""
        case .encourageOneMore: return "One more"
        case .encouragePush:    return "Push"
        case .encourageDrive:   return "Drive"
        case .encourageLastOne: return "Last one"
        case .encourageSteady:  return "Steady"
        case .encourageValidate: return "There we go"
        case .safetyPainStop:
            return "Let's stop there. Sharp pain is a stop signal. " +
                "If it keeps hurting, please check in with a physician."
        case .safetyDiagnosisDeflect:
            return "I can't diagnose that — sounds like something a physician should look at."
        case .safetyNutritionDeflect:
            return "I can help with training. For specific calorie or weight-cut numbers, " +
                "talk to a registered dietitian."
        case .safetyGenericDeflect:
            return "That's outside what I can help with. Let's get back to the set."
        }
    }
}

#endif
