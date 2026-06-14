//
//  ContainerFocusListView.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - Main Content View

struct ContainerFocusListView: View {
    let target: ContainerTarget
    @ObservedObject var viewModel: ContainerFocusViewModel
    let modelContext: ModelContext
    
    @State private var itemDragState = ItemDragState()

    private var groupedContent: (directItems: ContainerFocusViewModel.GroupedItems, sectionGroups: [ContainerFocusViewModel.SectionGroup]) {
        viewModel.groupedContent(for: target)
    }

    private var childContainerGroups: [ContainerFocusViewModel.ChildContainerGroup] {
        guard case .space(let space) = target else { return [] }
        return viewModel.childContainerGroups(for: space)
    }

    private let layoutMetrics = LayoutMetrics.focusView

    init(target: ContainerTarget, viewModel: ContainerFocusViewModel, modelContext: ModelContext) {
        self.target = target
        self.viewModel = viewModel
        self.modelContext = modelContext
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // Coordinate space for frame calculations
                    GeometryReader { geometry in
                        Color.clear
                            .frame(width: 0, height: 0)
                            .preference(key: ItemContentOriginKey.self, value: geometry.frame(in: .global).origin)
                    }
                    .onPreferenceChange(ItemContentOriginKey.self) { origin in
                        itemDragState.contentOriginInWindow = origin
                    }
                    
                    // Direct items - Unscheduled
                    if !directUnscheduledSlots.isEmpty {
                        let unscheduledItems = groupedContent.directItems.unscheduled
                        Section(header: sectionHeader("Unscheduled")) {
                            ForEach(directUnscheduledSlots, id: \.id) { slot in
                                switch slot {
                                case .item(let item):
                                    ItemRowView(
                                        item: item,
                                        groupContext: .directUnscheduled(target),
                                        isDragEnabled: true,
                                        unscheduledItems: unscheduledItems
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                case .gap:
                                    ItemDropGapView()
                                }
                            }
                        }
                    }

                    // Direct items - Scheduled
                    if !groupedContent.directItems.scheduled.isEmpty {
                        Section(header: sectionHeader("Scheduled")) {
                            ForEach(groupedContent.directItems.scheduled) { item in
                                ItemRowView(
                                    item: item,
                                    groupContext: .directUnscheduled(target),
                                    isDragEnabled: false,
                                    unscheduledItems: []
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                        }
                    }

                    // Task Sections
                    ForEach(groupedContent.sectionGroups) { sectionGroup in
                        Section(header: sectionHeader(sectionGroup.title)) {
                            if sectionGroup.groupedItems.isEmpty {
                                NoContentRow()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                            } else {
                                let sectionUnscheduled = sectionGroup.groupedItems.unscheduled
                                ForEach(sectionUnscheduled) { item in
                                    ItemRowView(
                                        item: item,
                                        groupContext: .sectionUnscheduled(sectionGroup.section),
                                        isDragEnabled: true,
                                        unscheduledItems: sectionUnscheduled
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                                ForEach(sectionGroup.groupedItems.scheduled) { item in
                                    ItemRowView(
                                        item: item,
                                        groupContext: .sectionUnscheduled(sectionGroup.section),
                                        isDragEnabled: false,
                                        unscheduledItems: []
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                    }

                    // Child Containers (for Space view)
                    ForEach(childContainerGroups) { childGroup in
                        Section(header: childContainerHeader(childGroup)) {
                            if viewModel.isChildContainerExpanded(childGroup.child) {
                                // Child container's direct items - Unscheduled
                                if !childGroup.directItems.unscheduled.isEmpty {
                                    let childUnscheduled = childGroup.directItems.unscheduled
                                    ForEach(childUnscheduled) { item in
                                        ItemRowView(
                                            item: item,
                                            groupContext: .childContainerUnscheduled(childGroup.child),
                                            isDragEnabled: true,
                                            unscheduledItems: childUnscheduled
                                        )
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                    }
                                }

                                // Child container's direct items - Scheduled
                                if !childGroup.directItems.scheduled.isEmpty {
                                    ForEach(childGroup.directItems.scheduled) { item in
                                        ItemRowView(
                                            item: item,
                                            groupContext: .childContainerUnscheduled(childGroup.child),
                                            isDragEnabled: false,
                                            unscheduledItems: []
                                        )
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                    }
                                }

                                // Child container's task sections
                                ForEach(childGroup.sectionGroups) { sectionGroup in
                                    Section(header: sectionHeader(sectionGroup.title)) {
                                        if sectionGroup.groupedItems.isEmpty {
                                            NoContentRow()
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 4)
                                        } else {
                                            let childSectionUnscheduled = sectionGroup.groupedItems.unscheduled
                                            ForEach(childSectionUnscheduled) { item in
                                                ItemRowView(
                                                    item: item,
                                                    groupContext: .sectionUnscheduled(sectionGroup.section),
                                                    isDragEnabled: true,
                                                    unscheduledItems: childSectionUnscheduled
                                                )
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                            }
                                            ForEach(sectionGroup.groupedItems.scheduled) { item in
                                                ItemRowView(
                                                    item: item,
                                                    groupContext: .sectionUnscheduled(sectionGroup.section),
                                                    isDragEnabled: false,
                                                    unscheduledItems: []
                                                )
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .coordinateSpace(name: "ItemContentView")
                .padding(.bottom, 80)
                // Observe drag state changes for target index calculation
                // Note: targetIndex is now updated directly in updateDragPosition
                // Handle reordering when drag ends
                .onChange(of: itemDragState.itemAtEnd) { oldValue, newValue in
                    if let draggedItem = itemDragState.itemAtEnd {
                        performReorder(item: draggedItem, toIndex: itemDragState.targetIndexAtEnd)
                        itemDragState.clearEndState()
                    }
                }
            }
            .scrollDisabled(itemDragState.isDragging)
            .environment(itemDragState)
            .onPreferenceChange(SectionPositionPreferenceKey.self) { positions in
                updateActiveNestedSections(from: positions)
            }
            
            // Floating drag row overlay
            if let floatingItem = itemDragState.floatingItem {
                ItemFloatingRow(
                    item: floatingItem,
                    dragScale: itemDragState.dragScale,
                    dragOpacity: itemDragState.dragOpacity,
                    fingerPosition: itemDragState.location,
                    contentOriginInWindow: itemDragState.contentOriginInWindow
                )
            }
        }
    }
    
    // MARK: - Computed Slot Properties
    
    /// Slots for direct unscheduled items with gap inserted at drop position.
    private var directUnscheduledSlots: [ItemSlotItem] {
        let items = groupedContent.directItems.unscheduled
        guard !items.isEmpty else { return [] }
        
        // Check if we're dragging within this context
        guard itemDragState.isDragging,
              case .directUnscheduled(let dragTarget) = itemDragState.groupContext else {
            return items.map { ItemSlotItem.item($0) }
        }
        
        // Compare targets properly
        let targetsMatch: Bool
        switch (dragTarget, target) {
        case (.space(let s1), .space(let s2)): targetsMatch = s1.persistentModelID == s2.persistentModelID
        case (.project(let p1), .project(let p2)): targetsMatch = p1.persistentModelID == p2.persistentModelID
        case (.list(let l1), .list(let l2)): targetsMatch = l1.persistentModelID == l2.persistentModelID
        default: targetsMatch = false
        }
        
        guard targetsMatch, itemDragState.targetIndex <= items.count else {
            return items.map { ItemSlotItem.item($0) }
        }
        
        // Build slots: keep dragged item in array, insert gap at target
        var slots: [ItemSlotItem] = []
        let draggedID = itemDragState.draggingItem?.id
        
        for (index, item) in items.enumerated() {
            // Insert gap at target index
            if index == itemDragState.targetIndex {
                slots.append(.gap)
            }
            // Add item (keep dragged item for gesture continuity, it will be hidden via opacity)
            slots.append(.item(item))
        }
        
        // If gap should be at the end
        if itemDragState.targetIndex == items.count {
            slots.append(.gap)
        }
        
        return slots
    }
    
    // MARK: - Drag and Drop Logic
    
    /// Gets the unscheduled items for a given group context (excluding the dragged item).
    private func getUnscheduledItems(for context: ItemGroupContext) -> [Item] {
        let allUnscheduled = getAllUnscheduledItems(for: context)
        return allUnscheduled.filter { $0.id != itemDragState.draggingItem?.id }
    }
    
    /// Gets all unscheduled items for a given group context (including the dragged item).
    private func getAllUnscheduledItems(for context: ItemGroupContext) -> [Item] {
        switch context {
        case .directUnscheduled(let containerTarget):
            let items: [Item]
            switch containerTarget {
            case .list(let list):
                items = list.items
            case .project(let project):
                items = project.items
            case .space(let space):
                items = space.items
            }
            return items.filter { $0.doDate == nil && $0.taskSection == nil }
                .sorted { $0.sortIndex < $1.sortIndex }
                
        case .childContainerUnscheduled(let child):
            let items: [Item]
            switch child {
            case .list(let list):
                items = list.items
            case .project(let project):
                items = project.items
            }
            return items.filter { $0.doDate == nil && $0.taskSection == nil }
                .sorted { $0.sortIndex < $1.sortIndex }
                
        case .sectionUnscheduled(let section):
            return Array(section.items).filter { $0.doDate == nil }
                .sorted { $0.sortIndex < $1.sortIndex }
        }
    }
    
    /// Performs the reordering of an item to a new index within its group.
    private func performReorder(item: Item, toIndex: Int) {
        guard let context = itemDragState.groupContext else { return }
        
        let allUnscheduled = getAllUnscheduledItems(for: context)
        guard !allUnscheduled.isEmpty else { return }
        
        // Remove the dragged item from its current position
        guard let currentIndex = allUnscheduled.firstIndex(where: { $0.id == item.id }) else { return }
        var reordered = allUnscheduled
        reordered.remove(at: currentIndex)
        
        // Insert at the new position (clamped to valid range)
        let clampedIndex = min(toIndex, reordered.count)
        reordered.insert(item, at: clampedIndex)
        
        // Update sortIndex values
        for (index, item) in reordered.enumerated() {
            item.sortIndex = index
            item.touch()
        }
        
        // Save the context
        try? modelContext.save()
    }
    
    /// Computes slot items with a gap inserted at the drop position during drag.
    private func computeSlotItems(items: [Item], context: ItemGroupContext) -> [ItemSlotItem] {
        // Check if we're dragging within this context
        guard itemDragState.isDragging,
              itemDragState.groupContext == context,
              itemDragState.targetIndex <= items.count else {
            return items.map { ItemSlotItem.item($0) }
        }
        
        // Insert gap at the target index
        var slots: [ItemSlotItem] = []
        for (index, item) in items.enumerated() {
            if index == itemDragState.targetIndex {
                slots.append(.gap)
            }
            // Only add item if it's not the one being dragged
            if item.id != itemDragState.draggingItem?.id {
                slots.append(.item(item))
            }
        }
        // If gap should be at the end
        if itemDragState.targetIndex == items.count {
            slots.append(.gap)
        }
        
        return slots
    }

    // MARK: - Section Headers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        if let childGroup = findChildContainerGroup(title: title) {
            CollapsibleHeaderLabel(
                title: childGroup.title,
                subtitle: viewModel.activeNestedSections[childGroup.child.id],
                symbol: childGroup.symbol,
                color: childGroup.color,
                itemCount: childGroup.directItems.unscheduled.count + childGroup.directItems.scheduled.count + childGroup.sectionGroups.reduce(0) { $0 + $1.groupedItems.unscheduled.count + $1.groupedItems.scheduled.count },
                isExpanded: viewModel.isChildContainerExpanded(childGroup.child)
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleChildContainer(childGroup.child)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.04))
            .cornerRadius(6)
        } else {
            SectionTitleLabel(title: title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(6)
        }
    }

    @ViewBuilder
    private func childContainerHeader(_ childGroup: ContainerFocusViewModel.ChildContainerGroup) -> some View {
        CollapsibleHeaderLabel(
            title: childGroup.title,
            subtitle: viewModel.activeNestedSections[childGroup.child.id],
            symbol: childGroup.symbol,
            color: childGroup.color,
            itemCount: childGroup.directItems.unscheduled.count + childGroup.directItems.scheduled.count + childGroup.sectionGroups.reduce(0) { $0 + $1.groupedItems.unscheduled.count + $1.groupedItems.scheduled.count },
            isExpanded: viewModel.isChildContainerExpanded(childGroup.child)
        ) {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.toggleChildContainer(childGroup.child)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(6)
    }

    // MARK: - Helper Methods

    private func findChildContainerGroup(title: String) -> ContainerFocusViewModel.ChildContainerGroup? {
        return childContainerGroups.first { $0.title == title }
    }

    private func updateActiveNestedSections(from positions: [SectionPositionInfo]) {
        guard case .space = target else { return }

        var newActiveSections: [ContainerChild.ID: String] = [:]
        let positionsByContainer = Dictionary(grouping: positions) { $0.childContainerID }

        for (childContainerID, containerPositions) in positionsByContainer {
            guard viewModel.expandedChildContainers.contains(childContainerID) else { continue }

            if let topmostSection = containerPositions.min(by: { $0.yPosition < $1.yPosition }) {
                newActiveSections[childContainerID] = topmostSection.title
            }
        }

        if newActiveSections != viewModel.activeNestedSections {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.activeNestedSections = newActiveSections
            }
        }
    }
}

// MARK: - Helper Views

struct SectionTitleLabel: View {
    let title: String
    var titleColor: Color = .secondary

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(titleColor)
            .lineLimit(1)
            .truncationMode(.tail)
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
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

struct NoContentRow: View {
    var body: some View {
        Text("No content")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .italic()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(Color.secondary.opacity(0.03))
            .cornerRadius(6)
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    EmptyView()
        .modelContainer(for: [Space.self, Project.self, List.self, Item.self, TaskSection.self], inMemory: true)
}