# Space Reordering Implementation Summary

## Overview
Implemented drag-and-drop reordering for spaces in the sidebar. When a space header is long-pressed, all space sections collapse their children (lists/projects), leaving only the headers visible. The user can then drag the space to the desired position, and on drop, the spaces are reordered.

## Files Modified/Created

### 1. `ContainerDragData.swift`
- Added `SpaceDragData` struct for transferring space identity during drag operations
- Added `UTType.spaceDrag` custom type for the drag operation

### 2. `GenericSwipeSelection.swift`
- Added `SidebarCollapseState` class to track which space is being dragged
- This shared observable state triggers the collapse of all other spaces when a drag starts

### 3. `SpaceReorderDropDelegate.swift` (NEW)
- Created `SpaceFrame` and `SpaceFramePreferenceKey` to track space header frames
- Implemented `SpaceInsertionLineDropDelegate` to handle drop events and insertion line visualization
- Similar pattern to existing `InsertionLineDropDelegate` used for list/project reordering

### 4. `Space.swift`
- Added `Space.moveSpace(_:to:context:)` static method to handle reordering
- Fetches all spaces, removes the moved space, inserts at new index, and re-indexes all spaces sequentially

### 5. `ContainersSidebarView.swift`
- Added state variables: `spaceInsertionLineY`, `spaceFrames`, `sidebarCoordName`
- Modified `scrollContent` to:
  - Collapse children when a space is being dragged (opacity = 0 for non-dragged spaces)
  - Track space header frames via `SpaceFramePreferenceKey`
  - Show green insertion line overlay during drag
  - Handle drop via `SpaceInsertionLineDropDelegate`
- Modified `spaceHeader` to:
  - Track its frame for insertion line calculation
  - Make the header draggable with `.draggable(SpaceDragData)`
  - Set collapse state when drag preview is created
- Added `handleSpaceReorderDrop` method to compute insertion index and perform reorder

## How It Works

1. **Long Press**: User long-presses a space header
   - SwiftUI's `.draggable` modifier activates
   - The drag preview is created, which sets `SidebarCollapseState.shared.draggingSpace`
   - All other spaces' children collapse (opacity = 0)

2. **Drag**: User drags the space
   - The `SpaceInsertionLineDropDelegate` tracks the finger position
   - A green insertion line appears between space headers indicating where the space will be dropped
   - The line position is calculated based on the finger's Y coordinate relative to space header frames

3. **Drop**: User releases the space
   - The drop delegate decodes the `SpaceDragData` to identify the dragged space
   - `handleSpaceReorderDrop` computes the insertion index from the line position
   - `Space.moveSpace` reorders the spaces by updating their `sortIndex` values
   - The collapse state is reset, and all spaces expand back to their original state

## Key Design Decisions

- **Reuse Existing Patterns**: The implementation closely mirrors the existing list/project drag-and-drop system for consistency
- **Collapse on Drag**: Children collapse automatically when a space is dragged to provide clear visual feedback and prevent accidental drops on child items
- **Insertion Line**: A green line indicates the drop target, matching the existing UX for list/project reordering
- **Model-Level Reordering**: The `Space.moveSpace` method handles all the re-indexing logic, keeping the view layer simple
- **Animation**: Spring animation on reorder provides smooth visual feedback

## Testing Considerations

- Test with multiple spaces (2+)
- Test dragging a space to the top, middle, and bottom positions
- Test that children collapse/expand correctly
- Test that the insertion line appears in the correct position
- Test that the reorder persists across app launches (via SwiftData)
- Test that swipe-to-delete still works alongside the new drag functionality
- Test on both iPhone and iPad

## Future Enhancements

- Add haptic feedback when crossing space boundaries during drag
- Add visual indicator (e.g., highlight) on the dragged space header
- Consider adding a small delay before collapsing children to allow for accidental quick taps
- Add accessibility support for reordering via VoiceOver