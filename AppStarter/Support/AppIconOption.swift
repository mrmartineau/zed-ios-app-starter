import SwiftUI
import UIKit

/// The app icons someone can choose between, and the one place that knows how
/// to swap them.
///
/// Each icon is an app icon set in `Assets.xcassets`.
/// `ASSETCATALOG_COMPILER_APPICON_NAME` names the default and
/// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` lists the rest;
/// `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS` is what actually gets the
/// alternates into the bundle. Those settings and `assetName` below are the
/// same strings, and if one is renamed they all have to move together.
///
/// The swatches shown in Settings are separate images in `Assets.xcassets`.
/// They have to be: the compiled app icon is not addressable as a `UIImage`, so
/// a picker that tried to show the real icons would render nothing at all.
/// Declaration order is the order Settings shows them in.
///
/// The four that ship are placeholder colourways of the same mark — the point
/// is the mechanism, not the artwork. Adding or replacing one is this list, an
/// `.appiconset`, a preview `.imageset`, and the name in the build setting;
/// nothing else. Artwork is full-bleed and square, with no alpha channel and no
/// rounded corners baked in: iOS applies its own mask, App Store Connect
/// rejects an icon with alpha, and the swatch below clips to the same shape.
enum AppIconOption: String, CaseIterable, Identifiable {
    case `default`
    case midnight
    case sand
    case mono

    var id: String { rawValue }

    /// The word under the swatch in Settings.
    var label: String { rawValue.capitalized }

    /// The app icon set in `Assets.xcassets`, and what the build settings call
    /// it. The default keeps Xcode's conventional `AppIcon` name; the rest are
    /// derived, so a new case needs no entry here.
    var assetName: String {
        self == .default ? "AppIcon" : "AppIcon" + label
    }

    /// The name of the swatch in `Assets.xcassets`.
    var previewImageName: String { "AppIconPreview" + label }

    /// What UIKit calls this icon. `nil` is not "none": it is how
    /// `setAlternateIconName` says *the primary icon*, so the default case
    /// deliberately has no name of its own.
    var alternateIconName: String? { self == .default ? nil : assetName }

    /// The icon iOS is showing right now.
    ///
    /// Read from `UIApplication` rather than a stored preference. iOS owns this
    /// state — it survives reinstalls of the app's defaults and can be reset
    /// out from under us — so a mirrored `@AppStorage` flag would eventually
    /// show a tick next to an icon that isn't on the home screen.
    @MainActor
    static var current: AppIconOption {
        guard let name = UIApplication.shared.alternateIconName else { return .default }
        return allCases.first { $0.alternateIconName == name } ?? .default
    }

    /// Whether the device will let the icon change at all. False on some
    /// managed devices, and in a few extensions.
    @MainActor
    static var isSupported: Bool { UIApplication.shared.supportsAlternateIcons }

    /// Switches the home screen icon.
    ///
    /// Setting the name iOS already holds throws, so asking for the icon that
    /// is already on is a no-op rather than an error. Changing it does show a
    /// system alert — that's iOS's, not ours, and there is no way to suppress
    /// it.
    @MainActor
    static func apply(_ option: AppIconOption) async throws {
        guard isSupported, current != option else { return }
        try await UIApplication.shared.setAlternateIconName(option.alternateIconName)
    }
}
