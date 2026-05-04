//
//  List.swift
//  Struct
//
//  Created by Otto Kiefer on 04.05.2026.
//

import Foundation
import SwiftData

enum ListKind: String, Codable {
    case user
    case inbox
}

@Model
final class List {
    @Attribute(.unique) var slug: String
    var title: String
    var notes: String
    var kindRaw: String
    var sortIndex: Int
    // Mirror of `space == nil`, kept in sync via `init` and `move(to:at:context:)`.
    // Stored to keep `@Query` predicates straightforward (SwiftData predicates on
    // optional to-one relationships are fragile).
    var isLoose: Bool
    var createdAt: Date
    var updatedAt: Date

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
        self.slug = slug
        self.title = title
        self.notes = notes
        self.kindRaw = kind.rawValue
        self.sortIndex = sortIndex
        self.isLoose = (space == nil)
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
    // to the end of the destination scope (across both Lists and Projects).
    func move(to space: Space?, at index: Int? = nil, context: ModelContext) {
        let destination = index ?? Containers.nextSortIndex(in: space, context: context)
        self.space = space
        self.isLoose = (space == nil)
        self.sortIndex = destination
        touch()
    }
}
