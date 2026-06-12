//
//  GenericDragState.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI
import SwiftData

// MARK: - Generic Row Frame Key

/// Generic preference key for row frame reporting.
/// Note: Using a class wrapper to avoid static stored properties in generic types.
struct GenericRowFrameKey<ID: Hashable>: PreferenceKey {
    typealias Value = [ID: CGRect]
    static var defaultValue: Value { [:] }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Generic Drag State

/// Generic observable drag state for drag-and-drop operations.
///
/// This class provides a reusable foundation for drag-and-drop functionality
/// that can be used across different views (sidebar, focus view, etc.).
/// It manages drag state, target computation, and coordinate transformations.
@Observable
class GenericDragState<ItemID: Hashable> {

    // MARK: - State

    /// The item currently being dragged; `nil` when idle.
    var dragging: ItemID? = nil

    /// Current finger position in the named coordinate space
    var location: CGPoint = .zero

    /// Every row's frame in the coordinate space, reported via preference keys.
    /// For SidebarDragState, this is keyed by ContainerChild.ID
    var rowFrames: [AnyHashable: CGRect] = [:]

    /// `true` from the moment a long-press fires until the gesture ends.
    var longPressActive: Bool = false

    /// Origin of the viewport in `.global` (window) coordinates.
    var viewportOriginInWindow: CGPoint = .zero

    /// Current vertical scroll offset, updated during auto-scroll.
    var scrollOffset: CGFloat = 0

    /// Height of the currently dragged card (used for drop gap sizing).
    var cardHeight: CGFloat = 44

    var isDragging: Bool { dragging != nil }

    // MARK: - Floating Card State

    /// Keeps the floating card alive through its fade-out after a drop.
    private(set) var floatingCardItem: ItemID? = nil

    /// `true` during the same synchronous execution as `end()`, then reset.
    var justEndedDrag = false

    // MARK: - Coordinate Conversion

    /// Converts a point in window coordinates into the sidebar coordinate space.
    /// Matches the coordinate space used by the ScrollView's .coordinateSpace(.named("sidebar")).
    func toViewport(_ windowPoint: CGPoint) -> CGPoint {
        CGPoint(x: windowPoint.x - viewportOriginInWindow.x,
                y: windowPoint.y - viewportOriginInWindow.y)
    }

    // MARK: - Lifecycle

    /// Begins a drag operation.
    func begin(item: ItemID, at point: CGPoint, height: CGFloat) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dragging = item
        floatingCardItem = item
        location = point
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
        }
        justEndedDrag = false
    }
}

// MARK: - Sidebar-Specific Drag State

/// Observable drag state for the container sidebar.
///
/// Owned as `@State` in `ContainersSidebarView` and injected into the view
/// hierarchy via `.environment(drag)`. `SpaceSectionView` reads it with
/// `@Environment(SidebarDragState.self)`.
@Observable
final class SidebarDragState {

    // MARK: State

    /// The item currently being dragged; `nil` when idle.
    var dragging: ContainerChild? = nil

    /// Current finger position in the `"sidebar"` named coordinate space
    var location: CGPoint = .zero

    /// Every row's frame in the sidebar coordinate space, reported via `RowFrameKey`.
    var rowFrames: [ContainerChild.ID: CGRect] = [:]

    /// Each space section header's frame, reported via `SpaceHeaderFrameKey`.
    var spaceHeaderFrames: [PersistentIdentifier: CGRect] = [:]

    /// The space that would receive the drop.
    var targetSpaceID: PersistentIdentifier? = nil

    /// Insertion index inside the target space's children.
    var targetIndex: Int = 0

    /// Height of the floating drag card.
    var cardHeight: CGFloat = 44

    var isDragging: Bool { dragging != nil }

    /// `true` from the moment a long-press fires until the gesture ends.
    var longPressActive: Bool = false

    /// Origin of the sidebar viewport in `.global` (window) coordinates.
    var sidebarOriginInWindow: CGPoint = .zero

    /// Current vertical scroll offset, updated during auto-scroll.
    var scrollOffset: CGFloat = 0

    /// Keeps the floating card alive through its fade-out after a drop.
    private(set) var floatingCardChild: ContainerChild? = nil

    /// `true` during the same synchronous execution as `end()`, then reset.
    private(set) var justEndedDrag = false

    // MARK: - Smooth Drag Visual State

    /// Current scale factor for the dragged row (1.0 = normal, 1.05 = lifted)
    var dragScale: CGFloat = 1.0

    /// Current opacity for the dragged row (1.0 = normal, 0.7 = lifted)
    var dragOpacity: CGFloat = 1.0

    /// The specific child currently being dragged (for visual state)
    var visuallyDraggingChild: ContainerChild? = nil

    // MARK: - Space drag state

    var draggingSpace: Space? = nil
    private(set) var spaceFloatingCardSpace: Space? = nil
    var spaceTargetIndex: Int = 0
    var spaceCardHeight: CGFloat = 44

    var isDraggingSpace: Bool { draggingSpace != nil }

    // MARK: - Coordinate Conversion

