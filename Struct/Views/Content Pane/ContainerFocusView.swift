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

    // MARK: - Grouped Content

    /// Computed grouped content for the current target
    private var groupedContent: (directItems: ContainerFocusViewModel.GroupedItems, sectionGroups: [ContainerFocusViewModel.SectionGroup]) {
        viewModel.groupedContent(for: target)
    }

    /// Child container groups for Space targets
    private var childContainerGroups: [ContainerFocusViewModel.ChildContainerGroup] {
        guard case .space(let space) = target else { return [] }
        return viewModel.childContainerGroups(for: space)
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
            switch target {
            case .space:
                if groupedContent.directItems.isEmpty && groupedContent.sectionGroups.isEmpty && childContainerGroups.isEmpty && !viewModel.showingTaskCreationCard {
                    ContentUnavailableView(
                        "No items",
                        systemImage: target.symbol,
                        description: Text("Items added to this space will appear here.")
                    )
                } else {
                    ContainerFocusListView(
                        target: target,
                        viewModel: viewModel,
                        modelContext: modelContext,
                        onSaveTask: { [weak viewModel] in
                            viewModel?.createTask(in: target, context: modelContext)
                        },
                        onCancelTask: { [weak viewModel] in
                            viewModel?.hideTaskCreationCard()
                        }
                    )
                }
            case .list, .project:
                if groupedContent.directItems.isEmpty && groupedContent.sectionGroups.isEmpty && !viewModel.showingTaskCreationCard {
                    ContentUnavailableView(
                        "No items",
                        systemImage: target.symbol,
                        description: Text("Items added to this container will appear here.")
                    )
                } else {
                    ContainerFocusListView(
                        target: target,
                        viewModel: viewModel,
                        modelContext: modelContext,
                        onSaveTask: { [weak viewModel] in
                            viewModel?.createTask(in: target, context: modelContext)
                        },
                        onCancelTask: { [weak viewModel] in
                            viewModel?.hideTaskCreationCard()
                        }
                    )
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

    // MARK: - Floating Add Button

    @Environment(\.modelContext) private var modelContext
    
    private var floatingAddButton: some View {
        Button {
            viewModel.showTaskCreationCard()
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
        .opacity(viewModel.showingTaskCreationCard ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showingTaskCreationCard)
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
        .overlay(alignment: .bottomTrailing) {
            floatingAddButton
        }
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

    // Create a Space with comprehensive test data
    let space = Space(name: "Personal", sortIndex: 0)
    context.insert(space)
    
    // Direct tasks in space (not in a section)
    Item.create(in: context, title: "Space task 1 (unscheduled)", sortIndex: 0, parent: .space(space))
    Item.create(in: context, title: "Space task 2 (unscheduled)", sortIndex: 1, parent: .space(space))
    Item.create(in: context, title: "Space task 3 (scheduled)", doDate: .now.addingTimeInterval(86_400), sortIndex: 2, parent: .space(space))
    Item.create(in: context, title: "Space task 4 (scheduled)", doDate: .now.addingTimeInterval(86_400 * 2), sortIndex: 3, parent: .space(space))
    
    // Task section directly in space
    let spaceSection = TaskSection(title: "Space Section", parent: .space(space))
    context.insert(spaceSection)
    Item.create(in: context, title: "Section task 1 (unscheduled)", sortIndex: 0, parent: .taskSection(spaceSection))
    Item.create(in: context, title: "Section task 2 (unscheduled)", sortIndex: 1, parent: .taskSection(spaceSection))
    Item.create(in: context, title: "Section task 3 (scheduled)", doDate: .now.addingTimeInterval(86_400 * 3), sortIndex: 2, parent: .taskSection(spaceSection))
    
    // Create a List within the space
    let list = List(title: "Groceries", space: space, sortIndex: 0)
    context.insert(list)
    
    // Direct tasks in list
    Item.create(in: context, title: "Buy milk", sortIndex: 0, parent: .list(list))
    Item.create(in: context, title: "Buy eggs", sortIndex: 1, parent: .list(list))
    Item.create(in: context, title: "Buy bread (scheduled)", doDate: .now.addingTimeInterval(86_400), sortIndex: 2, parent: .list(list))
    
    // Task section in list
    let listSection = TaskSection(title: "Weekly Shopping", parent: .list(list))
    context.insert(listSection)
    Item.create(in: context, title: "Apples", sortIndex: 0, parent: .taskSection(listSection))
    Item.create(in: context, title: "Bananas", sortIndex: 1, parent: .taskSection(listSection))
    Item.create(in: context, title: "Oranges (scheduled)", doDate: .now.addingTimeInterval(86_400 * 4), sortIndex: 2, parent: .taskSection(listSection))
    
    // Create a Project within the space
    let project = Project(title: "Home Renovation", space: space, sortIndex: 1)
    context.insert(project)
    
    // Direct tasks in project
    Item.create(in: context, title: "Choose paint colors", sortIndex: 0, parent: .project(project))
    Item.create(in: context, title: "Get contractor quotes", sortIndex: 1, parent: .project(project))
    Item.create(in: context, title: "Schedule inspection (scheduled)", doDate: .now.addingTimeInterval(86_400 * 5), sortIndex: 2, parent: .project(project))
    
    // Task section in project
    let projectSection = TaskSection(title: "Kitchen Remodel", parent: .project(project))
    context.insert(projectSection)
    Item.create(in: context, title: "Demolish old cabinets", sortIndex: 0, parent: .taskSection(projectSection))
    Item.create(in: context, title: "Install new countertops", sortIndex: 1, parent: .taskSection(projectSection))
    Item.create(in: context, title: "Install backsplash (scheduled)", doDate: .now.addingTimeInterval(86_400 * 6), sortIndex: 2, parent: .taskSection(projectSection))
    
    // Create another list with no tasks (to test empty state)
    let emptyList = List(title: "Empty List", space: space, sortIndex: 2)
    context.insert(emptyList)

    return NavigationStack {
        ContainerFocusView(target: .space(space))
    }
    .modelContainer(container)
}
