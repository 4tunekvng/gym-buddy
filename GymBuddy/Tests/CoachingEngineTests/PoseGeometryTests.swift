import XCTest
@testable import CoachingEngine

final class PoseGeometryTests: XCTestCase {

    func testAngleInterior90Degrees() {
        // At vertex (0,0), with a=(1,0) and b=(0,1), the interior angle is 90°.
        let vertex = Keypoint(x: 0, y: 0, confidence: 1)
        let a = Keypoint(x: 1, y: 0, confidence: 1)
        let b = Keypoint(x: 0, y: 1, confidence: 1)
        let angle = PoseGeometry.angle(at: vertex, between: a, and: b)
        XCTAssertEqual(angle?.degrees ?? 0, 90, accuracy: 0.01)
    }

    func testAngleInterior180DegreesCollinear() {
        let vertex = Keypoint(x: 0, y: 0, confidence: 1)
        let a = Keypoint(x: -1, y: 0, confidence: 1)
        let b = Keypoint(x: 1, y: 0, confidence: 1)
        let angle = PoseGeometry.angle(at: vertex, between: a, and: b)
        XCTAssertEqual(angle?.degrees ?? 0, 180, accuracy: 0.01)
    }

    func testAngleReturnsNilOnUnreliableKeypoint() {
        let vertex = Keypoint(x: 0, y: 0, confidence: 0.1)    // unreliable
        let a = Keypoint(x: 1, y: 0, confidence: 1)
        let b = Keypoint(x: 0, y: 1, confidence: 1)
        XCTAssertNil(PoseGeometry.angle(at: vertex, between: a, and: b))
    }

    func testPerpendicularDistanceKnownValue() {
        // Point (0,1) to line y=0 should have distance 1.
        let p = Keypoint(x: 0, y: 1, confidence: 1)
        let a = Keypoint(x: -1, y: 0, confidence: 1)
        let b = Keypoint(x: 1, y: 0, confidence: 1)
        let d = PoseGeometry.perpendicularDistance(from: p, toLineThrough: a, and: b)
        XCTAssertEqual(d ?? 0, 1.0, accuracy: 1e-9)
    }

    func testDistanceBetweenPoints() {
        let a = Keypoint(x: 0, y: 0, confidence: 1)
        let b = Keypoint(x: 3, y: 4, confidence: 1)
        XCTAssertEqual(PoseGeometry.distance(from: a, to: b) ?? 0, 5.0, accuracy: 1e-9)
    }

    func testMidpointAveragesPositions() {
        let a = Keypoint(x: 0, y: 0, confidence: 0.9)
        let b = Keypoint(x: 1, y: 1, confidence: 0.5)
        let mid = PoseGeometry.midpoint(a, b)
        XCTAssertEqual(mid?.x ?? 0, 0.5, accuracy: 1e-9)
        XCTAssertEqual(mid?.y ?? 0, 0.5, accuracy: 1e-9)
        XCTAssertEqual(mid?.confidence ?? 0, 0.5, accuracy: 1e-9)  // min of inputs
    }

    func testVerticalOffset() {
        let a = Keypoint(x: 0, y: 0.2, confidence: 1)
        let b = Keypoint(x: 0, y: 0.5, confidence: 1)
        let offset = PoseGeometry.verticalOffset(a, relativeTo: b)
        XCTAssertEqual(offset ?? 0, 0.3, accuracy: 1e-9) // b is below a, so positive
    }
}
