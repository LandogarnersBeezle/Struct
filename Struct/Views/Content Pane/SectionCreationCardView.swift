//
//  SectionCreationCardView.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI

/// A simplified card for creating a new task section. Contains only a title field
/// with Cancel/Save buttons. No date picker or container selector.
struct SectionCreationCardView: View {
    let targetContainer: ContainerTarget
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var title: String = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Title field
            TextField("Section title", text: $title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isTitleFocused)
                .onAppear {
                    isTitleFocused = true
                }

            // Buttons
            HStack(spacing: 12) {
                Button(role: .cancel) {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)

                Button {
                    onSave(title)
                } label: {
                    Image(systemName: "checkmark")
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
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.gray, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    SectionCreationCardView(
        targetContainer: .space(Space(name: "Personal", sortIndex: 0)),
        onCancel: {},
        onSave: { _ in }
    )
    .padding()
}