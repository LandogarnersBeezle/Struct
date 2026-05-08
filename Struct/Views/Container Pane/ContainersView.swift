//
//  ContainersView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - View

struct ContainersView: View {

    @Query(filter: #Predicate<List> { $0.kindRaw == "inbox" })
    private var inboxLists: [List]

    @Query(sort: \Space.sortIndex) private var spaces: [Space]

    @State private var navigationPath: [ContainerTarget] = []
    @State private var pendingCreate: CreateKind?

    // MARK: Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ContainersSidebarView(
                inbox: inboxLists.first,
                spaces: spaces,
                onSelect: { navigationPath = [$0] },
                pendingCreate: $pendingCreate
            )
            .navigationDestination(for: ContainerTarget.self) { target in
                ContainerFocusView(target: target) { newTarget in
                    navigationPath = [newTarget]
                }
            }
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

    let meetings = List(title: "Meetings with a lot of attendees that have a lot of work to do", space: work, sortIndex: 0)
    let launch = Project(title: "Q3 Launch", space: work, sortIndex: 0)
    let hiring = Project(title: "Hiring", space: work, sortIndex: 1)
    context.insert(meetings)
    context.insert(launch)
    context.insert(hiring)

    // Inbox items (no parent → routed to Inbox by `Item.create`).
    Item.create(in: context, title: "Reply to landlord",
                notes: "Re: broken heater — reply before end of day.",
                doDate: .now,
                sortIndex: 0)
    Item.create(in: context, title: "Pick up dry cleaning", sortIndex: 1)
    Item.create(in: context, title: "Schedule dentist",
                doDate: .now.addingTimeInterval(86_400),
                dueDate: .now.addingTimeInterval(86_400 * 3),
                sortIndex: 2)

    // Groceries — simple list, no dates needed
    Item.create(in: context, title: "Milk",      sortIndex: 0, parent: .list(groceries))
    Item.create(in: context, title: "Bread",     sortIndex: 1, parent: .list(groceries))
    Item.create(in: context, title: "Eggs",      sortIndex: 2, parent: .list(groceries))
    Item.create(in: context, title: "Olive oil", sortIndex: 3, parent: .list(groceries))

    // Books — no dates
    Item.create(in: context, title: "Project Hail Mary",        sortIndex: 0, parent: .list(books))
    Item.create(in: context, title: "The Pragmatic Programmer", sortIndex: 1, parent: .list(books))

    // Apartment Move — mixed dates and notes
    Item.create(in: context, title: "Book moving truck",
                notes: "Compare at least three quotes before booking.",
                doDate: .now.addingTimeInterval(86_400 * 2),
                dueDate: .now.addingTimeInterval(86_400 * 7),
                sortIndex: 0, parent: .project(apartment))
    Item.create(in: context, title: "Pack kitchen",
                doDate: .now.addingTimeInterval(86_400 * 5),
                sortIndex: 1, parent: .project(apartment))
    Item.create(in: context, title: "Forward mail", sortIndex: 2, parent: .project(apartment))

    // Marathon Training
    Item.create(in: context, title: "Long run — 18km",
                doDate: .now,
                sortIndex: 0, parent: .project(marathon))
    Item.create(in: context, title: "Buy new shoes",
                dueDate: .now.addingTimeInterval(86_400 * 4),
                sortIndex: 1, parent: .project(marathon))

    // Meetings
    Item.create(in: context, title: "Standup notes", sortIndex: 0, parent: .list(meetings))
    Item.create(in: context, title: "1:1 with manager",
                doDate: .now,
                dueDate: .now.addingTimeInterval(86_400),
                sortIndex: 1, parent: .list(meetings))

    // Q3 Launch
    Item.create(in: context, title: "Finalize launch plan",
                doDate: .now.addingTimeInterval(86_400 * 3),
                sortIndex: 0, parent: .project(launch))
    Item.create(in: context, title: "Draft press release", sortIndex: 1, parent: .project(launch))
    Item.create(in: context, title: "QA sign-off",
                doDate: .now.addingTimeInterval(-86_400 * 16),
                dueDate: .now.addingTimeInterval(-86_400 * 14),
                sortIndex: 2, parent: .project(launch))

    // Hiring
    Item.create(in: context, title: "Review CVs",
                doDate: .now.addingTimeInterval(86_400),
                sortIndex: 0, parent: .project(hiring))
    Item.create(in: context, title: "Schedule onsites", sortIndex: 1, parent: .project(hiring))

    // Items attached directly to a Space (rather than a List/Project).
    Item.create(in: context, title: "Plan weekend trip",      sortIndex: 0, parent: .space(personal))
    Item.create(in: context, title: "Review quarterly goals", sortIndex: 0, parent: .space(work))

    return ContainersView()
        .modelContainer(container)
}
