import Foundation

/// The 3 exercises in scope for Chapter 1.
///
/// Adding a fourth requires an ADR — default answer is no (see PRD §3.3).
/// Use a stable string raw value so persisted data survives schema evolution.
public enum ExerciseID: String, Codable, CaseIterable, Sendable {
    case pushUp = "push_up"
    case gobletSquat = "goblet_squat"
    case dumbbellRow = "dumbbell_row"

    /// A human-readable name suitable for UI and voice phrasing.
    public var displayName: String {
        switch self {
        case .pushUp: "Push-up"
        case .gobletSquat: "Goblet squat"
        case .dumbbellRow: "Dumbbell row"
        }
    }

    /// The primary movement pattern. Used by plan generation and substitution logic.
    public var movementPattern: MovementPattern {
        switch self {
        case .pushUp: .horizontalPush
        case .gobletSquat: .squat
        case .dumbbellRow: .horizontalPull
        }
    }
}

public enum MovementPattern: String, Codable, Sendable {
    case horizontalPush
    case horizontalPull
    case verticalPush
    case verticalPull
    case squat
    case hinge
    case lunge
    case carry
}
