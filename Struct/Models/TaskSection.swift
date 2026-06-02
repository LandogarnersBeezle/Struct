//
//  TaskSection.swift
//  Struct
//
//  Created by Otto Kiefer on 02.06.2026.
//

import Foundation
import SwiftData

/// Represents a user-created section/heading within a container (Space, List, or Project).
/// TaskSections provide an additional organizational layer, allowing tasks to be grouped
/// under headings within their parent container.
enum TaskSectionParent {
    case space(Space)
    case list(List)
    case project(Project)
}

@Model
final class TaskSection {
    var title: String
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date

    // Mutually-exclusive parents — invariant enforced via `setParent(_:)`.
    // Only one of these may be set at any time.
    private(set) var space: Space?
    private(set) var list: List?
    private(set) var project: Project?

    // Items belonging to this section. Cascade delete ensures that when a
    // section is deleted, its items are deleted with it. If you want items
    // to survive section deletion, change to .nullify and reassign items.
    @Relationship(deleteRule: .cascade, inverse: \Item.taskSection)
    var items: [Item] = []

    init(title: String,
         sortIndex: Int = 0,
         parent: TaskSectionParent? = nil) {
        self.title = title
        self.sortIndex = sortIndex
        self.createdAt = .now
        self.updatedAt = .now
        self.space = nil
        self.list = nil
        self.project = nil
        if let parent {
            applyParent(parent)
        }
        assertSingleParent()
    }

    /// Sets the parent container for this section, clearing any previous parent.
    func setParent(_ parent: TaskSectionParent) {
        applyParent(parent)
        assertExactlyOneParent()
    }

    func touch() {
        updatedAt = .now
    }

    private func applyParent(_ parent: TaskSectionParent) {
        switch parent {
        case .space(let s):
            self.space = s; self.list = nil; self.project = nil
        case .list(let l):
            self.space = nil; self.list = l; self.project = nil
        case .project(let p):
            self.space = nil; self.list = nil; self.project = p
        }
    }

    /// Returns the parent container as an ItemParent, for convenient item assignment.
    var itemParent: ItemParent? {
        if let space { return .space(space) }
        if let list { return .list(list) }
        if let project { return .project(project) }
        return nil
    }

    // MARK: - Parent Accessors

    /// Returns the containing Space, if any.
    var containerSpace: Space? { space }

    /// Returns the containing List, if any.
    var containerList: List? { list }

    /// Returns the containing Project, if any.
    var containerProject: Project? { project }

    // MARK: - Assertions

    /// Permissive check: at most one parent may be set. Zero is allowed to
    /// accommodate the transient parent-less state between `init` and parent assignment.
    private func assertSingleParent() {
        #if DEBUG
        let count = [space != nil, list != nil, project != nil].filter { $0 }.count
        assert(count <= 1, "TaskSection has multiple parents set simultaneously")
        #endif
    }

    /// Strict check: exactly one parent must be set. Use after a parent has
    /// been assigned.
    private func assertExactlyOneParent() {
        #if DEBUG
        let count = [space != nil, list != nil, project != nil].filter { $0 }.count
        assert(count == 1, "TaskSection must have exactly one parent")
        #endif
    }
}

// MARK: - TaskSection Management Helpers

extension TaskSection {
    /// Next available sort index for a new section within a Space.
    static func nextSortIndex(in space: Space, context: ModelContext) -> Int {
        let id = space.persistentModelID
        let descriptor = FetchDescriptor<TaskSection>(
            predicate: #Predicate { $0.space?.persistentModelID == id },
            sortBy: [SortDescriptor(\TaskSection.sortIndex, order: .reverse)]
        )
        let current = (try? context.fetch(descriptor).first?.sortIndex) ?? -1
        return current + 1
    }

    /// Next available sort index for a new section within a List.
    static func nextSortIndex(in list: List, context: ModelContext) -> Int {
        let id = list.persistentModelID
        let descriptor = FetchDescriptor<TaskSection>(
            predicate: #Predicate { $0.list?.persistentModelID == id },
            sortBy: [SortDescriptor(\TaskSection.sortIndex, order: .reverse)]
        )
        let current = (try? context.fetch(descriptor).first?.sortIndex) ?? -1
        return current + 1
    }

    /// Next available sort index for a new section within a Project.
    static func nextSortIndex(in project: Project, context: ModelContext) -> Int {
        let id = project.persistentModelID
        let descriptor = FetchDescriptor<TaskSection>(
            predicate: #Predicate { $0.project?.persistentModelID == id },
            sortBy: [SortDescriptor(\TaskSection.sortIndex, order: .reverse)]
        )
        let current = (try? context.fetch(descriptor).first?.sortIndex) ?? -1
        return current + 1
    }

    /// Moves this section to a new Space, optionally at a specific index.
    func move(to space: Space, at index: Int? = nil, context: ModelContext) {
        let destination = index ?? TaskSection.nextSortIndex(in: space, context: context)
        self.space = space
        self.list = nil
        self.project = nil
        self.sortIndex = destination
        touch()
    }

    /// Moves this section to a new List, optionally at a specific index.
    func move(to list: List, at index: Int? = nil, context: ModelContext) {
        let destination = index ?? TaskSection.nextSortIndex(in: list, context: context)
        self.space = nil
        self.list = list
        self.project = nil
        self.sortIndex = destination
        touch()
    }

    /// Moves this section to a new Project, optionally at a specific index.
    func move(to project: Project, at index: Int? = nil, context: ModelContext) {
        let destination = index ?? TaskSection.nextSortIndex(in: project, context: context)
        self.space = nil
        self.list = nil
        self.project = project
        self.sortIndex = destination
        touch()
    }

    /// Repacks sort indices for sections to be contiguous 0-based integers.
    static func repack(_ sections: [TaskSection]) {
        for (i, section) in sections.enumerated() {
            section.sortIndex = i
        }
    }
}