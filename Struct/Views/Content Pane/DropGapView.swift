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
    @State private var isExpanded = false
    
    private var gapHeight: CGFloat {
        itemDragState.rowHeight > 0 ? itemDragState.rowHeight : 44
    }
    
    var body: some View {
        Rectangle()
            .fill(Color.green.opacity(0.3))
            .frame(height: gapHeight)
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .scaleEffect(isExpanded ? 1.0 : 0.95)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: isExpanded)
            .onAppear {
                isExpanded = true
            }
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
