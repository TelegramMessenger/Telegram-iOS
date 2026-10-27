# Media Grid (stage 1: component + demo app) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A standalone, layer-based photo grid on the CoreList scroll engine, with zoom levels 1/3/5/15/31 (pinch, menu, tap-to-zoom), a date-scrubber API and a demo app that measures it at 100k items.

**Architecture:** `MediaGridView` (a `UIView`) owns a `PhysicsScrollEngine` in `.keyframe` mode and lays cells out as pooled `CALayer`s directly in the engine's `contentHost`, in absolute content coordinates. Geometry is a pure value (`MediaGridLayout`): closed-form for square levels, prefix sums for level 1. A zoom builds a second layer set for the target level and cross-fades/scales the two about an anchor index. Data comes through a `MediaGridDataSource` protocol indexed directly (no per-item entries).

**Tech Stack:** Swift, UIKit, QuartzCore, Photos, XCTest; XcodeGen-generated demo project; Bazel `swift_library` for the module.

**Spec:** `docs/superpowers/specs/2026-10-27-media-picker-grid-design.md`

**Scope:** stage 1 only. Stage 2 (moving `MediaPickerScreen` onto the grid) gets its own plan after stage 1 lands, using what stage 1 measured.

## Global Constraints

- Levels exactly `1, 3, 5, 15, 31` photos per row. Default 3 in portrait (and on regular width), 5 in landscape on compact width.
- Selection, checkbox, tap-to-open and pan-to-select only at 1, 3, 5. At 15 and 31: no checkbox, no badge, no selection marker of any kind; tap zooms in one level (31 → 15, 15 → 5) keeping the tapped photo under the finger.
- Camera cutout (1 column × 2 rows at top-left) only at 3 and 5; it fades by alpha during the transition; at 1/15/31 photos flow into its place.
- Level 1: each photo at its aspect ratio clamped to 2:1 … 1:2 (width/height in `0.5 ... 2.0`), aspect-fill crop of the overflow.
- Spacing 1 pt between cells and rows.
- Rotation: portrait → landscape moves one level up the list `[1, 3, 5, 15, 31]` (31 stays 31); landscape → portrait moves one level down (1 stays 1). The top visible photo stays in view.
- The grid module imports only UIKit, QuartzCore, Foundation, Photos and `CoreList`. No Display, AsyncDisplayKit, SwiftSignalKit, Postbox, TelegramCore, LegacyComponents.
- Scroll engine: `PhysicsScrollEngine` with `decelerationMode = .keyframe`. CoreList's behaviour and its test suite must not change.
- Project code style: no inline or doc comments in new code (user preference).
- All simulator work on a dedicated simulator `MediaGridDemo iPhone 18 Pro 27.0` (created in Task 2). Never the booted iPhone 17 Pro / iPhone 18 Pro, which hold logged-in Telegram.

## Review Focus

