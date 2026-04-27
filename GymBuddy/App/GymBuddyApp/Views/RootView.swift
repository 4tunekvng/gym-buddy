import SwiftUI
import DesignSystem

#if os(iOS)

struct RootView: View {
    @EnvironmentObject var composition: AppComposition
    @StateObject private var router = AppRouter()
    @State private var didCheckOnboarding = false

    var body: some View {
        ZStack {
            DS.Color.canvas.ignoresSafeArea()
            switch router.current {
            case .welcome:
                WelcomeView(onStart: { router.current = .onboarding })
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("screen_welcome")
            case .onboarding:
                OnboardingFlow(onFinish: { router.markOnboarded() })
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("screen_onboarding")
            case .today:
                TodayView(
                    onStartLiveSession: { exercise in
                        router.goToLiveSession(for: exercise, setNumber: 1)
                    },
                    onHistory: { router.current = .history },
                    onSettings: { router.current = .settings }
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("screen_today")
            case .liveSession(let exerciseId, let setNumber):
                LiveSessionView(
                    composition: composition,
                    exerciseId: exerciseId,
                    setNumber: setNumber,
                    onFinish: { observation in
                        router.goToPostSessionSummary(with: observation)
                    },
                    onCancel: {
                        router.goToToday()
                    }
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("screen_live_session")
            case .postSessionSummary:
                PostSessionSummaryView(
                    observation: router.lastSessionObservation,
                    onDone: { router.goToToday() }
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("screen_post_session")
            case .history:
                HistoryView(onBack: { router.current = .today })
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("screen_history")
            case .settings:
                SettingsView(onBack: { router.current = .today })
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("screen_settings")
            }
        }
        .environmentObject(router)
        .task {
            // On first appearance, check if a user profile is already on disk.
            // If so, skip straight to Today so returning users don't re-onboard.
            guard !didCheckOnboarding else { return }
            didCheckOnboarding = true
            if let _ = try? await composition.userProfileRepo.load() {
                router.isOnboarded = true
                router.current = .today
            }
        }
    }
}

#endif
