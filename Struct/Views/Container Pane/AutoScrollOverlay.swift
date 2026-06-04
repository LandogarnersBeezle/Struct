//
//  AutoScrollOverlay.swift
//  Struct
//
//  Created by Otto Kiefer on 01.06.2026.
//

import SwiftUI
import UIKit

// MARK: - AutoScrollOverlay

/// A transparent overlay that automatically scrolls the sidebar when a drag
/// gesture approaches the top or bottom edges of the visible area.
///
/// This overlay keeps the native SwiftUI ScrollView intact and only manipulates
/// the underlying UIScrollView during drag operations. The overlay itself has
/// `isUserInteractionEnabled = false`, ensuring all touches pass through to
/// the underlying views without interference.
struct AutoScrollOverlay: UIViewRepresentable {
    
    /// Reference to the shared drag state for monitoring drag position and status.
    let dragState: SidebarDragState
    
    /// Closure that returns the total content height of the scroll view.
    let contentHeight: () -> CGFloat
    
    func makeUIView(context: Context) -> AutoScrollUIView {
        let view = AutoScrollUIView()
        view.dragState = dragState
        view.contentHeight = contentHeight
        // Delay scrollView discovery to ensure layout is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak view] in
            view?.findScrollView()
        }
        return view
    }
    
    func updateUIView(_ uiView: AutoScrollUIView, context: Context) {
        uiView.updateAutoScroll()
    }
    
    static func dismantleUIView(_ uiView: AutoScrollUIView, coordinator: ()) {
        uiView.stopAutoScroll()
    }
}

// MARK: - AutoScrollUIView

/// The UIKit view that performs the actual auto-scroll logic.
/// This view is transparent and does not intercept any touch events.
class AutoScrollUIView: UIView {
    
    // MARK: - Properties
    
    weak var dragState: SidebarDragState?
    var contentHeight: () -> CGFloat = { 0 }
    
    private weak var scrollView: UIScrollView?
    private var displayLink: CADisplayLink?
    
    // Scroll threshold: begin scrolling when drag is within this distance from edge
    private let threshold: CGFloat = 60
    
    // Maximum scroll speed in points per second (at the very edge)
    private let maxScrollSpeed: CGFloat = 300
    
    // Current scroll direction: -1 for up, 1 for down, 0 for stopped
    private var scrollDirection: Int = 0
    
    // Current scroll speed in points per second
    private var scrollSpeed: CGFloat = 0
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UIScrollView Discovery
    
    /// Traverses the view hierarchy to find the UIScrollView that backs
    /// the SwiftUI ScrollView. This is done once on mount.
    func findScrollView() {
        // Use UIWindowScene.windows on a relevant window scene (iOS 15+)
        // Fallback to keyWindow for iOS 13-14
        let window: UIWindow?
        if #available(iOS 15.0, *) {
            window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            window = UIApplication.shared.keyWindow
        }
        
        guard let targetWindow = window else { return }
        
        scrollView = findScrollView(in: targetWindow)
    }
    
    private func findScrollView(in view: UIView) -> UIScrollView? {
        // Check if this view is a UIScrollView, but exclude UITextView,
        // UICollectionView, and UITableView which are not our target
        if let scrollView = view as? UIScrollView,
           !(view is UITextView) &&
           !(view is UICollectionView) &&
           !(view is UITableView) {
            return scrollView
        }
        
        // Recursively search subviews
        for subview in view.subviews {
            if let found = findScrollView(in: subview) {
                return found
            }
        }
        
        return nil
    }
    
    // MARK: - Auto-Scroll Logic
    
    /// Checks the current drag position and starts/stops auto-scroll as needed.
    func updateAutoScroll() {
        guard let drag = dragState,
              (drag.isDragging || drag.isDraggingSpace),
              let scrollView = scrollView else { return }
        
        let visibleHeight = scrollView.bounds.height
        let fingerY = drag.location.y
        
        // Check if finger is in top threshold zone
        if fingerY < threshold {
            let speed = calculateSpeed(distance: fingerY)
            startAutoScroll(direction: -1, speed: speed)
            return
        }
        
        // Check if finger is in bottom threshold zone
        if fingerY > visibleHeight - threshold {
            let distanceFromBottom = visibleHeight - fingerY
            let speed = calculateSpeed(distance: distanceFromBottom)
            startAutoScroll(direction: 1, speed: speed)
            return
        }
        
        // Finger is not near any edge — stop scrolling
        stopAutoScroll()
    }
    
    /// Calculates scroll speed based on distance from edge.
    /// Speed is 0 at the threshold boundary and maxScrollSpeed at the edge.
    private func calculateSpeed(distance: CGFloat) -> CGFloat {
        let ratio = 1.0 - (distance / threshold)
        return maxScrollSpeed * max(0, ratio)
    }
    
    /// Starts the CADisplayLink-driven auto-scroll animation.
    private func startAutoScroll(direction: Int, speed: CGFloat) {
        // Only start if not already scrolling in the same direction at similar speed
        if displayLink != nil && scrollDirection == direction && abs(scrollSpeed - speed) < 10 {
            return
        }
        
        stopAutoScroll()
        
        scrollDirection = direction
        scrollSpeed = speed
        
        let link = CADisplayLink(target: self, selector: #selector(scrollStep(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    
    /// Stops the auto-scroll animation and cleans up the display link.
    func stopAutoScroll() {
        displayLink?.invalidate()
        displayLink = nil
        scrollDirection = 0
        scrollSpeed = 0
    }
    
    /// Called by CADisplayLink at 60fps to perform the actual scrolling.
    @objc private func scrollStep(_ link: CADisplayLink) {
        guard let scrollView = scrollView,
              let drag = dragState,
              (drag.isDragging || drag.isDraggingSpace) else {
            stopAutoScroll()
            return
        }
        
        // Calculate scroll amount for this frame
        let deltaTime = link.duration
        let scrollAmount = scrollSpeed * CGFloat(scrollDirection) * deltaTime
        
        // Apply scroll offset
        var newOffset = scrollView.contentOffset.y + scrollAmount
        
        // Clamp to valid scroll range
        let contentH = contentHeight()
        let visibleH = scrollView.bounds.height
        let maxOffset = max(0, contentH - visibleH)
        newOffset = max(0, min(newOffset, maxOffset))
        
        scrollView.contentOffset.y = newOffset
        
        // Update scrollOffset so toSidebar() stays in sync with the
        // UIScrollView's content position during auto-scroll.
        drag.scrollOffset = newOffset
    }
}