1. **Empty and tiny libraries** (count 0, 1, fewer items than the camera cutout's slots) — the grid shows nothing / the items, no crash, no negative content height; pinch still works or is a no-op. Test in Task 3 and Task 4.
2. **Scrubbing to the very end and back to the top** in one drag at 100k items — the last row (partial) is fully visible, the first row sits under the top inset, nothing is left unbound. Test in Task 6.
3. **A pinch that starts during a fling** — motion stops in place, the anchor is the photo under the fingers at the *presented* position, not the engine's sampled offset. Test in Task 9.
4. **Level-1 exact heights arriving while the user is mid-scroll** — the photo at the top of the screen does not jump. Test in Task 10.
5. **A library change that removes the anchor or the visible photos** — the grid keeps the nearest surviving index in place and rebinds only changed visible cells. Test in Task 11.

---

## File Structure

All new files under `submodules/TelegramUI/Components/MediaGrid/`:

```
BUILD                         swift_library "MediaGrid" (srcs = Sources/**/*.swift), deps = CoreList
CLAUDE.md                     how to generate, build, test, run the demo; invariants
project.yml                   XcodeGen: CoreList framework, MediaGrid framework, MediaGridDemo app, MediaGridTests
Sources/
  MediaGridLevel.swift        levels, defaults, rotation mapping, capabilities per level
  MediaGridLayout.swift       protocol MediaGridLayout + MediaGridGeometry (width, spacing, insets)
  MediaGridUniformLayout.swift  square/fixed-aspect levels with reserved slots (camera, avatar)
  MediaGridAspectLayout.swift   level 1 prefix-sum layout with estimate→exact
  MediaGridAspectIndex.swift    off-main build/update of clamped aspect ratios
  MediaGridDataSource.swift     data source protocol, image request token, change set
  MediaGridCellLayer.swift      open base cell layer (image + detail flag)
  MediaGridCellPool.swift       reuse pool
  MediaGridLayoutLayer.swift    one level's visible cells in one container layer
  MediaGridPrefetch.swift       pure prefetch-window planner
  MediaGridZoom.swift           anchor math + interactive transition state
  MediaGridSelectionGesture.swift  pan-to-select (port of MediaPickerGridSelectionGesture)
  MediaGridView.swift         the public view: engine, layout layers, gestures, API
Demo/
  Info.plist                  NSPhotoLibraryUsageDescription
  AppDelegate.swift
  DemoViewController.swift    grid + toolbar (source, zoom in/out, measure), HUD, scrubber
  SyntheticDataSource.swift   seeded 100k items, dates, aspects, generated images
  PhotoLibraryDataSource.swift  PHFetchResult + PHCachingImageManager + PHChange
  DemoCellLayer.swift         checkmark + duration badge (only at interactive levels)
  DemoScrubberView.swift      minimal draggable thumb + date label
  FrameMonitor.swift          display-link frame intervals → dropped/worst readout
Tests/
  MediaGridLevelTests.swift
  MediaGridUniformLayoutTests.swift
  MediaGridAspectLayoutTests.swift
  MediaGridPrefetchTests.swift
  MediaGridZoomTests.swift
  MediaGridViewTests.swift    view-level: virtualization, reuse, scrubbing, taps, zoom, changes
  TestDataSource.swift        synchronous in-memory data source for tests
```

Modified: `submodules/TelegramUI/Components/CoreList/CoreListDemo/PhysicsScrollEngine.swift`, `ScrollEngine.swift` (visibility only, plus one property), `submodules/TelegramUI/Components/CoreList/CLAUDE.md` (one paragraph).

Common commands (used by every task; run from `submodules/TelegramUI/Components/MediaGrid`):

```bash
xcodegen generate --quiet
xcodebuild -project MediaGrid.xcodeproj -scheme MediaGridDemo -destination 'platform=iOS Simulator,name=MediaGridDemo iPhone 18 Pro 27.0' -parallel-testing-enabled NO test -only-testing:MediaGridTests/<Class>
```

`MediaGrid.xcodeproj` is generated and stays untracked (the root `.gitignore` already ignores `*.xcodeproj`).

---

### Task 1: Expose the CoreList scroll engine

**Files:**
- Modify: `submodules/TelegramUI/Components/CoreList/CoreListDemo/PhysicsScrollEngine.swift`
- Modify: `submodules/TelegramUI/Components/CoreList/CoreListDemo/ScrollEngine.swift` (`ScrollFlight` only)
- Modify: `submodules/TelegramUI/Components/CoreList/CLAUDE.md`
- Test: `submodules/TelegramUI/Components/CoreList/CoreListDemoTests/` (existing suite, plus one new test file `PhysicsScrollEnginePublicSurfaceTests.swift`)

**Interfaces:**
- Produces (all `public`, nothing else changes visibility; the `ScrollEngine` protocol stays internal):
  - `public final class PhysicsScrollEngine` with `public override init()`
  - `public enum DecelerationMode { case stepped, keyframe }`, `public var decelerationMode`
  - `public var offset: CGFloat`, `public var contentHost: UIView`, `public var isDecelerating: Bool`
  - `public var onScroll: ((CGFloat) -> Void)?`, `public var onFlightChanged: ((ScrollFlight?) -> Void)?`, `public var onWillBeginDragging`, `public var onDidEndDragging`, `public var onDidEndDecelerating`
  - `public func setOffset(_ y: CGFloat)`, `public func haltMotionInPlace()`, `public func setEdges(min: CGFloat?, max: CGFloat?)`, `public func tearDown()`
  - new: `public var isScrollEnabled: Bool` — get/set `pan.isEnabled`; setting `false` first calls `haltMotionInPlace()`
  - `public struct ScrollFlight` with `public var settledOffset: CGFloat` and `public let beginTime: CFTimeInterval` (stored `trajectory` stays internal)

- [ ] **Step 1: Write the failing test** `PhysicsScrollEnginePublicSurfaceTests.testDisablingScrollHaltsAndBlocksPan`: create engine, `setEdges(min: 0, max: 10_000)`, `setOffset(500)`, assert `isScrollEnabled == true`; set `isScrollEnabled = false`; assert `offset == 500`, `isDecelerating == false`, and the host's pan (`contentHost.gestureRecognizers?.first`) has `isEnabled == false`.
- [ ] **Step 2: Run it, expect a compile failure** (`isScrollEnabled` missing). Command: `xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo -destination 'platform=iOS Simulator,name=MediaGridDemo iPhone 18 Pro 27.0' -parallel-testing-enabled NO test -only-testing:CoreListDemoTests/PhysicsScrollEnginePublicSurfaceTests` from the CoreList directory. (Create the simulator first: `xcrun simctl create "MediaGridDemo iPhone 18 Pro 27.0" "iPhone 18 Pro" com.apple.CoreSimulator.SimRuntime.iOS-27-0`.)
- [ ] **Step 3: Add the `public` modifiers listed above and `isScrollEnabled`.** Visibility only; no logic change.
- [ ] **Step 4: Run the whole CoreList suite** (same command without `-only-testing`). Expected: everything that passed before still passes; record the pass/fail counts before and after in the commit message.
- [ ] **Step 5: Update `CoreList/CLAUDE.md`**: replace the sentence that says the ScrollEngine types stay module-internal with one stating that `PhysicsScrollEngine` and `ScrollFlight` are public for `MediaGrid`, the protocol stays internal, and `isScrollEnabled` exists for hosts that run their own gestures.
- [ ] **Step 6: Commit** `feat(corelist): expose PhysicsScrollEngine for MediaGrid`.

### Task 2: Module scaffold, demo project, levels

**Files:**
- Create: `MediaGrid/BUILD`, `MediaGrid/project.yml`, `MediaGrid/CLAUDE.md`, `MediaGrid/Demo/Info.plist`, `MediaGrid/Demo/AppDelegate.swift`, `MediaGrid/Demo/DemoViewController.swift` (empty white screen), `MediaGrid/Sources/MediaGridLevel.swift`
- Test: `MediaGrid/Tests/MediaGridLevelTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum MediaGridLevel: Int, CaseIterable, Comparable {
      case one = 1, three = 3, five = 5, fifteen = 15, thirtyOne = 31
      public var columns: Int
      public var isInteractive: Bool        // 1, 3, 5
      public var showsCamera: Bool          // 3, 5
      public var zoomedIn: MediaGridLevel?  // fewer columns; nil at .one
      public var zoomedOut: MediaGridLevel? // more columns; nil at .thirtyOne
      public static func defaultLevel(isLandscape: Bool) -> MediaGridLevel
      public func rotated(toLandscape: Bool) -> MediaGridLevel
  }
  ```

`project.yml` targets:
- `CoreList` (framework): sources `../CoreList/CoreListDemo` with `excludes` identical to the `exclude` list in `CoreList/BUILD` (AppDelegate, SceneDelegate, ViewController, PhysicsScrollDemoViewController, ScrollComparisonViewController, PipelineDepthProbe, PipelineDepthViewController, DemoRow, AutoLoadResponseScheduler, plus `Info.plist` and asset catalogs).
- `MediaGrid` (framework): `Sources`, depends on `CoreList`.
- `MediaGridDemo` (application, bundle id `org.telegram.MediaGridDemo`, iOS 15.0): `Demo`, depends on both; `Info.plist` from `Demo/Info.plist`.
- `MediaGridTests` (unit test bundle hosted by `MediaGridDemo`): `Tests`.

`BUILD`: `swift_library(name = "MediaGrid", module_name = "MediaGrid", srcs = glob(["Sources/**/*.swift"]), deps = ["//submodules/TelegramUI/Components/CoreList:CoreList"], visibility = ["//visibility:public"])`.

- [ ] **Step 1: Write failing tests** in `MediaGridLevelTests`:
  - `testColumns`: `MediaGridLevel.allCases.map(\.columns) == [1, 3, 5, 15, 31]`
  - `testCapabilities`: `isInteractive` true exactly for 1, 3, 5; `showsCamera` true exactly for 3, 5
  - `testZoomSteps`: `.thirtyOne.zoomedIn == .fifteen`, `.fifteen.zoomedIn == .five`, `.one.zoomedIn == nil`, `.thirtyOne.zoomedOut == nil`, `.three.zoomedOut == .five`
  - `testDefaults`: `defaultLevel(isLandscape: false) == .three`, `defaultLevel(isLandscape: true) == .five`
  - `testRotation`: to landscape `[1,3,5,15,31] → [3,5,15,31,31]`; to portrait `[1,3,5,15,31] → [1,1,3,5,15]`
- [ ] **Step 2: Generate and run; expect compile failure.** `xcodegen generate --quiet && xcodebuild … -only-testing:MediaGridTests/MediaGridLevelTests`
- [ ] **Step 3: Implement `MediaGridLevel`.**
- [ ] **Step 4: Run; expect PASS.** Also `xcodebuild … -scheme MediaGridDemo build` succeeds.
- [ ] **Step 5: Write `CLAUDE.md`** with: what the module is, the generate/build/test/run commands above, the dedicated simulator rule, the import whitelist, and "the `.xcodeproj` is generated; edit `project.yml`".
- [ ] **Step 6: Commit** `feat(media-grid): module scaffold, demo project and zoom levels`.

### Task 3: Uniform layout

**Files:**
- Create: `Sources/MediaGridLayout.swift`, `Sources/MediaGridUniformLayout.swift`
- Test: `Tests/MediaGridUniformLayoutTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct MediaGridGeometry: Equatable {
      public var width: CGFloat
      public var sideInset: CGFloat      // safe-area left/right, content spans width - 2*sideInset
      public var topInset: CGFloat
      public var bottomInset: CGFloat
      public var spacing: CGFloat        // 1.0
      public var scale: CGFloat          // screen scale for pixel snapping
  }
  public protocol MediaGridLayout {
      var count: Int { get }
      var contentHeight: CGFloat { get }        // includes top and bottom insets
      func frame(at index: Int) -> CGRect       // content coordinates
      func indexRange(intersecting rect: CGRect) -> Range<Int>
      func index(at point: CGPoint) -> Int?
  }
  public struct MediaGridSlot: Hashable { public var row: Int; public var column: Int }
  public struct MediaGridUniformLayout: MediaGridLayout {
      public init(geometry: MediaGridGeometry, columns: Int, cellAspect: CGFloat, reservedSlots: Set<MediaGridSlot>, count: Int)
      public func reservedFrame(_ slots: Set<MediaGridSlot>) -> CGRect?   // union frame, for the camera view
      public var itemSize: CGSize
  }
  ```
- `cellAspect` is height/width (1.0 square; 1.227 for story mode in stage 2).
- Item width `w = floor(((width - 2*sideInset) - spacing*(columns-1)) / columns * scale) / scale`; column `c` at `x = sideInset + c*(w+spacing)`; the last column's width extends to `width - sideInset`. Row height `h = floor(w*cellAspect*scale)/scale`, row `r` at `y = topInset + r*(h+spacing)`.
- Reserved slots are skipped in row-major order; index `i` maps to the `i`-th unreserved slot. All reserved slots lie in the first rows, so the mapping is a short scan over the sorted reserved slot numbers.
- `indexRange` and `index(at:)` are O(1) apart from that scan; never iterate items.

- [ ] **Step 1: Write failing tests:**
  - `testThreeColumnsOn393`: geometry width 393, scale 3, spacing 1, no insets: `itemSize.width == 130.333…` (floor to 1/3 pt), frame(0).minX == 0, frame(2).maxX == 393, frame(3).minY == itemSize.height + 1.
  - `testCameraSlotsSkipped`: columns 3, reserved `{(0,0),(1,0)}`: frame(0) is slot (0,1), frame(2) is slot (1,1), frame(4) is slot (2,0); `reservedFrame` height == 2*h + 1.
  - `testIndexRangeMatchesBruteForce`: for counts `[0, 1, 2, 7, 100_000]`, columns `[3,5,15,31]`, with and without camera, for 50 seeded random rects: `indexRange(intersecting:)` equals the brute-force set of indices whose frame intersects the rect.
  - `testIndexAtPoint`: centre of every frame for count 200 maps back to its index; a point in the spacing returns nil; a point in a reserved slot returns nil.
  - `testContentHeight`: count 0 → `topInset + bottomInset`; count 1 with camera at 3 columns → covers the camera's two rows.
- [ ] **Step 2: Run, expect failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media-grid): closed-form uniform layout`.

### Task 4: MediaGridView — scrolling, virtualization, pooled cells

**Files:**
- Create: `Sources/MediaGridDataSource.swift`, `Sources/MediaGridCellLayer.swift`, `Sources/MediaGridCellPool.swift`, `Sources/MediaGridLayoutLayer.swift`, `Sources/MediaGridView.swift`
- Create: `Demo/SyntheticDataSource.swift`; modify `Demo/DemoViewController.swift`
- Test: `Tests/TestDataSource.swift`, `Tests/MediaGridViewTests.swift`

**Interfaces:**
- Consumes: `MediaGridLevel`, `MediaGridUniformLayout`, `MediaGridGeometry`, `PhysicsScrollEngine` (Task 1).
- Produces:
  ```swift
  public protocol MediaGridImageRequest: AnyObject { func cancel() }
  public protocol MediaGridDataSource: AnyObject {
      var count: Int { get }
      func date(at index: Int) -> Date?
      func aspectRatio(at index: Int) -> CGFloat            // width / height; may be called off-main
      func requestImage(at index: Int, pixelSize: CGSize, completion: @escaping (UIImage?, _ isDegraded: Bool) -> Void) -> MediaGridImageRequest?
      func startCaching(indices: [Int], pixelSize: CGSize)
      func stopCaching(indices: [Int], pixelSize: CGSize)
  }
  public enum MediaGridCellDetail { case full, compact }   // compact at 15 and 31
  open class MediaGridCellLayer: CALayer {
      public private(set) var index: Int
      open func bind(index: Int, detail: MediaGridCellDetail)
      open func setImage(_ image: UIImage?)                 // sets contents, contentsGravity .resizeAspectFill
      open func prepareForReuse()
  }
  public final class MediaGridView: UIView {
      public init(dataSource: MediaGridDataSource, cellFactory: @escaping () -> MediaGridCellLayer)
      public var geometryInsets: UIEdgeInsets               // top inset hosts a banner in stage 2
      public var cellAspect: CGFloat                         // default 1.0
      public private(set) var level: MediaGridLevel
      public func reloadData()
      public var contentOffset: CGFloat { get }              // engine.offset
      public var contentHeight: CGFloat { get }
      public func setContentOffset(_ y: CGFloat)
      public func forEachVisibleCell(_ f: (Int, MediaGridCellLayer) -> Void)
      public func frameForItem(at index: Int) -> CGRect?     // in self's coordinates, nil if not laid out
      public var onScroll: ((CGFloat) -> Void)?
  }
  ```
- Cells are added to the engine's `contentHost.layer` inside one `MediaGridLayoutLayer` (a `CALayer` container) per active level; actions disabled (`actions` returns `NSNull` for all keys) on cells and containers.
- Engine edges: `setEdges(min: 0, max: max(0, contentHeight - bounds.height))`; content coordinates have the top inset inside `contentHeight`.
- Visible window = `indexRange(intersecting: viewport.insetBy(dy: -bounds.height))` where the viewport is centred on the offset passed to `onScroll` (the live sample during a flight).
- Images requested at `itemSize × scale` (rounded up); a request is cancelled in `prepareForReuse`; a degraded delivery is shown, then replaced.
- Pool: `MediaGridCellPool.dequeue() -> MediaGridCellLayer`, `enqueue(_:)`; enqueued cells are hidden, not removed from the tree; pool capped at 2 × the largest visible window seen.

- [ ] **Step 1: Write `TestDataSource`**: `count` settable; `requestImage` calls completion synchronously with a 1×1 image and counts requests and cancels; dates `Date(timeIntervalSince1970: 1_600_000_000 - index*3600)`; aspect 1.0.
- [ ] **Step 2: Write failing tests** in `MediaGridViewTests` (grid 393×852, count 100_000, level 3, scale 3, `layoutIfNeeded()` then drive `setContentOffset`):
  - `testVisibleCellsMatchLayout`: every visible index is in `indexRange` of the viewport ± one screen and every index of the viewport itself is visible; each cell's frame equals `layout.frame(at:)`.
  - `testFarJumpReusesCells`: record the set of cell object identities; `setContentOffset(contentHeight / 2)`; the number of distinct cell objects ever created ≤ 2 × the visible count; the number of live `CALayer` sublayers in the container did not grow.
  - `testCancelsOffscreenRequests`: after the jump, `cancelCount` ≥ number of cells that left.
  - `testEmptyAndTiny`: counts 0 and 1: no crash, `contentHeight >= 0`, visible cell count equals count.
- [ ] **Step 3: Run, expect failure.**
- [ ] **Step 4: Implement** the data source protocol, cell layer, pool, layout layer and view per the interfaces above.
- [ ] **Step 5: Run, expect PASS.**
- [ ] **Step 6: `SyntheticDataSource`**: `init(count: Int = 100_000, seed: UInt64 = 1)`; dates descending from 2026-10-01 with seeded 0–36 h gaps; aspect seeded from `[0.3, 0.5, 0.75, 1.0, 1.33, 1.78, 3.0]`; `requestImage` renders on a serial background queue a solid colour derived from the index with the index number drawn in the centre, at the requested size, completion on main; an `NSCache` keyed by `(index, size)`. `DemoViewController` shows a full-screen `MediaGridView` with it.
- [ ] **Step 7: Run the demo on the dedicated simulator** (`xcrun simctl install` + `launch` with bundle id `org.telegram.MediaGridDemo`), fling and confirm cells appear; take one screenshot with `xcrun simctl io <udid> screenshot`.
- [ ] **Step 8: Commit** `feat(media-grid): layer grid on the physics scroll engine`.

### Task 5: Prefetch planner and the photo-library source

**Files:**
- Create: `Sources/MediaGridPrefetch.swift`, `Demo/PhotoLibraryDataSource.swift`; modify `Sources/MediaGridView.swift`, `Demo/DemoViewController.swift`
- Test: `Tests/MediaGridPrefetchTests.swift`, `Tests/MediaGridViewTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct MediaGridPrefetchPlan: Equatable { public var start: [Int]; public var stop: [Int] }
  public struct MediaGridPrefetchPlanner {
      public init(screensAhead: CGFloat = 2.0)
      public mutating func update(layout: MediaGridLayout, viewportHeight: CGFloat, offset: CGFloat, settledOffset: CGFloat?) -> MediaGridPrefetchPlan
  }
  ```
  Caching window = the viewport at `offset` extended `screensAhead` screens in the direction of travel, plus, when `settledOffset` is non-nil (a flight from `onFlightChanged`), the viewport at `settledOffset` ± one screen. `start` = window minus previously cached; `stop` = previously cached minus window.
- `MediaGridView` feeds the plan to `startCaching`/`stopCaching` from `onScroll` and `onFlightChanged`, with `pixelSize` = current item pixel size.
- `PhotoLibraryDataSource(fetchResult: PHFetchResult<PHAsset>)`: newest first (index 0 = last object of a creation-date-ascending fetch, as `MediaPickerScreen` does today), `PHCachingImageManager` with `allowsCachingHighQualityImages = false`, `deliveryMode = .opportunistic`, `resizeMode = .fast`, `isNetworkAccessAllowed = true`; `date(at:)` and `aspectRatio(at:)` read `creationDate` and `pixelWidth/pixelHeight`.

- [ ] **Step 1: Failing planner tests**: `testIdleWindow` (no flight: window is viewport ± 2 screens down when moving down), `testFlightAddsLandingWindow` (settledOffset 50 screens below: plan contains the landing indices), `testStopsWhatLeft` (second update after a jump stops the first window, no index in both start and stop), `testEmptyLayout`.
- [ ] **Step 2: Run, expect failure.** **Step 3: Implement.** **Step 4: Run, expect PASS.**
- [ ] **Step 5: View test** `testFlightStartsCachingAtLanding`: simulate `onFlightChanged` via an internal test hook `MediaGridView._testFlight(settledOffset:)` (internal, `@testable import`) and assert `TestDataSource.cachedIndices` contains the landing window.
- [ ] **Step 6: Demo**: a source switch (Synthetic 100k / Photo Library) in the toolbar; Photo Library asks for read access and falls back to Synthetic when denied.
- [ ] **Step 7: Commit** `feat(media-grid): prefetch along the flight and a PhotoKit source`.

### Task 6: Scrubber API, demo scrubber, frame monitor

**Files:**
- Modify: `Sources/MediaGridView.swift`
- Create: `Demo/DemoScrubberView.swift`, `Demo/FrameMonitor.swift`; modify `Demo/DemoViewController.swift`
- Test: `Tests/MediaGridViewTests.swift`

**Interfaces:**
- Produces on `MediaGridView`:
  ```swift
  public var topVisibleIndex: Int? { get }        // first index whose frame intersects the area below the top inset
  public var topVisibleDate: Date? { get }        // cached per index, dataSource.date read once
  public var isUserScrolling: Bool { get }        // dragging or decelerating
  ```
  The date cache is a dictionary keyed by index, cleared on `reloadData` and on changes.
- `setContentOffset` is applied synchronously on the main thread with no queue hop or throttle (the spec's scrubber fix); it halts any flight first.
- `DemoScrubberView`: a thumb on the right edge mapping its track linearly to `[0, contentHeight - viewport]`, writing `setContentOffset` on every pan change, with a date label beside the thumb showing `topVisibleDate` formatted "LLLL yyyy".
- `FrameMonitor`: `CADisplayLink` at max rate, records intervals; HUD shows dropped frames (intervals > 1.5 × the link's `targetTimestamp - timestamp`) and the worst interval over the last 5 s; a Reset button.

- [ ] **Step 1: Failing tests**:
  - `testScrubToEndAndBack`: `setContentOffset(contentHeight - height)`: the last index is visible and its frame's maxY ≤ contentHeight; `setContentOffset(0)`: index 0 visible at `frame.minY == topInset`; in both, every index in the viewport has a bound cell with an image set.
  - `testTopVisibleIndexAndDate`: at offset 0 → index 0 and `TestDataSource.date(at: 0)`; at the row-10 offset → `10 * columns`; `date(at:)` called once per index across repeated reads.
- [ ] **Step 2: Run, expect failure.** **Step 3: Implement.** **Step 4: Run, expect PASS.**
- [ ] **Step 5: Demo**: scrubber + HUD in place; scrub top→bottom→top on Synthetic 100k on the simulator and note the HUD numbers in the commit message (simulator numbers are indicative only).
- [ ] **Step 6: Commit** `feat(media-grid): direct scrubber API and demo HUD`.

### Task 7: Taps, selection, camera cutout, top inset

**Files:**
- Create: `Sources/MediaGridSelectionGesture.swift`, `Demo/DemoCellLayer.swift`; modify `Sources/MediaGridView.swift`, `Demo/DemoViewController.swift`
- Test: `Tests/MediaGridViewTests.swift`

**Interfaces:**
- Produces on `MediaGridView`:
  ```swift
  public var onTapItem: ((Int) -> Void)?                     // only at interactive levels
  public var isItemSelected: ((Int) -> Bool)?
  public var onSelectionPan: ((Int, Bool) -> Void)?          // index, select
  public var cameraView: UIView?                             // placed over the reserved camera slots at 3 and 5
  public func index(at point: CGPoint) -> Int?               // point in self's coordinates
  ```
- `MediaGridSelectionGesture` is a port of `MediaPickerGridSelectionGesture` (`submodules/MediaPickerUI/Sources/MediaPickerScreen.swift:4177-4262`) with the same thresholds (fail on |dy| > 5 before |dx| > 8; side inset), non-generic over `Int`, and `updateIsScrollEnabled` wired to `engine.isScrollEnabled`. It is enabled only at interactive levels.
- At 3 and 5, reserved slots `{(0,0),(1,0)}` exist when `cameraView != nil`; at 1/15/31 none. The camera view lives in `contentHost` at `reservedFrame`.
- Cell detail: `.full` at interactive levels, `.compact` at 15/31. `DemoCellLayer` draws a checkmark circle (a sublayer created on first `.full` bind) reflecting `isItemSelected`, and nothing at `.compact`.

- [ ] **Step 1: Failing tests**: `testTapAtInteractiveLevelReportsIndex` (call the tap handler through an internal `_testTap(at:)` at the centre of index 7 → `onTapItem(7)`), `testCameraTakesTwoSlots` (with a camera view at level 3, index 0 is at slot (0,1) and the camera view's frame equals `reservedFrame`), `testNoCameraSlotsAtFifteen` (after `setLevel(.fifteen, animated: false)` from Task 8 — skip-marked until Task 8 lands, then enabled), `testCompactDetailAtFifteen` (cells bound with `.compact`), `testTopInsetShiftsContent` (`geometryInsets.top = 60` → index 0 minY == 60).
- [ ] **Step 2: Run, expect failure.** **Step 3: Implement.** **Step 4: Run, expect PASS.**
- [ ] **Step 5: Demo**: a grey placeholder camera view, a 44 pt banner placeholder in the top inset, tap toggles selection, pan selects.
- [ ] **Step 6: Commit** `feat(media-grid): taps, pan-to-select, camera cutout and top inset`.

### Task 8: Animated zoom: menu steps and tap-to-zoom

**Files:**
- Create: `Sources/MediaGridZoom.swift`; modify `Sources/MediaGridView.swift`, `Demo/DemoViewController.swift`
- Test: `Tests/MediaGridZoomTests.swift`, `Tests/MediaGridViewTests.swift`

**Interfaces:**
- Test hooks (internal, reached with `@testable import`): `_testTap(at:)` from Task 7, plus `_testFinishAnimations()` here, which completes any running zoom transition synchronously.
- Produces:
  ```swift
  public struct MediaGridZoomAnchor: Equatable { public var index: Int; public var pointInView: CGPoint }
  public enum MediaGridZoomMath {
      public static func targetOffset(anchor: MediaGridZoomAnchor, in layout: MediaGridLayout, viewportHeight: CGFloat) -> CGFloat
      public static func scale(from: MediaGridLayout, to: MediaGridLayout, anchorIndex: Int) -> CGFloat   // ratio of the anchor's frame widths
  }
  extension MediaGridView {
      public func setLevel(_ level: MediaGridLevel, animated: Bool, anchor: MediaGridZoomAnchor? = nil)
      public func zoomIn(); public func zoomOut()                 // one step, anchor = item at the viewport centre
      public var canZoomIn: Bool { get }; public var canZoomOut: Bool { get }
      public var isZoomEnabled: Bool                               // default true
      public var onLevelChanged: ((MediaGridLevel) -> Void)?
  }
  ```
- `targetOffset` puts the anchor index's frame so the anchor point keeps its relative position inside that frame at `pointInView`, clamped to `[0, contentHeight - viewportHeight]`.
- Animated transition: build the target `MediaGridLayoutLayer` at the target offset; animate the outgoing container scale (about the anchor point) from 1 to `scale` and opacity 1→0, the incoming from `1/scale` to 1 and opacity 0→1; camera view alpha to 0 or 1 per `showsCamera`; 0.35 s spring (damping 1.0). On completion the engine's offset and edges switch to the target layout and the outgoing container's cells return to the pool.
- At 15/31 a tap calls `setLevel(level.zoomedIn!, animated: true, anchor: MediaGridZoomAnchor(index: tapped, pointInView: tapPoint))`.

- [ ] **Step 1: Failing math tests**: anchor stays put — for every pair of adjacent levels and anchors at indices `[0, 1, 500, count-1]`, after `targetOffset` the anchor's frame in the target layout contains `pointInView` (in viewport coordinates) unless clamped at an edge; clamping at index 0 and at `count-1`; `scale(3→5)` ≈ ratio of item widths.
- [ ] **Step 2: Failing view tests**: `testZoomInFromThirtyOneByTap` (level 31, `_testTap` on index 4000 → level 15 after `_testFinishAnimations()`, index 4000's frame contains the tap point), `testZoomButtonsDisabledAtEnds`, `testCameraFadesAtFifteen` (camera alpha 0 after zoom out from 5), `testNoMarkersAtCompact` (no sublayers beyond the image on any visible `DemoCellLayer` at 31).
- [ ] **Step 3: Run, expect failure.** **Step 4: Implement.** **Step 5: Run, expect PASS** (and enable the skipped Task 7 test).
- [ ] **Step 6: Demo**: Zoom In / Zoom Out buttons bound to `canZoomIn/Out`.
- [ ] **Step 7: Commit** `feat(media-grid): animated zoom levels and tap-to-zoom`.

### Task 9: Interactive pinch

**Files:**
- Modify: `Sources/MediaGridZoom.swift`, `Sources/MediaGridView.swift`
- Test: `Tests/MediaGridZoomTests.swift`, `Tests/MediaGridViewTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct MediaGridPinchState {
      public init(startLevel: MediaGridLevel, anchor: MediaGridZoomAnchor)
      public mutating func update(scale: CGFloat) -> (from: MediaGridLevel, to: MediaGridLevel, progress: CGFloat)
      public func settle(velocity: CGFloat) -> MediaGridLevel
  }
  ```
- Pinch scale `s` maps to a continuous column position on the log scale of `columns`: `position = log(columns(start) / s)` interpolated between the levels' `log(columns)`; `from`/`to` are the neighbouring levels around that position and `progress` the fraction between them. Chaining past a level happens when the position crosses it: the outgoing container is recycled and a new pair is built.
- `settle`: the nearer level by position, biased one step in the direction of `velocity` when `|velocity| > 0.5` (scale units per second).
- On `.began`: `engine.haltMotionInPlace()`, `engine.isScrollEnabled = false`, anchor = item under the pinch centre using the **presented** layer position (`contentHost.layer.presentation()`), not `engine.offset`. On end: animate to the settled level with the remaining progress, then re-enable scrolling.
- Disabled when `isZoomEnabled == false`.

- [ ] **Step 1: Failing state tests**: `testScaleOneIsStart`, `testPinchOutThreeReachesFiveThenFifteen` (decreasing scale crosses 5 then 15; `from/to/progress` at the midpoint between 3 and 5 is `(3, 5, ~0.5)`), `testClampAtEnds` (scale beyond 31 or below 1 clamps, progress 0/1), `testSettleNearestAndVelocityBias`.
- [ ] **Step 2: Failing view test** `testPinchDuringFlightAnchorsPresentedItem`: start a flight through the internal hook, begin a pinch via `_testPinch(began:center:)`, assert `isUserScrolling == false` and the anchor index equals the item under the centre at the presented offset.
- [ ] **Step 3: Run, expect failure.** **Step 4: Implement.** **Step 5: Run, expect PASS.**
- [ ] **Step 6: Manual check in the demo**: pinch through every level pair including chaining 3 → 31 in one gesture; record the HUD's worst frame per pair in the commit message.
- [ ] **Step 7: Commit** `feat(media-grid): interactive pinch between levels`.

### Task 10: Level 1 — measurement first, then the aspect layout

**Files:**
- Create: `Sources/MediaGridAspectIndex.swift`, `Sources/MediaGridAspectLayout.swift`; modify `Sources/MediaGridView.swift`, `Demo/DemoViewController.swift`, `Demo/PhotoLibraryDataSource.swift`
- Test: `Tests/MediaGridAspectLayoutTests.swift`, `Tests/MediaGridViewTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public final class MediaGridAspectIndex {
      public init(count: Int, aspectRatio: @escaping (Int) -> CGFloat)
      public func build(completion: @escaping ([Float]) -> Void)         // off-main; completion on main; clamped to 0.5...2.0
      public static func clamp(_ aspect: CGFloat) -> CGFloat
  }
  public struct MediaGridAspectLayout: MediaGridLayout {
      public init(geometry: MediaGridGeometry, count: Int, aspects: [Float]?, estimatedAspect: CGFloat = 0.75)
  }
  ```
  Row height `= floor(contentWidth / aspect * scale) / scale`; prefix offsets stored as `[Double]` of length `count + 1`; `indexRange` and `index(at:)` by binary search. With `aspects == nil` every row uses `estimatedAspect`.
- When the index finishes, `MediaGridView` swaps the layout keeping `topVisibleIndex` at the same y within the viewport (its offset inside its own frame scaled by the frame's height change).

- [ ] **Step 1: Measurement (before any layout code).** Add a "Measure aspects" toolbar button to the demo that times, on a background queue, reading `pixelWidth`/`pixelHeight` for every asset of the current `PHFetchResult` (`enumerateObjects` and, separately, `object(at:)` in a loop), and shows both times and the count. Commit `chore(media-grid): aspect read measurement in the demo`.
- [ ] **Step 2: Checkpoint with Ilya.** Ask him to run the demo on a device with his real library (the demo needs his signing team set in Xcode) and report the two numbers. Proceed with precompute if the faster read is under 1 s for his library; otherwise stop and bring the numbers back, because the spec says the measurement decides between precompute and a lazily refined estimate.
- [ ] **Step 3: Failing layout tests**: `testClamp` (`0.2 → 0.5`, `3.0 → 2.0`, `1.0 → 1.0`), `testRowHeights` (width 393: aspect 2.0 → 196.5 rounded to pixels, 0.5 → 786), `testIndexRangeMatchesBruteForce` (seeded random aspects, counts `[0, 1, 1000]`), `testEstimateWhenNil`.
- [ ] **Step 4: Failing view tests**: `testExactHeightsKeepTopItem` (at level 1 scrolled to index 300 with estimates, deliver exact aspects; index 300's minY in view coordinates changes by less than 1 pt), `testZoomOneToThreeAnchors` (setLevel(.three) from level 1 with anchor index 300 keeps it on screen).
- [ ] **Step 5: Run, expect failure.** **Step 6: Implement**; level 1 uses `.full` detail, no camera slots, `contentsGravity = .resizeAspectFill`, images requested at the row's pixel size.
- [ ] **Step 7: Run, expect PASS.** Pinch 3 ↔ 1 in the demo.
- [ ] **Step 8: Commit** `feat(media-grid): level 1 in each photo's aspect ratio`.

