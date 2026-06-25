//
//  SpaceSectionView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Child Frame Preference Key

/// Collects the frame of each rendered child in the space VStack's coordinate
/// space, keyed by the child's ID.
struct ChildFrame: Equatable {
    let id:   ContainerChild.ID
    let rect: CGRect
}

struct ChildFramePreferenceKey: PreferenceKey {
    static let defaultValue: [ChildFrame] = []

    static func reduce(value: inout [ChildFrame], nextValue: () -> [ChildFrame]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Insertion Line Drop Delegate

/// Lightweight `DropDelegate` that tracks where the insertion‑line should
/// appear.  It updates `insertionLineY` based on the finger location and
/// loads `ContainerDragData` on drop.
private struct InsertionLineDropDelegate: DropDelegate {

    let children:    [ContainerChild]
    let childFrames: [ContainerChild.ID: CGRect]

    /// The Y position (in the VStack's coordinate space) where the green
    /// insertion line should be drawn, or `nil` when the drag is inactive.
    @Binding var insertionLineY: CGFloat?

    /// Called on drop with the decoded drag data.
    let performDropHandler: (ContainerDragData) -> Void

    // MARK: Drop lifecycle

    func dropEntered(info: DropInfo) {
        updateLineY(from: info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateLineY(from: info.location)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.15)) {
                insertionLineY = nil
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        // Do NOT clear insertionLineY here — it's still needed by
        // the drop handler to compute the insertion index.  The
        // handler will clear it after the move.
        guard let provider = info.itemProviders(for: [.containerDrag]).first else {
            DispatchQueue.main.async { insertionLineY = nil }
            return false
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.containerDrag.identifier) { data, error in
            guard let data,
                  let dragData = try? JSONDecoder().decode(ContainerDragData.self, from: data)
            else {
                DispatchQueue.main.async { self.insertionLineY = nil }
                return
            }

            DispatchQueue.main.async {
                self.performDropHandler(dragData)
            }
        }

        return true
    }

    // MARK: Line position

    /// Computes the insertion index from the finger location, then derives
    /// the Y position for the green line.
    private func updateLineY(from location: CGPoint) {
        let index = insertionIndex(at: location)
        let yPos: CGFloat = {
            let sorted = children
            guard !sorted.isEmpty else { return 0 }

            // Index is past the last child → line sits at the bottom of the last row
            if index >= sorted.count, let last = childFrames[sorted.last!.id] {
                return last.maxY
            }

            // Insert before child at `index` → line sits at that child's top edge
            if let rect = childFrames[sorted[index].id] {
                return rect.minY
            }

            // Fallback: estimate
            return CGFloat(index) * 52
        }()

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.12)) {
                insertionLineY = yPos
            }
        }
    }

    // MARK: Index calculation

    private func insertionIndex(at location: CGPoint) -> Int {
        let sorted = children
        guard !sorted.isEmpty else { return 0 }

        // Use the bottom edge of each row as the boundary between zones
        // (natural hysteresis — finger must leave a row to advance).
        let bottomEdges: [CGFloat] = sorted.compactMap { child in
            guard let rect = childFrames[child.id] else { return nil }
            return rect.maxY
        }

        if bottomEdges.count == sorted.count {
            for (i, maxY) in bottomEdges.enumerated() {
                if location.y < maxY {
                    return i
                }
            }
            return bottomEdges.count
        }

        let rowHeight: CGFloat = 52
        let estimatedIndex = Int(floor(location.y / rowHeight))
        return min(max(estimatedIndex, 0), sorted.count)
    }
}

// MARK: - SpaceSectionView

/// Renders one Space's children (lists and projects) with tap-to-select,
/// swipe-to-delete, and drag-to-reorder (within or across spaces).
struct SpaceSectionView: View {

    let space:     Space
    /// The currently selected container target (used for highlighting on iPad)
    var selectedTarget: ContainerTarget? = nil
    let onSelect:  (ContainerTarget) -> Void

    @Environment(SidebarSwipeSelection.self) private var swipeSelection
    @Environment(\.modelContext)             private var context

    // MARK: Error state

    @State private var saveError: DataError?

    // MARK: Insertion line visual feedback

    /// The Y position (in `spaceCoordName` coordinate space) where the green
    /// insertion line is drawn.  `nil` means no drag is active.
    @State private var insertionLineY: CGFloat? = nil

    @Query private var lists:    [List]
    @Query private var projects: [Project]

