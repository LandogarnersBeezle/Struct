//
//  ContainerCreationCardView.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI
import SwiftData

// MARK: - ContainerType Enum

/// Represents the three types of containers that can be created.
enum ContainerType: String, CaseIterable {
    case space
    case list
    case project
    
    var title: String {
        switch self {
        case .space: return "Space"
        case .list: return "List"
        case .project: return "Project"
        }
    }
    
    var header: String {
        "New \(title)"
    }
    
    var placeholder: String {
        switch self {
        case .space: return "Space name"
        case .list: return "List name"
        case .project: return "Project name"
        }
    }
    
    var icon: String {
        switch self {
        case .space: return "square.grid.2x2"
        case .list: return "list.bullet"
        case .project: return "folder"
        }
    }
    
    var color: Color {
        switch self {
        case .space: return Space.containerColor
        case .list: return List.containerColor
        case .project: return Project.containerColor
        }
    }
}

// MARK: - ContainerCreationCardView

/// An inline card view for creating new containers (Space, List, or Project).
/// Appears as an overlay on top of the sidebar content with a faded background.
struct ContainerCreationCardView: View {
    @Query(sort: \Space.sortIndex) private var spaces: [Space]
    
    @Environment(\.modelContext) private var modelContext
    
    let onCancel: () -> Void
    let onSave: () -> Void
    
    @State private var name: String = ""
    @State private var selectedType: ContainerType = .list
    @State private var saveError: DataError?
    
    @FocusState private var isNameFocused: Bool
    
    /// Determines if the type selector buttons should be shown.
    /// When there are no spaces, we force Space creation and hide the buttons.
    private var showsTypeSelector: Bool {
        !spaces.isEmpty
    }
    
    /// The effective container type being created.
    /// When no spaces exist, this is always .space regardless of selection.
    private var effectiveType: ContainerType {
        showsTypeSelector ? selectedType : .space
    }
    
    /// Whether the save button should be enabled.
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with icon and title
            headerView
            
            // Name text field
            nameField
            
            // Type selector buttons (hidden when no spaces exist)
            if showsTypeSelector {
                typeSelector
            }
            
            // Action buttons
            actionButtons
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .onAppear {
            isNameFocused = true
            // Default to space when no spaces exist
            if !showsTypeSelector {
                selectedType = .space
            }
        }
        .errorAlert($saveError)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: effectiveType.icon)
                .font(.title2)
                .foregroundColor(effectiveType.color)
                .frame(width: 32, height: 32)
                .background(effectiveType.color.opacity(0.1))
                .cornerRadius(8)
            
            Text(effectiveType.header)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    // MARK: - Name Field
    
    private var nameField: some View {
        TextField(effectiveType.placeholder, text: $name, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.body)
            .focused($isNameFocused)
            .padding(12)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(10)
            .onChange(of: effectiveType) { _, _ in
                // Clear name when type changes to avoid confusion
                name = ""
            }
    }
    
    // MARK: - Type Selector
    
    private var typeSelector: some View {
        HStack(spacing: 12) {
            ForEach(ContainerType.allCases, id: \.self) { type in
                TypeButton(
                    type: type,
                    isSelected: selectedType == type,
                    action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedType = type
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Cancel button
            Button(role: .cancel) {
                onCancel()
            } label: {
                HStack {
                    Image(systemName: "xmark")
                    Text("Cancel")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            // Save button
            Button {
                save()
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Save")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
        }
    }
    
    // MARK: - Save Logic
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch effectiveType {
        case .space:
            createSpace(name: trimmedName)
        case .list:
            createList(name: trimmedName)
        case .project:
            createProject(name: trimmedName)
        }
    }
    
    private func createSpace(name: String) {
        // Shift all existing spaces down by 1
        for space in spaces {
            space.sortIndex += 1
        }
        
        // Create new space at index 0
        let newSpace = Space(name: name, sortIndex: 0)
        modelContext.insert(newSpace)
        
        saveChanges()
    }
    
    private func createList(name: String) {
        guard let firstSpace = spaces.first else { return }
        
        // Shift all existing containers in this space down by 1
        shiftContainersDown(in: firstSpace)
        
        // Create new list at index 0
        let newList = List(title: name, kind: .user, space: firstSpace, sortIndex: 0)
        modelContext.insert(newList)
        
        saveChanges()
    }
    
    private func createProject(name: String) {
        guard let firstSpace = spaces.first else { return }
        
        // Shift all existing containers in this space down by 1
        shiftContainersDown(in: firstSpace)
        
        // Create new project at index 0
        let newProject = Project(title: name, space: firstSpace, sortIndex: 0)
        modelContext.insert(newProject)
        
        saveChanges()
    }
    
    /// Shifts all Lists and Projects in the given space down by 1 in the sort order.
    private func shiftContainersDown(in space: Space) {
        for list in space.lists where list.kind != .inbox {
            list.sortIndex += 1
        }
        for project in space.projects {
            project.sortIndex += 1
        }
    }
    
    private func saveChanges() {
        do {
            try modelContext.saveOrThrow()
            onSave()
        } catch let error as DataError {
            saveError = error
        } catch {
            saveError = .saveFailed(error)
        }
    }
}

// MARK: - TypeButton

/// A button for selecting a container type in the type selector.
struct TypeButton: View {
    let type: ContainerType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.title3)
                
                Text(type.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? type.color.opacity(0.15) : Color(.systemGray6).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? type.color : Color.clear, lineWidth: 2)
            )
            .foregroundColor(isSelected ? type.color : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(.systemGray6).ignoresSafeArea()
        
        ContainerCreationCardView(
            onCancel: {},
            onSave: {}
        )
    }
}