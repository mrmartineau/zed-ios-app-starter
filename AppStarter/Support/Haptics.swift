#if canImport(UIKit)
import UIKit

/// Thin wrapper over `UIFeedbackGenerator`, gated on the user's haptics
/// preference so there is one switch rather than a check at every call site.
///
/// Haptics are feedback, never information: everything they mark should also be
/// visible on screen.
@MainActor
enum Haptics {
    /// Mirrors `AppSettings.hapticsEnabled`; kept in sync by the app entry point.
    static var isEnabled = true

    /// A tap — a selection changed, a toggle moved.
    static func tap() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// A knock — something committed, like adding or deleting.
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// An outcome — success, warning or error.
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
#endif
