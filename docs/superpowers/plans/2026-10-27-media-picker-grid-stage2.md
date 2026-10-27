# MediaPickerScreen on MediaGrid (Stage 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The chat attachment menu's photo picker runs on `MediaGridView` by default, behind a server killswitch. The `GridNode` path stays intact.

**Architecture:**
- The demo's PhotoKit stack becomes a module, `MediaGridPhotoLibrary`.
- `MediaPickerUI` gets an internal grid seam with two implementations: the existing `GridNode` path and the new `MediaGrid` path. The choice is made once, when the picker is created.
- The new path has a picker-specific cell layer, transitions built from snapshots, and a non-`UIScrollView` arbitration protocol in `AttachmentContainer`.

**Tech Stack:** Swift, UIKit/QuartzCore, Photos, AsyncDisplayKit/Display (picker side only), Bazel via Make.py, xcodebuild for the MediaGrid module tests.

**Spec:** `docs/superpowers/specs/2026-10-27-media-picker-grid-stage2-design.md`. Stage-1 specs: `2026-10-27-media-picker-grid-design.md` and `2026-10-27-media-grid-thumbnail-store-design.md`.

## Global Constraints

- **Killswitch.** The key is `ios_killswitch_disable_media_grid_v2`; its presence means the old path. The debug flag is `ExperimentalUISettings.mediaGridLegacy`. By default the new grid is on. The flag is read once, at picker creation.
- **Scope.** The new grid covers only the chat attachment menu: Recents and albums, `.assets` subjects. Every other mode and subject stays on `GridNode`, unchanged.
- **The `GridNode` path does not change behaviour.** Refactoring it behind the seam is mechanical forwarding.
- **Import boundaries.**
  - `MediaGrid` (Sources) keeps its import rules: UIKit, QuartzCore, Foundation, CoreGraphics, ImageIO, CoreList. No Photos.
  - `MediaGridPhotoLibrary` may import Photos and MediaGrid, and nothing from Telegram: no Display, AsyncDisplayKit, SwiftSignalKit, Postbox or TelegramCore.
- **iOS 13.** Every MediaGrid module compiles for the app's deployment target, with `#available` guards for newer APIs. `MediaPickerUI` builds with `-warnings-as-errors`.
- **No code comments.** No inline or doc comments in new code. Stage explicit paths only, and diff each file against HEAD first: Ilya edits this checkout concurrently. Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **App build.** `python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache build --configurationPath build-system/appstore-configuration.json --codesigningInformationPath build-system/fake-codesigning --buildNumber=1 --configuration=debug_sim_arm64`. Add `--continueOnError` when needed.
- **Module tests.** Run the MediaGrid module tests on the dedicated simulator 4FAA8C5A-1B8A-4350-9627-917227146FA2 only, with `-collect-test-diagnostics never`.
- **In-app checks.** These run only on the simulator Ilya names, never on another one.

## Review Focus

1. **Pull-to-dismiss arbitration.** It must behave exactly like the old path:
   - pulling down at the top collapses or dismisses;
   - a scroll up expands;
   - the selection pan cancels the container pan;
   - a pinch never starts a container pan.
2. **Selection order numbers.** They must stay correct across zoom, rotation, a library change, and an album switch. The send must use exactly the selected assets, in order.
3. **The gallery transition.** It goes into the gallery and back from a cell at any level. Hiding and unhiding the source cell must work, and so must an edited or spoilered asset.
4. **Killswitch flips between picker opens.** Each open uses the then-current value. Nothing is shared between the two paths' states.
5. **Limited photo access and denied access.** Check the header region, the empty state, and the camera-denied variant.

---

### Task 1: The `MediaGridPhotoLibrary` module

**Files:**
- Create: `submodules/TelegramUI/Components/MediaGridPhotoLibrary/` with `BUILD`, `Sources/` and `Tests/`. It takes these from `MediaGrid/Demo/`:
  - `ImageLoadScheduler`;
  - the `PhotoLibraryDataSource` core (store, filler, catalog, PHChange, launch match glue);
  - `ThumbnailFiller` and the related files.
- Modify: `MediaGrid/project.yml` and the Demo, so the demo uses the module.
- Move the tests that cover the moved code.

**Interfaces:**
- Produces: `public final class MediaGridPhotoLibraryDataSource: MediaGridDataSource`, built from `(fetchResult: PHFetchResult<PHAsset>, reversed: Bool, store: MediaGridThumbnailStore, launch: MediaGridLaunchMatch?, …)`. It conforms to the full `MediaGridDataSource`, including thumbnails and launch images.
- Produces: `public final class MediaGridPhotoLibraryServices`. It is the app-session owner of the thumbnail store, the filler and the launch cache, with `shared` lazily created at `<Caches>/MediaGridThumbnails/`, plus `startLaunchLoading()`.
- Demo-only pieces stay in the Demo: the HUD, the probes, `InstrumentedDataSource` and the flags.

