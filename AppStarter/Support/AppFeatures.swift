import Foundation

/// Compile-time-ish switches for the optional modules.
///
/// Both ship **off**. The code for each is present and compiles either way —
/// StoreKit and `URLSession` are system frameworks, so an unused module costs
/// nothing at runtime and there are no dependencies to install. Flip a flag to
/// `true` and its UI appears; leave it `false` and the module is inert.
///
/// If a project will never want one, delete its folder and the two or three
/// references the compiler then points at — the README lists them.
enum AppFeatures {
    /// In-app purchases. Turning this on shows the Pro row in Settings and
    /// starts the StoreKit transaction listener at launch.
    ///
    /// Before shipping: create the products in App Store Connect with the same
    /// IDs as `Store/Products.storekit`, and add the In-App Purchase capability
    /// to the target.
    static let purchases = false

    /// Claude API chat. Turning this on shows the Assistant card on Home.
    ///
    /// Read `Features/AI/AnthropicClient.swift` before shipping this — a key
    /// embedded in a shipped app is extractable, so production builds should
    /// point `AnthropicClient` at your own proxy rather than the API directly.
    static let ai = false
}
