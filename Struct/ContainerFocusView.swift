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
                SwiftUI.List {
                    ForEach(target.items) { item in
                        ItemRow(item: item)
                    }
                }
            }
        }
        .navigationTitle(target.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isCompleted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.isCompleted)
                if let due = item.dueDate {
                    Text(due, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
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

    let space = Space(name: "Personal", sortIndex: 0)
    context.insert(space)
    let groceries = List(title: "Groceries", space: space, sortIndex: 0)
    context.insert(groceries)
    Item.create(in: context, title: "Milk", sortIndex: 0, parent: .list(groceries))
    Item.create(in: context, title: "Bread", sortIndex: 1, parent: .list(groceries))
    Item.create(in: context, title: "Eggs", dueDate: .now, sortIndex: 2, parent: .list(groceries))

    return NavigationStack {
        ContainerFocusView(target: .list(groceries))
    }
    .modelContainer(container)
}
