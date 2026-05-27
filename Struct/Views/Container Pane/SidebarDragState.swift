//
//  SidebarDragState.swift
//  Struct
//
//  Created by Otto Kiefer on 26.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - RowFrameKey

/// Preference key that bubbles each container row's frame (in the "sidebar"
/// named coordinate space) up to `ContainersSidebarView` so the drop-target
/// can be computed from raw geometry.
struct RowFrameKey: PreferenceKey {
    typealias Value = [ContainerChild.ID: CGRect]
    static var defaultValue: Value = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - SpaceHeaderFrameKey

/// Preference key for each space section header's frame in the "sidebar"
/// coordinate space.  Used to make empty spaces valid drop targets — when a
/// space has no children, its header frame supplies the reference geometry.
struct SpaceHeaderFrameKey: PreferenceKey {
    typealias Value = [PersistentIdentifier: CGRect]
    static var defaultValue: Value = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - SidebarDragState

/// Observable drag state for the container sidebar.
///
/// Owned as `@State` in `ContainersSidebarView` and injected into the view
/// hierarchy via `.environment(drag)`. `SpaceSectionView` reads it with
/// `@Environment(SidebarDragState.self)`.
///
/// All mutation runs on the main actor (SwiftUI views always call into this
/// from the main thread).
@Observable
final class SidebarDragState {

    // MARK: State

    /// The item currently being dragged; `nil` when idle.
    var dragging: ContainerChild? = nil

    /// Current finger position in the `"sidebar"` named coordinate space
    /// (matches the `coordinateSpace` on the `ScrollView`).
    var location: CGPoint = .zero

    /// Every row's frame in the sidebar coordinate space, reported via
    /// `RowFrameKey`. Updated each layout pass.
    var rowFrames: [ContainerChild.ID: CGRect] = [:]

    /// Each space section header's frame, reported via `SpaceHeaderFrameKey`.
    /// Used as the drop-zone anchor for spaces that have no children.
    var spaceHeaderFrames: [PersistentIdentifier: CGRect] = [:]

    /// The space that would receive the drop, recomputed on every gesture
    /// update.
    var targetSpaceID: PersistentIdentifier? = nil

    /// Insertion index inside the target space's children (after the dragged
    /// item has been removed from that list), recomputed on every gesture
    /// update.
    var targetIndex: Int = 0

    /// Height of the floating drag card, captured from the row that started
    /// the drag and used to size the drop-zone gap.
    var cardHeight: CGFloat = 44

    var isDragging: Bool { dragging != nil }

    /// Keeps the floating card alive and visible during its fade-out after a
    /// drop.  Set alongside `dragging` in `begin()`; cleared with an easeOut
    /// animation in `end()` so the card fades independently from the layout
    /// snap that clears `dragging`.
    private(set) var floatingCardChild: ContainerChild? = nil

    /// `true` during the same synchronous execution block as `end()`, then
    /// reset asynchronously.  Prevents the Button's tap action from firing
    /// navigation on the touch-up event that also ends the drag.
    private(set) var justEndedDrag = false

    // MARK: Lifecycle

    func begin(child: ContainerChild, at point: CGPoint, height: CGFloat) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dragging          = child
        floatingCardChild = child
        location          = point
        cardHeight        = height
    }

    func end() {
        // Instantly reset all layout state — no ghost row re-expansion
        // animation and no overshooting spring bounce on drop.
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            dragging = nil
        }
        justEndedDrag = true
        // On the next run loop: fade the card out and unblock tap navigation.
        // Deferring keeps the card visible for one frame while SwiftData
        // delivers the repacked sortIndex update, masking the layout snap.
        DispatchQueue.main.async { [weak self] in
            withAnimation(.easeOut(duration: 0.18)) {
                self?.floatingCardChild = nil
            }
            self?.justEndedDrag = false
        }
    }

    // MARK: Target computation

    /// Recomputes `targetSpaceID` and `targetIndex` from the current
    /// `location`, `rowFrames`, and `spaceHeaderFrames`.  Call this inside
    /// every drag gesture `.onChanged` after updating `location`.
    func updateTarget(in spaces: [Space]) {
        let y = location.y

        struct Candidate {
            let spaceID: PersistentIdentifier
            let index:   Int
            let dist:    CGFloat
        }
        var best: Candidate?

        func consider(_ candidate: Candidate) {
            if best == nil || candidate.dist < best!.dist { best = candidate }
        }

        for space in spaces {
            var kids = Containers.children(of: space)
            kids.removeAll { dragging?.id == $0.id }

            if kids.isEmpty {
                // No row frames to test — use the space header's bottom edge
                // as the virtual anchor for index-0 insertion.
                guard let headerFrame = spaceHeaderFrames[space.persistentModelID] else { continue }
                consider(Candidate(spaceID: space.persistentModelID,
                                   index:   0,
                                   dist:    abs(headerFrame.maxY - y)))
            } else {
                for (i, child) in kids.enumerated() {
                    guard let frame = rowFrames[child.id] else { continue }
                    let midY        = frame.midY
                    let insertIndex = y < midY ? i : i + 1
                    consider(Candidate(spaceID: space.persistentModelID,
                                       index:   insertIndex,
                                       dist:    abs(midY - y)))
                }

                // Extra candidate anchored at the last row's *bottom* edge so
                // the "insert after last item" slot has a full-row-height drop
                // zone instead of just half a row.  Without this the slot loses
                // to the next space's first row the moment the finger passes the
                // last item's midY.
                if let lastFrame = kids.compactMap({ rowFrames[$0.id] }).last {
                    consider(Candidate(spaceID: space.persistentModelID,
                                       index:   kids.count,
                                       dist:    abs(lastFrame.maxY - y)))
                }
            }
        }

        guard let b = best else { return }
        withAnimation(.spring(duration: 0.22, bounce: 0.3)) {
            targetSpaceID = b.spaceID
            targetIndex   = b.index
        }
    }
}
