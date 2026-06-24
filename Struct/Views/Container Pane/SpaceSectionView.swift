//
//  SpaceSectionView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                rowView(for: child)
                    // Track child frame for insertion‑index calculation
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
        // Drop target for the entire space's children area
        .coordinateSpace(.named(spaceCoordName))
        .dropDestination(for: ContainerDragData.self) { items, location in
            handleDrop(items, at: location)
        } isTargeted: { targeted in
            // Currently unused; we rely on the natural row-shifting of ForEach
        }
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

    private func handleDrop(_ items: [ContainerDragData], at location: CGPoint) -> Bool {
        guard let dragData = items.first else { return false }

        let insertionIndex = insertionIndex(at: location)

        // Look up the model from the context
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

        guard let child else { return false }

        // Animate the row into its new position with a smooth spring.
        // The @Query re-fetches after context.save() inside moveChild,
        // and withAnimation captures that diff for the ForEach transition.
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            Containers.moveChild(child, to: space, at: insertionIndex, context: context)
        }

        return true
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

        // Try precise frame-based positioning first
        // Collect midY for each child in visual order
        let midYs: [CGFloat] = sorted.compactMap { child in
            guard let rect = childFrames[child.id] else { return nil }
            return rect.midY
        }

        if midYs.count == sorted.count {
            for (i, midY) in midYs.enumerated() {
                if location.y < midY {
                    return i
                }
            }
            return midYs.count
        }

        // Fallback: estimate from row height when some frames are missing
        let rowHeight: CGFloat = 44
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