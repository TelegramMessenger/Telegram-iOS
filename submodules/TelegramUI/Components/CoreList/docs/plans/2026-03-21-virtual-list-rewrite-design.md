# CoreVirtualListView Rewrite Design

**Status:** IMPLEMENTED / CURRENT

## Goal
Rewrite CoreVirtualListView with a cleaner architecture: pure data Window, single container UIView, edge-anchored positioning for rubber-banding, delta clamping, no animations.

## Data Model
- `Window` is a pure value type: `[(index, view, frame)]` in container-local coordinates
- Protocols `CoreListItem` / `CoreListItemView` unchanged

## Container Positioning (three states)
- First item loaded (index 0): container top = 0 → top rubber-band
- Last item loaded (index == count-1): container bottom = contentSize.height → bottom rubber-band
- Neither edge loaded: container centered at virtualContentHeight / 2
- `bounds.origin.y` adjusted in lockstep on repositioning to prevent visual jumps
- `contentSize` = virtualContentHeight unless both edges loaded → tight fit

## Scroll Handling
- Delta clamped to `bounds.height` per scroll event
- `previousBoundsOriginY` tracked for delta computation
- Rebalance: remove off-screen items, prepend/append on-screen items, recompute container position

## scrollTo(index:pointOffset:)
- Builds new window anchored at index with pointOffset
- Reuses overlapping views from old window
- No animation — immediate swap
- Sets container position and bounds.origin.y so target item appears at pointOffset from viewport top

## Rendering
- Single container UIView owned by the list view (not by Window)
- On render: position container, lay out item views by local frame

## Removed from current implementation
- `Transition` struct and all animation code
- `presentationOffsetY`
- `animateWindowShift`
- Window owning its own container UIView
