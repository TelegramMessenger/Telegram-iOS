## Why

On iPad mini (and narrow iPad split-view widths `<= 160pt`), collapsing the chat list into a compact sidebar currently leads to several severe UX, hit-testing, and gesture conflicts:
1. `panRecognizer` in `ChatListContainerNode` attempts horizontal folder transitions across the narrow 96pt rail, cancelling avatar touch events (`touchesCancelled` in `ListView`).
2. `selectionRecognizer` in `ChatListNode` remains enabled, allowing multi-touch or accidental gestures to inadvertently trigger selection/edit mode (checkboxes) instead of opening chats.
3. Full chat list story mechanics (overscroll expansion, story creation hooks, `tempTopInset`) leak into the collapsed sidebar, causing accidental story creation or residual empty gaps.
4. Static overlay blocker nodes introduce scroll collision defects (items scrolling under a static blocker lose tap responsiveness).

This change replaces makeshift overlays with an upstream-clean architectural solution: explicit gesture disabling at the recognizer level, safe-area-derived insets, and robust avatar hit-testing across all folder tabs.

## What Changes

- **Gesture Isolation**: When in compact avatar rail mode (`tablet && width <= 160pt`):
  - Disable `panRecognizer` (folder swipe gesture) by returning empty allowed directions `[]` and setting `isEnabled = false`.
  - Disable `selectionRecognizer` by setting `isSelectionGestureEnabled = false`.
  - Disable all story posting / camera pan gestures and lock `tempTopInset = 0.0`, `storiesInset = 0.0`.
- **Clean Inset Hierarchy (No Static Overlays)**:
  - Eliminate fake touch-blocker overlays (`compactRailTopTouchBlockerNode`).
  - Derive top insets strictly from `statusBarHeight` + clean padding (e.g. `12pt`), ensuring list items remain fully responsive at all scroll positions.
- **Accurate Hit-Testing for Avatars**:
  - Full item width (0..`masterWidth`) routes single tap events directly to `interaction.peerSelected(...)`.
  - Ensure `resizeHandle` touch bounds do not interfere with avatar hit zones.
- **Consistent Folder Support**:
  - Apply identical zero-story-inset and gesture-suppression guarantees uniformly across root chat list and all folder-filtered tabs.
- **Clean Full-List Restoration**:
  - Seamlessly re-enable folder swiping, selection gestures, search bar, and story headers when the master pane expands to regular width (`> 160pt`).

## Capabilities

### New Capabilities
- `compact-avatar-rail`: Clean gesture suppression, safe-area insets, and deterministic avatar hit-testing for iPad compact sidebar.

### Modified Capabilities
<!-- None -->

## Impact

- `submodules/ChatListUI/Sources/ChatListControllerNode.swift`: Remove static touch blockers, disable `panRecognizer` in compact mode, clamp `tempTopInset` and `storiesInset` to 0.0.
- `submodules/ChatListUI/Sources/Node/ChatListNode.swift`: Disable `isSelectionGestureEnabled` when width `<= 160.0`.
- `submodules/ChatListUI/Sources/ChatListContainerItemNode.swift`: Clean safe-area-based top list insets without magic number offsets.
- `submodules/Display/Source/Navigation/NavigationSplitContainer.swift`: Tighten `resizeHandle` hit-test bounds.
