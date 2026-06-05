//
//  TaskCreationCard.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI

/// A card-style view for creating new tasks.
/// Appears at the top of the container list when the user taps the "+" button.
struct TaskCreationCard: View {
    @Binding var title: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with cancel and save buttons
            HStack {
                Button("Cancel", action: onCancel)
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Save", action: onSave)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.blue)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            // Title input field
            TextField("Task title", text: $title, axis: .vertical)
                .font(.body)
                .focused($isTitleFocused)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
            
            Divider()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            isTitleFocused = true
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var title = ""
        
        var body: some View {
            VStack {
                TaskCreationCard(
                    title: $title,
                    onSave: {
                        print("Save tapped: \(title)")
                    },
                    onCancel: {
                        print("Cancel tapped")
                    }
                )
                
                Spacer()
            }
            .padding(.top, 20)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    return PreviewWrapper()
}