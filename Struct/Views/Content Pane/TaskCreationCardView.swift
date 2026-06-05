//
//  TaskCreationCardView.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI
import SwiftData

/// An expanded task creation card that slides in at the top of the content area
/// when the user taps the + button. Contains a title field with Cancel / Save
/// buttons.
struct TaskCreationCardView: View {
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var title: String = "Test Task"

    var body: some View {
        VStack(spacing: 12) {
            // Title field
            TextField("Task title", text: $title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    onSave(title)
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    TaskCreationCardView(
        onCancel: {},
        onSave: { _ in }
    )
    .padding()
}