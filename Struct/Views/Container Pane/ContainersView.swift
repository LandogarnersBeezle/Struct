//
//  ContainersView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - ContainersView

/// Navigation host and data coordinator for the container pane.
///
/// Responsibilities:
///  - Fetches the inbox list and the ordered space list via `@Query`.
///  - On iPad: Uses `NavigationSplitView` with sidebar always visible
///  - On iPhone: Uses `NavigationStack` with push navigation
///  - Sets default selection to Inbox on launch
///
/// Layout and per-space data are delegated to `ContainersSidebarView` and
/// `SpaceSectionView` respectively.
struct ContainersView: View {

    @Query(filter: #Predicate<List> { $0.kindRaw == "inbox" })
    private var inboxLists: [List]

    @Query(sort: \Space.sortIndex) private var spaces: [Space]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // iPad: selected container for the detail view
    @State private var selectedTarget: ContainerTarget? = nil
    
    // iPhone: navigation path for push-based navigation
    @State private var navigationPath: [ContainerTarget] = []

    // MARK: Body

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad layout: NavigationSplitView with sidebar always visible
                NavigationSplitView(columnVisibility: .constant(.all)) {
                    // Sidebar column (iPad: hide action button since "+ Container" is in detail view)
                    ContainersSidebarView(
                        inbox: inboxLists.first,
                        spaces: spaces,
                        selectedTarget: selectedTarget,
                        showActionButton: false,
                        onSelect: { target in
                            selectedTarget = target
                        }
                    )
                    .padding(.horizontal)
                    .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
                    .toolbar(.hidden, for: .navigationBar)
                } detail: {
                    // Detail column - shows selected container or placeholder
                    if let target = selectedTarget {
                        ContainerFocusView(target: target, showBackButton: false)
                            .toolbar(.hidden, for: .navigationBar)
                    } else {
                        // Placeholder when nothing is selected
                        ContentUnavailableView(
                            "Select a Container",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Choose a container from the sidebar to view its items.")
                        )
                        .toolbar(.hidden, for: .navigationBar)
                    }
                }
                .navigationSplitViewStyle(.automatic)
                .toolbar(.hidden, for: .navigationBar)
            } else {
                // iPhone layout: NavigationStack with push navigation
                NavigationStack(path: $navigationPath) {
                    ContainersSidebarView(
                        inbox: inboxLists.first,
                        spaces: spaces,
                        onSelect: { target in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                navigationPath = [target]
                            }
                        }
                    )
                    .padding(.horizontal)
                    .navigationDestination(for: ContainerTarget.self) { target in
                        ContainerFocusView(target: target) { newTarget in
                            navigationPath = [newTarget]
                        }
                    }
                }
            }
        }
        // Migrate any space whose lists and projects still use separate
        // sortIndex namespaces into the unified single namespace.
        // Idempotent — safe to run on every launch.
        .onAppear {
            for space in spaces {
                Containers.ensureUnifiedSortOrder(for: space)
            }
            try? modelContext.save()
            
            // Always select Inbox by default on launch
            if let inbox = inboxLists.first {
                selectedTarget = .list(inbox)
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
    let l1 = List(title: "L1", space: personal, sortIndex: 2)
    let l2 = List(title: "L2", space: personal, sortIndex: 3)
    let l3 = List(title: "L3", space: personal, sortIndex: 4)
    let l4 = List(title: "L4", space: personal, sortIndex: 5)
    let apartment = Project(title: "Apartment Move", space: personal, sortIndex: 0)
    let literature = Project(title: "Literature", space: personal, sortIndex: 1)
    let music = Project(title: "Music", space: personal, sortIndex: 2)
    let screen = Project(title: "Screen", space: personal, sortIndex: 3)
    let games = Project(title: "Games", space: personal, sortIndex: 4)
    let marathon = Project(title: "Marathon Training", space: personal, sortIndex: 5)
    context.insert(groceries)
    context.insert(books)
    context.insert(l1)
    context.insert(l2)
    context.insert(l3)
    context.insert(l4)
    context.insert(apartment)
    context.insert(literature)
    context.insert(music)
    context.insert(screen)
    context.insert(games)
    context.insert(marathon)

    let meetings = List(title: "Meetings with a lot of attendees that have a lot of work to do", space: work, sortIndex: 0)
    let launch = Project(title: "Q3 Launch", space: work, sortIndex: 0)
    let dp1 = Project(title: "DP1", space: work, sortIndex: 1)
    let dp2 = Project(title: "DP2", space: work, sortIndex: 2)
    let dp3 = Project(title: "DP3", space: work, sortIndex: 3)
    let dp4 = Project(title: "DP4", space: work, sortIndex: 4)
    let dp5 = Project(title: "DP5", space: work, sortIndex: 5)
    let hiring = Project(title: "Hiring", space: work, sortIndex: 6)
    context.insert(meetings)
    context.insert(launch)
    context.insert(dp1)
    context.insert(dp2)
    context.insert(dp3)
    context.insert(dp4)
    context.insert(dp5)
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