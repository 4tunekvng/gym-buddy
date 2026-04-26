import SwiftUI
import CoachingEngine
import PoseVision
import DesignSystem

#if os(iOS)

/// The live-session hero screen.
///
/// Composition injection: a @StateObject can't read @EnvironmentObject during
/// initializer evaluation, so the RootView passes `composition` in as a plain
/// parameter. The view model owns all session state; this view is render-only
/// apart from the two buttons ("Start set" on setup, "End set" during the set,
/// "Cancel" before setup).
struct LiveSessionView: View {
    @StateObject private var viewModel: LiveSessionViewModel

    init(
        composition: AppComposition,
        exerciseId: ExerciseID,
        setNumber: Int,
        onFinish: @escaping (SessionObservation) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: LiveSessionViewModel(
            composition: composition,
            exerciseId: exerciseId,
            setNumber: setNumber,
            tone: .standard,
            memoryReferences: [],
            userId: UUID(),
            onFinish: onFinish,
            onCancel: onCancel
        ))
    }

    var body: some View {
        ZStack {
            DS.Color.canvas.ignoresSafeArea()

            if viewModel.isSetupComplete {
                liveHUD
            } else {
                SetupOverlay(checks: viewModel.setupChecks) {
                    Task { await viewModel.completeSetupAndStart() }
                }
                .padding(.horizontal, DS.Space.m)
            }

            VStack {
                topBar
                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textOnAccent)
                        .padding(DS.Space.s)
                        .background(DS.Color.warning.opacity(0.92), in: RoundedRectangle(cornerRadius: DS.Radius.small))
                        .padding(.horizontal, DS.Space.m)
                        .accessibilityIdentifier("live_error_banner")
                }
                Spacer()
                // Only show the bottom action once setup is complete. Before
                // that the SetupOverlay owns the primary action and a Cancel
                // here would overlap the overlay's "Start set" button in the
                // ZStack, hijacking taps intended for Start.
                if viewModel.isSetupComplete {
                    bottomBar
                }
            }
        }
    }

    /// Small top-right area for pre-session cancel. We can't use SwiftUI's
    /// `.toolbar` here because the app doesn't wrap its screens in a
    /// NavigationStack — toolbar items silently wouldn't render. Inline
    /// placement sidesteps that and sits above the SetupOverlay (which starts
    /// below the safe area) so it doesn't intercept overlay taps.
    @ViewBuilder
    private var topBar: some View {
        HStack {
            Spacer()
            if !viewModel.isSetupComplete {
                Button("Cancel") {
                    Task { await viewModel.cancel() }
                }
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.textPrimary)
                .padding(DS.Space.m)
                .accessibilityIdentifier("live_cancel")
            }
        }
        .padding(.top, DS.Space.s)
    }

    private var liveHUD: some View {
        VStack(spacing: DS.Space.l) {
            Text(viewModel.exerciseId.displayName)
                .font(DS.Font.headline)
                .foregroundStyle(DS.Color.textSecondary)
                .padding(.top, DS.Space.xxl)
                .accessibilityIdentifier("live_exercise_label")
            Spacer()
            RepCounterHUD(
                repCount: viewModel.repCount,
                partialMarker: viewModel.isPartialRep,
                cueText: viewModel.cueText
            )
            if let enc = viewModel.lastEncouragement {
                Text(enc.uppercased())
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.accent)
                    .padding(DS.Space.m)
                    .transition(.scale.combined(with: .opacity))
                    .id(enc)   // force new view so the transition re-plays on change
                    .accessibilityIdentifier("live_encouragement")
            }
            Spacer()
        }
        .animation(DS.Motion.standardSpring, value: viewModel.lastEncouragement)
    }

    /// Bottom action bar. Only visible once setup is complete.
    private var bottomBar: some View {
        HStack(spacing: DS.Space.m) {
            SecondaryButton(title: "End set") {
                Task { await viewModel.finishExplicitly() }
            }
            .accessibilityIdentifier("live_end_set")
        }
        .padding(DS.Space.l)
    }
}

#endif
