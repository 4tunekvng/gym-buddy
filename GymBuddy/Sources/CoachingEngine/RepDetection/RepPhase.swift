import Foundation

/// The rep FSM's four states. Shared across all exercises — the state names
/// describe rep-cycle phases, not specific joint positions, so the same FSM
/// shape applies to push-ups, squats, and rows.
public enum RepPhase: String, Codable, Sendable {
    case idle         // body detected, not yet in a rep
    case top          // at top of rep, ready to descend (or just finished a rep)
    case descending   // moving through the eccentric phase
    case bottom       // at bottom of rep, brief dwell
    case ascending    // moving through the concentric phase

    public var isInSet: Bool { self != .idle }
}
