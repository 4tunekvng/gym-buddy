import Foundation

/// Deterministic keyword-based pain detector.
///
/// Runs on STT transcripts before any LLM call, so a pain utterance is caught
/// with no network dependency and no LLM drift. See docs/Safety.md for the
/// canonical list.
public struct PainDetector: Sendable {
    public static let painPhrases: [String] = [
        "sharp pain",
        "something popped",
        "pulled something",
        "pinched",
        "pinching",
        "shooting pain",
        "stabbing pain",
        "tweaked",
        "it hurts",
        "that hurts",
        "hurts bad",
        "hurting",
        "hurts a lot"
    ]

    /// Negated contexts that should NOT be treated as pain despite containing a match.
    public static let negatedContexts: [String] = [
        "doesn't hurt",
        "didn't hurt",
        "not hurting",
        "not hurt",
        "no pain",
        "no sharp pain",
        "isn't hurting",
        "isn't hurt",
        "nothing is hurting",
        "nothing hurts",
        "nothing hurt"
    ]

    public init() {}

    /// Returns the matching pain phrase if the transcript contains pain language
    /// and the negated-context check passes. Otherwise nil.
    public func detect(in transcript: String) -> String? {
        let lower = transcript.lowercased()
        for neg in Self.negatedContexts where lower.contains(neg) {
            return nil
        }
        for phrase in Self.painPhrases where lower.contains(phrase) {
            return phrase
        }
        // Also catch bare "hurts" at word boundaries.
        let tokens = lower.split(whereSeparator: { !$0.isLetter })
        if tokens.contains("hurts") || tokens.contains("hurting") {
            if !lower.contains("muscle") && !lower.contains("legs are burning") && !lower.contains("burn") {
                return "hurts"
            }
        }
        return nil
    }
}
