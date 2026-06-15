//
//  ItemDropGapView.swift
//  Struct
//
//  Created by Otto Kiefer on 14.06.2026.
//

import SwiftUI

/// A visual gap indicator shown during item drag-and-drop to indicate the drop position.
/// Renders as a green-tinted horizontal bar with rounded corners, matching the row height.
struct ItemDropGapView: View {
    @Environment(ItemDragState.self) private var itemDragState
    
    private var gapHeight: CGFloat {
        itemDragState.rowHeight > 0 ? itemDragState.rowHeight : 44
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.green.opacity(0.15))
            .frame(height: gapHeight)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.85).combined(with: .opacity),
                removal:   .opacity.animation(.easeOut(duration: 0.18))
            ))
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Regular item")
        ItemDropGapView()
        Text("Another item")
    }
    .padding()
}
