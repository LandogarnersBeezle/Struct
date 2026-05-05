//
//  CreateContainerView.swift
//  Struct
//
//  Created by Otto Kiefer on 05.05.2026.
//

import SwiftUI
import SwiftData

// What the sheet is creating. `Identifiable` so it drives `.sheet(item:)`.
enum CreateKind: String, Identifiable {
    case space
    case list
    case project

    var id: String { rawValue }

    var title: String {
        switch self {
        case .space: "New Space"
        case .list: "New List"
        case .project: "New Project"
        }
    }

    var namePlaceholder: String {
        switch self {
        case .space: "Space name"
        case .list: "List name"
        case .project: "Project name"
        }
    }
}

struct CreateContainerView: View {
    let kind: CreateKind

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Space.sortIndex) private var spaces: [Space]

    @State private var name = ""
    @State private var selectedSpaceID: PersistentIdentifier?
    @State private var newSpaceName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(kind.namePlaceholder, text: $name)
                }

                if kind != .space {
                    spaceSection
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: create)
                        .disabled(!canCreate)
                }
            }
            .task {
                if selectedSpaceID == nil {
                    selectedSpaceID = spaces.first?.persistentModelID
                }
            }
        }
    }

    @ViewBuilder
    private var spaceSection: some View {
        if spaces.isEmpty {
            Section {
                TextField("New space name", text: $newSpaceName)
            } header: {
                Text("Space")
            } footer: {
                Text("No spaces yet — a new one will be created.")
            }
        } else {
            Section("Space") {
                Picker("Space", selection: $selectedSpaceID) {
                    ForEach(spaces) { space in
                        Text(space.name).tag(Optional(space.persistentModelID))
                    }
                }
            }
        }
    }

    private var canCreate: Bool {
        guard !name.trimmed.isEmpty else { return false }
        switch kind {
        case .space:
            return true
        case .list, .project:
            return spaces.isEmpty ? !newSpaceName.trimmed.isEmpty : selectedSpaceID != nil
        }
    }

    private func create() {
        let trimmedName = name.trimmed
        switch kind {
        case .space:
            let index = Space.nextSortIndex(context: modelContext)
            modelContext.insert(Space(name: trimmedName, sortIndex: index))
        case .list:
            guard let space = resolveSpace() else { return }
            let index = Containers.nextListSortIndex(in: space)
            modelContext.insert(List(title: trimmedName, kind: .user, space: space, sortIndex: index))
        case .project:
            guard let space = resolveSpace() else { return }
            let index = Containers.nextProjectSortIndex(in: space)
            modelContext.insert(Project(title: trimmedName, space: space, sortIndex: index))
        }
        dismiss()
    }

    // Returns the space to attach a new List/Project to: either the picked
    // existing one, or a freshly created Space when none exist.
    private func resolveSpace() -> Space? {
        if spaces.isEmpty {
            let trimmed = newSpaceName.trimmed
            guard !trimmed.isEmpty else { return nil }
            let index = Space.nextSortIndex(context: modelContext)
            let space = Space(name: trimmed, sortIndex: index)
            modelContext.insert(space)
            return space
        }
        return spaces.first { $0.persistentModelID == selectedSpaceID }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
