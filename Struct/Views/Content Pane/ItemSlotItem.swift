//
//  ItemSlotItem.swift
//  Struct
//
//  Created by Otto Kiefer on 14.06.2026.
//

import SwiftUI
import SwiftData

// MARK: - Item Slot Item

/// Display slot for items list: either a real item or the animated drop-zone gap
/// shown during a drag operation.
///
/// This enum is used by ContainerFocusListView to manage the items list
/// during drag-and-drop operations, inserting a gap at the drop position
/// to create the "push-aside" animation effect.
enum ItemSlotItem: Identifiable, Equatable {
    case item(Item)
    case gap
    
    var id: AnyHashable {
        switch self {
        case .item(let item): AnyHashable(item.persistentModelID)
        case .gap:          AnyHashable("item-gap")
        }
    }
    
    static func == (lhs: ItemSlotItem, rhs: ItemSlotItem) -> Bool {
        lhs.id == rhs.id
    }
}