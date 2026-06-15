//
//  ItemRow.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI
import SwiftData

struct ItemRowView: View {
    let item: Item
    let groupContext: ItemGroupContext
    let isDragEnabled: Bool
    let unscheduledItems: [Item]
    let commitDrop: () -> Void  // Synchronous commit callback (like sidebar's commitDrop)
    
    @Environment(ItemDragState.self) private var itemDragState
    
    @State private var isGhostRow = false
    
    private let calendar = Calendar.current
    
    private var isOverdue: Bool {
        guard let due = item.dueDate, !item.isCompleted else { return false }
        return due < .now
    }
    
    // MARK: - Date Formatting Helper
    
    /// Formats a date using the shared DateFormatter utility.
    /// See `DateFormatter.formattedDate(from:calendar:)` for formatting rules.
    private func formattedDate(from date: Date) -> String {
        DateFormatter.formattedDate(from: date, calendar: calendar)
    }
    
    // MARK: - Date Chip View
    
    /// Creates a styled date chip with padded background
    private func dateChip(for date: Date, color: Color, prefixIcon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon = prefixIcon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(formattedDate(from: date))
                .font(.caption)
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
    
    var body: some View {
        let isBeingDragged = itemDragState.draggingItem?.id == item.id
        let isGhost = isBeingDragged
        
        return HStack(alignment: .top, spacing: 4) {
            // Completion indicator
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isCompleted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .padding(.top, 1)
            
            VStack(alignment: .leading, spacing: 5) {
                // Title line with inline dates
                HStack(spacing: 8) {
                    // Do date (positioned at the beginning)
                    if let doDate = item.doDate {
                        dateChip(for: doDate, color: .accentColor)
                    }
                    
                    // Title
                    Text(item.title)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    
                    Spacer(minLength: 0)
                    
                    // Due date (positioned at the end, with flag icon)
                    if let dueDate = item.dueDate {
                        dateChip(for: dueDate, color: isOverdue ? .red : .secondary, prefixIcon: "flag.fill")
                    }
                }
                
                // Notes
                if !item.notes.isEmpty {
                    Text(item.notes)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, isGhost ? 0 : 2)
        // Ghost row collapses to zero opacity and height to avoid pushing rows down
        .opacity(isGhost ? 0 : 1.0)
        .frame(height: isGhost ? 0 : nil)
        .clipped()
        // Report frame for drop target calculation
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: ItemRowFrameKey.self,
                        value: [item.id: geometry.frame(in: .named("ItemContentView"))]
                    )
            }
        )
        // Add drag interaction if enabled and item is unscheduled
        .modifier(ItemRowDragModifier(
            item: item,
            groupContext: groupContext,
            isDragEnabled: isDragEnabled && isUnscheduled(item: item),
            unscheduledItems: unscheduledItems,
            commitDrop: commitDrop
        ))
    }
    
    /// Check if item is unscheduled (no doDate)
    private func isUnscheduled(item: Item) -> Bool {
        item.doDate == nil
    }
}

#Preview {
    PreviewWrapper()
}

struct PreviewWrapper: View {
    @State private var itemDragState = ItemDragState()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ItemRowView(item: Item(title: "Task 1"), groupContext: .directUnscheduled(.list(List(title: "Inbox"))), isDragEnabled: true, unscheduledItems: [], commitDrop: {})
                ItemRowView(item: Item(title: "Task 2"), groupContext: .directUnscheduled(.list(List(title: "Inbox"))), isDragEnabled: true, unscheduledItems: [], commitDrop: {})
                ItemRowView(item: Item(title: "Task 3"), groupContext: .directUnscheduled(.list(List(title: "Inbox"))), isDragEnabled: true, unscheduledItems: [], commitDrop: {})
            }
            .padding()
        }
        .environment(itemDragState)
        .modelContainer(for: [Space.self, Project.self, List.self, Item.self, TaskSection.self], inMemory: true)
    }
}

// MARK: - Item Row Drag Modifier

/// View modifier that adds long-press drag interaction to item rows.
struct ItemRowDragModifier: ViewModifier {
    let item: Item
    let groupContext: ItemGroupContext
    let isDragEnabled: Bool
    let unscheduledItems: [Item]
    let commitDrop: () -> Void  // Called synchronously when drag ends (like sidebar's commitDrop)
    
    @Environment(ItemDragState.self) private var itemDragState
    
    func body(content: Content) -> some View {
        content
            .draggableRowInteraction(
                supportsSwipe: false,
                accessibilityLabel: item.title,
                accessibilityHint: "Long press to reorder within group",
                onTap: {},
                onDragBegan: { location in
                    guard isDragEnabled else { return }
                    // Pre-set target to current position so gap opens in-place (no jump)
                    if let idx = unscheduledItems.firstIndex(where: { $0.id == item.id }) {
                        itemDragState.targetIndex = idx
                    }
                    itemDragState.beginDrag(item: item, context: groupContext, at: location, height: 44)
                },
                onDragChanged: { location in
                    guard isDragEnabled, itemDragState.isDragging else { return }
                    // Exclude the dragged item from the candidate list
                    let others = unscheduledItems.filter { $0.id != item.id }
                    itemDragState.updateDragPosition(location, among: others)
                },
                onDragEnded: {
                    guard isDragEnabled else { return }
                    // Commit the drop synchronously (like the sidebar's pattern)
                    commitDrop()
                }
            )
    }
}
