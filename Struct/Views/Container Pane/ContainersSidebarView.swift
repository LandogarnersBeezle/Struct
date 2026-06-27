//
//  ContainersSidebarView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - ContainersSidebarView

/// Layout host for the leading sidebar pane.
///
/// Displays the inbox row at the top, followed by a scrollable list of spaces
/// each containing their lists and projects. Supports tap-to-select,
/// swipe-to-delete, and long-press drag-to-reorder spaces.
struct ContainersSidebarView: View {

    let inbox: List?
    let spaces: [Space]
    /// The currently selected container target (used for highlighting on iPad)
    var selectedTarget: ContainerTarget? = nil
    /// Whether to show the bottom-right action button (plus/delete).
    /// On iPad, this is hidden because the "+ Container" button is in the detail view.
    var showActionButton: Bool = true

    /// Called whenever the user selects a container row or space header.
    let onSelect: (ContainerTarget) -> Void

    @Environment(\.modelContext) private var modelContext

    // MARK: Error state

    @State private var saveError: DataError?

    // MARK: Swipe selection

    @State private var swipeSelection = SidebarSwipeSelection()

    // MARK: Creation card state

    @State private var showCreationCard = false
    @State private var hidePlusButton = false

    // MARK: Services

    private var deletionService: ContainerDeletionService {
        ContainerDeletionService(modelContext: modelContext)
    }
    
    // MARK: Space reordering state

    /// The Y position where the insertion line should be drawn during space reorder drag.
    @State private var spaceInsertionLineY: CGFloat? = nil
    
    /// Rendered frames of space headers in the sidebar coordinate space.
    @State private var spaceFrames: [PersistentIdentifier: CGRect] = [:]
    
