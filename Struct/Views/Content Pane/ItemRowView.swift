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
    var isHighlighted: Bool = false
    /// Callback when drag begins — reports window-coordinate location.
    var onDragBegan: ((CGPoint) -> Void)? = nil
    /// Callback when drag location changes — reports window-coordinate location.
    var onDragChanged: ((CGPoint) -> Void)? = nil
    /// Callback when drag ends.
    var onDragEnded: (() -> Void)? = nil
    
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
        HStack(alignment: .top, spacing: 4) {
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
        .padding(12)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
        }
        // Install drag-and-drop gesture pipeline
        .draggableRowInteraction(
            onTap: { /* tap handling can be added if needed */ },
            onDragBegan: { [self] windowLoc in
                // Height is tracked by TaskRowFrameAnchor via preference key
                onDragBegan?(windowLoc)
            },
            onDragChanged: { windowLoc in
                onDragChanged?(windowLoc)
            },
            onDragEnded: {
                onDragEnded?()
            }
        )
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Space.self, Project.self, List.self, Item.self,
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
    
    return ScrollView {
        LazyVStack(spacing: 10) {
            ItemRowView(item: plain)
            ItemRowView(item: full)
            ItemRowView(item: overdue)
            ItemRowView(item: done)
            ItemRowView(item: laterThisYear)
            ItemRowView(item: nextYear)
        }
        .padding()
    }
    .modelContainer(container)
}