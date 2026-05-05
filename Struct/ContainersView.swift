//
//  ContentView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

struct ContainersView: View {
    @Query(filter: #Predicate<List> { $0.kindRaw == "inbox" })
    private var inboxLists: [List]

    @Query(sort: \Space.sortIndex) private var spaces: [Space]

    @State private var pendingCreate: CreateKind?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let inbox = inboxLists.first {
                        section(title: "Inbox") {
                            row(symbol: "tray", title: inbox.title)
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
            .sheet(item: $pendingCreate) { kind in
                CreateContainerView(kind: kind)
            }
        }
    }

    private var addMenu: some View {
        Menu {
            Button("New Space", systemImage: "square.grid.2x2") { pendingCreate = .space }
            Button("New Project", systemImage: "folder") { pendingCreate = .project }
            Button("New List", systemImage: "list.bullet") { pendingCreate = .list }
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
