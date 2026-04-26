import Foundation
import CoachingEngine
import PoseVision

/// CLI harness for the offline coaching engine. Pipes pose fixtures through
/// the engine and prints every emitted intent. This is the M1 demo tool per
/// MILESTONES.md.
///
/// Usage:
///   coaching-cli fixture-path.json
///
/// If no argument is given, we run the built-in synthetic push-up fixture
/// with 13 reps (ramped fatigue) — the north-star demo scenario.

@main
struct CoachingCLI {
    static func main() {
        let args = CommandLine.arguments.dropFirst()
        let result = run(args: Array(args))
        if result != 0 {
            FileHandle.standardError.write(Data("\(result)\n".utf8))
        }
        exit(Int32(result))
    }

    static func run(args: [String]) -> Int32 {
        let samples: [PoseSample]
        let exerciseId: ExerciseID

        if let firstArg = args.first {
            let url = URL(fileURLWithPath: firstArg)
            do {
                let loaded = try PoseFixtureLoader.load(from: url)
                samples = loaded.samples
                exerciseId = loaded.exerciseId
            } catch {
                print("Failed to load fixture: \(error)")
                return 1
            }
        } else {
            print("No fixture argument — running built-in north-star push-up demo (13 reps, fatigue ramp).")
            exerciseId = .pushUp
            samples = buildHeroFixture()
        }

        let config = SessionConfig(exerciseId: exerciseId, setNumber: 1, targetReps: nil, tone: .standard)
        let context = SessionContext(userId: UUID(), tone: .standard, priorSessionBestReps: [exerciseId: 11])
        let orchestrator = SessionOrchestrator(config: config, context: context)

        var totalIntents = 0
        for sample in samples {
            let intents = orchestrator.observe(sample: sample)
            for intent in intents {
                totalIntents += 1
                print(render(intent))
            }
        }

        let obs = orchestrator.buildObservation()
        print("")
        print("— Set complete —")
        print("Reps: \(obs.totalReps) (full: \(obs.fullReps), partial: \(obs.partialReps))")
        if let baseline = obs.tempoBaselineMs { print("Tempo baseline: \(baseline) ms") }
        if let fatigue = obs.fatigueSlowdownAtRep { print("Fatigue began at rep: \(fatigue)") }
        print("Cues: \(obs.cueEvents.count)")
        return 0
    }

    static func render(_ intent: CoachingIntent) -> String {
        switch intent {
        case .sayRepCount(let n, let t): return String(format: "[%.2f] Rep: %d", t, n)
        case .formCue(let cue): return "[cue] \(cue.cueType.rawValue) severity=\(cue.severity)"
        case .encouragement(let kind, _, let t): return String(format: "[%.2f] encouragement: %@", t, String(describing: kind))
        case .setEnded(let e): return "[set-ended] reps=\(e.totalReps) reason=\(e.reason)"
        case .startRest(let s): return "[rest] \(Int(s))s"
        case .contextualSpeech: return "[contextual speech]"
        case .painStop(let tr): return "[PAIN-STOP] \(tr)"
        }
    }

    // Built-in hero fixture — 13 push-up reps with fatigue ramp. Mirrors the
    // north-star demo test but lives here so the CLI demo can run standalone.
    static func buildHeroFixture() -> [PoseSample] {
        var samples: [PoseSample] = []
        var t: TimeInterval = 0
        let dt = 1.0 / 30.0
        for _ in 0..<30 {
            samples.append(Self.pushUpSample(elbow: 170, t: t))
            t += dt
        }
        for rep in 1...13 {
            let concentric: TimeInterval = rep <= 7 ? 1.0 : 1.0 + Double(rep - 7) / 6.0 * 1.0
            let eccentric: TimeInterval = 0.8
            for i in 0..<max(1, Int(eccentric * 30)) {
                let phase = Double(i + 1) / Double(Int(eccentric * 30))
                samples.append(Self.pushUpSample(elbow: 170 - 75 * phase, t: t))
                t += dt
            }
            for _ in 0..<3 { samples.append(Self.pushUpSample(elbow: 95, t: t)); t += dt }
            for i in 0..<max(1, Int(concentric * 30)) {
                let phase = Double(i + 1) / Double(Int(concentric * 30))
                samples.append(Self.pushUpSample(elbow: 95 + 75 * phase, t: t))
                t += dt
            }
            for _ in 0..<3 { samples.append(Self.pushUpSample(elbow: 170, t: t)); t += dt }
        }
        for _ in 0..<(30 * 5) { samples.append(Self.pushUpSample(elbow: 170, t: t)); t += dt }
        return samples
    }

    static func pushUpSample(elbow: Double, t: TimeInterval) -> PoseSample {
        SyntheticPoseGenerator.pushUpPoseAt(elbowDegrees: elbow, t: t)
    }
}
