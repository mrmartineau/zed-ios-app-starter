import SwiftUI

/// The app shell: three tabs, each owning its own `NavigationStack` so pushes
/// stay inside their tab and the back stacks survive tab switches.
///
/// To add a tab: add a case to `Screen`, then a matching `Tab` entry below.
/// Nothing else needs to change. (The enum is `Screen`, not `Tab`, because
/// `Tab` is SwiftUI's own type — shadowing it breaks the `TabView` builder.)
struct RootView: View {
    enum Screen: Hashable {
        case home, items, settings
    }

    @State private var selection: Screen = .home
    @Environment(AppSettings.self) private var settings

    var body: some View {
        // `@Bindable` is what lets a view write back to an `@Observable` object
        // it got from the environment — here so `OnboardingView` can flip
        // `hasCompletedOnboarding` when it finishes.
        @Bindable var settings = settings

        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: Screen.home) {
                NavigationStack { HomeView() }
            }

            Tab("Items", systemImage: "list.bullet", value: Screen.items) {
                NavigationStack { ItemListView() }
            }

            Tab("Settings", systemImage: "gearshape", value: Screen.settings) {
                NavigationStack { SettingsView() }
            }
        }
        .sheet(isPresented: .constant(!settings.hasCompletedOnboarding)) {
            OnboardingView()
                // Not dismissible by swipe: the walkthrough has its own Skip
                // button, and a half-finished swipe would leave the flag unset
                // and re-present it on the next launch.
                .interactiveDismissDisabled()
        }
    }
}

#Preview {
    RootView()
        .environment(AppSettings.preview)
        .environment(StoreManager())
        .modelContainer(PreviewData.container)
}
