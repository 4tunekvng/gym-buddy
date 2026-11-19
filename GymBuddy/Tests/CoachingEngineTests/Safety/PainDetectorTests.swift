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

    func testNegationOfOneSpotDoesNotHidePainInAnother() {
        let transcript = "no pain in my knee but I felt a sharp pain in my shoulder"

        let trigger = detector.detect(in: transcript)

        XCTAssertEqual(trigger, "sharp pain")
    }

    func testEarlierNegationDoesNotHideNewPain() {
        let transcript = "it didn't hurt before but now something popped"

        let trigger = detector.detect(in: transcript)

        XCTAssertEqual(trigger, "something popped")
    }

    func testCasesInsensitive() {
        XCTAssertNotNil(detector.detect(in: "SHARP PAIN RIGHT NOW"))
    }
}
