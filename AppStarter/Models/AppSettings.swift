import SwiftUI

/// App-wide preferences, persisted in `UserDefaults`.
///
/// `@AppStorage` is fine for a single flag read in a single view, but it can
/// only live in a `View`, so anything a model or a plain function needs to read
/// ends up threaded through the view tree. This is the same storage with an
/// `@Observable` object in front of it: inject once in the app entry point,
/// read it anywhere with `@Environment(AppSettings.self)`.
///
/// To add a preference: add a `Key`, add a property that reads it in `init` and
/// writes it in `didSet`. That's the whole pattern.
@Observable
final class AppSettings {
    enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let appearance = "appearance"
        static let hapticsEnabled = "hapticsEnabled"
    }

    /// Light / dark / follow the system.
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var label: String {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }

        /// `nil` means "don't override", which is what `preferredColorScheme`
        /// wants for the system option.
        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    /// Set once the walkthrough has been finished or skipped. Flipping this
    /// back to `false` in Settings replays it.
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// - Parameter defaults: injectable so previews and tests can use a
    ///   throwaway suite instead of scribbling on the real app's settings.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // `bool(forKey:)` returns false for a missing key, which is the right
        // default here. `hapticsEnabled` wants to default *on*, so it is
        // registered rather than read raw.
        defaults.register(defaults: [Key.hapticsEnabled: true])

        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        hapticsEnabled = defaults.bool(forKey: Key.hapticsEnabled)
        appearance = defaults.string(forKey: Key.appearance)
            .flatMap(Appearance.init(rawValue:)) ?? .system
    }

    /// Wipes every preference this object owns — the "Reset" row in Settings.
    func reset() {
        for key in [Key.hasCompletedOnboarding, Key.appearance, Key.hapticsEnabled] {
            defaults.removeObject(forKey: key)
        }
        hasCompletedOnboarding = false
        appearance = .system
        hapticsEnabled = true
    }
}

extension AppSettings {
    /// Settings backed by a scratch suite, for previews.
    static var preview: AppSettings {
        AppSettings(defaults: UserDefaults(suiteName: "preview") ?? .standard)
    }
}
