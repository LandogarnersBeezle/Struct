//
//  ContainerFocusView.swift
//  Struct
//
//  Created by Otto Kiefer on 05.05.2026.
//

import SwiftUI
import SwiftData

struct ContainerFocusView: View {
    let target: ContainerTarget
    /// Called when the user selects a container from the search/filter view.
    /// The owner should replace the navigation path with the new target so
    /// the back button returns to the root rather than the previous detail view.
    var onNavigate: (ContainerTarget) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ContainerFocusViewModel

    // MARK: - Data Queries

    @Query(filter: #Predicate<List> { $0.kindRaw == "inbox" })
    private var inboxLists: [List]

    @Query(sort: \Space.sortIndex)
    private var spaces: [Space]

    init(target: ContainerTarget, onNavigate: @escaping (ContainerTarget) -> Void = { _ in }) {
        self.target = target
        self.onNavigate = onNavigate
        _viewModel = StateObject(wrappedValue: ContainerFocusViewModel())
    }

    // MARK: - Container Data

    /// All containers in the same order as ContainersSidebarView:
    /// Inbox → (Space → lists → projects) per space.
    /// `isChild` is true for lists/projects that belong to a space (drives indentation).
    private var allContainers: [ContainerFocusViewModel.SearchEntry] {
        var result: [ContainerFocusViewModel.SearchEntry] = []
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

    // MARK: - Back Button

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
        }
    }

    // MARK: - Title Button

    private var titleButton: some View {
        Button {
            viewModel.toggleFilterView()
        } label: {
            HStack(spacing: 4) {
                HierarchicalTitleView(target: target)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .rotationEffect(.degrees(viewModel.showFilterView ? 180 : 0))
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Menu Button

    private var menuButton: some View {
        Button { } label: {
            Image(systemName: "ellipsis")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            backButton
            titleButton
            Spacer()
            menuButton
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
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
    }

    // MARK: - Swipe Back Gesture

    private var swipeBackOverlay: some View {
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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            // Content + filter view overlay
            ZStack(alignment: .top) {
                contentView

                if viewModel.showFilterView {
                    FilterViewOverlay(
                        searchText: $viewModel.searchText,
                        allContainers: allContainers,
                        onSelect: onNavigate,
                        onClose: {
                            viewModel.closeFilterView()
                        },
                        viewModel: viewModel
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.8, blendDuration: 0), value: viewModel.showFilterView)
            .overlay(alignment: .leading) {
                swipeBackOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Preview

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