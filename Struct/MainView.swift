//
//  ContentView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.timestamp) private var items: [TodoItem]

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    HStack {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        Text(item.title)
                        Text(item.timestamp, style: .time)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        item.isCompleted.toggle()
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func addItem() {
        let newItem = TodoItem(title: "New Task")
        modelContext.insert(newItem)
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

#Preview {
    MainView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
