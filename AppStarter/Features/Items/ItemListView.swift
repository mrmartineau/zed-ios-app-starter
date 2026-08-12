import SwiftData
import SwiftUI

/// The list half of the list/detail pattern, backed by SwiftData.
///
/// `@Query` handles fetching, sorting and live updates — there is no view model
/// and no manual reload. Inserting or deleting through the `modelContext`
/// re-renders this list automatically.
struct ItemListView: View {
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    ItemRow(item: item)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Items")
        .navigationDestination(for: Item.self) { item in
            ItemDetailView(item: item)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add item", systemImage: "plus", action: add)
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
                        .buttonStyle(.borderedProminent)
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
    NavigationStack { ItemListView() }
        .modelContainer(PreviewData.container)
}
