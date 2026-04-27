import SwiftUI
import CoachingEngine
import LLMClient
import Persistence
import DesignSystem

#if os(iOS)

/// Warm post-set summary (PRD §6.3).
///
/// Receives the `SessionObservation` produced by `LiveSessionViewModel` and
/// renders a grounded, specific summary. The LLM call is routed through the
/// composition's `SafeLLMClient` which applies the content-safety filter; if
/// the LLM output is substituted for safety reasons, we render a fallback
/// specific-numeric message instead of generic praise.
///
/// When `observation` is nil (shouldn't happen in normal navigation but we're
/// defensive), we show a placeholder rather than crashing.
struct PostSessionSummaryView: View {
    @EnvironmentObject var composition: AppComposition
    let observation: SessionObservation?
    let onDone: () -> Void

    @State private var summary: String = ""
    @State private var isLoading: Bool = true
    @State private var stats: [StatsRow] = []
    @State private var summarySourceLabel: String = ""

    struct StatsRow: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let value: String
    }

    var body: some View {
        VStack(spacing: DS.Space.l) {
            Spacer()
            Text("Set done")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.textPrimary)
                .accessibilityIdentifier("post_session_title")

            Card {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    if isLoading {
                        ProgressView()
                            .accessibilityIdentifier("post_session_loading")
                    } else {
                        Text(summary)
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Color.textPrimary)
                            .accessibilityIdentifier("post_session_summary_text")
                        if !summarySourceLabel.isEmpty {
                            Text(summarySourceLabel)
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                                .accessibilityIdentifier("post_session_summary_source")
                        }
                        if !stats.isEmpty {
                            Divider().background(DS.Color.separator)
                            ForEach(stats) { row in
                                HStack {
                                    Text(row.label)
                                        .font(DS.Font.caption)
                                        .foregroundStyle(DS.Color.textSecondary)
                                    Spacer()
                                    Text(row.value)
                                        .font(DS.Font.caption)
                                        .foregroundStyle(DS.Color.textPrimary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Space.l)

            Spacer()

            PrimaryButton(title: "Back to today", action: onDone)
                .padding(.horizontal, DS.Space.l)
                .padding(.bottom, DS.Space.xl)
                .accessibilityIdentifier("post_session_done")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadSummary() }
    }

    private func loadSummary() async {
        guard let obs = observation else {
            summary = "No session data."
            isLoading = false
            return
        }

        // 1. Render stats rows up front — they're deterministic and don't depend on LLM.
        var rows: [StatsRow] = [
            StatsRow(label: "Reps", value: "\(obs.totalReps)")
        ]
        if obs.partialReps > 0 {
            rows.append(StatsRow(label: "Full reps", value: "\(obs.fullReps)"))
            rows.append(StatsRow(label: "Partial", value: "\(obs.partialReps)"))
        }
        if let baseline = obs.tempoBaselineMs {
            rows.append(StatsRow(label: "Tempo baseline", value: "\(baseline) ms"))
        }
        if let fatigue = obs.fatigueSlowdownAtRep {
            rows.append(StatsRow(label: "Fatigue began", value: "rep \(fatigue)"))
        }
        rows.append(StatsRow(label: "Cues", value: "\(obs.cueEvents.count)"))
        stats = rows

        // 2. Ask the LLM for the warm paragraph. The SafeLLMClient will
        // substitute with a pre-recorded safe response if anything unsafe
        // slips through.
        let rendered = PromptRegistry.renderPostSetSummary(observation: obs, tone: .standard)
        let request = LLMRequest(
            promptId: rendered.id,
            promptVersion: rendered.version,
            system: rendered.system,
            user: rendered.user,
            temperature: 0.6,
            maxTokens: 200
        )
        let tone = (try? await composition.userProfileRepo.load())?.tone ?? .standard
        do {
            let response = try await composition.llmClient.complete(request: request)
            if response.text.hasPrefix("safe:") {
                // Safety substitution happened — show a deterministic
                // specific-numeric fallback instead of the safe-marker literal.
                summary = specificFallback(for: obs)
                summarySourceLabel = "Safety fallback"
            } else {
                summary = response.text
                summarySourceLabel = composition.runtimeStatus.llmLabel
            }
        } catch {
            summary = specificFallback(for: obs)
            summarySourceLabel = "Deterministic fallback"
        }

        if !summary.isEmpty {
            let spokenSummary = summary
            let stream = AsyncStream<String> { continuation in
                continuation.yield(spokenSummary)
                continuation.finish()
            }
            try? await composition.voicePlayer.speakStreaming(text: stream, tone: tone)
        }

        isLoading = false
    }

    /// OQ-009 fallback: never ship generic praise. Always include at least one
    /// quantitative fact. This kicks in if the LLM call fails or is substituted
    /// for safety reasons.
    private func specificFallback(for obs: SessionObservation) -> String {
        var parts: [String] = []
        parts.append("\(obs.totalReps) reps of \(obs.exerciseId.displayName).")
        if let fatigue = obs.fatigueSlowdownAtRep {
            parts.append("You hit the grind at rep \(fatigue).")
        } else if obs.partialReps == 0 {
            parts.append("Clean through the whole set.")
        }
        parts.append("Rest \(Int(90))s and go again.")
        return parts.joined(separator: " ")
    }
}

#endif
