//
//  ContainerStore.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import Foundation
import Observation
import SwiftData

/// Owns the ordered containers, interfaces with SwiftData `ModelContext`, and applies reordering operations.
///
/// In the hybrid architecture, items maintain explicit `parentID` and `sortOrder`.
/// `items` holds the canonical projected display sequence for the UI list.
@Observable
final class ContainerStore {
    private var modelContext: ModelContext?
    var items: [ContainerItem] = []

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        if modelContext != nil {
            reload()
        }
    }

    /// Connects or updates the model context and reloads the items.
    func configure(with modelContext: ModelContext) {
        guard self.modelContext !== modelContext else { return }
        self.modelContext = modelContext
        reload()
    }

    /// Fetches all containers from the context, projected into canonical visual order.
    func reload() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<ContainerItem>()
        do {
            let fetched = try modelContext.fetch(descriptor)
            items = ContainerMove.projectSorted(fetched)
        } catch {
            print("Failed to fetch containers: \(error)")
        }
    }

    /// Moves the containers identified by `ids` – together with the explicit children
    /// of any space among them – so that they end up placed directly before `destinationID`.
    /// If `destinationID` is `nil`, they are placed at the end of the list.
    func move(_ ids: [ContainerItem.ID], before destinationID: ContainerItem.ID?) {
        items = ContainerMove.resolve(items, moving: ids, before: destinationID)
        saveChanges()
    }

    /// Moves the containers identified by `ids` – together with the explicit children
    /// of any space among them – so that they end up before `destinationIndex`.
    func move(_ ids: [ContainerItem.ID], to destinationIndex: Int) {
        let destinationID = items.indices.contains(destinationIndex) ? items[destinationIndex].id : nil
        move(ids, before: destinationID)
    }

    /// Toggles the expansion state of a space and persists the change.
    func toggleExpansion(for spaceID: ContainerItem.ID) {
        guard let space = items.first(where: { $0.id == spaceID && $0.isSpace }) else { return }
        space.isExpanded.toggle()
        saveChanges()
    }

    /// Returns the items the list renders, in display order.
    ///
    /// Lists and projects appear only while the space that owns them is expanded.
    ///
    /// This decides which rows *exist* in the list, so it must never run while a
    /// reorder drag is in flight: a drag session works against the rows it
    /// started with, and removing rows underneath it desynchronises the
    /// placeholder and the drop — the list then crashes with "attempt to move
    /// index path". The chevron is therefore the only thing that drives this,
    /// because it cannot be reached during a drag.
    func visibleItems() -> [ContainerItem] {
        // Build a lookup of expanded spaces
        let expandedSpaceIDs = Set(items.filter { $0.isSpace && $0.isExpanded }.map(\.id))

        return items.filter { item in
            if item.isSpace || item.parentID == nil {
                return true
            }
            // Child item: visible only if its parent space is expanded
            if let parentID = item.parentID {
                return expandedSpaceIDs.contains(parentID)
            }
            return true
        }
    }

    /// Seeds sample containers into SwiftData if none exist or when requested.
    /// Guarded against duplicates: does nothing if sample data is already present.
    func seedSampleContainers() {
        guard let modelContext, !hasSampleData else { return }
        let samples = SampleContainers.createSamples()
        for sample in samples {
            modelContext.insert(sample)
        }
        saveChanges()
        reload()
    }

    /// Deletes all containers flagged as `isSample == true` in one step.
    func deleteSampleContainers() {
        guard let modelContext else { return }
        do {
            try modelContext.delete(model: ContainerItem.self, where: #Predicate { $0.isSample })
            saveChanges()
            reload()
        } catch {
            print("Failed to delete sample containers: \(error)")
        }
    }

    /// Whether any containers in the current list are marked as sample items.
    var hasSampleData: Bool {
        items.contains(where: \.isSample)
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

    private func saveChanges() {
        guard let modelContext else { return }
        do {
            try modelContext.save()
        } catch {
            print("Failed to save ModelContext: \(error)")
        }
    }
}