### Task 11: Library changes

**Files:**
- Modify: `Sources/MediaGridDataSource.swift`, `Sources/MediaGridView.swift`, `Sources/MediaGridAspectIndex.swift`, `Demo/PhotoLibraryDataSource.swift`
- Test: `Tests/MediaGridViewTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct MediaGridChanges {
      public var removed: IndexSet      // indices in the old list
      public var inserted: IndexSet     // indices in the new list
      public var changed: IndexSet      // indices in the new list
      public init(removed: IndexSet, inserted: IndexSet, changed: IndexSet)
  }
  extension MediaGridView { public func apply(_ changes: MediaGridChanges) }
  extension MediaGridAspectIndex { public func apply(_ changes: MediaGridChanges, aspectRatio: (Int) -> CGFloat) -> [Float] }
  ```
- No animation (my call in the plan; the spec asks only for incremental handling). The anchor is `topVisibleIndex` mapped through the change (shifted by removals/insertions before it; if removed, the nearest surviving index); its y in the viewport is preserved. Only visible cells whose index is in `changed` or whose index moved are rebound.
- `PhotoLibraryDataSource` registers as `PHPhotoLibraryChangeObserver` and converts `PHFetchResultChangeDetails` (reversed to the newest-first order) into `MediaGridChanges`; on `hasIncrementalChanges == false` it calls `reloadData`.

