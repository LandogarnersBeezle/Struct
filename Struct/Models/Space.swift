//
//  Space.swift
//  Struct
//
//  Created by Otto Kiefer on 04.05.2026.
//

import Foundation
import SwiftData

@Model
final class Space {
    var name: String
    var symbolName: String
    var colorHex: String?
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Project.space)
    var projects: [Project] = []

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

// Type-erased child of a container scope (loose, or inside a Space). Lists and
// Projects share a single ordering namespace per scope, so the UI merges them
// by `sortIndex`.
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
    // One past the current max `sortIndex` across both Lists and Projects in
    // the given scope. Pass `space = nil` for the loose scope. The Inbox is
    // excluded — it is rendered as its own section, not as a loose List.
    static func nextSortIndex(in space: Space?, context: ModelContext) -> Int {
        let listMax = maxListSortIndex(in: space, context: context)
        let projectMax = maxProjectSortIndex(in: space, context: context)
        return max(listMax, projectMax) + 1
    }

    // Lists + (non-inbox) ordered by `sortIndex` for rendering inside a Space.
    static func children(of space: Space) -> [ContainerChild] {
        let lists = space.lists
            .filter { $0.kind != .inbox }
            .map(ContainerChild.list)
        let projects = space.projects.map(ContainerChild.project)
        return (lists + projects).sorted { $0.sortIndex < $1.sortIndex }
    }

    private static func maxListSortIndex(in space: Space?, context: ModelContext) -> Int {
        if let space {
            return space.lists
                .filter { $0.kind != .inbox }
                .map(\.sortIndex)
                .max() ?? -1
        }
        let inboxRaw = ListKind.inbox.rawValue
        let descriptor = FetchDescriptor<List>(
            predicate: #Predicate { $0.isLoose && $0.kindRaw != inboxRaw },
            sortBy: [SortDescriptor(\.sortIndex, order: .reverse)]
        )
        return (try? context.fetch(descriptor).first?.sortIndex) ?? -1
    }

    private static func maxProjectSortIndex(in space: Space?, context: ModelContext) -> Int {
        if let space {
            return space.projects.map(\.sortIndex).max() ?? -1
        }
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.isLoose },
            sortBy: [SortDescriptor(\.sortIndex, order: .reverse)]
        )
        return (try? context.fetch(descriptor).first?.sortIndex) ?? -1
    }
}
