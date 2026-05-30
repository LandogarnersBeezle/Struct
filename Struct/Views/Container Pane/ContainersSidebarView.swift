//
//  ContainersSidebarView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - SpaceSlotItem

/// Display slot for the spaces list: either a real space section or the
/// animated drop-zone gap shown during a space drag.
private enum SpaceSlotItem: Identifiable, Equatable {
    case space(Space)
    case gap

    var id: AnyHashable {
        switch self {
        case .space(let s): AnyHashable(s.persistentModelID)
        case .gap:          AnyHashable("space-gap")
        }
    }

    static func == (lhs: SpaceSlotItem, rhs: SpaceSlotItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - ContainersSidebarView

/// Layout host for the leading sidebar pane.
///
/// Owns the shared SidebarDragState and injects it into the view hierarchy
/// via .environment.  Collects per-row frames through RowFrameKey and
/// routes them into drag.rowFrames so drop-target computation (which runs
/// entirely inside SidebarDragState) has up-to-date geometry.
///
/// The floating drag card and the dashed drop-zone gap together produce the
/// smooth "push-aside" animation: the gap is rendered by SpaceSectionView
/// in the normal layout flow (so other rows spring apart naturally), while
/// the card floats above everything in a ZStack overlay.
struct ContainersSidebarView: View {

    let inbox:  List?
    let spaces: [Space]

    /// Called whenever the user taps a container row or space header.
    let onSelect: (ContainerTarget) -> Void

    /// Drives the "create container" sheet; owned by the parent so the sheet
    /// survives sidebar hide/show transitions.
    @Binding var pendingCreate: CreateKind?

    @Environment(\.modelContext) private var modelContext

    // MARK: Drag state

    @State private var drag           = SidebarDragState()
    @State private var swipeSelection = SidebarSwipeSelection()

    // MARK: Body

    var body: some View {
        // Inbox row — sits above the drag-enabled scroll area
        if let inbox {
            Button { onSelect(.list(inbox)) } label: {
                ContainerRowView(symbol: "tray", title: inbox.title,
                                 openTaskCount: inbox.items.filter { !$0.isCompleted }.count,
                                 color: List.containerColor)
            }
            .buttonStyle(ContainerRowButtonStyle())
            .padding(5)
        }

        // ZStack: scroll content behind + floating drag cards on top
        ZStack(alignment: .top) {
            scrollContent
            floatingCardOverlay
            spaceFloatingCardOverlay
        }
        .environment(drag)
        .environment(swipeSelection)
    }

    // MARK: - Space slots

    /// Spaces array with a gap inserted at the current drop position during a
    /// space drag — mirrors the container slot mechanism in SpaceSectionView.
    private var spaceSlots: [SpaceSlotItem] {
        var result = spaces.map(SpaceSlotItem.space)
        guard drag.isDraggingSpace else { return result }
        let ghostPos = spaces.firstIndex { drag.draggingSpace?.persistentModelID == $0.persistentModelID }
        let adjusted = ghostPos.map { drag.spaceTargetIndex > $0 ? drag.spaceTargetIndex + 1
                                                                  : drag.spaceTargetIndex }
                       ?? drag.spaceTargetIndex
        result.insert(.gap, at: max(0, min(adjusted, result.count)))
        return result
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(spaceSlots) { slot in
                    switch slot {
                    case .space(let space):
                        let isGhost = drag.draggingSpace?.persistentModelID == space.persistentModelID
                        Section {
                            SpaceSectionView(space: space, allSpaces: spaces, onSelect: onSelect)
                                .padding(.horizontal, 5)
                                .padding(.bottom, isGhost ? 0 : 8)
                        } header: {
                            spaceHeader(for: space)
                        }
                    case .gap:
                        spaceDropGap
                    }
                }
            }
            .animation(.spring(duration: 0.22, bounce: 0), value: spaceSlots)
        }
        .coordinateSpace(.named("sidebar"))
        // Capture the sidebar viewport's origin in window coordinates so the
        // UIKit-backed gesture overlay can report finger locations in the
        // "sidebar" named coordinate space (drag.toSidebar).
        // We use an overlay instead of background to ensure the GeometryReader
        // is laid out correctly and the preference propagates properly.
        .overlay {
            GeometryReader { geo in
                Color.clear
                    .preference(key: SidebarOriginKey.self,
                                value: geo.frame(in: .global).origin)
            }
        }
        // Disable scrolling once a long press fires so the drag-for-reorder
        // gesture owns subsequent touches.  Before the long press the flag is
        // false and the user scrolls freely.
        .scrollDisabled(drag.longPressActive || drag.isDragging || drag.isDraggingSpace)
        .onPreferenceChange(RowFrameKey.self)         { drag.rowFrames           = $0 }
        .onPreferenceChange(SpaceHeaderFrameKey.self) { drag.spaceHeaderFrames   = $0 }
        .onPreferenceChange(SidebarOriginKey.self)    { drag.sidebarOriginInWindow = $0 }
        .safeAreaInset(edge: .bottom) {
            // The add button and the action bar share the same fixed-height slot
            // (using a ZStack) so the scroll inset never changes size — rows near
            // the bottom are always fully visible regardless of which is active.
            ZStack {
                addMenu
                    .opacity(swipeSelection.active == nil ? 1 : 0)
                    .scaleEffect(swipeSelection.active == nil ? 1 : 0.85)
                ContainerActionBar()
                    .opacity(swipeSelection.active != nil ? 1 : 0)
                    .scaleEffect(swipeSelection.active != nil ? 1 : 0.85)
            }
            .animation(.spring(duration: 0.28, bounce: 0), value: swipeSelection.active != nil)
            .padding()
        }
        .sheet(item: $pendingCreate) { CreateContainerView(kind: $0) }
        // Dismiss any open action bar when a drag-and-drop begins.
        .onChange(of: drag.isDragging)      { _, on in if on { swipeSelection.clear() } }
        .onChange(of: drag.isDraggingSpace) { _, on in if on { swipeSelection.clear() } }
    }

