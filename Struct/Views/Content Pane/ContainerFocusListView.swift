//
//  ContainerFocusListView.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI
import SwiftData

/// Main content view for ContainerFocusView that displays all items with proper sticky headers.
/// Uses a single SwiftUI.List to ensure headers stick properly when scrolling.
struct ContainerFocusListView: View {
    let target: ContainerTarget
    @ObservedObject var viewModel: ContainerFocusViewModel
    
    private var groupedContent: (directItems: ContainerFocusViewModel.GroupedItems, sectionGroups: [ContainerFocusViewModel.SectionGroup]) {
        viewModel.groupedContent(for: target)
    }
    
    private var childContainerGroups: [ContainerFocusViewModel.ChildContainerGroup] {
        guard case .space(let space) = target else { return [] }
        return viewModel.childContainerGroups(for: space)
    }
    
    var body: some View {
        SwiftUI.List {
            switch target {
            case .space:
                spaceContent
            case .list, .project:
                listProjectContent
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - List/Project Content
    
    @ViewBuilder
    private var listProjectContent: some View {
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
            SectionTitleLabel(title: sectionGroup.title, itemCount: sectionGroup.groupedItems.unscheduled.count + sectionGroup.groupedItems.scheduled.count)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.clear)
                .padding(.horizontal, -16)
                .padding(.vertical, -10)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private func childContainerContent(childGroup: ContainerFocusViewModel.ChildContainerGroup) -> some View {
        let isExpanded = viewModel.isChildContainerExpanded(childGroup.child)
        let totalCount = childGroup.directItems.unscheduled.count + childGroup.directItems.scheduled.count + childGroup.sectionGroups.reduce(0) { $0 + $1.groupedItems.unscheduled.count + $1.groupedItems.scheduled.count }
        
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
                    taskSectionContent(sectionGroup: sectionGroup)
                }
            }
        } header: {
            // Sticky header with row-like appearance
            CollapsibleHeaderLabel(
                title: childGroup.title,
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
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .opacity(isEmpty ? 0.5 : 1.0)
            
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.05))
    }
}

/// Collapsible header label for child containers
struct CollapsibleHeaderLabel: View {
    let title: String
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
            
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.tail)
                .opacity(isEmpty ? 0.5 : 1.0)
            
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
    
    let space = Space(name: "Personal", sortIndex: 0)
    context.insert(space)
    let list = List(title: "Test List", space: space, sortIndex: 0)
    context.insert(list)
    
    let viewModel = ContainerFocusViewModel()
    
    return NavigationStack {
        ContainerFocusListView(target: .list(list), viewModel: viewModel)
    }
    .modelContainer(container)
}