# MediaGrid Thumbnail Store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every cell of the MediaGrid shows an image in the same frame it becomes visible, at every level and in every motion. The image comes from a persistent on-device store of 48 px thumbnails that fills in the background.

**Architecture:**
- A Photos-free `MediaGridThumbnailStore` in the grid module stores 48×48 px slots in 16×16-slot pages. Each page is one JPEG plus an index. Decoded pages are held as shared `CGImage`s in an LRU cache.
- Cells show a slot by setting `contents` to the page image and `contentsRect` to the slot.
- The grid binds thumbnails synchronously and asks for sharp PhotoKit images only when motion settles.
- A PhotoKit filler in the demo fills the store with priority around the viewport and the scrub target. It moves to a real module in stage 2.

**Tech Stack:** Swift, UIKit/QuartzCore, ImageIO (JPEG encode and decode), Photos (demo only), and XCTest through xcodegen/xcodebuild on the dedicated simulator.

**Spec:** `docs/superpowers/specs/2026-10-27-media-grid-thumbnail-store-design.md`, an addendum to `docs/superpowers/specs/2026-10-27-media-picker-grid-design.md`.

## Global Constraints

- All of `.superpowers/sdd/2026-10-27-media-grid-stage1/global-constraints.md` still applies: imports, no code comments, the dedicated simulator only, explicit staging, and the commit trailer.
- Slot: 48×48 px. The photo is drawn aspect-fit inside the slot, with its aspect clamped to `0.5 ... 2.0` (width/height) and centred. The padding repeats the drawn rect's outermost row or column (edge-extended, so JPEG has no hard edge there); `contentsRect` never shows it.
- Page: 16×16 slots = 768×768 px, 256 photos. Stored as a JPEG with quality 0.6.
- Storage lives in `<Caches>/MediaGridThumbnails/`, unencrypted, and survives relaunch. It is rebuilt if it is missing or corrupt, and it never crashes on bad files.
- The decoded-page budget defaults to 32 pages. On a memory warning or when the app enters the background, the cache is trimmed to the pages that are currently visible.
- No disk I/O, decode or encode on main. `thumbnail(for:)` is O(1) on main.
- At levels 15 and 31 (cell pixel size ≤ 1.25 × 48 px on its longer side), no sharp PhotoKit request is made.
- A bound cell never returns to empty. A sharp or degraded image replaces the thumbnail only if its pixel size is larger.
- Tests pass `-collect-test-diagnostics never` to xcodebuild.

## Review Focus

1. The store is filled for only part of the range, so the grid mixes thumbnails and empty cells. Unfilled cells get the thumbnail as soon as it is written. There is no full reload.
2. A page is not decoded yet when a scrub lands. The cell fills in the frame its page decode finishes, and no other cell flickers.
3. A photo is edited, so its modification date changes. Its slot is redrawn and the cells showing it refresh. A removed photo's slot is reused, and a reused slot never shows the old photo, including through a stale decoded page.
4. Cold launch with a full store: the first screen shows thumbnails on the first frame after the pages around the initial position decode. Opening is not slowed by loading the index, which happens off main or is O(1).
5. A memory warning during a scrub or pinch: the visible pages stay and nothing goes white.

---

### Task 1: Store core (in-memory)

**Files:**
- Create: `Sources/MediaGridThumbnailStore.swift`, `Sources/MediaGridThumbnail.swift`
- Test: `Tests/MediaGridThumbnailStoreTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct MediaGridThumbnail {
      public let image: CGImage
      public let contentsRect: CGRect
      public func contentsRect(fillingAspect aspect: CGFloat) -> CGRect
  }
  public final class MediaGridThumbnailStore {
      public init(directory: URL?, slotPixelSize: Int = 48, pageSide: Int = 16, decodedPageBudget: Int = 32)
      public func version(for id: String) -> String?
      public func thumbnail(for id: String) -> MediaGridThumbnail?
      public func write(_ image: CGImage, id: String, version: String)
      public func remove(ids: [String])
      public var onThumbnailsChanged: ((Set<String>) -> Void)?
  }
  ```
  - `MediaGridThumbnail.contentsRect` is the slot's unit rectangle within the page, covering the drawn aspect-fit area.
  - `contentsRect(fillingAspect:)` crops that area to the given cell aspect (aspect-fill).
  - `directory: nil` means memory-only, for tests.
  - `write` may be called from any thread. It draws into the page's in-memory buffer, then publishes a new page `CGImage` to main and calls `onThumbnailsChanged` on main with the ids that changed.
  - Slots are assigned in write order, and a removed id's slot is reused.

