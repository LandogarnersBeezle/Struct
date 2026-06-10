//
//  TaskDropGapView.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI

/// Dashed-outline placeholder that shows where the dragged card will land.
struct TaskDropGapView: View {
    let cardHeight: CGFloat
    
    private let layoutMetrics = LayoutMetrics.focusView
    
    var body: some View {
        RoundedRectangle(cornerRadius: layoutMetrics.dropGapCornerRadius, style: .continuous)
            .strokeBorder(
                Color.accentColor.opacity(0.55),
                style: StrokeStyle(lineWidth: layoutMetrics.dropGapLineWidth, dash: layoutMetrics.dropGapDashPattern)
            )
            .frame(height: cardHeight)
            .padding(.horizontal, 16)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.85).combined(with: .opacity),
                removal: .opacity.animation(.easeOut(duration: layoutMetrics.cardFadeOutDuration))
            ))
    }
}