- [ ] **Step 1:** Move the code and its tests. The Demo uses the module. Add the module to `project.yml` as a framework target with its own test target.
- [ ] **Step 2:** Run the MediaGrid suite and the new module suite on the dedicated simulator. The counts must equal today's (319 with 2 skipped, split between the two), with no failures.
- [ ] **Step 3:** Run `bazel query //submodules/TelegramUI/Components/MediaGridPhotoLibrary:MediaGridPhotoLibrary` and confirm it resolves.
- [ ] **Step 4:** Commit `refactor(media-grid): photo library stack as a module`.

### Task 2: Killswitch and debug toggle

**Files:**
- Create: `submodules/AccountContext/Sources/MediaPickerGridV2.swift`, following `ChatMediaEditorV2.swift`.
- Modify: `TelegramUIPreferences/Sources/ExperimentalUISettings.swift` and `DebugSettingsUI/Sources/DebugController.swift`. Use a new, unused stable id; the file's comment lists the ids that are taken.
- Test: next to `ChatMediaEditorFlagTests`, or a new `ios_unit_test` in AccountContext if that is cleaner. Run it with `Make.py test --target`.

**Interfaces:**
- `public let mediaPickerGridV2KillswitchKey = "ios_killswitch_disable_media_grid_v2"`.
- `public func mediaPickerGridV2Enabled(legacyOverride: Bool, killswitchPresent: Bool) -> Bool`, which returns `!legacyOverride && !killswitchPresent`.
- `extension AccountContext { var usesMediaPickerGridV2: Bool }`.

- [ ] **Step 1:** Write the failing tests: the four combinations of the pure function, and decode/encode of `mediaGridLegacy` with a default of false.
- [ ] **Step 2:** Implement. Run the tests.
- [ ] **Step 3:** Commit `feat(media-picker): media grid v2 killswitch and debug toggle`.

### Task 3: The grid seam with the `GridNode` implementation

**Files:**
- Create: `MediaPickerUI/Sources/MediaPickerGridHost.swift`, holding an internal protocol and the `GridNode`-backed class.
- Modify: `MediaPickerUI/Sources/MediaPickerScreen.swift`. Every `gridNode` use goes through the seam.

**Interfaces:**
- The protocol covers exactly the surface listed in the exploration (spec, "Seam"):
  - data updates: `apply(entries transaction)`;
  - layout: insets, cutouts for the camera and avatar, item size and columns;
  - `forEachVisibleItem(identifier, view/cell)`;
  - item at point;
  - scroll state: offset, top, dragging and decelerating;
  - `setContentOffset` and `scrollToTop`;
  - `isScrollEnabled`;
  - `scrollingInitiated`, `visibleContentOffsetChanged` and `visibleItemsUpdated` callbacks;
  - the camera host view and the header host;
  - transition view, transition image and default transition view for an identifier;
  - hidden-media updates;
  - `interactiveTransitionGestureRecognizerTest`;
  - hidden and user-interaction flags.
- The `GridNode` class forwards to today's code.

- [ ] **Step 1:** Refactor mechanically. Do not change any behaviour.
- [ ] **Step 2:** Run `Make.py build`.
- [ ] **Step 3:** Run a short in-app smoke test of the old path: open the attachment menu, scroll, select, open the gallery, send. Ask Ilya for the simulator first.
- [ ] **Step 4:** Commit `refactor(media-picker): grid seam`.

### Task 4: The `MediaGrid` implementation (data, layout, scroll, scrubber, header, camera)

**Files:**
- Create: `MediaPickerUI/Sources/MediaPickerMediaGridHost.swift`.
- Modify: `MediaPickerScreen.swift`. When `usesMediaPickerGridV2` is set, the chat attachment mode and `.assets` choose the new host.
- Modify: `MediaPickerUI/BUILD`, adding deps on MediaGrid and MediaGridPhotoLibrary.

**Interfaces:**
- **Data and layout.**
  - The data source is `MediaGridPhotoLibraryDataSource` over the picker's fetch result. Recents are reversed. An album is not reversed and starts scrolled to its end.
  - Album switching reloads the data.
  - `PHChange` is mapped to `apply`.
  - Layout uses `updateLayout(size:safeInsets:isLandscape:transition:)`. Zoom is enabled.
- **Scroll state and scrubber.**
  - Scroll state, callbacks, `scrollToTop` and `setContentOffset` are mapped onto `MediaGridView`. Add small public API to MediaGrid where it is missing: an animated scroll-to-top, a begin-drag callback, and a header region.
  - `SparseItemGridScrollingArea` is driven by `topVisibleDate`, `contentOffset`, `contentHeight` and `isUserScrolling`.
- **Header and camera.**
  - `MediaPickerManageNode` goes in the header region and scrolls with the content.
  - The camera wrapper is hosted in `cameraView`. Camera visibility is computed from the grid.
  - The avatar cutout stays on the old path; it is not needed in the attachment menu.