    func toSidebar(_ windowPoint: CGPoint) -> CGPoint {
        CGPoint(x: windowPoint.x - sidebarOriginInWindow.x,
                y: windowPoint.y - sidebarOriginInWindow.y)
    }

    // MARK: Lifecycle

    func begin(child: ContainerChild, at point: CGPoint, height: CGFloat) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dragging = child
        floatingCardChild = child
        location = point
        cardHeight = height
    }

    func end() {
        longPressActive = false
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { dragging = nil }
        justEndedDrag = true
        DispatchQueue.main.async { [weak self] in
            withAnimation(.easeOut(duration: 0.18)) { self?.floatingCardChild = nil }
            self?.justEndedDrag = false
        }
    }

    func beginSpaceDrag(space: Space, at point: CGPoint, headerHeight: CGFloat) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        draggingSpace = space
        spaceFloatingCardSpace = space
        location = point
        spaceCardHeight = headerHeight
    }

    func endSpaceDrag() {
        longPressActive = false
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { draggingSpace = nil }
        justEndedDrag = true
        DispatchQueue.main.async { [weak self] in
            withAnimation(.easeOut(duration: 0.18)) { self?.spaceFloatingCardSpace = nil }
            self?.justEndedDrag = false
        }
    }

    func updateSpaceTarget(in spaces: [Space]) {
        let y = location.y
        let others = spaces.filter { draggingSpace?.persistentModelID != $0.persistentModelID }

        struct Candidate { let index: Int; let dist: CGFloat }
        var best: Candidate?

        func consider(_ c: Candidate) { if best == nil || c.dist < best!.dist { best = c } }

        for (i, space) in others.enumerated() {
            guard let frame = spaceHeaderFrames[space.persistentModelID] else { continue }
            let insertIndex = y < frame.midY ? i : i + 1
            consider(Candidate(index: insertIndex, dist: abs(frame.midY - y)))
        }
        if let lastFrame = others.compactMap({ spaceHeaderFrames[$0.persistentModelID] }).last {
            consider(Candidate(index: others.count, dist: abs(lastFrame.maxY - y)))
        }
        guard let b = best else { return }
        withAnimation(.spring(duration: 0.22, bounce: 0)) { spaceTargetIndex = b.index }
    }

    func updateTarget(in spaces: [Space]) {
        let y = location.y

        struct Candidate {
            let spaceID: PersistentIdentifier
            let index: Int
            let dist: CGFloat
        }
        var best: Candidate?

        func consider(_ candidate: Candidate) {
            if best == nil || candidate.dist < best!.dist { best = candidate }
        }

        for space in spaces {
            var kids = Containers.children(of: space)
            kids.removeAll { dragging?.id == $0.id }

            if kids.isEmpty {
                guard let headerFrame = spaceHeaderFrames[space.persistentModelID] else { continue }
                consider(Candidate(spaceID: space.persistentModelID,
                                   index: 0,
                                   dist: abs(headerFrame.maxY - y)))
            } else {
                for (i, child) in kids.enumerated() {
                    guard let frame = rowFrames[child.id] else { continue }
                    let midY = frame.midY
                    let insertIndex = y < midY ? i : i + 1
                    consider(Candidate(spaceID: space.persistentModelID,
                                       index: insertIndex,
                                       dist: abs(midY - y)))
                }
                if let lastFrame = kids.compactMap({ rowFrames[$0.id] }).last {
                    consider(Candidate(spaceID: space.persistentModelID,
                                       index: kids.count,
                                       dist: abs(lastFrame.maxY - y)))
                }
            }
        }

        guard let b = best else { return }
        withAnimation(.spring(duration: 0.22, bounce: 0.3)) {
            targetSpaceID = b.spaceID
            targetIndex = b.index
        }
    }

    // MARK: - Smooth Drag Animations

    /// Animates the row lifting effect when drag begins
    func animateLift() {
        withAnimation(.spring(duration: 0.15, bounce: 0)) {
            dragScale = 1.05
            dragOpacity = 0.7
        }
    }

    /// Animates the row dropping effect when drag ends
    func animateDrop() {
        // First phase: quick scale down with bounce
        withAnimation(.spring(duration: 0.1, bounce: 0.3)) {
            dragScale = 0.95
            dragOpacity = 1.0
        }

        // Second phase: settle to normal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            withAnimation(.spring(duration: 0.15, bounce: 0)) {
                self?.dragScale = 1.0
            }
        }
    }

    /// Resets visual state without animation (for cancel)
    func resetVisualState() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            dragScale = 1.0
            dragOpacity = 1.0
        }
    }
}

// MARK: - Preference Keys (Sidebar-Specific)

/// Preference key for container row frames (sidebar-specific).
/// Uses ContainerChild.ID as the key to match the rowFrames dictionary in SidebarDragState.
struct RowFrameKey: PreferenceKey {
    typealias Value = [ContainerChild.ID: CGRect]
    static var defaultValue: Value = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Preference key for space header frames (sidebar-specific).
struct SpaceHeaderFrameKey: PreferenceKey {
    typealias Value = [PersistentIdentifier: CGRect]
    static var defaultValue: Value = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Preference key for sidebar viewport origin (sidebar-specific).
struct SidebarOriginKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}