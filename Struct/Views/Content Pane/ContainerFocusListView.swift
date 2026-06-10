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

// MARK: - Container Frame Tracker

/// Tracks the frame of a container/section area for drop target detection.
struct ContainerDropZoneAnchor: View {
    let targetKey: String
    var dragState: TaskDragState
    
    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .named("ScrollView"))
            Color.clear
                .preference(key: TaskContainerFrameKey.self, value: [targetKey: frame])
        }
    }
}

// MARK: - Drop Zone Highlight View

/// Dashed border highlight shown on container/section when it's a valid drop target.
struct DropZoneHighlightView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(
                Color.accentColor.opacity(0.6),
                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
            )
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.05))
            )
            .transition(.opacity)
    }
}

// MARK: - Main Content View

struct ContainerFocusListView: View {
    let target: ContainerTarget
    @ObservedObject var viewModel: ContainerFocusViewModel
    let modelContext: ModelContext
    @State private var highlightedItemId: PersistentIdentifier?
    @State private var taskDragState: TaskDragState
    @State private var containerFrames: [String: CGRect] = [:]
    @State private var highlightedDropTarget: TaskDropTarget? = nil
    
    private var groupedContent: (directItems: ContainerFocusViewModel.GroupedItems, sectionGroups: [ContainerFocusViewModel.SectionGroup]) {
        viewModel.groupedContent(for: target)
    }
    
    private var childContainerGroups: [ContainerFocusViewModel.ChildContainerGroup] {
        guard case .space(let space) = target else { return [] }
        return viewModel.childContainerGroups(for: space)
    }
    
    private let headerThreshold: CGFloat = 60
    private let autoScrollEdgeThreshold: CGFloat = 80
    private let autoScrollSpeed: CGFloat = 15
    
