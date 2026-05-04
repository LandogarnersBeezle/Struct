//
//  ContentView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

struct ContainersView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<List> { $0.kindRaw == "inbox" })
    private var inboxLists: [List]

    @Query(sort: \Space.sortIndex) private var spaces: [Space]

    @Query(filter: #Predicate<List> { $0.isLoose && $0.kindRaw != "inbox" },
           sort: \List.sortIndex)
    private var looseLists: [List]

    @Query(filter: #Predicate<Project> { $0.isLoose },
           sort: \Project.sortIndex)
    private var looseProjects: [Project]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let inbox = inboxLists.first {
                        section(title: "Inbox") {
                            row(symbol: "tray", title: inbox.title)
                        }
                    }

                    if !looseLists.isEmpty {
                        section(title: "Loose Lists") {
                            ForEach(looseLists) { list in
                                row(symbol: "list.bullet", title: list.title)
                            }
                        }
                    }

                    if !looseProjects.isEmpty {
                        section(title: "Loose Projects") {
                            ForEach(looseProjects) { project in
                                row(symbol: "folder", title: project.title)
                            }
                        }
                    }

                    ForEach(spaces) { space in
                        section(title: space.name) {
                            ForEach(Containers.children(of: space)) { child in
                                switch child {
                                case .list(let list):
                                    row(symbol: "list.bullet", title: list.title)
                                case .project(let project):
                                    row(symbol: "folder", title: project.title)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                addMenu
                    .padding()
            }
        }
    }

    private var addMenu: some View {
        Menu {
            Button("New Space", systemImage: "square.grid.2x2", action: addSpace)
            Button("New Project", systemImage: "folder", action: addProject)
            Button("New List", systemImage: "list.bullet", action: addList)
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
                .background(.tint, in: Circle())
                .foregroundStyle(.white)
                .shadow(radius: 4, y: 2)
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func row(symbol: String, title: String) -> some View {
        HStack {
            Image(systemName: symbol)
                .frame(width: 24)
            Text(title)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func addSpace() {
        let index = Space.nextSortIndex(context: modelContext)
        modelContext.insert(Space(name: "New Space", sortIndex: index))
    }

    private func addProject() {
        let index = Containers.nextSortIndex(in: nil, context: modelContext)
        modelContext.insert(Project(title: "New Project", sortIndex: index))
    }

    private func addList() {
        let index = Containers.nextSortIndex(in: nil, context: modelContext)
        modelContext.insert(List(title: "New List", kind: .user, sortIndex: index))
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Space.self, Project.self, List.self, Item.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    List.ensureInbox(in: container.mainContext)
    return ContainersView()
        .modelContainer(container)
}
