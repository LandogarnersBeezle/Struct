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
    /// Whether to show the back button. On iPad with split view, the back button
    /// is hidden since the sidebar is always visible.
    var showBackButton: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ContainerFocusViewModel
    @State private var showTaskCreationCard: Bool = false
    @State private var showSectionCreationCard: Bool = false
    @State private var showContainerCreationCard: Bool = false
    @State private var isDatePickerShown: Bool = false
    @State private var isPlusButtonVisible: Bool = true
    @State private var selectedTaskContainer: ContainerTarget? = nil
    @State private var showContainerSelector: Bool = false
    @State private var containerSelectorSearchText: String = ""
    @State private var cardSelectedContainer: ContainerTarget? = nil
    @State private var shouldFocusFilterSearch: Bool = false
    @FocusState private var isContainerSearchFocused: Bool

    // MARK: - Data Queries

    @Query(filter: #Predicate<List> { $0.kindRaw == "inbox" })
    private var inboxLists: [List]

    @Query(sort: \Space.sortIndex)
    private var spaces: [Space]
    
    init(target: ContainerTarget, onNavigate: @escaping (ContainerTarget) -> Void = { _ in }, showBackButton: Bool = true) {
        self.target = target
        self.onNavigate = onNavigate
        self.showBackButton = showBackButton
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

    // MARK: - Item Creation

    /// The next sort index for a new item in the current container.
    private var nextItemSortIndex: Int {
        (target.items.map(\.sortIndex).max() ?? -1) + 1
    }

    /// Convert the current navigation target into an `ItemParent` so we can
    /// create an item owned by this container.
    private func parentForTarget() -> ItemParent? {
        switch target {
        case .space(let s):  return .space(s)
        case .project(let p): return .project(p)
        case .list(let l):   return .list(l)
        }
    }

    // MARK: - Back Button

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var backButton: some View {
        Group {
            if showBackButton {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                }
            }
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
                if groupedContent.directItems.isEmpty && groupedContent.sectionGroups.isEmpty && childContainerGroups.isEmpty {
                    ContentUnavailableView(
                        "No items",
                        systemImage: target.symbol,
                        description: Text("Items added to this space will appear here.")
                    )
                } else {
                    ContainerFocusListView(
                        target: target,
                        viewModel: viewModel,
                        modelContext: modelContext
                    )
                }
            case .list, .project:
                if groupedContent.directItems.isEmpty && groupedContent.sectionGroups.isEmpty {
                    ContentUnavailableView(
                        "No items",
                        systemImage: target.symbol,
                        description: Text("Items added to this container will appear here.")
                    )
                } else {
                    ContainerFocusListView(
                        target: target,
                        viewModel: viewModel,
                        modelContext: modelContext
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
            .blur(radius: isDatePickerShown ? 4 : 0)
            .animation(.easeInOut(duration: 0.2), value: isDatePickerShown)
            .animation(.spring(response: 0.25, dampingFraction: 0.8, blendDuration: 0), value: viewModel.showFilterView)
            .overlay(alignment: .leading) {
                swipeBackOverlay
            }
            .overlay(alignment: .bottomTrailing) {
                if isPlusButtonVisible {
                    HStack(spacing: 12) {
                        // Container button (iPad only)
                        if horizontalSizeClass == .regular {
                            Button {
                                // Hide the plus button before the keyboard appears
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    isPlusButtonVisible = false
                                }
                                // Small delay to ensure button animates out before card appears
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        showContainerCreationCard.toggle()
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.caption.weight(.semibold))
                                    Text("Container")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.blue))
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }

                        // Section button
                        Button {
                            // Hide the plus button before the keyboard appears
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                isPlusButtonVisible = false
                            }
                            // Small delay to ensure button animates out before card appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    showSectionCreationCard.toggle()
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.caption.weight(.semibold))
                                Text("Section")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.gray))
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)

                        // Task button
                        Button {
                            // Hide the plus button before the keyboard appears
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                isPlusButtonVisible = false
                            }
                            // Small delay to ensure button animates out before card appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    showTaskCreationCard.toggle()
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.caption.weight(.semibold))
                                Text("Task")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.accentColor))
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 16)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            // Section creation card overlay
            .overlay(alignment: .top) {
                if showSectionCreationCard {
                    SectionCreationCardView(
                        targetContainer: target,
                        onCancel: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                showSectionCreationCard = false
                            }
                            // Restore the plus button after the keyboard has collapsed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    isPlusButtonVisible = true
                                }
                            }
                        },
                        onSave: { title in
                            // Animate the card out first
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                showSectionCreationCard = false
                            }
                            // After the card finishes dismissing, create the section and restore the plus button
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                // Determine the parent for the new section
                                let parent: TaskSectionParent
                                switch target {
                                case .space(let s): parent = .space(s)
                                case .project(let p): parent = .project(p)
                                case .list(let l): parent = .list(l)
                                }

                                // Get existing sections for this container to shift their sort indices
                                let existingSections: [TaskSection]
                                switch target {
                                case .space(let s):
                                    existingSections = s.taskSections
                                case .project(let p):
                                    existingSections = p.taskSections
                                case .list(let l):
                                    existingSections = l.taskSections
                                }

                                // Shift all existing sections' sort indices by +1
                                for section in existingSections {
                                    section.sortIndex += 1
                                }

                                // Create the new section at sort index 0
                                let newSection = TaskSection(title: title, sortIndex: 0, parent: parent)
                                modelContext.insert(newSection)

                                // Restore the plus button after the keyboard has collapsed
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    isPlusButtonVisible = true
                                }
                            }
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            // Task creation card overlay - shown regardless of container content
            .overlay(alignment: .top) {
                if showTaskCreationCard {
                    TaskCreationCardView(
                        targetContainer: target,
                        allContainers: allContainers,
                        viewModel: viewModel,
                        onContainerSelect: { newTarget in
                            selectedTaskContainer = newTarget
                        },
                        onCancel: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                showTaskCreationCard = false
                                selectedTaskContainer = nil
                            }
                            // Restore the plus button after the keyboard has collapsed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    isPlusButtonVisible = true
                                }
                            }
                        },
                        onDatePickerVisibilityChanged: { isShown in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDatePickerShown = isShown
                            }
                        },
                        onShowContainerSelector: {
                            showContainerSelector = true
                        },
                        onContainerSelected: { newTarget in
                            cardSelectedContainer = newTarget
                        },
                        selectedContainerBinding: $cardSelectedContainer,
                        onFocusFilterSearch: {
                            shouldFocusFilterSearch = true
                        },
                        onSave: { title, doDate, dueDate in
                            // Animate the card out first
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                showTaskCreationCard = false
                            }
                            // After the card finishes dismissing, insert the item and restore the plus button
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                // Use the selected container if one was chosen, otherwise use the current target
                                let saveTarget = selectedTaskContainer ?? target
                                let parent: ItemParent
                                switch saveTarget {
                                case .space(let s): parent = .space(s)
                                case .project(let p): parent = .project(p)
                                case .list(let l): parent = .list(l)
                                }
                                let itemSortIndex = (saveTarget.items.map(\.sortIndex).max() ?? -1) + 1
                                let item = Item.create(in: modelContext,
                                                       title: title,
                                                       doDate: doDate,
                                                       dueDate: dueDate,
                                                       sortIndex: itemSortIndex,
                                                       parent: parent)
                                selectedTaskContainer = nil
                                // Restore the plus button after the keyboard has collapsed
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    isPlusButtonVisible = true
                                }
                            }
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            // Container creation card overlay (iPad only)
            .overlay(alignment: .top) {
                if showContainerCreationCard {
                    ZStack {
                        // Invisible hit-testing layer for dismissing on background tap
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    showContainerCreationCard = false
                                }
                                // Restore the plus button after the keyboard has collapsed
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        isPlusButtonVisible = true
                                    }
                                }
                            }

                        // Container creation card centered in detail view
                        ContainerCreationCardView(
                            onCancel: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    showContainerCreationCard = false
                                }
                                // Restore the plus button after the keyboard has collapsed
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        isPlusButtonVisible = true
                                    }
                                }
                            },
                            onSave: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    showContainerCreationCard = false
                                }
                                // Restore the plus button after the keyboard has collapsed
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        isPlusButtonVisible = true
                                    }
                                }
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    .transition(.opacity)
                }
            }
            // Container selector overlay (for breadcrumb in task creation card)
            .onChange(of: shouldFocusFilterSearch) { _, newValue in
                if newValue {
                    isContainerSearchFocused = true
                    shouldFocusFilterSearch = false
                }
            }
            .overlay {
                if showContainerSelector {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                showContainerSelector = false
                                isContainerSearchFocused = false
                                containerSelectorSearchText = ""
                            }
                        }
                        .overlay(alignment: .top) {
                            VStack(spacing: 0) {
                                Color.clear.frame(height: 100)
                                VStack(alignment: .leading, spacing: 0) {
                                    FilterSearchField(searchText: $containerSelectorSearchText, isFocused: $isContainerSearchFocused)
                                    FilterResultsView(entries: viewModel.filteredContainers(from: allContainers, searchText: containerSelectorSearchText), onSelect: { targetContainer in
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            showContainerSelector = false
                                            isContainerSearchFocused = false
                                            containerSelectorSearchText = ""
                                        }
                                        selectedTaskContainer = targetContainer
                                        cardSelectedContainer = targetContainer
                                    })
                                }
                                .frame(maxHeight: 300)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(UIColor.systemBackground))
                                        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
                                )
                                .padding(.horizontal, 16)
                                Spacer(minLength: 0)
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
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
    Item.create(in: context, title: "Section task 3 (scheduled)", doDate: .now.addingTimeInterval(86_400 * 42), sortIndex: 2, parent: .taskSection(spaceSection))
    
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