import Foundation
import SwiftData

/// The one sample persisted type, here so the SwiftData wiring is already
/// working end to end: container → query → list → detail → edit → delete.
///
/// Rename it to whatever your app is actually about, or delete this file and
/// the `Features/Items` folder entirely — see the README for the three other
/// places SwiftData is referenced.
@Model
final class Item {
    /// A stable identifier of your own. SwiftData gives every model a
    /// `persistentModelID`, but that one changes if the store is rebuilt, so
    /// anything you sync, export or link to wants an id you control.
    var id: UUID
    var title: String
    var note: String
    var isFavourite: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        isFavourite: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.isFavourite = isFavourite
        self.createdAt = createdAt
    }
}

extension Item {
    /// Used by previews and by the "Add sample data" button in Settings.
    static var samples: [Item] {
        [
            Item(title: "First item", note: "Items are stored with SwiftData.", isFavourite: true),
            Item(title: "Second item", note: "Swipe to delete, tap to open."),
            Item(title: "Third item", note: "Edit a title in the detail view and it saves itself."),
        ]
    }
}
