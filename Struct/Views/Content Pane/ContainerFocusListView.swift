//
//  ContainerFocusListView.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - Scroll Tracking Types

/// Information about a nested section header's position for tracking which section is at the boundary.
/// Used to determine when a task section header within a child container is about to scroll off.
struct SectionPositionInfo: Equatable {
    /// The child container (list/project) that contains this section
    let childContainerID: ContainerChild.ID
    /// The title of the section (used for breadcrumb display)
    let title: String
    /// The y-position of the section header in the scroll view's coordinate space
    let yPosition: CGFloat
}

/// PreferenceKey for tracking section header positions within the scroll view.
/// Aggregates positions from all tracked section headers to determine which is closest to the top.
struct SectionPositionPreferenceKey: PreferenceKey {
    static var defaultValue: [SectionPositionInfo] = []
    
    static func reduce(value: inout [SectionPositionInfo], nextValue: () -> [SectionPositionInfo]) {
        value.append(contentsOf: nextValue())
    }
}

/// A simple view that reports its section header's position via preference key.
/// Used as an overlay on section headers to track their scroll position.
struct PositionTracker: View {
    let childContainerID: ContainerChild.ID
    let title: String
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: SectionPositionPreferenceKey.self,
                    value: [
                        SectionPositionInfo(
                            childContainerID: childContainerID,
                            title: title,
                            yPosition: geometry.frame(in: .named("ScrollView")).minY
                        )
                    ]
                )
        }
    }
}

/// Main content view for ContainerFocusView that displays all items with proper sticky headers.
/// Uses a single SwiftUI.List to ensure headers stick properly when scrolling.
struct ContainerFocusListView: View {
    let target: ContainerTarget
    @ObservedObject var viewModel: ContainerFocusViewModel
    let modelContext: ModelContext
    let onSaveTask: () -> Void
    let onCancelTask: () -> Void
    
    private var groupedContent: (directItems: ContainerFocusViewModel.GroupedItems, sectionGroups: [ContainerFocusViewModel.SectionGroup]) {
        viewModel.groupedContent(for: target)
    }
    
    private var childContainerGroups: [ContainerFocusViewModel.ChildContainerGroup] {
        guard case .space(let space) = target else { return [] }
        return viewModel.childContainerGroups(for: space)
    }
    
    // The threshold y-position where a section header is considered "at the top"
    // This accounts for the header height in ContainerFocusView (approximately 60 points)
    private let headerThreshold: CGFloat = 60
    
    var body: some View {
        SwiftUI.List {
            switch target {
            case .space:
                spaceContent
            case .list, .project:
                listProjectContent
            }
        }
        .coordinateSpace(name: "ScrollView")
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .onPreferenceChange(SectionPositionPreferenceKey.self) { positions in
            updateActiveNestedSections(from: positions)
        }
    }
    
