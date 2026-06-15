//
//  ItemDragState.swift
//  Struct
//
//  Created by Otto Kiefer on 14.06.2026.
//

import SwiftUI
import SwiftData

// MARK: - Item Group Context

/// Identifies the specific unscheduled group context for drag operations.
/// This ensures items can only be reordered within their originating group.
enum ItemGroupContext: Equatable, Hashable {
    /// Direct unscheduled items in a container (not in a section)
    case directUnscheduled(ContainerTarget)
    /// Direct unscheduled items in a child container (List/Project within a Space)
    case childContainerUnscheduled(ContainerChild)
    /// Unscheduled items within a specific TaskSection
    case sectionUnscheduled(TaskSection)
    
    static func == (lhs: ItemGroupContext, rhs: ItemGroupContext) -> Bool {
        switch (lhs, rhs) {
        case (.directUnscheduled(let a), .directUnscheduled(let b)):
            // Compare ContainerTarget by extracting the underlying persistent model ID
            let idA: PersistentIdentifier
            let idB: PersistentIdentifier
            switch a {
            case .space(let s): idA = s.persistentModelID
            case .project(let p): idA = p.persistentModelID
            case .list(let l): idA = l.persistentModelID
            }
            switch b {
            case .space(let s): idB = s.persistentModelID
            case .project(let p): idB = p.persistentModelID
            case .list(let l): idB = l.persistentModelID
            }
            return idA == idB
        case (.childContainerUnscheduled(let a), .childContainerUnscheduled(let b)):
            return a.id == b.id
        case (.sectionUnscheduled(let a), .sectionUnscheduled(let b)):
            return a.persistentModelID == b.persistentModelID
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .directUnscheduled(let target):
            hasher.combine(0)
            switch target {
            case .space(let s): hasher.combine(s.persistentModelID)
            case .project(let p): hasher.combine(p.persistentModelID)
            case .list(let l): hasher.combine(l.persistentModelID)
            }
        case .childContainerUnscheduled(let child):
            hasher.combine(1)
            hasher.combine(child.id)
        case .sectionUnscheduled(let section):
            hasher.combine(2)
            hasher.combine(section.persistentModelID)
        }
    }
}

// MARK: - Item Drag State

/// Observable drag state for item reordering within the detail view.
///
/// Owned as `@State` in `ContainerFocusListView` and injected into the view
/// hierarchy via `.environment(itemDragState)`. Item rows read it with
/// `@Environment(ItemDragState.self)`.
@Observable
final class ItemDragState {
    
    // MARK: - State
    
    /// The item currently being dragged; `nil` when idle.
    var draggingItem: Item? = nil
    
    /// The group context this drag operation is confined to.
    var groupContext: ItemGroupContext? = nil
    
    /// Current finger position in window coordinates.
    var location: CGPoint = .zero
    
    /// Every row's frame in the content view coordinate space, reported via `ItemRowFrameKey`.
    var rowFrames: [Item.ID: CGRect] = [:]
    
    /// The calculated insertion index within the current group.
    var targetIndex: Int = 0
    
    /// Height of the floating drag row.
    var rowHeight: CGFloat = 44
    
    /// `true` if a drag operation is in progress.
    var isDragging: Bool { draggingItem != nil }
    
    /// `true` from the moment a long-press fires until the gesture ends.
    var longPressActive: Bool = false
    
    /// Origin of the content view in `.global` (window) coordinates.
    var contentOriginInWindow: CGPoint = .zero
    
    /// Keeps the floating row alive through its fade-out after a drop.
    private(set) var floatingItem: Item? = nil
    
    /// The item that was being dragged when the drag ended (preserved for reordering).
    private(set) var itemAtEnd: Item? = nil
    
    /// The target index when the drag ended (preserved for reordering).
    private(set) var targetIndexAtEnd: Int = 0
    
    /// The group context when the drag ended (preserved for reordering).
    private(set) var groupContextAtEnd: ItemGroupContext? = nil
    
    /// `true` from the moment `endDrag()` fires until the next run loop turn.
    /// Prevents tap gestures from firing immediately after a drag ends.
    private(set) var justEndedDrag = false
    
    /// Current vertical scroll offset, updated during auto-scroll.
    var scrollOffset: CGFloat = 0
    
    // MARK: - Smooth Drag Visual State
    
    /// Current scale factor for the dragged row (1.0 = normal, 1.05 = lifted)
    var dragScale: CGFloat = 1.0
    
    /// Current opacity for the dragged row (1.0 = normal, 0.85 = lifted)
    var dragOpacity: CGFloat = 1.0
    
    // MARK: - Coordinate Conversion
    
    /// Converts a window-coordinate point to content view coordinates.
    func toContentView(_ windowPoint: CGPoint) -> CGPoint {
        CGPoint(x: windowPoint.x - contentOriginInWindow.x,
                y: windowPoint.y - contentOriginInWindow.y)
    }
    
    // MARK: - Lifecycle
    