    init(target: ContainerTarget, viewModel: ContainerFocusViewModel, modelContext: ModelContext) {
        self.target = target
        self.viewModel = viewModel
        self.modelContext = modelContext
        _taskDragState = State(wrappedValue: TaskDragState())
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
        .onPreferenceChange(TaskContainerFrameKey.self) { frames in
            containerFrames = frames
            taskDragState.containerFrames = frames
            updateHighlightedDropTarget()
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
            }
        }
    }

    private var nextItemSortIndex: Int {
        (target.items.map(\.sortIndex).max() ?? -1) + 1
    }

    private func parentForTarget() -> ItemParent? {
        switch target {
        case .space(let s): return .space(s)
        case .project(let p): return .project(p)
        case .list(let l): return .list(l)
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
    
    // MARK: - Drag and Drop Helpers
    
    private func updateHighlightedDropTarget() {
        guard taskDragState.isDragging,
              let dragging = taskDragState.dragging else {
            highlightedDropTarget = nil
            return
        }
        
        highlightedDropTarget = computeContainerTarget(draggingItemID: dragging.persistentModelID)
        taskDragState.target = highlightedDropTarget
    }
    
    /// Computes the container-level drop target based on drag position.
    private func computeContainerTarget(draggingItemID: PersistentIdentifier) -> TaskDropTarget? {
        let y = taskDragState.location.y
        let draggingIsScheduled = taskDragState.dragging?.doDate != nil
        
        var bestTarget: (target: TaskDropTarget, dist: CGFloat)? = nil
        
        for (key, frame) in containerFrames {
            // Check if drag position is within this container's frame
            guard frame.minY <= y && y <= frame.maxY else { continue }
            
            // Parse the target key
            guard let dropTarget = parseTargetKey(key, draggingIsScheduled: draggingIsScheduled) else { continue }
            
            // Prefer targets closer to the drag position
            let dist = abs(y - frame.midY)
            if bestTarget == nil || dist < bestTarget!.dist {
                bestTarget = (target: dropTarget, dist: dist)
            }
        }
        
        return bestTarget?.target
    }
    
    /// Parses a target key into a TaskDropTarget.
    private func parseTargetKey(_ key: String, draggingIsScheduled: Bool) -> TaskDropTarget? {
        let parts = key.split(separator: ":")
        guard parts.count >= 2 else { return nil }
        
        if parts[0] == "directItems" && parts.count == 4 {
            let containerType = String(parts[1])
            let containerID = String(parts[2])
            let isScheduled = parts[3] == "true"
            
            // Validate scheduled/unscheduled compatibility
            if draggingIsScheduled && !isScheduled { return nil }
            if !draggingIsScheduled && isScheduled { return nil }
            
            // Resolve container based on type and ID
            return resolveContainerTarget(type: containerType, id: containerID, isScheduled: isScheduled)
        } else if parts[0] == "taskSection" && parts.count == 2 {
            let sectionID = String(parts[1])
            return resolveTaskSectionTarget(id: sectionID)
        }
        
        return nil
    }
    
    private func resolveContainerTarget(type: String, id: String, isScheduled: Bool) -> TaskDropTarget? {
        // Resolve based on container type
        switch type {
        case "space":
            guard let space = findSpace(id: id) else { return nil }
            return .directItems(containerTarget: .space(space), isScheduled: isScheduled)
        case "list":
            guard let list = findList(id: id) else { return nil }
            return .directItems(containerTarget: .list(list), isScheduled: isScheduled)
        case "project":
            guard let project = findProject(id: id) else { return nil }
            return .directItems(containerTarget: .project(project), isScheduled: isScheduled)
        default:
            return nil
        }
    }
    
    private func resolveTaskSectionTarget(id: String) -> TaskDropTarget? {
        // Search through all possible task sections
        // Direct sections in current target
        for sectionGroup in groupedContent.sectionGroups {
            if String(describing: sectionGroup.section.persistentModelID) == id {
                return .taskSection(section: sectionGroup.section)
            }
        }
        
        // Sections in child containers (for space view)
        for childGroup in childContainerGroups {
            for sectionGroup in childGroup.sectionGroups {
                if String(describing: sectionGroup.section.persistentModelID) == id {
                    return .taskSection(section: sectionGroup.section)
                }
            }
        }
        
        return nil
    }
    
    private func findSpace(id: String) -> Space? {
        // Can't use String(describing:) in #Predicate, so fetch all and filter
        let descriptor = FetchDescriptor<Space>()
        let spaces = try? modelContext.fetch(descriptor)
        return spaces?.first { String(describing: $0.persistentModelID) == id }
    }
    
    private func findList(id: String) -> List? {
        let descriptor = FetchDescriptor<List>()
        let lists = try? modelContext.fetch(descriptor)
        return lists?.first { String(describing: $0.persistentModelID) == id }
    }
    
    private func findProject(id: String) -> Project? {
        let descriptor = FetchDescriptor<Project>()
        let projects = try? modelContext.fetch(descriptor)
        return projects?.first { String(describing: $0.persistentModelID) == id }
    }
    
    private func makeDragHandlers(for item: Item) -> (
        onDragBegan: (CGPoint) -> Void,
        onDragChanged: (CGPoint) -> Void,
        onDragEnded: () -> Void
    ) {
        return (
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
    }
    
    private func handleDragBegan(item: Item, windowLocation: CGPoint) {
        let contentLoc = taskDragState.toContent(windowLocation)
        taskDragState.begin(item: item, at: contentLoc, height: taskDragState.cardHeight)
    }
    
    private func handleDragChanged(windowLocation: CGPoint) {
        guard taskDragState.isDragging else { return }
        let contentLoc = taskDragState.toContent(windowLocation)
        taskDragState.location = contentLoc
        updateHighlightedDropTarget()
        handleAutoScroll()
    }
    
    private func handleDragEnded() {
        guard taskDragState.isDragging else { return }
        commitDrop()
        taskDragState.end()
    }
    
    private func handleAutoScroll() {
        guard taskDragState.isDragging else { return }
        
        let y = taskDragState.location.y
        let contentHeight: CGFloat = 800 // Approximate
        
        if y < autoScrollEdgeThreshold {
            taskDragState.autoScrollDelta = -autoScrollSpeed
        } else if y > contentHeight - autoScrollEdgeThreshold {
            taskDragState.autoScrollDelta = autoScrollSpeed
        } else {
            taskDragState.autoScrollDelta = 0
        }
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
                dropZoneHeader(
                    targetKey: makeDirectItemsKey(containerTarget: target, isScheduled: false),
                    title: "Unscheduled",
                    isDropTarget: highlightedDropTarget == .directItems(containerTarget: target, isScheduled: false)
                )
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
                dropZoneHeader(
                    targetKey: makeDirectItemsKey(containerTarget: target, isScheduled: true),
                    title: "Scheduled",
                    isDropTarget: highlightedDropTarget == .directItems(containerTarget: target, isScheduled: true)
                )
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
                dropZoneHeader(
                    targetKey: makeDirectItemsKey(containerTarget: target, isScheduled: false),
                    title: "Unscheduled",
                    isDropTarget: highlightedDropTarget == .directItems(containerTarget: target, isScheduled: false)
                )
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
                dropZoneHeader(
                    targetKey: makeDirectItemsKey(containerTarget: target, isScheduled: true),
                    title: "Scheduled",
                    isDropTarget: highlightedDropTarget == .directItems(containerTarget: target, isScheduled: true)
                )
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
        let handlers = makeDragHandlers(for: item)
        return ItemRowView(
            item: item,
            isHighlighted: item.persistentModelID == highlightedItemId,
            onDragBegan: handlers.onDragBegan,
            onDragChanged: handlers.onDragChanged,
            onDragEnded: handlers.onDragEnded
        )
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .opacity(taskDragState.dragging?.persistentModelID == item.persistentModelID ? 0 : 1)
    }
    
    @ViewBuilder
    private func taskSectionContent(sectionGroup: ContainerFocusViewModel.SectionGroup, titleColor: Color = .secondary) -> some View {
        taskSectionContent(sectionGroup: sectionGroup, childContainerID: nil, titleColor: titleColor)
    }
    
    @ViewBuilder
    private func taskSectionContent(sectionGroup: ContainerFocusViewModel.SectionGroup, childContainerID: ContainerChild.ID?, titleColor: Color = .secondary) -> some View {
        let isDropTarget = highlightedDropTarget == .taskSection(section: sectionGroup.section)
        
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
                    if isDropTarget {
                        DropZoneHighlightView()
                    }
                    if let childContainerID = childContainerID {
                        PositionTracker(childContainerID: childContainerID, title: sectionGroup.title)
                    }
                }
                .background(ContainerDropZoneAnchor(
                    targetKey: "taskSection:\(sectionGroup.section.persistentModelID)",
                    dragState: taskDragState
                ))
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    private func childContainerContent(childGroup: ContainerFocusViewModel.ChildContainerGroup) -> some View {
        let isExpanded = viewModel.isChildContainerExpanded(childGroup.child)
        let totalCount = childGroup.directItems.unscheduled.count + childGroup.directItems.scheduled.count + childGroup.sectionGroups.reduce(0) { $0 + $1.groupedItems.unscheduled.count + $1.groupedItems.scheduled.count }
        let activeNestedTitle = viewModel.activeNestedSections[childGroup.child.id]
        
        // Check if this child container is the drop target
        let isDropTarget: Bool
        switch target {
        case .space(let space):
            isDropTarget = highlightedDropTarget == .directItems(containerTarget: .space(space), isScheduled: false) ||
                          highlightedDropTarget == .directItems(containerTarget: .space(space), isScheduled: true)
        default:
            isDropTarget = false
        }
        
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
            .overlay {
                if isDropTarget {
                    DropZoneHighlightView()
                }
            }
            .background(ContainerDropZoneAnchor(
                targetKey: makeChildContainerKey(childGroup: childGroup),
                dragState: taskDragState
            ))
        } footer: {
            EmptyView()
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    /// Creates a drop zone header with optional highlight.
    @ViewBuilder
    private func dropZoneHeader(targetKey: String, title: String, isDropTarget: Bool) -> some View {
        SectionTitleLabel(title: title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .padding(.horizontal, -16)
            .padding(.vertical, -10)
            .overlay {
                if isDropTarget {
                    DropZoneHighlightView()
                }
            }
            .background(ContainerDropZoneAnchor(
                targetKey: targetKey,
                dragState: taskDragState
            ))
    }
    
    // MARK: - Target Key Helpers
    
    private func makeDirectItemsKey(containerTarget: ContainerTarget, isScheduled: Bool) -> String {
        switch containerTarget {
        case .space(let space):
            return "directItems:space:\(space.persistentModelID):\(isScheduled)"
        case .list(let list):
            return "directItems:list:\(list.persistentModelID):\(isScheduled)"
        case .project(let project):
            return "directItems:project:\(project.persistentModelID):\(isScheduled)"
        }
    }
    
    private func makeChildContainerKey(childGroup: ContainerFocusViewModel.ChildContainerGroup) -> String {
        switch childGroup.child {
        case .list(let list):
            return "directItems:list:\(list.persistentModelID):false"
        case .project(let project):
            return "directItems:project:\(project.persistentModelID):false"
        }
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