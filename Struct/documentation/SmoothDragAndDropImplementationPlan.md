# Things 3-Like Smooth Drag-and-Drop Implementation Plan

## Overview

This document outlines the re-architecture needed to achieve Things 3-level smooth drag-and-drop transitions in the sidebar. The key insight is that we must eliminate the separate floating card and instead make the original row itself "float" above the layout during drag.

---

## Option A: Implementation from Original Baseline (Recommended)

See: [`SmoothDragAndDropImplementationPlan_FromBaseline.md`](./SmoothDragAndDropImplementationPlan_FromBaseline.md)

This is the recommended approach - revert to the git state before any smooth drag modifications and implement the new system from scratch. This provides the cleanest implementation path.

---

## Option B: Implementation from Current State

This document describes how to implement the smooth drag system starting from the **current state** (after the smooth drag modifications have been applied).

### Current State Summary

The current codebase already has:
- `SidebarDragState` with `dragScale`, `dragOpacity`, `animateLift()`, `animateDrop()` methods
- Smooth animations on ghost row collapse
- Enhanced floating card animations
- `SmoothDragInteractionModifier.swift` (partially implemented)

### Files to Create

#### 1. `Struct/Views/Components/DragAndDrop/SmoothDragManager.swift`

A new centralized manager that coordinates the visual state:

```swift
import SwiftUI
import SwiftData

/// Central manager for smooth drag-and-drop operations.
@Observable
final class SmoothDragManager {
    var draggingID: ContainerChild.ID?
    var fingerPosition: CGPoint = .zero
    var dragScale: CGFloat = 1.0
    var dragOpacity: CGFloat = 1.0
    var isDragging: Bool { draggingID != nil }
    
    let liftScale: CGFloat = 1.05
    let liftOpacity: CGFloat = 0.85
    let liftDuration: CGFloat = 0.15
    let dropDuration: CGFloat = 0.1
    
    func beginDrag(id: ContainerChild.ID, at position: CGPoint) {
        draggingID = id
        fingerPosition = position
        withAnimation(.spring(duration: liftDuration, bounce: 0)) {
            dragScale = liftScale
            dragOpacity = liftOpacity
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    func updateFingerPosition(_ position: CGPoint) {
        fingerPosition = position
    }
    
    func endDrag() {
        withAnimation(.spring(duration: dropDuration, bounce: 0.3)) {
            dragScale = 0.95
            dragOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dropDuration) { [weak self] in
            withAnimation(.spring(duration: 0.15, bounce: 0)) {
                self?.dragScale = 1.0
                self?.dragOpacity = 1.0
            }
            self?.draggingID = nil
        }
    }
    
    func cancelDrag() {
        withAnimation(.spring(duration: 0.2, bounce: 0)) {
            dragScale = 1.0
            dragOpacity = 1.0
        }
        draggingID = nil
    }
}
```

#### 2. `Struct/Views/Container Pane/SmoothDragFloatingRow.swift`

A floating row that follows the finger:

```swift
import SwiftUI

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
```

### Files to Modify

#### 1. `Struct/Views/Container Pane/ContainersSidebarView.swift`

**Changes:**
- Add `SmoothDragManager` as `@State`
- Replace `floatingCardOverlay` with `SmoothDragFloatingRow`
- Update gesture callbacks to use `SmoothDragManager`

```swift
struct ContainersSidebarView: View {
    // ... existing properties ...
    
    // ADD: New smooth drag manager
    @State private var smoothDragManager = SmoothDragManager()
    
    // MODIFY: Replace floatingCardOverlay
    @ViewBuilder
    private var floatingCardOverlay: some View {
        if let draggingID = smoothDragManager.draggingID,
           let child = findChild(by: draggingID) {
            SmoothDragFloatingRow(
                child: child,
                position: smoothDragManager.fingerPosition,
                scale: smoothDragManager.dragScale,
                opacity: smoothDragManager.dragOpacity,
                isVisible: smoothDragManager.isDragging
            )
        }
    }
    
    // MODIFY: Update handleDragBegan
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
    
    // MODIFY: Update handleDragChanged
    private func handleDragChanged(at windowLoc: CGPoint) {
        guard drag.isDragging else { return }
        drag.location = drag.toSidebar(windowLoc)
        drag.updateTarget(in: allSpaces)
        smoothDragManager.updateFingerPosition(windowLoc)
    }
    
    // MODIFY: Update handleDragEnded
    private func handleDragEnded() {
        drag.longPressActive = false
        guard drag.isDragging else { return }
        smoothDragManager.endDrag()
        commitDrop()
    }
    
    // ADD: Helper to find child by ID
    private func findChild(by id: ContainerChild.ID) -> ContainerChild? {
        children.first { $0.id == id }
    }
}
```

#### 2. `Struct/Views/Container Pane/SpaceSectionView.swift`

