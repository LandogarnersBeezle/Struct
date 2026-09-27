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
/// follow it. Lists and projects either live inside a space or exist on their
/// own above the first space.
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
/// The type stays a plain value type so the reordering rules can be exercised
/// without a user interface. When persistence arrives, this maps onto a model
/// type carrying a sort index and an optional parent.
struct ContainerItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var kind: ContainerKind
    var name: String

    init(id: UUID = UUID(), kind: ContainerKind, name: String) {
        self.id = id
        self.kind = kind
        self.name = name
    }

    var isSpace: Bool { kind == .space }
}
