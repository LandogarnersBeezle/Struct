//
//  ContainerFocusViewModel.swift
//  Struct
//
//  Created by Otto Kiefer on 05.05.2026.
//

import SwiftUI
import Combine
import SwiftData

/// ViewModel for ContainerFocusView that manages filter state and logic.
@MainActor
class ContainerFocusViewModel: ObservableObject {
    // MARK: - Types
    
    /// Represents a container entry for search/filter results.
    /// `isChild` indicates if the container belongs to a space (drives indentation).
    typealias SearchEntry = (target: ContainerTarget, isChild: Bool)
    
    /// Grouped items for display: unscheduled and scheduled items.
    struct GroupedItems {
        var unscheduled: [Item]  // Items without doDate, sorted by sortIndex
        var scheduled: [Item]    // Items with doDate, sorted by doDate ascending
        
        var isEmpty: Bool { unscheduled.isEmpty && scheduled.isEmpty }
        var count: Int { unscheduled.count + scheduled.count }
        
        init(items: [Item]) {
            // Separate by doDate
            let unscheduled = items.filter { $0.doDate == nil }
            let scheduled = items.filter { $0.doDate != nil }
            
            // Sort unscheduled by sortIndex (for manual reordering)
            self.unscheduled = unscheduled.sorted { $0.sortIndex < $1.sortIndex }
            // Sort scheduled by doDate ascending (earliest first)
            self.scheduled = scheduled.sorted { a, b in
                guard let aDate = a.doDate, let bDate = b.doDate else { return false }
                return aDate < bDate
            }
        }
    }
    
    /// Represents a TaskSection with its grouped items.
    struct SectionGroup: Identifiable {
        let section: TaskSection
        let groupedItems: GroupedItems
        
        var id: PersistentIdentifier { section.persistentModelID }
        var title: String { section.title }
    }
    
    /// Represents a child container (List/Project) with its grouped content for Space view.
    struct ChildContainerGroup: Identifiable {
        let child: ContainerChild
        let directItems: GroupedItems
        let sectionGroups: [SectionGroup]
        
        var id: ContainerChild.ID { child.id }
        var title: String { child.title }
        var symbol: String { child.symbol }
        var color: Color { child.containerColor }
        var isOpen: Bool {
            !directItems.isEmpty || sectionGroups.contains { !$0.groupedItems.isEmpty }
        }
    }
    
    // MARK: - Published Properties
    
    @Published var searchText: String = ""
    @Published var showFilterView: Bool = false
    
    /// Tracks which child containers are expanded in Space view (session-only).
    @Published var expandedChildContainers: Set<ContainerChild.ID> = []
    
    // MARK: - Methods
    
    /// Closes the filter view with animation and resets search state.
    func closeFilterView() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8, blendDuration: 0)) {
            showFilterView = false
            searchText = ""
        }
    }
    
    /// Toggles the filter view visibility.
    func toggleFilterView() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8, blendDuration: 0)) {
            showFilterView.toggle()
        }
    }
    
    /// Computes filtered containers based on search text.
    /// - Parameters:
    ///   - allContainers: All available containers
    ///   - searchText: Current search text
    /// - Returns: Filtered list of containers matching the search text
    func filteredContainers(from allContainers: [SearchEntry]) -> [SearchEntry] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return allContainers }
        return allContainers.filter { $0.target.title.localizedCaseInsensitiveContains(q) }
    }
    
    // MARK: - Grouping Logic
    
    /// Groups items for a List or Project target.
    /// Returns direct items (not in a section) and section groups.
    func groupedContent(for target: ContainerTarget) -> (directItems: GroupedItems, sectionGroups: [SectionGroup]) {
        let allItems = target.items
        
        // Direct items: not in a TaskSection
        let directItems = allItems.filter { $0.taskSection == nil }
        
        // Section groups: TaskSections with their items
        let sections: [TaskSection]
        switch target {
        case .list(let list):
            sections = list.taskSections.sorted { $0.sortIndex < $1.sortIndex }
        case .project(let project):
            sections = project.taskSections.sorted { $0.sortIndex < $1.sortIndex }
        case .space(let space):
            sections = space.taskSections.sorted { $0.sortIndex < $1.sortIndex }
        }
        
        let sectionGroups = sections.map { section in
            SectionGroup(
                section: section,
                groupedItems: GroupedItems(items: Array(section.items))
            )
        }
        
        return (
            directItems: GroupedItems(items: directItems),
            sectionGroups: sectionGroups
        )
    }
    
    /// Gets child containers with their grouped content for a Space target.
    func childContainerGroups(for space: Space) -> [ChildContainerGroup] {
        let children = Containers.children(of: space)
        
        return children.map { child in
            switch child {
            case .list(let list):
                let directItems = list.items.filter { $0.taskSection == nil }
                let sections = list.taskSections.sorted { $0.sortIndex < $1.sortIndex }
                let sectionGroups = sections.map { section in
                    SectionGroup(
                        section: section,
                        groupedItems: GroupedItems(items: Array(section.items))
                    )
                }
                return ChildContainerGroup(
                    child: child,
                    directItems: GroupedItems(items: directItems),
                    sectionGroups: sectionGroups
                )
            case .project(let project):
                let directItems = project.items.filter { $0.taskSection == nil }
                let sections = project.taskSections.sorted { $0.sortIndex < $1.sortIndex }
                let sectionGroups = sections.map { section in
                    SectionGroup(
                        section: section,
                        groupedItems: GroupedItems(items: Array(section.items))
                    )
                }
                return ChildContainerGroup(
                    child: child,
                    directItems: GroupedItems(items: directItems),
                    sectionGroups: sectionGroups
                )
            }
        }
    }
    
    /// Toggles expansion state for a child container.
    func toggleChildContainer(_ child: ContainerChild) {
        if expandedChildContainers.contains(child.id) {
            expandedChildContainers.remove(child.id)
        } else {
            expandedChildContainers.insert(child.id)
        }
    }
    
    /// Checks if a child container is expanded.
    func isChildContainerExpanded(_ child: ContainerChild) -> Bool {
        expandedChildContainers.contains(child.id)
    }
}
