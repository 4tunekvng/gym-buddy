import Foundation

/// A single body keypoint in normalized image-space coordinates.
///
/// Coordinate system: origin at top-left, x and y both in [0, 1].
/// A keypoint with confidence < `minimumConfidence` is treated as missing by
/// rep detection; cue logic that depends on missing joints no-ops rather than
/// firing based on stale or inferred data.
public struct Keypoint: Equatable, Codable, Sendable, Hashable {
    public let x: Double
    public let y: Double
    public let confidence: Double

    public init(x: Double, y: Double, confidence: Double) {
        self.x = x
        self.y = y
        self.confidence = confidence
    }

    /// Keypoints below this confidence are considered missing / unreliable.
    /// Calibrated against Apple Vision output during M2 fixture work.
    public static let minimumConfidence: Double = 0.30

    public var isReliable: Bool { confidence >= Self.minimumConfidence }
}
