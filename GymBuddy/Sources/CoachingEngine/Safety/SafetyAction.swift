import Foundation

/// The safety layer's directive to the rest of the system.
public enum SafetyAction: Equatable, Sendable {
    /// Everything is fine. Proceed.
    case proceed
    /// Stop the set immediately; pain signal detected.
    case stopSet(trigger: String)
    /// LLM output contained something unsafe; substitute with a safe response.
    case substituteResponse(category: SafetyCategory, safeResponseId: String)
}

public enum SafetyCategory: String, Codable, Sendable {
    case diagnosis
    case unsafeNutrition
    case shame
    case pushThroughPain
    case unknown
}
