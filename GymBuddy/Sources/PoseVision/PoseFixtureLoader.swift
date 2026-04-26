import Foundation
import CoachingEngine

/// Load JSON-encoded pose fixtures.
///
/// Fixture format (JSON):
/// ```json
/// {
///   "exerciseId": "push_up",
///   "description": "10 clean reps",
///   "samples": [
///     { "t": 0.00, "joints": { "leftShoulder": { "x": 0.4, "y": 0.4, "confidence": 0.95 }, ... } },
///     ...
///   ]
/// }
/// ```
public enum PoseFixtureLoader {

    public struct Fixture: Codable, Equatable, Sendable {
        public let exerciseId: String
        public let description: String
        public let samples: [RawSample]

        public struct RawSample: Codable, Equatable, Sendable {
            public let t: Double
            public let joints: [String: RawKeypoint]
        }

        public struct RawKeypoint: Codable, Equatable, Sendable {
            public let x: Double
            public let y: Double
            public let confidence: Double
        }
    }

    public static func load(from url: URL) throws -> (exerciseId: ExerciseID, samples: [PoseSample]) {
        let data = try Data(contentsOf: url)
        let fixture = try JSONDecoder().decode(Fixture.self, from: data)
        guard let exerciseId = ExerciseID(rawValue: fixture.exerciseId) else {
            throw LoaderError.unknownExercise(fixture.exerciseId)
        }
        let samples: [PoseSample] = fixture.samples.map { raw in
            var mapped: [JointName: Keypoint] = [:]
            for (rawName, kp) in raw.joints {
                if let name = JointName(rawValue: rawName) {
                    mapped[name] = Keypoint(x: kp.x, y: kp.y, confidence: kp.confidence)
                }
            }
            return PoseSample(timestamp: raw.t, joints: mapped)
        }
        return (exerciseId, samples)
    }

    public static func loadFromString(_ json: String) throws -> (exerciseId: ExerciseID, samples: [PoseSample]) {
        guard let data = json.data(using: .utf8) else { throw LoaderError.invalidEncoding }
        let fixture = try JSONDecoder().decode(Fixture.self, from: data)
        guard let exerciseId = ExerciseID(rawValue: fixture.exerciseId) else {
            throw LoaderError.unknownExercise(fixture.exerciseId)
        }
        let samples: [PoseSample] = fixture.samples.map { raw in
            var mapped: [JointName: Keypoint] = [:]
            for (rawName, kp) in raw.joints {
                if let name = JointName(rawValue: rawName) {
                    mapped[name] = Keypoint(x: kp.x, y: kp.y, confidence: kp.confidence)
                }
            }
            return PoseSample(timestamp: raw.t, joints: mapped)
        }
        return (exerciseId, samples)
    }

    public enum LoaderError: Error, Equatable {
        case unknownExercise(String)
        case invalidEncoding
    }
}
