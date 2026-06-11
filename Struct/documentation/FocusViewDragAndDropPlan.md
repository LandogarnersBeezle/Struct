# Focus View Drag and Drop Implementation Plan

## Overview

This document outlines the implementation plan for adding drag-and-drop reordering functionality to the detail view (`ContainerFocusListView`). The implementation will mirror the proven architecture used in the sidebar, ensuring the same smooth, synchronized experience.

### Scope (Phase 1)

**Initial Implementation**: Reorder tasks only within the same parent group (unscheduled ↔ unscheduled, scheduled ↔ scheduled). No cross-group or cross-container dragging yet.

**Future Extension**: The architecture will be designed to support full flexibility for dragging tasks to any valid position across container and task section boundaries.

---

## Current Architecture Analysis

### Sidebar Implementation (Reference)

The sidebar uses a robust drag-and-drop system with these key components:

1. **`SidebarDragState`** - Observable class managing all drag state
2. **Preference Keys** - Collect row frames and viewport origin
3. **`draggableRowInteraction`** - UIKit gesture modifier for rows
4. **`SpaceSectionView`** - Manages slots (rows + drop gap) per section
5. **`DragFloatingCard`** - Visual feedback during drag
6. **`AutoScrollOverlay`** - Enables scrolling during drag

### Detail View Structure

The `ContainerFocusListView` displays content in groups:

```
ContainerFocusListView
├── Direct Items (Unscheduled)
│   └── Items without doDate, directly attached to container
├── Direct Items (Scheduled)
│   └── Items with doDate, directly attached to container
├── Task Sections
│   ├── Section 1
│   │   ├── Unscheduled Items
│   │   └── Scheduled Items
│   ├── Section 2
│   │   ├── Unscheduled Items
│   │   └── Scheduled Items
│   └── ...
└── Child Containers (Space only)
    └── Each with same structure as above
```

### Key Insight

Each "group" (unscheduled or scheduled) is a distinct logical unit. Tasks should only be reorderable within their current group in Phase 1.

---

## Implementation Plan

### Step 1: Create Group Identifier System

**File**: `Struct/Views/Components/DragAndDrop/FocusGroupIdentifier.swift`

```swift
import Foundation
import SwiftData

/// Uniquely identifies a group of items that can be reordered together.
/// This enum provides type-safe identification of drag-and-drop scopes.
enum FocusGroupIdentifier: Hashable {
    /// Direct items (not in a task section) without a doDate
    case directUnscheduled(parent: ContainerTarget)
    
    /// Direct items (not in a task section) with a doDate
    case directScheduled(parent: ContainerTarget)
    
    /// Items within a task section without a doDate
    case sectionUnscheduled(section: TaskSection)
    
    /// Items within a task section with a doDate
    case sectionScheduled(section: TaskSection)
}

extension FocusGroupIdentifier {
    /// Returns a human-readable description for debugging
    var debugDescription: String {
        switch self {
        case .directUnscheduled(let parent):
            return "direct-unscheduled(\(parent.title))"
        case .directScheduled(let parent):
            return "direct-scheduled(\(parent.title))"
        case .sectionUnscheduled(let section):
            return "section-unscheduled(\(section.title))"
        case .sectionScheduled(let section):
            return "section-scheduled(\(section.title))"
        }
    }
}
```

### Step 2: Create Preference Keys

**File**: `Struct/Views/Components/DragAndDrop/FocusViewPreferenceKeys.swift`

```swift
import SwiftUI
import SwiftData

/// Preference key for item row frames in the focus view coordinate space.
/// Each row reports its frame, which is collected by the scroll view.
struct FocusRowFrameKey: PreferenceKey {
    typealias Value = [Item.ID: CGRect]
    static var defaultValue: Value { [:] }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Preference key for the focus view viewport origin in window coordinates.
/// Used for coordinate conversion during drag operations.
struct FocusViewOriginKey: PreferenceKey {
    static var defaultValue: CGPoint { .zero }
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}
```

### Step 3: Create Focus View Drag State

**File**: `Struct/Views/Components/DragAndDrop/FocusViewDragState.swift`

