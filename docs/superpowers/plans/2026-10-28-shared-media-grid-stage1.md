# Shared Media on MediaGrid, stage 1 (Media tab) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The profile's photo/video shared media runs on `MediaGrid` with levels 3, 5, 15, behind a killswitch that is on by default.

**Architecture:** MediaGrid gains three host settings (available levels, sharp images at compact levels, a visible-range callback) plus velocity transfer, none of which change the picker. A new pane class, `PeerInfoMediaGridPaneNode`, sits beside `PeerInfoVisualMediaPaneNode` in the same module and is chosen at the one construction site for `.media`; both conform to a new protocol `PeerInfoVisualMediaPane`, which replaces the screen's concrete-class casts. Its data source adapts `SparseMessageList` to `MediaGridDataSource` with a fixed index space, shimmer cells for holes, and images from `DirectMediaImageCache`.

**Tech Stack:** Swift, UIKit layers, CoreList `PhysicsScrollEngine` (through MediaGrid), SwiftSignalKit, TelegramCore `SparseMessageList`, Bazel via `Make.py`.

**Spec:** `docs/superpowers/specs/2026-10-28-shared-media-grid-design.md`

## Global Constraints

- No code comments (inline or doc), in any file.
- MediaGrid sources import only UIKit, QuartzCore, Foundation, Photos and CoreList.
- The photo picker's behaviour must not change: every new MediaGrid setting defaults to today's behaviour.
- Levels for this pane: `[.three, .five, .fifteen]`; default `.three`.
- Stored level mapping on read: 2–3 → 3, 4–7 → 5, 8 and more → 15; written as 3, 5 or 15.
- Width buckets for preview requests: the existing `widthSpecs` of `PeerInfoVisualMediaPaneNode.swift` (cell point width ≤50 → 64 px, ≤100 → 150, ≤140 → 200, else 280).
- Killswitch key `ios_killswitch_disable_shared_media_grid_v2`; Debug Settings toggle "Shared media: legacy grid" (`ExperimentalUISettings.sharedMediaGridLegacy`); accessor `context.usesSharedMediaGridV2`.
- Files, Voice/Video messages, Music and GIFs stay on their current panes.
- Never stage Ilya's files (`Authorization.swift`, `SharedAccountContext.swift`, `InterruptedAuthorizationTests.swift`, `third-party/TelegramAppEvents/`); stage with explicit paths after diffing each file against HEAD. Commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push.
- Builds: simulator `Make.py … build --codesigningInformationPath build-system/fake-codesigning --buildNumber=1 --configuration=debug_sim_arm64`; MediaGrid tests with xcodegen on simulator `4FAA8C5A-1B8A-4350-9627-917227146FA2` (commands in `submodules/TelegramUI/Components/MediaGrid/CLAUDE.md`); in-app checks on `882DFBE5-37C1-449D-A1DA-ED66D0255610` only, never sending, posting or changing account settings.

## Review Focus

- A scrubber jump into an unloaded range at 15: cells show shimmer, never white, never another message's image, and the viewport does not move when the hole fills.
- The total count changing after the skeleton arrives (100 → real count) while the user is scrolled: the top visible item keeps its position.
- Photo/video filter switch while scrolled and mid-load: the grid reloads at the top of the new list, with no stale images or crashes from late hole results.
- Gallery open/close from a cell at 3 and 5: the transition source frame is the right cell and hidden media hides that cell.
- Pinch past 15 or below 3: rubber-bands and lands on 15 or 3, never on 31 or 1.

The first four depend on TelegramCore state and the gallery, which no host or app-side test target here can build; they
are checked from recorded frames in Task 9 Step 3. The fifth is Task 1's `testPinchStopsAtAvailableBounds`.

---

### Task 1: MediaGrid available levels

**Files:**
- Modify: `submodules/TelegramUI/Components/MediaGrid/Sources/MediaGridLevel.swift`, `MediaGridZoom.swift`, `MediaGridView.swift`
- Test: `submodules/TelegramUI/Components/MediaGrid/Tests/MediaGridAvailableLevelsTests.swift` (add to the MediaGridTests target in `project.yml` if tests are not globbed)

**Interfaces:**
- Produces: `MediaGridView.availableLevels: [MediaGridLevel]` (default `MediaGridLevel.allCases`; the setter sorts, ignores an empty array, and moves the current level to the nearest available one without animation). `MediaGridLevel.zoomedIn(within: [MediaGridLevel]) -> MediaGridLevel?`, `zoomedOut(within:)`, `rotated(toLandscape:within:)`.
- `MediaGridPinchState` takes its level list from the view instead of `MediaGridLevel.allCases`.

