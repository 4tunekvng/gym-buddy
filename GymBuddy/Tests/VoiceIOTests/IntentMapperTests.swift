import XCTest
@testable import CoachingEngine
@testable import VoiceIO

final class IntentMapperTests: XCTestCase {

    func testRepCountMapsToRepCountPhrase() async throws {
        let player = MockVoicePlayer()
        let phrase = PhraseID(kind: .repCount, tone: .standard, number: 3)
        let cache = PhraseCache(variants: [phrase: [PhraseCache.Variant(index: 0, assetName: "r3-0")]])
        let mapper = IntentToVoiceMapper(tone: .standard, cache: cache, voice: player)
        let played = try await mapper.route(.sayRepCount(number: 3, timestamp: 1.0))
        XCTAssertEqual(played?.number, 3)
        let hist = await player.cachedHistory()
        XCTAssertEqual(hist.count, 1)
    }

    func testEncouragementMapsToCorrectKind() async throws {
        let player = MockVoicePlayer()
        let oneMore = PhraseID(kind: .encourageOneMore, tone: .standard)
        let cache = PhraseCache(variants: [oneMore: [PhraseCache.Variant(index: 0, assetName: "om")]])
        let mapper = IntentToVoiceMapper(tone: .standard, cache: cache, voice: player)
        _ = try await mapper.route(.encouragement(kind: .oneMore, timing: .bottomOfRep, timestamp: 5.0))
        let hist = await player.cachedHistory()
        XCTAssertEqual(hist.count, 1)
        XCTAssertEqual(hist.first?.kind, .encourageOneMore)
    }

    func testFormCueMapperStaysSilentInMVP() async throws {
        let player = MockVoicePlayer()
        let cache = PhraseCache(variants: [:])
        let mapper = IntentToVoiceMapper(tone: .standard, cache: cache, voice: player)
        let cue = CueEvent(
            exerciseId: .pushUp, cueType: .hipSag, severity: .safety,
            repNumber: 1, timestamp: 0, observationCode: "x"
        )
        let played = try await mapper.route(.formCue(cue))
        XCTAssertNil(played)
        let hist = await player.cachedHistory()
        XCTAssertTrue(hist.isEmpty)
    }

    func testPainStopPlaysSafeResponse() async throws {
        let player = MockVoicePlayer()
        let phrase = PhraseID(kind: .safetyPainStop, tone: .standard)
        let cache = PhraseCache(variants: [phrase: [PhraseCache.Variant(index: 0, assetName: "pain")]])
        let mapper = IntentToVoiceMapper(tone: .standard, cache: cache, voice: player)
        let played = try await mapper.route(.painStop(trigger: "sharp pain"))
        XCTAssertEqual(played?.kind, .safetyPainStop)
    }
}
