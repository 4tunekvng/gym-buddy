import Foundation

/// Generates a 4-week linear-progression plan.
///
/// Inputs: goal, frequency, equipment, experience, injuries.
/// Output: a `Plan` where weeks 1→4 progress in reps (and optionally a slight
/// volume bump by adding one backoff set in week 3).
///
/// Intentionally simple per the PRD — no adaptive replanning in MVP.
public struct PlanGenerator: Sendable {
    public struct Inputs: Equatable, Sendable {
        public enum Goal: String, Codable, Sendable {
            case strength
            case hypertrophy
            case recomp
            case maintenance
        }

        public enum Experience: String, Codable, Sendable {
            case beginner, intermediate, advanced
        }

        public enum Equipment: String, Codable, Sendable {
            case bodyweightOnly
            case dumbbells
            case dumbbellsAndBench
        }

        public let goal: Goal
        public let experience: Experience
        public let equipment: Equipment
        public let sessionsPerWeek: Int
        public let injuryBodyParts: Set<MemoryTag>

        public init(
            goal: Goal,
            experience: Experience,
            equipment: Equipment,
            sessionsPerWeek: Int,
            injuryBodyParts: Set<MemoryTag> = []
        ) {
            self.goal = goal
            self.experience = experience
            self.equipment = equipment
            self.sessionsPerWeek = sessionsPerWeek
            self.injuryBodyParts = injuryBodyParts
        }
    }

    public init() {}

    public func generate(from inputs: Inputs) -> Plan {
        let baseReps = baseReps(for: inputs)
        let sets = baseSets(for: inputs)
        let daysPerWeek = clamp(inputs.sessionsPerWeek, to: 2...5)
        let workoutDays: [Int] = distribute(daysPerWeek, over: 7)
        let exercises = orderedExercises(for: inputs)

        var weeks: [PlanWeek] = []
        for weekIndex in 0..<4 {
            var days: [PlanDay] = []
            for day in 1...7 {
                let isWorkout = workoutDays.contains(day)
                let dayExercises: [PlannedExercise] = isWorkout
                    ? exercises.map { exerciseId in
                        PlannedExercise(
                            exerciseId: exerciseId,
                            sets: (1...sets).map { setNumber in
                                let repDelta = weekIndex * 1
                                let isAmrap = (setNumber == sets) && exerciseId == .pushUp
                                return PlannedSet(
                                    setNumber: setNumber,
                                    targetReps: baseReps + repDelta,
                                    isAmrap: isAmrap
                                )
                            }
                        )
                    }
                    : []
                days.append(PlanDay(
                    weekNumber: weekIndex + 1,
                    dayOfWeek: day,
                    isRestDay: !isWorkout,
                    exercises: dayExercises
                ))
            }
            weeks.append(PlanWeek(weekNumber: weekIndex + 1, days: days))
        }
        return Plan(
            weeks: weeks,
            rationale: rationaleString(for: inputs)
        )
    }

    private func baseReps(for inputs: Inputs) -> Int {
        switch (inputs.goal, inputs.experience) {
        case (.strength, .advanced): return 5
        case (.strength, _): return 6
        case (.hypertrophy, _): return 10
        case (.recomp, _): return 8
        case (.maintenance, _): return 10
        }
    }

    private func baseSets(for inputs: Inputs) -> Int {
        switch inputs.experience {
        case .beginner: return 2
        case .intermediate: return 3
        case .advanced: return 4
        }
    }

    private func orderedExercises(for inputs: Inputs) -> [ExerciseID] {
        var base: [ExerciseID] = [.pushUp, .dumbbellRow, .gobletSquat]
        // Simple injury-based swap (MVP): skip squats if knee injury.
        if inputs.injuryBodyParts.contains(.bodyPartKnee) {
            base.removeAll { $0 == .gobletSquat }
        }
        // Skip dumbbell row if dumbbells not available (shouldn't happen given scope).
        if inputs.equipment == .bodyweightOnly {
            base.removeAll { $0 == .dumbbellRow || $0 == .gobletSquat }
        }
        return base
    }

    private func distribute(_ days: Int, over week: Int) -> [Int] {
        // Evenly distribute workout days. 3/week → M, W, F. 4/week → M, Tu, Th, Sa. etc.
        guard days > 0 else { return [] }
        let spacing = Double(week) / Double(days)
        return (0..<days).map { Int(round(Double($0) * spacing)) + 1 }.map { min($0, 7) }
    }

    private func rationaleString(for inputs: Inputs) -> String {
        "Linear progression plan: \(inputs.sessionsPerWeek) days/week, \(inputs.goal.rawValue) focus, scaled for \(inputs.experience.rawValue). Adds 1 rep per set per week over 4 weeks."
    }

    private func clamp(_ v: Int, to range: ClosedRange<Int>) -> Int {
        min(max(v, range.lowerBound), range.upperBound)
    }
}
