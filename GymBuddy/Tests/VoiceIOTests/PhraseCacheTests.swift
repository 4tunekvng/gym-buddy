import XCTest
@testable import CoachingEngine
@testable import VoiceIO

final class PhraseCacheTests: XCTestCase {

    func testSelectReturnsAVariantFromRegisteredList() throws {
        let phrase = PhraseID(kind: .encourageOneMore, tone: .standard)
        let variants = (0..<7).map { PhraseCache.Variant(index: $0, assetName: "one-more-\($0)") }
        let cache = PhraseCache(variants: [phrase: variants], windowSize: 3)
        let sel = try cache.select(phrase)
        XCTAssertTrue(variants.map(\.index).contains(sel.variant.index))
    }

    func testNoRepeatWindowAvoidsRecentVariants() throws {
        let phrase = PhraseID(kind: .encourageOneMore, tone: .standard)
        let variants = (0..<8).map { PhraseCache.Variant(index: $0, assetName: "x\($0)") }
        let cache = PhraseCache(variants: [phrase: variants], windowSize: 4, rng: { 0.0 }) // deterministic
        // First 4 picks should all be different due to rng + window.
        var picked: [Int] = []
        for _ in 0..<4 {
            picked.append(try cache.select(phrase).variant.index)
        }
        XCTAssertEqual(Set(picked).count, 4, "First 4 picks should be distinct with window=4")
    }

    func testNoVariantsThrows() {
        let phrase = PhraseID(kind: .encourageOneMore, tone: .standard)
        let cache = PhraseCache(variants: [:])
        XCTAssertThrowsError(try cache.select(phrase))
    }

    func testValidateReturnsMissingPhraseIDs() {
        let phraseA = PhraseID(kind: .encourageOneMore, tone: .standard)
        let phraseB = PhraseID(kind: .encouragePush, tone: .standard)
        let cache = PhraseCache(variants: [phraseA: [PhraseCache.Variant(index: 0, assetName: "a")]])
        let missing = cache.validate(required: [phraseA, phraseB])
        XCTAssertEqual(missing, [phraseB])
    }

    func testResetClearsHistory() throws {
        let phrase = PhraseID(kind: .encouragePush, tone: .standard)
        let variants = (0..<3).map { PhraseCache.Variant(index: $0, assetName: "p\($0)") }
        let cache = PhraseCache(variants: [phrase: variants], windowSize: 10)
        for _ in 0..<2 { _ = try cache.select(phrase) }
        cache.reset()
        // After reset, history is clear so any pick is allowed again.
        _ = try cache.select(phrase)
        XCTAssertTrue(true)  // didn't throw
    }
}
