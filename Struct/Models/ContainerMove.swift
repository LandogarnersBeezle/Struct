//
//  ContainerMove.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import Foundation

/// Applies a reordering operation in the hybrid architecture.
///
/// In the hybrid architecture, items have explicit `parentID` and `sortOrder`.
/// Moving items resolves their updated parentage and order while maintaining
/// continuous sorting invariants and moving spaces along with their explicit children.
enum ContainerMove {
    /// Everything that travels with `id`:
    /// If `id` is a space, it travels with all items where `parentID == id`.
    /// Otherwise, just `id`.
    static func travellingIdentifiers(for id: ContainerItem.ID, in items: [ContainerItem]) -> [ContainerItem.ID] {
        guard let item = items.first(where: { $0.id == id }) else { return [] }
        if item.isSpace {
            let childIDs = items.filter { $0.parentID == item.id }.map(\.id)
            return [item.id] + childIDs
        } else {
            return [item.id]
        }
    }

    /// The union of all identifiers that travel when multiple `ids` are dragged.
    static func movingIdentifiers(in items: [ContainerItem], moving ids: [ContainerItem.ID]) -> Set<ContainerItem.ID> {
        var moving: Set<ContainerItem.ID> = []
        for id in ids {
            moving.formUnion(travellingIdentifiers(for: id, in: items))
        }
        return moving
    }

    /// Number of autonomous (sole) lists and projects above the first space.
    static func soleRegionLength(in items: [ContainerItem]) -> Int {
        items.prefix { !$0.isSpace && $0.parentID == nil }.count
    }

    /// Projects and sorts a set of items into canonical visual display order:
    /// 1. Autonomous items (parentID == nil && !isSpace) sorted by `sortOrder`
    /// 2. For each space (sorted by `sortOrder`):
    ///    - the space itself
    ///    - its children (parentID == space.id) sorted by `sortOrder`
    static func projectSorted(_ items: [ContainerItem]) -> [ContainerItem] {
        let autonomous = items
            .filter { !$0.isSpace && $0.parentID == nil }
            .sorted { $0.sortOrder < $1.sortOrder }

        let spaces = items
            .filter { $0.isSpace }
            .sorted { $0.sortOrder < $1.sortOrder }

        var result: [ContainerItem] = []
        result.reserveCapacity(items.count)
        result.append(contentsOf: autonomous)

        for space in spaces {
            result.append(space)
            let children = items
                .filter { $0.parentID == space.id }
                .sorted { $0.sortOrder < $1.sortOrder }
            result.append(contentsOf: children)
        }

        return result
    }

    /// Moves `ids` – together with the explicit children of any space among them – so
    /// that they end up placed directly before `destinationID` in the visual list.
    /// If `destinationID` is `nil`, they are placed at the end of the list.
    ///
    /// Returns the updated items with explicit `parentID` and `sortOrder` normalized.
    static func resolve(
        _ items: [ContainerItem],
        moving ids: [ContainerItem.ID],
        before destinationID: ContainerItem.ID?
    ) -> [ContainerItem] {
        let moving = movingIdentifiers(in: items, moving: ids)
        guard !moving.isEmpty else { return items }

        // Dropping onto an item that travels with the drag keeps the order.
        if let destinationID, moving.contains(destinationID) {
            return items
        }

        let travelling = items.filter { moving.contains($0.id) }
        var remaining = items.filter { !moving.contains($0.id) }

        var insertionIndex: Int
        if let destinationID, let targetIndex = remaining.firstIndex(where: { $0.id == destinationID }) {
            insertionIndex = targetIndex
        } else {
            insertionIndex = remaining.count
        }

        // The sole lists and projects own the region above the first space:
        // A space dropped there (or onto one of them) snaps to the start of the spaces region.
        if travelling.contains(where: \.isSpace) {
            let soleCount = remaining.prefix { !$0.isSpace && $0.parentID == nil }.count
            insertionIndex = max(insertionIndex, soleCount)
        }

        remaining.insert(contentsOf: travelling, at: insertionIndex)

        // Derive explicit relational attributes (parentID & sortOrder) from this visual ordering.
        return normalizeRelations(remaining)
    }

    /// Moves `ids` – together with the explicit children of any space among them – so
    /// that they end up placed directly before `destinationIndex` in the visual list.
    ///
    /// `destinationIndex` refers to `items` as displayed *before* the move.
    /// Returns the updated items with explicit `parentID` and `sortOrder` normalized.
    static func resolve(
        _ items: [ContainerItem],
        moving ids: [ContainerItem.ID],
        destinationIndex: Int
    ) -> [ContainerItem] {
        let destinationID = items.indices.contains(destinationIndex) ? items[destinationIndex].id : nil
        return resolve(items, moving: ids, before: destinationID)
    }

    /// Derives explicit `parentID` and normalized `sortOrder` from a visual list sequence.
    /// This keeps the domain models synchronized with the visual projection.
    static func normalizeRelations(_ visualItems: [ContainerItem]) -> [ContainerItem] {
        var currentSpaceID: ContainerItem.ID? = nil

        var orderCounter: Double = 100

        for item in visualItems {
            if item.isSpace {
                currentSpaceID = item.id
                item.parentID = nil
                item.sortOrder = orderCounter
                orderCounter += 100
            } else {
                item.parentID = currentSpaceID
                item.sortOrder = orderCounter
                orderCounter += 100
            }
        }

        return visualItems
    }
}

