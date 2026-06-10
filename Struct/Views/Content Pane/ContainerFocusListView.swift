//
//  ContainerFocusListView.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - Task Slot

/// One element in the task list during drag: either a real item/section header or the drop-zone gap.
enum TaskSlot: Identifiable, Hashable {
    case sectionHeader(String)  // Section title
    case item(Item, TaskDropTarget)
    case gap
    
    var id: String {
        switch self {
        case .sectionHeader(let title): return "header:\(title)"
        case .item(let item, _): return "item:\(item.persistentModelID)"
        case .gap: return "gap"
        }
    }
}

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
    @State private var taskDragState: TaskDragState
    
    private var groupedContent: (directItems: ContainerFocusViewModel.GroupedItems, sectionGroups: [ContainerFocusViewModel.SectionGroup]) {
        viewModel.groupedContent(for: target)
    }
    
    private var childContainerGroups: [ContainerFocusViewModel.ChildContainerGroup] {
        guard case .space(let space) = target else { return [] }
        return viewModel.childContainerGroups(for: space)
    }
    
    private let headerThreshold: CGFloat = 60
    private let layoutMetrics = LayoutMetrics.focusView
    
    init(target: ContainerTarget, viewModel: ContainerFocusViewModel, modelContext: ModelContext) {
        self.target = target
        self.viewModel = viewModel
        self.modelContext = modelContext
        _taskDragState = State(wrappedValue: TaskDragState())
    }
    
    // MARK: - Slots Computation
    
    /// Build the flat array of all items for slot computation.
    /// This includes section headers and items, matching the visual layout.
    private var allTaskSlots: [TaskSlot] {
        var result: [TaskSlot] = []
        
        let directItems = groupedContent.directItems
        
        // Unscheduled direct items
        if !directItems.unscheduled.isEmpty {
            result.append(.sectionHeader("Unscheduled"))
            for item in directItems.unscheduled {
                result.append(.item(item, .directItems(containerTarget: target, isScheduled: false)))
            }
        }
        
        // Scheduled direct items
        if !directItems.scheduled.isEmpty {
            result.append(.sectionHeader("Scheduled"))
            for item in directItems.scheduled {
                result.append(.item(item, .directItems(containerTarget: target, isScheduled: true)))
            }
        }
        
        // Task sections
        for sectionGroup in groupedContent.sectionGroups {
            result.append(.sectionHeader(sectionGroup.title))
            for item in sectionGroup.groupedItems.unscheduled {
                result.append(.item(item, .taskSection(section: sectionGroup.section)))
            }
            for item in sectionGroup.groupedItems.scheduled {
                result.append(.item(item, .taskSection(section: sectionGroup.section)))
            }
        }
        
        // Child containers (lists and projects within the space)
        for childGroup in childContainerGroups {
            // Always show the child container header
            result.append(.sectionHeader(childGroup.title))
            
            if viewModel.isChildContainerExpanded(childGroup.child) {
                // Show items when expanded
                if !childGroup.directItems.unscheduled.isEmpty {
                    for item in childGroup.directItems.unscheduled {
                        result.append(.item(item, .directItems(containerTarget: childGroup.child.target, isScheduled: false)))
                    }
                }
                if !childGroup.directItems.scheduled.isEmpty {
                    for item in childGroup.directItems.scheduled {
                        result.append(.item(item, .directItems(containerTarget: childGroup.child.target, isScheduled: true)))
                    }
                }
                for sectionGroup in childGroup.sectionGroups {
                    result.append(.sectionHeader(sectionGroup.title))
                    for item in sectionGroup.groupedItems.unscheduled {
                        result.append(.item(item, .taskSection(section: sectionGroup.section)))
                    }
                    for item in sectionGroup.groupedItems.scheduled {
                        result.append(.item(item, .taskSection(section: sectionGroup.section)))
                    }
                }
            }
        }
        
        return result
    }
    
    /// Computed slots with gap insertion during drag.
    private var slots: [TaskSlot] {
        guard taskDragState.isDragging, let dragging = taskDragState.dragging else {
            return allTaskSlots
        }
        
        var result = allTaskSlots
        let draggingIsScheduled = dragging.doDate != nil
        
        // Find the ghost position (dragged item in the slots)
        let ghostPos = result.firstIndex { slot in
            if case .item(let item, _) = slot {
                return item.persistentModelID == dragging.persistentModelID
            }
            return false
        }
        
        // Compute target index based on drag position
        let targetIndex = computeTargetIndex(y: taskDragState.location.y, draggingIsScheduled: draggingIsScheduled)
        
        // Adjust for ghost position
        let adjusted = ghostPos.map { targetIndex > $0 ? targetIndex + 1 : targetIndex } ?? targetIndex
        let idx = max(0, min(adjusted, result.count))
        
        // Insert gap at drop position
        result.insert(.gap, at: idx)
        
        return result
    }
    
    /// Compute the target index based on drag Y position.
    private func computeTargetIndex(y: CGFloat, draggingIsScheduled: Bool) -> Int {
        // Build a list of item frames for comparison
        var itemFrames: [(y: CGFloat, index: Int)] = []
        
        for (index, slot) in allTaskSlots.enumerated() {
            if case .item(let item, let dropTarget) = slot {
                // Filter by scheduled/unscheduled compatibility
                if draggingIsScheduled && !dropTarget.acceptsScheduledTasks { continue }
                if !draggingIsScheduled && !dropTarget.acceptsUnscheduledTasks { continue }
                
                // Use frame if available, otherwise use a default position
                if let frame = taskDragState.rowFrames[item.persistentModelID] {
                    itemFrames.append((y: frame.midY, index: index))
                } else {
                    // Item has no frame yet (e.g., in collapsed container) - skip it
                    continue
                }
            }
        }
        
        // If no items have frames, return 0
        guard !itemFrames.isEmpty else { return 0 }
        
        // Find the closest item to the drag position
        var bestIndex = itemFrames.count
        var bestDist = CGFloat.infinity
        
        for (frameY, index) in itemFrames {
            let dist = abs(y - frameY)
            if dist < bestDist {
                bestDist = dist
                bestIndex = y < frameY ? index : index + 1
            }
        }
        
        return max(0, min(bestIndex, itemFrames.count))
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // Render slots with gap insertion
                    ForEach(slots) { slot in
                        slotView(for: slot)
                    }
                }
                .padding(.bottom, 80)
                .animation(.spring(duration: layoutMetrics.dragSpringDuration, bounce: layoutMetrics.dragSpringBounce), value: slots.map(\.id))
            }
            .coordinateSpace(name: "ScrollView")
            .scrollContentBackground(.hidden)
            .onPreferenceChange(SectionPositionPreferenceKey.self) { positions in
                updateActiveNestedSections(from: positions)
            }
            .onPreferenceChange(TaskRowFrameKey.self) { frames in
                taskDragState.rowFrames = frames
            }
            .overlay {
                GeometryReader { geo in
                    Color.clear
                        .preference(key: TaskContentOriginKey.self, value: geo.frame(in: .global).origin)
                        .onChange(of: geo.frame(in: .global).origin) { _, newOrigin in
                            taskDragState.viewportOriginInWindow = newOrigin
                        }
                }
            }
            .overlay {
                // Floating drag card
                if taskDragState.isDragging,
                   let dragging = taskDragState.dragging,
                   taskDragState.floatingCardItem != nil {
                    TaskFloatingCard(item: dragging)
                        .position(x: taskDragState.location.x, y: taskDragState.location.y)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
        }
    }
    
    @ViewBuilder
    private func slotView(for slot: TaskSlot) -> some View {
        switch slot {
        case .sectionHeader(let title):
            // Check if this is a child container header (collapsible)
            if let childGroup = findChildContainerGroup(title: title) {
                // Collapsible child container header
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
                // Regular section header
                SectionTitleLabel(title: title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(6)
            }
            
        case .item(let item, let dropTarget):
            let isGhosted = taskDragState.dragging?.persistentModelID == item.persistentModelID
            let isDropTarget = taskDragState.target == dropTarget
            
            ItemRowView(
                item: item,
                isHighlighted: isDropTarget && !isGhosted,
                onDragBegan: { [self] windowLoc in
                    handleDragBegan(item: item, windowLocation: windowLoc)
                },
                onDragChanged: { [self] windowLoc in
                    handleDragChanged(windowLocation: windowLoc)
                },
                onDragEnded: { [self] in
                    handleDragEnded()
                }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .opacity(isGhosted ? 0 : 1)
            .frame(height: isGhosted ? 0 : nil)
            .clipped()
            .allowsHitTesting(!isGhosted)
            .background {
                GeometryReader { geo in
                    let frame = geo.frame(in: .named("ScrollView"))
                    Color.clear
                        .preference(key: TaskRowFrameKey.self, value: [item.persistentModelID: frame])
                        .onChange(of: frame.height, initial: true) { _, h in
                            if !taskDragState.isDragging {
                                taskDragState.cardHeight = h
                            }
                        }
                }
            }
            
        case .gap:
            TaskDropGapView(cardHeight: taskDragState.cardHeight)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                    removal: .opacity.animation(.easeOut(duration: layoutMetrics.cardFadeOutDuration))
                ))
        }
    }
    
    // MARK: - Drag Handlers
    
    private func handleDragBegan(item: Item, windowLocation: CGPoint) {
        let contentLoc = taskDragState.toContent(windowLocation)
        taskDragState.begin(item: item, at: contentLoc, height: taskDragState.cardHeight)
    }
    
    private func handleDragChanged(windowLocation: CGPoint) {
        guard taskDragState.isDragging else { return }
        let contentLoc = taskDragState.toContent(windowLocation)
        taskDragState.location = contentLoc
        
        // Update target based on position
        let draggingIsScheduled = taskDragState.dragging?.doDate != nil
        let targetIndex = computeTargetIndex(y: contentLoc.y, draggingIsScheduled: draggingIsScheduled)
        
        // Find the drop target at this index
        if let slot = slots[safe: targetIndex], case .item(_, let dropTarget) = slot {
            taskDragState.target = dropTarget
        }
    }
    
    private func handleDragEnded() {
        guard taskDragState.isDragging else { return }
        commitDrop()
        taskDragState.end()
    }
    
    private func commitDrop() {
        guard let target = taskDragState.target,
              let dragging = taskDragState.dragging else { return }
        
        // Validate drop target compatibility
        let draggingIsScheduled = dragging.doDate != nil
        if draggingIsScheduled && !target.acceptsScheduledTasks { return }
        if !draggingIsScheduled && !target.acceptsUnscheduledTasks { return }
        
        // Perform the move
        switch target {
        case .directItems(let containerTarget, let isScheduled):
            moveItemToDirectItems(dragging, containerTarget: containerTarget, isScheduled: isScheduled)
        case .taskSection(let section):
            moveItemToSection(dragging, section: section)
        }
    }
    
    private func moveItemToDirectItems(_ item: Item, containerTarget: ContainerTarget, isScheduled: Bool) {
        // Update parent
        switch containerTarget {
        case .space(let space): item.setParent(.space(space))
        case .list(let list): item.setParent(.list(list))
        case .project(let project): item.setParent(.project(project))
        }
        
        // Get all items in target section
        var itemsInSection: [Item]
        switch containerTarget {
        case .space(let space):
            itemsInSection = space.items.filter { $0.taskSection == nil && ($0.doDate != nil) == isScheduled }
        case .list(let list):
            itemsInSection = list.items.filter { $0.taskSection == nil && ($0.doDate != nil) == isScheduled }
        case .project(let project):
            itemsInSection = project.items.filter { $0.taskSection == nil && ($0.doDate != nil) == isScheduled }
        }
        
        // Remove dragged item if present
        itemsInSection.removeAll { $0.persistentModelID == item.persistentModelID }
        
        // Sort scheduled items by doDate then title
        if isScheduled {
            itemsInSection.sort { a, b in
                guard let aDate = a.doDate, let bDate = b.doDate else { return false }
                if aDate != bDate { return aDate < bDate }
                return a.title < b.title
            }
        }
        
        // Add at end
        itemsInSection.append(item)
        
        // Repack sort indices
        for (i, it) in itemsInSection.enumerated() {
            it.sortIndex = i
        }
        
        try? modelContext.save()
    }
    
    private func moveItemToSection(_ item: Item, section: TaskSection) {
        // Update parent
        item.setParent(.taskSection(section))
        
        // Get all items in section
        var itemsInSection = Array(section.items)
        
        // Remove dragged item if present
        itemsInSection.removeAll { $0.persistentModelID == item.persistentModelID }
        
        // Sort if there are scheduled items
        let hasScheduled = itemsInSection.contains { $0.doDate != nil } || (item.doDate != nil)
        if hasScheduled {
            itemsInSection.sort { a, b in
                guard let aDate = a.doDate, let bDate = b.doDate else { return false }
                if aDate != bDate { return aDate < bDate }
                return a.title < b.title
            }
        }
        
        // Add at end
        itemsInSection.append(item)
        
        // Repack sort indices
        for (i, it) in itemsInSection.enumerated() {
            it.sortIndex = i
        }
        
        try? modelContext.save()
    }
    
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

// MARK: - Extensions

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    EmptyView()
        .modelContainer(for: [Space.self, Project.self, List.self, Item.self, TaskSection.self], inMemory: true)
}