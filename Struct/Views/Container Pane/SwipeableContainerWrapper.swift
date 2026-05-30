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
}

// MARK: - SwipeableContainerKind

/// Identifies which model object a swipe gesture has targeted.
enum SwipeableContainerKind {
    case list(List)
    case project(Project)
    case space(Space)
}

// MARK: - SwipeableRow

/// Swipe-trigger row wrapper.
///
/// A short left swipe bounces the row ~20 pt then springs back, calling
/// onTriggered once.  It does **not** reveal inline buttons; the action
/// bar appears at the bottom of the sidebar instead.
///
/// isHighlighted is driven by the caller (via SidebarSwipeSelection) so
/// the accent-colour background persists while the action bar is visible.
///
/// Uses .simultaneousGesture to coexist with the LongPressGesture →
/// DragGesture chain used for drag-and-drop reordering.
struct SwipeableRow<Content: View>: View {

    /// Renders a subtle accent-coloured background while true.
    var isHighlighted: Bool = false
    /// Called once when a qualifying left swipe is recognised.
    let onTriggered: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    /// `true` from the moment a long-press fires until the gesture ends.
    /// Used to disable ScrollView scrolling once the user commits to a swipe,
    /// while still allowing normal scroll before the long-press threshold.
    @State private var longPressActive = false

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(isHighlighted ? 0.10 : 0))
                    .animation(.easeOut(duration: 0.2), value: isHighlighted)
            }
            .offset(x: offset)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.3)
                    .sequenced(before: DragGesture(minimumDistance: 8))
                    .onChanged { value in
                        switch value {
                        case .first(true):
                            // Long press fired; disable scroll before the finger moves.
                            longPressActive = true
                        case .second(true, let g?):
                            handleChanged(g)
                        default: break
                        }
                    }
                    .onEnded { _ in
                        // Always clear the long-press flag — covers the case where the
                        // long press fired but the user lifted before a drag began.
                        longPressActive = false
                        // Only trigger swipe if we actually dragged leftward
                        guard longPressActive || offset < 0 else { return }
                        // We need the last drag value, but onEnded doesn't provide it.
                        // Use the current offset to determine if swipe qualified.
                        handleEnded()
                    }
            )
    }

    // MARK: Gesture

    private func handleChanged(_ v: DragGesture.Value) {
        let dx = v.translation.width, dy = v.translation.height
        guard abs(dx) > abs(dy), dx < 0 else { return }
        // Rubber-band: the row resists at ~35 % of finger speed, capped at 24 pt.
        offset = max(-24, dx * 0.35)
    }

    private func handleEnded() {
        guard offset < -12 else {
            withAnimation(.spring(duration: 0.25, bounce: 0)) { offset = 0 }
            return
        }
        // Snap briefly to max excursion, then spring back with a small bounce.
        withAnimation(.spring(duration: 0.12, bounce: 0)) { offset = -20 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) { offset = 0 }
        }
        onTriggered()
    }
}

// MARK: - ContainerSwipeActions

/// Connects a sidebar row to the shared SidebarSwipeSelection.
///
/// All rename / delete business logic lives in ContainerActionBar; this
/// wrapper's sole job is detecting the swipe and toggling the selection state.
struct ContainerSwipeActions<Content: View>: View {

    let container: SwipeableContainerKind
    @ViewBuilder let content: () -> Content

    @Environment(SidebarSwipeSelection.self) private var selection

    var body: some View {
        SwipeableRow(
            isHighlighted: selection.matches(container),
            onTriggered: {
                // Swiping the already-active row toggles it off.
                if selection.matches(container) { selection.clear()            }
                else                           { selection.active = container }
                // Suppress the button tap that fires on the same touch-up event.
                selection.markTriggered()
            }
        ) {
            content()
        }
    }
}

// MARK: - ContainerActionBar

/// Bottom action bar that replaces the add button when a container row is
/// swipe-selected.  Owns the rename alert and delete confirmation dialog.
struct ContainerActionBar: View {

    @Environment(SidebarSwipeSelection.self) private var selection
    @Environment(\.modelContext) private var context

    // MARK: State

    @State private var isRenaming       = false
    @State private var renameText       = ""
    @State private var showDeleteDialog = false
    @State private var hasOpenTasks     = false

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
    }

    // MARK: - Button layout

    @ViewBuilder
    private func actionButton(_ label: String, icon: String, tint: Color,
                               action: @escaping () -> Void) -> some View {
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
        try? context.save()
        selection.clear()
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
        return try? context.fetch(desc).first
    }

    private func deleteList(_ list: List, moveToInbox: Bool) {
        if moveToInbox, let inbox = fetchInbox() {
            list.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) }
        }
        context.delete(list)
        try? context.save()
    }

    private func deleteProject(_ project: Project, moveToInbox: Bool) {
        if moveToInbox, let inbox = fetchInbox() {
            project.items.filter { !$0.isCompleted }.forEach { $0.setParent(.list(inbox)) }
        }
        context.delete(project)
        try? context.save()
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
        try? context.save()
    }
}
