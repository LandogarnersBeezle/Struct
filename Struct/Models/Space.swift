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
    static let containerColor: Color = .blue
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

// Type-erased child of a Space. Lists and Projects each have their own
// ordering namespace within the Space; the UI renders all Lists first
// (sorted by `sortIndex`) followed by all Projects (sorted by `sortIndex`).
enum ContainerChild: Identifiable {
    case list(List)
    case project(Project)

    enum ID: Hashable {
        case list(PersistentIdentifier)
        case project(PersistentIdentifier)
    }

    var id: ID {
        switch self {
        case .list(let l): return .list(l.persistentModelID)
        case .project(let p): return .project(p.persistentModelID)
        }
    }

    var sortIndex: Int {
        switch self {
        case .list(let l): return l.sortIndex
        case .project(let p): return p.sortIndex
        }
    }
}

enum Containers {
    // One past the current max `sortIndex` among Lists in `space` (Inbox
    // excluded — it is rendered as its own section).
    static func nextListSortIndex(in space: Space) -> Int {
        let max = space.lists
            .filter { $0.kind != .inbox }
            .map(\.sortIndex)
            .max() ?? -1
        return max + 1
    }

    // One past the current max `sortIndex` among Projects in `space`.
    static func nextProjectSortIndex(in space: Space) -> Int {
        (space.projects.map(\.sortIndex).max() ?? -1) + 1
    }

    // All Lists (sorted by `sortIndex`) followed by all Projects (sorted by
    // `sortIndex`). The two types occupy separate ordering namespaces and are
    // never interleaved.
    static func children(of space: Space) -> [ContainerChild] {
        let lists = space.lists
            .filter { $0.kind != .inbox }
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(ContainerChild.list)
        let projects = space.projects
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(ContainerChild.project)
        return lists + projects
    }
}
