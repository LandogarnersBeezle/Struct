//
//  ContainerMove.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import Foundation

/// Applies a reordering operation to the flat container array.
///
/// The array itself is the hierarchy, so every rule about parents, children and
/// the sole lists and projects is expressed as index arithmetic on this array.
enum ContainerMove {
    /// The containers that travel with one item: a list or project on its own,
    /// or a space together with the lists and projects that follow it.
    static func blockRange(startingAt index: Int, in items: [ContainerItem]) -> Range<Int> {
        guard items.indices.contains(index) else { return index..<index }
        guard items[index].isSpace else { return index..<(index + 1) }
        var end = index + 1
        while end < items.count, !items[end].isSpace { end += 1 }
        return index..<end
    }

    /// The identifiers of everything that travels with `id`.
    static func travellingIdentifiers(for id: ContainerItem.ID, in items: [ContainerItem]) -> [ContainerItem.ID] {
        guard let index = items.index(of: id) else { return [] }
        return blockRange(startingAt: index, in: items).map { items[$0].id }
    }

    /// The identifiers of everything that travels with `ids`.
    static func movingIdentifiers(in items: [ContainerItem], moving ids: [ContainerItem.ID]) -> Set<ContainerItem.ID> {
        var moving: Set<ContainerItem.ID> = []
        for id in ids {
            moving.formUnion(travellingIdentifiers(for: id, in: items))
        }
        return moving
    }

    /// Number of sole lists and projects above the first space.
    static func soleRegionLength(in items: [ContainerItem]) -> Int {
        items.prefix { !$0.isSpace }.count
    }

    /// Moves `ids` – together with the children of any space among them – so
    /// that they end up directly before `destinationIndex`.
    ///
    /// `destinationIndex` refers to `items` as it is *before* the move.
    static func resolve(
        _ items: [ContainerItem],
        moving ids: [ContainerItem.ID],
        destinationIndex: Int
    ) -> [ContainerItem] {
        let moving = movingIdentifiers(in: items, moving: ids)
        guard !moving.isEmpty else { return items }

        let anchor = max(0, min(destinationIndex, items.count))
        // Dropping onto a container that travels with the drag keeps the order.
        if anchor < items.count, moving.contains(items[anchor].id) { return items }

        let travelling = items.filter { moving.contains($0.id) }
        let remaining = items.filter { !moving.contains($0.id) }

        // Number of remaining containers that precede the drop anchor.
        var insertionIndex = items[..<anchor].filter { !moving.contains($0.id) }.count

        // The sole lists and projects own the region above the first space, so a
        // space that is dropped there – or onto one of them – snaps to the end of
        // that region and leaves them untouched.
        if travelling.contains(where: \.isSpace) {
            insertionIndex = max(insertionIndex, soleRegionLength(in: items))
            insertionIndex = min(insertionIndex, remaining.count)
        }

        var result = remaining
        result.insert(contentsOf: travelling, at: insertionIndex)
        return normalize(result)
    }

    /// Hook for rules about the resulting order. The flat array already
    /// guarantees that a space is never nested inside another space, so this
    /// returns the order unchanged.
    static func normalize(_ items: [ContainerItem]) -> [ContainerItem] { items }
}
