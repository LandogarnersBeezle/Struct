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

    var color: Color {
        switch self {
        case .space:   Space.containerColor
        case .list:    List.containerColor
        case .project: Project.containerColor
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
    /// Called when the user selects a container from the search bar.
    /// The owner should replace the navigation path with the new target so
    /// the back button returns to the root rather than the previous detail view.
    var onNavigate: (ContainerTarget) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    // MARK: Search data
    @Query(filter: #Predicate<List> { $0.kindRaw == "inbox" })
    private var inboxLists: [List]

    @Query(sort: \Space.sortIndex) private var spaces: [Space]

    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    // All containers in the same order as ContainersSidebarView:
    // Inbox → (Space → lists → projects) per space.
    // `isChild` is true for lists/projects that belong to a space (drives indentation).
    private typealias SearchEntry = (target: ContainerTarget, isChild: Bool)

    private var allContainers: [SearchEntry] {
        var result: [SearchEntry] = []
        if let inbox = inboxLists.first {
            result.append((target: .list(inbox), isChild: false))
        }
        for space in spaces {
            result.append((target: .space(space), isChild: false))
            for child in Containers.children(of: space) {
                switch child {
                case .list(let l):    result.append((target: .list(l),    isChild: true))
                case .project(let p): result.append((target: .project(p), isChild: true))
                }
            }
        }
        return result
    }

    private var filteredContainers: [SearchEntry] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return allContainers }
        return allContainers.filter { $0.target.title.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Row 1 — back button · search bar · menu button
            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.appHeadline)
                }

                // Search bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                    TextField("Search", text: $searchText)
                        .font(.appFont)
                        .focused($isSearchFocused)
                        .submitLabel(.done)
                        .onSubmit { isSearchFocused = false }
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(UIColor.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 8))

                // Menu button — placeholder, no functionality yet
                Button { } label: {
                    Image(systemName: "ellipsis")
                        .font(.appHeadline)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .padding(.bottom, 8)

            // MARK: Row 2 — container title, leading-aligned
            HStack(spacing: 6) {
                Image(systemName: target.symbol)
                    .foregroundStyle(target.color)
                Text(target.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            .font(.appHeadline)
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()

            // MARK: Content + search dropdown overlay
            ZStack(alignment: .top) {
                // Regular content
                Group {
                    if target.items.isEmpty {
                        ContentUnavailableView(
                            "No items",
                            systemImage: target.symbol,
                            description: Text("Items added to this container will appear here.")
                        )
                    } else {
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
                // Search results dropdown — floats above the content
                if isSearchFocused {
                    VStack(spacing: 0) {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(filteredContainers, id: \.target) { entry in
                                    Button {
                                        isSearchFocused = false
                                        onNavigate(entry.target)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: entry.target.symbol)
                                                .frame(width: 20)
                                                .foregroundStyle(entry.target.color)
                                            Text(entry.target.title)
                                                .font(.appFont)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 10)
                                        .padding(.leading, entry.isChild ? 16 : 0)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().padding(.leading, entry.isChild ? 60 : 44)
                                }
                            }
                        }
                        .frame(maxHeight: 240)
                        Divider()
                    }
                    .background(Color(UIColor.systemBackground))
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        // Dismiss search when tapping outside the search bar
        .onTapGesture {
            if isSearchFocused { isSearchFocused = false }
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
