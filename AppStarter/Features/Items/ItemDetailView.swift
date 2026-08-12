import SwiftData
import SwiftUI

/// The detail half of the list/detail pattern, and an editor at the same time.
///
/// A SwiftData `@Model` is a reference type that publishes its own changes, so
/// binding a `TextField` straight to `item.title` edits the stored object in
/// place and the list updates as you type. There is no separate draft, no save
/// button, and no "did the user cancel?" state to reconcile — which is why
/// there is a delete confirmation instead: deletion is the only step here that
/// can't be undone by typing.
struct ItemDetailView: View {
    @Bindable var item: Item

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $item.title)
                TextField("Note", text: $item.note, axis: .vertical)
                    .lineLimit(3...8)
                Toggle("Favourite", isOn: $item.isFavourite)
            }

            Section {
                LabeledContent("Created", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            Section {
                Button("Delete item", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .navigationTitle(item.title.isEmpty ? "Untitled" : item.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this item?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                context.delete(item)
                Haptics.notify(.success)
                dismiss()
            }
        } message: {
            Text("This can't be undone.")
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: PreviewData.sampleItem)
    }
    .modelContainer(PreviewData.container)
}
