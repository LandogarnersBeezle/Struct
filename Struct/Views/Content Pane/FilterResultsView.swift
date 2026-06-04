//
//  FilterResultsView.swift
//  Struct
//
//  Created by Otto Kiefer on 05.05.2026.
//

import SwiftUI

/// Displays a scrollable list of filtered container results.
struct FilterResultsView: View {
    let entries: [ContainerFocusViewModel.SearchEntry]
    let onSelect: (ContainerTarget) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(entries, id: \.target) { entry in
                    Button {
                        onSelect(entry.target)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: entry.target.symbol)
                                .frame(width: 20)
                                .foregroundStyle(entry.target.color)
                            Text(entry.target.title)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .padding(.leading, entry.isChild ? 16 : 0)
                    }
                    .buttonStyle(.plain)
                    Divider()
                        .padding(.leading, entry.isChild ? 60 : 44)
                        .padding(.trailing, 12)
                }
            }
        }
    }
}