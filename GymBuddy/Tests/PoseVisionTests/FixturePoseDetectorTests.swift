import XCTest
@testable import CoachingEngine
@testable import PoseVision

final class FixturePoseDetectorTests: XCTestCase {

    func testDetectorEmitsAllSamplesInOrder() async throws {
        let samples = (0..<10).map { i in
            PoseSample(timestamp: Double(i) * 0.033, joints: [:])
        }
        let detector = FixturePoseDetector(samples: samples, frameInterval: 0)
        var stream = detector.bodyStateStream().makeAsyncIterator()
        try await detector.start()

        var received: [BodyState] = []
        for _ in 0..<10 {
            if let next = await stream.next() { received.append(next) } else { break }
        }
        await detector.stop()
        XCTAssertEqual(received.count, 10)
        for (i, state) in received.enumerated() {
            if case .pose(let s) = state {
                XCTAssertEqual(s.timestamp, Double(i) * 0.033, accuracy: 1e-9)
            }
        }
    }

    func testSecondStartThrowsAlreadyStarted() async throws {
        let detector = FixturePoseDetector(samples: [PoseSample(timestamp: 0, joints: [:])])
        try await detector.start()
        do {
            try await detector.start()
            XCTFail("Expected alreadyStarted")
        } catch PoseDetectionError.alreadyStarted {
            // ok
        } catch {
            XCTFail("Wrong error: \(error)")
        }
        await detector.stop()
    }
}
