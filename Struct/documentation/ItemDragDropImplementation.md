# Item Drag and Drop Implementation - Phase 1 (Intra-Group Reordering)

## Overview

Successfully implemented drag-and-drop functionality for reordering unscheduled tasks within their current unscheduled group in the detail view (ContainerFocusListView). This implementation mirrors the smooth drag-and-drop experience from the sidebar but is tailored for item rows.

## Files Created

### 1. `Struct/Views/Components/DragAndDrop/ItemDragState.swift`
A new observable class that manages the drag state for items:
- Tracks the currently dragged item and its group context
- Manages finger position and target insertion index
- Handles smooth lift/drop animations (scale and opacity)
- Provides coordinate conversion from window to content view space
- Enforces intra-group constraint via `ItemGroupContext`

**Key Features:**
- `ItemGroupContext` enum to identify which unscheduled group the drag is confined to:
  - `.directUnscheduled(ContainerTarget)` - for direct unscheduled items in a container
  - `.childContainerUnscheduled(ContainerChild)` - for unscheduled items in child containers
  - `.sectionUnscheduled(TaskSection)` - for unscheduled items within a TaskSection
- Smooth animations: lift (scale to 1.05, opacity to 0.85), drop (scale to 0.95 with bounce)
- Haptic feedback on drag start

### 2. `Struct/Views/Content Pane/ItemFloatingRow.swift`
A floating row view that follows the finger during drag:
- Displays the dragged item with full styling (title, dates, notes, completion state)
- Applies scale and opacity from ItemDragState
- Uses subtle shadow for depth perception
- Non-interactive overlay that follows finger position

## Files Modified

### 1. `Struct/Views/Content Pane/ItemRowView.swift`
- Added `groupContext` and `isDragEnabled` parameters
- Integrated `ItemRowDragModifier` for drag gesture handling
- Added frame reporting via `ItemRowFrameKey` preference key
- Applied ghost row styling (reduced opacity) when being dragged
- Only unscheduled items (no doDate) are draggable

### 2. `Struct/Views/Content Pane/ContainerFocusListView.swift`
- Added `@State private var itemDragState = ItemDragState()`
- Injected ItemDragState into environment
- Added coordinate space "ItemContentView" for frame calculations
- Added floating row overlay when dragging
- Implemented `getUnscheduledItems(for:)` and `getAllUnscheduledItems(for:)` helpers
- Implemented `performReorder(item:toIndex:)` to update sortIndex values
- Added onChange handlers for drag position updates and reordering

## How It Works

### User Experience

1. **Initiate Drag**: Long-press (1 second) on an unscheduled task row
2. **Lift Animation**: Row scales up to 105% and fades to 85% opacity with haptic feedback
3. **Drag**: A floating copy follows the finger while the original row becomes semi-transparent
4. **Drop Target**: As you move, the system calculates the insertion point within the same unscheduled group
5. **Drop**: Release to drop - the row scales down with a bounce effect and settles
6. **Reorder**: The item's sortIndex is updated and all items in the group are re-sorted

### Technical Flow

```
User long-presses row
    ↓
ItemRowDragModifier detects gesture
    ↓
ItemDragState.beginDrag() - stores item, context, starts animations
    ↓
ItemFloatingRow appears and follows finger
    ↓
Original row becomes ghost (opacity 0.3)
    ↓
On location change: updateTargetIndex() calculates drop position
    ↓
User releases
    ↓
ItemDragState.endDrag() - plays drop animation
    ↓
performReorder() updates sortIndex values and saves
```

### Constraints

- **Intra-group only**: Items can only be reordered within their current unscheduled group
- **Unscheduled only**: Only items without a doDate can be dragged
- **Same section**: Items in TaskSections stay within their section
- **Same container**: Child container items stay within their container

## Key Implementation Details

### Group Context Tracking
Each drag operation knows its group context, preventing cross-group drags:
```swift
enum ItemGroupContext: Equatable, Hashable {
    case directUnscheduled(ContainerTarget)
    case childContainerUnscheduled(ContainerChild)
    case sectionUnscheduled(TaskSection)
}
```

### SortIndex Recalculation
When an item is dropped:
1. Get all unscheduled items in the group (sorted by sortIndex)
2. Remove the dragged item from its current position
3. Insert at the new position (clamped to valid range)
4. Reassign sortIndex values (0, 1, 2, ...)
5. Save the model context

### Coordinate System
- Frame tracking uses `ItemContentView` named coordinate space
- Finger position tracked in window coordinates
- Conversion via `contentOriginInWindow` for accurate drop target calculation

## Future Enhancements (Phase 2)

The architecture supports future expansion to:
- Cross-group reordering (move items between different unscheduled groups)
- Cross-section reordering (move items between TaskSections)
- Cross-container reordering (move items between Lists/Projects)
- Visual feedback for valid/invalid drop zones
- Auto-scroll when dragging near edges
- Drag multiple items at once

## Testing Recommendations

1. **Basic Reorder**: Drag items within the same unscheduled group
2. **Multiple Groups**: Verify items can't be dragged between groups
3. **Scheduled Items**: Confirm scheduled items (with doDate) are not draggable
4. **Sections**: Test reordering within TaskSections
5. **Child Containers**: Test reordering in Space view's child containers
6. **Edge Cases**: First/last items, single-item groups, empty groups
7. **Performance**: Test with many items to ensure smooth animations
8. **Persistence**: Verify sortIndex changes persist across app launches

## Known Limitations

- No auto-scroll when dragging near top/bottom of scroll view
- No visual indicator of drop position (gap insertion) during drag
- Ghost row doesn't collapse to maintain layout stability
- Drop target calculation may be slightly off during fast drags

## Conclusion

This implementation provides a solid foundation for item reordering with smooth animations and proper data persistence. The intra-group constraint ensures data integrity while the architecture supports future expansion to more flexible dragging scenarios.