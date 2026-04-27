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
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isSetupComplete {
            VStack(spacing: 0) {
                topBar
                if viewModel.isRunningDemoFixture {
                    demoModeBanner
                        .padding(.bottom, DS.Space.s)
                }
                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textOnAccent)
                        .padding(DS.Space.s)
                        .background(DS.Color.warning.opacity(0.92), in: RoundedRectangle(cornerRadius: DS.Radius.small))
                        .padding(.horizontal, DS.Space.m)
                        .padding(.bottom, DS.Space.s)
                        .accessibilityIdentifier("live_error_banner")
                }

                Text(viewModel.exerciseId.displayName)
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .accessibilityIdentifier("live_exercise_label")

                Spacer(minLength: DS.Space.l)

                RepCounterHUD(
                    repCount: viewModel.repCount,
                    partialMarker: viewModel.isPartialRep,
                    cueText: viewModel.cueText
                )

                if let enc = viewModel.lastEncouragement {
                    Text(enc.uppercased())
                        .font(DS.Font.title)
                        .foregroundStyle(DS.Color.accent)
                        .padding(.top, DS.Space.m)
                        .transition(.scale.combined(with: .opacity))
                        .id(enc)
                        .accessibilityIdentifier("live_encouragement")
                }

                Spacer(minLength: DS.Space.l)

                spokenPhraseBubble
                    .padding(.horizontal, DS.Space.l)

                Button {
                    Task { await viewModel.finishExplicitly() }
                } label: {
                    Text("End set")
                        .font(DS.Font.headline)
                        .foregroundStyle(DS.Color.textOnAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(DS.Color.accent, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DS.Space.l)
                .padding(.bottom, DS.Space.l)
                .accessibilityIdentifier("live_end_set")
            }
            .animation(DS.Motion.standardSpring, value: viewModel.lastEncouragement)
            .animation(DS.Motion.fastEase, value: viewModel.lastSpokenPhrase)
        } else {
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                SetupOverlay(checks: viewModel.setupChecks) {
                    Task { await viewModel.completeSetupAndStart() }
                }
                .padding(.horizontal, DS.Space.m)
                Spacer(minLength: 0)
            }
        }
    }

    /// Banner that says "Running demo (no camera)". Tells the user the rep
    /// counter is being driven by a synthetic pose stream, so they understand
    /// what they're watching when the device they're on doesn't have a usable
    /// camera (Simulator, denied permission).
    private var demoModeBanner: some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(.black)
            Text("Running demo — no camera attached")
                .font(DS.Font.caption)
                .foregroundStyle(.black)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, DS.Space.s)
        // High-contrast accent capsule so it can't blend into the canvas. The
        // PRD-correct subdued styling lands once on-device camera is wired up;
        // for the simulator this needs to be visible at a glance.
        .background(DS.Color.accent, in: Capsule())
        .padding(.horizontal, DS.Space.m)
        .accessibilityIdentifier("live_demo_banner")
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

    // Old-style liveHUD kept only as a stub — the live content now lives directly
    // inside `content` so SwiftUI can flow Spacers/buttons in one VStack.
    private var liveHUD: some View {
        EmptyView()
    }

    @ViewBuilder
    private var spokenPhraseBubble: some View {
        if let phrase = viewModel.lastSpokenPhrase {
            HStack(spacing: DS.Space.s) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(DS.Color.accent)
                Text("\u{201C}\(phrase)\u{201D}")
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Space.l)
            .padding(.vertical, DS.Space.m)
            // The bubble was using `surface` which is almost identical to
            // `canvas`, making it functionally invisible at a glance. Use a
            // border + slightly elevated bg so it actually reads.
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.medium)
                    .fill(DS.Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.medium)
                            .stroke(DS.Color.accent.opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.bottom, DS.Space.l)
            .id(phrase)
            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
            .accessibilityIdentifier("live_spoken_phrase")
            .accessibilityLabel(Text("Coach said: \(phrase)"))
        }
    }

    // bottomBar is no longer used — End set button is now inline in `content`.
    private var bottomBar: some View { EmptyView() }
}

#endif
