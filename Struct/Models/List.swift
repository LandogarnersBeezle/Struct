//
//  List.swift
//  Struct
//
//  Created by Otto Kiefer on 04.05.2026.
//

import Foundation
import SwiftData
import SwiftUI

enum ListKind: String, Codable {
    case user
    case inbox
}

@Model
final class List {
    /// The canonical tint colour for List containers throughout the app.
    static let containerColor: Color = .cyan
    @Attribute(.unique) var slug: String
    var title: String
    var notes: String
    var kindRaw: String
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date

    // Optional only to accommodate the system Inbox (`kind == .inbox`). Every
    // user-created List must belong to a Space; enforced in `init` via assert.
    var space: Space?

    @Relationship(deleteRule: .cascade, inverse: \Item.list)
    var items: [Item] = []

    var kind: ListKind {
        get { ListKind(rawValue: kindRaw) ?? .user }
        set { kindRaw = newValue.rawValue }
    }

    init(title: String,
         notes: String = "",
         kind: ListKind = .user,
         space: Space? = nil,
         sortIndex: Int = 0,
         slug: String = UUID().uuidString) {
        assert(kind == .inbox || space != nil, "Non-inbox List must belong to a Space")
        self.slug = slug
        self.title = title
        self.notes = notes
        self.kindRaw = kind.rawValue
        self.sortIndex = sortIndex
        self.createdAt = .now
        self.updatedAt = .now
        self.space = space
    }

    func touch() {
        updatedAt = .now
    }
}

extension List {
    static let inboxSlug = "inbox"

    static func ensureInbox(in context: ModelContext) {
        let slug = inboxSlug
        let descriptor = FetchDescriptor<List>(
            predicate: #Predicate { $0.slug == slug }
        )
        do {
            let existing = try context.fetch(descriptor)
            if existing.isEmpty == false { return }
            let inbox = List(title: "Inbox", kind: .inbox, slug: inboxSlug)
            context.insert(inbox)
            try context.save()
        } catch {
            assertionFailure("Inbox bootstrap failed: \(error)")
        }
    }

    // Centralized re-parent / re-order entry point. Pass `index = nil` to append
    // to the end of the List ordering namespace within `space`.
    func move(to space: Space, at index: Int? = nil, context: ModelContext) {
        let destination = index ?? Containers.nextListSortIndex(in: space)
        self.space = space
        self.sortIndex = destination
        touch()
    }
}
