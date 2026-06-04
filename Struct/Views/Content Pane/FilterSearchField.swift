//
//  FilterSearchField.swift
//  Struct
//
//  Created by Otto Kiefer on 05.05.2026.
//

import SwiftUI

/// A search field component for filtering containers.
struct FilterSearchField: View {
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool
    
    var onSubmit: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter containers", text: $searchText)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { onSubmit?(); isFocused = false }
            if !searchText.isEmpty {
                Button {
                    withAnimation {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 8))
    }
}
