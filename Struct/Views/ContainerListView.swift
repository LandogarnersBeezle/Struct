//
//  ContainerListView.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import SwiftUI
import SwiftData

/// The container list: the sole lists and projects, followed by every space
/// with the lists and projects it owns.
///
/// Every container can be dragged to any other position. A space takes its
/// lists and projects with it, and the drop position decides parenting.
struct ContainerListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store = ContainerStore()
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        let presentations = store.items.rowPresentations

        List {
            ForEach(store.visibleItems()) { item in
                ContainerRowView(
                    item: item,
                    presentation: presentations[item.id] ?? ContainerRowPresentation(),
                    onToggleExpand: {
                        withAnimation(.snappy(duration: 0.25)) {
                            store.toggleExpansion(for: item.id)
                        }
                    }
                )
            }
            .reorderable()
        }
        .reorderContainer(for: ContainerItem.self) { difference in
            // Deliberately the only thing this closure does. Applying a move and
            // changing which rows exist in the same update leaves the drop still
            // animating rows that are no longer there, which is fatal.
            store.apply(difference)
        }
        .listStyle(.plain)
        .navigationTitle("Containers")
        .overlay {
            if store.items.isEmpty {
                ContentUnavailableView {
                    Label("No Containers", systemImage: "tray")
                } description: {
                    Text("Seed sample containers or add your own to get started.")
                } actions: {
                    Button("Seed Sample Data") {
                        withAnimation {
                            store.seedSampleContainers()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.hasSampleData)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        withAnimation {
                            store.seedSampleContainers()
                        }
                    } label: {
                        Label("Seed Sample Containers", systemImage: "sparkles")
                    }
                    .disabled(store.hasSampleData)

                    if store.hasSampleData {
                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label("Delete Sample Containers", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete Sample Containers?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Samples", role: .destructive) {
                withAnimation {
                    store.deleteSampleContainers()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove all containers created as part of the sample setup.")
        }
        .task {
            store.configure(with: modelContext)
            // Automatically seed sample data on first launch if the store is completely empty
            if store.items.isEmpty {
                store.seedSampleContainers()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ContainerListView()
    }
    .modelContainer(for: ContainerItem.self, inMemory: true)
}

