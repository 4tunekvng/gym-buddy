import XCTest
@testable import CoachingEngine
@testable import LLMClient

final class MemoryExtractorTests: XCTestCase {

    func testParsesValidJSON() throws {
        let json = """
        [
          {"content": "left knee clicks on deep squats", "tags": ["injury", "body-part:knee"]},
          {"content": "prefers AMRAP sets", "tags": ["preference"]}
        ]
        """
        let notes = try MemoryExtractor.parse(json)
        XCTAssertEqual(notes.count, 2)
        XCTAssertTrue(notes.contains { $0.tags.contains("body-part:knee") })
    }

    func testEmptyArrayReturnsEmpty() throws {
        XCTAssertEqual(try MemoryExtractor.parse("[]"), [])
    }

    func testMalformedInputGivesEmpty() throws {
        XCTAssertEqual(try MemoryExtractor.parse("not json"), [])
    }

    func testExtractorCallsLLMWithCorrectPrompt() async throws {
        let mock = MockLLMClient()
        mock.setScript(.fixed("""
        [{"content":"wrist hurts during push-ups","tags":["injury"]}]
        """), for: PromptRegistry.memoryExtractionId)
        let extractor = MemoryExtractor(client: mock)
        let notes = try await extractor.extract(from: "My wrist hurts", source: .betweenSet)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(mock.callLog.first?.promptId, PromptRegistry.memoryExtractionId)
    }
}
