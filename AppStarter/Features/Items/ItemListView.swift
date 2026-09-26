import SwiftData
import SwiftUI

/// The Items tab: list and detail side by side on a wide screen, a normal
/// push on a narrow one. `NavigationSplitView` collapses to a stack by itself
/// in a compact size class, so one view serves iPhone, iPad and every window
/// size between.
struct ItemsView: View {
    @Binding var showingSettings: Bool
    @State private var selection: Item?

    var body: some View {
        NavigationSplitView {
            ItemListView(selection: $selection)
                .withChrome(showingSettings: $showingSettings)
        } detail: {
            if let selection {
                // Clearing the selection is what closes the detail, on both
                // widths — `dismiss()` does nothing in a split view's column.
                ItemDetailView(item: selection) { self.selection = nil }
            } else {
                ContentUnavailableView("No item selected", systemImage: "list.bullet")
            }
        }
    }
}

/// The list half of the list/detail pattern, backed by SwiftData.
///
/// `@Query` handles fetching, sorting and live updates — there is no view model
/// and no manual reload. Inserting or deleting through the `modelContext`
/// re-renders this list automatically.
struct ItemListView: View {
    @Binding var selection: Item?

    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @Environment(\.modelContext) private var context

    var body: some View {
        List(selection: $selection) {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    ItemRow(item: item)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Items")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add item", systemImage: "plus", action: add)
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("No items", systemImage: "tray")
                } description: {
                    Text("Items you add will appear here.")
                } actions: {
                    Button("Add an item", action: add)
                        .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private func add() {
        // No explicit save: SwiftData autosaves the context, and calling
        // `save()` by hand here would only make the write less batched.
        context.insert(Item(title: "New item"))
        Haptics.impact()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            if items[index] == selection { selection = nil }
            context.delete(items[index])
        }
        Haptics.impact(.medium)
    }
}

private struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if item.isFavourite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    // Decorative here — the label below already says it.
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.isFavourite ? "\(item.title), favourite" : item.title)
    }
}

#Preview {
    ItemsView(showingSettings: .constant(false))
        .modelContainer(PreviewData.container)
}
