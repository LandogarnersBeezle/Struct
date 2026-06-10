//
//  SpaceSlotItem.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI
import SwiftData

// MARK: - Space Slot Item

/// Display slot for the spaces list: either a real space section or the
/// animated drop-zone gap shown during a space drag.
///
/// This enum is used by ContainersSidebarView to manage the space list
/// during drag-and-drop operations, inserting a gap at the drop position
/// to create the "push-aside" animation effect.
enum SpaceSlotItem: Identifiable, Equatable {
    case space(Space)
    case gap

    var id: AnyHashable {
        switch self {
        case .space(let s): AnyHashable(s.persistentModelID)
        case .gap:          AnyHashable("space-gap")
        }
    }

    static func == (lhs: SpaceSlotItem, rhs: SpaceSlotItem) -> Bool {
        lhs.id == rhs.id
    }
}
