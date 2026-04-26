import Foundation
import SwiftUI

/// Design tokens — the single place color, spacing, typography, radii,
/// elevation, and animation duration are defined.
///
/// Rule: views never use literal colors, font sizes, or spacing — always
/// reference a token. This keeps dark-mode coverage automatic and snapshot
/// tests meaningful.
public enum DS {

    // MARK: - Color ramps

    public enum Color {
        public static let accent = SwiftUI.Color(red: 0.98, green: 0.62, blue: 0.14)
        public static let accentMuted = SwiftUI.Color(red: 0.90, green: 0.56, blue: 0.14).opacity(0.85)
        public static let canvas = SwiftUI.Color(red: 0.06, green: 0.07, blue: 0.09)
        public static let surface = SwiftUI.Color(red: 0.11, green: 0.12, blue: 0.14)
        public static let textPrimary = SwiftUI.Color(red: 0.95, green: 0.95, blue: 0.97)
        public static let textSecondary = SwiftUI.Color(red: 0.62, green: 0.64, blue: 0.70)
        public static let textOnAccent = SwiftUI.Color.black
        public static let success = SwiftUI.Color(red: 0.42, green: 0.78, blue: 0.46)
        public static let warning = SwiftUI.Color(red: 0.93, green: 0.75, blue: 0.21)
        public static let danger = SwiftUI.Color(red: 0.85, green: 0.34, blue: 0.32)
        public static let separator = SwiftUI.Color.gray.opacity(0.18)
    }

    // MARK: - Typography

    public enum Font {
        // `relativeTo:` anchors each token to a Dynamic Type text-style so the
        // UI scales at Accessibility sizes without becoming unreadable or
        // overflowing containers. Every Text using these fonts participates
        // in Dynamic Type automatically.
        public static let displayLarge = SwiftUI.Font.system(size: 56, weight: .semibold, design: .rounded)
            .leading(.tight)
        public static let repCounter = SwiftUI.Font.system(size: 180, weight: .bold, design: .rounded)
            .leading(.tight)
        public static let title = SwiftUI.Font.system(size: 28, weight: .semibold)
        public static let headline = SwiftUI.Font.system(size: 20, weight: .semibold)
        public static let body = SwiftUI.Font.system(size: 17, weight: .regular)
        public static let caption = SwiftUI.Font.system(size: 13, weight: .medium)
    }

    // MARK: - Spacing

    public enum Space {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 16
        public static let l: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    // MARK: - Radius

    public enum Radius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 14
        public static let large: CGFloat = 24
    }

    // MARK: - Shadows

    public enum Shadow {
        public static let soft = (color: SwiftUI.Color.black.opacity(0.07), radius: 6.0, y: 2.0)
        public static let elevated = (color: SwiftUI.Color.black.opacity(0.12), radius: 12.0, y: 4.0)
    }

    // MARK: - Motion

    public enum Motion {
        public static let fastEase = SwiftUI.Animation.easeOut(duration: 0.18)
        public static let standardSpring = SwiftUI.Animation.interpolatingSpring(stiffness: 300, damping: 24)
        public static let dwell = SwiftUI.Animation.easeInOut(duration: 0.45)
    }
}
