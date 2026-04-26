import SwiftUI
import CoachingEngine
import Persistence
import DesignSystem

#if os(iOS)

struct SettingsView: View {
    @EnvironmentObject var composition: AppComposition
    let onBack: () -> Void

    @State private var tone: CoachingTone = .standard
    @State private var shareDiagnostics: Bool = false
    @State private var hasLoaded: Bool = false

    var body: some View {
        VStack(spacing: DS.Space.m) {
            HStack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                }
                .accessibilityIdentifier("settings_back")
                Spacer()
            }
            .padding(DS.Space.m)
            Text("Settings")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.textPrimary)

            Form {
                Section("Coaching") {
                    Picker("Tone", selection: $tone) {
                        ForEach(CoachingTone.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .accessibilityIdentifier("settings_tone_picker")
                }
                Section("Privacy") {
                    Toggle("Share diagnostics with developer", isOn: $shareDiagnostics)
                        .accessibilityIdentifier("settings_diagnostics_toggle")
                    Text("Currently stored on this device only. Future versions may offer optional cloud-side sharing — you'll be asked again before any change.")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                Section("About") {
                    Label("Version 1.0 (MVP)", systemImage: "info.circle")
                }
            }
        }
        .task { await load() }
        .onChange(of: tone) { _, newTone in
            // Skip the initial synchronization from load() — otherwise load itself
            // would trigger a save round-trip and bump updatedAt for no reason.
            guard hasLoaded else { return }
            Task { await saveTone(newTone) }
        }
    }

    private func load() async {
        let profile = try? await composition.userProfileRepo.load()
        await MainActor.run {
            tone = profile?.tone ?? .standard
            hasLoaded = true
        }
    }

    private func saveTone(_ newTone: CoachingTone) async {
        guard var profile = try? await composition.userProfileRepo.load() else { return }
        profile.tone = newTone
        profile.updatedAt = Date()
        try? await composition.userProfileRepo.save(profile)
    }
}

#endif
