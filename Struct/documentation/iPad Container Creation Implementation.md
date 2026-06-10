# iPad Container Creation Implementation Plan

## Overview

Adapt the container creation workflow for iPad's split-view layout by:
1. Removing the plus button from the narrow sidebar on iPad
2. Adding a "+ Container" button to the detail view's existing button group
3. Showing the container creation card as an overlay in the detail view

## Problem

The current container creation card (`ContainerCreationCardView`) appears as an overlay in the sidebar. On iPad, the sidebar is only 300pt wide, making the card too cramped and unusable.

## Solution

Move the container creation functionality to the detail view on iPad, where there is ample space for the card to display properly.

## Architecture

### Components to Modify

1. **`ContainersSidebarView.swift`**
   - Hide the bottom-right overlay (plus/delete button) on iPad
   - Use `@Environment(\.horizontalSizeClass)` to detect device type

2. **`ContainerFocusView.swift`**
   - Add "+ Container" button to the existing button group in the top-right corner
   - Add state to show/hide the container creation card overlay
   - Display `ContainerCreationCardView` centered in the detail area

## Implementation Details

### 1. Hide Plus Button in Sidebar on iPad

In `ContainersSidebarView.swift`, wrap the bottom-right overlay in a conditional:

```swift
.overlay(alignment: .bottomTrailing) {
    // Only show on iPhone (compact horizontal size class)
    if horizontalSizeClass == .compact {
        Group {
            if swipeSelection.active == nil && !showCreationCard && !hidePlusButton {
                SidebarAddButton {
                    showCreationCardAnimated()
                }
            } else if swipeSelection.active != nil {
                ContainerDeleteButton(
                    onDelete: handleDelete
                )
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: swipeSelection.active == nil)
    }
}
```

Add the environment property at the top of the struct:

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass
```

### 2. Add "+ Container" Button to Detail View

In `ContainerFocusView.swift`, modify the top-right button group:

**Current state:**
```swift
.toolbar {
    ToolbarItemGroup(placement: .topBarTrailing) {
        HStack(spacing: 12) {
            Button(action: { showTaskCreationCard = true }) {
                Label("Task", systemImage: "plus")
            }
            Button(action: { showSectionCreationCard = true }) {
                Label("Section", systemImage: "plus")
            }
        }
        .buttonStyle(.bordered)
    }
}
```

**Modified:**
```swift
.toolbar {
    ToolbarItemGroup(placement: .topBarTrailing) {
        HStack(spacing: 12) {
            // Only show on iPad (regular horizontal size class)
            if horizontalSizeClass == .regular {
                Button(action: { showContainerCreationCard = true }) {
                    Label("Container", systemImage: "plus")
                }
            }
            
            Button(action: { showTaskCreationCard = true }) {
                Label("Task", systemImage: "plus")
            }
            Button(action: { showSectionCreationCard = true }) {
                Label("Section", systemImage: "plus")
            }
        }
        .buttonStyle(.bordered)
    }
}
```

Add the necessary state and environment properties:

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass
@State private var showContainerCreationCard = false
```

### 3. Show Container Creation Card in Detail View

Add an overlay to `ContainerFocusView` that displays the creation card when active:

```swift
.overlay {
    if showContainerCreationCard {
        ZStack {
            // Invisible hit-testing layer for dismissing on background tap
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    showContainerCreationCard = false
                }
            
            // Container creation card centered in detail view
            ContainerCreationCardView(
                onCancel: {
                    showContainerCreationCard = false
                },
                onSave: {
                    showContainerCreationCard = false
                }
            )
            .transition(.scale.combined(with: .opacity))
        }
        .transition(.opacity)
        .zIndex(1000)
    }
}
```

### 4. Reuse Existing ContainerCreationCardView

The existing `ContainerCreationCardView` can be reused as-is. It already:
- Handles Space, List, and Project creation
- Shows type selector buttons
- Has proper validation and error handling
- Uses appropriate animations for presentation/dismissal

No modifications to `ContainerCreationCardView.swift` are needed.

## Files to Modify

1. **`Struct/Views/Container Pane/ContainersSidebarView.swift`**
   - Add `@Environment(\.horizontalSizeClass)`
   - Wrap bottom-right overlay in `if horizontalSizeClass == .compact`

2. **`Struct/Views/Content Pane/ContainerFocusView.swift`**
   - Add `@Environment(\.horizontalSizeClass)`
   - Add `@State private var showContainerCreationCard = false`
   - Add "+ Container" button to toolbar (iPad only)
   - Add overlay for container creation card

## Behavior Summary

### iPhone (Compact Horizontal Size Class)
- Plus button visible in bottom-right of sidebar
- Container creation card appears as sidebar overlay
- No changes to existing behavior

### iPad (Regular Horizontal Size Class)
- No plus button in sidebar
- "+ Container" button in detail view toolbar (left of "+ Task" and "+ Section")
- Container creation card appears centered in detail view
- Card dismisses on background tap, Cancel, or Save

## Animation Details

- Card presentation: `.scale.combined(with: .opacity)` - scales up from 90% while fading in
- Card dismissal: Same animation in reverse
- Duration: Default SwiftUI animation (0.35s)

## Z-Index Layering

- Main content: default (0)
- Container creation card overlay: 1000
- Task creation card: existing value (likely similar)
- Section creation card: existing value (likely similar)

## Testing Checklist

### iPad
- [ ] No plus button visible in sidebar
- [ ] "+ Container" button visible in detail view toolbar
- [ ] Tapping "+ Container" shows creation card centered in detail view
- [ ] Card has sufficient space and is not cramped
- [ ] Background tap dismisses card
- [ ] Cancel button dismisses card
- [ ] Save button creates container and dismisses card
- [ ] All three container types (Space, List, Project) work correctly

### iPhone
- [ ] Plus button still visible in sidebar
- [ ] Container creation card still appears as sidebar overlay
- [ ] No regression in existing behavior

## Future Considerations

1. **Unified Card Presentation**: Consider creating a reusable "centered card overlay" component that can be used for all creation cards (container, task, section) across both iPhone and iPad.

2. **Popover on iPad**: For even better iPad UX, consider showing the container creation card as a popover anchored to the "+ Container" button instead of a centered overlay.

3. **Keyboard Handling**: Ensure proper keyboard handling so the card doesn't get obscured when the keyboard appears (may need to adjust positioning or use `ScrollViewReader`).