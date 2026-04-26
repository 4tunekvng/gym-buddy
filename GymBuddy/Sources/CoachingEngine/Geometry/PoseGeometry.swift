import Foundation

/// Geometry helpers that operate on pose keypoints.
///
/// All helpers are pure functions with no side effects. If a required joint is
/// missing or unreliable, the helper returns nil so callers can decide how to
/// handle the gap (usually: skip this frame's cue evaluation).
public enum PoseGeometry {

    /// The angle at `vertex` formed by segments `vertex→a` and `vertex→b`, in
    /// the canonical interior-angle sense (always in [0°, 180°]).
    public static func angle(
        at vertex: Keypoint,
        between a: Keypoint,
        and b: Keypoint
    ) -> Angle? {
        guard vertex.isReliable, a.isReliable, b.isReliable else { return nil }
        let va = Vector2D(from: vertex, to: a)
        let vb = Vector2D(from: vertex, to: b)
        let magProduct = va.magnitude * vb.magnitude
        guard magProduct > 0 else { return nil }
        let cos = max(-1.0, min(1.0, va.dot(vb) / magProduct))
        return Angle(radians: acos(cos))
    }

    /// Perpendicular distance from point `p` to the infinite line through `a` and `b`.
    /// Returns nil if any input is unreliable or if `a == b`.
    public static func perpendicularDistance(
        from p: Keypoint,
        toLineThrough a: Keypoint,
        and b: Keypoint
    ) -> Double? {
        guard p.isReliable, a.isReliable, b.isReliable else { return nil }
        let ab = Vector2D(from: a, to: b)
        let ap = Vector2D(from: a, to: p)
        guard ab.magnitude > 0 else { return nil }
        return abs(ab.cross(ap)) / ab.magnitude
    }

    /// Distance between two keypoints in normalized image coords.
    public static func distance(from a: Keypoint, to b: Keypoint) -> Double? {
        guard a.isReliable, b.isReliable else { return nil }
        return Vector2D(from: a, to: b).magnitude
    }

    /// The signed vertical offset (positive = a is above b in image coords, since
    /// image y grows downward, "above" means y is smaller).
    public static func verticalOffset(_ a: Keypoint, relativeTo b: Keypoint) -> Double? {
        guard a.isReliable, b.isReliable else { return nil }
        return b.y - a.y
    }

    /// Average of two keypoint positions, confidence = min of the two.
    public static func midpoint(_ a: Keypoint, _ b: Keypoint) -> Keypoint? {
        guard a.isReliable, b.isReliable else { return nil }
        return Keypoint(
            x: (a.x + b.x) / 2,
            y: (a.y + b.y) / 2,
            confidence: min(a.confidence, b.confidence)
        )
    }
}
