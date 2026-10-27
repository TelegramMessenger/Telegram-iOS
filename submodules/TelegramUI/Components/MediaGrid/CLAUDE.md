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

`-source photos` opens the Photo Library, `-level N` sets the starting level, `-autoScrub` scrubs 0 → 1 → 0 (`-scrubTo F` scrubs 0 → F → F/2, `-scrubSteps N` frames per leg) and prints per-frame `empty=` counts plus a settle line with request/cancel/latency counters (`InstrumentedDataSource`). `-benchPhotos`, `-benchThroughput` and `-benchBatch` time raw PhotoKit requests. `-measureAspects` (or the "Measure aspects" button) times reading every asset's pixel size; `-driftAt F` jumps to fraction F of the content and then steps one pixel every 2 s, for checking pixel alignment from screenshots at deep offsets.

The dedicated simulator's PhotoKit is not a device: `.fastFormat` fails with error 3303 for every asset, opportunistic requests never deliver a degraded image first, and throughput is ~650 images/s for targets up to 240 px (111/s at 402 px) whatever the concurrency or `PHCachingImageManager` batching, with tccd and assetsd busy and the app not CPU-bound. `PHCachingImageManager` does not cache targets under ~100 px at all. Its library also holds ~11.8k iCloud-only images with no local thumbnail, so 15,776 images in all, of which the newest ~4,000 are local. Never request synchronously at any delivery mode other than `.fastFormat`: a synchronous `.highQualityFormat` request blocked the main thread for 240 s there.

## Level 1

Level 1 is `MediaGridAspectLayout`: one photo per row at its aspect ratio, clamped to 0.5 ... 2.0, with row heights floored to whole pixels and prefix offsets accumulated in integer pixels, so deep offsets stay pixel-exact. Until `MediaGridAspectIndex` has read every aspect (off the main thread, so `MediaGridDataSource.aspectRatio(at:)` must be thread-safe), rows use a 0.75 estimate; the exact layout replaces it when the view is idle at level 1, keeping the top visible photo in place. Level-1 rows differ in pixel size, so prefetch calls `startCaching`/`stopCaching` once per run of equal sizes.