    // MARK: - Space drop gap

    private var spaceDropGap: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.accentColor.opacity(0.55),
                          style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
            .frame(height: drag.spaceCardHeight)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.85).combined(with: .opacity),
                removal:   .opacity.animation(.easeOut(duration: 0.1))
            ))
    }

    // MARK: - Floating drag card

    @ViewBuilder
    private var floatingCardOverlay: some View {
        // Driven by floatingCardChild (not dragging) so the card outlives the
        // drag state and can fade out independently after a drop.
        if let child = drag.floatingCardChild {
            GeometryReader { proxy in
                ContainerRowView(
                    symbol:        child.symbol,
                    title:         child.title,
                    openTaskCount: child.openTaskCount,
                    color:         child.containerColor
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                        .opacity(0.5)
                )
                // Center horizontally in the sidebar; follow finger vertically
                .position(x: proxy.size.width / 2,
                          y: drag.location.y)
            }
            .allowsHitTesting(false)
            // Fade in on lift; fade out via easeOut in SidebarDragState.end()
            .transition(.opacity)
            .zIndex(999)
        }
    }

    // MARK: - Space header

    /// Shared row content used by both the header button and the floating card.
    @ViewBuilder
    private func spaceRowContent(for space: Space) -> some View {
        HStack {
            Image(systemName: space.symbolName)
                .foregroundStyle(Space.containerColor)
                .frame(width: 24)
            Text(space.name)
                .lineLimit(1)
                .fontWeight(.bold)
            Spacer()
            let openCount = space.items.filter { !$0.isCompleted }.count
            if openCount > 0 {
                Text("\(openCount)")
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    }
                    .padding(.trailing, 5)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func spaceHeader(for space: Space) -> some View {
        let isGhost = drag.draggingSpace?.persistentModelID == space.persistentModelID
        VStack(alignment: .leading, spacing: 0) {
            // Divider stays outside the interactive region — it belongs to the
            // section boundary, not to the row's hit target.
            Divider()
            spaceRowContent(for: space)
                .padding(.bottom, 10)
                .sidebarRowInteraction(
                    isHighlighted: swipeSelection.matches(.space(space)),
                    onTap:            { handleSpaceTap(space) },
                    onSwipeTriggered: { swipeSelection.toggle(.space(space)) },
                    onDragBegan:      { handleSpaceDragBegan(space, at: $0) },
                    onDragChanged:    { handleSpaceDragChanged(at: $0) },
                    onDragEnded:      { handleSpaceDragEnded() }
                )
        }
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: SpaceHeaderFrameKey.self,
                                       value: [space.persistentModelID: geo.frame(in: .named("sidebar"))])
            }
        }
        .background(.background)
        // Ghost: collapse header to zero height so the space slot takes no space,
        // while keeping the view (and its gesture recogniser) in the hierarchy.
        .opacity(isGhost ? 0 : 1)
        .frame(height: isGhost ? 0 : nil)
        .clipped()
        .allowsHitTesting(!isGhost)
        .animation(.spring(duration: 0.22, bounce: 0), value: isGhost)
    }

    // MARK: - Space floating card

    /// Mirrors the dragged space's header content; outlives draggingSpace
    /// so it can fade out independently after the drop (same pattern as
    /// floatingCardOverlay for container rows).
    @ViewBuilder
    private var spaceFloatingCardOverlay: some View {
        if let space = drag.spaceFloatingCardSpace {
            GeometryReader { proxy in
                spaceRowContent(for: space)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.background)
                            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                            .opacity(0.5)
                    )
                    .position(x: proxy.size.width / 2, y: drag.location.y)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
            .zIndex(999)
        }
    }

    // MARK: - Space gesture callbacks

    private func handleSpaceTap(_ space: Space) {
        if !drag.isDraggingSpace, !drag.justEndedDrag, !swipeSelection.justTriggered {
            onSelect(.space(space))
        }
    }

    private func handleSpaceDragBegan(_ space: Space, at windowLoc: CGPoint) {
        drag.longPressActive = true
        let loc = drag.toSidebar(windowLoc)
        // Pre-set the target to the space's own position so the gap opens
        // in-place and no other spaces shift on first render.
        if let idx = spaces.firstIndex(where: { $0.persistentModelID == space.persistentModelID }) {
            drag.spaceTargetIndex = idx
        }
        let h = drag.spaceHeaderFrames[space.persistentModelID]?.height ?? 44
        drag.beginSpaceDrag(space: space, at: loc, headerHeight: h)
    }

    private func handleSpaceDragChanged(at windowLoc: CGPoint) {
        guard drag.isDraggingSpace else { return }
        drag.location = drag.toSidebar(windowLoc)
        drag.updateSpaceTarget(in: spaces)
    }

    private func handleSpaceDragEnded() {
        drag.longPressActive = false
        guard drag.isDraggingSpace else { return }
        commitSpaceDrop()
    }

    // MARK: - Commit space drop

    private func commitSpaceDrop() {
        defer { drag.endSpaceDrag() }
        guard let dragging = drag.draggingSpace else { return }
        var ordered = spaces.filter { dragging.persistentModelID != $0.persistentModelID }
        let idx = max(0, min(drag.spaceTargetIndex, ordered.count))
        ordered.insert(dragging, at: idx)
        for (i, space) in ordered.enumerated() { space.sortIndex = i }
        try? modelContext.save()
    }

    // MARK: - Add menu

    private var addMenu: some View {
        Menu {
            Button("New Space",   systemImage: "square.grid.2x2") { pendingCreate = .space }
            Button("New List",    systemImage: "list.bullet")     { pendingCreate = .list }
            Button("New Project", systemImage: "folder")          { pendingCreate = .project }
        } label: {
            Image(systemName: "plus")
                .frame(width: 56, height: 56)
                .background(.tint, in: Circle())
                .foregroundStyle(.white)
                .shadow(radius: 4, y: 2)
        }
    }
}