```swift
import SwiftUI
import SwiftData

/// Observable drag state for the focus view (detail view).
/// Manages drag operations within a single group of items.
@Observable
final class FocusViewDragState {
    
    // MARK: - State
    
    /// The item currently being dragged; `nil` when idle.
    var dragging: Item? = nil
    
    /// The group identifier for the current drag operation.
    var groupIdentifier: FocusGroupIdentifier? = nil
    
    /// Current finger position in the focus view coordinate space.
    var location: CGPoint = .zero
    
    /// Every row's frame in the focus view coordinate space.
    var rowFrames: [Item.ID: CGRect] = [:]
    
    /// Insertion index within the current group.
    var targetIndex: Int = 0
    
    /// Height of the floating drag card.
    var cardHeight: CGFloat = 48
    
    /// `true` from the moment a long-press fires until the gesture ends.
    var longPressActive: Bool = false
    
    /// Origin of the focus view viewport in window coordinates.
    var viewportOriginInWindow: CGPoint = .zero
    
    /// Current vertical scroll offset, updated during auto-scroll.
    var scrollOffset: CGFloat = 0
    
    /// Keeps the floating card alive through its fade-out after a drop.
    private(set) var floatingCardItem: Item? = nil
    
    /// `true` during the same synchronous execution as `end()`, then reset.
    var justEndedDrag = false
    
    var isDragging: Bool { dragging != nil }
    
    // MARK: - Coordinate Conversion
    
    /// Converts a point in window coordinates to focus view coordinate space.
    func toViewport(_ windowPoint: CGPoint) -> CGPoint {
        CGPoint(x: windowPoint.x - viewportOriginInWindow.x,
                y: windowPoint.y - viewportOriginInWindow.y)
    }
    
    // MARK: - Lifecycle
    
    /// Begins a drag operation for an item within a specific group.
    func begin(item: Item, group: FocusGroupIdentifier, at point: CGPoint, height: CGFloat) {
        dragging = item
        groupIdentifier = group
        floatingCardItem = item
        location = point
        cardHeight = height
        
        // Pre-set target index to current position
        if let items = itemsForGroup(group),
           let idx = items.firstIndex(where: { $0.persistentModelID == item.persistentModelID }) {
            targetIndex = idx
        }
    }
    
    /// Updates the drop target based on current finger position.
    /// Only considers items within the same group.
    func updateTarget() {
        guard let group = groupIdentifier,
              let items = itemsForGroup(group) else { return }
        
        let y = location.y
        let filteredItems = items.filter { $0.persistentModelID != dragging?.persistentModelID }
        
        struct Candidate {
            let index: Int
            let dist: CGFloat
        }
        var best: Candidate?
        
        func consider(_ c: Candidate) {
            if best == nil || c.dist < best!.dist { best = c }
        }
        
        for (i, item) in filteredItems.enumerated() {
            guard let frame = rowFrames[item.persistentModelID] else { continue }
            let midY = frame.midY
            let insertIndex = y < midY ? i : i + 1
            consider(Candidate(index: insertIndex, dist: abs(midY - y)))
        }
        
        if let lastFrame = filteredItems.compactMap({ rowFrames[$0.persistentModelID] }).last {
            consider(Candidate(index: filteredItems.count, dist: abs(lastFrame.maxY - y)))
        }
        
        if let b = best {
            withAnimation(.spring(duration: 0.22, bounce: 0.3)) {
                targetIndex = b.index
            }
        }
    }
    
    /// Ends the drag operation with fade-out animation.
    func end() {
        longPressActive = false
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            dragging = nil
            groupIdentifier = nil
        }
        justEndedDrag = true
        DispatchQueue.main.async { [weak self] in
            withAnimation(.easeOut(duration: 0.18)) {
                self?.floatingCardItem = nil
            }
            self?.justEndedDrag = false
        }
    }
    
    /// Immediately resets all drag state without animation.
    func reset() {
        longPressActive = false
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            dragging = nil
            groupIdentifier = nil
            floatingCardItem = nil
        }
        justEndedDrag = false
    }
    
    // MARK: - Helper Methods
    
    /// Returns the items for a given group identifier.
    /// This is used to filter drop target candidates.
    private func itemsForGroup(_ group: FocusGroupIdentifier) -> [Item]? {
        // This will be set by the view model or container
        // For now, return nil - the actual implementation will inject this
        return nil
    }
    
    /// Sets the items provider for group lookups.
    /// Called by the view to provide current item lists.
    var itemsProvider: ((FocusGroupIdentifier) -> [Item]?)?
}
```

### Step 4: Create Focus Group View

**File**: `Struct/Views/Content Pane/FocusGroupView.swift`

