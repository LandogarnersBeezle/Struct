//
//  SpaceReorderDropDelegate.swift
//  Struct
//
//  Created by Otto Kiefer on 27.06.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Space Frame Preference Key

/// Collects the frame of each space header in the sidebar's coordinate
/// space, keyed by the space's persistent model ID.
struct SpaceFrame: Equatable {
    let id: PersistentIdentifier
    let rect: CGRect
}

struct SpaceFramePreferenceKey: PreferenceKey {
    static let defaultValue: [SpaceFrame] = []
    
    static func reduce(value: inout [SpaceFrame], nextValue: () -> [SpaceFrame]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Space Insertion Line Drop Delegate

/// Drop delegate for reordering spaces in the sidebar.
/// Tracks the insertion line position and performs the reorder on drop.
struct SpaceInsertionLineDropDelegate: DropDelegate {
    
    let spaces: [Space]
    let spaceFrames: [PersistentIdentifier: CGRect]
    
    /// The Y position (in the sidebar's coordinate space) where the green
    /// insertion line should be drawn, or `nil` when the drag is inactive.
    @Binding var insertionLineY: CGFloat?
    
    /// Called on drop with the decoded drag data and model context for lookup.
    let performDropHandler: (Space) -> Void
    
    // MARK: Drop lifecycle
    
    func dropEntered(info: DropInfo) {
        updateLineY(from: info.location)
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateLineY(from: info.location)
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        insertionLineY = nil
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.spaceDrag]).first else {
            DispatchQueue.main.async { insertionLineY = nil }
            return false
        }
        
        provider.loadDataRepresentation(forTypeIdentifier: UTType.spaceDrag.identifier) { data, error in
            guard let data,
                  let dragData = try? JSONDecoder().decode(SpaceDragData.self, from: data) else {
                DispatchQueue.main.async { self.insertionLineY = nil }
                return
            }
            
            DispatchQueue.main.async {
                // Find the space by its persistent model ID from the known spaces array
                guard let space = self.spaces.first(where: { $0.persistentModelID == dragData.spaceID }) else {
                    self.insertionLineY = nil
                    return
                }
                self.performDropHandler(space)
            }
        }
        
        return true
    }
    
    // MARK: Line position
    
    /// Computes the insertion index from the finger location, then derives
    /// the Y position for the green line.
    private func updateLineY(from location: CGPoint) {
        guard !spaces.isEmpty else {
            insertionLineY = nil
            return
        }
        
        // Find the nearest space header to the finger location
        var nearestSpaceIndex: Int?
        var minDistance: CGFloat = 20 // Only show line if within 20 points of a header
        
        for (i, space) in spaces.enumerated() {
            guard let rect = spaceFrames[space.persistentModelID] else { continue }
            
            // Check distance to top edge of this header
            let distanceToTop = abs(location.y - rect.minY)
            if distanceToTop < minDistance {
                minDistance = distanceToTop
                nearestSpaceIndex = i
            }
            
            // Also check distance to bottom edge (for inserting after last space)
            if i == spaces.count - 1 {
                let distanceToBottom = abs(location.y - rect.maxY)
                if distanceToBottom < minDistance {
                    minDistance = distanceToBottom
                    nearestSpaceIndex = i + 1 // Insert after this space
                }
            }
        }
        
        // Only show insertion line if we're near a valid position
        guard let index = nearestSpaceIndex else {
            insertionLineY = nil
            return
        }
        
        // Calculate the Y position for the insertion line
        let yPos: CGFloat
        if index >= spaces.count, let last = spaceFrames[spaces.last!.persistentModelID] {
            // Insert after the last space
            yPos = last.maxY
        } else if let rect = spaceFrames[spaces[index].persistentModelID] {
            // Insert before this space
            yPos = rect.minY
        } else {
            insertionLineY = nil
            return
        }
        
        insertionLineY = yPos
    }
}