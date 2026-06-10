//
//  SwipeableContainerWrapper.swift
//  Struct
//
//  Created by Otto Kiefer on 28.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - Container Delete Button

/// Circular delete button that replaces the add button when a container row is
/// swipe-selected.  Triggers the delete alert which is managed by the parent.
///
/// This button now delegates the actual delete logic to the parent via the
/// onDelete callback, following the single responsibility principle.
struct ContainerDeleteButton: View {
    let onDelete: () -> Void

    var body: some View {
        Button(action: onDelete) {
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
}

// MARK: - Delete Confirmation Alert

/// Custom-styled delete confirmation alert that displays the container's icon and name.
///
/// This alert is shown when the user taps the delete button after swipe-selecting
/// a container. It provides options to either move open tasks to inbox or delete
/// everything.
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