import XCTest
@testable import CoachingEngine
@testable import VoiceIO

final class PhraseManifestTests: XCTestCase {

    func testManifestContainsRepCounts1Through50() {
        let manifest = PhraseManifest.required(for: .standard)
        let counts = manifest.filter { $0.kind == .repCount }.compactMap { $0.number }
        XCTAssertEqual(Set(counts), Set(1...50))
    }

    func testManifestIncludesAllBasicEncouragements() {
        let manifest = PhraseManifest.required(for: .standard)
        let kinds = Set(manifest.map(\.kind))
        for required: PhraseID.Kind in [.encourageOneMore, .encouragePush, .encourageDrive, .encourageLastOne] {
            XCTAssertTrue(kinds.contains(required))
        }
    }

    func testManifestIncludesSafetyResponses() {
        let manifest = PhraseManifest.required(for: .standard)
        let kinds = Set(manifest.map(\.kind))
        XCTAssertTrue(kinds.contains(.safetyPainStop))
        XCTAssertTrue(kinds.contains(.safetyDiagnosisDeflect))
    }

    func testMinimumVariantsRequireAtLeastOne() {
        for (kind, count) in PhraseManifest.minimumVariantsByKind {
            XCTAssertGreaterThan(count, 0, "Kind \(kind) requires at least one variant")
        }
    }
}
