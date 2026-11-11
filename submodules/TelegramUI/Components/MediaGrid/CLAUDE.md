# MediaGrid

Standalone layer-based photo grid on CoreList's `PhysicsScrollEngine`. Zoom levels are 1, 3, 5, 15 and 31 photos per row.

The `.xcodeproj` is generated and untracked; edit `project.yml`. The `CoreList` framework target compiles `../CoreList/CoreListDemo` with the same excludes as `CoreList/BUILD`.

```sh
cd submodules/TelegramUI/Components/MediaGrid
xcodegen generate --quiet
SIM=4FAA8C5A-1B8A-4350-9627-917227146FA2
xcodebuild -project MediaGrid.xcodeproj -scheme MediaGridDemo -destination "id=$SIM" -parallel-testing-enabled NO -collect-test-diagnostics never test
xcodebuild -project MediaGrid.xcodeproj -scheme MediaGridDemo -destination "id=$SIM" build
```

`-collect-test-diagnostics never` keeps a failing run from sitting in `simctl diagnose`. CoreList's suite (the engine is shared) runs the same way from `../CoreList`: `xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo -destination "id=$SIM" -parallel-testing-enabled NO -collect-test-diagnostics never test`. Expected: MediaGridTests 299 tests (2 skipped), MediaGridPhotoLibraryTests 73, CoreList 1048 (unchanged, not re-run in Task 5), 0 failures.

Run only on the dedicated simulator `MediaGridDemo iPhone 18 Pro 27.0` (UDID above); never on the booted logged-in simulators.

Sources import only UIKit, QuartzCore, Foundation, Photos and CoreList. No Display, AsyncDisplayKit, SwiftSignalKit, Postbox, TelegramCore or LegacyComponents. APIs newer than iOS 13 need `#available` guards, since the sources also compile in the app.

The PhotoKit loading stack (`ImageLoadScheduler`, `MediaGridPhotoLibraryDataSource`, the filler, the launch-match glue) is the sibling module `../MediaGridPhotoLibrary` (Bazel target and an xcodegen framework target here, with its own `MediaGridPhotoLibraryTests`). `MediaGridPhotoLibraryServices.shared` owns the app-session store, filler and launch cache under `<Caches>/MediaGridThumbnails/`; tests inject temporary directories and never touch `shared`. A data source maps grid index `i` to fetch index `count - 1 - i` when `reversed` (Recents, newest first; the demo) and to `i` otherwise (an album). Only a data source given the filler (`isLibrary`) drives it: its catalog decides which stored ids are orphans, so never give the filler an album's data source.

## Stage 2: the app's photo picker

The chat attachment menu's photo picker runs on this grid (see `submodules/MediaPickerUI/CLAUDE.md` for the seam and the killswitch). Host API it relies on:


`MediaPickerUI`'s `MediaPickerMediaGridHost` embeds the grid. What it relies on: `headerView`/`headerHeight` (a region above the first row, inside the content, after `geometryInsets.top`); `scrollToTop(animated:)` (a display-link ease-out, jumping first to at most two screens away); `scrollToEnd()` (also before the first layout); `onWillBeginDragging`/`onDidEndDragging`; `onSelectionPanBegan`; `onTapItemAt` (index and point); `onZoomingChanged`/`isZooming`; `compactLevelTopInset` (the content top inset at 15 and 31, which then also hide `headerView`; each layout carries its own geometry, so zooms stay anchored and a top-inset change at a compact level rebuilds nothing); `onTargetLevelChanged`/`targetLevel` (the level a release would land on, live during a pinch, at the start of a tap or menu zoom, and the final level at its end); `cameraView` (two reserved slots at top-left at level 3 only, in portrait and landscape alike; a zoom to or from 3 fades it by alpha, and 1, 5, 15 and 31 flow photos into its place) and `isCameraVisible`; `bounces` (off clamps the top while dragging, re-anchoring the drag); `reanchorDrag()`; `holdsDragAtTop`/`endDragHold()` (the attachment sheet holds the grid's drag at the top while the sheet moves, and a held drag never flings); `overlayView` and `contentFrameForItem(at:)` (views in content coordinates above the cells); `MediaGridCellLayer.displayedImage`. `setContentOffset` mid-drag shifts the drag instead of cancelling it. `MediaGridPhotoLibraryServices.configureLaunchCoverage` injects the launch screen until the cache exists (the app passes the main window's screen). `reloadImages(at:)` re-requests the images of the given visible cells (edited thumbnails) without touching layout, a pinch or a zoom; `forEachCell` also walks a zoom transition's incoming cells. The tap and pan-to-select recognizers ignore touches in `headerView` and `cameraView`, so buttons there get their touch-up. Every other picker mode runs with `isZoomEnabled = false` and relies on `cellAspect` (stories), `cameraLevels` (the camera's levels, default `[.three]`; `[.three, .five]` keeps it in landscape), `accessoryView` (one reserved slot at row 0, right of the camera or first without one, at `accessoryLevels`, default 3 and 5; hidden during a zoom transition; its touches are its own) and `isSelectionPanEnabled`. The store's `onThumbnailsChanged` has one owner (`hookOwner`): the latest data source; the owner's deinit clears it, an older one's does not.

## Hosts other than the picker

The profile's Media tab (`PeerInfoMediaGridPaneNode`) also relies on: `availableLevels` (the levels pinch, menu zoom,
tap zoom, prefetch neighbours and rotation step through; default all five; setting it moves the current level to the
nearest available one); `compactLevelsRequestSharpImages` (15 and 31 request sharp images and prefetch like 3 and 5;
compact detail is otherwise unchanged); `visibleIndexRange` / `onVisibleRangeChanged` (indices intersecting the
viewport, reported once per change from every binding pass); `transferVelocity(_:)` (a grid-owned display-link decay
with SparseItemGrid's formula, not a CoreList fling, since `PhysicsScrollEngine` has no public launch); and
`isScrollingLockedAtTop` (offset 0 and the pan off; zoom endings and the selection pan respect it); `MediaGridCellLayer.isBinding`
(true while the grid binds the cell, including image completions delivered synchronously from `requestImage`, so a
subclass can animate only late arrivals); `MediaGridCellLayer.imageRequestTime` (when the grid last asked for the cell's
image; the Media tab shows an image that arrives within 100 ms of it, a disk cache hit, without its crossfade).

The picker also uses `zoomContentMinY` (during a zoom, the top of the visible cells of both layers in view coordinates;
nil outside a zoom) with `onZoomFrame` (each pinch step and the start and end of a zoom): its bar treats content as
under it when cells rise above their resting top during a zoom, at any level.

## Measuring image loading in the demo

`-source photos` opens the Photo Library, `-level N` sets the starting level, `-autoScrub` scrubs 0 → 1 → 0 (`-scrubTo F` scrubs 0 → F → F/2, `-scrubSteps N` frames per leg) and prints per-frame `empty=` counts plus a settle line with request/cancel/latency counters (`InstrumentedDataSource`). `-benchPhotos`, `-benchThroughput` and `-benchBatch` time raw PhotoKit requests. `-frameLog` prints one `FRAME` line per display-link frame (interval, level, zoom in progress, empty cells, `filled_empty` = empty cells whose photo is in the store, and every 15th frame `unfilled` = visible photos not in the store); `-noThumbnails` turns the store off (no thumbnails, no prepare, no network lane) for a baseline; `-startAt F` jumps to fraction F after 1 s; `-noLaunchCache`, `-fillLog` (a `FILL_PROGRESS` line every 10 s) and `-waitForFill` as their names say. `-measureAspects` (or the "Measure aspects" button) times reading every asset's pixel size; `-driftAt F` jumps to fraction F of the content and then steps one pixel every 2 s, for checking pixel alignment from screenshots at deep offsets. `-pinchDelay S` waits S seconds after `-autoPinch` jumps to its start offset before pinching. `-autoRotate` rotates to landscape after `-rotateDelay S` seconds (default 3) and back 3 s later, first jumping to fraction `-rotateAt F` if given, and prints a `rotate` line per rotation: levels, top index, first row, `updateLayout` time, display-link frame intervals, each slow frame's time after `updateLayout`, and the duration of the main-thread turn that starts the rotation with the image requests issued in it (`turn_requests`).

The dedicated simulator's PhotoKit is not a device: `.fastFormat` fails with error 3303 for every asset, opportunistic requests never deliver a degraded image first, and throughput is ~650 images/s for targets up to 240 px (111/s at 402 px) whatever the concurrency or `PHCachingImageManager` batching, with tccd and assetsd busy and the app not CPU-bound. `PHCachingImageManager` does not cache targets under ~100 px at all. Its library holds 15,776 images; ~9.6k had no local bytes at all, because iCloud background download is blocked there (`constrainedNetwork`), so no delivery mode works for them without network. The demo's network lane (below) makes them local at ~1.7/s while the grid is idle: 13,042 of 15,776 were in the store when Task 5's runs ended (from 10,441 at their start), not converged. Never request synchronously at any delivery mode other than `.fastFormat`: a synchronous `.highQualityFormat` request blocked the main thread for 240 s there.

## Level 1

Level 1 is `MediaGridAspectLayout`: one photo per row at its aspect ratio, clamped to 0.5 ... 2.0, with row heights floored to whole pixels and offsets accumulated in integer pixels, so deep offsets stay pixel-exact.

- Aspects come from `MediaGridDataSource.aspectRatioReader()`, a `@Sendable` snapshot that `MediaGridAspectIndex` reads off the main thread (cancelled by `reloadData`).
- The O(n) pixel prefix is a `MediaGridAspectTable` built off main once per content width, scale and spacing, and shared; constructing a layout is O(1), so pinch crossings, rebuilds and swaps do nothing proportional to the library on main.
- Until the table for the current width exists, rows use a 0.75 estimate, or the last table scaled to the new width. The exact layout replaces it only when no transition, pinch, drag, flight (`onFlightChanged(nil)` ends one in keyframe mode) or pan-to-select is in progress, keeping the top visible photo at the same fraction of its row, and only cells whose pixel size changed are re-requested.
- In a 1 ↔ 3 transition the layers also scale vertically, so the anchor photo's height morphs between the two levels instead of cross-fading between two heights.
- Level-1 rows differ in pixel size, so prefetch calls `startCaching`/`stopCaching` once per run of equal sizes.

Binding a frame's cells happens inside `MediaGridDataSource.performBatch`, so a LIFO loader starts the viewport's requests first even with free slots. A frame step longer than the viewport switches to moving fast at once (a scrubber jump), without waiting for the 50 ms speed sample. `MediaGridPhotoLibraryDataSource` redraws images of 512×512 px or more off the main thread before delivering them: committing PhotoKit's full-size level-1 images as delivered cost ~7 ms each on main. The queued redraw is skipped when the job has meanwhile lost its consumers, finished or restarted (`Job.hasConsumers(running:)`, a lock-guarded snapshot readable off main).

## Thumbnails

`MediaGridDataSource.thumbnail(at:)` (main, O(1)) and `prepareThumbnails(ranges:)` (both defaulted) feed a 48 px placeholder per cell; the grid stays index-based and never sees `MediaGridThumbnailStore`.

- Binding sets the thumbnail synchronously (`setThumbnail`: the page image as `contents`, the slot cropped aspect-fill as `contentsRect`), then requests the sharp image unless the cell shows a thumbnail at a compact level (15, 31) or its longer pixel side is at most 1.25 × the thumbnail's. Without a thumbnail it requests as before.
- `setImage` replaces a thumbnail only with an image wider in visible pixels; a final image that is not is still marked final. Over a sharp image, a degraded image must be wider than what is shown (capped at the cell's pixel width) and a final one at least as wide; a changed photo's stale image accepts anything. A cell never returns to empty: only reuse for an index whose page is not decoded yet leaves it empty, until `thumbnailsDidChange(indices:)` fills it (the demo HUD's `empty` line counts those).
- While moving fast (above 2 screens/s, or a frame step over a screen), during a rotation's deferred binding, cells get thumbnails only and are marked `isAwaitingSharpImage`; the 0.12 s settle (or the deferred binding's run-loop wake) requests them, viewport last and top-left last of all. Sharp prefetch (`startCaching`) pauses while moving fast and does not run at 15 and 31.
- A zoom's incoming cells get thumbnails before the first transition frame, and take the outgoing cell's sharp image for the same index when it is wider and at most 2× the incoming cell's pixel width (3 → 1 keeps sharpness; 1 → 3 and 3 → 15 do not carry oversized images). A kept image over 2× asks for a right-sized one at 1, 3 and 5 and falls back to the thumbnail at 15 and 31. A rebind for a new pixel size keeps a final image final.
- Cells leaving the window are reassigned in place to the indices entering it (request cancelled, token bumped, no hide/unhide, `contents` replaced by the new thumbnail); only the surplus goes to the pool.
- Cell subclass contract: `prepareForReuse()` (empty in the base) is where a subclass resets per-photo state. It runs on every change of photo, both for a cell going to the pool (after which the base clears the image) and for one reassigned in place (which keeps its image until the new thumbnail replaces it), so it must not rely on the cell being empty afterwards; `bind(index:detail:)` follows. The grid's own binding state is reset separately, before `prepareForReuse`. `apply(_:)` re-keys a cell to the same photo's new index with `bind` alone, no `prepareForReuse`. Binding runs with actions disabled. At 15 and 31 the binding window has no margin while moving fast.
- `thumbnailsDidChange` refreshes only visible cells showing nothing or a thumbnail; a sharp cell refreshes through `apply`'s `changed`. At a compact level the arrival also cancels a pending sharp request.
- `prepareThumbnails(ranges:)` gets one complete, disjoint, most-important-first list, sent only when it changes; the store replaces its queue with it, caps it at the decoded-page budget and returns early when the page list is unchanged. The list: the viewport; while moving fast the viewports one and two scrub steps ahead (a step that lands after a dropped frame moves twice as far; with one step only, a whole frame at 15 went white); at rest (or in a pinch) both neighbour levels' target viewports (the pinch anchor, else the centre); the binding window; the fling target; one screen above and below (dropped while moving fast at 15 and 31). During a transition: the incoming bound range, the incoming final viewport, the outgoing range.

## Zoom crossfade

The denser level (more columns) sits below the sparser one and stays opaque while the sparser one fades; it fades out only over the sparser level's last quarter (`denseFadeStart` 0.75), so neither end shows one level's cells in the other's gaps and at most ~4% of the background shows through. Animated transitions get the same curve as opacity keyframes sampled along the transform's spring. With the old complementary fade every zoom brightened by 17–23 luma on the synthetic grid (a quarter of the white background at mid-transition); now ≤ 4 on synthetic and ≤ 5 on the Photo Library.

## Thumbnail store, filler and launch cache

- Store (`MediaGridThumbnailStore`): 48 px slots aspect-fit (clamped 0.5…2, edge-extended padding) in 16×16 pages of 768 px, JPEG q0.6, `<Caches>/MediaGridThumbnails/`. Slots go in write order; a removed id's slot is reused, and a reused slot never shows the old photo (the writer draws into the page; installs need a generation ≥ the held one). The version is the asset's modification date; a new version redraws the slot. Page files are written atomically under a new stamp and the old one is deleted only after an index without it is on disk. Decoded-page budget 32 (28 images + 4 writer contexts), LRU, never evicting a page with unflushed writes; memory warning and background trim to the visible pages. A bound cell never goes back to empty; the one exception is reuse for an index whose page is not decoded yet.
- Filler (`MediaGridPhotoLibrary`): local `.fastFormat` 96 px, 16 in flight idle / 4 moving fast; misses retry after 30 s, 2 min, 10 min, then next launch (re-queued 30 s after launch, 256/s). The network lane: 2 in flight, only while idle and the sharp network lane is idle, cancelled when sharp network work appears, `.highQualityFormat` 96 px; final sharp deliveries are also harvested into the store.
- Launch cache (`MediaGridLaunchCache`, `<Caches>/MediaGridThumbnails/launch/launch.cache`): the newest photos, one screen plus one row at the default level in both orientations (24 at 522 px on an 18 Pro), JPEG q0.85, refreshed from delivered sharp images only at rest at the top. Coverage is the delivered image's short side; an entry is shown only on an id and version match, and a cell makes no sharp request when coverage ≥ its pixel width. The first layout waits at most 50 ms (`launchImageWait`). In the app, start loading it when the attach menu begins presenting; decoded it is about 26 MB on a device (24 × 522² × 4 B).

## Uniform levels

Columns of `MediaGridUniformLayout` start at pixel-rounded `leftInset + c × (contentWidth + spacing) / columns`, so widths differ by at most one pixel and the row fills the content width exactly (the last column used to take the remainder: 23 pt against 30 pt at 31 in landscape). Row height comes from the nominal floored width. `pixelSize(at:)` is the widest column's pixel size for every cell, so a level keeps one image size per asset and one caching run.

## Library changes

`MediaGridView.apply(_ changes: MediaGridChanges)` takes `removed` (old indices), `inserted` and `changed` (new indices), called after the data source already serves the new list, in the same main-thread turn. A change whose counts do not add up reloads instead.

- The top visible photo (or, if removed, the nearest survivor, the later one on a tie) keeps its y in the viewport. At rest the offset is clamped; mid-drag or mid-flight it moves by `PhysicsScrollEngine.applyShift` (a drag is then re-anchored with `reanchorDragToCurrentPosition`, since the edge may have moved under it), so the gesture or fling continues, springing back if the new end is above it.
- A zoom transition or pinch in progress is finished first (as `reloadData` does): the data source has already swapped, so neither layout can keep binding old indices.
- Visible cells are re-keyed, not rebound; only `changed` cells, cells whose pixel size changed and inserted holes are requested. Data-source state keyed by index (the demo's prefetch keys) must be remapped by the data source before calling `apply`; the host remaps its selection the same way (`MediaGridChanges.newIndex(forOld:)`).
- Level 1: the new aspects array is built off main by `MediaGridAspectIndex.apply` from the previous one, reading only inserted and changed assets; until its table arrives the layout is the old table patched by the change log (`MediaGridAspectLayout(patches:)`, O(changed ranges) to build), inserted rows at the estimate. A newer change cancels the in-flight rebuild and restarts it from the last built aspects with all pending changes.
- `MediaGridPhotoLibraryDataSource` runs `changeDetails(for:)` and `fetchResultAfterChanges` off main on a serial queue against its own last-seen fetch result, then applies each update on main in order; an update whose previous fetch result is not the current one reloads. Its prefetch remap swaps the fetch result before any prefetch resolves.

## Rotation and width changes

The host sets the frame, then calls `updateLayout(size:safeInsets:isLandscape:transition:)` (the demo from `viewDidLayoutSubviews`, with the coordinator's duration from `viewWillTransition`). The level never derives from bounds: a change of `isLandscape` moves it with `level.rotated(toLandscape:)`, and the first call only records it, so the host picks the starting level (`MediaGridLevel.defaultLevel`). The host owns the `isLandscape` decision: phones of every size, Plus and Max included, pass `true` in landscape; iPad passes `false` in both orientations, so its level stays put (the demo: `idiom == .phone && width > height`). Left, right and bottom safe insets become content insets, the left and right ones each on its own side (`MediaGridGeometry.leftInset`/`rightInset`): iPhone Duo's side strip is on one side only, and taking the larger inset on both sides squeezed the attachment menu's grid into a band 84pt short of the screen's (#83); the top inset stays the host's `geometryInsets.top`.

- A width, side-inset or orientation change finishes a zoom transition or pinch first, halts a fling and cancels a drag (its release goes through `shouldStopScrollingOnRelease` at zero velocity, so no flight launches). A bottom-inset-only change just relayouts, keeping any motion.
- Any rebuild that changes width, side inset or scale keeps the top visible photo in the first row at the same fraction of its row; a top-inset-only change keeps visible content in place instead, by `applyShift` while dragging or flinging so the motion continues. A layout pass never clamps a drag that is rubber-banding past the end. The anchor (index, fraction) is remembered with the offset it produced and reused while the offset is unchanged, so 3 → 5 → 3 returns the same top index; any scroll, zoom, pinch, library change or reload drops it.
- A level change from rotation rebuilds at once, even before the host's frame catches up, so `level`, the layout and `apply(_:)` never disagree; the later frame change rebuilds again from the remembered anchor.
- Landing on level 1 at a width without a table uses the cached table scaled, requests the exact one off main and swaps it in by the deferred `applyAspects`, as any width change does.
- With a duration (and a window), the change crossfades (a `CATransition` fade on the grid's layer; cells are not animated frame by frame), and the sharp requests of newly visible or resized cells plus prefetch wait for the run loop's next wake (a one-shot `afterWaiting` observer, followed by `CFRunLoopWakeUp`), so the rotation's first commit carries only layout and thumbnails. While that is pending, any layout pass (the grid's own `layoutSubviews` included) binds thumbnails only. `DispatchQueue.main.async` is not enough for this: the main queue is drained before the same turn's `beforeWaiting`, so its binding landed in the first commit. Photo Library, 4 runs each: the first turn issued 18 (1 → 3) and 45 (3 → 5) image requests and took 18.5–22.1 ms (1 → 3) and 9.0–15.4 ms (3 → 5) before; with the observer it issues none and takes 9.5–14.8 ms (1 → 3) and 8.7–14.3 ms (3 → 5). `updateLayout` itself is 0.5–0.9 ms at level 1 and about 0.17 ms at 3. The rest of that turn is UIKit's rotation setup.

## Invariants worth knowing

- The CoreList surface MediaGrid depends on (`PhysicsScrollEngine`, `ScrollFlight`, `applyShift`, `reanchorDragToCurrentPosition`, `shouldStopScrollingOnRelease`, `isScrollEnabled`) is listed, with the reasons, in `../CoreList/CLAUDE.md`. CoreList's behaviour is unchanged.
- In keyframe mode only `onFlightChanged(nil)` ends a fling.
- Images, the memory cache and the scheduler's jobs are keyed by `PHAsset.localIdentifier`, never by index, so library changes and re-keyed cells keep their images. Index-keyed state (prefetch keys) is remapped by the data source.
- `performBatch` is part of `MediaGridDataSource` (with a default); the app's data source needs the same viewport-first batching and large-image redraw as the demo's.

## Measured results (simulator only)

`MediaGridDemo iPhone 18 Pro 27.0`, debug build, 60 Hz. The simulator's PhotoKit is not a device's (see above), so these are functional checks and not the success measures.

- Scrub `-scrubTo 0.05`/`0.2`, 120 steps per leg: 0 dropped frames. Cells without an image: level 3 0/240 frames; level 1 0/240 in 5 of 9 runs and 1/240 in the rest (step 1 after a jump of 3.6 screens, PhotoKit's first image takes up to 15 ms here).
- Pinch crossings `-autoPinch`: 1.2 to 5.5 ms of main-thread work per crossing, worst frame 16.7 ms, no drops (Photo Library and Synthetic).
- Rotation (Photo Library, 1 → 3 and 3 → 5, 4 runs each): first main-thread turn 8.7–14.8 ms with no image requests in it, 0 dropped frames in all 8 runs (3 in 8 before the binding moved past the first commit); `updateLayout` 0.16–0.9 ms.
- Scrub `-scrubTo 0.2`, 120 steps per leg (1.4 screens per frame at level 3), 3 runs, measured before the thumbnail-store redesign: empty visible-cell fraction L1 0–0.003, L3 0.63–0.70, L5 0.45, L15 0.35–0.45, L31 0.67–0.69, 0 dropped frames, settle 83–133 ms (L3/L5), 117–350 ms (L15), 2.75–2.82 s (L31). Synthetic default scrub: L15 0 dropped; L31 3, 6 and 7 dropped frames, worst 50–54 ms, `setContentOffset` up to 6.3 ms.
- Task 5 acceptance (Photo Library, store 12.1k–13.0k of 15.8k, `-frameLog`; artifacts in `.superpowers/sdd/2026-10-27-media-grid-thumbnail-store/acceptance/`): pinch 3→5→15→31→15→5→3→1→3, 0 frames with an empty stored photo during the gestures (one frame of 24 at the programmatic `-startAt` jump before them), 4 dropped of 5,763, worst 48.5 ms (two at 31 ↔ 15 transitions); scrub top→bottom→top in 90 steps per leg, L3 and L31, 3 runs each, 0 empty stored photos, L3 0–1 and L31 0 dropped, worst 33.3 ms; cold launch with the launch cache, first grid frame at 459 ms with 0/16 empty, 24/24 launch entries matched, main-thread wait 13.9 ms, the first frame showing the settled sharp images; a replay of Ilya's sequence (pinch to 15, fling, scrubber drag, pinch back, fling) 0 empty stored photos after the two-step fix (before it, one white frame of 481/510), 2 dropped, worst 35.8 ms. Synthetic: pinch sequence 0 empty, 0 dropped; menu zoom out ×3 / in ×3 0 empty, 1 dropped (33 ms at 15 → 31, the same with `-noThumbnails`); scrub at 1–31 0 empty, 0 dropped except 1 at 31 (also 1 with `-noThumbnails`). Probe off (no `-mainProbe`), 4× scrub at L31: 0–1 dropped of 60 in 5 runs, one run with 3 empty frames (synthetic pages still rendering at the start).
- With thumbnails (Synthetic 100k, generated pages decoded off main): default `-autoScrub` at 1, 3, 15 and 31, 0 empty frames of 240 and 0 dropped frames in every run; `-autoPinch` 0 empty frames, 0 dropped. A 4× faster scrub (`-scrubSteps 30`, L31; with `-mainProbe` the `AUTOSCRUB` line's `main_avg`/`main_worst` is `setContentOffset` plus a forced commit): 0–1 dropped of 60 in 6 debug and 3 `-O` runs (empty frames 0, one debug run 13), main 5.3–6.9 ms/frame debug and 5.2–5.7 ms `-O`; before in-place reassignment and the other per-cell savings it was 15–23 dropped and 7.8–8.6 ms debug, 0–1 dropped and 6.7–7.5 ms `-O`. `-O` here means `SWIFT_OPTIMIZATION_LEVEL=-O` on the Debug configuration.

## Device (pending)

Dropped frames and worst frame from the demo's HUD, on a real device. Fill in before stage 2.

| Gesture | Real library | Synthetic 100k |
|---|---|---|
| Fling | | |
| Scrub top to bottom and back | | |
| Pinch through all levels | | |
| Store fill time (local, then network) | | — |
| Empty stored photos per frame, L1 / 3 / 5 / 15 / 31 | | |
| Cold launch: first grid frame, empty cells, launch wait | | — |
