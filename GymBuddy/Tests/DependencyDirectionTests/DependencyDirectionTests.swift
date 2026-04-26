import XCTest

/// Validates the architectural contract: `CoachingEngine` never imports
/// platform frameworks or vendor SDKs.
///
/// This test reads the source files on disk and greps for forbidden imports.
/// It's a belt-and-suspenders check on top of the `Package.swift` dependency
/// declarations — since SwiftPM enforces module boundaries already, this test
/// primarily catches *textual* drift (someone typing `import Vision` by mistake
/// in the CoachingEngine tree even if the module build would fail later).
final class DependencyDirectionTests: XCTestCase {

    func testCoachingEngineHasNoForbiddenImports() throws {
        let forbidden = [
            "UIKit", "SwiftUI", "Vision", "CoreML",
            "AVFoundation", "HealthKit", "Speech",
            "URLSession",  // heuristic — no network from the domain
            "SwiftData"
        ]
        let sources = try walk(directory: "Sources/CoachingEngine")
        var violations: [String] = []
        for file in sources {
            guard let text = try? String(contentsOfFile: file) else { continue }
            let lines = text.split(separator: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.hasPrefix("import ") { continue }
                let module = trimmed.split(separator: " ").dropFirst().first.map(String.init) ?? ""
                if forbidden.contains(module) {
                    violations.append("\(file): \(trimmed)")
                }
            }
        }
        XCTAssertTrue(violations.isEmpty, "CoachingEngine must not import: \(violations.joined(separator: "; "))")
    }

    // MARK: - Helpers

    private func walk(directory: String) throws -> [String] {
        // Resolve relative to the package root (SwiftPM sets the cwd to the
        // package directory during test runs).
        let fm = FileManager.default
        let base = fm.currentDirectoryPath
        let root = base + "/" + directory
        guard let enumerator = fm.enumerator(atPath: root) else { return [] }
        var out: [String] = []
        while let path = enumerator.nextObject() as? String {
            if path.hasSuffix(".swift") {
                out.append(root + "/" + path)
            }
        }
        return out
    }
}