- [ ] **Step 1: Failing tests.**
  - `testWriteThenThumbnailHasSlotRect`: the first id gets slot 0 → `contentsRect.origin == .zero`, and the size is `48/768` for a square image.
  - `testAspectFitClamped`: a 4:1 image is clamped to 2:1, so the drawn rect is 48×24 px centred.
  - `testFillingAspectCrops`: a 2:1 slot filled to aspect 1 gives the centre 24×24 px region.
  - `testRemoveReusesSlot`, `testSecondPageAfter256`, `testRewriteSameIdKeepsSlotUpdatesVersion`.
  - `testReusedSlotNeverShowsOldPixels`: write A red, remove A, write B blue into the same slot, and check that the sampled pixel is blue.
  - `testThumbnailOnMainIsCheap`: 10k lookups take < 5 ms.
- [ ] **Step 2: Run, expect failure.** **Step 3: Implement.** **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media-grid): in-memory thumbnail store`.

### Task 2: Persistence and the decoded-page cache

**Files:**
- Modify: `Sources/MediaGridThumbnailStore.swift` (or split it into `Sources/MediaGridThumbnailPages.swift`)
- Test: `Tests/MediaGridThumbnailStoreTests.swift`

**Interfaces:**
- Produces:
  ```swift
  extension MediaGridThumbnailStore {
      public func load(completion: @escaping () -> Void)
      public func prepare(ids: [String])
      public func flush(completion: (() -> Void)?)
      public func trimToVisible(ids: Set<String>)
      public var decodedPageCount: Int { get }
  }
  ```
  - `load` reads the index off main and calls `completion` on main.
  - Dirty pages are encoded to JPEG off main and written atomically. They are flushed in batches: within 2 s of the last write, on `flush`, and on background.
  - The index is written after its pages, in a versioned binary or plist format. A missing or corrupt index or page gives an empty store or an empty page, never a crash.
  - `thumbnail(for:)` returns nil when the id's page is not decoded. `prepare` decodes the needed pages off main, most recent request first, and calls `onThumbnailsChanged` on main for their ids.
  - The LRU has `decodedPageBudget` entries. Pages with unflushed writes are never evicted.

- [ ] **Step 1: Failing tests.**
  - `testRoundTripAcrossInstances`: write 300 ids, flush, open a new store on the same directory, load, prepare, and check that the pixels match within JPEG tolerance.
  - `testCorruptIndexStartsEmpty`, `testCorruptPageGivesNilNotCrash`.
  - `testPrepareDecodesOffMainAndNotifies`.
  - `testBudgetEvictsLeastRecent`, `testDirtyPageNotEvicted`.
  - `testTrimToVisibleKeepsVisiblePages`.
  - `testLoadIsOffMain`: the main thread is never blocked for more than 2 ms during `load` of a 100k-id index.
- [ ] **Step 2: Run, expect failure.** **Step 3: Implement.** **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media-grid): thumbnail store persistence and page cache`.

### Task 3: Grid integration

**Files:**
- Modify: `Sources/MediaGridDataSource.swift`, `Sources/MediaGridCellLayer.swift`, `Sources/MediaGridLayoutLayer.swift`, `Sources/MediaGridView.swift`, `Sources/MediaGridZoom.swift` as needed
- Modify: `Tests/TestDataSource.swift`
- Test: `Tests/MediaGridThumbnailBindingTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public protocol MediaGridDataSource {
      func thumbnail(at index: Int) -> MediaGridThumbnail?
      func prepareThumbnails(indices: Range<Int>)
  }
  extension MediaGridView { public func thumbnailsDidChange(indices: IndexSet?) }
  ```
  - Both protocol methods get default implementations: nil and a no-op.
  - Passing `nil` to `thumbnailsDidChange` means all visible cells.
  - The cell gets `setThumbnail(_ thumbnail: MediaGridThumbnail, cellAspect: CGFloat)`. It shares the page's `contents`, sets `contentsRect`, and records the pixel size it shows. `setImage` resets `contentsRect` to the unit rectangle and replaces the thumbnail only if it is larger.
  - **Binding:** bind the thumbnail synchronously, then request a sharp image unless the cell's pixel size is ≤ 1.25 × the slot. While moving fast, bind thumbnails only. The settle upgrade (0.12 s, already there) requests the sharp images.
  - **Removal:** the `.fast` request quality and its plumbing (`MediaGridImageQuality.fast`) are deleted where the thumbnail path replaces them. The data source keeps `requestImage` for sharp images.
  - **Prepare calls:**
    - the visible range plus the prefetch window, on every window update;
    - during a scrub, the target index range ahead;
    - at pinch begin and at `setLevel`, the incoming level's range before the first transition frame;
    - the rotation target range.
  - **Zoom transition:** incoming cells are bound with thumbnails before the first transition frame. An outgoing cell's sharp image is reused for the same index when the incoming cell's thumbnail is smaller, so a zoom-in from 3 to 1 keeps sharpness.
  - `thumbnailsDidChange` refreshes the given visible cells that are showing nothing or a smaller thumbnail. Cells with a sharp image are left alone, unless their id's version changed, which the data source signals via `changed` in `apply`.

