//
//  ContainerHierarchy.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import Foundation

/// Presentation data that the list derives from the explicit container relations.
struct ContainerRowPresentation: Equatable, Sendable {
    /// Nesting level, used for indentation.
    var depth = 0
    /// Number of lists and projects owned by a space.
    var childCount = 0
    /// `true` for a list or project that sits above the spaces (autonomous/sole).
    var isAutonomous = false
    /// For a space: whether its children are currently expanded.
    var isExpanded = true
}

/// Hybrid projection helpers.
///
/// In the hybrid architecture, presentation properties and visual ordering are
/// projected from explicit relational data (`parentID`, `sortOrder`, `isSpace`)
/// rather than relying on positional array-scanning hacks.
extension Array where Element == ContainerItem {
    func index(of id: ContainerItem.ID) -> Int? {
        firstIndex { $0.id == id }
    }

    /// The space that owns the container at `index`, if any.
    func parentID(at index: Int) -> ContainerItem.ID? {
        guard indices.contains(index) else { return nil }
        return self[index].parentID
    }

    /// `true` for a list or project that is autonomous (has no parent space).
    func isAutonomous(at index: Int) -> Bool {
        guard indices.contains(index) else { return false }
        return !self[index].isSpace && self[index].parentID == nil
    }

    /// Nesting level of the container at `index`.
    func depth(at index: Int) -> Int {
        guard indices.contains(index) else { return 0 }
        return self[index].isSpace || isAutonomous(at: index) ? 0 : 1
    }

    /// Number of lists and projects owned by the space at `index`.
    func childCount(ofSpaceAt index: Int) -> Int {
        guard indices.contains(index), self[index].isSpace else { return 0 }
        let spaceID = self[index].id
        return filter { $0.parentID == spaceID }.count
    }

    /// Presentation data for every container, keyed by identifier, computed in
    /// a clean single pass over explicit relational data.
    var rowPresentations: [ContainerItem.ID: ContainerRowPresentation] {
        // Pre-calculate child counts per space in O(N)
        var counts: [ContainerItem.ID: Int] = [:]
        for item in self where !item.isSpace {
            if let parentID = item.parentID {
                counts[parentID, default: 0] += 1
            }
        }

        var presentations: [ContainerItem.ID: ContainerRowPresentation] = [:]
        presentations.reserveCapacity(count)

        for item in self {
            if item.isSpace {
                presentations[item.id] = ContainerRowPresentation(
                    depth: 0,
                    childCount: counts[item.id] ?? 0,
                    isAutonomous: false,
                    isExpanded: item.isExpanded
                )
            } else {
                let isAuto = item.parentID == nil
                presentations[item.id] = ContainerRowPresentation(
                    depth: isAuto ? 0 : 1,
                    childCount: 0,
                    isAutonomous: isAuto,
                    isExpanded: true
                )
            }
        }
        return presentations
    }
}

