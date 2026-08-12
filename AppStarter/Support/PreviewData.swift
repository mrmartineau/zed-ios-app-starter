import SwiftData
import Foundation

/// An in-memory SwiftData stack for previews, pre-filled with sample rows.
///
/// `isStoredInMemoryOnly` matters: without it, every preview render would write
/// to the real on-disk store and previews would slowly fill the simulator's
/// database with junk.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: Item.self, configurations: configuration)
            for item in Item.samples {
                container.mainContext.insert(item)
            }
            return container
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }()

    /// A single detached item, for previewing the detail screen.
    static let sampleItem = Item(
        title: "Sample item",
        note: "Bound straight to the model — edits here update the list.",
        isFavourite: true
    )
}
