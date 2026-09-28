//
//  ContainerItem.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import Foundation
import SwiftData

/// The kinds of container in the app's hierarchy.
///
/// A space is a top-level container that groups the lists and projects that
/// belong to it. Lists and projects either live inside a space (with `parentID`
/// pointing to that space) or exist on their own (`parentID == nil`).
enum ContainerKind: String, Codable, CaseIterable, Sendable {
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

/// A single entry of the container list persisted via SwiftData.
///
/// Under the hybrid architecture, each item explicitly declares its optional parent
/// (`parentID`) and its relative ordering. This prepares the model for relational
/// persistence (SwiftData / CoreData / SQLite) and multi-level hierarchies.
@Model
final class ContainerItem: Identifiable {
    var id: UUID = UUID()
    var kind: ContainerKind = ContainerKind.list
    var name: String = ""
    /// The parent space if nested, or `nil` if top-level / autonomous.
    var parentID: UUID?
    /// Explicit ordering index among siblings.
    var sortOrder: Double = 0
    /// Indicates whether this container is part of the sample dataset.
    var isSample: Bool = false
    /// For a space, determines whether its child lists and projects are expanded in the list.
    var isExpanded: Bool = true

    init(
        id: UUID = UUID(),
        kind: ContainerKind,
        name: String,
        parentID: UUID? = nil,
        sortOrder: Double = 0,
        isSample: Bool = false,
        isExpanded: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.parentID = parentID
        self.sortOrder = sortOrder
        self.isSample = isSample
        self.isExpanded = isExpanded
    }

    var isSpace: Bool { kind == .space }
}



