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
struct SectionPositionInfo: Equatable {
    let childContainerID: ContainerChild.ID
    let title: String
    let yPosition: CGFloat
}

struct SectionPositionPreferenceKey: PreferenceKey {
    static var defaultValue: [SectionPositionInfo] = []
    static func reduce(value: inout [SectionPositionInfo], nextValue: () -> [SectionPositionInfo]) {
        value.append(contentsOf: nextValue())
    }
}

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

// MARK: - Main Content View

struct ContainerFocusListView: View {
    let target: ContainerTarget
    @ObservedObject var viewModel: ContainerFocusViewModel
    let modelContext: ModelContext
    
    private var groupedContent: (directItems: ContainerFocusViewModel.GroupedItems, sectionGroups: [ContainerFocusViewModel.SectionGroup]) {
        viewModel.groupedContent(for: target)
    }
    
    private var childContainerGroups: [ContainerFocusViewModel.ChildContainerGroup] {
        guard case .space(let space) = target else { return [] }
        return viewModel.childContainerGroups(for: space)
    }
    
    private let headerThreshold: CGFloat = 60
    
    init(target: ContainerTarget, viewModel: ContainerFocusViewModel, modelContext: ModelContext) {
        self.target = target
        self.viewModel = viewModel
        self.modelContext = modelContext
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
        .coordinateSpace(name: "ScrollView")
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .onPreferenceChange(SectionPositionPreferenceKey.self) { positions in
            updateActiveNestedSections(from: positions)
        }
    }
    
    private func updateActiveNestedSections(from positions: [SectionPositionInfo]) {
        guard case .space = target else { return }
        
        var newActiveSections: [ContainerChild.ID: String] = [:]
        let positionsByContainer = Dictionary(grouping: positions) { $0.childContainerID }
        
        for (childContainerID, containerPositions) in positionsByContainer {
            guard viewModel.expandedChildContainers.contains(childContainerID) else { continue }
            
            if let topmostSection = containerPositions.min(by: { $0.yPosition < $1.yPosition }) {
                if topmostSection.yPosition <= headerThreshold {
                    newActiveSections[childContainerID] = topmostSection.title
                }
            }
        }
        
        if newActiveSections != viewModel.activeNestedSections {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.activeNestedSections = newActiveSections
            }
        }
    }
    
    // MARK: - Content Builders
    
    @ViewBuilder
    private var listProjectContent: some View {
        let directItems = groupedContent.directItems
        
        // Unscheduled direct items section
        if !directItems.unscheduled.isEmpty {
            Section {
                ForEach(directItems.unscheduled, id: \.persistentModelID) { item in
                    itemRow(item)
                }
            } header: {
                SectionTitleLabel(title: "Unscheduled")
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        
        // Scheduled direct items section
        if !directItems.scheduled.isEmpty {
            Section {
                ForEach(directItems.scheduled, id: \.persistentModelID) { item in
                    itemRow(item)
                }
            } header: {
                SectionTitleLabel(title: "Scheduled")
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        
        // Task sections
        ForEach(groupedContent.sectionGroups) { sectionGroup in
            taskSectionContent(sectionGroup: sectionGroup)
        }
    }
    
    @ViewBuilder
    private var spaceContent: some View {
        let directItems = groupedContent.directItems
        
        // Unscheduled direct items section
        if !directItems.unscheduled.isEmpty {
            Section {
                ForEach(directItems.unscheduled, id: \.persistentModelID) { item in
                    itemRow(item)
                }
            } header: {
                SectionTitleLabel(title: "Unscheduled")
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        
        // Scheduled direct items section
        if !directItems.scheduled.isEmpty {
            Section {
                ForEach(directItems.scheduled, id: \.persistentModelID) { item in
                    itemRow(item)
                }
            } header: {
                SectionTitleLabel(title: "Scheduled")
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
    
    private func itemRow(_ item: Item) -> some View {
        ItemRowView(item: item)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
    }
    
    @ViewBuilder
    private func taskSectionContent(sectionGroup: ContainerFocusViewModel.SectionGroup, titleColor: Color = .secondary) -> some View {
        taskSectionContent(sectionGroup: sectionGroup, childContainerID: nil, titleColor: titleColor)
    }
    
    @ViewBuilder
    private func taskSectionContent(sectionGroup: ContainerFocusViewModel.SectionGroup, childContainerID: ContainerChild.ID?, titleColor: Color = .secondary) -> some View {
        Section {
            if sectionGroup.groupedItems.unscheduled.isEmpty && sectionGroup.groupedItems.scheduled.isEmpty {
                EmptyView()
            } else {
                ForEach(sectionGroup.groupedItems.unscheduled, id: \.persistentModelID) { item in
                    itemRow(item)
                }
                ForEach(sectionGroup.groupedItems.scheduled, id: \.persistentModelID) { item in
                    itemRow(item)
                }
            }
        } header: {
            SectionTitleLabel(title: sectionGroup.title, titleColor: titleColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.clear)
                .padding(.horizontal, -16)
                .padding(.vertical, -10)
                .overlay {
                    if let childContainerID = childContainerID {
                        PositionTracker(childContainerID: childContainerID, title: sectionGroup.title)
                    }
                }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    private func childContainerContent(childGroup: ContainerFocusViewModel.ChildContainerGroup) -> some View {
        let isExpanded = viewModel.isChildContainerExpanded(childGroup.child)
        let totalCount = childGroup.directItems.unscheduled.count + childGroup.directItems.scheduled.count + childGroup.sectionGroups.reduce(0) { $0 + $1.groupedItems.unscheduled.count + $1.groupedItems.scheduled.count }
        let activeNestedTitle = viewModel.activeNestedSections[childGroup.child.id]
        
        return Section {
            if isExpanded {
                // Direct items in container
                if !childGroup.directItems.unscheduled.isEmpty || !childGroup.directItems.scheduled.isEmpty {
                    ForEach(childGroup.directItems.unscheduled, id: \.persistentModelID) { item in
                        itemRow(item)
                    }
                    ForEach(childGroup.directItems.scheduled, id: \.persistentModelID) { item in
                        itemRow(item)
                    }
                }
                
                // Task sections in container
                ForEach(childGroup.sectionGroups) { sectionGroup in
                    taskSectionContent(sectionGroup: sectionGroup, childContainerID: childGroup.child.id)
                }
            }
        } header: {
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

struct SectionTitleLabel: View {
    let title: String
    var titleColor: Color = .secondary
    
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(6)
    }
}

struct CollapsibleHeaderLabel: View {
    let title: String
    let subtitle: String?
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
                    .foregroundStyle(.secondary)
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
    EmptyView()
        .modelContainer(for: [Space.self, Project.self, List.self, Item.self, TaskSection.self], inMemory: true)
}