    /// Begins a drag operation for an item within a specific group context.
    /// - Parameters:
    ///   - item: The item being dragged
    ///   - context: The group context constraining this drag operation
    ///   - point: Initial finger position in window coordinates
    ///   - height: The row height for the floating overlay
    func beginDrag(item: Item, context: ItemGroupContext, at point: CGPoint, height: CGFloat) {
        // Full reset of all state
        reset()
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        draggingItem = item
        groupContext = context
        floatingItem = item
        location = point
        rowHeight = height
        
        // Animate lift effect
        withAnimation(.spring(duration: 0.15, bounce: 0)) {
            dragScale = 1.05
            dragOpacity = 0.85
        }
    }
    
    /// Updates the finger position and calculates the drop target.
    /// - Parameters:
    ///   - point: New finger position in window coordinates
    ///   - unscheduledItems: The unscheduled items in the current group (excluding the dragged item)
    func updateDragPosition(_ point: CGPoint, among unscheduledItems: [Item]) {
        location = point
        updateTargetIndex(among: unscheduledItems)
    }
    
    /// Updates the target insertion index based on current position.
    /// - Parameter unscheduledItems: The unscheduled items in the current group (excluding the dragged item)
    func updateTargetIndex(among unscheduledItems: [Item]) {
        guard let context = groupContext else { return }
        
        let contentLocation = toContentView(location)
        let y = contentLocation.y
        
        // Find the closest row midpoint
        struct Candidate {
            let index: Int
            let dist: CGFloat
        }
        
        var best: Candidate?
        
        func consider(_ candidate: Candidate) {
            if best == nil || candidate.dist < best!.dist {
                best = candidate
            }
        }
        
        for (i, item) in unscheduledItems.enumerated() {
            guard let frame = rowFrames[item.id] else { continue }
            let midY = frame.midY
            let insertIndex = y < midY ? i : i + 1
            consider(Candidate(index: insertIndex, dist: abs(midY - y)))
        }
        
        // Also consider the position after the last item
        if let lastFrame = unscheduledItems.compactMap({ rowFrames[$0.id] }).last {
            consider(Candidate(index: unscheduledItems.count, dist: abs(lastFrame.maxY - y)))
        }
        
        // Update target index (no animation for the index change itself - the gap movement is animated by SwiftUI)
        targetIndex = best?.index ?? 0
    }
    
    /// Ends the drag operation with smooth drop animation.
    func endDrag() {
        longPressActive = false
        
        // First phase: quick scale down with bounce
        withAnimation(.spring(duration: 0.1, bounce: 0.3)) {
            dragScale = 0.95
            dragOpacity = 1.0
        }
        
        // Clear the floating item after a short delay to allow the drop animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.floatingItem = nil
        }
        
        // Prevent taps from firing immediately after a drag ends
        justEndedDrag = true
        DispatchQueue.main.async { [weak self] in
            self?.justEndedDrag = false
        }
        
        // Clear dragging state after animations
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            draggingItem = nil
            groupContext = nil
        }
    }
    
    /// Cancels the drag operation and resets visual state.
    func cancelDrag() {
        withAnimation(.spring(duration: 0.2, bounce: 0)) {
            dragScale = 1.0
            dragOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.floatingItem = nil
            self?.draggingItem = nil
            self?.groupContext = nil
        }
    }
    
    /// Immediately resets all state without animation.
    func reset() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            draggingItem = nil
            groupContext = nil
            floatingItem = nil
            itemAtEnd = nil
            targetIndexAtEnd = 0
            dragScale = 1.0
            dragOpacity = 1.0
        }
    }
    
    /// Clears the end-drag state after reordering is complete.
    func clearEndState() {
        itemAtEnd = nil
        targetIndexAtEnd = 0
        groupContextAtEnd = nil
    }
    
    /// Captures the drag state for reordering before clearing.
    private(set) var capturedDragItem: Item? = nil
    private(set) var capturedDragContext: ItemGroupContext? = nil
    private(set) var capturedDragTargetIndex: Int = 0
    
    /// Set to true when drag ends and state is captured for reordering.
    /// The parent view should observe this and call commitReorder(), which clears this flag.
    private(set) var needsReorder = false
    
    /// Called from the gesture's onDragEnded. Captures state and triggers reorder.
    func endDragAndCommit() {
        guard draggingItem != nil, groupContext != nil else {
            endDrag()
            return
        }
        
        // Capture state before clearing
        capturedDragItem = draggingItem
        capturedDragContext = groupContext
        capturedDragTargetIndex = targetIndex
        
        // Signal that reorder is needed
        needsReorder = true
        
        // End the drag (animates and clears draggingItem/groupContext)
        endDrag()
    }
    
    /// Called by the parent view to clear the needsReorder flag after committing.
    func clearNeedsReorder() {
        needsReorder = false
        capturedDragItem = nil
        capturedDragContext = nil
        capturedDragTargetIndex = 0
    }
}

// MARK: - Preference Keys

/// Preference key for item row frames in the content view.
struct ItemRowFrameKey: PreferenceKey {
    typealias Value = [Item.ID: CGRect]
    static var defaultValue: Value = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Preference key for content view viewport origin in window coordinates.
struct ItemContentOriginKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}