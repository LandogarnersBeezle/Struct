//
//  SpaceSectionView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - SlotItem

/// One element in a space's display list during a drag: either a real child
/// row or the animated drop-zone gap.
private enum SlotItem: Identifiable {
    case child(ContainerChild)
    case gap

    var id: AnyHashable {
        switch self {
        case .child(let c): AnyHashable(c.id)
        case .gap:          AnyHashable("gap")
        }
    }
}

extension SlotItem: Hashable {
    static func == (lhs: SlotItem, rhs: SlotItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Drop Gap View

/// Dashed-outline placeholder that shows where the dragged card will land.
private struct DropGapView: View {
    let height: CGFloat
    let layoutMetrics: LayoutMetrics

    var body: some View {
        RoundedRectangle(cornerRadius: layoutMetrics.dropGapCornerRadius, style: .continuous)
            .strokeBorder(
                Color.accentColor.opacity(0.55),
                style: StrokeStyle(lineWidth: layoutMetrics.dropGapLineWidth, dash: layoutMetrics.dropGapDashPattern)
            )
            .frame(height: height)
            .padding(.horizontal, 4)
    }
}

// MARK: - SpaceSectionView

/// Renders one Space's children with drag-and-drop support.
///
/// Each row owns a long-press → drag gesture that feeds into the shared
/// `SidebarDragState`.  The `slots` computed property inserts a gap at the
/// current drop target position so SwiftUI's layout engine produces the
/// smooth "push-aside" animation automatically.
struct SpaceSectionView: View {

    let space:     Space
    /// All spaces — needed so any section can commit a cross-space drop.
    let allSpaces: [Space]
    let onSelect:  (ContainerTarget) -> Void

    @Environment(SidebarDragState.self)      private var drag
    @Environment(SidebarSwipeSelection.self) private var swipeSelection
    @Environment(\.modelContext)             private var context

    // MARK: Layout metrics

    private let layoutMetrics = LayoutMetrics.sidebar

    // MARK: Error state

    @State private var saveError: DataError?

    @Query private var lists:    [List]
    @Query private var projects: [Project]

    init(space: Space, allSpaces: [Space], onSelect: @escaping (ContainerTarget) -> Void) {
        self.space     = space
        self.allSpaces = allSpaces
        self.onSelect  = onSelect
        let id = space.persistentModelID
        _lists = Query(
            filter: #Predicate<List> {
                $0.space?.persistentModelID == id && $0.kindRaw != "inbox"
            },
            sort: \.sortIndex
        )
        _projects = Query(
            filter: #Predicate<Project> { $0.space.persistentModelID == id },
            sort: \.sortIndex
        )
    }

    // MARK: Derived data

    /// Live children merged and sorted by unified sortIndex.
    private var children: [ContainerChild] {
        let ls = lists.map(ContainerChild.list)
        let ps = projects.map(ContainerChild.project)
        return (ls + ps).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Display list: the dragged item is **kept** in the array (removing it
    /// from `ForEach` would destroy its view and cancel the active gesture
    /// recogniser).  It is instead collapsed to zero height so it takes no
    /// layout space.  A gap is inserted at the drop position when this space
    /// is the current target.
    private var slots: [SlotItem] {
        // All children — never filtered — so the dragged row's view (and its
        // gesture recogniser) are never torn down mid-drag.
        var result = children.map(SlotItem.child)

        if drag.isDragging, drag.targetSpaceID == space.persistentModelID {
            // `drag.targetIndex` is computed against *kids* (children with the
            // dragged item removed).  `result` still contains the ghost, so
            // when the ghost sits before the insertion point every slot beyond
            // it is shifted by one.  Compensate with a +1 offset in that case.
            let ghostPos = children.firstIndex(where: { drag.dragging?.id == $0.id })
            let adjusted = ghostPos.map { drag.targetIndex > $0 ? drag.targetIndex + 1
                                                                 : drag.targetIndex }
                           ?? drag.targetIndex
            let idx = max(0, min(adjusted, result.count))
            result.insert(.gap, at: idx)
        }
        return result
    }

    var body: some View {
        // spacing: 0 so we can suppress the gap around the collapsed ghost row.
        VStack(alignment: .leading, spacing: 0) {
            // bounce: 0 — crisp, no-overshoot spring for both drag start
            // (row collapses cleanly) and gap movement (rows glide apart).
            ForEach(slots) { slot in
                switch slot {
                case .child(let child):
                    let isGhosted = drag.dragging?.id == child.id
                    rowView(for: child)
                        // frameAnchor must sit before .padding so the GeometryReader
                        // measures the raw row height (excluding the 8 pt gap).
                        // DropGapView uses that same height, so the gap slot and a
                        // normal row slot are identical in total height.
                        .background(frameAnchor(for: child))
                        // Collapsed ghost takes no space; normal rows keep 8 pt below.
                        .padding(.bottom, isGhosted ? 0 : 8)
                case .gap:
                    DropGapView(height: drag.cardHeight, layoutMetrics: layoutMetrics)
                        .padding(.bottom, 8)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                            removal:   .opacity.animation(.easeOut(duration: layoutMetrics.cardFadeOutDuration))
                        ))
                }
            }
        }
        .animation(.spring(duration: layoutMetrics.dragSpringDuration, bounce: layoutMetrics.dragSpringBounce), value: slots.map(\.id))
        .padding(.leading, 8)
        // When this space is being dragged as a whole, collapse all its children
        // so only the (ghost) space header remains visible in the layout.
        .opacity(drag.draggingSpace?.persistentModelID == space.persistentModelID ? 0 : 1)
        .frame(height: drag.draggingSpace?.persistentModelID == space.persistentModelID ? 0 : nil)
        .clipped()
        .animation(.spring(duration: layoutMetrics.dragSpringDuration, bounce: layoutMetrics.dragSpringBounce),
                   value: drag.draggingSpace?.persistentModelID)
        .errorAlert($saveError)
    }

    // MARK: - Row view

    @ViewBuilder
    private func rowView(for child: ContainerChild) -> some View {
        let isGhosted = drag.dragging?.id == child.id
        let openCount = child.openTaskCount
        let typeLabel: String = {
            switch child {
            case .list: return NSLocalizedString("List", comment: "Container type")
            case .project: return NSLocalizedString("Project", comment: "Container type")
            }
        }()
        let accessibilityLabelText = openCount > 0
            ? String(format: NSLocalizedString("%@, %@, %d open task%@", comment: "Accessibility label format: title, type, count, tasks"),
                     child.title, typeLabel, openCount, openCount == 1 ? "" : "s")
            : String(format: NSLocalizedString("%@, %@", comment: "Accessibility label format: title, type"),
                     child.title, typeLabel)

        ContainerRowView(
            symbol:        child.symbol,
            title:         child.title,
            openTaskCount: child.openTaskCount,
            color:         child.containerColor
        )
        // Single UIKit-backed gesture pipeline handles tap, swipe-left, and
        // long-press-drag without competing with the ScrollView's pan.
        .draggableRowInteraction(
            isHighlighted: swipeSelection.matches(child.swipeKind),
            accessibilityLabel: accessibilityLabelText,
            onTap:            { handleTap(child) },
            onSwipeTriggered: { swipeSelection.toggle(child.swipeKind) },
            onDragBegan:      { handleDragBegan(child, at: $0) },
            onDragChanged:    { handleDragChanged(at: $0) },
            onDragEnded:      { handleDragEnded() }
        )
        // Ghost-collapse: keep the view (and its gesture host) alive but at
        // zero height so the active recogniser is not torn down mid-drag.
        .opacity(isGhosted ? 0 : 1)
        .frame(height: isGhosted ? 0 : nil)
        .clipped()
        .allowsHitTesting(!isGhosted)
    }

    // MARK: - Gesture callbacks

    private func handleTap(_ child: ContainerChild) {
        if !drag.isDragging, !drag.justEndedDrag, !swipeSelection.justTriggered {
            swipeSelection.clear()
            onSelect(child.target)
        }
    }

    private func handleDragBegan(_ child: ContainerChild, at windowLoc: CGPoint) {
        drag.longPressActive = true
        let loc = drag.toSidebar(windowLoc)
        // Pre-set the target to the row's own current slot so the gap opens
        // in-place — zero net displacement for every other row.
        if let idx = children.firstIndex(where: { $0.id == child.id }) {
            drag.targetSpaceID = space.persistentModelID
            drag.targetIndex   = idx
        }
        drag.begin(child: child, at: loc, height: layoutMetrics.rowHeight)
    }

    private func handleDragChanged(at windowLoc: CGPoint) {
        guard drag.isDragging else { return }
        drag.location = drag.toSidebar(windowLoc)
        drag.updateTarget(in: allSpaces)
    }

    private func handleDragEnded() {
        drag.longPressActive = false
        guard drag.isDragging else { return }
        commitDrop()
    }

    // MARK: - Frame reporting

    /// Transparent background that publishes the row's frame via `RowFrameKey`
    /// and keeps `drag.cardHeight` in sync.
    private func frameAnchor(for child: ContainerChild) -> some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named("sidebar"))
            Color.clear
                .preference(key: RowFrameKey.self, value: [child.id: frame])
                .onChange(of: geo.size.height, initial: true) { _, h in
                    if !drag.isDragging { drag.cardHeight = h }
                }
        }
    }

    // MARK: - Drop commit

    private func commitDrop() {
        defer { drag.end() }

        guard let dragging       = drag.dragging,
              let targetSpaceID  = drag.targetSpaceID,
              let targetSpace    = allSpaces.first(where: { $0.persistentModelID == targetSpaceID })
        else { return }

        // Determine source space before we mutate anything
        let sourceSpaceID: PersistentIdentifier? = {
            switch dragging {
            case .list(let l):    return l.space?.persistentModelID
            case .project(let p): return p.space.persistentModelID
            }
        }()
        let isCrossSpace = sourceSpaceID != targetSpace.persistentModelID

        // Build the intended child order for the target space
        var targetChildren = Containers.children(of: targetSpace)
        targetChildren.removeAll { $0.id == dragging.id }
        let idx = max(0, min(drag.targetIndex, targetChildren.count))
        targetChildren.insert(dragging, at: idx)

        // Re-parent if moving across spaces
        if isCrossSpace {
            switch dragging {
            case .list(let l):    l.space = targetSpace
            case .project(let p): p.space = targetSpace
            }
        }

        // Write unified sortIndex values to the target space
        Containers.repack(targetChildren)

        // Repack source space's remaining children
        if isCrossSpace,
           let srcID    = sourceSpaceID,
           let srcSpace = allSpaces.first(where: { $0.persistentModelID == srcID }) {
            Containers.repack(Containers.children(of: srcSpace))
        }

        do {
            try context.saveOrThrow()
        } catch let error as DataError {
            saveError = error
        } catch {
            saveError = .saveFailed(error)
        }
    }
}
