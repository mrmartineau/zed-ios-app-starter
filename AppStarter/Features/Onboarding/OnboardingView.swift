import SwiftUI

/// First-launch walkthrough, replayable from Settings.
///
/// The pages are data rather than hand-written views, so adding a step is one
/// entry in `Page.all`. `hasCompletedOnboarding` is the only thing that decides
/// whether this sheet appears — Settings replays it by setting that back to
/// `false`.
struct OnboardingView: View {
    struct Page: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let body: String

        static let all: [Page] = [
            Page(
                symbol: "hand.wave",
                title: "Welcome",
                body: "A short walkthrough runs the first time the app opens. Replace these pages with the ones your app needs."
            ),
            Page(
                symbol: "list.bullet.rectangle",
                title: "Keep track",
                body: "The Items tab stores things on device with SwiftData. Swipe to delete, tap to edit."
            ),
            Page(
                symbol: "gearshape",
                title: "Make it yours",
                body: "Settings has appearance, haptics, and a way to replay this walkthrough whenever you like."
            ),
        ]
    }

    @Environment(AppSettings.self) private var settings
    @State private var index = 0

    private var isLastPage: Bool { index == Page.all.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $index) {
                ForEach(Array(Page.all.enumerated()), id: \.element.id) { position, page in
                    PageView(page: page)
                        .tag(position)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: Theme.Spacing.sm) {
                Button(isLastPage ? "Get started" : "Next") {
                    if isLastPage {
                        finish()
                    } else {
                        // The page indicator moving is meaningful, not
                        // decorative, so this one animates regardless.
                        withAnimation { index += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Button("Skip", action: finish)
                    .opacity(isLastPage ? 0 : 1)
                    // Kept in the layout when hidden so the button above
                    // doesn't jump on the last page.
                    .disabled(isLastPage)
                    .accessibilityHidden(isLastPage)
            }
            .padding(Theme.Spacing.md)
        }
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
        Haptics.notify(.success)
    }
}

private struct PageView: View {
    let page: OnboardingView.Page

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: page.symbol)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.sm) {
                Text(page.title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

#Preview {
    OnboardingView()
        .environment(AppSettings.preview)
}
