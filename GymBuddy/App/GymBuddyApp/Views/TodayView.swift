import SwiftUI
import CoachingEngine
import Persistence
import DesignSystem

#if os(iOS)

/// The "home screen" after onboarding. Shows a personal greeting (PRD §6.5),
/// today's planned workout, and entry points to History + Settings.
///
/// The greeting is personalized with the user's name and references the first
/// injury the user flagged in onboarding if any. The exercise list shows each
/// exercise with its prescribed sets × reps (so the user knows what's ahead).
struct TodayView: View {
    @EnvironmentObject var composition: AppComposition
    let onStartLiveSession: (ExerciseID) -> Void
    let onHistory: () -> Void
    let onSettings: () -> Void

    @State private var greeting: String = "Welcome back."
    @State private var todayExercises: [PlannedExercise] = []
    @State private var userName: String = ""
    @State private var recentSessionCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            toolbar
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    greetingCard
                    todayCard
                    exercisesList
                    Spacer()
                }
                .padding(DS.Space.l)
            }
        }
        // Pin to the safe-area top edge. Without this the parent ZStack in
        // RootView centers the natural size of the VStack — which produces
        // a giant black band above the toolbar because the VStack only sizes
        // to its content, not the screen.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await load() }
    }

    private var toolbar: some View {
        HStack {
            Button(action: onHistory) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(DS.Color.textPrimary)
                    .padding(DS.Space.s)
            }
            .accessibilityIdentifier("today_history_button")
            Spacer()
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .foregroundStyle(DS.Color.textPrimary)
                    .padding(DS.Space.s)
            }
            .accessibilityIdentifier("today_settings_button")
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.top, DS.Space.m)
    }

    private var greetingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text("Good to see you, \(userName.isEmpty ? "friend" : userName).")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.textPrimary)
                Text(greeting)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.textSecondary)
                    .accessibilityIdentifier("today_greeting")
            }
        }
    }

    private var todayCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text("Today")
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.textSecondary)
                Text(todayExercises.isEmpty ? "Rest day." : todayExercises.map(\.exerciseId.displayName).joined(separator: " · "))
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.textPrimary)
                    .accessibilityIdentifier("today_exercise_list")
                if recentSessionCount > 0 {
                    Text("\(recentSessionCount) recent session\(recentSessionCount == 1 ? "" : "s") on file.")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .accessibilityIdentifier("today_recent_count")
                }
            }
        }
    }

    private var exercisesList: some View {
        VStack(spacing: DS.Space.m) {
            ForEach(todayExercises) { planned in
                Button {
                    onStartLiveSession(planned.exerciseId)
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            Text(planned.exerciseId.displayName)
                                .font(DS.Font.headline)
                                .foregroundStyle(DS.Color.textPrimary)
                            Text(prescribedString(for: planned))
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(DS.Color.accent)
                            .font(DS.Font.title)
                    }
                    .padding(DS.Space.l)
                    .background(DS.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
                }
                .accessibilityIdentifier("today_start_\(planned.exerciseId.rawValue)")
                .accessibilityLabel(Text("\(planned.exerciseId.displayName), \(prescribedString(for: planned))"))
            }
        }
    }

    /// Render a prescription as "3 × 10" or "3 × AMRAP" or "8 reps" for a single-set variant.
    private func prescribedString(for planned: PlannedExercise) -> String {
        let sets = planned.sets
        guard !sets.isEmpty else { return "—" }
        if sets.count == 1 {
            let s = sets[0]
            return s.isAmrap ? "AMRAP" : "\(s.targetReps) reps"
        }
        let allSame = sets.dropFirst().allSatisfy { $0.targetReps == sets[0].targetReps && $0.isAmrap == sets[0].isAmrap }
        if allSame {
            let s = sets[0]
            return s.isAmrap ? "\(sets.count) × AMRAP" : "\(sets.count) × \(s.targetReps)"
        }
        return sets.map { $0.isAmrap ? "AMRAP" : "\($0.targetReps)" }.joined(separator: " / ")
    }

    private func load() async {
        let profile = try? await composition.userProfileRepo.load()
        let plan = try? await composition.planRepo.activePlan()
        let recent = (try? await composition.sessionRepo.recent(limit: 100)) ?? []
        await MainActor.run {
            userName = profile?.displayName ?? ""
            let day = Self.pickTodayPlanDay(from: plan)
            todayExercises = day?.exercises ?? []
            greeting = buildGreeting(profile: profile, day: day, recentSessions: recent.count)
            recentSessionCount = recent.count
        }
    }

    /// Pick the right plan day for today. Delegates to the domain-layer
    /// `PlanDayPicker` so the logic is covered by Swift-package tests and
    /// shared across CLI / preview / iOS app.
    static func pickTodayPlanDay(from plan: Plan?) -> PlanDay? {
        PlanDayPicker.dayForToday(
            in: plan,
            weekdayMondayFirst: PlanDayPicker.mondayFirstWeekday()
        )
    }

    private func buildGreeting(profile: UserProfile?, day: PlanDay?, recentSessions: Int) -> String {
        guard day != nil else { return "Rest day. I'll see you tomorrow." }
        if profile?.injuryBodyParts.contains(.bodyPartKnee) == true {
            return "Warming into today's plan. How's the knee?"
        }
        if recentSessions == 0 {
            return "Ready when you are. Your first session is below."
        }
        return "Ready when you are. Today's plan is below."
    }
}

#endif
