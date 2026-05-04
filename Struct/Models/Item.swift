//
//  Item.swift
//  Struct
//
//  Created by Otto Kiefer on 04.05.2026.
//

import Foundation
import SwiftData

enum ItemParent {
    case space(Space)
    case project(Project)
    case list(List)
}

@Model
final class Item {
    var title: String
    var notes: String
    var isCompleted: Bool {
        didSet {
            completedAt = isCompleted ? (completedAt ?? .now) : nil
        }
    }
    var completedAt: Date?
    var dueDate: Date?
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date

    // Mutually-exclusive parents — invariant enforced via `setParent(_:)`.
    // `private(set)` blocks the most obvious leak (direct assignment); note
    // that the inverse-relationship route (`list.items.append(item)`) can
    // still mutate these without clearing the others. Funnel parent changes
    // through `setParent` to preserve the invariant.
    private(set) var space: Space?
    private(set) var project: Project?
    private(set) var list: List?

    // Future hooks — enable when tags / subtasks land:
    //
    // @Relationship(inverse: \Tag.items)
    // var tags: [Tag] = []
    //
    // var parent: Item?
    //
    // @Relationship(deleteRule: .cascade, inverse: \Item.parent)
    // var subtasks: [Item] = []

    // `parent` is optional so callers can defer the choice to the persistence
    // layer. A `nil` parent leaves the item parent-less *transiently*; it must
    // be attached to the Inbox via `attachToInboxIfNeeded(in:)` (or assigned
    // another parent via `setParent`) before it is observed by the UI.
    // Prefer `Item.create(in:title:…)` for the fully wired flow.
    init(title: String,
         notes: String = "",
         dueDate: Date? = nil,
         sortIndex: Int = 0,
         parent: ItemParent? = nil) {
        self.title = title
        self.notes = notes
        self.isCompleted = false
        self.completedAt = nil
        self.dueDate = dueDate
        self.sortIndex = sortIndex
        self.createdAt = .now
        self.updatedAt = .now
        self.space = nil
        self.project = nil
        self.list = nil
        if let parent {
            applyParent(parent)
        }
        assertSingleParent()
    }

    func setParent(_ parent: ItemParent) {
        applyParent(parent)
        assertExactlyOneParent()
    }

    func touch() {
        updatedAt = .now
    }

    private func applyParent(_ parent: ItemParent) {
        switch parent {
        case .space(let s):
            self.space = s; self.project = nil; self.list = nil
        case .project(let p):
            self.space = nil; self.project = p; self.list = nil
        case .list(let l):
            self.space = nil; self.project = nil; self.list = l
        }
    }

    // Permissive check: at most one parent may be set. Zero is allowed to
    // accommodate the transient parent-less state between `init` and
    // `attachToInboxIfNeeded(in:)`.
    private func assertSingleParent() {
        #if DEBUG
        let count = [space != nil, project != nil, list != nil].filter { $0 }.count
        assert(count <= 1, "Item has multiple parents set simultaneously")
        #endif
    }

    // Strict check: exactly one parent must be set. Use after a parent has
    // been assigned (explicitly or via Inbox fallback).
    private func assertExactlyOneParent() {
        #if DEBUG
        let count = [space != nil, project != nil, list != nil].filter { $0 }.count
        assert(count == 1, "Item must have exactly one parent")
        #endif
    }
}

extension Item {
    // Idiomatic entry point: builds the item, inserts it into `context`, and
    // falls back to the Inbox `List` when no parent was supplied. Keeps the
    // ModelContext dependency out of `init`, where it isn't available.
    @discardableResult
    static func create(in context: ModelContext,
                       title: String,
                       notes: String = "",
                       dueDate: Date? = nil,
                       sortIndex: Int = 0,
                       parent: ItemParent? = nil) -> Item {
        let item = Item(title: title,
                        notes: notes,
                        dueDate: dueDate,
                        sortIndex: sortIndex,
                        parent: parent)
        context.insert(item)
        if parent == nil {
            item.attachToInboxIfNeeded(in: context)
        }
        return item
    }

    // Assigns the Inbox list as the parent if (and only if) no parent is set.
    // No-op for items that already have a parent. Relies on
    // `List.ensureInbox(in:)` having run at app start.
    func attachToInboxIfNeeded(in context: ModelContext) {
        guard space == nil, project == nil, list == nil else { return }
        let inboxRaw = ListKind.inbox.rawValue
        let descriptor = FetchDescriptor<List>(
            predicate: #Predicate { $0.kindRaw == inboxRaw }
        )
        do {
            if let inbox = try context.fetch(descriptor).first {
                applyParent(.list(inbox))
                assertExactlyOneParent()
            } else {
                assertionFailure("Inbox list missing; call List.ensureInbox(in:) at app start.")
            }
        } catch {
            assertionFailure("Inbox lookup failed: \(error)")
        }
    }
}
