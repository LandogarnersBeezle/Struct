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
    @Query(sort: \Project.sortIndex) private var projects: [Project]

    @Query(filter: #Predicate<List> { $0.kindRaw != "inbox" },
           sort: \List.sortIndex)
    private var userLists: [List]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let inbox = inboxLists.first {
                        section(title: "Inbox") {
                            row(symbol: "tray", title: inbox.title)
                        }
                    }

                    section(title: "Spaces") {
                        ForEach(spaces) { space in
                            row(symbol: space.symbolName, title: space.name)
                        }
                    }

                    section(title: "Projects") {
                        ForEach(projects) { project in
                            row(symbol: "folder", title: project.title)
                        }
                    }

                    section(title: "Lists") {
                        ForEach(userLists) { list in
                            row(symbol: "list.bullet", title: list.title)
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
        modelContext.insert(Space(name: "New Space"))
    }

    private func addProject() {
        modelContext.insert(Project(title: "New Project"))
    }

    private func addList() {
        modelContext.insert(List(title: "New List", kind: .user))
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
