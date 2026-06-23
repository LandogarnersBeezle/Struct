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
/// Displays the inbox row at the top, followed by a scrollable list of spaces
/// each containing their lists and projects. Supports tap-to-select and
/// swipe-to-delete. Drag-and-drop reordering has been removed.
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
        .coordinateSpace(.named("sidebar"))
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .errorAlert($saveError)
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