    init(space: Space, selectedTarget: ContainerTarget? = nil, onSelect: @escaping (ContainerTarget) -> Void) {
        self.space     = space
        self.selectedTarget = selectedTarget
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

    // MARK: Child frames

    /// Rendered child frames in the space VStack's coordinate space, populated
    /// via `ChildFramePreferenceKey`.
    @State private var childFrames: [ContainerChild.ID: CGRect] = [:]

    /// The coordinate space name for this space's VStack.
    private var spaceCoordName: String {
        "spaceVStack_\(space.persistentModelID)"
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                rowView(for: child)
                    // Track child frame for insertion‑line calculation
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: ChildFramePreferenceKey.self,
                                    value: [ChildFrame(
                                        id: child.id,
                                        rect: geo.frame(in: .named(spaceCoordName))
                                    )]
                                )
                        }
                    )
            }
        }
        .padding(.leading, 8)
        .errorAlert($saveError)
        // Receive frame updates
        .onPreferenceChange(ChildFramePreferenceKey.self) { frames in
            for frame in frames {
                childFrames[frame.id] = frame.rect
            }
        }
        // Green insertion‑line overlay
        .overlay(alignment: .topLeading) {
            if let y = insertionLineY {
                Rectangle()
                    .fill(Color.green)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .offset(y: y - 1) // centre the 2pt line on the target Y
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.12), value: insertionLineY)
            }
        }
        // Drop target with full location tracking via custom DropDelegate
        .coordinateSpace(.named(spaceCoordName))
        .onDrop(
            of: [UTType.containerDrag],
            delegate: InsertionLineDropDelegate(
                children: children,
                childFrames: childFrames,
                insertionLineY: $insertionLineY,
                performDropHandler: { dragData in
                    self.handleDrop(dragData)
                }
            )
        )
    }

    // MARK: - Row view

    @ViewBuilder
    private func rowView(for child: ContainerChild) -> some View {
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
        // Background highlight for selected state (no layout shift)
        .background(selectedTarget == child.target ? Color.accentColor.opacity(0.12) : Color.clear)
        .cornerRadius(8)
        // Gesture pipeline handles tap and swipe-left
        .swipeableRowInteraction(
            isHighlighted: swipeSelection.matches(child.swipeKind),
            accessibilityLabel: accessibilityLabelText,
            onTap:            { handleTap(child) },
            onSwipeTriggered: { swipeSelection.toggle(child.swipeKind) }
        )
        // Drag source — long‑press lifts the actual row
        .draggable(ContainerDragData(
            containerID:   child.persistentModelID,
            isList:        child.isList,
            sourceSpaceID: space.persistentModelID
        ))
        .padding(.bottom, 8)
    }

    // MARK: - Drop handling

    /// Called by `InsertionLineDropDelegate` when the drop completes.
    /// Looks up the model from the drag payload and performs the reorder.
    /// Reads `insertionLineY` to determine where to insert, then clears it.
    private func handleDrop(_ dragData: ContainerDragData) {
        // Snapshot the line position before clearing it.
        let lineY = insertionLineY
        insertionLineY = nil

        let modelID = dragData.containerID
        let child: ContainerChild? = {
            if dragData.isList,
               let list = context.model(for: modelID) as? List {
                return .list(list)
            } else if let project = context.model(for: modelID) as? Project {
                return .project(project)
            }
            return nil
        }()

        guard let child else { return }

        // Compute insertion index from the line position.
        // Find the child whose top edge is at (or just past) the line's Y,
        // then insert before it.
        let insertionIndex: Int = {
            let sorted = children
            guard !sorted.isEmpty else { return 0 }
            guard let lineY else { return 0 }
            for (i, child) in sorted.enumerated() {
                if let rect = childFrames[child.id], rect.minY >= lineY {
                    return i
                }
            }
            return sorted.count
        }()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            Containers.moveChild(child, to: space, at: insertionIndex, context: context)
        }
    }

    /// Calculates the insertion index for a drop at `location.y` within this
    /// space's children VStack coordinate space.
    ///
    /// Uses the collected child frame rects for precise positioning. Falls
    /// back to row-height estimation when frames aren't available (e.g. empty
    /// space or first frame(s) not yet rendered).
    private func insertionIndex(at location: CGPoint) -> Int {
        let sorted = children
        guard !sorted.isEmpty else { return 0 }

        let bottomEdges: [CGFloat] = sorted.compactMap { child in
            guard let rect = childFrames[child.id] else { return nil }
            return rect.maxY
        }

        if bottomEdges.count == sorted.count {
            for (i, maxY) in bottomEdges.enumerated() {
                if location.y < maxY {
                    return i
                }
            }
            return bottomEdges.count
        }

        let rowHeight: CGFloat = 52
        let estimatedIndex = Int(floor(location.y / rowHeight))
        return min(max(estimatedIndex, 0), sorted.count)
    }

    // MARK: - Gesture callbacks

    private func handleTap(_ child: ContainerChild) {
        if !swipeSelection.justTriggered {
            swipeSelection.clear()
            onSelect(child.target)
        }
    }
}