import SwiftUI

/// The four-check setup overlay. Session cannot start until all four are green.
public struct SetupOverlay: View {
    public struct Check: Identifiable, Equatable {
        public enum Kind: String, CaseIterable {
            case angle, distance, lighting, fullBody
            public var title: String {
                switch self {
                case .angle: "Camera angle"
                case .distance: "Distance"
                case .lighting: "Lighting"
                case .fullBody: "Full body in frame"
                }
            }
            public var helperText: String {
                switch self {
                case .angle: "Prop the phone so the lens is level with your body."
                case .distance: "Step back until feet and head are both in frame."
                case .lighting: "Move to a brighter spot — we need to see you clearly."
                case .fullBody: "Make sure head and ankles are both visible."
                }
            }
        }
        public let id: Kind
        public let passing: Bool
        public init(id: Kind, passing: Bool) {
            self.id = id
            self.passing = passing
        }
    }

    public let checks: [Check]
    public let onConfirm: () -> Void

    public init(checks: [Check], onConfirm: @escaping () -> Void) {
        self.checks = checks
        self.onConfirm = onConfirm
    }

    public var allPassing: Bool { checks.allSatisfy(\.passing) && checks.count == 4 }

    public var body: some View {
        VStack(spacing: DS.Space.l) {
            Text("Let's get you in frame")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.textPrimary)
            VStack(spacing: DS.Space.m) {
                ForEach(checks) { check in
                    HStack(spacing: DS.Space.m) {
                        Image(systemName: check.passing ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(check.passing ? DS.Color.success : DS.Color.textSecondary)
                            .font(DS.Font.headline)
                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            Text(check.id.title).font(DS.Font.headline)
                            if !check.passing {
                                Text(check.id.helperText)
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Color.textSecondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(DS.Space.l)
            .background(DS.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large))

            PrimaryButton(title: allPassing ? "Start set" : "Waiting for all checks", action: onConfirm)
                .accessibilityIdentifier("setup_start_button")
                .disabled(!allPassing)
        }
        .padding(DS.Space.l)
    }
}
