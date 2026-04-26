import Foundation

/// A 2D vector with origin at (0, 0). Used for joint-to-joint segments.
public struct Vector2D: Equatable, Hashable, Codable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(from a: Keypoint, to b: Keypoint) {
        self.x = b.x - a.x
        self.y = b.y - a.y
    }

    public var magnitude: Double { (x * x + y * y).squareRoot() }

    public func dot(_ other: Vector2D) -> Double { x * other.x + y * other.y }

    /// Cross product in 2D returns a scalar (the z-component of the 3D cross).
    public func cross(_ other: Vector2D) -> Double { x * other.y - y * other.x }
}