```swift
import SwiftUI
import SwiftData

/// Wrapper view for a group of items (unscheduled or scheduled) with drag-and-drop support.
/// This view manages the slots (items + drop gap) and handles drag gestures.
struct FocusGroupView: View {
    let items: [Item]
    let groupIdentifier: FocusGroupIdentifier
    let layoutMetrics: LayoutMetrics
    let onItemTap: (Item) -> Void
    let onReorder: (Item, FocusGroupIdentifier, Int) -> Void
    
    @Environment(FocusViewDragState.self) private var drag
    @State private var saveError: DataError?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(slots) { slot in
                switch slot {
                case .item(let item):
                    let isGhosted = drag.dragging?.persistentModelID == item.persistentModelID
                    itemRow(for: item)
                        .padding(.bottom, isGhosted ? 0 : layoutMetrics.rowSpacing)
                case .gap:
                    dropGap
                        .padding(.bottom, layoutMetrics.rowSpacing)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                            removal: .opacity.animation(.easeOut(duration: layoutMetrics.cardFadeOutDuration))
                        ))
                }
            }
        }
        .animation(.spring(duration: layoutMetrics.dragSpringDuration, bounce: layoutMetrics.dragSpringBounce), 
                   value: slots.map(\.id))
    }
    
    // MARK: - Slots
    
    /// Display list: the dragged item is kept in the array (to preserve gesture)
    /// but collapsed to zero height. A gap is inserted at the drop position.
    private var slots: [FocusSlotItem] {
        var result = items.map(FocusSlotItem.item)
        
        if drag.isDragging, drag.groupIdentifier == groupIdentifier {
            let ghostPos = items.firstIndex { $0.persistentModelID == drag.dragging?.persistentModelID }
            let adjusted = ghostPos.map { drag.targetIndex > $0 ? drag.targetIndex + 1 : drag.targetIndex }
                         ?? drag.targetIndex
            let idx = max(0, min(adjusted, result.count))
            result.insert(.gap, at: idx)
        }
        return result
    }
    
    // MARK: - Item Row
    
    @ViewBuilder
    private func itemRow(for item: Item) -> some View {
        let isGhosted = drag.dragging?.persistentModelID == item.persistentModelID
        
        ItemRowView(item: item)
            .background(frameAnchor(for: item))
            .draggableRowInteraction(
                supportsSwipe: false,  // No swipe in focus view for now
                accessibilityLabel: item.title,
                onTap: { onItemTap(item) },
                onDragBegan: { handleDragBegan(item, at: $0) },
                onDragChanged: { handleDragChanged(at: $0) },
                onDragEnded: { handleDragEnded() }
            )
            .frame(height: isGhosted ? 0 : nil)
            .clipped()
            .allowsHitTesting(!isGhosted)
    }
    
    // MARK: - Drop Gap
    
    private var dropGap: some View {
        RoundedRectangle(cornerRadius: layoutMetrics.dropGapCornerRadius, style: .continuous)
            .fill(Color.green.opacity(0.15))
            .frame(height: drag.cardHeight)
            .padding(.horizontal, 4)
    }
    
    // MARK: - Frame Reporting
    
    private func frameAnchor(for item: Item) -> some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named("focusview"))
            Color.clear
                .preference(key: FocusRowFrameKey.self, value: [item.persistentModelID: frame])
                .onChange(of: geo.size.height, initial: true) { _, h in
                    if !drag.isDragging { drag.cardHeight = h }
                }
        }
    }
    
    // MARK: - Gesture Callbacks
    
    private func handleDragBegan(_ item: Item, at windowLoc: CGPoint) {
        drag.longPressActive = true
        let loc = drag.toViewport(windowLoc)
        drag.begin(item: item, group: groupIdentifier, at: loc, height: layoutMetrics.rowHeight)
    }
    
    private func handleDragChanged(at windowLoc: CGPoint) {
        guard drag.isDragging else { return }
        drag.location = drag.toViewport(windowLoc)
        
        // Only update target if still in the same group
        if drag.groupIdentifier == groupIdentifier {
            drag.updateTarget()
        }
        // If dragged outside the group, no drop target is shown
    }
    
    private func handleDragEnded() {
        drag.longPressActive = false
        guard drag.isDragging, drag.groupIdentifier == groupIdentifier else { return }
        commitDrop()
    }
    
    // MARK: - Commit Drop
    
    private func commitDrop() {
        defer { drag.end() }
        
        guard let dragging = drag.dragging else { return }
        onReorder(dragging, groupIdentifier, drag.targetIndex)
    }
}

// MARK: - Slot Item

private enum FocusSlotItem: Identifiable {
    case item(Item)
    case gap
    
    var id: AnyHashable {
        switch self {
        case .item(let item): AnyHashable(item.persistentModelID)
        case .gap: AnyHashable("gap")
        }
    }
}
```