- **Launch and store.** `MediaGridPhotoLibraryServices.shared.startLaunchLoading()` is called when the attachment menu begins presenting the media tab.

- [ ] **Step 1:** Write unit tests in the MediaGridPhotoLibrary or MediaGrid test targets for:
  - reversed and unreversed index mapping;
  - an album that starts at its end;
  - the header-region layout;
  - animated scroll-to-top.
- [ ] **Step 2:** Implement. Run the module suites and `Make.py build`.
- [ ] **Step 3:** Commit `feat(media-picker): media grid host`.

### Task 5: Picker cell, selection, tap-to-open, transitions

**Files:**
- Create: `MediaPickerUI/Sources/MediaPickerGridCellLayer.swift`.
- Modify: `MediaPickerMediaGridHost.swift` and `MediaPickerScreen.swift`, for the transition and selection wiring.

**Interfaces:**
- **The cell layer.** `MediaPickerGridCellLayer: MediaGridCellLayer` has layer-based decorations:
  - a check with its order number. Read the selection index from `TGMediaSelectionContext` by identifier, and update it from `selectionChangedSignal` through `forEachVisibleCell`.
  - duration, or GIF;
  - the live-photo icon;
  - the price;
  - the download-status overlay.

  A spoiler shows its dust through an overlay view that the host positions over the cell. There are no decorations at 15 or 31.
- **Edited thumbnails.** `editingContext.thumbnailImageSignal` overrides the shown image for edited ids, through the data source.
- **Selection and tap.**
  - Pan-to-select uses MediaGrid's `MediaGridSelectionGesture`, which calls the picker's `toggleSelection`. When it begins, it calls `controller.cancelPanGesture()`.
  - Tap-to-open calls `openMedia` with the un-reversed fetch index, exactly as today.
- **Transitions.**
  - `transitionView(for:snapshot:hideSource:)` returns a snapshot view built from the cell's contents in grid coordinates, and hides the cell layer.
  - `transitionImage(for:)` and `defaultTransitionView()` behave the same way.
  - The send-preview and selected-list `getTransitionView` closures use the same snapshot. The dust node is nil, or comes from the spoiler overlay.

- [ ] **Step 1:** Write unit tests for the cell's decoration states: order numbers, duration formatting, compact levels hiding decorations, and the spoiler overlay request. Run them in the MediaPickerUI test target if one exists, or add an `ios_unit_test`. Keep the decisions under test free of `PresentationStrings`.
- [ ] **Step 2:** Implement. Run `Make.py build`.
- [ ] **Step 3:** Commit `feat(media-picker): media grid cells, selection and transitions`.

### Task 6: Attachment container arbitration

**Files:**
- Modify: `AttachmentUI/Sources/AttachmentContainer.swift`, plus a protocol in AttachmentUI.
- Modify: `MediaPickerMediaGridHost.swift`, which adopts the protocol.

**Interfaces:**
- `public protocol AttachmentScrollableContent: AnyObject`, adopted by a view in the hit-tested chain. It exposes:
  - `var isContentAtTop: Bool`;
  - `var isContentScrolling: Bool`;
  - `func setContentScrollingEnabled(_:)`;
  - `func stopContentScrolling()`.
- `findScrollView` also finds `AttachmentScrollableContent`. The pan handler uses it with the same decisions it makes for a `UIScrollView`.

- [ ] **Step 1:** Implement. The `UIScrollView` path is unchanged.
- [ ] **Step 2:** Run `Make.py build`.
- [ ] **Step 3:** In the app, check against the old path that pull-down at the top collapses or dismisses, a scroll up expands, a selection pan cancels the container pan, and a pinch does not move the sheet.
- [ ] **Step 4:** Commit `feat(attachment): arbitration for non-scroll-view content`.

### Task 7: In-app acceptance and docs

- [ ] **Step 1:** On the simulator Ilya names, use the new path to:
  - open the attachment menu, cold and warm;
  - scroll and scrub at 3 and 31;
  - pinch through every level;
  - select 5 photos by tap and by pan;
  - open the gallery from levels 3 and 1 and return;
  - send;
  - pull down to dismiss;
  - switch albums;
  - check the limited-access header;
  - rotate.

  Record the runs and check the frames: no white cells for indexed photos, no snake, and a sharp first screen.
- [ ] **Step 2:** Flip the debug toggle. Check that the old path works (smoke test), and that the killswitch key forces the old path, using a debug override of the app config if that is available. Otherwise use the unit test plus the toggle.
- [ ] **Step 3:** Update the docs:
  - the `MediaGrid/CLAUDE.md` stage-2 section;
  - a `MediaPickerUI` note on the seam and the killswitch;
  - a root `CLAUDE.md` Subsystem guides line for MediaGridPhotoLibrary.
- [ ] **Step 4:** Commit `docs(media-picker): media grid v2 notes`.
