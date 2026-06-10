//
//  ContainerDeletionService.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI
import SwiftData

// MARK: - Container Deletion Service

/// Centralized service for container deletion operations.
///
/// This service handles all the complex logic involved in deleting containers
/// (lists, projects, spaces) including:
/// - Moving open tasks to inbox when requested
/// - Handling nested items properly
/// - Managing space children (lists/projects) deletion
/// - Error handling and rollback
///
/// Using a centralized service eliminates duplicated delete logic across
/// different views and ensures consistent behavior.
final class ContainerDeletionService {

    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public Methods

    /// Deletes a list, optionally moving its open tasks to inbox first.
    /// - Parameters:
    ///   - list: The list to delete
    ///   - moveToInbox: Whether to move open tasks to inbox
    /// - Throws: DataError if save fails
    func deleteList(_ list: List, moveToInbox: Bool) throws {
        if moveToInbox, let inbox = fetchInbox() {
            list.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) }
        }
        modelContext.delete(list)
        try modelContext.saveOrThrow()
    }

    /// Deletes a project, optionally moving its open tasks to inbox first.
    /// - Parameters:
    ///   - project: The project to delete
    ///   - moveToInbox: Whether to move open tasks to inbox
    /// - Throws: DataError if save fails
    func deleteProject(_ project: Project, moveToInbox: Bool) throws {
        if moveToInbox, let inbox = fetchInbox() {
            project.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) }
        }
        modelContext.delete(project)
        try modelContext.saveOrThrow()
    }

    /// Deletes a space, optionally moving all open tasks to inbox first.
    /// Also deletes all child lists (space.lists uses deleteRule .nullify).
    /// - Parameters:
    ///   - space: The space to delete
    ///   - moveToInbox: Whether to move open tasks to inbox
    /// - Throws: DataError if save fails
    func deleteSpace(_ space: Space, moveToInbox: Bool) throws {
        if moveToInbox, let inbox = fetchInbox() {
            // Move space's direct items
            space.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) }

            // Move all list items
            for list in space.lists {
                list.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) }
            }

            // Move all project items
            for project in space.projects {
                project.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) }
            }
        }

        // Space.lists uses deleteRule .nullify — delete explicitly to avoid orphans.
        for list in space.lists {
            modelContext.delete(list)
        }

        modelContext.delete(space)
        try modelContext.saveOrThrow()
    }

    /// Checks if a container has open tasks.
    /// - Parameter kind: The container kind to check
    /// - Returns: Number of open tasks in the container
    func openTaskCount(in kind: SwipeableContainerKind) -> Int {
        switch kind {
        case .list(let l):
            return l.items.filter { !$0.isCompleted }.count
        case .project(let p):
            return p.items.filter { !$0.isCompleted }.count
        case .space(let s):
            let directItems = s.items.filter { !$0.isCompleted }.count
            let listItems = s.lists.flatMap { $0.items }.filter { !$0.isCompleted }.count
            let projectItems = s.projects.flatMap { $0.items }.filter { !$0.isCompleted }.count
            return directItems + listItems + projectItems
        }
    }

    // MARK: - Private Methods

    private func fetchInbox() -> List? {
        List.ensureInbox(in: modelContext)
        let slug = List.inboxSlug
        let desc = FetchDescriptor<List>(predicate: #Predicate { $0.slug == slug })
        return try? modelContext.fetchOrThrow(desc).first
    }
}

// MARK: - Deletion Result

/// Result of a deletion operation for error handling.
enum DeletionResult {
    case success
    case failure(Error)
}