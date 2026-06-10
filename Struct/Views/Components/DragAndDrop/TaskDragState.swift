//
//  TaskDragState.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI
import SwiftData

// MARK: - Task Drop Target (Container-Level)

/// Represents a valid drop target for a task at the container level.
enum TaskDropTarget: Equatable {
    /// Drop into a container's direct items (unscheduled or scheduled section)
    case directItems(containerTarget: ContainerTarget, isScheduled: Bool)
    /// Drop into a task section
    case taskSection(section: TaskSection)
    
    static func == (lhs: TaskDropTarget, rhs: TaskDropTarget) -> Bool {
        switch (lhs, rhs) {
        case (.directItems(let l1, let s1), .directItems(let l2, let s2)):
            return l1 == l2 && s1 == s2
        case (.taskSection(let s1), .taskSection(let s2)):
            return s1.persistentModelID == s2.persistentModelID
        default:
            return false
        }
    }
    
    /// The container target that owns this drop target.
    var containerTarget: ContainerTarget {
        switch self {
        case .directItems(let containerTarget, _):
            return containerTarget
        case .taskSection(let section):
            if let space = section.space { return .space(space) }
            if let list = section.list { return .list(list) }
            if let project = section.project { return .project(project) }
            fatalError("TaskSection must have a parent container")
        }
    }
    
    /// Whether this target accepts scheduled tasks.
    var acceptsScheduledTasks: Bool {
        switch self {
        case .directItems(_, let isScheduled):
            return isScheduled
        case .taskSection(let section):
            // Task sections can contain both scheduled and unscheduled tasks
            return true
        }
    }
    
    /// Whether this target accepts unscheduled tasks.
    var acceptsUnscheduledTasks: Bool {
        switch self {
        case .directItems(_, let isScheduled):
            return !isScheduled
        case .taskSection(let section):
            // Task sections can contain both scheduled and unscheduled tasks
            return true
        }
    }
}

// MARK: - Task Drag State

/// Observable drag state for task drag-and-drop operations in the detail view.
///
/// Owned as `@State` in `ContainerFocusListView` and injected into the view
/// hierarchy via `.environment(taskDrag)`.
@Observable
final class TaskDragState {
    
    // MARK: - State
    
    /// The item currently being dragged; `nil` when idle.
    var dragging: Item? = nil
    
    /// Current finger position in the content coordinate space
    var location: CGPoint = .zero
    
    /// Every container/section area's frame in the content coordinate space, reported via preference keys.
    var containerFrames: [String: CGRect] = [:]
    
    /// `true` from the moment a long-press fires until the gesture ends.
    var longPressActive: Bool = false
    
    /// Origin of the viewport in `.global` (window) coordinates.
    var viewportOriginInWindow: CGPoint = .zero
    
    /// Current vertical scroll offset, updated during auto-scroll.
    var scrollOffset: CGFloat = 0
    
    /// Height of the currently dragged card (used for drop gap sizing).
    var cardHeight: CGFloat = 44
    
    /// The current drop target, if any.
    var target: TaskDropTarget? = nil
    
    var isDragging: Bool { dragging != nil }
    
    // MARK: - Floating Card State
    
    /// Keeps the floating card alive through its fade-out after a drop.
    private(set) var floatingCardItem: PersistentIdentifier? = nil
    
    /// `true` during the same synchronous execution as `end()`, then reset.
    var justEndedDrag = false
    
    // MARK: - Auto-Scroll State
    
    /// The scroll action to perform during drag.
    var autoScrollDelta: CGFloat = 0
    
    // MARK: - Coordinate Conversion
    
    /// Converts a point in window coordinates into the content coordinate space.
    func toContent(_ windowPoint: CGPoint) -> CGPoint {
        CGPoint(x: windowPoint.x - viewportOriginInWindow.x,
                y: windowPoint.y - viewportOriginInWindow.y)
    }
    
    // MARK: - Lifecycle
    
    /// Begins a drag operation.
    func begin(item: Item, at point: CGPoint, height: CGFloat) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dragging = item
        floatingCardItem = item.persistentModelID
        location = point
        cardHeight = height
    }
    
    /// Ends the drag operation with fade-out animation.
    func end() {
        longPressActive = false
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            dragging = nil
        }
        justEndedDrag = true
        DispatchQueue.main.async { [weak self] in
            withAnimation(.easeOut(duration: 0.18)) {
                self?.floatingCardItem = nil
            }
            self?.justEndedDrag = false
        }
    }
    
    /// Immediately resets all drag state without animation.
    func reset() {
        longPressActive = false
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            dragging = nil
            floatingCardItem = nil
            target = nil
        }
        justEndedDrag = false
    }
    
    // MARK: - Target Computation
    
    /// Computes the drop target based on current location and available container frames.
    /// - Parameters:
    ///   - draggingItemID: The ID of the item being dragged
    /// - Returns: The computed drop target, or nil if no valid target
    func computeTarget(draggingItemID: PersistentIdentifier) -> TaskDropTarget? {
        let y = location.y
        
        // Find the container/section whose frame contains the drag location
        var bestTarget: (target: TaskDropTarget, dist: CGFloat)? = nil
        
        for (key, frame) in containerFrames {
            // Skip if the frame doesn't contain the y position
            guard frame.minY <= y && y <= frame.maxY else { continue }
            
            // Parse the key to get the target
            guard let dropTarget = parseTargetKey(key) else { continue }
            
            // Validate that this target is appropriate for the dragged item
            let draggingIsScheduled = dragging?.doDate != nil
            if draggingIsScheduled && !dropTarget.acceptsScheduledTasks {
                continue
            }
            if !draggingIsScheduled && !dropTarget.acceptsUnscheduledTasks {
                continue
            }
            
            // Compute distance from center of frame
            let dist = abs(y - frame.midY)
            
            if bestTarget == nil || dist < bestTarget!.dist {
                bestTarget = (target: dropTarget, dist: dist)
            }
        }
        
        return bestTarget?.target
    }
    
    /// Parses a target key string into a TaskDropTarget.
    /// Key format: "directItems:containerType:containerID:isScheduled" or "taskSection:sectionID"
    private func parseTargetKey(_ key: String) -> TaskDropTarget? {
        let parts = key.split(separator: ":")
        guard parts.count >= 2 else { return nil }
        
        if parts[0] == "directItems" && parts.count == 4 {
            let containerType = String(parts[1])
            let containerID = String(parts[2])
            let isScheduled = parts[3] == "true"
            
            // We need to resolve the container from the context
            // This will be done by the caller who has access to the model context
            // For now, return nil - the actual resolution happens in ContainerFocusListView
            return nil
        } else if parts[0] == "taskSection" && parts.count == 2 {
            // Task section resolution also needs context
            return nil
        }
        
        return nil
    }
}

// MARK: - Preference Keys

/// Preference key for container/section frames in the content coordinate space.
struct TaskContainerFrameKey: PreferenceKey {
    typealias Value = [String: CGRect]
    static var defaultValue: Value = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Preference key for content viewport origin in window coordinates.
struct TaskContentOriginKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

// MARK: - Container Frame Tracker

/// A view that reports its container/section frame via preference key.
struct TaskContainerFrameAnchor: View {
    let targetKey: String
    var dragState: TaskDragState
    
    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .named("ScrollView"))
            Color.clear
                .preference(key: TaskContainerFrameKey.self, value: [targetKey: frame])
        }
    }
}