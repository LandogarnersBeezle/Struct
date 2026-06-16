//
//  SmoothDragManager.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI
import SwiftData

/// Central manager for smooth drag-and-drop operations.
/// Coordinates the visual state during drag to create Things 3-like smooth transitions.
@Observable
final class SmoothDragManager {
    
    // MARK: - State
    
    /// The ID of the item currently being dragged
    var draggingID: ContainerChild.ID?
    
    /// Current finger position in window coordinates
    var fingerPosition: CGPoint = .zero
    
    /// Current scale factor for the dragged item
    var dragScale: CGFloat = 1.0
    
    /// Current opacity for the dragged item
    var dragOpacity: CGFloat = 1.0
    
    /// Whether a drag operation is in progress
    var isDragging: Bool { draggingID != nil }
    
    
    // MARK: - Animation Constants
    
    /// Scale factor during lift (1.05x = slightly enlarged)
    let liftScale: CGFloat = 1.05
    
    /// Opacity during lift (0.85 = slightly transparent)
    let liftOpacity: CGFloat = 0.85
    
    /// Duration of lift animation
    let liftDuration: CGFloat = 0.15
    
    /// Duration of drop animation
    let dropDuration: CGFloat = 0.1
    
    /// Duration of settle animation
    let settleDuration: CGFloat = 0.15
    
    // MARK: - Drag Lifecycle
    
    /// Begins a drag operation with smooth lift animation.
    /// - Parameters:
    ///   - id: The ID of the item being dragged
    ///   - position: Initial finger position in window coordinates
    func beginDrag(id: ContainerChild.ID, at position: CGPoint) {
        draggingID = id
        fingerPosition = position
        
        // Animate lift effect
        withAnimation(.spring(duration: Double(liftDuration), bounce: 0)) {
            dragScale = liftScale
            dragOpacity = liftOpacity
        }
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    /// Updates the finger position during drag.
    /// - Parameter position: New finger position in window coordinates
    func updateFingerPosition(_ position: CGPoint) {
        fingerPosition = position
    }
    
    /// Ends the drag operation with smooth drop animation.
    func endDrag() {
        // First phase: quick scale down with bounce
        withAnimation(.spring(duration: Double(dropDuration), bounce: 0.3)) {
            dragScale = 0.95
            dragOpacity = 1.0
        }
        
        // Second phase: settle to normal and clear drag state
        DispatchQueue.main.asyncAfter(deadline: .now() + dropDuration) { [weak self] in
            let settleDur = self?.settleDuration ?? 0.15
            withAnimation(.spring(duration: Double(settleDur), bounce: 0)) {
                self?.dragScale = 1.0
                self?.dragOpacity = 1.0
            }
            // Clear drag state after settle animation
            DispatchQueue.main.asyncAfter(deadline: .now() + settleDur) { [weak self] in
                self?.draggingID = nil
            }
        }
    }
    
    /// Cancels the drag operation (e.g., when drag exits valid area).
    func cancelDrag() {
        withAnimation(.spring(duration: 0.2, bounce: 0)) {
            dragScale = 1.0
            dragOpacity = 1.0
        }
        draggingID = nil
    }
    
    /// Immediately resets all state without animation.
    func reset() {
        draggingID = nil
        fingerPosition = .zero
        dragScale = 1.0
        dragOpacity = 1.0
    }
}