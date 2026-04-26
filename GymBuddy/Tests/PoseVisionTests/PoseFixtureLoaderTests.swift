import XCTest
@testable import CoachingEngine
@testable import PoseVision

final class PoseFixtureLoaderTests: XCTestCase {

    func testLoadsValidFixture() throws {
        let json = """
        {
          "exerciseId": "push_up",
          "description": "one frame at top",
          "samples": [
            { "t": 0.0, "joints": {
                "leftShoulder": { "x": 0.3, "y": 0.4, "confidence": 0.95 },
                "rightShoulder": { "x": 0.32, "y": 0.4, "confidence": 0.95 }
              }
            }
          ]
        }
        """
        let result = try PoseFixtureLoader.loadFromString(json)
        XCTAssertEqual(result.exerciseId, .pushUp)
        XCTAssertEqual(result.samples.count, 1)
        XCTAssertEqual(result.samples.first?.joints.count, 2)
    }

    func testRejectsUnknownExerciseId() {
        let json = """
        { "exerciseId": "deadlift", "description": "x", "samples": [] }
        """
        do {
            _ = try PoseFixtureLoader.loadFromString(json)
            XCTFail("Expected error for unknown exercise")
        } catch PoseFixtureLoader.LoaderError.unknownExercise(let name) {
            XCTAssertEqual(name, "deadlift")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
