# Things 3-Like Smooth Drag-and-Drop Implementation Plan (From Baseline)

## Overview

This document provides the detailed implementation plan for achieving Things 3-level smooth drag-and-drop transitions, starting from the **original baseline state** (before any smooth drag modifications). This is the recommended approach as it provides the cleanest implementation path.

## Baseline State Description

The baseline state (git commit before smooth drag modifications) has:
- `SidebarDragState` with basic drag state (`dragging`, `floatingCardChild`, `location`)
- `SpaceSectionView` with ghost row that collapses to height 0
- `ContainersSidebarView` with `floatingCardOverlay` using `DragFloatingCard`
- `DragFloatingCard.swift` - Basic floating card with simple fade transition
- `draggableRowInteraction` modifier for UIKit gesture handling

**No visual state properties** (`dragScale`, `dragOpacity`) exist in the baseline.

---

## Implementation Architecture

### Core Principle

**Keep the row in the layout but make it visually float above everything using z-index and positioning.**

### Visual Layers (z-index order)

```
Layer 3 (top):     SmoothDragFloatingRow (follows finger)
Layer 2:           Drop gap (green placeholder)
Layer 1 (bottom):  Layout with ghost row (transparent, full height)
```

---

## Files to Create

### 1. `Struct/Views/Components/DragAndDrop/SmoothDragManager.swift`

```swift
//
//  SmoothDragManager.swift
//  Struct
//
//  Created by [Your Name] on [Date].
//

import SwiftUI
import SwiftData

/// Central manager for smooth drag-and-drop operations.
/// Coordinates the visual state across all views involved in dragging,
/// providing Things 3-like smooth transitions.
@Observable
final class SmoothDragManager {
    
    // MARK: - Drag State
    
    /// The item currently being dragged
    var draggingID: ContainerChild.ID?
    
    /// Current finger position in window coordinates
    var fingerPosition: CGPoint = .zero
    
    /// Scale factor for the dragged item
    var dragScale: CGFloat = 1.0
    
    /// Opacity for the dragged item
    var dragOpacity: CGFloat = 1.0
    
    /// Whether drag is active
    var isDragging: Bool { draggingID != nil }
    
    // MARK: - Configuration
    
    /// Scale when lifted
    let liftScale: CGFloat = 1.05
    
    /// Opacity when lifted
    let liftOpacity: CGFloat = 0.85
    
    /// Duration of lift animation
    let liftDuration: CGFloat = 0.15
    
    /// Duration of drop animation
    let dropDuration: CGFloat = 0.1
    
    /// Duration of settle animation
    let settleDuration: CGFloat = 0.15
    
    // MARK: - Lifecycle
    
    /// Begin drag with smooth lift animation
    func beginDrag(id: ContainerChild.ID, at position: CGPoint) {
        draggingID = id
        fingerPosition = position
        
        // Smooth lift animation
        withAnimation(.spring(duration: liftDuration, bounce: 0)) {
            dragScale = liftScale
            dragOpacity = liftOpacity
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    /// Update finger position during drag
    func updateFingerPosition(_ position: CGPoint) {
        fingerPosition = position
    }
    
    /// End drag with smooth settle animation
    func endDrag() {
        // Quick scale down with bounce
        withAnimation(.spring(duration: dropDuration, bounce: 0.3)) {
            dragScale = 0.95
            dragOpacity = 1.0
        }
        
        // Settle to normal
        DispatchQueue.main.asyncAfter(deadline: .now() + dropDuration) { [weak self] in
            withAnimation(.spring(duration: self?.settleDuration ?? 0.15, bounce: 0)) {
                self?.dragScale = 1.0
                self?.dragOpacity = 1.0
            }
            self?.draggingID = nil
        }
    }
    
    /// Cancel drag - return to normal immediately
    func cancelDrag() {
        withAnimation(.spring(duration: 0.2, bounce: 0)) {
            dragScale = 1.0
            dragOpacity = 1.0
        }
        draggingID = nil
    }
    
    /// Reset all state
    func reset() {
        draggingID = nil
        dragScale = 1.0
        dragOpacity = 1.0
    }
}
```

### 2. `Struct/Views/Container Pane/SmoothDragFloatingRow.swift`

```swift
//
//  SmoothDragFloatingRow.swift
//  Struct
//
//  Created by [Your Name] on [Date].
//

import SwiftUI

/// The floating row that follows the finger during drag.
/// This provides the visual feedback during drag operations,
/// appearing to lift the original row out of the layout.
struct SmoothDragFloatingRow: View {
    let child: ContainerChild
    let position: CGPoint
    let scale: CGFloat
    let opacity: CGFloat
    let isVisible: Bool
    let layoutMetrics: LayoutMetrics
    
    init(
        child: ContainerChild,
        position: CGPoint,
        scale: CGFloat = 1.0,
        opacity: CGFloat = 0.5,
        isVisible: Bool,
        layoutMetrics: LayoutMetrics = .sidebar
    ) {
        self.child = child
        self.position = position
        self.scale = scale
        self.opacity = opacity
        self.isVisible = isVisible
        self.layoutMetrics = layoutMetrics
    }
    
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
                RoundedRectangle(cornerRadius: layoutMetrics.cardCornerRadius, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(layoutMetrics.cardShadowOpacity),
                            radius: layoutMetrics.cardShadowRadius, y: 6)
                    .opacity(layoutMetrics.cardOpacity)
            )
            .position(x: position.x, y: position.y)
            .scaleEffect(scale)
            .opacity(opacity)
            .allowsHitTesting(false)  // Let touches pass through
        }
    }
}
```

