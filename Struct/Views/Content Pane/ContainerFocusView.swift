//
//  ContainerFocusView.swift
//  Struct
//
//  Created by Otto Kiefer on 05.05.2026.
//

import SwiftUI
import SwiftData

// Type-erased navigation target. `PersistentModel` is `Hashable`, so the
// enum derives `Hashable` automatically — usable directly as a
// `NavigationLink` value.
enum ContainerTarget: Hashable {
    case space(Space)
    case project(Project)
    case list(List)
}

extension ContainerTarget {
    var title: String {
        switch self {
        case .space(let s): s.name
        case .project(let p): p.title
        case .list(let l): l.title
        }
    }

    var symbol: String {
        switch self {
        case .space(let s): s.symbolName
        case .project: "folder"
        case .list(let l): l.kind == .inbox ? "tray" : "list.bullet"
        }
    }

    var items: [Item] {
        let raw: [Item]
        switch self {
        case .space(let s): raw = s.items
        case .project(let p): raw = p.items
        case .list(let l): raw = l.items
        }
        return raw.sorted { $0.sortIndex < $1.sortIndex }
    }
}

struct ContainerFocusView: View {
    let target: ContainerTarget

    var body: some View {
        Group {
            if target.items.isEmpty {
                ContentUnavailableView(
                    "No items",
                    systemImage: target.symbol,
                    description: Text("Items added to this container will appear here.")
                )
            } else {
                HStack(alignment: .top) {
                    Image(systemName: target.symbol)
                        .font(.appFont)
                        .padding(.top, 2)
                    Text(target.title)
                        .font(.appFont)
                    Spacer()
                }
                .padding(.horizontal, 15)
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(target.items) { item in
                            ItemRowView(item: item)
                        }
                    }
                    .padding()
                }
            }
        }
//        .navigationTitle(target.title)
//        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Space.self, Project.self, List.self, Item.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    List.ensureInbox(in: context)

    let space = Space(name: "Personal", sortIndex: 0)
    context.insert(space)
    let apartment = List(title: "Meetings with a lot of attendees that have a lot of work to do", space: space, sortIndex: 0)
    context.insert(apartment)

    Item.create(in: context, title: "Book moving truck",
                notes: "Compare at least three quotes before booking.",
                doDate: .now.addingTimeInterval(86_400 * 2),
                dueDate: .now.addingTimeInterval(86_400 * 7),
                sortIndex: 0, parent: .list(apartment))
    Item.create(in: context, title: "Pack kitchen",
                doDate: .now.addingTimeInterval(86_400 * 5),
                sortIndex: 1, parent: .list(apartment))
    Item.create(in: context, title: "Submit change-of-address form",
                dueDate: .now.addingTimeInterval(-86_400),   // overdue
                sortIndex: 2, parent: .list(apartment))

    let done = Item.create(in: context, title: "Forward mail",
                           sortIndex: 3, parent: .list(apartment))
    done.isCompleted = true

    return NavigationStack {
        ContainerFocusView(target: .list(apartment))
    }
    .modelContainer(container)
}