- [ ] **Step 1: Write the failing tests** — `testZoomStepsStayWithinAvailableLevels` (levels `[.three, .five, .fifteen]`: `.fifteen.zoomedOut(within:)` is nil, `.three.zoomedIn(within:)` is nil, `.five.zoomedOut(within:)` is `.fifteen`); `testPinchStopsAtAvailableBounds` (drive `debugDrivePinch` from 15 with scale 0.2 and release: level stays `.fifteen`; from 3 with scale 5: level `.three`); `testTapAtFifteenZoomsToFive` (tap a cell at 15 with the restricted set: level becomes `.five`); `testMenuZoomRespectsAvailableLevels` (`canZoomOut` false at 15, `canZoomIn` false at 3); `testSettingAvailableLevelsMovesCurrentLevel` (at `.one`, set `[.three, .five, .fifteen]`: level `.three`); `testDefaultLevelsUnchanged` (default `availableLevels == MediaGridLevel.allCases`).
- [ ] **Step 2: Run them to verify they fail** — `xcodebuild … -scheme MediaGridDemo … test` on `4FAA8C5A…`; expected: compile errors for the missing API.
- [ ] **Step 3: Implement** — every use of `zoomedIn`/`zoomedOut`/`allCases` in `MediaGridView.swift` (`handleTap`, `canZoomIn`, `canZoomOut`, `zoomIn`, `zoomOut`, the neighbour prepare ranges, the pinch crossing at the `from > level ? level.zoomedOut : level.zoomedIn` site, rotation) and `MediaGridPinchState.levels` go through the view's `availableLevels`.
- [ ] **Step 4: Run all MediaGrid tests** — expected: the new tests pass and the existing counts in `MediaGrid/CLAUDE.md` still pass (0 failures).
- [ ] **Step 5: Commit** — `MediaGrid: host-chosen zoom levels`.

### Task 2: Sharp images at compact levels

**Files:**
- Modify: `MediaGrid/Sources/MediaGridView.swift`, `MediaGridLayoutLayer.swift`
- Test: `MediaGrid/Tests/MediaGridCompactSharpTests.swift`

**Interfaces:**
- Produces: `MediaGridView.compactLevelsRequestSharpImages: Bool` (default `false`). When `true`, a cell at 15 or 31 is requested like one at 3 or 5: `wantsSharpImage` no longer returns false for `.compact` thumbnails, prefetch (`updatePrefetch`) runs, and the settle after moving fast requests visible sharp images. Compact detail itself (no badges, tap zooms in, no pan-to-select) is unchanged.

- [ ] **Step 1: Write the failing tests** — with a counting test data source (thumbnails for every index): `testCompactLevelRequestsSharpWhenEnabled` (level `.fifteen`, flag on, layout once at rest: `requestImage` called for every visible index); `testCompactLevelSkipsSharpByDefault` (flag off: no `requestImage` calls at 15); `testCompactPrefetchRunsWhenEnabled` (flag on at 15: `startCaching` called).
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement** — a stored flag passed down to the active and incoming `MediaGridLayoutLayer`s.
- [ ] **Step 4: Run all MediaGrid tests** — 0 failures.
- [ ] **Step 5: Commit** — `MediaGrid: optional sharp images at compact levels`.

### Task 3: Visible range and velocity transfer

**Files:**
- Modify: `MediaGrid/Sources/MediaGridView.swift`
- Test: `MediaGrid/Tests/MediaGridVisibleRangeTests.swift`

**Interfaces:**
- Produces: `MediaGridView.visibleIndexRange: Range<Int>?` (indices whose frames intersect the viewport at the current layout level, nil without a layout); `MediaGridView.onVisibleRangeChanged: ((Range<Int>) -> Void)?`, called on main whenever that range changes (scroll, zoom landing, reload, apply, rotation), never twice in a row with the same value; `MediaGridView.transferVelocity(_ velocity: CGFloat)`, which starts a fling at that velocity (points per second, positive scrolls content up) as `SparseItemGrid.transferVelocity` does for the profile header hand-off.

