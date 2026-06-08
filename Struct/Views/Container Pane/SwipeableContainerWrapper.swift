//
//  SwipeableContainerWrapper.swift
//  Struct
//
//  Created by Otto Kiefer on 28.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - SidebarSwipeSelection

/// Shared swipe-selection state for the container sidebar.
///
/// Owned as @State in ContainersSidebarView and injected into the view
/// hierarchy via .environment.  When active is non-nil the sidebar
/// replaces its add button with a circular delete button.
@Observable
final class SidebarSwipeSelection {
    var active: SwipeableContainerKind? = nil

    /// true during the run-loop cycle in which a swipe fired — mirrors
    /// SidebarDragState.justEndedDrag to block the button tap that arrives
    /// on the same touch-up event as the swipe gesture's onEnded.
    private(set) var justTriggered = false

    func clear() { active = nil }

    /// Sets justTriggered for one main-queue cycle, then resets it.
    func markTriggered() {
        justTriggered = true
        DispatchQueue.main.async { [weak self] in self?.justTriggered = false }
    }

    /// Returns true when kind refers to the same persistent object as active.
    func matches(_ kind: SwipeableContainerKind) -> Bool {
        guard let active else { return false }
        switch (active, kind) {
        case (.list(let a),    .list(let b)):    return a.persistentModelID == b.persistentModelID
        case (.project(let a), .project(let b)): return a.persistentModelID == b.persistentModelID
        case (.space(let a),   .space(let b)):   return a.persistentModelID == b.persistentModelID
        default: return false
        }
    }

    /// Swipe-trigger semantics shared by every row: tapping an already-active
    /// row clears it, otherwise it becomes the new selection.  `markTriggered`
    /// suppresses the tap that arrives on the same touch-up event.
    func toggle(_ kind: SwipeableContainerKind) {
        if matches(kind) { clear() }
        else             { active = kind }
        markTriggered()
    }
}

// MARK: - SwipeableContainerKind

/// Identifies which model object a swipe gesture has targeted.
enum SwipeableContainerKind {
    case list(List)
    case project(Project)
    case space(Space)
}

// MARK: - ContainerDeleteButton

/// Circular delete button that replaces the add button when a container row is
/// swipe-selected.  Triggers the delete alert which is managed by the parent.
struct ContainerDeleteButton: View {

    @Environment(SidebarSwipeSelection.self) private var selection
    @Environment(\.modelContext)             private var context

    // MARK: State

    @State private var hasOpenTasks = false

    // MARK: Body

    var body: some View {
        Button(action: initiateDelete) {
            Image(systemName: "trash")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.red))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete")
        .accessibilityHint(NSLocalizedString("Remove this container", comment: "Delete button accessibility hint"))
    }

    // MARK: - Delete

    private func initiateDelete() {
        guard let active = selection.active else { return }
        hasOpenTasks = openTaskCount(in: active) > 0
        // Store hasOpenTasks in a shared state for the alert to access
        DeleteAlertState.shared.hasOpenTasks = hasOpenTasks
        DeleteAlertState.shared.showAlert = true
    }

    // MARK: - Helpers

    private func openTaskCount(in kind: SwipeableContainerKind) -> Int {
        switch kind {
        case .list(let l):    return l.items.filter { !$0.isCompleted }.count
        case .project(let p): return p.items.filter { !$0.isCompleted }.count
        case .space(let s):
            let n1 = s.items.filter    { !$0.isCompleted }.count
            let n2 = s.lists.flatMap    { $0.items }.filter { !$0.isCompleted }.count
            let n3 = s.projects.flatMap { $0.items }.filter { !$0.isCompleted }.count
            return n1 + n2 + n3
        }
    }

    private func fetchInbox() -> List? {
        List.ensureInbox(in: context)
        let slug = List.inboxSlug
        let desc = FetchDescriptor<List>(predicate: #Predicate { $0.slug == slug })
        return try? context.fetchOrThrow(desc).first
    }

    func deleteList(_ list: List, moveToInbox: Bool) {
        if moveToInbox, let inbox = fetchInbox() {
            list.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) }
        }
        context.delete(list)
        try? context.saveOrThrow()
    }

    func deleteProject(_ project: Project, moveToInbox: Bool) {
        if moveToInbox, let inbox = fetchInbox() {
            project.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) }
        }
        context.delete(project)
        try? context.saveOrThrow()
    }

    func deleteSpace(_ space: Space, moveToInbox: Bool) {
        if moveToInbox, let inbox = fetchInbox() {
            space.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) }
            for list in space.lists { list.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) } }
            for project in space.projects { project.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) } }
        }
        // Space.lists uses deleteRule .nullify — delete explicitly to avoid orphans.
        for list in space.lists { context.delete(list) }
        context.delete(space)
        try? context.saveOrThrow()
    }
}

// MARK: - DeleteAlertState

/// Shared state for the delete alert, accessible from both the button and the alert overlay.
@Observable
final class DeleteAlertState {
    static let shared = DeleteAlertState()

    var showAlert = false
    var hasOpenTasks = false

    private init() {}
}

// MARK: - DeleteConfirmationAlert

/// Custom-styled delete confirmation alert that displays the container's icon and name.
struct DeleteConfirmationAlert: View {
    let containerKind: SwipeableContainerKind?
    let hasOpenTasks: Bool
    let onDelete: (Bool) -> Void
    let onCancel: () -> Void

    @State private var isVisible = false

    private var containerInfo: (icon: String, name: String, color: Color) {
        guard let kind = containerKind else {
            return (icon: "questionmark", name: "Unknown", color: .gray)
        }
        switch kind {
        case .list(let l):
            return (icon: l.kindRaw == "inbox" ? "tray" : "list.bullet", name: l.title, color: List.containerColor)
        case .project(let p):
            return (icon: "folder", name: p.title, color: Project.containerColor)
        case .space(let s):
            return (icon: s.symbolName, name: s.name, color: Space.containerColor)
        }
    }

    var body: some View {
        ZStack {
            // Alert card
            VStack(spacing: 20) {
                // Container icon
                ZStack {
                    Circle()
                        .fill(containerInfo.color.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: containerInfo.icon)
                        .font(.system(size: 32))
                        .foregroundStyle(containerInfo.color)
                }

                // Title
                Text("Delete \"\(containerInfo.name)\"?")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                // Message for open tasks
                if hasOpenTasks {
                    Text("This container has open tasks. Choose how to handle them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Action buttons
                VStack(spacing: 12) {
                    if hasOpenTasks {
                        Button(action: { onDelete(true) }) {
                            Text("Move Open Tasks to Inbox")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundStyle(Color.accentColor)
                                .cornerRadius(12)
                        }
                    }

                    Button(role: .destructive) {
                        onDelete(false)
                    } label: {
                        Text(hasOpenTasks ? "Delete All" : "Delete")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.12))
                            .foregroundStyle(.red)
                            .cornerRadius(12)
                    }

                    Button(action: onCancel) {
                        Text("Cancel")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.gray.opacity(0.12))
                            .foregroundStyle(.primary)
                            .cornerRadius(12)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
            // Animate alert card appearance with scale and opacity
            .scaleEffect(isVisible ? 1 : 0.9)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            // Trigger animation after a tiny delay for smooth entrance
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                isVisible = true
            }
        }
    }
}
