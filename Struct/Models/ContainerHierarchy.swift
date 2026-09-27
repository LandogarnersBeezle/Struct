//
//  ContainerHierarchy.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import Foundation

/// Presentation data that the list derives from the container order.
struct ContainerRowPresentation: Equatable {
    /// Nesting level, used for indentation.
    var depth = 0
    /// Number of lists and projects owned by a space.
    var childCount = 0
    /// `true` for a list or project that sits above the first space.
    var isAutonomous = false
}

/// Position-based hierarchy helpers.
///
/// The order of the array *is* the hierarchy: lists and projects that follow a
/// space belong to it, while everything above the first space is a sole list or
/// project.
extension Array where Element == ContainerItem {
    func index(of id: ContainerItem.ID) -> Int? {
        firstIndex { $0.id == id }
    }

    /// The space that owns the container at `index`, if any.
    func parentID(at index: Int) -> ContainerItem.ID? {
        guard indices.contains(index), !self[index].isSpace else { return nil }
        return self[..<index].last { $0.isSpace }?.id
    }

    /// `true` for a list or project that sits above the first space.
    func isAutonomous(at index: Int) -> Bool {
        guard indices.contains(index) else { return false }
        return !self[index].isSpace && parentID(at: index) == nil
    }

    /// Nesting level of the container at `index`.
    func depth(at index: Int) -> Int {
        guard indices.contains(index) else { return 0 }
        return self[index].isSpace || isAutonomous(at: index) ? 0 : 1
    }

    /// Number of lists and projects owned by the space at `index`.
    func childCount(ofSpaceAt index: Int) -> Int {
        guard indices.contains(index), self[index].isSpace else { return 0 }
        return Swift.max(0, ContainerMove.blockRange(startingAt: index, in: self).count - 1)
    }

    /// Presentation data for every container, keyed by identifier, so the list
    /// can render rows while iterating over the containers themselves.
    var rowPresentations: [ContainerItem.ID: ContainerRowPresentation] {
        var presentations: [ContainerItem.ID: ContainerRowPresentation] = [:]
        for index in indices {
            presentations[self[index].id] = ContainerRowPresentation(
                depth: depth(at: index),
                childCount: childCount(ofSpaceAt: index),
                isAutonomous: isAutonomous(at: index)
            )
        }
        return presentations
    }
}
