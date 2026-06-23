//
//  SpaceSectionView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - SpaceSectionView

/// Renders one Space's children (lists and projects) with tap-to-select and
/// swipe-to-delete. Drag-and-drop reordering functionality has been removed.
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(children, id: \.id) { child in
                rowView(for: child)
            }
        }
        .padding(.leading, 8)
        .errorAlert($saveError)
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
        .padding(.bottom, 8)
    }

    // MARK: - Gesture callbacks

    private func handleTap(_ child: ContainerChild) {
        if !swipeSelection.justTriggered {
            swipeSelection.clear()
            onSelect(child.target)
        }
    }
}