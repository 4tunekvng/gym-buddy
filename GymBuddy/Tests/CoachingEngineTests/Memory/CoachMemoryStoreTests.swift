import XCTest
@testable import CoachingEngine

final class CoachMemoryStoreTests: XCTestCase {

    func testAddAndRetrieveByTag() async {
        let store = InMemoryCoachMemoryStore()
        await store.add(CoachMemoryNote(content: "left knee clicks on squats", tags: ["injury", "body-part:knee"]))
        await store.add(CoachMemoryNote(content: "loves AMRAP sets", tags: ["preference"]))
        let kneeNotes = await store.recent(matching: ["body-part:knee"], limit: 10)
        XCTAssertEqual(kneeNotes.count, 1)
        XCTAssertTrue(kneeNotes.first?.content.contains("knee") ?? false)
    }

    func testEmptyTagQueryReturnsAllOrderedByRecency() async {
        let store = InMemoryCoachMemoryStore()
        let early = CoachMemoryNote(
            content: "early", tags: ["context"],
            createdAt: Date(timeIntervalSinceReferenceDate: 100)
        )
        let late = CoachMemoryNote(
            content: "late", tags: ["context"],
            createdAt: Date(timeIntervalSinceReferenceDate: 200)
        )
        await store.add(early)
        await store.add(late)
        let all = await store.recent(matching: [], limit: 10)
        XCTAssertEqual(all.first?.content, "late")
    }

    func testLimitCapsResults() async {
        let store = InMemoryCoachMemoryStore()
        for i in 0..<20 {
            await store.add(CoachMemoryNote(content: "n\(i)", tags: ["context"]))
        }
        let limited = await store.recent(matching: ["context"], limit: 5)
        XCTAssertEqual(limited.count, 5)
    }

    func testRemoveById() async {
        let store = InMemoryCoachMemoryStore()
        let note = CoachMemoryNote(content: "x", tags: ["context"])
        await store.add(note)
        await store.remove(note.id)
        let all = await store.all()
        XCTAssertTrue(all.isEmpty)
    }
}
