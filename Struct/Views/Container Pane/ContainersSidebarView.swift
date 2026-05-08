//
//  ContainersSidebarView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - Sidebar

/// The leading sidebar pane: inbox row, space sections, and the floating add menu.
///
/// State that affects the *split layout* (selection, layout transitions) stays in
/// `ContainersView`; this view communicates back through the `onSelect` closure and
/// the `pendingCreate` binding.
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Inbox row
                if let inbox {
                    Button { onSelect(.list(inbox)) } label: {
                        ContainerRowView(symbol: "tray", title: inbox.title, sortIndex: 0,
                                         color: List.containerColor)
                    }
                    .buttonStyle(.plain)
                }

                // Space sections
                ForEach(spaces) { space in
                    spaceSection(space: space)
                }
            }
            .padding(5)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { addMenu.padding() }
        .sheet(item: $pendingCreate) { CreateContainerView(kind: $0) }
    }

    // MARK: - Space section

    @ViewBuilder
    private func spaceSection(space: Space) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Space header — tapping selects the space as the detail target
            Button { onSelect(.space(space)) } label: {
                Label {
                    Text(space.name).lineLimit(1)
                } icon: {
                    Image(systemName: space.symbolName)
                        .foregroundStyle(Space.containerColor)
                        .frame(width: 24)
                }
                .font(.appHeadline)
            }
            .buttonStyle(.plain)

            // Children (lists then projects)
            ForEach(Containers.children(of: space)) { child in
                switch child {
                case .list(let list):
                    Button { onSelect(.list(list)) } label: {
                        ContainerRowView(symbol: "list.bullet", title: list.title,
                                         sortIndex: list.sortIndex, color: List.containerColor)
                    }
                    .buttonStyle(.plain)
                case .project(let project):
                    Button { onSelect(.project(project)) } label: {
                        ContainerRowView(symbol: "folder", title: project.title,
                                         sortIndex: project.sortIndex, color: Project.containerColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 8)
        }
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