- [ ] **Step 1: Failing tests.** All use a `TestDataSource` with thumbnails.
  - `testBindShowsThumbnailSynchronously`: after `setContentOffset`, every visible cell has `contents` with no delivery flushed.
  - `testNoSharpRequestAtFifteenAndThirtyOne`.
  - `testFastMotionBindsThumbnailsOnly`.
  - `testSettleUpgradesToSharp`.
  - `testSmallerImageDoesNotReplaceThumbnail`.
  - `testZoomIncomingHasThumbnailsOnFirstFrame`: pinch began, then every incoming visible cell has `contents`.
  - `testZoomInReusesOutgoingSharpImage`.
  - `testThumbnailsDidChangeFillsEmptyCellsOnly`.
  - `testPrepareCalledForScrubTargetAndIncomingLevel`.
  - `testNeverReturnsToEmpty`: across a scrub, pinch, rotation and `apply`, a cell whose thumbnail exists is never seen with nil `contents` after its first bind.
- [ ] **Step 2: Run, expect failure.** **Step 3: Implement.** **Step 4: Run, expect PASS.** Run the full MediaGridTests suite.
- [ ] **Step 5: Commit** `feat(media-grid): bind thumbnails before sharp images`.

### Task 4: PhotoKit filler in the demo

**Files:**
- Create: `Demo/ThumbnailFiller.swift`
- Modify: `Demo/PhotoLibraryDataSource.swift`, `Demo/DemoViewController.swift`
- Test: `Tests/ThumbnailFillerTests.swift`, through a protocol seam that fakes the PhotoKit image source

**Interfaces:**
- `PhotoLibraryDataSource` owns a `MediaGridThumbnailStore` at `<Caches>/MediaGridThumbnails/` and a `ThumbnailFiller`.
  - `thumbnail(at:)` maps the index to `localIdentifier` and then to `store.thumbnail(for:)`.
  - `prepareThumbnails` maps indices to ids and calls `store.prepare`.
  - `store.onThumbnailsChanged` maps ids back to the indices currently visible (identifier → index through the current fetch result; keep an id→index dictionary rebuilt off main per fetch result) and calls `grid.thumbnailsDidChange`.
- **Filler requests:** for ids that are missing or whose version differs (`modificationDate` as the version string), request a 96 px image with `.fastFormat`, `.exact` resize and no network access. At most 16 in flight. Write the result to the store.
- **Filler priority:**
  1. The visible range.
  2. The scrub or fling target the grid reports.
  3. Outward from the current position.
  4. The rest of the library, in grid order.
- **Throttling:** while the grid is moving fast, at most 4 requests are in flight; the remaining PhotoKit bandwidth goes to visible prepares and sharp images. When idle, the full 16 run.
- **Library changes:** on `PHChange`, inserted and changed ids are queued first, and removed ids go to `store.remove`. The id→index map is rebuilt off main, as in Task 11.
- **Removed:** Task 9b's synchronous `fastFormat` probe, its budget, the cut-off and the re-probe. `.fast`-quality jobs go from `ImageLoadScheduler` if Task 3 removed the quality. Their tests are deleted or adapted.
- **HUD:** shows `thumbs filled/total` and `empty cells this frame`. `-autoScrub`, `-level` and `-source photos` keep working. Add `-waitForFill`, which waits until the store is full before the automated run.

- [ ] **Step 1: Failing tests** with a fake image source.
  - `testFillsMissingInPriorityOrder`, `testSkipsUpToDateVersion`, `testChangedVersionRefills`, `testRemovedFreesSlot`.
  - `testThrottlesWhileMovingFast`: at most 4 in flight while fast, 16 when idle.
  - `testIdToIndexMapFollowsChanges`.
- [ ] **Step 2: Run, expect failure.** **Step 3: Implement.** **Step 4: Run, expect PASS.** Run the full suite.
- [ ] **Step 5:** Run the demo on the dedicated simulator in Photo Library mode. Record the fill time for the simulator library, the store size on disk, and the decoded-page memory.
- [ ] **Step 6: Commit** `feat(media-grid): fill the thumbnail store from the photo library`.

### Task 4b: The first screen opens sharp (Ilya, 2026-10-27)

Ilya's requirement: "При открытии первый набор фоток (те что влазят на экран), синхронно бы в хорошем качестве сразу показать, а не в маленьком". The first frame the grid shows on open has sharp images in every visible cell, not 48 px thumbnails.

