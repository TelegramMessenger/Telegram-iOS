# MediaGrid: thumbnail store

Addendum to `2026-10-27-media-picker-grid-design.md`. Status: proposed, 2026-10-27.

## Why

Ilya tested the demo in Photo Library mode, with photos already downloaded from iCloud, and the result fell short of the spec (recording: `~/Desktop/Screen Recording MediaGridDemo iPhone 18 Pro 27.0 27-10-2026 at 10.14.56.mp4`). He saw three failures:

1. **Zoom flashes white.** During a zoom transition, the incoming level's cells are white until PhotoKit delivers their images.
2. **A "snake" after a zoom-out.** When the zoom-out settles, cells fill one by one from the bottom up instead of all at once. This happens because the visible lane is LIFO and the grid binds in reading order.
3. **A fast scroll or a scrub shows a white screen.** The user can't see what they are scrolling past.

All three have one cause: every image the grid shows comes from an asynchronous PhotoKit request. PhotoKit cannot fill a screen of 15 to 2,100 cells within one frame. Tuning the scheduler, which Task 9b did, does not change that.

## Goal

Every cell shows an image in the same frame it becomes visible. That holds at every level (1, 3, 5, 15, 31) and in every motion: drag, fling, scrub, pinch, menu zoom, tap-zoom, rotation, and a library change. The one exception is a photo the store has not indexed yet.

At 15 and 31 the stored thumbnail is the final image. At 1, 3 and 5 it is a blurry placeholder, the same thing system Photos does. A sharp image replaces it when PhotoKit delivers, as today.

**Anti-goals:**
- A white cell while scrolling, for any photo that has been indexed.
- A dropped frame caused by the store.
- The store growing without bound.

## Decisions (Ilya, 2026-10-27)

- **Thumbnail size: 48 px.** Each photo is stored aspect-fit in a 48×48 px slot, with its aspect clamped to 0.5…2. At 31 a cell is about 38 px, so the thumbnail is sharp. At 15 it is about 75 px, so it is soft. At 3 and 5 it is a placeholder.
- **Storage: on disk, unencrypted**, in the app's Caches directory. It survives relaunches. The OS may purge it, and in that case it is rebuilt.
- **Placeholders at 1, 3 and 5: yes.** These levels show the blurry thumbnail straight away, then upgrade to the sharp image.

## Design (my calls, open to change)

### Store (grid module, no Photos import)

`MediaGridThumbnailStore` is keyed by an opaque `String` identifier, which for PhotoKit is the `localIdentifier`, plus a version token, which for PhotoKit is the modification date.

**Pages.** Thumbnails are grouped into pages of 16×16 slots: 768×768 px, 256 photos per page. Each page is one JPEG file (quality 0.6, padding edge-extended) of about 110 KB, measured with 256 real photos. A small index file maps each identifier to a slot and a version.
- Slots are assigned in fill order. The first fill runs in grid order, so one screen falls into a few pages: about 9 at 31, and 1 at 3.
- A deleted photo's slot is reused.
- The expected size is about 7 MB of pages for 16k photos and about 44 MB for 100k, plus an index of about 70 bytes per photo (7 MB for 100k).

**Memory.** Decoded pages are `CGImage`s of about 2.3 MB each, held in an LRU with a fixed budget. The working number is 32 pages, about 75 MB, at most. It is trimmed on a memory warning and when the app goes to the background.

**Display.** A cell shows a thumbnail by sharing its page's `CGImage` and setting `contentsRect` to the photo's tile, cropped aspect-fill to the cell's own aspect.
- There is one texture per page, not per cell, and no per-cell image creation.
- Looking up a thumbnail is O(1) on main and never touches the disk.

**Decoding.** Pages are decoded off main on a concurrent queue. The grid asks for pages ahead of need:
- the pages around the visible range and the prefetch window;
- during a scrub, the pages around the scrubber's target index, before the grid lands there;
- during a zoom, the pages of the incoming level's range when the transition begins.

  If a page is not decoded in time, the cell stays empty for the frame or two the decode takes. That case is measured, and the target is 0 frames during a normal scrub.

**Writing.**
- New tiles are drawn into an in-memory page buffer.
- Dirty pages are encoded and written off main, batched, and saved atomically.
- The index is written after its pages.
- A photo whose version changed gets its slot redrawn.

### Filler (PhotoKit side: the demo now, a real module in stage 2)

The filler fetches the same `PHFetchResult` the grid shows. For each photo missing from the store, or whose version is stale, it requests a thumbnail: about 96 px, `.fastFormat`, no network access. iCloud-only photos still have a small local thumbnail. It then resizes the image into the slot.

- **Priority.**
  1. The visible range.
  2. The scrubber or fling target.
  3. Outward from the current position.
  4. The rest of the library, in grid order.
- **Throughput.** It keeps up to 16 requests in flight at low QoS. It pauses while a fling or scrub is stealing PhotoKit's bandwidth from the visible sharp images, and runs at full speed when idle.
- **Library changes.** It handles `PHChange`: inserted and changed photos are queued at high priority, and removed photos free their slots.
- **Expected fill time.** The simulator delivers about 650 images per second, so 16k photos take about 25 seconds. A device should be several times faster. This gets measured.

### Grid integration

The data-source protocol gains an optional synchronous method:

```swift
func thumbnail(at index: Int) -> MediaGridThumbnail?    // { image: CGImage, contentsRect: CGRect }
func prepareThumbnails(indices: Range<Int>, priority: ...)  // page decode ahead
```

Both have default implementations, so `SyntheticDataSource` and `TestDataSource` keep working.

- **Binding a cell.** The grid first sets the thumbnail, synchronously, then requests the sharp image as today. It skips the request when the cell's pixel size is at most about 1.25× the thumbnail, which is levels 15 and 31.
- **Upgrading to the sharp image.** The upgrade happens only when the delivered image arrives. A cell never goes back to white. A degraded image replaces the thumbnail only if it is larger.
- **Zoom.** The incoming level is bound with thumbnails before the first transition frame. The pages for its range are requested when the pinch begins.
- **Moving fast.** While the grid moves fast it binds thumbnails only, with no PhotoKit requests for the viewport. Sharp requests start when motion settles, which keeps Task 9b's 0.12 s delay. This replaces the `.fast`-quality PhotoKit path from Task 9b.

### What happens to Task 9b's machinery

The scheduler keeps its role for sharp images: prefetch, cancel coalescing, and the network lane. The synchronous `fastFormat` probe and the `.fast` request quality are removed. The thumbnail store replaces them.

## Verification

Ilya's recording is the acceptance test. The demo is run on the dedicated simulator against the same library, with the store filled, through these scenarios:

- pinch through every level and back;
- the menu Zoom In and Zoom Out;
- a fling at 3 and at 31;
- a scrub from top to bottom at 3, 5, 15, 31 and 1;
- a rotation.

Each scenario is recorded with `simctl recordVideo`, and every frame is checked with `tools/animation_sheet.py` plus a per-frame count of empty cells. The requirement is 0 empty cells in every frame for indexed photos, and no dropped frames that the store causes.

Also measured:
- the fill time;
- the store's size on disk and in memory;
- the page decode time;
- the time to the first frame on a cold open, with the store already filled.

## Not in scope

- Encrypting the store.
- Sharing it with the app's other photo pickers.
- Faces and search.
