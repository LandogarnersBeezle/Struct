//
//  ItemAutoScrollOverlay.swift
//  Struct
//
//  Created on 15.06.2026.
//

import SwiftUI
import UIKit

// MARK: - ItemAutoScrollOverlay

/// A transparent overlay that automatically scrolls the content view when a drag
/// gesture approaches the top or bottom edges of the visible area.
///
/// Mirrors the sidebar's `AutoScrollOverlay` but works with `ItemDragState`.
struct ItemAutoScrollOverlay: UIViewRepresentable {
    
    /// Reference to the shared drag state for monitoring drag position and status.
    let dragState: ItemDragState
    
    /// Closure that returns the total content height of the scroll view.
    let contentHeight: () -> CGFloat
    
    func makeUIView(context: Context) -> ItemAutoScrollUIView {
        let view = ItemAutoScrollUIView()
        view.dragState = dragState
        view.contentHeight = contentHeight
        // Delay scrollView discovery to ensure layout is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak view] in
            view?.findScrollView()
        }
        return view
    }
    
    func updateUIView(_ uiView: ItemAutoScrollUIView, context: Context) {
        uiView.updateAutoScroll()
    }
    
    static func dismantleUIView(_ uiView: ItemAutoScrollUIView, coordinator: ()) {
        uiView.stopAutoScroll()
    }
}

// MARK: - ItemAutoScrollUIView

/// The UIKit view that performs the actual auto-scroll logic for item drag operations.
/// This view is transparent and does not intercept any touch events.
class ItemAutoScrollUIView: UIView {
    
    // MARK: - Properties
    
    weak var dragState: ItemDragState?
    var contentHeight: () -> CGFloat = { 0 }
    
    private weak var scrollView: UIScrollView?
    private var displayLink: CADisplayLink?
    
    // Scroll threshold: begin scrolling when drag is within this distance from edge
    private var threshold: CGFloat { LayoutMetrics.focusView.autoScrollThreshold }
    
    // Maximum scroll speed in points per second (at the very edge)
    private var maxScrollSpeed: CGFloat { LayoutMetrics.focusView.autoScrollMaxSpeed }
    
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
        if let scrollView = view as? UIScrollView,
           !(view is UITextView) &&
           !(view is UICollectionView) &&
           !(view is UITableView) {
            return scrollView
        }
        
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
              drag.isDragging,
              let scrollView = scrollView else { return }
        
        // Convert window coordinates to content view coordinates for threshold comparison
        let contentLocation = drag.toContentView(drag.location)
        let fingerY = contentLocation.y
        let visibleHeight = scrollView.bounds.height
        
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
    private func calculateSpeed(distance: CGFloat) -> CGFloat {
        let ratio = 1.0 - (distance / threshold)
        return maxScrollSpeed * max(0, ratio)
    }
    
    /// Starts the CADisplayLink-driven auto-scroll animation.
    private func startAutoScroll(direction: Int, speed: CGFloat) {
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
              drag.isDragging else {
            stopAutoScroll()
            return
        }
        
        let deltaTime = link.duration
        let scrollAmount = scrollSpeed * CGFloat(scrollDirection) * deltaTime
        
        var newOffset = scrollView.contentOffset.y + scrollAmount
        
        let contentH = contentHeight()
        let visibleH = scrollView.bounds.height
        let maxOffset = max(0, contentH - visibleH)
        newOffset = max(0, min(newOffset, maxOffset))
        
        scrollView.contentOffset.y = newOffset
        
        // Update scrollOffset so toContentView() stays in sync with the
        // UIScrollView's content position during auto-scroll
        drag.scrollOffset = newOffset
    }
}