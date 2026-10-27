# MediaGrid

Standalone layer-based photo grid on CoreList's `PhysicsScrollEngine`. Zoom levels are 1, 3, 5, 15 and 31 photos per row.

The `.xcodeproj` is generated and untracked; edit `project.yml`. The `CoreList` framework target compiles `../CoreList/CoreListDemo` with the same excludes as `CoreList/BUILD`.

```sh
cd submodules/TelegramUI/Components/MediaGrid
xcodegen generate --quiet
SIM=4FAA8C5A-1B8A-4350-9627-917227146FA2
xcodebuild -project MediaGrid.xcodeproj -scheme MediaGridDemo -destination "id=$SIM" -parallel-testing-enabled NO test
xcodebuild -project MediaGrid.xcodeproj -scheme MediaGridDemo -destination "id=$SIM" build
```

Run only on the dedicated simulator `MediaGridDemo iPhone 18 Pro 27.0` (UDID above); never on the booted logged-in simulators.

Sources import only UIKit, QuartzCore, Foundation, Photos and CoreList. No Display, AsyncDisplayKit, SwiftSignalKit, Postbox, TelegramCore or LegacyComponents. APIs newer than iOS 13 need `#available` guards, since the sources also compile in the app.

## Measuring image loading in the demo

`-source photos` opens the Photo Library, `-level N` sets the starting level, `-autoScrub` scrubs 0 → 1 → 0 (`-scrubTo F` scrubs 0 → F → F/2, `-scrubSteps N` frames per leg) and prints per-frame `empty=` counts plus a settle line with request/cancel/latency counters (`InstrumentedDataSource`). `-benchPhotos`, `-benchThroughput` and `-benchBatch` time raw PhotoKit requests. `-measureAspects` (or the "Measure aspects" button) times reading every asset's pixel size; `-driftAt F` jumps to fraction F of the content and then steps one pixel every 2 s, for checking pixel alignment from screenshots at deep offsets. `-pinchDelay S` waits S seconds after `-autoPinch` jumps to its start offset before pinching. `-autoRotate` rotates to landscape after `-rotateDelay S` seconds (default 3) and back 3 s later, first jumping to fraction `-rotateAt F` if given, and prints a `rotate` line per rotation: levels, top index, first row, `updateLayout` time and display-link frame intervals.

The dedicated simulator's PhotoKit is not a device: `.fastFormat` fails with error 3303 for every asset, opportunistic requests never deliver a degraded image first, and throughput is ~650 images/s for targets up to 240 px (111/s at 402 px) whatever the concurrency or `PHCachingImageManager` batching, with tccd and assetsd busy and the app not CPU-bound. `PHCachingImageManager` does not cache targets under ~100 px at all. Its library also holds ~11.8k iCloud-only images with no local thumbnail, so 15,776 images in all, of which the newest ~4,000 are local. Never request synchronously at any delivery mode other than `.fastFormat`: a synchronous `.highQualityFormat` request blocked the main thread for 240 s there.

## Level 1

Level 1 is `MediaGridAspectLayout`: one photo per row at its aspect ratio, clamped to 0.5 ... 2.0, with row heights floored to whole pixels and offsets accumulated in integer pixels, so deep offsets stay pixel-exact.

- Aspects come from `MediaGridDataSource.aspectRatioReader()`, a `@Sendable` snapshot that `MediaGridAspectIndex` reads off the main thread (cancelled by `reloadData`).
- The O(n) pixel prefix is a `MediaGridAspectTable` built off main once per content width, scale and spacing, and shared; constructing a layout is O(1), so pinch crossings, rebuilds and swaps do nothing proportional to the library on main.
- Until the table for the current width exists, rows use a 0.75 estimate, or the last table scaled to the new width. The exact layout replaces it only when no transition, pinch, drag, flight (`onFlightChanged(nil)` ends one in keyframe mode) or pan-to-select is in progress, keeping the top visible photo at the same fraction of its row, and only cells whose pixel size changed are re-requested.
- In a 1 ↔ 3 transition the layers also scale vertically, so the anchor photo's height morphs between the two levels instead of cross-fading between two heights.
- Level-1 rows differ in pixel size, so prefetch calls `startCaching`/`stopCaching` once per run of equal sizes.

Binding a frame's cells happens inside `MediaGridDataSource.performBatch`, so a LIFO loader starts the viewport's requests first even with free slots. A frame step longer than the viewport switches to `.fast` at once (a scrubber jump), without waiting for the 50 ms speed sample. `PhotoLibraryDataSource` redraws images of 512×512 px or more off the main thread before delivering them: committing PhotoKit's full-size level-1 images as delivered cost ~7 ms each on main.

## Library changes

`MediaGridView.apply(_ changes: MediaGridChanges)` takes `removed` (old indices), `inserted` and `changed` (new indices), called after the data source already serves the new list, in the same main-thread turn. A change whose counts do not add up reloads instead.

- The top visible photo (or, if removed, the nearest survivor, the later one on a tie) keeps its y in the viewport. At rest the offset is clamped; mid-drag or mid-flight it moves by `PhysicsScrollEngine.applyShift` (a drag is then re-anchored with `reanchorDragToCurrentPosition`, since the edge may have moved under it), so the gesture or fling continues, springing back if the new end is above it.
- A zoom transition or pinch in progress is finished first (as `reloadData` does): the data source has already swapped, so neither layout can keep binding old indices.
- Visible cells are re-keyed, not rebound; only `changed` cells, cells whose pixel size changed and inserted holes are requested. Data-source state keyed by index (the demo's prefetch keys) must be remapped by the data source before calling `apply`; the host remaps its selection the same way (`MediaGridChanges.newIndex(forOld:)`).
- Level 1: the new aspects array is built off main by `MediaGridAspectIndex.apply` from the previous one, reading only inserted and changed assets; until its table arrives the layout is the old table patched by the change log (`MediaGridAspectLayout(patches:)`, O(changed ranges) to build), inserted rows at the estimate. A newer change cancels the in-flight rebuild and restarts it from the last built aspects with all pending changes.
- The demo's `PhotoLibraryDataSource` runs `changeDetails(for:)` and `fetchResultAfterChanges` off main on a serial queue against its own last-seen fetch result, then applies each update on main in order; an update whose previous fetch result is not the current one reloads. Its prefetch remap swaps the fetch result before any prefetch resolves.

## Rotation and width changes

The host sets the frame, then calls `updateLayout(size:safeInsets:isLandscape:transition:)` (the demo from `viewDidLayoutSubviews`, with the coordinator's duration from `viewWillTransition`). The level never derives from bounds: a change of `isLandscape` moves it with `level.rotated(toLandscape:)`, and the first call only records it, so the host picks the starting level (`MediaGridLevel.defaultLevel`); the demo passes `isLandscape` only on phones, so regular width stays at its level. Left, right and bottom safe insets become content insets; the top inset stays the host's `geometryInsets.top`.

- A zoom transition or pinch is finished first; a fling is halted and a drag cancelled (its release does not fling).
- Any rebuild that changes width, side inset or scale keeps the top visible photo in the first row at the same fraction of its row; a top-inset-only change keeps visible content in place instead.
- Landing on level 1 at a width without a table uses the cached table scaled, requests the exact one off main and swaps it in by the deferred `applyAspects`, as any width change does.
- With a duration, the change crossfades (a `CATransition` fade on the grid's layer); cells are not animated frame by frame.
