import Foundation

/// Post-LLM content filter. Every LLM output passes through here before it
/// reaches the voice layer.
///
/// The filter is deliberately conservative: borderline patterns trigger a
/// substitution rather than a rewrite. Substitution targets a small, pre-written,
/// pre-recorded safe-response library (see docs/Safety.md).
public struct ContentSafetyFilter: Sendable {
    public init() {}

    public struct Result: Equatable, Sendable {
        public let action: SafetyAction
        public let originalText: String
    }

    public func inspect(_ text: String) -> Result {
        let lower = text.lowercased()

        if detectsDiagnosis(lower) {
            return Result(
                action: .substituteResponse(
                    category: .diagnosis,
                    safeResponseId: "safety.diagnosis.deflect"
                ),
                originalText: text
            )
        }
        if detectsUnsafeNutrition(lower) {
            return Result(
                action: .substituteResponse(
                    category: .unsafeNutrition,
                    safeResponseId: "safety.nutrition.deflect"
                ),
                originalText: text
            )
        }
        if detectsShame(lower) {
            return Result(
                action: .substituteResponse(
                    category: .shame,
                    safeResponseId: "safety.generic.deflect"
                ),
                originalText: text
            )
        }
        if detectsPushThroughPain(lower) {
            return Result(
                action: .substituteResponse(
                    category: .pushThroughPain,
                    safeResponseId: "safety.pain.stop"
                ),
                originalText: text
            )
        }
        return Result(action: .proceed, originalText: text)
    }

    private func detectsDiagnosis(_ lower: String) -> Bool {
        // Literal phrases.
        let phrases: [String] = [
            "you have tendinitis",
            "you have tendinopathy",
            "you have arthritis",
            "you have bursitis",
            "you probably have",
            "you're dealing with a strain",
            "you've torn your"
        ]
        if phrases.contains(where: { lower.contains($0) }) { return true }

        // Variants on "sounds/looks like a [word] tear/strain/sprain/rupture" —
        // LLMs often add a body-part qualifier ("rotator cuff tear", "meniscus
        // tear") that a literal substring miss.
        let diagnosticNouns = ["tear", "strain", "sprain", "rupture", "injury"]
        let diagnosticLeaders = ["sounds like a", "looks like a", "sounds like you have a",
                                 "looks like you have a", "must be a", "probably a"]
        for leader in diagnosticLeaders {
            guard let leaderRange = lower.range(of: leader) else { continue }
            let after = lower[leaderRange.upperBound...]
            // Look within the next ~6 words for a diagnostic noun.
            let window = after.prefix(60)
            if diagnosticNouns.contains(where: { window.contains($0) }) {
                return true
            }
        }
        return false
    }

    private func detectsUnsafeNutrition(_ lower: String) -> Bool {
        // Any direct calorie target below 1500 kcal/day or weight-cut prescription.
        let patterns: [String] = [
            "cut to 1200 calories",
            "eat 1000 calories",
            "eat 1100 calories",
            "eat 1200 calories",
            "eat 1300 calories",
            "eat 1400 calories",
            "fast for 48 hours",
            "drop to 10% body fat",
            "weight cut to 150",
            "cut weight fast"
        ]
        if patterns.contains(where: { lower.contains($0) }) { return true }
        // Broader numeric scan: any "eat 8xx/9xx/10xx/11xx/12xx/13xx/14xx calories" phrasing.
        if let range = lower.range(of: #"eat\s+\d{3,4}\s+calories"#, options: .regularExpression) {
            let matched = String(lower[range])
            if let num = matched.split(separator: " ").dropFirst().first.flatMap({ Int($0) }),
               num < 1500 {
                return true
            }
        }
        return false
    }

    private func detectsShame(_ lower: String) -> Bool {
        let patterns: [String] = [
            "pathetic", "you're weak", "that's embarrassing",
            "you should be ashamed", "quit being lazy"
        ]
        return patterns.contains(where: { lower.contains($0) })
    }

    private func detectsPushThroughPain(_ lower: String) -> Bool {
        // Fires if any of these coexist with a pain keyword in the same output.
        // (The LLM shouldn't, but this is belt-and-suspenders.)
        let pushWords = ["push through", "don't stop", "work through the pain", "keep going anyway"]
        let painWords = ["pain", "hurts", "sharp", "popped"]
        let hasPush = pushWords.contains(where: { lower.contains($0) })
        let hasPain = painWords.contains(where: { lower.contains($0) })
        return hasPush && hasPain
    }
}