### Step 5: Create Floating Card

**File**: `Struct/Views/Content Pane/FocusFloatingCard.swift`

```swift
import SwiftUI
import SwiftData

/// Floating drag card for items in the focus view.
/// Matches the visual style of the sidebar's floating cards.
struct FocusFloatingCard: View {
    let item: Item
    let layoutMetrics: LayoutMetrics
    
    var body: some View {
        ItemRowView(item: item)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: layoutMetrics.cardCornerRadius, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(layoutMetrics.cardShadowOpacity),
                            radius: layoutMetrics.cardShadowRadius, y: 6)
                    .opacity(layoutMetrics.cardOpacity)
            )
            .transition(.opacity)
    }
}
```

### Step 6: Modify ItemRowView

**File**: `Struct/Views/Content Pane/ItemRowView.swift`

Add frame reporting capability:

```swift
// Add this modifier when used in focus view:
// .background {
//     GeometryReader { geo in
//         Color.clear
//             .preference(key: FocusRowFrameKey.self, 
//                        value: [item.persistentModelID: geo.frame(in: .named("focusview"))])
//     }
// }
```

### Step 7: Integrate into ContainerFocusListView

**File**: `Struct/Views/Content Pane/ContainerFocusListView.swift`

Key changes:

1. Add drag state:
```swift
@State private var drag = FocusViewDragState()
```

2. Configure items provider:
```swift
.onAppear {
    drag.itemsProvider = { [weak self] group in
        self?.itemsForGroup(group)
    }
}
```

3. Wrap groups in `FocusGroupView`:
```swift
// Direct items - Unscheduled
if !groupedContent.directItems.unscheduled.isEmpty {
    Section(header: sectionHeader("Unscheduled")) {
        FocusGroupView(
            items: groupedContent.directItems.unscheduled,
            groupIdentifier: .directUnscheduled(parent: target),
            layoutMetrics: layoutMetrics,
            onItemTap: handleItemTap,
            onReorder: handleReorder
        )
        .padding(.horizontal, 16)
    }
}
```

4. Add coordinate space and preference collection:
```swift
ScrollView {
    // content
}
.coordinateSpace(.named("focusview"))
.onPreferenceChange(FocusRowFrameKey.self) { drag.rowFrames = $0 }
.onPreferenceChange(FocusViewOriginKey.self) { drag.viewportOriginInWindow = $0 }
.scrollDisabled(drag.longPressActive || drag.isDragging)
.environment(drag)
```

5. Add overlays:
```swift
ZStack {
    scrollContent
    floatingCardOverlay
}
.overlay {
    AutoScrollOverlay(
        dragState: drag,
        contentHeight: { estimateContentHeight() }
    )
}
```

### Step 8: Add Data Model Methods

**File**: `Struct/Models/Item.swift`

```swift
extension Item {
    /// Reorders this item within a group to a new index.
    /// Updates sortIndex values for all items in the group.
    func reorder(within group: FocusGroupIdentifier, to index: Int, context: ModelContext) {
        guard let items = itemsForGroup(group, context: context) else { return }
        
        // Remove this item from the list
        var reordered = items.filter { $0.persistentModelID != self.persistentModelID }
        
        // Insert at new position
        let clampedIndex = max(0, min(index, reordered.count))
        reordered.insert(self, at: clampedIndex)
        
        // Update sort indices
        for (i, item) in reordered.enumerated() {
            item.sortIndex = i
        }
        
        touch()
    }
    
    /// Returns all items in the same group.
    private func itemsForGroup(_ group: FocusGroupIdentifier, context: ModelContext) -> [Item]? {
        switch group {
        case .directUnscheduled(let parent):
            return parent.items.filter { $0.taskSection == nil && $0.doDate == nil }
        case .directScheduled(let parent):
            return parent.items.filter { $0.taskSection == nil && $0.doDate != nil }
        case .sectionUnscheduled(let section):
            return Array(section.items).filter { $0.doDate == nil }
        case .sectionScheduled(let section):
            return Array(section.items).filter { $0.doDate != nil }
        }
    }
}
```

---

## Visual Design Specifications

### Drop Gap
- **Color**: Green with 15% opacity (`Color.green.opacity(0.15)`)
- **Corner Radius**: 8 points
- **Height**: Matches the dragged item's row height
- **Horizontal Padding**: 4 points on each side
- **Animation**: Spring with 0.22s duration, 0.3 bounce on insertion; ease-out 0.18s on removal