- [ ] **Step 1: Failing tests**: `testInsertAboveKeepsTopItem` (insert 10 at index 0 while index 500 is at the top → index 510 at the same y), `testRemoveAnchorKeepsNearest`, `testChangedRebindsOnlyVisible` (request count grows by the visible changed cells only), `testAspectIndexAppliesChanges`.
- [ ] **Step 2: Run, expect failure.** **Step 3: Implement.** **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media-grid): incremental library changes`.

### Task 12: Rotation and width changes

**Files:**
- Modify: `Sources/MediaGridView.swift`, `Demo/DemoViewController.swift`
- Test: `Tests/MediaGridViewTests.swift`

**Interfaces:**
- Produces: `extension MediaGridView { public func updateLayout(size: CGSize, safeInsets: UIEdgeInsets, isLandscape: Bool, transition duration: TimeInterval) }`. When `isLandscape` changes, the level becomes `level.rotated(toLandscape:)`; `topVisibleIndex` stays at the top. `MediaGridView` no longer derives its level from `bounds` alone.

- [ ] **Step 1: Failing tests**: `testRotateThreeToFiveKeepsTop` (portrait level 3 at index 900 → landscape level 5, index 900 visible in the first row), `testRotateThirtyOneStays`, `testLandscapeOneToPortraitOne`, `testSideInsetsRespected` (safe insets 59/59 → frame(0).minX == 59).
- [ ] **Step 2: Run, expect failure.** **Step 3: Implement.** **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media-grid): rotation keeps the step and the top photo`.

