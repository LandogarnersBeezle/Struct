//
//  ContainerStore.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import Foundation
import Observation

/// Owns the ordered containers and applies reordering operations.
///
/// In the hybrid architecture, items maintain explicit `parentID` and `sortOrder`.
/// `items` holds the canonical projected display sequence for the UI list.
@Observable
final class ContainerStore {
    var items: [ContainerItem]

    init(items: [ContainerItem] = SampleContainers.all) {
        self.items = items
    }

    /// Moves the containers identified by `ids` – together with the explicit children
    /// of any space among them – so that they end up before `destinationIndex`.
    func move(_ ids: [ContainerItem.ID], to destinationIndex: Int) {
        items = ContainerMove.resolve(items, moving: ids, destinationIndex: destinationIndex)
    }

    /// Everything that travels when `id` is dragged.
    func travellingIdentifiers(for id: ContainerItem.ID) -> [ContainerItem.ID] {
        ContainerMove.travellingIdentifiers(for: id, in: items)
    }

    /// Explicitly fetch all children belonging to a space.
    func children(of spaceID: ContainerItem.ID) -> [ContainerItem] {
        items.filter { $0.parentID == spaceID }
    }

    /// Explicitly fetch all autonomous (sole) items.
    var autonomousItems: [ContainerItem] {
        items.filter { !$0.isSpace && $0.parentID == nil }
    }

    /// Explicitly fetch all spaces.
    var spaces: [ContainerItem] {
        items.filter { $0.isSpace }
    }
}

