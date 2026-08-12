import SwiftUI

/// Branded splash shown briefly on launch, over the same colour the launch
/// screen uses — so the system launch image blends straight into this and there
/// is no white flash on the way in.
///
/// Replace `AppMark` with your own icon artwork; keep `LaunchBackground` in the
/// asset catalog in step with whatever this view's background is.
struct SplashView: View {
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                AppMark(shown: shown)
                    .frame(width: 120, height: 120)

                Text("App Starter")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
        .onAppear {
            // Pure decoration, so under Reduce Motion the mark is simply
            // already in place rather than scaling up.
            withMotion(.spring(duration: 0.6, bounce: 0.3), reduceMotion: reduceMotion) {
                shown = true
            }
        }
    }
}

/// Placeholder app mark — a rounded square with a glyph. Swap for real artwork.
private struct AppMark: View {
    var shown: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
            .fill(Theme.brandGradient)
            .overlay(
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .scaleEffect(shown ? 1 : 0.7)
            .opacity(shown ? 1 : 0)
            .accessibilityHidden(true)
    }
}

#Preview {
    SplashView()
}
