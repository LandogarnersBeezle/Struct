//
//  SmoothDragFloatingRow.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI

/// A floating row that follows the finger during drag operations.
/// This creates the Things 3-like smooth transition where the row appears
/// to lift off and follow the user's finger.
struct SmoothDragFloatingRow: View {
    let child: ContainerChild
    let position: CGPoint
    let scale: CGFloat
    let opacity: CGFloat
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            ContainerRowView(
                symbol: child.symbol,
                title: child.title,
                openTaskCount: child.openTaskCount,
                color: child.containerColor
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            )
            .position(x: position.x, y: position.y)
            .scaleEffect(scale)
            .opacity(opacity)
            .allowsHitTesting(false)
        }
    }
}