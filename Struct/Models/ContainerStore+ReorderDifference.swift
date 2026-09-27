//
//  ContainerStore+ReorderDifference.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import SwiftUI

/// Bridges the reorder modifier to the store.
///
/// This is the only place where the reordering rules meet the user interface
/// framework: the store itself stays framework-free, so the presentation layer
/// can change without touching the model.
extension ContainerStore {
    /// Applies the change that `reorderContainer(for:move:)` reports.
    func apply(_ difference: ReorderDifference<ContainerItem.ID, ReorderableSingleCollectionIdentifier>) {
        switch difference.destination.position {
        case .before(let id):
            move(difference.sources, to: items.index(of: id) ?? items.count)
        case .end:
            move(difference.sources, to: items.count)
        }
    }
}
