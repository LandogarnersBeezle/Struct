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

    private var isOverdue: Bool {
        guard let due = item.dueDate, !item.isCompleted else { return false }
        return due < .now
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Completion indicator
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(item.isCompleted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                // Title
                Text(item.title)
                    .font(.body.weight(.medium))
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                // Notes
                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Date chips
                if item.doDate != nil || item.dueDate != nil {
                    HStack(spacing: 10) {
                        if let doDate = item.doDate {
                            Label {
                                Text(doDate, style: .date)
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        if let dueDate = item.dueDate {
                            Label {
                                Text(dueDate, style: .date)
                            } icon: {
                                Image(systemName: "flag.fill")
                            }
                            .font(.caption)
                            .foregroundStyle(isOverdue ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        }
                    }
                    .padding(.top, 1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
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

    for item in [plain, full, overdue, done] { context.insert(item) }

    return ScrollView {
        LazyVStack(spacing: 10) {
            ItemRowView(item: plain)
            ItemRowView(item: full)
            ItemRowView(item: overdue)
            ItemRowView(item: done)
        }
        .padding()
    }
    .modelContainer(container)
}
