//
//  ItemFloatingRow.swift
//  Struct
//
//  Created by Otto Kiefer on 14.06.2026.
//

import SwiftUI
import SwiftData

/// A floating row view that follows the finger during drag operations.
/// Displays the dragged item with smooth scale and opacity animations.
struct ItemFloatingRow: View {
    let item: Item
    let dragScale: CGFloat
    let dragOpacity: CGFloat
    let fingerPosition: CGPoint
    let contentOriginInWindow: CGPoint
    
    private let calendar = Calendar.current
    
    // MARK: - Date Formatting Helper
    
    private func formattedDate(from date: Date) -> String {
        DateFormatter.formattedDate(from: date, calendar: calendar)
    }
    
    // MARK: - Date Chip View
    
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
    
    private var isOverdue: Bool {
        guard let due = item.dueDate, !item.isCompleted else { return false }
        return due < .now
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
        .padding(.vertical, 2)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .scaleEffect(dragScale)
        .opacity(dragOpacity)
        .position(x: fingerPosition.x - contentOriginInWindow.x, y: fingerPosition.y - contentOriginInWindow.y)
        .allowsHitTesting(false)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Space.self, Project.self, List.self, Item.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    List.ensureInbox(in: context)
    
    let item = Item(title: "Book moving truck",
                    notes: "Compare at least three quotes before booking.",
                    doDate: .now.addingTimeInterval(86_400 * 2),
                    dueDate: .now.addingTimeInterval(86_400 * 7))
    context.insert(item)
    
    return ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        ItemFloatingRow(
            item: item,
            dragScale: 1.05,
            dragOpacity: 0.85,
            fingerPosition: CGPoint(x: 200, y: 300),
            contentOriginInWindow: .zero
        )
    }
    .modelContainer(container)
}