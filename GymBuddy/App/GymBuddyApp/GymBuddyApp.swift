import SwiftUI
import CoachingEngine
import PoseVision
import VoiceIO
import LLMClient
import Persistence
import HealthKitBridge
import DesignSystem
import Telemetry

#if os(iOS)

/// The app composition root. All dependency wiring happens here — view layer
/// receives already-composed protocols, never instantiates concrete adapters.
@main
struct GymBuddyApp: App {
    @StateObject private var composition = AppComposition.makeProduction()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(composition)
                .preferredColorScheme(.dark)
        }
    }
}

#endif
