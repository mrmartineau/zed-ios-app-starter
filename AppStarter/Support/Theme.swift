import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// One place for the numbers and colours the app reuses, so a redesign is an
/// edit here rather than a hunt through every view.
///
/// Colours that need to differ between light and dark belong in
/// `Assets.xcassets` as a colour set with a Dark appearance — the accent colour
/// already works that way. Semantic system colours (`.primary`, `.secondary`,
/// `.background`) adapt on their own and should be preferred where they fit.
enum Theme {
    // MARK: Spacing

    /// A 4pt scale. Sticking to these keeps vertical rhythm consistent without
    /// anyone having to remember what "a bit of padding" meant last time.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 40
    }

    // MARK: Shape

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 28
    }

    // MARK: Colour

    /// The tint, read from the asset catalog so the accent colour and the
    /// launch screen can never drift apart.
    static let accent = Color.accentColor

    /// A soft two-stop wash used behind the splash and the Home header.
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Card

extension View {
    /// Standard raised container: padding, rounded rect, hairline border.
    ///
    /// Uses `.background` rather than a hard-coded colour so it stays legible
    /// in both appearances.
    func card() -> some View {
        padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
    }
}