    /// Updates the active nested sections based on current scroll positions.
    /// For each child container, finds the section header that is closest to the top.
    /// When a section header is near the top (within headerThreshold), it means the header
    /// is stuck at the top and about to be pushed off by the next section header.
    private func updateActiveNestedSections(from positions: [SectionPositionInfo]) {
        // Only process for space views
        guard case .space = target else { return }
        
        var newActiveSections: [ContainerChild.ID: String] = [:]
        
        // Group positions by child container
        let positionsByContainer = Dictionary(grouping: positions) { $0.childContainerID }
        
        for (childContainerID, containerPositions) in positionsByContainer {
            // Only track if the child container is expanded
            guard viewModel.expandedChildContainers.contains(childContainerID) else { continue }
            
            // Find the section header with the smallest yPosition (closest to top)
            // When its yPosition is close to the header threshold, the section header is stuck at top
            if let topmostSection = containerPositions.min(by: { $0.yPosition < $1.yPosition }) {
                // Show the nested section title if the section header is near the top
                // The section header is approximately 44 points tall, so when the header
                // is at y <= headerThreshold, it's stuck at the top and about to scroll off
                if topmostSection.yPosition <= headerThreshold {
                    newActiveSections[childContainerID] = topmostSection.title
                }
            }
        }
        
        // Update the view model if changed
        if newActiveSections != viewModel.activeNestedSections {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.activeNestedSections = newActiveSections
            }
        }
    }
    
    // MARK: - List/Project Content
    
    @ViewBuilder
    private var listProjectContent: some View {
        // Task creation card (shown at top when active)
        if viewModel.showingTaskCreationCard {
            Section {
                TaskCreationCard(
                    title: $viewModel.newTaskTitle,
                    onSave: onSaveTask,
                    onCancel: onCancelTask
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } header: {
                EmptyView()
            }
        }
        
        // Direct items (unscheduled first, then scheduled)
        let directItems = groupedContent.directItems
        if !directItems.unscheduled.isEmpty || !directItems.scheduled.isEmpty {
            Section {
                ForEach(directItems.unscheduled, id: \.persistentModelID) { item in
                    ItemRowView(item: item)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
                ForEach(directItems.scheduled, id: \.persistentModelID) { item in
                    ItemRowView(item: item)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
            } header: {
                // Empty header to use sticky behavior
                EmptyView()
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        
        // Task sections
        ForEach(groupedContent.sectionGroups) { sectionGroup in
            taskSectionContent(sectionGroup: sectionGroup)
        }
    }
    
    // MARK: - Space Content
    
    @ViewBuilder
    private var spaceContent: some View {
        // Task creation card (shown at top when active)
        if viewModel.showingTaskCreationCard {
            Section {
                TaskCreationCard(
                    title: $viewModel.newTaskTitle,
                    onSave: onSaveTask,
                    onCancel: onCancelTask
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } header: {
                EmptyView()
            }
        }
        
        // Direct items (unscheduled first, then scheduled)
        let directItems = groupedContent.directItems
        if !directItems.unscheduled.isEmpty || !directItems.scheduled.isEmpty {
            Section {
                ForEach(directItems.unscheduled, id: \.persistentModelID) { item in
                    ItemRowView(item: item)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
                ForEach(directItems.scheduled, id: \.persistentModelID) { item in
                    ItemRowView(item: item)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
            } header: {
                EmptyView()
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        
        // Task sections directly in space
        ForEach(groupedContent.sectionGroups) { sectionGroup in
            taskSectionContent(sectionGroup: sectionGroup)
        }
        
        // Child containers (Lists/Projects)
        ForEach(childContainerGroups) { childGroup in
            childContainerContent(childGroup: childGroup)
        }
    }
    
    // MARK: - Section Builders
    
    @ViewBuilder
    private func taskSectionContent(sectionGroup: ContainerFocusViewModel.SectionGroup) -> some View {
        taskSectionContent(sectionGroup: sectionGroup, childContainerID: nil)
    }
    
    @ViewBuilder
    private func taskSectionContent(sectionGroup: ContainerFocusViewModel.SectionGroup, childContainerID: ContainerChild.ID?) -> some View {
        // Section title header - uses Section header for sticky behavior
        Section {
            if sectionGroup.groupedItems.unscheduled.isEmpty && sectionGroup.groupedItems.scheduled.isEmpty {
                // Empty section - show nothing
                EmptyView()
            } else {
                // Items (unscheduled first, then scheduled)
                ForEach(sectionGroup.groupedItems.unscheduled, id: \.persistentModelID) { item in
                    ItemRowView(item: item)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
                ForEach(sectionGroup.groupedItems.scheduled, id: \.persistentModelID) { item in
                    ItemRowView(item: item)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
            }
        } header: {
            // Sticky header with row-like appearance
            // Track position for sections inside child containers in space view
            SectionTitleLabel(title: sectionGroup.title, itemCount: sectionGroup.groupedItems.unscheduled.count + sectionGroup.groupedItems.scheduled.count)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.clear)
                .padding(.horizontal, -16)
                .padding(.vertical, -10)
                .overlay {
                    // Overlay the tracker on the header to track its position
                    if let childContainerID = childContainerID {
                        PositionTracker(
                            childContainerID: childContainerID,
                            title: sectionGroup.title
                        )
                    }
                }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private func childContainerContent(childGroup: ContainerFocusViewModel.ChildContainerGroup) -> some View {
        let isExpanded = viewModel.isChildContainerExpanded(childGroup.child)
        let totalCount = childGroup.directItems.unscheduled.count + childGroup.directItems.scheduled.count + childGroup.sectionGroups.reduce(0) { $0 + $1.groupedItems.unscheduled.count + $1.groupedItems.scheduled.count }
        let activeNestedTitle = viewModel.activeNestedSections[childGroup.child.id]
        
        // Use Section header for sticky behavior
        Section {
            if isExpanded {
                // Direct items in container (unscheduled first, then scheduled)
                if !childGroup.directItems.unscheduled.isEmpty || !childGroup.directItems.scheduled.isEmpty {
                    ForEach(childGroup.directItems.unscheduled, id: \.persistentModelID) { item in
                        ItemRowView(item: item)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                    ForEach(childGroup.directItems.scheduled, id: \.persistentModelID) { item in
                        ItemRowView(item: item)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                }
                
                // Task sections in container
                ForEach(childGroup.sectionGroups) { sectionGroup in
                    taskSectionContent(sectionGroup: sectionGroup, childContainerID: childGroup.child.id)
                }
            }
        } header: {
            // Sticky header with row-like appearance
            CollapsibleHeaderLabel(
                title: childGroup.title,
                subtitle: activeNestedTitle,
                symbol: childGroup.symbol,
                color: childGroup.color,
                itemCount: totalCount,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleChildContainer(childGroup.child)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .padding(.horizontal, -16)
            .padding(.vertical, -4)
        } footer: {
            EmptyView()
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Helper Views

/// Header label for TaskSection titles
struct SectionTitleLabel: View {
    let title: String
    var itemCount: Int = 0
    
    private var isEmpty: Bool { itemCount == 0 }
    
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .opacity(isEmpty ? 0.5 : 1.0)
            
            Spacer()
            
            if !isEmpty {
                Text("\(itemCount)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.clear)
    }
}

/// Collapsible header label for child containers
struct CollapsibleHeaderLabel: View {
    let title: String
    let subtitle: String? // Optional nested section title for breadcrumb
    let symbol: String
    let color: Color
    var itemCount: Int = 0
    let isExpanded: Bool
    let onToggle: () -> Void
    
    private var isEmpty: Bool { itemCount == 0 }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 0) {
                if let subtitle = subtitle {
                    // Breadcrumb mode: show "Container › Section"
                    HStack(spacing: 4) {
                        Text(title)
                            .fontWeight(.semibold)
                            .foregroundStyle(color)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Text("›")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        
                        Text(subtitle)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .opacity(isEmpty ? 0.5 : 1.0)
                } else {
                    // Normal mode: just show title
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .opacity(isEmpty ? 0.5 : 1.0)
                }
            }
            
            Spacer()
            
            if !isEmpty {
                Text("\(itemCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
            
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Space.self, Project.self, List.self, Item.self, TaskSection.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    List.ensureInbox(in: context)
    
    // Create a Space with test data for hierarchical sticky headers
    let space = Space(name: "Personal", sortIndex: 0)
    context.insert(space)
    
    // Create a List within the space with a task section
    let list = List(title: "Groceries", space: space, sortIndex: 0)
    context.insert(list)
    
    // Direct tasks in list
    Item.create(in: context, title: "Buy milk", sortIndex: 0, parent: .list(list))
    Item.create(in: context, title: "Buy eggs", sortIndex: 1, parent: .list(list))
    Item.create(in: context, title: "Buy bread", sortIndex: 2, parent: .list(list))
    
    // Task section in list
    let listSection = TaskSection(title: "Weekly Shopping", parent: .list(list))
    context.insert(listSection)
    Item.create(in: context, title: "Apples", sortIndex: 0, parent: .taskSection(listSection))
    Item.create(in: context, title: "Bananas", sortIndex: 1, parent: .taskSection(listSection))
    Item.create(in: context, title: "Oranges", sortIndex: 2, parent: .taskSection(listSection))
    
    // Create a Project within the space with a task section
    let project = Project(title: "Home Renovation", space: space, sortIndex: 1)
    context.insert(project)
    
    // Direct tasks in project
    Item.create(in: context, title: "Choose paint colors", sortIndex: 0, parent: .project(project))
    Item.create(in: context, title: "Get contractor quotes", sortIndex: 1, parent: .project(project))
    
    // Task section in project
    let projectSection = TaskSection(title: "Kitchen Remodel", parent: .project(project))
    context.insert(projectSection)
    Item.create(in: context, title: "Demolish old cabinets", sortIndex: 0, parent: .taskSection(projectSection))
    Item.create(in: context, title: "Install new countertops", sortIndex: 1, parent: .taskSection(projectSection))
    
    let viewModel = ContainerFocusViewModel()
    // Pre-expand both containers for testing
    viewModel.expandedChildContainers = [.list(list.persistentModelID), .project(project.persistentModelID)]
    
    return NavigationStack {
        ContainerFocusListView(
            target: .space(space),
            viewModel: viewModel,
            modelContext: context,
            onSaveTask: {},
            onCancelTask: {}
        )
    }
    .modelContainer(container)
}
