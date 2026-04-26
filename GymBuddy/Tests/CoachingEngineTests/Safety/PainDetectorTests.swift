import XCTest
@testable import CoachingEngine

final class PainDetectorTests: XCTestCase {
    let detector = PainDetector()

    func testDetectsSharpPain() {
        XCTAssertNotNil(detector.detect(in: "I feel a sharp pain in my shoulder"))
    }

    func testDetectsSomethingPopped() {
        XCTAssertNotNil(detector.detect(in: "I think something popped"))
    }

    func testDetectsBareHurts() {
        XCTAssertNotNil(detector.detect(in: "that hurts"))
    }

    func testDoesNotFireOnMuscleBurn() {
        XCTAssertNil(detector.detect(in: "my legs are burning"))
        XCTAssertNil(detector.detect(in: "this feels like muscle fatigue"))
    }

    func testDoesNotFireOnNegatedContext() {
        XCTAssertNil(detector.detect(in: "it doesn't hurt"))
        XCTAssertNil(detector.detect(in: "there's no pain"))
        XCTAssertNil(detector.detect(in: "nothing is hurting"))
    }

    func testCasesInsensitive() {
        XCTAssertNotNil(detector.detect(in: "SHARP PAIN RIGHT NOW"))
    }
}
