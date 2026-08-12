import SwiftData
import SwiftUI

/// Preferences, plus the usual "about" odds and ends.
///
/// Every row here reads and writes `AppSettings`, which persists to
/// `UserDefaults` — so there is nothing to save and nothing to reload.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var context

    @State private var showingPaywall = false
    @State private var confirmingReset = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Appearance") {
                Picker("Theme", selection: $settings.appearance) {
                    ForEach(AppSettings.Appearance.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
            }

            Section {
                Toggle("Haptics", isOn: $settings.hapticsEnabled)
            } footer: {
                Text("Small vibrations when something is added, deleted or confirmed.")
            }

            if AppFeatures.purchases {
                Section("Pro") {
                    if store.hasPro {
                        Label("Pro unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Unlock Pro") { showingPaywall = true }
                    }

                    Button("Restore purchases") {
                        Task { await store.restore() }
                    }
                }
            }

            Section("Help") {
                Button("Show the walkthrough again") {
                    settings.hasCompletedOnboarding = false
                }
            }

            Section {
                LabeledContent("Version", value: Bundle.main.versionString)
            }

            Section {
                Button("Reset all settings", role: .destructive) {
                    confirmingReset = true
                }
            } footer: {
                Text("Restores appearance, haptics and the walkthrough to their defaults. Your items are not touched.")
            }

            #if DEBUG
            // Debug-only so it can never ship. Handy while building screens
            // that need something on them.
            Section("Debug") {
                Button("Add sample items") {
                    for item in Item.samples { context.insert(item) }
                }
            }
            #endif
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .confirmationDialog(
            "Reset all settings?",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                settings.reset()
                Haptics.notify(.success)
            }
        }
    }
}

extension Bundle {
    /// "1.2 (34)" — marketing version and build number, as shown in Settings.
    var versionString: String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AppSettings.preview)
        .environment(StoreManager())
        .modelContainer(PreviewData.container)
}
