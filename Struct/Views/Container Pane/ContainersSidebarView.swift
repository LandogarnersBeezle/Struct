//
//  ContainersSidebarView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI

// MARK: - ContainersSidebarView

/// Pure layout/composition for the leading sidebar pane.
///
/// Renders the inbox row, one `SpaceSectionView` per space, and the floating
/// add menu. Owns no queries and no navigation state — all data and callbacks
/// flow in from `ContainersView`.
struct ContainersSidebarView: View {

    let inbox: List?
    let spaces: [Space]

    /// Called whenever the user taps a container row or space header.
    let onSelect: (ContainerTarget) -> Void

    /// Drives the "create container" sheet; owned by the parent so the sheet
    /// survives sidebar hide/show transitions.
    @Binding var pendingCreate: CreateKind?

    // MARK: Body

    var body: some View {
        // Inbox row
        if let inbox {
            Button { onSelect(.list(inbox)) } label: {
                ContainerRowView(symbol: "tray", title: inbox.title, sortIndex: 0,
                                 color: List.containerColor)
            }
            .buttonStyle(.plain)
            .padding(5)
        }

        // Space sections — each SpaceSectionView owns its own @Query so
        // new lists and projects appear immediately after creation.
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(spaces) { space in
                    SpaceSectionView(space: space, onSelect: onSelect)
                }
            }
            .padding(5)
        }
//        .background(Color(UIColor.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { addMenu.padding() }
        .sheet(item: $pendingCreate) { CreateContainerView(kind: $0) }
    }

    // MARK: - Add menu

    private var addMenu: some View {
        Menu {
            Button("New Space",   systemImage: "square.grid.2x2") { pendingCreate = .space }
            Button("New List",    systemImage: "list.bullet")     { pendingCreate = .list }
            Button("New Project", systemImage: "folder")          { pendingCreate = .project }
        } label: {
            Image(systemName: "plus")
                .font(.appTitle2)
                .frame(width: 56, height: 56)
                .background(.tint, in: Circle())
                .foregroundStyle(.white)
                .shadow(radius: 4, y: 2)
        }
    }
}
