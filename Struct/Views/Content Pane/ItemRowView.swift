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
        .padding(.vertical, 2)
        // Apply ghost row styling when being dragged
        .opacity(isGhost ? 0.3 : 1.0)
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
            unscheduledItems: unscheduledItems
        ))
    }
    
    /// Check if item is unscheduled (no doDate)
    private func isUnscheduled(item: Item) -> Bool {
        item.doDate == nil
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Space.self, Project.self, List.self, Item.self, TaskSection.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    List.ensureInbox(in: context)
    
    // Plain item — no dates, no notes
    let plain = Item(title: "Pick up dry cleaning")
    
    // Scheduled + due date, with notes
    let full = Item(title: "Book moving truck",
                    notes: "Compare at least three quotes before booking.",
                    doDate: .now.addingTimeInterval(86_400 * 2),
                    dueDate: .now.addingTimeInterval(86_400 * 7))
    
    // Overdue item
    let overdue = Item(title: "Submit tax return",
                       dueDate: .now.addingTimeInterval(-86_400 * 2))
    
    // Completed item
    let done = Item(title: "Reply to landlord",
                    doDate: .now.addingTimeInterval(-86_400))
    done.isCompleted = true
    
    // Item with date in current year but beyond 7 days
    let laterThisYear = Item(title: "Schedule annual checkup",
                             doDate: .now.addingTimeInterval(86_400 * 30))
    
    // Item with date in a different year
    let nextYear = Item(title: "Renew passport",
                        doDate: .now.addingTimeInterval(86_400 * 400),
                        dueDate: .now.addingTimeInterval(86_400 * 450))
    
    for item in [plain, full, overdue, done, laterThisYear, nextYear] { context.insert(item) }
    
    // Create a mock target for preview
    guard let inbox = try? context.fetch(FetchDescriptor<List>()).first else {
        return EmptyView()
    }
    
    let allItems = [plain, full, overdue, done, laterThisYear, nextYear]
    
    return ScrollView {
        LazyVStack(spacing: 10) {
            ItemRowView(item: plain, groupContext: .directUnscheduled(.list(inbox)), isDragEnabled: true, unscheduledItems: allItems)
            ItemRowView(item: full, groupContext: .directUnscheduled(.list(inbox)), isDragEnabled: true, unscheduledItems: allItems)
            ItemRowView(item: overdue, groupContext: .directUnscheduled(.list(inbox)), isDragEnabled: true, unscheduledItems: allItems)
            ItemRowView(item: done, groupContext: .directUnscheduled(.list(inbox)), isDragEnabled: true, unscheduledItems: allItems)
            ItemRowView(item: laterThisYear, groupContext: .directUnscheduled(.list(inbox)), isDragEnabled: true, unscheduledItems: allItems)
            ItemRowView(item: nextYear, groupContext: .directUnscheduled(.list(inbox)), isDragEnabled: true, unscheduledItems: allItems)
        }
        .padding()
    }
    .modelContainer(container)
}

// MARK: - Item Row Drag Modifier

/// View modifier that adds long-press drag interaction to item rows.
struct ItemRowDragModifier: ViewModifier {
    let item: Item
    let groupContext: ItemGroupContext
    let isDragEnabled: Bool
    let unscheduledItems: [Item]
    
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
                    itemDragState.beginDrag(item: item, context: groupContext, at: location, height: 44)
                },
                onDragChanged: { location in
                    guard isDragEnabled, itemDragState.isDragging else { return }
                    itemDragState.updateDragPosition(location, among: unscheduledItems)
                },
                onDragEnded: {
                    guard isDragEnabled else { return }
                    itemDragState.endDrag()
                }
            )
    }
}
