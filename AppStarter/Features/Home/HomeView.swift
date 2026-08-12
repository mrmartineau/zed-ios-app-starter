import SwiftData
import SwiftUI

/// The first tab — a header, a live count read from SwiftData, and whatever
/// cards the app wants to surface.
///
/// Kept deliberately thin: this is the screen most likely to be replaced
/// wholesale, so nothing else depends on it.
struct HomeView: View {
    /// A `@Query` re-runs whenever the store changes, so the count below stays
    /// live without any manual refresh.
    @Query private var items: [Item]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header

                NavigationLink {
                    ItemListView()
                } label: {
                    StatCard(
                        title: "Items",
                        value: "\(items.count)",
                        caption: items.isEmpty ? "Nothing saved yet" : "Tap to browse"
                    )
                }
                .buttonStyle(.plain)

                if AppFeatures.ai {
                    NavigationLink {
                        AIChatView()
                    } label: {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Label("Assistant", systemImage: "sparkles")
                                .font(.headline)
                            Text("Ask a question and stream the answer back.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Start here")
                        .font(.headline)
                    Text("""
                        Replace this screen with whatever the app is actually \
                        about. The Items tab shows the SwiftData list/detail \
                        pattern, and Settings shows preferences backed by \
                        UserDefaults.
                        """)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .card()
            }
            .padding(Theme.Spacing.md)
        }
        .navigationTitle("Home")
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Welcome")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("A starting point, not a finished app.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(Theme.brandGradient)
        )
    }
}

/// A single headline number with a caption.
private struct StatCard: View {
    var title: String
    var value: String
    var caption: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.headline)
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(value)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.accent)
        }
        .card()
        // One label rather than three fragments, so VoiceOver reads it as a
        // single meaningful unit.
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environment(AppSettings.preview)
        .environment(StoreManager())
        .modelContainer(PreviewData.container)
}
