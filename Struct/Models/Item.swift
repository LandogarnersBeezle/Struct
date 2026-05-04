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

    init(title: String,
         notes: String = "",
         dueDate: Date? = nil,
         sortIndex: Int = 0,
         parent: ItemParent) {
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
        applyParent(parent)
        assertSingleParent()
    }

    func setParent(_ parent: ItemParent) {
        applyParent(parent)
        assertSingleParent()
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

    private func assertSingleParent() {
        #if DEBUG
        let count = [space != nil, project != nil, list != nil].filter { $0 }.count
        assert(count <= 1, "Item has multiple parents set simultaneously")
        #endif
    }
}
