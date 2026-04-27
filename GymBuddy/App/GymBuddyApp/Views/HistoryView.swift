import SwiftUI
import CoachingEngine
import Persistence
import DesignSystem

#if os(iOS)

struct HistoryView: View {
    @EnvironmentObject var composition: AppComposition
    let onBack: () -> Void

    @State private var sessions: [WorkoutSessionRecord] = []

    var body: some View {
        VStack(spacing: DS.Space.m) {
            HStack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                }
                .accessibilityIdentifier("history_back")
                Spacer()
            }
            .padding(DS.Space.m)
            Text("History").font(DS.Font.title).foregroundStyle(DS.Color.textPrimary)

            if sessions.isEmpty {
                Spacer()
                Text("No sessions yet. After your first live session, you'll see your progression here.")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(DS.Space.l)
                Spacer()
            } else {
                List(sessions) { session in
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(DS.Font.headline)
                        ForEach(session.performedExercises) { ex in
                            Text("\(ex.exerciseId.displayName) — \(ex.performedSets.map { "\($0.reps)" }.joined(separator: " / "))")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }
                .listStyle(.plain)
                .accessibilityIdentifier("history_list")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task { await load() }
    }

    private func load() async {
        let recent = (try? await composition.sessionRepo.recent(limit: 30)) ?? []
        await MainActor.run { sessions = recent }
    }
}

#endif
