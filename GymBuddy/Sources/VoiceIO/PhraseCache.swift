import Foundation
import CoachingEngine

/// Manages the Tier-1 variant library (pre-generated TTS audio assets).
///
/// A `Variant` is one of several interchangeable audio files for a single
/// `PhraseID`. Selection at runtime: exclude the most-recently-played window,
/// then weighted random among the remainder (weight ∝ 1 / (1 + playCount)).
///
/// This type owns variant metadata only — actual audio loading lives in the
/// `AudioPlayback` adapter so the cache is testable without an audio engine.
public final class PhraseCache: @unchecked Sendable {

    public struct Variant: Equatable, Sendable {
        public let index: Int
        public let assetName: String        // basename of the audio asset
        public init(index: Int, assetName: String) {
            self.index = index
            self.assetName = assetName
        }
    }

    public struct Selection: Equatable, Sendable {
        public let phrase: PhraseID
        public let variant: Variant
    }

    public enum Error: Swift.Error, Equatable {
        case noVariants(PhraseID)
    }

    private var variants: [PhraseID: [Variant]]
    private var recentByPhrase: [PhraseID: [Int]] = [:]
    private var playCounts: [PhraseID: [Int: Int]] = [:]
    private let windowSize: Int
    private let rng: @Sendable () -> Double

    /// - Parameters:
    ///   - variants: phrase → ordered variant list.
    ///   - windowSize: number of most-recent variants to avoid (no-repeat window).
    ///   - rng: injection seam for tests; default is `Double.random(in:)`.
    public init(
        variants: [PhraseID: [Variant]],
        windowSize: Int = 6,
        rng: @escaping @Sendable () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.variants = variants
        self.windowSize = windowSize
        self.rng = rng
    }

    public func select(_ phrase: PhraseID) throws -> Selection {
        guard let all = variants[phrase], !all.isEmpty else {
            throw Error.noVariants(phrase)
        }
        let recent = recentByPhrase[phrase] ?? []
        let effectiveWindow = Swift.min(max(0, windowSize), Swift.max(0, all.count - 1))
        let blockedIndexes = Set(recent.suffix(effectiveWindow))
        let candidates = all.filter { !blockedIndexes.contains($0.index) }
        let pickPool = candidates.isEmpty ? all : candidates

        // Weighted random — weight = 1 / (1 + playCount).
        let counts = playCounts[phrase] ?? [:]
        let weights = pickPool.map { 1.0 / (1.0 + Double(counts[$0.index] ?? 0)) }
        let total = weights.reduce(0, +)
        let pick = rng() * total
        var acc = 0.0
        var chosen: Variant = pickPool[0]
        for (i, variant) in pickPool.enumerated() {
            acc += weights[i]
            if pick <= acc {
                chosen = variant
                break
            }
        }

        // Update history.
        var newRecent = recent
        newRecent.append(chosen.index)
        if newRecent.count > windowSize { newRecent.removeFirst(newRecent.count - windowSize) }
        recentByPhrase[phrase] = newRecent
        var newCounts = playCounts[phrase] ?? [:]
        newCounts[chosen.index, default: 0] += 1
        playCounts[phrase] = newCounts

        return Selection(phrase: phrase, variant: chosen)
    }

    public func reset() {
        recentByPhrase.removeAll()
        playCounts.removeAll()
    }

    public var phraseIds: Set<PhraseID> { Set(variants.keys) }

    /// Validate the cache against a required manifest. Returns the phrase IDs
    /// that lack variants in this cache.
    public func validate(required: [PhraseID]) -> [PhraseID] {
        required.filter { (variants[$0]?.count ?? 0) == 0 }
    }
}