    /// Coordinate space name for the sidebar's space list.
    private var sidebarCoordName: String {
        "sidebarSpaces"
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // Main layout: inbox on top, scroll content below
            VStack(alignment: .leading, spacing: 0) {
                // Inbox row — stays at the top, outside the scroll area
                if let inbox {
                    InboxRow(inbox: inbox, isSelected: selectedTarget == .list(inbox), onSelect: onSelect)
                }
                Spacer(minLength: 10)
                // Scroll content below inbox
                scrollContent
            }
            // Bottom-right button overlay (controlled by showActionButton parameter)
            // On iPad, showActionButton is false because the "+ Container" button is in the detail view
            .overlay(alignment: .bottomTrailing) {
                if showActionButton {
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
        .environment(swipeSelection)
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(spaces, id: \.persistentModelID) { space in
                    // When a space is being dragged, only show space headers (no children)
                    if SidebarCollapseState.shared.draggingSpace != nil {
                        // In collapse mode, show only the space header
                        spaceHeader(for: space)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 4)
                    } else {
                        // Normal mode: show space with its children
                        Section {
                            SpaceSectionView(space: space, selectedTarget: selectedTarget, onSelect: onSelect)
                                .padding(.horizontal, 5)
                                .padding(.bottom, 8)
                        } header: {
                            spaceHeader(for: space)
                        }
                    }
                }
            }
            .coordinateSpace(.named(sidebarCoordName))
        }
        .coordinateSpace(.named("sidebar"))
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .errorAlert($saveError)
        // Track space header frames for insertion line calculation
        .onPreferenceChange(SpaceFramePreferenceKey.self) { frames in
            for frame in frames {
                spaceFrames[frame.id] = frame.rect
            }
        }
        // Green insertion line overlay for space reordering
        .overlay(alignment: .topLeading) {
            if let lineY = spaceInsertionLineY {
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 200, height: 2)
                    .position(x: 100, y: lineY)
                    .animation(.easeOut(duration: 0.15), value: lineY)
            }
        }
        // Drop target for space reordering
        .onDrop(
            of: [UTType.spaceDrag],
            delegate: SpaceInsertionLineDropDelegate(
                spaces: spaces,
                spaceFrames: spaceFrames,
                insertionLineY: $spaceInsertionLineY
            ) { dragData in
                handleSpaceReorderDrop(dragData)
            }
        )
    }

    // MARK: - Space header

    @ViewBuilder
    private func spaceHeader(for space: Space) -> some View {
        let isSelected = selectedTarget == .space(space)
        let spaceOpenCount = space.items.filter { !$0.isCompleted }.count
        let spaceAccessibilityLabel = spaceOpenCount > 0
            ? String(format: NSLocalizedString("%@, Space, %d open task%@", comment: "Space accessibility label format"),
                     space.name, spaceOpenCount, spaceOpenCount == 1 ? "" : "s")
            : String(format: NSLocalizedString("%@, Space, no open tasks", comment: "Space accessibility label"),
                     space.name)

        VStack(alignment: .leading, spacing: 0) {
            spaceRowContent(for: space)
                .padding(.bottom, 10)
                .swipeableRowInteraction(
                    isHighlighted: swipeSelection.matches(.space(space)),
                    accessibilityLabel: spaceAccessibilityLabel,
                    onTap: { handleSpaceTap(space) },
                    onSwipeTriggered: { swipeSelection.toggle(.space(space)) }
                )
                // Track space header frame for insertion line calculation
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: SpaceFramePreferenceKey.self,
                                value: [SpaceFrame(
                                    id: space.persistentModelID,
                                    rect: geo.frame(in: .named(sidebarCoordName))
                                )]
                            )
                    }
                )
                // Add long press gesture to collapse all spaces before drag starts
                .onLongPressGesture(
                    minimumDuration: 0.5,
                    pressing: { isPressed in
                        if isPressed {
                            // User has pressed long enough - collapse all spaces
                            withAnimation(.easeInOut(duration: 0.25)) {
                                SidebarCollapseState.shared.draggingSpace = space
                            }
                        }
                        // Note: Don't expand when isPressed becomes false here,
                        // because the drag might still be in progress.
                        // Expansion will happen in handleSpaceReorderDrop after drop completes.
                    },
                    perform: {
                        // Long press recognized - space is now ready to drag
                        // The collapse already happened in the pressing callback
                    }
                )
                // Make space header draggable on long press
                .draggable(SpaceDragData(spaceID: space.persistentModelID)) {
                    // Drag preview
                    spaceRowContent(for: space)
                        .frame(maxWidth: 240)
                        .scaleEffect(0.8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                }
        }
        // Opaque background to prevent content from showing through when sticky
        .background(Color(.systemBackground))
        // Selection highlight on top of opaque background
        .overlay(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .cornerRadius(8)
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

    // MARK: - Space gesture callbacks

    private func handleSpaceTap(_ space: Space) {
        if !swipeSelection.justTriggered {
            swipeSelection.clear()
            onSelect(.space(space))
        }
    }
    
    // MARK: - Space Reordering
    
    /// Handles the drop when reordering spaces.
    private func handleSpaceReorderDrop(_ space: Space) {
        defer {
            // Always reset collapse state when drop completes
            SidebarCollapseState.shared.draggingSpace = nil
        }
        
        // Find the insertion index based on the line position
        guard let lineY = spaceInsertionLineY else {
            spaceInsertionLineY = nil
            return
        }
        
        // Compute insertion index from the line position
        // Only consider space header frames, not children
        let insertionIndex: Int = {
            guard !spaces.isEmpty else { return 0 }
            
            // Find the space header whose top edge is at or just past the line's Y
            for (i, s) in spaces.enumerated() {
                if let rect = spaceFrames[s.persistentModelID], rect.minY >= lineY {
                    return i
                }
            }
            
            // If line is past all headers, insert at the end
            return spaces.count
        }()
        
        // Clear the insertion line
        spaceInsertionLineY = nil
        
        // Perform the reorder with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            Containers.moveSpace(space, to: insertionIndex, context: modelContext)
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
}