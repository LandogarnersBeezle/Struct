//
//  TaskFloatingCard.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI
import SwiftData

/// Floating drag card for tasks.
///
/// This card appears during drag operations and follows the user's finger,
/// providing visual feedback about what's being dragged. It uses the same
/// visual styling as ItemRowView for consistency.
struct TaskFloatingCard: View {
    let item: Item
    
    private let calendar = Calendar.current
    
    private var isOverdue: Bool {
        guard let due = item.dueDate, !item.isCompleted else { return false }
        return due < .now
    }
    
    private func formattedDate(from date: Date) -> String {
        DateFormatter.formattedDate(from: date, calendar: calendar)
    }
    
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
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
        .opacity(0.92)
        .transition(.opacity)
    }
}