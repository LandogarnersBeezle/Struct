//
//  ContainersSidebarView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

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

    let inbox: List?
    let spaces: [Space]

    /// Called whenever the user taps a container row or space header.
    let onSelect: (ContainerTarget) -> Void

    @Environment(\.modelContext) private var modelContext

    // MARK: Error state

    @State private var saveError: DataError?

    // MARK: Drag state

    @State private var drag = SidebarDragState()
    @State private var swipeSelection = SidebarSwipeSelection()

    // MARK: Creation card state

    @State private var showCreationCard = false
    @State private var hidePlusButton = false

    // MARK: Services

    private var deletionService: ContainerDeletionService {
        ContainerDeletionService(modelContext: modelContext)
    }

    // MARK: Layout metrics

    private let layoutMetrics = LayoutMetrics.sidebar

    // MARK: Body

    var body: some View {
        ZStack {
            // Main layout: inbox on top, scroll content below
            VStack(alignment: .leading, spacing: 0) {
                // Inbox row — stays at the top, outside the scroll area
                if let inbox {
                    InboxRow(inbox: inbox, onSelect: onSelect)
                }

                // Scroll content below inbox
                ZStack(alignment: .top) {
                    scrollContent
                    floatingCardOverlay
                    spaceFloatingCardOverlay
                }
            }
            // Bottom-right button overlay
            .overlay(alignment: .bottomTrailing) {
                Group {
                    if swipeSelection.active == nil && !showCreationCard && !hidePlusButton {
                        SidebarAddButton {
                            showCreationCardAnimated()
                        }
                    } else if swipeSelection.active != nil {
                        ContainerDeleteButton(
                            onDelete: handleDelete
                        )
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 16)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: swipeSelection.active == nil)
            }

            // Delete confirmation alert - centered on screen
            if DeleteAlertState.shared.showAlert {
                DeleteConfirmationAlert(
                    containerKind: swipeSelection.active,
                    hasOpenTasks: DeleteAlertState.shared.hasOpenTasks,
                    onDelete: { moveToInbox in
                        handleConfirmedDelete(moveToInbox: moveToInbox)
                    },
                    onCancel: {
                        DeleteAlertState.shared.showAlert = false
                        swipeSelection.clear()
                    }
                )
                .transition(.opacity)
                .zIndex(1000)
            }

            // Creation card overlay
            if showCreationCard {
                ZStack {
                    // Invisible hit-testing layer for dismissing on background tap
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissCreationCard()
                        }

                    // Creation card
                    ContainerCreationCardView(
                        onCancel: {
                            dismissCreationCard()
                        },
                        onSave: {
                            dismissCreationCard()
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1001)
                }
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .environment(drag)
        .environment(swipeSelection)
    }

    // MARK: - Space slots

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
            .animation(.spring(duration: layoutMetrics.dragSpringDuration, bounce: layoutMetrics.dragSpringBounce), value: spaceSlots)
        }
        .coordinateSpace(.named("sidebar"))
        .overlay {
            AutoScrollOverlay(
                dragState: drag,
                contentHeight: { estimateContentHeight() }
            )
        }
        .overlay {
            GeometryReader { geo in
                Color.clear
                    .preference(key: SidebarOriginKey.self,
                               value: geo.frame(in: .global).origin)
            }
        }
        .scrollDisabled(drag.longPressActive || drag.isDragging || drag.isDraggingSpace)
        .onPreferenceChange(RowFrameKey.self)         { drag.rowFrames = $0 }
        .onPreferenceChange(SpaceHeaderFrameKey.self) { drag.spaceHeaderFrames = $0 }
        .onPreferenceChange(SidebarOriginKey.self)    { drag.sidebarOriginInWindow = $0 }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .errorAlert($saveError)
        .onChange(of: drag.isDragging)      { _, on in if on { swipeSelection.clear() } }
        .onChange(of: drag.isDraggingSpace) { _, on in if on { swipeSelection.clear() } }
    }

    // MARK: - Space drop gap

    private var spaceDropGap: some View {
        RoundedRectangle(cornerRadius: layoutMetrics.dropGapCornerRadius, style: .continuous)
            .strokeBorder(Color.accentColor.opacity(0.55),
                          style: StrokeStyle(lineWidth: layoutMetrics.dropGapLineWidth, dash: layoutMetrics.dropGapDashPattern))
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
        if let child = drag.floatingCardChild {
            GeometryReader { proxy in
                DragFloatingCard(child: child, layoutMetrics: layoutMetrics)
                    .position(x: proxy.size.width / 2, y: drag.location.y)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
            .zIndex(999)
        }
    }

    // MARK: - Space header

    @ViewBuilder
    private func spaceHeader(for space: Space) -> some View {
        let isGhost = drag.draggingSpace?.persistentModelID == space.persistentModelID
        let spaceOpenCount = space.items.filter { !$0.isCompleted }.count
        let spaceAccessibilityLabel = spaceOpenCount > 0
            ? String(format: NSLocalizedString("%@, Space, %d open task%@", comment: "Space accessibility label format"),
                     space.name, spaceOpenCount, spaceOpenCount == 1 ? "" : "s")
            : String(format: NSLocalizedString("%@, Space, no open tasks", comment: "Space accessibility label"),
                     space.name)

        VStack(alignment: .leading, spacing: 0) {
            Divider()
            spaceRowContent(for: space)
                .padding(.bottom, 10)
                .draggableRowInteraction(
                    isHighlighted: swipeSelection.matches(.space(space)),
                    accessibilityLabel: spaceAccessibilityLabel,
                    onTap: { handleSpaceTap(space) },
                    onSwipeTriggered: { swipeSelection.toggle(.space(space)) },
                    onDragBegan: { handleSpaceDragBegan(space, at: $0) },
                    onDragChanged: { handleSpaceDragChanged(at: $0) },
                    onDragEnded: { handleSpaceDragEnded() }
                )
        }
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: SpaceHeaderFrameKey.self,
                                       value: [space.persistentModelID: geo.frame(in: .named("sidebar"))])
            }
        }
        .background(.background)
        .opacity(isGhost ? 0 : 1)
        .frame(height: isGhost ? 0 : nil)
        .clipped()
        .allowsHitTesting(!isGhost)
        .animation(.spring(duration: layoutMetrics.dragSpringDuration, bounce: layoutMetrics.dragSpringBounce), value: isGhost)
    }

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
                    .font(.caption)
                    .padding(.trailing, 5)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Space floating card

    @ViewBuilder
    private var spaceFloatingCardOverlay: some View {
        if let space = drag.spaceFloatingCardSpace {
            GeometryReader { proxy in
                SpaceFloatingCard(space: space, layoutMetrics: layoutMetrics)
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
            swipeSelection.clear()
            onSelect(.space(space))
        }
    }

    private func handleSpaceDragBegan(_ space: Space, at windowLoc: CGPoint) {
        drag.longPressActive = true
        let loc = drag.toSidebar(windowLoc)
        if let idx = spaces.firstIndex(where: { $0.persistentModelID == space.persistentModelID }) {
            drag.spaceTargetIndex = idx
        }
        let h = drag.spaceHeaderFrames[space.persistentModelID]?.height ?? layoutMetrics.headerHeight
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
        do {
            try modelContext.saveOrThrow()
        } catch let error as DataError {
            saveError = error
        } catch {
            saveError = .saveFailed(error)
        }
    }

    // MARK: - Delete handling

    private func handleDelete() {
        guard let active = swipeSelection.active else { return }
        DeleteAlertState.shared.hasOpenTasks = deletionService.openTaskCount(in: active) > 0
        DeleteAlertState.shared.showAlert = true
    }

    private func handleConfirmedDelete(moveToInbox: Bool) {
        guard let active = swipeSelection.active else { return }
        do {
            switch active {
            case .list(let l):    try deletionService.deleteList(l, moveToInbox: moveToInbox)
            case .project(let p): try deletionService.deleteProject(p, moveToInbox: moveToInbox)
            case .space(let s):   try deletionService.deleteSpace(s, moveToInbox: moveToInbox)
            }
        } catch let error as DataError {
            saveError = error
        } catch {
            saveError = .saveFailed(error)
        }
        DeleteAlertState.shared.showAlert = false
        swipeSelection.clear()
    }

    // MARK: - Show/Dismiss Creation Card

    private func showCreationCardAnimated() {
        // Hide the plus button immediately before showing the card
        hidePlusButton = true
        
        // Show the card after a brief delay to ensure button is hidden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCreationCard = true
            }
        }
    }

    private func dismissCreationCard() {
        // Hide the card first
        withAnimation(.easeInOut(duration: 0.2)) {
            showCreationCard = false
        }
        
        // Keep button hidden during keyboard dismissal, then show it after
        // Keyboard dismissal typically takes about 0.25-0.3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.2)) {
                hidePlusButton = false
            }
        }
    }

    // MARK: - Content Height Estimation

    private func estimateContentHeight() -> CGFloat {
        layoutMetrics.estimateContentHeight(
            rowCount: spaces.reduce(0) { $0 + Containers.children(of: $1).count },
            headerCount: spaces.count,
            hasInbox: inbox != nil
        )
    }
}
