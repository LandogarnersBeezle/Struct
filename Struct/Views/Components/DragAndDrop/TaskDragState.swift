//
//  TaskDragState.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI
import SwiftData

// MARK: - Task Drop Target

/// Represents a valid drop target for a task.
enum TaskDropTarget: Equatable, Hashable {
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
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .directItems(let containerTarget, let isScheduled):
            hasher.combine(0)
            hasher.combine(containerTarget)
            hasher.combine(isScheduled)
        case .taskSection(let section):
            hasher.combine(1)
            hasher.combine(section.persistentModelID)
        }
    }
    
    /// A unique string key for this drop target.
    var key: String {
        switch self {
        case .directItems(let containerTarget, let isScheduled):
            switch containerTarget {
            case .space(let space): return "directItems:space:\(space.persistentModelID):\(isScheduled)"
            case .list(let list): return "directItems:list:\(list.persistentModelID):\(isScheduled)"
            case .project(let project): return "directItems:project:\(project.persistentModelID):\(isScheduled)"
            }
        case .taskSection(let section):
            return "taskSection:\(section.persistentModelID)"
        }
    }
    
    /// Whether this target accepts scheduled tasks.
    var acceptsScheduledTasks: Bool {
        switch self {
        case .directItems(_, let isScheduled):
            return isScheduled
        case .taskSection:
            // Task sections can contain both scheduled and unscheduled tasks
            return true
        }
    }
    
    /// Whether this target accepts unscheduled tasks.
    var acceptsUnscheduledTasks: Bool {
        switch self {
        case .directItems(_, let isScheduled):
            return !isScheduled
        case .taskSection:
            // Task sections can contain both scheduled and unscheduled tasks
            return true
        }
    }
}

// MARK: - Task Drop Slot

/// Represents a slot in the drop target list - either a valid drop target or a gap.
enum TaskDropSlot: Identifiable, Hashable {
    case target(TaskDropTarget, ItemRowInfo)
    case gap(TaskDropTarget, ItemRowInfo)
    
    var id: String {
        switch self {
        case .target(let target, _): return "target:\(target)"
        case .gap(let target, _): return "gap:\(target)"
        }
    }
    
    var dropTarget: TaskDropTarget? {
        switch self {
        case .target(let target, _): return target
        case .gap(let target, _): return target
        }
    }
    
    var itemRowInfo: ItemRowInfo {
        switch self {
        case .target(_, let info): return info
        case .gap(_, let info): return info
        }
    }
    
    var isGap: Bool {
        if case .gap = self { return true }
        return false
    }
}

// MARK: - Item Row Information

/// Information about a task row's position and dimensions.
struct ItemRowInfo: Equatable, Hashable {
    let itemID: PersistentIdentifier?
    let frame: CGRect
    let dropTarget: TaskDropTarget
    
    var id: String {
        if let itemID = itemID {
            return String(describing: itemID)
        }
        return dropTarget.key
    }
}

// MARK: - Task Drag State

/// Observable drag state for task drag-and-drop operations in the detail view.
///
/// Owned as `@State` in `ContainerFocusListView` and injected into the view
/// hierarchy via `.environment(drag)`.
@Observable
final class TaskDragState {
    
    // MARK: - State
    
    /// The item currently being dragged; `nil` when idle.
    var dragging: Item? = nil
    
    /// Current finger position in the content coordinate space
    var location: CGPoint = .zero
    
    /// Every item row's frame in the content coordinate space, reported via preference keys.
    var rowFrames: [PersistentIdentifier: CGRect] = [:]
    
    /// All available drop targets with their frames.
    var dropTargets: [TaskDropTarget: ItemRowInfo] = [:]
    
    /// `true` from the moment a long-press fires until the gesture ends.
    var longPressActive: Bool = false
    
    /// Origin of the viewport in `.global` (window) coordinates.
    var viewportOriginInWindow: CGPoint = .zero
    
    /// Current vertical scroll offset, updated during auto-scroll.
    var scrollOffset: CGFloat = 0
    
    /// Height of the currently dragged card (used for drop gap sizing).
    var cardHeight: CGFloat = 48
    
    /// The current drop target, if any.
    var target: TaskDropTarget? = nil
    
    /// The index within the slots array where the gap should be inserted.
    var gapInsertionIndex: Int = -1
    
    var isDragging: Bool { dragging != nil }
    
    // MARK: - Floating Card State
    
    /// Keeps the floating card alive through its fade-out after a drop.
    private(set) var floatingCardItem: PersistentIdentifier? = nil
    
    /// `true` during the same synchronous execution as `end()`, then reset.
    var justEndedDrag = false
    
    // MARK: - Auto-Scroll State
    
    /// The scroll action to perform during drag.
    var autoScrollDelta: CGFloat = 0
    
    // MARK: - Computed Slots
    
