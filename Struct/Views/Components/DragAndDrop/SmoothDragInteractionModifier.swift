//
//  SmoothDragInteractionModifier.swift
//  Struct
//
//  Created by Otto Kiefer on 12.06.2026.
//

import SwiftUI

// MARK: - Drag State Helper

/// Helper class to manage drag visual state across the view hierarchy
@Observable
class DragVisualState {
    /// The ID of the item currently being dragged
    var draggingID: AnyHashable?
    
    /// The scale factor for the dragged item (1.0 = normal, 1.05 = lifted)
    var dragScale: CGFloat = 1.0
    
    /// The opacity for the dragged item (1.0 = normal, 0.0 = hidden)
    var dragOpacity: CGFloat = 1.0
    
    /// Whether the drag is currently active
    var isDragging: Bool { draggingID != nil }
    
    /// Begin drag with smooth lift animation
    func beginDrag(id: AnyHashable) {
        draggingID = id
        withAnimation(.spring(duration: 0.15, bounce: 0)) {
            dragScale = 1.05
            dragOpacity = 0.0  // Make invisible - the floating version will be visible
        }
    }
    
    /// End drag with smooth settle animation
    func endDrag() {
        withAnimation(.spring(duration: 0.1, bounce: 0.3)) {
            dragScale = 0.95
            dragOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            withAnimation(.spring(duration: 0.15, bounce: 0)) {
                self?.dragScale = 1.0
                self?.dragOpacity = 1.0
            }
            self?.draggingID = nil
        }
    }
    
    /// Cancel drag - return to normal
    func cancelDrag() {
        withAnimation(.spring(duration: 0.2, bounce: 0)) {
            dragScale = 1.0
            dragOpacity = 1.0
        }
        draggingID = nil
    }
}

// MARK: - Smooth Drag Row Modifier

/// A modifier that makes a row participate in smooth drag-and-drop
/// by transforming it into a floating element during drag
struct SmoothDragRowModifier: ViewModifier {
    let dragState: DragVisualState
    let rowID: AnyHashable
    let isBeingDragged: Bool
    let onDragStart: (CGPoint) -> Void
    let onDragChange: (CGPoint) -> Void
    let onDragEnd: () -> Void
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isBeingDragged ? dragState.dragScale : 1.0)
            .opacity(isBeingDragged ? dragState.dragOpacity : 1.0)
            .animation(.spring(duration: 0.15, bounce: 0), value: isBeingDragged)
    }
}

// MARK: - Floating Drag Card

/// A floating card that appears during drag and follows the finger
/// This replaces the original row visually during drag
struct FloatingDragCard<Content: View>: View {
    let content: Content
    let isShowing: Bool
    let position: CGPoint
    let scale: CGFloat
    let opacity: CGFloat
    
    init(
        isShowing: Bool,
        position: CGPoint,
        scale: CGFloat = 1.0,
        opacity: CGFloat = 0.5,
        @ViewBuilder content: () -> Content
    ) {
        self.isShowing = isShowing
        self.position = position
        self.scale = scale
        self.opacity = opacity
        self.content = content()
    }
    
    var body: some View {
        if isShowing {
            content
                .position(x: position.x, y: position.y)
                .scaleEffect(scale)
                .opacity(opacity)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - View Extension

extension View {
    /// Apply smooth drag transition to a row
    func smoothDragRow(
        dragState: DragVisualState,
        rowID: AnyHashable,
        onDragStart: @escaping (CGPoint) -> Void = { _ in },
        onDragChange: @escaping (CGPoint) -> Void = { _ in },
        onDragEnd: @escaping () -> Void = {}
    ) -> some View {
        let isBeingDragged = dragState.draggingID as? AnyHashable == rowID
        return modifier(SmoothDragRowModifier(
            dragState: dragState,
            rowID: rowID,
            isBeingDragged: isBeingDragged,
            onDragStart: onDragStart,
            onDragChange: onDragChange,
            onDragEnd: onDragEnd
        ))
    }
}