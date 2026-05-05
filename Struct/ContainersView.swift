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
                        NavigationLink(value: ContainerTarget.list(inbox)) {
                            ContainerRowView(symbol: "tray", title: inbox.title, sortIndex: 0)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(spaces) { space in
                        section(title: space.name, symbol: space.symbolName, target: .space(space)) {
                            ForEach(Containers.children(of: space)) { child in
                                switch child {
                                case .list(let list):
                                    NavigationLink(value: ContainerTarget.list(list)) {
                                        ContainerRowView(symbol: "list.bullet", title: list.title, sortIndex: list.sortIndex)
                                    }
                                    .buttonStyle(.plain)
                                case .project(let project):
                                    NavigationLink(value: ContainerTarget.project(project)) {
                                        ContainerRowView(symbol: "folder", title: project.title, sortIndex: project.sortIndex)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.leading, 16)
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
            .navigationDestination(for: ContainerTarget.self) { target in
                ContainerFocusView(target: target)
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
                                        symbol: String,
                                        target: ContainerTarget,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(value: target) {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: symbol)
                        .frame(width: 24)
                }
                .font(.headline)
            }
            .buttonStyle(.plain)
            content()
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Space.self, Project.self, List.self, Item.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    List.ensureInbox(in: context)

    let personal = Space(name: "Personal", sortIndex: 0)
    let work = Space(name: "Work", sortIndex: 1)
    context.insert(personal)
    context.insert(work)

    let groceries = List(title: "Groceries", space: personal, sortIndex: 0)
    let books = List(title: "Books to Read", space: personal, sortIndex: 1)
    let apartment = Project(title: "Apartment Move", space: personal, sortIndex: 0)
    let marathon = Project(title: "Marathon Training", space: personal, sortIndex: 1)
    context.insert(groceries)
    context.insert(books)
    context.insert(apartment)
    context.insert(marathon)

    let meetings = List(title: "Meetings", space: work, sortIndex: 0)
    let launch = Project(title: "Q3 Launch", space: work, sortIndex: 0)
    let hiring = Project(title: "Hiring", space: work, sortIndex: 1)
    context.insert(meetings)
    context.insert(launch)
    context.insert(hiring)

    // Inbox items (no parent → routed to Inbox by `Item.create`).
    Item.create(in: context, title: "Reply to landlord", sortIndex: 0)
    Item.create(in: context, title: "Pick up dry cleaning", sortIndex: 1)
    Item.create(in: context, title: "Schedule dentist", dueDate: .now.addingTimeInterval(86_400 * 3), sortIndex: 2)

    Item.create(in: context, title: "Milk", sortIndex: 0, parent: .list(groceries))
    Item.create(in: context, title: "Bread", sortIndex: 1, parent: .list(groceries))
    Item.create(in: context, title: "Eggs", sortIndex: 2, parent: .list(groceries))
    Item.create(in: context, title: "Olive oil", sortIndex: 3, parent: .list(groceries))

    Item.create(in: context, title: "Project Hail Mary", sortIndex: 0, parent: .list(books))
    Item.create(in: context, title: "The Pragmatic Programmer", sortIndex: 1, parent: .list(books))

    Item.create(in: context, title: "Book moving truck", dueDate: .now.addingTimeInterval(86_400 * 7), sortIndex: 0, parent: .project(apartment))
    Item.create(in: context, title: "Pack kitchen", sortIndex: 1, parent: .project(apartment))
    Item.create(in: context, title: "Forward mail", sortIndex: 2, parent: .project(apartment))

    Item.create(in: context, title: "Long run — 18km", sortIndex: 0, parent: .project(marathon))
    Item.create(in: context, title: "Buy new shoes", sortIndex: 1, parent: .project(marathon))

    Item.create(in: context, title: "Standup notes", sortIndex: 0, parent: .list(meetings))
    Item.create(in: context, title: "1:1 with manager", dueDate: .now.addingTimeInterval(86_400), sortIndex: 1, parent: .list(meetings))

    Item.create(in: context, title: "Finalize launch plan", sortIndex: 0, parent: .project(launch))
    Item.create(in: context, title: "Draft press release", sortIndex: 1, parent: .project(launch))
    Item.create(in: context, title: "QA sign-off", dueDate: .now.addingTimeInterval(86_400 * 14), sortIndex: 2, parent: .project(launch))

    Item.create(in: context, title: "Review CVs", sortIndex: 0, parent: .project(hiring))
    Item.create(in: context, title: "Schedule onsites", sortIndex: 1, parent: .project(hiring))

    // Items attached directly to a Space (rather than a List/Project).
    Item.create(in: context, title: "Plan weekend trip", sortIndex: 0, parent: .space(personal))
    Item.create(in: context, title: "Review quarterly goals", sortIndex: 0, parent: .space(work))

    return ContainersView()
        .modelContainer(container)
}
