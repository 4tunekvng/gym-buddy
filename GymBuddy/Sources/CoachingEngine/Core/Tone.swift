import Foundation

/// The coaching tone preference.
///
/// Same coach, different delivery. See PRD §6.4 and ADR-0002 for how this maps
/// to the pre-cached TTS variant bundles.
public enum CoachingTone: String, Codable, CaseIterable, Sendable {
    case quiet
    case standard
    case intense

    public var displayName: String {
        switch self {
        case .quiet: "Quiet"
        case .standard: "Standard"
        case .intense: "Intense"
        }
    }
}