    /// The list of slots to display, including the gap at the appropriate position.
    var slots: [TaskDropSlot] {
        guard isDragging, let dragging = dragging else {
            return dropTargets.map { .target($0.key, $0.value) }.sorted { $0.itemRowInfo.frame.minY < $1.itemRowInfo.frame.minY }
        }
        
        var result: [TaskDropSlot] = []
        let draggingIsScheduled = dragging.doDate != nil
        
        // Get all valid targets for this drag item
        let validTargets = dropTargets.filter { target, _ in
            if draggingIsScheduled {
                return target.acceptsScheduledTasks
            } else {
                return target.acceptsUnscheduledTasks
            }
        }
        
        // Convert to slots
        for (target, info) in validTargets {
            // Skip the dragged item's original position
            if info.itemID == dragging.persistentModelID {
                continue
            }
            result.append(.target(target, info))
        }
        
        // Sort by vertical position
        result.sort { $0.itemRowInfo.frame.minY < $1.itemRowInfo.frame.minY }
        
        // Insert gap at the appropriate position
        if gapInsertionIndex >= 0 && gapInsertionIndex <= result.count, let currentTarget = target {
            result.insert(.gap(currentTarget, makeGapRowInfo(for: currentTarget)), at: gapInsertionIndex)
        }
        
        return result
    }
    
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
        
        // Set initial gap position to current position (in-place reorder)
        updateGapInsertionIndex()
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
            gapInsertionIndex = -1
        }
        justEndedDrag = false
    }
    
    // MARK: - Target Computation
    
    /// Updates the drop target and gap insertion index based on current location.
    func updateTarget() {
        guard isDragging, let dragging = dragging else { return }
        
        let y = location.y
        let draggingIsScheduled = dragging.doDate != nil
        
        struct Candidate {
            let target: TaskDropTarget
            let info: ItemRowInfo
            let dist: CGFloat
        }
        
        var best: Candidate?
        
        for (dropTarget, info) in dropTargets {
            // Skip if not compatible with dragged item type
            if draggingIsScheduled && !dropTarget.acceptsScheduledTasks { continue }
            if !draggingIsScheduled && !dropTarget.acceptsUnscheduledTasks { continue }
            
            // Check if the drag position is within or near this target's frame
            let frame = info.frame
            let midY = frame.midY
            let dist = abs(y - midY)
            
            // Consider this target if it's the closest so far
            if best == nil || dist < best!.dist {
                best = Candidate(target: dropTarget, info: info, dist: dist)
            }
        }
        
        if let candidate = best {
            target = candidate.target
            updateGapInsertionIndex()
        } else {
            target = nil
            gapInsertionIndex = -1
        }
    }
    
    private func updateGapInsertionIndex() {
        guard let target = target else {
            gapInsertionIndex = -1
            return
        }
        
        // Find the index of the target in the sorted slots list
        let sortedTargets = dropTargets.keys.sorted { target1, target2 in
            guard let info1 = dropTargets[target1], let info2 = dropTargets[target2] else { return false }
            return info1.frame.minY < info2.frame.minY
        }
        
        if let index = sortedTargets.firstIndex(of: target) {
            gapInsertionIndex = index
        }
    }
    
    private func makeGapRowInfo(for dropTarget: TaskDropTarget) -> ItemRowInfo {
        // Use the frame of the target for the gap
        if let info = dropTargets[dropTarget] {
            return info
        }
        // Fallback: create a default frame at the drag location
        return ItemRowInfo(
            itemID: nil,
            frame: CGRect(x: 0, y: location.y - cardHeight / 2, width: 300, height: cardHeight),
            dropTarget: dropTarget
        )
    }
}

// MARK: - Preference Keys

/// Preference key for item row frames in the content coordinate space.
struct TaskRowFrameKey: PreferenceKey {
    typealias Value = [PersistentIdentifier: CGRect]
    static var defaultValue: Value = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Preference key for drop target frames.
struct TaskDropTargetFrameKey: PreferenceKey {
    typealias Value = [String: ItemRowInfo]
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

// MARK: - Row Frame Anchor

/// A view that reports its row frame via preference key.
struct TaskRowFrameAnchor: View {
    let itemID: PersistentIdentifier
    var dragState: TaskDragState
    
    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .named("ScrollView"))
            Color.clear
                .preference(key: TaskRowFrameKey.self, value: [itemID: frame])
                .onChange(of: frame.height, initial: true) { _, h in
                    if !dragState.isDragging {
                        dragState.cardHeight = h
                    }
                }
        }
    }
}

// MARK: - Drop Target Anchor

/// A view that reports a drop target's frame via preference key.
struct TaskDropTargetAnchor: View {
    let targetKey: String
    let dropTarget: TaskDropTarget
    let itemID: PersistentIdentifier?
    var dragState: TaskDragState
    
    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .named("ScrollView"))
            let info = ItemRowInfo(itemID: itemID, frame: frame, dropTarget: dropTarget)
            Color.clear
                .preference(key: TaskDropTargetFrameKey.self, value: [targetKey: info])
        }
    }
}