### Task 13: Verification pass

**Files:**
- Modify: `MediaGrid/CLAUDE.md` (measured numbers, invariants learned)

- [ ] **Step 1: Full MediaGrid suite**: `xcodebuild … test` (no `-only-testing`). Expected: all pass.
- [ ] **Step 2: Full CoreList suite** (Task 1 command). Expected: same result as before Task 1.
- [ ] **Step 3: Bazel**: `python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache build --configurationPath build-system/appstore-configuration.json --codesigningInformationPath build-system/fake-codesigning --buildNumber=1 --configuration=debug_sim_arm64` from the repo root. Expected: success (it compiles CoreList with the new visibility; MediaGrid itself joins the app graph in stage 2, which is where its `BUILD` is first compiled — say so in the summary). Also `./build-input/bazel-9.2.0-darwin-arm64 query //submodules/TelegramUI/Components/MediaGrid:MediaGrid` resolves.
- [ ] **Step 4: Device check with Ilya**: on his device with the real library and with Synthetic 100k, fling, scrub top↔bottom, pinch through all levels; record the HUD's dropped-frame count and worst frame for each in `CLAUDE.md`. These are the spec's success measures; a miss is reported, not hidden.
- [ ] **Step 5: Commit** `docs(media-grid): measured results and invariants`.
