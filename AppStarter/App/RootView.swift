import SwiftUI

/// The app shell: a tab bar (a sidebar on iPad), each tab owning its own
/// navigation so pushes stay inside their tab and the back stacks survive tab
/// switches. Settings is a sheet from the leading toolbar button on every tab.
///
/// To add a tab: add a case to `Screen`, then a matching `Tab` entry below with
/// `.withChrome(showingSettings: $showingSettings)` on its root view. (The enum
/// is `Screen`, not `Tab`, because `Tab` is SwiftUI's own type — shadowing it
/// breaks the `TabView` builder.)
struct RootView: View {
    enum Screen: Hashable {
        case home, items
    }

    /// `false` while the splash is up. Onboarding waits for it: a sheet asked
    /// for in the first frame is dropped.
    var isReady = true

    @State private var selection: Screen = .home
    @State private var showingSettings = false
    @State private var showingOnboarding = false
    @Environment(AppSettings.self) private var settings

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: Screen.home) {
                NavigationStack {
                    HomeView().withChrome(showingSettings: $showingSettings)
                }
            }

            Tab("Items", systemImage: "list.bullet", value: Screen.items) {
                ItemsView(showingSettings: $showingSettings)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .sheet(isPresented: $showingSettings, onDismiss: presentOnboardingIfNeeded) {
            SettingsView()
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
                // Not dismissible by swipe: the walkthrough has its own Skip
                // button, and a half-finished swipe would leave the flag unset
                // and re-present it on the next launch.
                .interactiveDismissDisabled()
        }
        .onChange(of: isReady, initial: true) { presentOnboardingIfNeeded() }
        .onChange(of: settings.hasCompletedOnboarding) { _, done in
            if done { showingOnboarding = false } else { presentOnboardingIfNeeded() }
        }
    }

    /// One sheet at a time: "Show the walkthrough again" in Settings clears the
    /// flag while Settings is still up, so the walkthrough waits for its
    /// `onDismiss` rather than being dropped.
    private func presentOnboardingIfNeeded() {
        guard isReady, !showingSettings, !settings.hasCompletedOnboarding else { return }
        showingOnboarding = true
    }
}

extension View {
    /// The toolbar every tab shares. Tab-specific buttons (Add) go on the
    /// trailing side in the tab's own view.
    func withChrome(showingSettings: Binding<Bool>) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", systemImage: "gearshape") { showingSettings.wrappedValue = true }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppSettings.preview)
        .environment(StoreManager())
        .modelContainer(PreviewData.container)
}
