## 1. Gesture Recognizer Isolation

- [x] 1.1 Disable `panRecognizer` in `ChatListContainerNode` when `isCompactAvatarRail` is true (allowed directions `[]` and `panRecognizer.isEnabled = false`).
- [x] 1.2 Disable `isSelectionGestureEnabled` on `ChatListNode` in compact rail mode to prevent unintended selection/edit mode triggers.
- [x] 1.3 Remove `compactRailTopTouchBlockerNode` static overlay to eliminate scroll collision defects.

## 2. Story Mechanics & Chrome Suppression

- [x] 2.1 Ensure `ChatListNavigationBar` view is completely hidden and non-interactive when `isCompactAvatarRail` is true.
- [x] 2.2 Enforce `tempTopInset = 0.0`, `storiesInset = 0.0`, and `startedScrollingAtUpperBound = false` in `ChatListControllerNode` and `ChatListContainerNode`.
- [x] 2.3 Verify bottom `TabBarComponent` is hidden during collapsed sidebar mode.

## 3. Hit-Testing, Insets, and Avatar Tap Verification

- [x] 3.1 Derive top list insets in `ChatListContainerItemNode` cleanly from `statusBarHeight` + margin without arbitrary large offsets.
- [x] 3.2 Verify hit-testing on all visible chat avatars at default position and after scrolling.
- [x] 3.3 Verify hit-testing across all folder-filtered lists so selecting any avatar opens the corresponding chat.
- [x] 3.4 Verify clean restoration of all controls and gesture recognizers when expanding master width back to normal (`> 160pt`).

## 4. Conformance and Build Verification

- [x] 4.1 Validate OpenSpec artifacts with `openspec validate --all --strict`.
- [x] 4.2 Perform simulator and device build verification to ensure clean compilation and stable runtime behavior.

## 5. Experimental Mode Integration

- [x] 5.1 Add `compactAvatarRail` experimental setting to `ExperimentalUISettings`.
- [x] 5.2 Implement compact mode toggling via Debug settings.
- [x] 5.3 Ensure `compactAvatarRail` setting persists through app restarts.
