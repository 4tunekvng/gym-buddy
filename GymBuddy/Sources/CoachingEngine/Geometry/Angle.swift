import Foundation

/// A unit-aware angle. Stored as radians; readable in degrees.
public struct Angle: Equatable, Hashable, Codable, Sendable, Comparable {
    public let radians: Double

    public init(radians: Double) { self.radians = radians }
    public init(degrees: Double) { self.radians = degrees * .pi / 180.0 }

    public var degrees: Double { radians * 180.0 / .pi }

    public static func < (lhs: Angle, rhs: Angle) -> Bool { lhs.radians < rhs.radians }
    public static let zero = Angle(radians: 0)
    public static let pi = Angle(radians: .pi)
}
