//
//  SpaceSectionView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - SpaceSectionView

/// Renders one Space's header and its children (lists then projects).
///
/// Owning its own `@Query` for lists and projects means SwiftData notifies
/// this view directly whenever a child is inserted or removed — no
/// relationship-traversal lag, no need to navigate away and back.
struct SpaceSectionView: View {

    let space: Space
    let onSelect: (ContainerTarget) -> Void

    @Query private var lists: [List]
    @Query private var projects: [Project]

    init(space: Space, onSelect: @escaping (ContainerTarget) -> Void) {
        self.space = space
        self.onSelect = onSelect
        let id = space.persistentModelID
        _lists = Query(
            filter: #Predicate<List> {
                $0.space?.persistentModelID == id && $0.kindRaw != "inbox"
            },
            sort: \.sortIndex
        )
        _projects = Query(
            filter: #Predicate<Project> {
                $0.space.persistentModelID == id
            },
            sort: \.sortIndex
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Space header — tapping selects the space as the detail target
            Button { onSelect(.space(space)) } label: {
                HStack {
                    Image(systemName: space.symbolName)
                        .foregroundStyle(Space.containerColor)
                        .frame(width: 24)
                    Text(space.name)
                        .lineLimit(1)
                        .font(.appHeadline)
                    Spacer()
                    let openCount = space.items.filter { !$0.isCompleted }.count
                    if openCount > 0 {
                        Text("\(openCount)")
                            .font(.appFont.weight(.light))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Lists
            ForEach(lists) { list in
                Button { onSelect(.list(list)) } label: {
                    ContainerRowView(symbol: "list.bullet", title: list.title,
                                     openTaskCount: list.items.filter { !$0.isCompleted }.count,
                                     color: List.containerColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 8)

            // Projects
            ForEach(projects) { project in
                Button { onSelect(.project(project)) } label: {
                    ContainerRowView(symbol: "folder", title: project.title,
                                     openTaskCount: project.items.filter { !$0.isCompleted }.count,
                                     color: Project.containerColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 8)
        }
    }
}
