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
/// Every mutation funnels through `move(_:to:)`, so replacing this in-memory
/// array with persisted models later only touches this type.
@Observable
final class ContainerStore {
    var items: [ContainerItem]

    init(items: [ContainerItem] = SampleContainers.all) {
        self.items = items
    }

    /// Moves the containers identified by `ids` – together with the children of
    /// any space among them – so that they end up before `destinationIndex`.
    func move(_ ids: [ContainerItem.ID], to destinationIndex: Int) {
        items = ContainerMove.resolve(items, moving: ids, destinationIndex: destinationIndex)
    }

    /// Everything that travels when `id` is dragged.
    func travellingIdentifiers(for id: ContainerItem.ID) -> [ContainerItem.ID] {
        ContainerMove.travellingIdentifiers(for: id, in: items)
    }
}