### 3. `Struct/Views/Container Pane/SmoothDropGap.swift`

```swift
//
//  SmoothDropGap.swift
//  Struct
//
//  Created by [Your Name] on [Date].
//

import SwiftUI

/// Enhanced drop gap with smooth animations.
/// Shows where the dragged item will land with a subtle green placeholder.
struct SmoothDropGap: View {
    let height: CGFloat
    let layoutMetrics: LayoutMetrics
    let isInserting: Bool
    
    init(
        height: CGFloat,
        layoutMetrics: LayoutMetrics = .sidebar,
        isInserting: Bool = false
    ) {
        self.height = height
        self.layoutMetrics = layoutMetrics
        self.isInserting = isInserting
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: layoutMetrics.dropGapCornerRadius, style: .continuous)
            .fill(Color.green.opacity(0.15))
            .frame(height: height)
            .padding(.horizontal, 4)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.85).combined(with: .opacity),
                removal: .scale(scale: 1.1).combined(with: .opacity)
            ))
            .animation(.spring(duration: 0.25, bounce: 0.2), value: isInserting)
    }
}
```

---

## Files to Modify

### 1. `Struct/Views/Container Pane/ContainersSidebarView.swift`

**Changes:**

1. Add `SmoothDragManager` as `@State`
2. Replace `floatingCardOverlay` with `SmoothDragFloatingRow`
3. Update gesture callbacks to use `SmoothDragManager`

```swift
struct ContainersSidebarView: View {
    // ... existing properties ...
    
    // ADD: New smooth drag manager
    @State private var smoothDragManager = SmoothDragManager()
    
    // REPLACE: floatingCardOverlay
    @ViewBuilder
    private var floatingCardOverlay: some View {
        if let draggingID = smoothDragManager.draggingID,
           let child = findChild(by: draggingID) {
            SmoothDragFloatingRow(
                child: child,
                position: smoothDragManager.fingerPosition,
                scale: smoothDragManager.dragScale,
                opacity: smoothDragManager.dragOpacity,
                isVisible: smoothDragManager.isDragging,
                layoutMetrics: layoutMetrics
            )
        }
    }
    
    // ADD: Helper to find child by ID
    private func findChild(by id: ContainerChild.ID) -> ContainerChild? {
        // Search through all spaces' children
        for space in spaces {
            let children = Containers.children(of: space)
            if let child = children.first(where: { $0.id == id }) {
                return child
            }
        }
        return nil
    }
    
    // MODIFY: handleDragBegan
    private func handleDragBegan(_ child: ContainerChild, at windowLoc: CGPoint) {
        drag.longPressActive = true
        let loc = drag.toSidebar(windowLoc)
        if let idx = children.firstIndex(where: { $0.id == child.id }) {
            drag.targetSpaceID = space.persistentModelID
            drag.targetIndex = idx
        }
        drag.begin(child: child, at: loc, height: layoutMetrics.rowHeight)
        // Use smooth drag manager for visual state
        smoothDragManager.beginDrag(id: child.id, at: windowLoc)
    }
    
    // MODIFY: handleDragChanged
    private func handleDragChanged(at windowLoc: CGPoint) {
        guard drag.isDragging else { return }
        drag.location = drag.toSidebar(windowLoc)
        drag.updateTarget(in: allSpaces)
        smoothDragManager.updateFingerPosition(windowLoc)
    }
    
    // MODIFY: handleDragEnded
    private func handleDragEnded() {
        drag.longPressActive = false
        guard drag.isDragging else { return }
        smoothDragManager.endDrag()
        commitDrop()
    }
}
```

### 2. `Struct/Views/Container Pane/SpaceSectionView.swift`

**Changes:**

1. Keep ghost row at full height, just make it transparent
2. Remove height collapse animation

```swift
@ViewBuilder
private func rowView(for child: ContainerChild) -> some View {
    let isGhosted = drag.dragging?.id == child.id
    // ... existing code ...
    
    ContainerRowView(/* ... */)
        // ... existing modifiers ...
        // CHANGE: Keep full height, just change opacity
        .opacity(isGhosted ? 0 : 1)
        .frame(height: nil)  // Keep natural height
        .animation(.spring(duration: 0.15, bounce: 0), value: isGhosted)
        .allowsHitTesting(!isGhosted)
}
```

