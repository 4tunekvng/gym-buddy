import XCTest
@testable import Telemetry

final class TelemetryLogTests: XCTestCase {

    func testInMemoryLogRecordsAndSnapshot() async {
        let log = InMemoryTelemetryLog()
        await log.log(TelemetryEvent(kind: .sessionStarted(exerciseId: "push_up", setNumber: 1, plannedReps: 10)))
        let snap = await log.snapshot()
        XCTAssertEqual(snap.count, 1)
    }

    func testClearEmptiesLog() async {
        let log = InMemoryTelemetryLog()
        await log.log(TelemetryEvent(kind: .appLaunched(coldStart: true, launchToFirstPaint_ms: 500)))
        await log.clear()
        let snap = await log.snapshot()
        XCTAssertTrue(snap.isEmpty)
    }

    func testPruneByCountDropsOldest() async {
        let log = InMemoryTelemetryLog(maxEvents: 5)
        for i in 0..<10 {
            await log.log(TelemetryEvent(kind: .repDetected(exerciseId: "push_up", repNumber: i, concentric_ms: 800, eccentric_ms: 600, romScore: 0.9)))
        }
        let snap = await log.snapshot()
        XCTAssertEqual(snap.count, 5)
    }

    func testNoOpLogNeverStores() async {
        let log = NoOpTelemetryLog()
        await log.log(TelemetryEvent(kind: .appLaunched(coldStart: true, launchToFirstPaint_ms: 0)))
        let snap = await log.snapshot()
        XCTAssertTrue(snap.isEmpty)
    }

    func testEventRoundTripsThroughCodable() throws {
        let event = TelemetryEvent(kind: .cueFired(exerciseId: "push_up", cueType: "hip_sag", severity: 2, latency_ms: 350))
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(TelemetryEvent.self, from: data)
        XCTAssertEqual(event, decoded)
    }
}
