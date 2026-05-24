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
                ContainerRowView(symbol: "tray", title: inbox.title,
                                 openTaskCount: inbox.items.filter { !$0.isCompleted }.count,
                                 color: List.containerColor)
            }
            .buttonStyle(ContainerRowButtonStyle())
            .padding(5)
        }

        // Space sections — each SpaceSectionView owns its own @Query so
        // new lists and projects appear immediately after creation.
        // LazyVStack with pinnedViews keeps each space header visible while
        // its children scroll underneath it.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(spaces) { space in
                    Section {
                        SpaceSectionView(space: space, onSelect: onSelect)
                            .padding(.horizontal, 5)
                            .padding(.bottom, 8)
                    } header: {
                        spaceHeader(for: space)
                    }
                }
            }
        }
//        .background(Color(UIColor.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { addMenu.padding() }
        .sheet(item: $pendingCreate) { CreateContainerView(kind: $0) }
    }

    // MARK: - Space header (used as sticky section header)

    private func spaceHeader(for space: Space) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            Button { onSelect(.space(space)) } label: {
                HStack {
                    Image(systemName: space.symbolName)
                        .foregroundStyle(Space.containerColor)
                        .frame(width: 24)
                    Text(space.name)
                        .lineLimit(1)
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
                .padding(.bottom, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(ContainerRowButtonStyle())
        }
        // Solid background so content scrolling behind doesn't show through.
        .background(.background)
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