**Files:**
- Create: `Sources/MediaGridLaunchCache.swift` (Photos-free)
- Modify: `Sources/MediaGridDataSource.swift`, `Sources/MediaGridView.swift`, `Demo/PhotoLibraryDataSource.swift`
- Test: `Tests/MediaGridLaunchCacheTests.swift`

**Interfaces:**
- **`MediaGridLaunchCache`** is a small persisted set of sharp images for the opening viewport. It lives in `<Caches>/MediaGridThumbnails/launch/` and is keyed by `(id, version, pixel width)`.
  - **What it covers:**
    - the newest photos (the picker opens at the top);
    - the default levels in both orientations: level 3 in portrait, level 5 in landscape;
    - one screen plus one row.
  - **Pixel size:** each image is stored at the cell pixel size of the level that needs the larger image.
  - **Storage:** one JPEG per image at quality 0.85, or a single atlas if that measures faster.
  - **Read API:**
    - `load()`: synchronous. It reads and decodes everything off main, starting as early as possible (data-source init).
    - `image(for id:, version:) -> CGImage?`: O(1) on main.
    - `waitUntilLoaded(timeout:)`: called by the grid's first layout, so the first frame is sharp. It waits at most 50 ms. Measure: with ~15–21 small JPEGs it should finish before the first layout.
  - **Refresh:** `update(entries:)` runs off main after the sharp images for the opening viewport have been delivered while the grid sat at rest at the top. It also runs when a library change touches the newest photos. It writes atomically.
- **Data source:** gains `func launchImage(at index: Int) -> MediaGridLaunchImage?`, with a default of nil.
- **Grid binding:**
  - On first bind, a cell uses the launch image if one exists, then the thumbnail. A launch image counts as sharp: no sharp request is made when its pixel size is ≥ the cell's.
  - The first layout calls the data source's wait hook.
- **No launch cache yet** (first ever open): the grid shows thumbnails, then sharp images, as today.
- **Stale entries:** a stale entry (version mismatch) is never shown.

- [ ] **Step 1: Failing tests.**
  - `testFirstLayoutShowsLaunchImagesSynchronously`: every visible cell's `contents` is a launch image after the first `layoutIfNeeded`, and there are no sharp requests for those cells.
  - `testStaleLaunchEntryIgnored`.
  - `testLaunchCacheRoundTrip`.
  - `testWaitTimesOut`: a slow decode yields thumbnails, and no hang longer than 50 ms.
  - `testRefreshAfterRestAtTop`.
  - `testLibraryInsertAtTopRefreshes`.
- [ ] **Step 2: Run, expect failure.** **Step 3: Implement.** **Step 4: Run, expect PASS.** Run the full suite.
- [ ] **Step 5:** Measure on the dedicated simulator, at a cold launch into Photo Library mode, then record a video of the cold launch and check its first frames:
  - the main-thread time spent waiting in the first layout;
  - the time from process start to the first frame;
  - whether every visible cell is sharp in the first frame.
- [ ] **Step 6: Commit** `feat(media-grid): open with sharp images for the first screen`.

### Task 5: Acceptance on recordings (Ilya's scenarios)

**Files:**
- Modify: `MediaGrid/CLAUDE.md`
- Artifacts: `.superpowers/sdd/2026-10-27-media-grid-thumbnail-store/acceptance/`

- [ ] **Step 1:** Fill the store (`-waitForFill`). On the dedicated simulator, in Photo Library mode, run each scenario with `xcrun simctl io <udid> recordVideo`, logging per-frame empty cells and frame times:
  1. pinch 3→5→15→31 and back to 3, then 3→1→3;
  2. menu Zoom Out ×3 and Zoom In ×3;
  3. a fling at 3 and at 31;
  4. a scrub from top to bottom and back at each of 1, 3, 5, 15 and 31;
  5. rotation portrait→landscape→portrait at 3;
  6. a cold launch with a full store and a launch cache: every visible cell sharp in the first frame.
- [ ] **Step 2:** Make frame sheets with `tools/animation_sheet.py` for scenarios 1, 2 and 4 at 31. Look at them.
  - Requirement: 0 empty cells in every frame, in every scenario, for filled photos.
  - No white flashes during zoom, and no bottom-up fill ("snake").
  - The store adds no dropped frames: compare against the same scenario with the store disabled.
- [ ] **Step 3:** Fix any miss found here as part of this task, with a test where the miss is grid logic. Report every number.
- [ ] **Step 4:** Update `MediaGrid/CLAUDE.md`:
  - the store's invariants (slot reuse, version, page eviction rules, never back to empty);
  - the measured numbers;
  - the Device (pending) table, with fill-time and empty-cell rows.
- [ ] **Step 5: Commit** `docs(media-grid): thumbnail store acceptance results`.
