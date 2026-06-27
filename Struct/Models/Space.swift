//
//  Space.swift
//  Struct
//
//  Created by Otto Kiefer on 04.05.2026.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Space {
    /// The canonical tint colour for Space containers throughout the app.
    static let containerColor: Color = .indigo
    var name: String
    var symbolName: String
    var colorHex: String?
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date

    // Cascade: `Project.space` is non-optional, so projects cannot outlive
    // their Space.
    @Relationship(deleteRule: .cascade, inverse: \Project.space)
    var projects: [Project] = []

    // Nullify: `List.space` remains optional to accommodate the system Inbox,
    // but user-created Lists are guaranteed to belong to a Space at creation
    // time. On Space deletion, surviving lists become orphaned (which today
    // means hidden from the UI); revisit if/when we re-introduce a loose
    // scope.
    @Relationship(deleteRule: .nullify, inverse: \List.space)
    var lists: [List] = []

    @Relationship(deleteRule: .nullify, inverse: \Item.space)
    var items: [Item] = []

    @Relationship(deleteRule: .nullify, inverse: \TaskSection.space)
    var taskSections: [TaskSection] = []

    init(name: String,
         symbolName: String = "square.grid.2x2",
         colorHex: String? = nil,
         sortIndex: Int = 0) {
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.sortIndex = sortIndex
        self.createdAt = .now
        self.updatedAt = .now
    }

    func touch() {
        updatedAt = .now
    }
}

extension Space {
    static func nextSortIndex(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Space>(
            sortBy: [SortDescriptor(\.sortIndex, order: .reverse)]
        )
        let current = (try? context.fetch(descriptor).first?.sortIndex) ?? -1
        return current + 1
    }
}

// MARK: - ContainerTarget

// Type-erased navigation target. `PersistentModel` is `Hashable`, so the
// enum derives `Hashable` automatically — usable directly as a
// `NavigationLink` value.
enum ContainerTarget: Hashable {
    case space(Space)
    case project(Project)
    case list(List)
}

extension ContainerTarget {
    var title: String {
        switch self {
        case .space(let s): s.name
        case .project(let p): p.title
        case .list(let l): l.title
        }
    }

    var symbol: String {
        switch self {
        case .space(let s): s.symbolName
        case .project: "folder"
        case .list(let l): l.kind == .inbox ? "tray" : "list.bullet"
        }
    }

    var color: Color {
        switch self {
        case .space:   Space.containerColor
        case .list:    List.containerColor
        case .project: Project.containerColor
        }
    }

    var items: [Item] {
        let raw: [Item]
        switch self {
        case .space(let s): raw = s.items
        case .project(let p): raw = p.items
        case .list(let l): raw = l.items
        }
        return raw.sorted { $0.sortIndex < $1.sortIndex }
    }
}

// MARK: - ContainerChild

// Type-erased child of a Space. After the unified-sortIndex migration both
// Lists and Projects share a single ordering namespace per Space; the UI
// sorts them together by `sortIndex` and may freely interleave them.
enum ContainerChild: Identifiable, Hashable {
    case list(List)
    case project(Project)

    enum ID: Hashable {
        case list(PersistentIdentifier)
        case project(PersistentIdentifier)
    }

    var id: ID {
        switch self {
        case .list(let l):    return .list(l.persistentModelID)
        case .project(let p): return .project(p.persistentModelID)
        }
    }

    var sortIndex: Int {
        switch self {
        case .list(let l):    return l.sortIndex
        case .project(let p): return p.sortIndex
        }
    }

    static func == (lhs: ContainerChild, rhs: ContainerChild) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - ContainerChild display helpers

extension ContainerChild {

    var symbol: String {
        switch self {
        case .list:    "list.bullet"
        case .project: "folder"
        }
    }

    var title: String {
        switch self {
        case .list(let l):    l.title
        case .project(let p): p.title
        }
    }

    var openTaskCount: Int {
        switch self {
        case .list(let l):    l.items.filter { !$0.isCompleted }.count
        case .project(let p): p.items.filter { !$0.isCompleted }.count
        }
    }

    var containerColor: Color {
        switch self {
        case .list:    List.containerColor
        case .project: Project.containerColor
        }
    }

    /// Navigation target for this child.
    var target: ContainerTarget {
        switch self {
        case .list(let l):    .list(l)
        case .project(let p): .project(p)
        }
    }

    /// Persistent identifier for lookups.
    var persistentModelID: PersistentIdentifier {
        switch self {
        case .list(let l):    return l.persistentModelID
        case .project(let p): return p.persistentModelID
        }
    }

    /// Whether this child is a List (as opposed to a Project).
    var isList: Bool {
        switch self {
        case .list:    return true
        case .project: return false
        }
    }

    /// Swipe-selection identifier for this child — used by sidebar rows to
    /// drive `SidebarSwipeSelection.matches` / `.toggle`.
    var swipeKind: SwipeableContainerKind {
        switch self {
        case .list(let l):    .list(l)
        case .project(let p): .project(p)
        }
    }
}

enum Containers {

    // MARK: Sort index helpers

