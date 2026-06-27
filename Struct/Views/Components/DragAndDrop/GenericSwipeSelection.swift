//
//  GenericSwipeSelection.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI
import SwiftData

// MARK: - Generic Swipe Selection

/// Generic observable swipe selection state.
///
/// This class provides a reusable foundation for swipe-to-select functionality
/// that can be used across different views (sidebar, focus view, etc.).
/// When active is non-nil, the view typically shows a delete or action button.
@Observable
class GenericSwipeSelection<Item: Hashable> {
    var active: Item? = nil

    /// true during the run-loop cycle in which a swipe fired.
    private(set) var justTriggered = false

    func clear() { active = nil }

    /// Sets justTriggered for one main-queue cycle, then resets it.
    func markTriggered() {
        justTriggered = true
        DispatchQueue.main.async { [weak self] in self?.justTriggered = false }
    }

    /// Returns true when item refers to the same object as active.
    func matches(_ item: Item) -> Bool {
        guard let active else { return false }
        return active == item
    }

    /// Swipe-trigger semantics: tapping an already-active item clears it,
    /// otherwise it becomes the new selection.
    func toggle(_ item: Item) {
        if matches(item) { clear() }
        else { active = item }
        markTriggered()
    }
}

// MARK: - Sidebar-Specific Type Alias

/// Sidebar-specific swipe selection for container kinds.
typealias SidebarSwipeSelection = GenericSwipeSelection<SwipeableContainerKind>

// MARK: - Swipeable Container Kind

/// Identifies which model object a swipe gesture has targeted.
enum SwipeableContainerKind: Hashable {
    case list(List)
    case project(Project)
    case space(Space)

    static func == (lhs: SwipeableContainerKind, rhs: SwipeableContainerKind) -> Bool {
        switch (lhs, rhs) {
        case (.list(let a), .list(let b)): return a.persistentModelID == b.persistentModelID
        case (.project(let a), .project(let b)): return a.persistentModelID == b.persistentModelID
        case (.space(let a), .space(let b)): return a.persistentModelID == b.persistentModelID
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .list(let l): hasher.combine(l.persistentModelID)
        case .project(let p): hasher.combine(p.persistentModelID)
        case .space(let s): hasher.combine(s.persistentModelID)
        }
    }
}

// MARK: - Container Child Extension

extension GenericSwipeSelection where Item == SwipeableContainerKind {
    /// Returns true when the active selection matches the given container child.
    func matches(_ child: ContainerChild) -> Bool {
        guard let active else { return false }
        switch (active, child) {
        case (.list(let a), .list(let b)): return a.persistentModelID == b.persistentModelID
        case (.project(let a), .project(let b)): return a.persistentModelID == b.persistentModelID
        default: return false
        }
    }

    /// Returns true when the active selection matches the given space.
    func matches(_ space: Space) -> Bool {
        guard let active else { return false }
        switch active {
        case .space(let s): return s.persistentModelID == space.persistentModelID
        default: return false
        }
    }
}
// MARK: - Sidebar Collapse State

/// Shared observable state that tracks whether the sidebar is in "reorder mode"
/// (i.e., a space header is being long-pressed for reordering).
/// When active, all space sections collapse their children.
@Observable
class SidebarCollapseState {
    static let shared = SidebarCollapseState()
    
    /// The space currently being dragged for reordering, or nil if not dragging.
    var draggingSpace: Space? = nil
    
    /// Returns true when any space is being dragged.
    var isCollapsing: Bool {
        draggingSpace != nil
    }
    
    private init() {}
}


// MARK: - Delete Alert State

/// Shared state for the delete alert, accessible from both the button and the alert overlay.
@Observable
final class DeleteAlertState {
    static let shared = DeleteAlertState()

    var showAlert = false
    var hasOpenTasks = false

    private init() {}
}