- [ ] **Step 1: Write the failing tests** — `testVisibleRangeAfterLayout` (count 1000, level 3, 390×844: range starts at 0 and covers the visible rows); `testVisibleRangeCallbackOnScroll` (`setContentOffset` by one screen: callback fired once with the new range); `testVisibleRangeCallbackNotRepeated` (an offset change within one row that keeps the range: no callback); `testTransferVelocityStartsFling` (after `transferVelocity(2000)` the content offset increases over the next frames, driven with the engine's test clock as existing fling tests do).
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run all MediaGrid tests** — 0 failures.
- [ ] **Step 5: Commit** — `MediaGrid: visible range callback and velocity transfer`.

### Task 4: `PeerInfoVisualMediaPane` protocol

**Files:**
- Create: `submodules/TelegramUI/Components/PeerInfo/PeerInfoVisualMediaPaneNode/Sources/PeerInfoVisualMediaPane.swift`
- Modify: `PeerInfoVisualMediaPaneNode.swift` (conformance only), `PeerInfoScreen/Sources/PeerInfoScreen.swift` (the two casts in `openMediaCalendar`), `PeerInfoScreen/Sources/PeerInfoScreenDisplayMediaGalleryContextMenu.swift` (the casts at the zoom/filter menu and the three hit-test loops)

**Interfaces:**
- Produces:
  ```swift
  public protocol PeerInfoVisualMediaPane: PeerInfoPaneNode {
      var contentType: PeerInfoVisualMediaPaneNode.ContentType { get }
      var calendarSource: SparseMessageCalendar? { get }
      var openCurrentDate: (() -> Void)? { get set }
      var paneDidScroll: (() -> Void)? { get set }
      func updateContentType(contentType: PeerInfoVisualMediaPaneNode.ContentType)
      func currentTopTimestamp() -> Int32?
      func scrollToItem(index: Int)
      func brieflyDisableTouchActions()
      func canZoom(isZoomIn: Bool) -> Bool
      func zoom(isZoomIn: Bool)
  }
  ```
  `PeerInfoVisualMediaPaneNode` implements `canZoom`/`zoom` with its existing `availableZoomLevels()` and `updateZoomLevel(level:)` (same semantics as the menu code they replace: zoom in = `increment`).
- The menu and calendar code cast to `PeerInfoVisualMediaPane`; the hit-test loops check it before `PeerInfoStoryPaneNode`.

- [ ] **Step 1: Implement** — behaviour must be identical (rule: a conversion, not a change).
- [ ] **Step 2: Build** — simulator build, expected success.
- [ ] **Step 3: Commit** — `PeerInfo: a protocol for the photo/video pane`.

### Task 5: Killswitch

**Files:**
- Create: `submodules/AccountContext/Sources/SharedMediaGridV2.swift`
- Modify: `submodules/TelegramUIPreferences/Sources/ExperimentalUISettings.swift`, `submodules/DebugSettingsUI/Sources/DebugController.swift`
- Test: `submodules/TelegramUI/Components/ChatMediaEditorScreen/Tests/SharedMediaGridFlagTests.swift` (in the same test target as `MediaPickerGridFlagTests.swift`)

**Interfaces:**
- Produces: `sharedMediaGridV2KillswitchKey = "ios_killswitch_disable_shared_media_grid_v2"`, `sharedMediaGridV2Enabled(legacyOverride:killswitchPresent:) -> Bool`, `AccountContext.usesSharedMediaGridV2`, mirroring `MediaPickerGridV2.swift` exactly. `ExperimentalUISettings.sharedMediaGridLegacy` (default false, coded like `mediaGridLegacy`), Debug entry `.sharedMediaGridLegacy` titled "Shared media: legacy grid" next to "Media picker: legacy grid".

- [ ] **Step 1: Write the failing tests** — `testEnabledByDefault`, `testLegacyOverrideDisables`, `testKillswitchDisables` (the three truth-table rows of `sharedMediaGridV2Enabled`).
- [ ] **Step 2: Run them to verify they fail** — `Make.py test --target` for that test target.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them to verify they pass.**
- [ ] **Step 5: Commit** — `Shared media: grid v2 killswitch`.

### Task 6: Pure decisions

**Files:**
- Create: `submodules/TelegramUI/Components/PeerInfo/PeerInfoVisualMediaPaneNode/Sources/MediaGridPaneDecisions.swift` (Foundation and CoreGraphics only)
- Create: `submodules/TelegramUI/Components/PeerInfo/PeerInfoVisualMediaPaneNode/Tests/MediaGridPaneDecisionsTests.swift`
- Modify: `PeerInfoVisualMediaPaneNode/BUILD` (exclude `Tests/` from the library glob; add `swift_test(name = "MediaGridPaneDecisionsTests", srcs = [the two files])` as `MediaPickerUI/BUILD` does)

**Interfaces:**
- Produces (internal):
  - `func mediaGridPaneLevelColumns(storedColumns: Int32?) -> Int` — nil → 3; ≤3 → 3; 4…7 → 5; ≥8 → 15.
  - `func mediaGridPanePreviewWidth(cellPointWidth: CGFloat) -> Int` and `let mediaGridPanePreviewWidths: [Int] = [64, 150, 200, 280]`, matching `widthSpecs`.
  - `struct MediaGridPaneHole { var anchorIndex: Int }` and `func mediaGridPaneHoleToLoad(visible: Range<Int>, isLoaded: (Int) -> Bool, holes: [MediaGridPaneHole]) -> MediaGridPaneHole?` — today's rule: the first visible index without an item; the hole whose `anchorIndex` is nearest to it (ties: the lower index); nil if every visible index is loaded or there are no holes.
  - `func mediaGridPaneDateIndex(at index: Int, anchors: [(index: Int, timestamp: Int32)]) -> Int32?` — the timestamp of the nearest anchor at or below `index`, else the nearest above; nil with no anchors.

- [ ] **Step 1: Write the failing tests** — the mapping table (nil, 2, 3, 4, 7, 8, 12 → 3, 3, 3, 5, 5, 15, 15); widths (30 → 64, 50 → 64, 51 → 150, 100 → 150, 140 → 200, 141 → 280); hole choice (all loaded → nil; first empty at 40 with anchors 0, 35, 100 → 35; tie 30/50 for 40 → 30); dates (index between anchors uses the lower; before the first uses the first; empty → nil).
- [ ] **Step 2: Run them to verify they fail** — `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TelegramUI/Components/PeerInfo/PeerInfoVisualMediaPaneNode:MediaGridPaneDecisionsTests`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them to verify they pass.**
- [ ] **Step 5: Commit** — `Shared media: grid decisions`.

### Task 7: Data source and cell

**Files:**
- Create: `PeerInfoVisualMediaPaneNode/Sources/MediaGridPaneDataSource.swift`, `MediaGridPaneCellLayer.swift`
- Modify: `PeerInfoVisualMediaPaneNode/BUILD` (add `//submodules/TelegramUI/Components/MediaGrid`)

**Interfaces:**
- Consumes: Task 6 decisions; `SparseMessageList.State` (its `items` with absolute indices, `totalCount`), `DirectMediaImageCache.getImage(message:media:width:possibleWidths:includeBlurred:synchronous:)`.
- Produces: `final class MediaGridPaneDataSource: MediaGridDataSource` with
  - `init(context: AccountContext, directMediaImageCache: DirectMediaImageCache)`;
  - `func update(state: SparseMessageList.State) -> MediaGridPaneUpdate` where `enum MediaGridPaneUpdate { case none, changed(IndexSet), apply(MediaGridChanges), reload }`: the index space is the state's total count; a same-count update that fills or changes items is `.changed`; a count change becomes `.apply` (inserted or removed at the end of the list, the side the skeleton grows), and anything a cheap diff cannot express is `.reload`;
  - `func message(at index: Int) -> EngineMessage?`, `func index(of id: EngineMessage.Id) -> Int?`, `func holes() -> [MediaGridPaneHole]` and `func holeAnchorMessageId(at anchorIndex: Int) -> EngineMessage.Id?` (the placeholder or non-local message the old pane turns into a `VisualMediaHoleAnchor`), `func dateAnchors() -> [(index: Int, timestamp: Int32)]`;
  - `requestImage`: nil for a hole; otherwise the preview at `mediaGridPanePreviewWidth` of the cell, delivered degraded first when only the blurred tiny thumbnail is available, final when the real preview arrives; keyed by message id and media id so a re-keyed cell keeps its image;
  - `thumbnail(at:)`: the blurred tiny thumbnail (`includeBlurred: true`) as a `MediaGridThumbnail` with contents rect `(0, 0, 1, 1)`, from an in-memory cache filled off main in `prepareThumbnails(ranges:)`, after which the host calls `thumbnailsDidChange(indices:)`;
  - `date(at:)` through `mediaGridPaneDateIndex`; `aspectRatioReader` returns 1.
- Produces: `final class MediaGridPaneCellLayer: MediaGridCellLayer` — hole cells show a shimmer with today's colours (`SparseItemGridBindingImpl.getShimmerColors`), a horizontal sweep whose phase is the cell's x within the grid width, so neighbouring cells sweep as one, as SparseItemGrid's `Shimmer` does; loaded cells show today's badges at `.full` detail (duration with the short style under 80 pt, live photo, check in selection mode) and only spoiler and sensitive-content blur at `.compact`. Badge drawing reuses the existing `DurationLayer` and spoiler code (make them module-internal instead of private, unchanged).

- [ ] **Step 1: Implement** the data source and cell.
- [ ] **Step 2: Build** — simulator build, expected success.
- [ ] **Step 3: Commit** — `Shared media: MediaGrid data source and cell`.

### Task 8: The pane

**Files:**
- Create: `PeerInfoVisualMediaPaneNode/Sources/PeerInfoMediaGridPaneNode.swift`

**Interfaces:**
- Consumes: Tasks 1–7.
- Produces: `public final class PeerInfoMediaGridPaneNode: ASDisplayNode, PeerInfoVisualMediaPane` with the same init parameters as `PeerInfoVisualMediaPaneNode` for `.photoOrVideo` (`context, chatControllerInteraction, peerId, chatLocation, chatLocationContextHolder, contentType, captureProtected, initialFocusMessageIndex`), and:
  - a `MediaGridView` with `availableLevels = [.three, .five, .fifteen]`, `compactLevelsRequestSharpImages = true`, the level from `visualMediaStoredState` through `mediaGridPaneLevelColumns`, written back (3, 5 or 15) on every landed zoom;
  - loading: `sparseMessageList` and `sparseMessageCalendar` exactly as the old pane builds them; on `onVisibleRangeChanged` and after each state update, `mediaGridPaneHoleToLoad` picks a hole and `SparseMessageList.loadHole(anchor:direction:completion:)` loads it with the anchor's message id and the direction the old pane's `loadHole` derives, one at a time (the next pick waits for `completion`); the update kinds of Task 7 map to `reloadImages`/`apply`/`reloadData`; `updateContentType` rebuilds the list and the data source and reloads at the top;
  - the `PeerInfoPaneNode` surface as the old pane does it: `tabBarOffset`/`tabBarOffsetUpdated` and the covering inset from the content offset relative to `topInset`, `scrollToTop`, `transferVelocity` (Task 3), `hitTestResultForScrolling`, `brieflyDisableTouchActions`, `cancelPreviewGestures`, `findLoadedMessage`, `transitionNodeForGallery` (from `contentFrameForItem` and the cell's contents, as the old pane snapshots its layer), `addToTransitionSurface` (the grid's `overlayView`), `updateHiddenMedia`, `updateSelectedMessages`, `ensureMessageIsVisible`, `status`, `isReady`;
  - taps at 3 and 5 open the gallery as the old pane's `onTap` does; selection mode and pan-to-select use `chatControllerInteraction`'s selection state; the long-press context menu (`ContextControllerSourceNode`) as the old pane wires it;
  - a `SparseItemGridScrollingArea` driven by the grid's offset and `topVisibleDate`, opening the calendar through `openCurrentDate`, with the fast-scroll tooltip as the old pane shows it; `scrollToItem(index:)` and `currentTopTimestamp()` for the calendar; `scrollToTimestamp` among loaded items;
  - the empty state and status line as the old pane builds them.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Build** — simulator build, expected success.
- [ ] **Step 3: Commit** — `Shared media: MediaGrid pane`.

### Task 9: Routing, check and docs

**Files:**
- Modify: `PeerInfoScreen/Sources/PeerInfoPaneContainerNode.swift` (the `.media` case)
- Modify: `submodules/TelegramUI/Components/PeerInfo/PeerInfoVisualMediaPaneNode/CLAUDE.md` (create), root `CLAUDE.md` (one line under Subsystem guides), `MediaGrid/CLAUDE.md` (the three new settings)

**Interfaces:**
- The `.media` case builds `PeerInfoMediaGridPaneNode` when `context.usesSharedMediaGridV2`, else the old pane, and wires `openCurrentDate`/`paneDidScroll` through the protocol.

- [ ] **Step 1: Implement the routing.**
- [ ] **Step 2: Build and install on `882DFBE5`** (whole-`.app` copy, root `CLAUDE.md`).
- [ ] **Step 3: Check in the app**, recording the simulator and reading frames: a profile with many photos, a forum topic, Saved Messages' per-peer media; pinch 3→5→15→5→3 and past both ends; tap at 15; scrubber jump to the middle at 15 (shimmers, then images, no movement); open and close the gallery at 3 and 5; selection with pan-to-select; long-press menu with zoom and the photo/video filter; calendar open and jump; Debug toggle back to the legacy grid.
- [ ] **Step 4: Write the guides** — the pane guide: what the new pane does, the hole and update rules, the killswitch, the known limits found in Step 3.
- [ ] **Step 5: Commit** — `Shared media: MediaGrid behind a killswitch`.