    /// Next available sort index in the unified namespace for a new child of
    /// `space`. Lists and Projects share the same integer sequence.
    static func nextSortIndex(in space: Space) -> Int {
        let all = space.lists.filter { $0.kind != .inbox }.map(\.sortIndex)
                + space.projects.map(\.sortIndex)
        return (all.max() ?? -1) + 1
    }

    /// Alias kept for `CreateContainerView` call sites.
    static func nextListSortIndex(in space: Space) -> Int { nextSortIndex(in: space) }

    /// Alias kept for `CreateContainerView` call sites.
    static func nextProjectSortIndex(in space: Space) -> Int { nextSortIndex(in: space) }

    // MARK: Children

    /// All non-inbox children of `space`, sorted by their unified `sortIndex`.
    static func children(of space: Space) -> [ContainerChild] {
        let lists    = space.lists.filter { $0.kind != .inbox }.map(ContainerChild.list)
        let projects = space.projects.map(ContainerChild.project)
        return (lists + projects).sorted { $0.sortIndex < $1.sortIndex }
    }

    // MARK: Move child

    /// Moves a container child to the specified space at the specified index.
    /// If the source and target spaces differ, the child is re-parented.
    /// Both spaces are re-indexed afterward to ensure sequential sort indices.
    static func moveChild(_ child: ContainerChild, to targetSpace: Space, at index: Int, context: ModelContext) {
        // 1. Get the source space before modifying the child
        let sourceSpace: Space?
        switch child {
        case .list(let l):
            sourceSpace = l.space
            l.space = targetSpace
        case .project(let p):
            sourceSpace = p.space
            p.space = targetSpace
        }

        // 2. Collect target space children (child is now included)
        var targetChildren = Containers.children(of: targetSpace)

        // 3. Remove child from its current position, then insert at desired index
        guard let currentIdx = targetChildren.firstIndex(where: { $0.id == child.id }) else {
            try? context.save()
            return
        }
        let moved = targetChildren.remove(at: currentIdx)
        let clamped = min(index, targetChildren.count)
        // When dragging downward (currentIdx < clamped), removing the item from a
        // lower index shifts all subsequent items up by one, so the target index
        // must be reduced by one to compensate.
        let adjusted = currentIdx < clamped ? clamped - 1 : clamped
        targetChildren.insert(moved, at: adjusted)

        // 4. Re-number sequentially
        for (i, c) in targetChildren.enumerated() {
            switch c {
            case .list(let l):    l.sortIndex = i
            case .project(let p): p.sortIndex = i
            }
        }

        // 5. Re-index source space if different
        if let source = sourceSpace, source.persistentModelID != targetSpace.persistentModelID {
            Containers.ensureUnifiedSortOrder(for: source)
        }

        try? context.save()
    }

    // MARK: Move Space

    /// Moves a space to a new index in the global ordering.
    /// Re-indexes all spaces to maintain sequential sort indices.
    static func moveSpace(_ space: Space, to index: Int, context: ModelContext) {
        // Fetch all spaces sorted by current sortIndex
        let descriptor = FetchDescriptor<Space>(sortBy: [SortDescriptor(\.sortIndex)])
        guard var allSpaces = try? context.fetch(descriptor), !allSpaces.isEmpty else { return }
        
        // Remove the space from its current position
        guard let currentIndex = allSpaces.firstIndex(where: { $0.persistentModelID == space.persistentModelID }) else { return }
        let movedSpace = allSpaces.remove(at: currentIndex)
        
        // Insert at new position (clamped to valid range)
        let newIndex = min(index, allSpaces.count)
        // When dragging downward (currentIndex < newIndex), removing the space from a
        // lower index shifts all subsequent spaces up by one, so the target index
        // must be reduced by one to compensate.
        let adjustedIndex = currentIndex < newIndex ? newIndex - 1 : newIndex
        allSpaces.insert(movedSpace, at: adjustedIndex)
        
        // Re-number all spaces sequentially
        for (i, s) in allSpaces.enumerated() {
            s.sortIndex = i
        }
        
        try? context.save()
    }

    // MARK: Migration

    /// Migrates a space whose lists and projects still occupy separate
    /// `sortIndex` namespaces (pre-unification) into the single unified
    /// namespace.
    ///
    /// Canonical order after migration: lists (original relative order)
    /// followed by projects (original relative order), matching the previous
    /// visual layout.  The function is idempotent — a space that is already
    /// correctly packed is left unchanged.
    static func ensureUnifiedSortOrder(for space: Space) {
        let lists    = space.lists.filter { $0.kind != .inbox }.sorted { $0.sortIndex < $1.sortIndex }
        let projects = space.projects.sorted { $0.sortIndex < $1.sortIndex }

        // Check if already packed in the unified namespace
        var expected = 0
        var needsMigration = false
        for l in lists    { if l.sortIndex != expected { needsMigration = true; break }; expected += 1 }
        if !needsMigration {
            for p in projects { if p.sortIndex != expected { needsMigration = true; break }; expected += 1 }
        }
        guard needsMigration else { return }

        for (i, l) in lists.enumerated()    { l.sortIndex = i }
        for (i, p) in projects.enumerated() { p.sortIndex = lists.count + i }
    }
}
