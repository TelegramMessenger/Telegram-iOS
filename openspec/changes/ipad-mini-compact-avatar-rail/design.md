## Context

On iPad mini and small tablet viewports, the master pane in `NavigationSplitContainer` can collapse to a compact sidebar (`masterWidth <= 160.0`, typically ~96pt).
Currently, the Telegram chat list implementation assumes full-width presentation, causing:
1. Gesture conflicts: `panRecognizer` (folder swiping) and `selectionRecognizer` (chat selection) steal touches from avatar items.
2. Inadvertent story triggers: overscroll pulling or upper region interactions trigger story creation or leave large blank gaps (`storiesInset`).
3. Scroll conflicts with static overlays: placing static touch blockers over a scrollable `ListView` causes scrolled-up items to become unclickable.

## Goals / Non-Goals

**Goals:**
- Eliminate all gesture conflicts by disabling extraneous recognizers (`panRecognizer`, `selectionRecognizer`, story gestures) directly at the recognizer level when `width <= 160.0`.
- Remove all artificial static overlay blockers and derive the top inset cleanly from `statusBarHeight` + standard padding.
- Guarantee that 100% of visible chat avatars are responsive to single taps across all scroll positions and across all folder tabs.
- Seamlessly restore standard full chat list controls (Search, Folder tabs, Story strips, Bottom Tab Bar, gestures) when expanding to regular width (`masterWidth > 160.0`).

**Non-Goals:**
- Creating custom rich folder navigation within the narrow avatar rail (folders remain accessible in full mode).
- Modifying chat list behavior on iPhone or standard large iPad viewports.

## Decisions

### Decision 1: Direct Recognizer Disabling instead of Static Touch Blockers
- **Choice**: When `isCompactAvatarRail` (`tablet && width <= 160.0`):
  - Configure `panRecognizer.allowedDirections` to return `[]` and set `panRecognizer.isEnabled = false`.
  - Set `isSelectionGestureEnabled = false` on `ChatListNode`.
  - Remove `compactRailTopTouchBlockerNode` completely.
- **Rationale**: Static overlays break hit-testing when the list is scrolled. Disabling recognizers directly ensures touch events pass cleanly to the `ListView` items without unintended gesture cancellations (`touchesCancelled`).

### Decision 2: Clean Safe-Area-Derived Top Inset
- **Choice**: In `ChatListContainerItemNode`, set the top inset for compact rail to `layout.statusBarHeight` (or safe area top) plus a standard 12pt visual margin, avoiding arbitrary large hardcoded offsets.
- **Rationale**: Provides consistent, natural top spacing aligned with iOS system standards while keeping items accessible and scrollable.

### Decision 3: Total Story Mechanics Suppression
- **Choice**: In `ChatListControllerNode`, clamp `tempTopInset = 0.0`, `storiesInset = 0.0`, `startedScrollingAtUpperBound = false`, and supply empty `effectiveStorySubscriptions` for compact mode. Propagate `effectiveStoriesInset = 0.0` to all container item nodes across all tabs.
- **Rationale**: Completely eliminates story creation triggers, story header expansions, and residual top gaps on overscroll or double-tap.

### Decision 4: Deterministic Hit-Test Frame Routing
- **Choice**: Verify that `ChatListItemNode` spans the full rail width (0..`masterWidth`) and that `NavigationSplitContainer.resizeHandle` hit-test is constrained to the boundary region (`+-6pt`).
- **Rationale**: Ensures every tap on a visible avatar row reliably triggers `interaction.peerSelected(...)`.

## Risks / Trade-offs

- **[Risk]** Disabling folder swiping prevents switching folders by dragging the sidebar.
  → **Mitigation**: In a 96pt rail, folder swiping was an accidental trigger hazard. Users switch folders by expanding to regular master width or using folder shortcuts.
- **[Risk]** Resizing master width back to regular must re-enable gestures cleanly.
  → **Mitigation**: All recognizers and insets are re-evaluated dynamically in `update(...)` and `containerLayoutUpdated(...)`.
