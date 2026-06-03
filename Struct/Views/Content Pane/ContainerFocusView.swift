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
    /// Called when the user selects a container from the search/filter view.
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
    @State private var showFilterView: Bool = false

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

    /// The symbol name for a given container target.
    private func symbol(for target: ContainerTarget) -> String {
        switch target {
        case .space(let space):
            return space.symbolName
        case .list(let list):
            return list.kind == .inbox ? "tray" : "list.bullet"
        case .project:
            return "folder"
        }
    }

    /// The color for a given container target.
    private func color(for target: ContainerTarget) -> Color {
        switch target {
        case .space:
            return Space.containerColor
        case .list:
            return List.containerColor
        case .project:
            return Project.containerColor
        }
    }

    /// The display title for the current container, showing hierarchy if inside a space.
    /// Returns a view with icons and text.
    @ViewBuilder
    private var hierarchicalTitleView: some View {
        switch target {
        case .space(let space):
            HStack(spacing: 4) {
                Image(systemName: space.symbolName)
                    .foregroundStyle(Space.containerColor)
                Text(space.name)
            }
        case .list(let list):
            if let space = list.space {
                HStack(spacing: 4) {
                    Image(systemName: space.symbolName)
                        .foregroundStyle(Space.containerColor)
                    Text(space.name)
                    Text("/")
                        .foregroundStyle(.secondary)
                    Image(systemName: list.kind == .inbox ? "tray" : "list.bullet")
                        .foregroundStyle(List.containerColor)
                    Text(list.title)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: list.kind == .inbox ? "tray" : "list.bullet")
                        .foregroundStyle(List.containerColor)
                    Text(list.title)
                }
            }
        case .project(let project):
            HStack(spacing: 4) {
                Image(systemName: project.space.symbolName)
                    .foregroundStyle(Space.containerColor)
                Text(project.space.name)
                Text("/")
                    .foregroundStyle(.secondary)
                Image(systemName: "folder")
                    .foregroundStyle(Project.containerColor)
                Text(project.title)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Row 1 — back button · container title · menu button
            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                }

                // Container title — clickable to toggle filter view
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showFilterView.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        hierarchicalTitleView
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .rotationEffect(.degrees(showFilterView ? 180 : 0))
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Spacer()

                // Menu button — placeholder, no functionality yet
                Button { } label: {
                    Image(systemName: "ellipsis")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .padding(.bottom, 8)

            Divider()

            // MARK: Content + filter view overlay
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

                // Filter view — animated overlay in a distinguishable frame
                if showFilterView {
                    VStack(spacing: 0) {
                        // Search field inside the filter view
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Filter containers", text: $searchText)
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.tertiarySystemFill),
                                    in: RoundedRectangle(cornerRadius: 8))
                        .focused($isSearchFocused)

                        // Filter results
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(filteredContainers, id: \.target) { entry in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showFilterView = false
                                            isSearchFocused = false
                                        }
                                        onNavigate(entry.target)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: entry.target.symbol)
                                                .frame(width: 20)
                                                .foregroundStyle(entry.target.color)
                                            Text(entry.target.title)
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
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                }
            }

            // Swipe from the left edge to go back (mirrors the back button).
            // Attaching to the ZStack (content area only) means the overlay strip
            // sits above the ScrollView — so it wins the gesture against UIScrollView's
            // pan recogniser — while leaving the header row (back button, title)
            // completely uncovered.
            .overlay(alignment: .leading) {
                Color.clear
                    .frame(width: 30)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                let isRightwardSwipe = value.translation.width > 80
                                let isMoreHorizontal = abs(value.translation.width) > abs(value.translation.height)
                                if isRightwardSwipe && isMoreHorizontal {
                                    dismiss()
                                }
                            }
                    )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        // Handle tap outside to dismiss filter view
        .onTapGesture {
            if showFilterView {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFilterView = false
                    isSearchFocused = false
                    searchText = ""
                }
            }
        }
        // Auto-focus text field when filter view appears
        .onChange(of: showFilterView) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Space.self, Project.self, List.self, Item.self, TaskSection.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    List.ensureInbox(in: context)

    let space = Space(name: "Personal", sortIndex: 0)
    context.insert(space)
    let apartment = List(title: "Meetings", space: space, sortIndex: 0)
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
