import SwiftUI

/// The "App icon" rows in Settings: a swatch per icon, tap to switch.
///
/// Its own file rather than another `Section` inside `SettingsView`, because it
/// is the only part of that screen holding state of its own — what iOS is
/// currently showing, and what to say when iOS refuses to change it.
///
/// The icon is a Pro thing, so the swatches stay visible but inert without it.
/// A locked control you can see is what tells you there is something to unlock;
/// a hidden one just isn't there.
struct AppIconSection: View {
    @Environment(StoreManager.self) private var store

    /// Owned by `SettingsView`, which is where the paywall sheet is presented
    /// from — one sheet for both the Pro row and this one.
    @Binding var showingPaywall: Bool

    @State private var selection = AppIconOption.default
    @State private var isSupported = true
    @State private var failure: String?

    /// With purchases switched off there is nothing to buy, so nothing to lock.
    private var isUnlocked: Bool { !AppFeatures.purchases || store.hasPro }

    var body: some View {
        if isSupported {
            Section {
                // A grid rather than a row: four swatches and their labels are
                // wider than a form row on any phone. The minimum is high
                // enough to land on two columns on a phone — four in a tidy
                // square rather than three and an orphan — and lets iPad and
                // landscape use the room they have.
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 104), spacing: Theme.Spacing.md, alignment: .top)],
                    alignment: .leading,
                    spacing: Theme.Spacing.md
                ) {
                    ForEach(AppIconOption.allCases) { option in
                        swatch(option)
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)

                if !isUnlocked {
                    Button("Unlock Pro") { showingPaywall = true }
                }
            } header: {
                Text("App icon")
            } footer: {
                if let failure {
                    Text(failure).foregroundStyle(.red)
                } else if isUnlocked {
                    Text("Changes the icon on your home screen. iOS asks you to confirm the swap.")
                } else {
                    Text("The default is everyone's. Pro picks from all four.")
                }
            }
            .task {
                isSupported = AppIconOption.isSupported
                selection = AppIconOption.current
            }
        }
    }

    /// The selected ring, drawn a few points outside the artwork.
    ///
    /// Concentric corners: the outer radius is the inner one *plus* the gap, or
    /// the ring's corners read as tighter than the thing they surround and the
    /// gap pools at the four corners.
    ///
    /// The artwork is square and clipped here rather than pre-rounded, so the
    /// inner radius is ours to pick: iOS's squircle is about 22.4% of the
    /// width, which is 14.3pt at this size.
    private enum Ring {
        static let swatch: CGFloat = 64
        static let gap: CGFloat = 4
        static let width: CGFloat = 3
        static let artwork = swatch * 0.2237
        static let radius = artwork + gap
    }

    private func swatch(_ option: AppIconOption) -> some View {
        Button {
            choose(option)
        } label: {
            VStack(spacing: Theme.Spacing.sm) {
                Image(option.previewImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Ring.swatch, height: Ring.swatch)
                    .clipShape(
                        RoundedRectangle(cornerRadius: Ring.artwork, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Ring.radius, style: .continuous)
                            .strokeBorder(
                                selection == option ? Theme.accent : .clear,
                                lineWidth: Ring.width
                            )
                            .padding(-Ring.gap)
                    }
                    .opacity(isUnlocked ? 1 : 0.5)

                Text(option.label)
                    .font(.footnote)
                    .foregroundStyle(selection == option ? Theme.accent : .primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(selection == option ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isUnlocked ? "" : "Needs Pro")
    }

    private func choose(_ option: AppIconOption) {
        guard isUnlocked else {
            showingPaywall = true
            return
        }
        guard option != selection else { return }

        // Moved before the await so the tick lands with the tap rather than
        // after the system alert; put back below if iOS says no.
        let previous = selection
        selection = option
        Haptics.tap()

        Task {
            do {
                try await AppIconOption.apply(option)
                failure = nil
            } catch {
                selection = previous
                failure = "iOS wouldn't change the icon just now. Try again in a moment."
            }
        }
    }
}

#Preview {
    @Previewable @State var showingPaywall = false

    return NavigationStack {
        Form {
            AppIconSection(showingPaywall: $showingPaywall)
        }
    }
    .environment(StoreManager())
}
