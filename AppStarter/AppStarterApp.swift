import SwiftData
import SwiftUI

@main
struct AppStarterApp: App {
    /// Settings are created once here and injected, so any view can read them
    /// with `@Environment(AppSettings.self)` instead of threading them through.
    @State private var settings = AppSettings()

    /// The store is created even when purchases are off — it does nothing until
    /// `start()` is called, and this keeps `PaywallView` compiling either way.
    @State private var store = StoreManager()

    @State private var showSplash = true

    /// The SwiftData stack. One line per `@Model` type in the schema.
    ///
    /// A failure here means the on-disk store is unreadable — usually a model
    /// change without a migration during development. Crashing is the right
    /// call: silently starting with an empty in-memory store hides the bug.
    private let container: ModelContainer = {
        do {
            return try ModelContainer(for: Item.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .environment(settings)
            .environment(store)
            .preferredColorScheme(settings.appearance.colorScheme)
            .task {
                Haptics.isEnabled = settings.hapticsEnabled

                if AppFeatures.purchases {
                    await store.start()
                }

                // Long enough to register as branding, short enough not to be
                // in the way. The launch screen uses the same background colour,
                // so the hand-off is invisible.
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
            // Keep the haptics switch in step with the preference. `Haptics` is
            // a plain enum with no environment of its own, so it can't observe
            // `AppSettings` directly.
            .onChange(of: settings.hapticsEnabled) { _, enabled in
                Haptics.isEnabled = enabled
            }
        }
        .modelContainer(container)
    }
}
