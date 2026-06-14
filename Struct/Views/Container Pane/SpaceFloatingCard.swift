//
//  SpaceFloatingCard.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI

// MARK: - Space Floating Card

/// Floating drag card for space headers.
///
/// This card appears during space reordering operations and follows the
/// user's finger, providing visual feedback about which space is being dragged.
struct SpaceFloatingCard: View {
    let space: Space
    let layoutMetrics: LayoutMetrics

    init(space: Space, layoutMetrics: LayoutMetrics = .sidebar) {
        self.space = space
        self.layoutMetrics = layoutMetrics
    }

    var body: some View {
        spaceRowContent
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: layoutMetrics.cardCornerRadius, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(layoutMetrics.cardShadowOpacity),
                            radius: layoutMetrics.cardShadowRadius, y: 6)
                    .opacity(layoutMetrics.cardOpacity)
            )
            .transition(.opacity)
    }

    @ViewBuilder
    private var spaceRowContent: some View {
        HStack {
            Image(systemName: space.symbolName)
                .foregroundStyle(Space.containerColor)
                .frame(width: 24)
            Text(space.name)
                .lineLimit(1)
                .fontWeight(.bold)
            Spacer()
            let openCount = space.items.filter { !$0.isCompleted }.count
            if openCount > 0 {
                Text("\(openCount)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(.trailing, 5)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}