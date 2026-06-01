# Auto-Scroll Implementation Plan

## Overview

Add automatic scrolling to the container sidebar when dragging items near the top or bottom edges of the scroll view. This allows users to access all drop zones without manually scrolling first.

## Architecture

### Core Principle
**Keep the native SwiftUI `ScrollView` intact** and add a transparent overlay that manipulates the underlying `UIScrollView` during drag operations.

### Components

1. **AutoScrollOverlay.swift** (New file)
   - `UIViewRepresentable` that creates a transparent overlay
   - Finds the underlying `UIScrollView` once on mount
   - Monitors drag state and triggers scrolling when in threshold zones
   - Uses `CADisplayLink` for 60fps smooth scrolling

2. **SidebarDragState.swift** (Modify)
   - Add auto-scroll state tracking properties
   - Add methods to start/stop/update auto-scroll behavior

3. **ContainersSidebarView.swift** (Modify)
   - Add `AutoScrollOverlay` as an overlay on the `ScrollView`

## Implementation Details

### AutoScrollOverlay.swift

```swift
import SwiftUI
import UIKit

struct AutoScrollOverlay: UIViewRepresentable {
    @ObservedObject var dragState: SidebarDragState
    let scrollViewContentHeight: () -> CGFloat
    
    func makeUIView(context: Context) -> AutoScrollUIView {
        let view = AutoScrollUIView()
        view.dragState = dragState
        view.scrollViewContentHeight = scrollViewContentHeight
        view.setupScrollViewFinder()
        return view
    }
    
    func updateUIView(_ uiView: AutoScrollUIView, context: Context) {
        uiView.updateAutoScroll()
    }
    
    static func dismantleUIView(_ uiView: AutoScrollUIView, coordinator: ()) {
        uiView.stopAutoScroll()
    }
}

class AutoScrollUIView: UIView {
    weak var dragState: SidebarDragState?
    var scrollViewContentHeight: () -> CGFloat = { 0 }
    private weak var scrollView: UIScrollView?
    private var displayLink: CADisplayLink?
    
    // Threshold: start scrolling when within 60px of edge
    private let threshold: CGFloat = 60
    // Maximum scroll speed: 300px/s at the very edge
    private let maxScrollSpeed: CGFloat = 300
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func findScrollView() {
        guard let window = UIApplication.shared.windows.first else { return }
        
        scrollView = findScrollView(in: window)
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
    
    func updateAutoScroll() {
        guard let drag = dragState,
              drag.isDragging || drag.isDraggingSpace,
              let scrollView = scrollView else { return }
        
        let contentHeight = scrollViewContentHeight()
        let visibleHeight = scrollView.bounds.height
        let scrollOffset = scrollView.contentOffset.y
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
        
        stopAutoScroll()
    }
    
    private func calculateSpeed(distance: CGFloat) -> CGFloat {
        // Linear interpolation: 0 at threshold, max at edge
        let ratio = 1.0 - (distance / threshold)
        return maxScrollSpeed * max(0, ratio)
    }
    
    private func startAutoScroll(direction: Int, speed: CGFloat) {
        guard displayLink == nil else { return }
        
        let link = CADisplayLink(target: self, selector: #selector(scrollStep(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        
        // Store scroll parameters
        scrollDirection = direction
        scrollSpeed = speed
    }
    
    private var scrollDirection: Int = 0
    private var scrollSpeed: CGFloat = 0
    
    @objc private func scrollStep(_ link: CADisplayLink) {
        guard let scrollView = scrollView,
              let drag = dragState,
              (drag.isDragging || drag.isDraggingSpace) else {
            stopAutoScroll()
            return
        }
        
        let deltaTime = link.duration
        let scrollAmount = scrollSpeed * CGFloat(scrollDirection) * deltaTime
        
        var newOffset = scrollView.contentOffset.y + scrollAmount
        
        // Clamp to valid scroll range
        let maxOffset = scrollViewContentHeight() - scrollView.bounds.height
        newOffset = max(0, min(newOffset, maxOffset))
        
        scrollView.contentOffset.y = newOffset
        
        // Update drag state's scroll offset tracking if needed
        // This ensures drop target calculations account for scroll position
    }
    
    func stopAutoScroll() {
        displayLink?.invalidate()
        displayLink = nil
    }
}
```

### SidebarDragState.swift Additions

Add these properties to `SidebarDragState`:

```swift
// MARK: - Auto-Scroll State

/// Current vertical scroll offset of the sidebar (updated by AutoScrollOverlay)
var scrollOffset: CGFloat = 0

/// Called when auto-scroll begins
func didStartAutoScroll() {
    // Optional: Add haptic feedback or other effects
}

/// Called when auto-scroll ends
func didStopAutoScroll() {
    // Optional: Cleanup
}
```

### ContainersSidebarView.swift Modifications

Add the overlay to the `ScrollView`:

```swift
private var scrollContent: some View {
    ScrollView {
        // ... existing content ...
    }
    .coordinateSpace(.named("sidebar"))
    .overlay {
        // Existing GeometryReader for sidebar origin
        GeometryReader { geo in
            Color.clear
                .preference(key: SidebarOriginKey.self,
                           value: geo.frame(in: .global).origin)
        }
    }
    .overlay {
        // NEW: Auto-scroll overlay
        AutoScrollOverlay(
            dragState: drag,
            scrollViewContentHeight: { [weak self] in
                // Calculate total content height
                guard let self = self else { return 0 }
                // Sum up all space heights + content
                // This is an approximation; could be improved with actual measurement
                return self.estimateContentHeight()
            }
        )
    }
    // ... rest of modifiers ...
}

private func estimateContentHeight() -> CGFloat {
    // Estimate based on number of items
    // Each row is approximately 44px, headers ~44px, spacing ~8px
    let rowHeight: CGFloat = 44
    let headerHeight: CGFloat = 44
    let spacing: CGFloat = 8
    
    var total: CGFloat = 0
    for space in spaces {
        total += headerHeight + spacing
        let children = Containers.children(of: space).count
        total += CGFloat(children) * rowHeight
    }
    return total
}
```

## Threshold Zones

- **Top Zone**: 0-60px from top of visible area
- **Bottom Zone**: 0-60px from bottom of visible area
- **Scroll Speed**: 0px/s at 60px threshold → 300px/s at 0px from edge

## Performance Considerations

1. **UIScrollView found once** - No continuous hierarchy traversal
2. **CADisplayLink only active during drag** - No overhead when idle
3. **Transparent overlay** - `isUserInteractionEnabled = false` ensures no touch interference
4. **Efficient scroll calculations** - Simple linear interpolation for speed

## Testing Checklist

- [ ] Drag item near top edge → view scrolls up
- [ ] Drag item near bottom edge → view scrolls down
- [ ] Scroll speed increases as finger approaches edge
- [ ] Scrolling stops when finger moves away from edge
- [ ] Drop target updates correctly during auto-scroll
- [ ] Works for both container and space drags
- [ ] No gesture conflicts with swipe-to-delete
- [ ] No layout issues or visual glitches
- [ ] Performance is smooth (60fps)

## Future Improvements

1. **Dynamic content height** - Use actual measurement instead of estimation
2. **Configurable thresholds** - Allow customization of threshold distance and max speed
3. **Acceleration curve** - Use exponential instead of linear speed curve for more natural feel
4. **Scroll indicators** - Show scroll indicators during auto-scroll for better feedback