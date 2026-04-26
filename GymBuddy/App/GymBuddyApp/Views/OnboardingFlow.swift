import SwiftUI
import CoachingEngine
import Persistence
import DesignSystem

#if os(iOS)

/// 5–7 minute conversational onboarding. Voice-forward when mic is tapped,
/// typed otherwise. Collects: name, goal, experience, equipment, injuries,
/// sessions/week, tone preference.
struct OnboardingFlow: View {
    @EnvironmentObject var composition: AppComposition
    let onFinish: () -> Void

    @State private var step: Step = .name
    @State private var displayName: String = ""
    @State private var goal: PlanGenerator.Inputs.Goal = .hypertrophy
    @State private var experience: PlanGenerator.Inputs.Experience = .intermediate
    @State private var equipment: PlanGenerator.Inputs.Equipment = .dumbbells
    @State private var sessionsPerWeek: Int = 3
    @State private var kneeInjury: Bool = false
    @State private var shoulderInjury: Bool = false
    @State private var backInjury: Bool = false
    @State private var tone: CoachingTone = .standard

    enum Step: CaseIterable {
        case name, goal, experience, equipment, frequency, injuries, tone, review
    }

    var body: some View {
        VStack {
            header
            Spacer(minLength: DS.Space.l)
            body(for: step)
                .transition(.opacity)
            Spacer()
            footer
        }
        .padding(DS.Space.l)
        .animation(DS.Motion.fastEase, value: step)
    }

    private var header: some View {
        HStack {
            Text("Step \(stepIndex + 1) of \(Step.allCases.count)")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Spacer()
            ProgressView(value: Double(stepIndex + 1), total: Double(Step.allCases.count))
                .tint(DS.Color.accent)
                .frame(width: 120)
        }
        .padding(.top, DS.Space.m)
    }

    private var stepIndex: Int {
        Step.allCases.firstIndex(of: step) ?? 0
    }

    @ViewBuilder
    private func body(for step: Step) -> some View {
        switch step {
        case .name:
            VStack(alignment: .leading, spacing: DS.Space.m) {
                Text("What should I call you?").font(DS.Font.title).foregroundStyle(DS.Color.textPrimary)
                TextField("Name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("onboarding_name_field")
            }
        case .goal:
            pickerStep(
                title: "What are we chasing?",
                selection: $goal,
                options: [
                    (.strength, "Strength"),
                    (.hypertrophy, "Hypertrophy"),
                    (.recomp, "Body recomp"),
                    (.maintenance, "Maintain")
                ]
            )
        case .experience:
            pickerStep(
                title: "How long have you been training?",
                selection: $experience,
                options: [
                    (.beginner, "Just getting started"),
                    (.intermediate, "A year or two"),
                    (.advanced, "Several years")
                ]
            )
        case .equipment:
            pickerStep(
                title: "What do you have at home?",
                selection: $equipment,
                options: [
                    (.bodyweightOnly, "Bodyweight"),
                    (.dumbbells, "Dumbbells"),
                    (.dumbbellsAndBench, "Dumbbells + bench")
                ]
            )
        case .frequency:
            VStack(alignment: .leading, spacing: DS.Space.m) {
                Text("How many sessions per week?").font(DS.Font.title).foregroundStyle(DS.Color.textPrimary)
                Stepper("\(sessionsPerWeek) sessions", value: $sessionsPerWeek, in: 2...5)
                    .accessibilityIdentifier("onboarding_frequency_stepper")
            }
        case .injuries:
            VStack(alignment: .leading, spacing: DS.Space.m) {
                Text("Anything bothering you these days?").font(DS.Font.title).foregroundStyle(DS.Color.textPrimary)
                Toggle("Knee", isOn: $kneeInjury).accessibilityIdentifier("injury_knee")
                Toggle("Shoulder", isOn: $shoulderInjury).accessibilityIdentifier("injury_shoulder")
                Toggle("Lower back", isOn: $backInjury).accessibilityIdentifier("injury_back")
            }
        case .tone:
            pickerStep(
                title: "How do you like to be coached?",
                selection: $tone,
                options: [
                    (.quiet, "Quiet — spare the words"),
                    (.standard, "Standard — warm and honest"),
                    (.intense, "Intense — push me hard")
                ]
            )
        case .review:
            VStack(alignment: .leading, spacing: DS.Space.m) {
                Text("Review").font(DS.Font.title).foregroundStyle(DS.Color.textPrimary)
                Text("We'll put together a 4-week plan for you. You can change any of this in settings later.")
                    .font(DS.Font.body).foregroundStyle(DS.Color.textSecondary)
                summaryRow("Name", displayName)
                summaryRow("Goal", goal.rawValue)
                summaryRow("Experience", experience.rawValue)
                summaryRow("Sessions/week", "\(sessionsPerWeek)")
                summaryRow("Tone", tone.displayName)
            }
        }
    }

    private func pickerStep<T: Hashable>(
        title: String,
        selection: Binding<T>,
        options: [(T, String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text(title).font(DS.Font.title).foregroundStyle(DS.Color.textPrimary)
            ForEach(options.indices, id: \.self) { i in
                let opt = options[i]
                Button(action: { selection.wrappedValue = opt.0 }) {
                    HStack {
                        Text(opt.1)
                            .font(DS.Font.headline)
                            .foregroundStyle(DS.Color.textPrimary)
                        Spacer()
                        Image(systemName: selection.wrappedValue == opt.0 ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selection.wrappedValue == opt.0 ? DS.Color.accent : DS.Color.textSecondary)
                    }
                    .padding(DS.Space.m)
                    .background(DS.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
                }
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(DS.Font.body).foregroundStyle(DS.Color.textSecondary)
            Spacer()
            Text(value).font(DS.Font.body).foregroundStyle(DS.Color.textPrimary)
        }
    }

    private var footer: some View {
        HStack(spacing: DS.Space.m) {
            if step != .name {
                SecondaryButton(title: "Back", action: goBack)
                    .accessibilityIdentifier("onboarding_back")
            }
            PrimaryButton(
                title: step == .review ? "Let's go" : "Continue",
                action: step == .review ? finish : advance
            )
            .accessibilityIdentifier("onboarding_next")
            .disabled(step == .name && displayName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func advance() {
        guard let idx = Step.allCases.firstIndex(of: step), idx < Step.allCases.count - 1 else { return }
        step = Step.allCases[idx + 1]
    }

    private func goBack() {
        guard let idx = Step.allCases.firstIndex(of: step), idx > 0 else { return }
        step = Step.allCases[idx - 1]
    }

    private func finish() {
        var injuries: Set<MemoryTag> = []
        if kneeInjury { injuries.insert(.bodyPartKnee) }
        if shoulderInjury { injuries.insert(.bodyPartShoulder) }
        if backInjury { injuries.insert(.bodyPartBack) }

        let profile = UserProfile(
            displayName: displayName,
            tone: tone,
            experience: experience,
            goal: goal,
            equipment: equipment,
            sessionsPerWeek: sessionsPerWeek,
            injuryBodyParts: injuries
        )
        let plan = PlanGenerator().generate(from: PlanGenerator.Inputs(
            goal: goal,
            experience: experience,
            equipment: equipment,
            sessionsPerWeek: sessionsPerWeek,
            injuryBodyParts: injuries
        ))
        Task {
            try? await composition.userProfileRepo.save(profile)
            try? await composition.planRepo.save(plan)
            await MainActor.run { onFinish() }
        }
    }
}

#endif
