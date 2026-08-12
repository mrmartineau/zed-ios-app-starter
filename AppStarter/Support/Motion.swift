import SwiftUI

/// Animation helpers that stand down when Reduce Motion is on.
///
/// Apple's guidance is to replace movement with a cross-fade rather than to
/// remove all change, so plain opacity transitions can be left alone. Route
/// anything that *moves*, *scales* or *rotates* through here instead of calling
/// `withAnimation` directly — the state change still lands, it just lands
/// instantly for people who asked for that.
extension View {
    /// `animation(_:value:)`, skipped entirely under Reduce Motion.
    func motion<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(ReduceMotionAnimation(animation: animation, value: value))
    }
}

private struct ReduceMotionAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var animation: Animation?
    var value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

/// `withAnimation`, skipped when `reduceMotion` is on.
///
/// The flag is passed in rather than read here: this is a free function, so it
/// has no environment of its own. Call sites already hold
/// `\.accessibilityReduceMotion`.
@MainActor
func withMotion<Result>(
    _ animation: Animation,
    reduceMotion: Bool,
    _ body: () throws -> Result
) rethrows -> Result {
    try reduceMotion ? body() : withAnimation(animation, body)
}
