# Hierarchical Sticky Headers Implementation

## Overview

This implementation adds hierarchical sticky header behavior to space views, where task section headers within child containers (Lists/Projects) are reflected in the parent container header when they're about to scroll off screen.

## Problem

In space views, when scrolling through expanded child containers with task sections:
- The child container header (e.g., "Groceries") sticks to the top
- Task section headers (e.g., "Weekly Shopping") within that container scroll away normally
- This loses context about which section is currently visible

## Solution

When a task section header approaches the top of the screen (about to scroll off), the parent container header updates to show a breadcrumb: "Groceries › Weekly Shopping"

## Implementation Details

### 1. ViewModel State (`ContainerFocusViewModel.swift`)

Added a new published property to track active nested sections:
```swift
@Published var activeNestedSections: [ContainerChild.ID: String] = [:]
```

This dictionary maps each child container ID to the title of its currently active nested section (if any).

### 2. Scroll Tracking (`ContainerFocusListView.swift`)

#### Types
- `SectionPositionInfo`: Stores position data for each task section header
- `SectionPositionPreferenceKey`: A `PreferenceKey` that collects section positions from the scroll view

#### Tracking Mechanism
1. Each task section header (only those inside child containers) has a `GeometryReader` in its background
2. The `GeometryReader` reports its y-position relative to the scroll view's coordinate space
3. The `onPreferenceChange` handler processes these positions whenever scrolling occurs

#### Active Section Detection
The `updateActiveNestedSections(from:)` method:
1. Groups section positions by their parent child container
2. For each expanded container, finds the visible section closest to the top
3. If that section's y-position is ≤ 60 points (the header threshold), it's marked as "active"
4. Updates the ViewModel's `activeNestedSections` dictionary with smooth animation

### 3. Header Display (`CollapsibleHeaderLabel`)

Updated to support an optional `subtitle` parameter:
- When `subtitle` is `nil`: Shows just the container title (e.g., "Groceries")
- When `subtitle` is set: Shows breadcrumb format (e.g., "Groceries › Weekly Shopping")

The breadcrumb uses:
- Primary color and semibold weight for the container title
- A "›" separator in secondary color
- Secondary color and medium weight for the section title

## Performance Considerations

1. **Selective Tracking**: Only task sections inside child containers are tracked (not direct space sections)
2. **Efficient Updates**: The ViewModel only updates when the active sections actually change
3. **Smooth Animations**: Changes animate with a 0.15s ease-in-out duration
4. **Minimal Overhead**: Only section headers (not individual rows) use `GeometryReader`

## Threshold Configuration

The `headerThreshold` constant (60 points) represents:
- The approximate height of the navigation header in `ContainerFocusView`
- When a section header reaches this y-position, it's considered "at the top"
- This creates the visual effect of the section "pushing" against the parent header

## Behavior

### Scrolling Down
1. Child container header sticks to top
2. As you scroll, task section headers approach the top
3. When a section header reaches the threshold, the parent header updates to show the breadcrumb
4. As you continue scrolling to the next section, the breadcrumb updates

### Scrolling Up
1. When the active section scrolls back down (away from the top)
2. The breadcrumb disappears, showing only the container title
3. Smooth animation provides visual feedback

### Multiple Containers
- Each expanded child container tracks its own active section independently
- Multiple containers can show breadcrumbs simultaneously if they're all visible

## Files Modified

1. `Struct/Views/Content Pane/ContainerFocusViewModel.swift`
   - Added `activeNestedSections` published property

2. `Struct/Views/Content Pane/ContainerFocusListView.swift`
   - Added scroll tracking types (`SectionPositionInfo`, `SectionPositionPreferenceKey`)
   - Added `coordinateSpace(name: "ScrollView")` to the List
   - Added `onPreferenceChange` handler for scroll tracking
   - Implemented `updateActiveNestedSections(from:)` method
   - Added overload for `taskSectionContent` with tracking support
   - Updated `childContainerContent` to pass active section title
   - Updated `CollapsibleHeaderLabel` to support breadcrumb display

## Testing

The existing preview in `ContainerFocusView.swift` provides comprehensive test data:
- A space with direct items and sections
- Two child containers (Groceries list, Home Renovation project)
- Each child container has direct items and a task section

To test:
1. Run the preview
2. Expand both child containers
3. Scroll down through the content
4. Observe the headers updating to show breadcrumbs when sections approach the top