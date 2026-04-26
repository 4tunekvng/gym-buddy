import Foundation
import SwiftUI
import CoachingEngine

#if os(iOS)

/// Top-level navigation state. A single source of truth that the RootView
/// reacts to — no scattered NavigationLink isActive bindings.
///
/// Also carries transient hand-offs between screens (e.g. the `SessionObservation`
/// produced by LiveSession, consumed by PostSessionSummary). Screens never
/// inspect the router for state they own; they only read their hand-off slot.
@MainActor
final class AppRouter: ObservableObject {
    enum Screen: Equatable {
        case welcome
        case onboarding
        case today
        case liveSession(exerciseId: ExerciseID, setNumber: Int)
        case postSessionSummary
        case history
        case settings
    }

    @Published var current: Screen = .welcome
    @Published var isOnboarded: Bool = false

    /// Live-session → post-session hand-off. Cleared on consumption.
    @Published var lastSessionObservation: SessionObservation?

    func markOnboarded() {
        isOnboarded = true
        current = .today
    }

    func goToLiveSession(for exerciseId: ExerciseID, setNumber: Int) {
        lastSessionObservation = nil
        current = .liveSession(exerciseId: exerciseId, setNumber: setNumber)
    }

    func goToPostSessionSummary(with observation: SessionObservation) {
        lastSessionObservation = observation
        current = .postSessionSummary
    }

    func goToToday() {
        lastSessionObservation = nil
        current = .today
    }
}

#endif
