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
/// replaces its add button with ContainerActionBar.
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

// MARK: - ContainerActionBar

/// Bottom action bar that replaces the add button when a container row is
/// swipe-selected.  Owns the rename alert and delete confirmation dialog.
struct ContainerActionBar: View {

    @Environment(SidebarSwipeSelection.self) private var selection
    @Environment(\.modelContext)             private var context

    // MARK: State

    @State private var isRenaming       = false
    @State private var renameText       = ""
    @State private var showDeleteDialog = false
    @State private var hasOpenTasks     = false
    @State private var actionError: DataError?

    // MARK: Body

    var body: some View {
        HStack(spacing: 12) {
            actionButton("Rename", icon: "pencil", tint: .blue) { startRename()    }
            actionButton("Delete", icon: "trash",  tint: .red)  { initiateDelete() }
        }
        .frame(height: 56)
        .alert("Rename", isPresented: $isRenaming) {
            TextField("Name", text: $renameText)
                .autocorrectionDisabled()
            Button("Save")                  { saveRename()  }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(deleteTitle,
                            isPresented: $showDeleteDialog,
                            titleVisibility: .visible) {
            if hasOpenTasks {
                Button("Move Open Tasks to Inbox")       { performDelete(moveToInbox: true)  }
                Button("Delete All", role: .destructive) { performDelete(moveToInbox: false) }
            } else {
                Button("Delete", role: .destructive)     { performDelete(moveToInbox: false) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if hasOpenTasks { Text("Some tasks are still open. Choose how to handle them.") }
        }
        .errorAlert($actionError) {
            // Clear selection when error is dismissed to reset state
            selection.clear()
        }
    }

    // MARK: - Button layout

    @ViewBuilder
    private func actionButton(_ label: String, icon: String, tint: Color,
                               action: @escaping () -> Void) -> some View {
        let hint: String = {
            switch label {
            case "Rename": return NSLocalizedString("Change the name of this container", comment: "Rename button accessibility hint")
            case "Delete": return NSLocalizedString("Remove this container", comment: "Delete button accessibility hint")
            default: return ""
            }
        }()
        Button(action: action) {
            Label(label, systemImage: icon)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tint.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .foregroundStyle(tint)
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(Text(hint))
    }

    // MARK: - Rename

    private func startRename() {
        guard let active = selection.active else { return }
        renameText = name(of: active)
        isRenaming = true
    }

    private func saveRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let active = selection.active else { return }
        switch active {
        case .list(let l):    l.title = trimmed; l.touch()
        case .project(let p): p.title = trimmed; p.touch()
        case .space(let s):   s.name  = trimmed; s.touch()
        }
        do {
            try context.saveOrThrow()
            selection.clear()
        } catch let error as DataError {
            actionError = error
        } catch {
            actionError = .saveFailed(error)
        }
    }

    // MARK: - Delete

    private func initiateDelete() {
        guard let active = selection.active else { return }
        hasOpenTasks     = openTaskCount(in: active) > 0
        showDeleteDialog = true
    }

    private func performDelete(moveToInbox: Bool) {
        guard let active = selection.active else { return }
        switch active {
        case .list(let l):    deleteList(l,    moveToInbox: moveToInbox)
        case .project(let p): deleteProject(p, moveToInbox: moveToInbox)
        case .space(let s):   deleteSpace(s,   moveToInbox: moveToInbox)
        }
        selection.clear()
    }

    // MARK: - Helpers

    private func name(of kind: SwipeableContainerKind) -> String {
        switch kind {
        case .list(let l):    return l.title
        case .project(let p): return p.title
        case .space(let s):   return s.name
        }
    }

    private var deleteTitle: String {
        guard let a = selection.active else { return "Delete?" }
        switch a {
        case .list(let l):    return "Delete \"\(l.title)\"?"
        case .project(let p): return "Delete \"\(p.title)\"?"
        case .space(let s):   return "Delete \"\(s.name)\"?"
        }
    }

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

    private func deleteList(_ list: List, moveToInbox: Bool) {
        if moveToInbox, let inbox = fetchInbox() {
            list.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) }
        }
        context.delete(list)
        do {
            try context.saveOrThrow()
            selection.clear()
        } catch let error as DataError {
            actionError = error
        } catch {
            actionError = .deleteFailed(error)
        }
    }

    private func deleteProject(_ project: Project, moveToInbox: Bool) {
        if moveToInbox, let inbox = fetchInbox() {
            project.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) }
        }
        context.delete(project)
        do {
            try context.saveOrThrow()
            selection.clear()
        } catch let error as DataError {
            actionError = error
        } catch {
            actionError = .deleteFailed(error)
        }
    }

    private func deleteSpace(_ space: Space, moveToInbox: Bool) {
        if moveToInbox, let inbox = fetchInbox() {
            space.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) }
            for list    in space.lists    { list.items.filter    { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) } }
            for project in space.projects { project.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) } }
        }
        // Space.lists uses deleteRule .nullify — delete explicitly to avoid orphans.
        for list in space.lists { context.delete(list) }
        context.delete(space)
        do {
            try context.saveOrThrow()
            selection.clear()
        } catch let error as DataError {
            actionError = error
        } catch {
            actionError = .deleteFailed(error)
        }
    }

}
