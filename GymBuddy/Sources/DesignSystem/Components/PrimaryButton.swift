import SwiftUI

/// The one big call-to-action button. Consistent styling across the app.
public struct PrimaryButton: View {
    public let title: String
    public let isLoading: Bool
    public let action: () -> Void

    public init(title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.s) {
                if isLoading {
                    ProgressView().tint(DS.Color.textOnAccent)
                }
                Text(title)
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.textOnAccent)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(DS.Color.accent)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous))
        }
        .accessibilityLabel(Text(title))
        .disabled(isLoading)
    }
}

public struct SecondaryButton: View {
    public let title: String
    public let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Font.headline)
                .foregroundStyle(DS.Color.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                        .stroke(DS.Color.separator, lineWidth: 1)
                )
        }
    }
}