**Changes:**
- Keep row at full height, just change opacity (don't collapse)
- Coordinate with `SmoothDragManager` for visual state

```swift
@ViewBuilder
private func rowView(for child: ContainerChild) -> some View {
    let isGhosted = drag.dragging?.id == child.id
    let isCurrentlyDragging = drag.isDragging && drag.dragging?.id == child.id
    // ... existing code ...
    
    ContainerRowView(/* ... */)
        // ... existing modifiers ...
        // CHANGE: Keep full height, just change opacity
        .opacity(isGhosted ? 0 : (isCurrentlyDragging ? drag.dragOpacity : 1.0))
        .frame(height: nil)  // Keep natural height
        .animation(.spring(duration: 0.15, bounce: 0), value: isGhosted)
        .allowsHitTesting(!isGhosted)
}
```

#### 3. `Struct/Views/Container Pane/ContainersSidebarView.swift` (Space Header)

**Changes:**
- Update space header drag callbacks to use `SmoothDragManager`

```swift
// MODIFY: Update handleSpaceDragBegan
private func handleSpaceDragBegan(_ space: Space, at windowLoc: CGPoint) {
    drag.longPressActive = true
    let loc = drag.toSidebar(windowLoc)
    if let idx = spaces.firstIndex(where: { $0.persistentModelID == space.persistentModelID }) {
        drag.spaceTargetIndex = idx
    }
    let h = drag.spaceHeaderFrames[space.persistentModelID]?.height ?? layoutMetrics.headerHeight
    drag.beginSpaceDrag(space: space, at: loc, headerHeight: h)
    // Use smooth drag manager for visual state
    smoothDragManager.beginDrag(id: /* space ID */, at: windowLoc)
}

// MODIFY: Update handleSpaceDragEnded
private func handleSpaceDragEnded() {
    drag.longPressActive = false
    guard drag.isDraggingSpace else { return }
    smoothDragManager.endDrag()
    commitSpaceDrop()
}
```

### Implementation Steps

1. **Create `SmoothDragManager.swift`**
2. **Create `SmoothDragFloatingRow.swift`**
3. **Modify `ContainersSidebarView.swift`**:
   - Add `smoothDragManager` state
   - Replace `floatingCardOverlay`
   - Update gesture callbacks
4. **Modify `SpaceSectionView.swift`**:
   - Change ghost row to opacity-only (no height collapse)
5. **Test and refine animations**
6. **Remove unused code** (old `dragScale`/`dragOpacity` from `SidebarDragState`)

### Key Differences from Baseline Implementation

| Aspect | From Current State | From Baseline |
|--------|-------------------|---------------|
| Starting point | Has partial smooth drag code | Clean slate |
| `SidebarDragState` | Already has `dragScale`/`dragOpacity` | No visual state properties |
| Ghost row | Already animates collapse | Collapses instantly |
| Floating card | Already has smooth animations | Basic fade transition |
| Migration effort | Medium (modify existing) | Low (create new) |

### Risks

1. **Conflicting state**: The current `SidebarDragState` has `dragScale`/`dragOpacity` that may conflict with `SmoothDragManager`
2. **Animation timing**: Existing animations may need to be disabled to avoid conflicts
3. **Testing complexity**: More edge cases due to partial existing implementation

---

## Animation Specifications (Both Options)

| Phase | Duration | Scale | Opacity | Curve |
|-------|----------|-------|---------|-------|
| Lift (drag start) | 0.15s | 1.0 → 1.05 | 1.0 → 0.85 | Spring (bounce: 0) |
| Drag (holding) | - | 1.05 | 0.85 | - |
| Drop (release) | 0.1s | 1.05 → 0.95 | 0.85 → 1.0 | Spring (bounce: 0.3) |
| Settle (final) | 0.15s | 0.95 → 1.0 | 1.0 | Spring (bounce: 0) |
| Ghost disappear | 0.15s | - | 1 → 0 | Spring (bounce: 0) |
| Drop gap insertion | 0.25s | 0.85 → 1 | 0 → 1 | Spring (bounce: 0.2) |

---

## Success Criteria (Both Options)

1. **No visible swap**: The row should appear to morph, not be replaced
2. **Smooth animations**: All transitions should use spring curves
3. **Consistent timing**: Animations should feel snappy but not jarring
4. **Visual continuity**: The dragged element should always be visible
5. **Natural physics**: Scale and opacity changes should feel physical

---

## Recommendation

**Option A (From Baseline) is recommended** because:
- Cleaner implementation with no conflicting code
- Easier to test and debug
- No risk of animation conflicts
- Clear separation between old and new systems

To use Option A, revert to the git state before smooth drag modifications and follow the detailed plan in `SmoothDragAndDropImplementationPlan_FromBaseline.md`.