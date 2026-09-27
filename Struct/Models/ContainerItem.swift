//
//  ContainerItem.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import Foundation

/// The kinds of container in the app's hierarchy.
///
/// A space is a top-level container that groups the lists and projects that
/// belong to it. Lists and projects either live inside a space (with `parentID`
/// pointing to that space) or exist on their own (`parentID == nil`).
enum ContainerKind: String, CaseIterable, Sendable {
    case space
    case list
    case project

    var displayName: String {
        switch self {
        case .space: "Space"
        case .list: "List"
        case .project: "Project"
        }
    }

    var symbolName: String {
        switch self {
        case .space: "square.stack.3d.up"
        case .list: "list.bullet"
        case .project: "checklist"
        }
    }
}

/// A single entry of the container list.
///
/// Under the hybrid architecture, each item explicitly declares its optional parent
/// (`parentID`) and its relative ordering. This prepares the model for relational
/// persistence (SwiftData / CoreData / SQLite) and multi-level hierarchies.
struct ContainerItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var kind: ContainerKind
    var name: String
    /// The parent space if nested, or `nil` if top-level / autonomous.
    var parentID: UUID?
    /// Explicit ordering index among siblings.
    var sortOrder: Double

    init(
        id: UUID = UUID(),
        kind: ContainerKind,
        name: String,
        parentID: UUID? = nil,
        sortOrder: Double = 0
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.parentID = parentID
        self.sortOrder = sortOrder
    }

    var isSpace: Bool { kind == .space }
}