### Floating Card
- **Background**: System background color
- **Corner Radius**: 10 points
- **Shadow**: Black, 12 points radius, 18% opacity, 6 points y-offset
- **Opacity**: 50%
- **Position**: Centered horizontally, follows finger vertically

### Ghost Row
- **Height**: 0 points (collapsed)
- **Visibility**: Hidden (allowsHitTesting = false)
- **Purpose**: Preserves gesture recognizer during drag

---

## Animation Specifications

| Animation | Duration | Spring Bounce | Curve |
|-----------|----------|---------------|-------|
| Drag Start (row collapse) | 0.22s | 0 | Spring |
| Gap Insertion | 0.22s | 0.3 | Spring |
| Gap Removal | 0.18s | - | Ease Out |
| Card Fade Out | 0.18s | - | Ease Out |
| Row Push Aside | 0.22s | 0 | Spring |

---

## Edge Cases & Error Handling

### 1. Dragging Outside Group Boundaries
- **Behavior**: No drop gap appears
- **Visual**: Floating card continues to follow finger
- **On Release**: Drag is cancelled, item returns to original position
- **Implementation**: `handleDragChanged` only calls `updateTarget()` when `drag.groupIdentifier == groupIdentifier`

### 2. Empty Groups
- **Behavior**: Can still drop items (gap appears at position 0)
- **Visual**: Gap appears at the top of the empty group area

### 3. Single Item Groups
- **Behavior**: Can reorder (effectively no change) or drag out (not allowed in Phase 1)

### 4. Scroll View Interaction
- **Behavior**: Scroll is disabled during drag (`scrollDisabled`)
- **Auto-scroll**: Enabled via `AutoScrollOverlay` when near edges

### 5. Rapid Successive Drags
- **Behavior**: Previous drag must complete before new one starts
- **Implementation**: `justEndedDrag` flag prevents immediate re-trigger

---

## Extension Points for Future Cross-Group Dragging

The architecture supports future expansion:

1. **Group Identifier**: Already tracks source group; can compare with target group
2. **Drag State**: Can store both `sourceGroup` and `targetGroup`
3. **Drop Validation**: Can be enhanced to allow specific cross-group moves
4. **Data Model**: `Item.setParent()` already supports moving between parents
5. **Visual Feedback**: Can show different gap colors for cross-group moves

### Future Implementation Steps

1. Modify `updateTarget()` to consider items in other groups
2. Add cross-group validation logic
3. Update `commitDrop()` to handle parent changes
4. Add visual differentiation for cross-group drops
5. Implement proper sort index management across groups

---

## Files to Create

| File | Purpose |
|------|---------|
| `FocusGroupIdentifier.swift` | Group identification enum |
| `FocusViewPreferenceKeys.swift` | Preference keys for geometry |
| `FocusViewDragState.swift` | Drag state manager |
| `FocusGroupView.swift` | Group wrapper with drag support |
| `FocusFloatingCard.swift` | Floating card for items |

## Files to Modify

| File | Changes |
|------|---------|
| `ItemRowView.swift` | Add frame reporting capability |
| `ContainerFocusListView.swift` | Integrate drag system |
| `Item.swift` | Add reordering method |
| `ContainerFocusViewModel.swift` | Add group item lookup |

---

## Testing Checklist

- [ ] Drag item within unscheduled group
- [ ] Drag item within scheduled group
- [ ] Drag item within task section unscheduled
- [ ] Drag item within task section scheduled
- [ ] Attempt to drag to different group (should show no gap)
- [ ] Drag with auto-scroll enabled
- [ ] Drag with empty groups
- [ ] Drag with single-item groups
- [ ] Cancel drag by releasing outside group
- [ ] Rapid successive drags
- [ ] Verify sort indices remain contiguous
- [ ] Verify no layout shifts during drag
- [ ] Verify floating card follows finger accurately
- [ ] Verify drop gap appears at correct position
- [ ] Verify ghost row collapses properly

---

## Success Criteria

1. **Visual Synchronization**: No offsets between finger position and floating card
2. **Smooth Animations**: Spring animations feel natural, no jarring movements
3. **Accurate Drop Targets**: Gap appears exactly where item will land
4. **No Layout Shifts**: Other items smoothly push aside without jumping
5. **Clear Boundaries**: No drop targets shown in forbidden groups
6. **Consistent UX**: Matches sidebar's drag-and-drop quality