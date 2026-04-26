import SwiftUI
import DesignSystem

#if os(iOS)

/// First thing a new user sees. Warm, simple, one CTA.
struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: DS.Space.xl) {
            Spacer()
            VStack(spacing: DS.Space.m) {
                Text("Gym Buddy")
                    .font(DS.Font.displayLarge)
                    .foregroundStyle(DS.Color.textPrimary)
                Text("A coach that watches, remembers, and pushes.")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Space.l)
            }
            Spacer()
            VStack(spacing: DS.Space.m) {
                PrimaryButton(title: "Get started", action: onStart)
                    .accessibilityIdentifier("welcome_start_button")
                Text("Takes 5 minutes. Your camera stays on this phone.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .padding(.horizontal, DS.Space.l)
            .padding(.bottom, DS.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#endif
