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
    private let voicesByTone: [CoachingTone: AVSpeechSynthesisVoice]
    private var sessionConfigured = false

    public override init() {
        self.voicesByTone = Self.pickVoicesByTone()
        super.init()
    }

    public func playCached(_ selection: PhraseCache.Selection) async throws {
        await ensureAudioSession()
        let text = Self.spokenText(for: selection)
        let utterance = makeUtterance(text: text, tone: selection.phrase.tone, variantIndex: selection.variant.index)
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
                    synthesizer.speak(makeUtterance(text: sentence, tone: tone, variantIndex: 0))
                }
            }
        }
        let tail = pending.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty {
            synthesizer.speak(makeUtterance(text: tail, tone: tone, variantIndex: 0))
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

    private func makeUtterance(text: String, tone: CoachingTone, variantIndex: Int) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voicesByTone[tone] ?? voicesByTone[.standard]
        let variantBump = min(Double(variantIndex), 6.0) * 0.01
        // Tone affects rate + pitch only — content is unchanged (PRD §6.4).
        switch tone {
        case .quiet:
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(0.90 + variantBump)
            utterance.pitchMultiplier = Float(0.92 + variantBump)
            utterance.volume = 0.85
        case .standard:
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(0.98 + variantBump)
            utterance.pitchMultiplier = Float(0.98 + variantBump)
            utterance.volume = 1.0
        case .intense:
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(1.05 + variantBump)
            utterance.pitchMultiplier = Float(1.03 + variantBump)
            utterance.volume = 1.0
        }
        return utterance
    }

    /// Map a `PhraseID` to spoken English. The real ElevenLabs cache (M3) keys
    /// on these same IDs and ships pre-recorded audio with multiple variants —
    /// for now we synthesize on the fly so the user hears the right thing in
    /// the right moment.
    static func spokenText(for selection: PhraseCache.Selection) -> String {
        let phrase = selection.phrase
        let variant = selection.variant.index
        switch phrase.kind {
        case .repCount:
            let number = phrase.number ?? 0
            let options = [
                "\(number)",
                "Rep \(number)",
                "\(number)."
            ]
            return options[variant % options.count]
        case .encourageOneMore:
            return variantText(
                tone: phrase.tone,
                variant: variant,
                quiet: ["One more", "You've got one more", "Stay with it"],
                standard: ["One more", "Give me one more", "You've got one more", "One clean rep"],
                intense: ["One more", "Give me one", "Up again", "Another rep"]
            )
        case .encouragePush:
            return variantText(
                tone: phrase.tone,
                variant: variant,
                quiet: ["Push", "Keep pushing", "Smooth push"],
                standard: ["Push", "Push through", "Drive it up", "Keep pushing"],
                intense: ["Push", "Up", "Drive it", "Move"]
            )
        case .encourageDrive:
            return variantText(
                tone: phrase.tone,
                variant: variant,
                quiet: ["Drive", "Steady drive", "Keep it moving"],
                standard: ["Drive", "Drive through", "Finish the rep", "Keep driving"],
                intense: ["Drive", "Go", "Finish it", "Move now"]
            )
        case .encourageLastOne:
            return variantText(
                tone: phrase.tone,
                variant: variant,
                quiet: ["Last one", "Final rep", "This is the last one"],
                standard: ["Last one", "That's the last rep", "Finish this one", "Final rep"],
                intense: ["Last one", "Last rep", "Finish it", "End it here"]
            )
        case .encourageSteady:
            return variantText(
                tone: phrase.tone,
                variant: variant,
                quiet: ["Steady", "Stay steady"],
                standard: ["Steady", "Hold it steady", "Stay organized"],
                intense: ["Steady", "Control it", "Stay tight"]
            )
        case .encourageValidate:
            return variantText(
                tone: phrase.tone,
                variant: variant,
                quiet: ["There it is", "That's it"],
                standard: ["There we go", "That's it", "Yes, that's the rep"],
                intense: ["Yes", "There it is", "That's it", "Good"]
            )
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

    private static func pickVoicesByTone() -> [CoachingTone: AVSpeechSynthesisVoice] {
        let ranked = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { lhs, rhs in
                let lhsRank = voiceRank(lhs)
                let rhsRank = voiceRank(rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.identifier < rhs.identifier
            }

        let fallback = ranked.first ?? AVSpeechSynthesisVoice(language: "en-US")
        let uniqueVoices = Array(ranked.prefix(3))
        let quiet = uniqueVoices.indices.contains(0) ? uniqueVoices[0] : fallback
        let standard = uniqueVoices.indices.contains(1) ? uniqueVoices[1] : quiet
        let intense = uniqueVoices.indices.contains(2) ? uniqueVoices[2] : standard
        return [
            .quiet: quiet,
            .standard: standard,
            .intense: intense
        ].compactMapValues { $0 }
    }

    private static func voiceRank(_ voice: AVSpeechSynthesisVoice) -> Int {
        switch voice.quality {
        case .premium: return 0
        case .enhanced: return 1
        default: return 2
        }
    }

    private static func variantText(
        tone: CoachingTone,
        variant: Int,
        quiet: [String],
        standard: [String],
        intense: [String]
    ) -> String {
        let options: [String]
        switch tone {
        case .quiet:
            options = quiet
        case .standard:
            options = standard
        case .intense:
            options = intense
        }
        guard !options.isEmpty else { return "" }
        return options[variant % options.count]
    }
}

#endif