### 3. `Struct/Views/Container Pane/ContainersSidebarView.swift` (Space Header)

**Changes:**

Update space header drag callbacks to use `SmoothDragManager`:

```swift
// MODIFY: handleSpaceDragBegan
private func handleSpaceDragBegan(_ space: Space, at windowLoc: CGPoint) {
    drag.longPressActive = true
    let loc = drag.toSidebar(windowLoc)
    if let idx = spaces.firstIndex(where: { $0.persistentModelID == space.persistentModelID }) {
        drag.spaceTargetIndex = idx
    }
    let h = drag.spaceHeaderFrames[space.persistentModelID]?.height ?? layoutMetrics.headerHeight
    drag.beginSpaceDrag(space: space, at: loc, headerHeight: h)
    // Use smooth drag manager for visual state (use space's persistentModelID as identifier)
    // Note: For space headers, we need to handle this differently since SmoothDragManager
    // expects ContainerChild.ID. Consider creating a separate manager for spaces or
    // using a generic ID type.
}

// MODIFY: handleSpaceDragEnded
private func handleSpaceDragEnded() {
    drag.longPressActive = false
    guard drag.isDraggingSpace else { return }
    // Note: Need to handle space drag ending separately
    // For now, keep existing behavior or extend SmoothDragManager
    commitSpaceDrop()
}
```

**Note:** Space header dragging may need separate handling since `SmoothDragManager` is designed for `ContainerChild.ID`. Consider either:
1. Creating a generic `SmoothDragManager<ItemID: Hashable>`
2. Using a separate `SmoothSpaceDragManager`
3. Using `AnyHashable` for the dragging ID

---

## Implementation Steps

### Phase 1: Create New Components (Non-Breaking)

1. Create `SmoothDragManager.swift`
2. Create `SmoothDragFloatingRow.swift`
3. Create `SmoothDropGap.swift`

These files can be created without affecting existing functionality.

### Phase 2: Integrate into ContainersSidebarView

1. Add `smoothDragManager` as `@State` in `ContainersSidebarView`
2. Replace `floatingCardOverlay` with `SmoothDragFloatingRow`
3. Update `handleDragBegan` to call `smoothDragManager.beginDrag()`
4. Update `handleDragChanged` to call `smoothDragManager.updateFingerPosition()`
5. Update `handleDragEnded` to call `smoothDragManager.endDrag()`
6. Add `findChild(by:)` helper method

### Phase 3: Modify SpaceSectionView

1. Change ghost row to opacity-only (no height collapse)
2. Update animation to match new timing

### Phase 4: Handle Space Header Dragging

1. Decide on approach for space header drag management
2. Implement appropriate solution
3. Update space header gesture callbacks

### Phase 5: Polish Animations

1. Fine-tune animation durations and values
2. Test on device
3. Adjust based on visual feedback

### Phase 6: Clean Up

1. Remove unused code from old system
2. Update comments and documentation
3. Final testing

---

## Animation Specifications

| Phase | Duration | Scale | Opacity | Curve |
|-------|----------|-------|---------|-------|
| Lift (drag start) | 0.15s | 1.0 → 1.05 | 1.0 → 0.85 | Spring (bounce: 0) |
| Drag (holding) | - | 1.05 | 0.85 | - |
| Drop (release) | 0.1s | 1.05 → 0.95 | 0.85 → 1.0 | Spring (bounce: 0.3) |
| Settle (final) | 0.15s | 0.95 → 1.0 | 1.0 | Spring (bounce: 0) |
| Ghost disappear | 0.15s | - | 1 → 0 | Spring (bounce: 0) |
| Drop gap insertion | 0.25s | 0.85 → 1 | 0 → 1 | Spring (bounce: 0.2) |

---

## Testing Checklist

- [ ] Long press triggers smooth lift animation
- [ ] Row scales to 1.05x and becomes slightly transparent
- [ ] Floating row follows finger smoothly
- [ ] Original row becomes invisible (not collapsed)
- [ ] Drop gap appears with smooth animation
- [ ] Other rows push aside smoothly
- [ ] Drop animation has subtle bounce
- [ ] Cancel drag returns row to normal
- [ ] Rapid successive drags work correctly
- [ ] Cross-space dragging works
- [ ] Space header dragging works (if implemented)
- [ ] Auto-scroll during drag works
- [ ] No visual glitches or jumps
- [ ] Haptic feedback feels appropriate

---

## Success Criteria

1. **No visible swap**: The row should appear to morph, not be replaced
2. **Smooth animations**: All transitions should use spring curves
3. **Consistent timing**: Animations should feel snappy but not jarring
4. **Visual continuity**: The dragged element should always be visible
5. **Natural physics**: Scale and opacity changes should feel physical

---

## Notes

- This plan assumes starting from the baseline state (before any smooth drag modifications)
- If starting from a different state, refer to `SmoothDragAndDropImplementationPlan.md` for Option B
- Space header dragging may require additional consideration for the ID type
- Test thoroughly on device as animations may look different on simulator