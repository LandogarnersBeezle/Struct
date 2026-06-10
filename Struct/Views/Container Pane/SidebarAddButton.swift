//
//  SidebarAddButton.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI

// MARK: - Sidebar Add Button

/// Floating add button for the sidebar.
///
/// This button appears in the bottom-right corner of the sidebar when
/// no container is swipe-selected. It will be used to trigger container
/// creation functionality.
struct SidebarAddButton: View {
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("Add container", comment: "Add button accessibility label"))
        .accessibilityHint(NSLocalizedString("Tap to create a new list or project", comment: "Add button accessibility hint"))
    }
}