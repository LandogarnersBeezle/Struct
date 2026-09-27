//
//  ContainerListView.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import SwiftUI

/// The container list: the sole lists and projects, followed by every space
/// with the lists and projects it owns.
///
/// Every container can be dragged to any other position. A space takes its
/// lists and projects with it, and the drop position decides parenting.
struct ContainerListView: View {
    @State private var store = ContainerStore()

    var body: some View {
        let presentations = store.items.rowPresentations

        List {
            ForEach(store.items) { item in
                ContainerRowView(item: item, presentation: presentations[item.id] ?? ContainerRowPresentation())
            }
            .reorderable()
        }
        .reorderContainer(for: ContainerItem.self) { difference in
            store.apply(difference)
        }
        .listStyle(.plain)
        .navigationTitle("Containers")
    }
}

#Preview {
    NavigationStack {
        ContainerListView()
    }
}
