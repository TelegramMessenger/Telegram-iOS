# Media picker grid: a layer grid on the CoreList scroll engine, with Photos-style zoom

Date: 2026-10-27. Status: approved by Ilya 2026-10-27.

## Intent

`MediaPickerScreen` is slow in three places: opening, fast scrolling, and above all scrolling with the date
scrubber. The grid it is built on (`GridNode` + one `ASDisplayNode` tree per cell) is the cause, not the
photo library. We replace it with a new grid that:

- does not use `GridNode` and does not use `ASDisplayNode` for cells;
- scrolls on the CoreList scroll engine, whose flicks are baked and played by Core Animation on the render
  server instead of being stepped on the main thread;
- adds Photos-style zoom: pinch, and Zoom In / Zoom Out menu items, changing how many photos sit in a row.

The grid is built first as a standalone component with its own demo app, so it can be iterated without
building Telegram. Moving `MediaPickerScreen` onto it is a second stage.

## Why it is slow today (measured by reading the code, 2026-10-26)

Line references are to the tree as read on 2026-10-26 (branch `chat-media-editor-stage6` at `2a092b2527`).

- **Scrubber.** `scrollingArea.setContentOffset` hops to a concurrent queue, goes through a 0.05 s
  `mapToThrottled`, then back to main (`MediaPickerScreen.swift:796-831`). The grid therefore jumps at most
  ~20 times a second, each time by many screens, and every jump destroys every visible cell and builds
  30-45 new ones. The scrubber's date comes from an arbitrary visible cell (dictionary order), read from
  `PHAsset.creationDate` on main for every fresh cell.
- **Scrolling.** `GridNode` finds visible items with a linear scan from item 0 on every scroll tick
  (`GridNode.swift:821-834`), so a frame costs more the deeper the user is. Cells are never reused: each
  new one is ~10 nodes and 5-7 signal subscriptions, bound on main (`MediaPickerGridItem.swift:437-700`),
  which allocates `TGMediaAsset` several times, redraws the favourite icon, reads the type via KVC and lays
  out an attributed duration string. Thumbnails use `.opportunistic` (two deliveries), each routed through
  the main queue and then a display link, and `PHCachingImageManager.startCachingImages` is never called.
- **Opening.** 13 entries are shown first; 0.5 s later a full N-entry array is built, diffed 13 → N, and N
  `GridItem`s created, while `GridNode` lays out all N, during the attachment sheet's animation. The asset
  fetch itself runs on main.

## Goals

1. Fast open, smooth fast scroll and smooth scrubbing on a large library (tens of thousands of assets).
2. Zoom levels **1, 3, 5, 15, 31** photos per row, default **3** in portrait and **5** in landscape.
3. Interactive pinch between levels, able to pass through several levels in one gesture, and menu items
   Zoom In / Zoom Out that step one level with an animation.
4. A standalone grid component plus a demo app that exercises it at scale.
5. Second stage: `MediaPickerScreen` on the new grid with every current feature preserved.

## Non-goals

- Changing what the picker does beyond the zoom: selection rules, editing, sending, albums, drafts stay.
- Replacing the scrubber's look. The existing `SparseItemGridScrollingArea` stays; only its wiring changes.
- Horizontal scrolling, trackpad-specific polish, scroll-to-top on status-bar tap (the engine has none;
  revisit only if the picker needs it).
- Generalising `CoreVirtualListView` into a grid. It is a 1-D list with diff transactions, unknown total
  height, no view reuse and a per-frame jump clamp; none of that fits. Only its scroll engine is used.
- Changing `SparseItemGrid` (shared media). Its zoom and layout ideas are reused by re-implementation, not by
  modifying it.

## Anti-goals (would be a failure even if it technically works)

- Scrubbing or flinging that still drops frames on a large library on device.
- Any marker, badge or checkbox drawn at 15 and 31 per row.
- Breaking the attachment sheet's drag-to-dismiss / expand hand-off, or the transitions into the gallery
  and media editor, during stage 2.
- The grid component depending on Telegram modules (Display, AsyncDisplayKit, SwiftSignalKit, Postbox,
  TelegramCore, LegacyComponents). It depends on UIKit, QuartzCore, Photos and the scroll engine only.

## Behaviour (decided with Ilya)

### Zoom levels

| Photos per row | Cell shape | Selection | Tap | Camera |
|---|---|---|---|---|
| 1 | each photo at its own aspect ratio, clamped to 2:1 … 1:2, overflow cropped (aspect fill) | checkbox, tap, pan-to-select | opens the viewer | hidden |
| 3 (portrait default) | square | checkbox, tap, pan-to-select | opens the viewer | shown, 1 column × 2 rows at top-left |
| 5 (landscape default) | square | checkbox, tap, pan-to-select | opens the viewer | shown, 1 column × 2 rows at top-left |
| 15 | square | none | zooms in one level (to 5), keeping the tapped photo under the finger | hidden |
| 31 | square | none | zooms in one level (to 15), keeping the tapped photo under the finger | hidden |

- Zoom is enabled only in the attachment-menu picker for now. Every other mode (stories, avatar, stickers,
  wallpapers, album views opened elsewhere, the attachment carousel) stays at its current single layout
  with zoom off. The grid still supports a non-square cell aspect and more than one cutout, because story
  mode (`itemWidth × 1.227`) and the avatar preview need them at their one level; it does not need them to
  vary per zoom level.
- "Hidden" for the camera means it fades out by alpha as the zoom transition runs; where it is hidden the
  photos flow into its place (no empty hole). *My call* — Ilya said "hide it by alpha" and did not say
  whether its space stays. The shift this causes in the index-to-cell mapping is harmless: the pinch and
  tap anchors are a photo index, resolved to a frame in each layout, never a cell position. Rows fill in
  index order from the top; the last row is the partial one.
- Tap at 15/31 steps one level, not straight to a selectable level. *My call*; Ilya said "just zoom into
  the tapped place".
- The picker opens at the orientation's default every time; the level is not remembered. *My call*, stated
  to Ilya and not contradicted.
- Orientation (Ilya): the level set is the same 1, 3, 5, 15, 31 in both orientations; the **default is 3 in
  portrait and 5 in landscape** on a phone, and landscape can still go to 3 and 1.
- On rotation the level moves by the same step the default moves: portrait 3 ↔ landscape 5, portrait
  1 ↔ landscape 3, portrait 5 ↔ landscape 15, portrait 15 ↔ landscape 31, and 31 stays 31 (and landscape
  1 goes to portrait 1). The photo at the top of the screen is kept in view across the rotation. *My call.*
- iPad (regular width) behaves as portrait: default 3, same levels. *My call*; today it is 3 there.
- At 15 and 31 nothing marks selected photos. No checkbox, no tint, no border.
- Level 1 behaves like 3 and 5 in every respect except layout.

### Pinch

As in Photos and in `SparseItemGrid` (`submodules/SparseItemGrid/Sources/SparseItemGrid.swift:1430-1625`,
`1786-1944`), re-implemented on the new grid:

- the photo under the pinch centre stays under the fingers;
- the outgoing and incoming layouts are both present, scaled about the anchor and cross-faded;
- one gesture can chain through several levels; on release it settles to the nearer level with an
  animation that continues the gesture's velocity.

The transition between 3 and 1 morphs square cells into aspect-ratio rows; the cross-fade covers it, and a
per-cell frame morph for the photos visible in both layouts is preferred if it is cheap.

### Menu

Zoom In / Zoom Out items, each one level, disabled at the ends. Where they live in the picker's menu is
decided in stage 2; in the demo they are buttons.

## How it is built (decided)

### Scroll engine: CoreList's, not the list

`submodules/TelegramUI/Components/CoreList/CoreListDemo/` contains a scroll engine separate from the list:
`ScrollEngine` (protocol), `PhysicsScrollEngine`, `PhysicsScrollCore`, `ScrollPhysics/` (a replica of
UIScrollView physics), `Trajectory`, `KeyframeFlight`, `PhysicsPanGestureRecognizer`. Chat history runs on
`PhysicsScrollEngine` in `.keyframe` mode in production. There is also a standalone `PhysicsScrollView`
(a plain `UIView` with `contentView` + `contentHeight`) that uses the physics without the list.

The grid uses that engine in `.keyframe` mode. Consequences the builder must honour:

- During a flight the content is moved by the render server; the main thread's `offset` is sampled once per
  frame and can lag. Anything positioned against scroll (visible range, prefetch) composes against the
  published `ScrollFlight`, as CoreList does.
- The flight's resting offset is known at release. Use it: start `PHCachingImageManager` caching for the
  landing window immediately, and keep cells bound ahead of the presented position along the path.
- These types are `internal` to the `CoreList` module today. Expose what the grid needs, either by making
  them public or by splitting the engine into its own module that `CoreList` and the grid both depend on.
  *Left to the builder*, with the constraint that `CoreList`'s behaviour and its tests do not change.

### Layout

- Levels 3-31: closed-form row/column arithmetic. `frame(at:)` and the visible index range are O(1). The
  camera (1 × 2 cells at top-left, levels 3 and 5 only) and, in the picker, the avatar preview are fixed
  cutouts the arithmetic skips. Spacing stays 1 pt as today.
- Level 1: a prefix-sum of row heights from `PHAsset.pixelWidth/pixelHeight`, clamped to 2:1 … 1:2,
  computed off main once per `PHFetchResult` and cached; visible range by binary search. Until it is ready,
  rows use an estimated height and the anchor photo is held in place when exact heights arrive. Library
  changes update it incrementally.
- **Measure first.** Before anything else in the level-1 work, measure on a device with a large real
  library how long reading every asset's size takes. If it is too slow to precompute, fall back to a
  lazily refined estimate; the measurement decides.

### Cells

- Plain `CALayer`s (or a thin `UIView` only where a gesture or accessibility needs one), from a reuse pool.
- Image content set directly as `contents`; no display-link hop.
- Badges (video duration, type icon, spoiler, price, live photo, iCloud progress, selection checkbox) are
  sublayers added lazily and only when needed; static images are created once, not per bind.
- At 15 and 31 no badge or checkbox is created at all, and thumbnails are requested at the cell's real
  pixel size (tiny).

### Data

- The grid indexes the `PHFetchResult` (or the demo's synthetic source) directly. No per-asset entry array,
  no diff of N items. `PHChange` is applied incrementally.
- Per-index state the picker needs (selection, spoiler, price, edited thumbnail, download progress) is
  pulled for visible cells only, and pushed to visible cells on change; no per-cell signal subscriptions.

### Scrubber

- `SparseItemGridScrollingArea` writes the grid's offset directly: no queue hop, no throttle.
- The date shown is the creation date of the top visible index, read lazily and cached per index.

### Demo app

- Lives next to the grid's sources with its own `.xcodeproj`, built with `xcodebuild` on a dedicated
  simulator, following the `CoreListDemo` pattern (`CoreList/CLAUDE.md`). Bazel compiles only the library
  sources from the same directory.
- Two data sources, switchable at runtime:
  1. the simulator's or device's real photo library;
  2. a synthetic library of 50-100k items with coloured placeholder images, random dates and random aspect
     ratios, to test scale without a real library.
- Exercises: scrolling, flinging, scrubber, pinch and menu zoom, tap-to-zoom at 15/31, selection by tap and
  pan at 1/3/5, a camera cutout placeholder, a top inset for a banner.
- Has a frame-time readout (dropped frames, worst frame) so performance claims are measured.

## Stage 2: the picker on the new grid

Everything `MediaPickerScreen` uses today must keep working. The main items:

- **Attachment sheet hand-off.** `AttachmentContainer` finds a `UIScrollView` under the finger, sets its
  `contentOffset`, flips `bounces` and resets the pan's translation (`AttachmentContainer.swift:288-340`).
  The engine is not a `UIScrollView`, so the container needs an abstraction it can drive. Same for the
  scrubber's `beginScrolling` (returns a `UIScrollView`, `MediaPickerScreen.swift:782-789`) and the
  pan-to-select gesture toggling `isScrollEnabled` (`:1043`).
- Camera view and avatar preview as cutouts; the limited-access / camera-denied banner inside the top
  inset; the placeholder; the warp view wrapping the grid; story drafts first; story mode's taller cells
  (`itemWidth × 1.227`).
- Hidden media during gallery/editor transitions, `transitionView(for:)`, `transitionImage(for:)`,
  `defaultTransitionView()`, and the selected-list / send-preview `getTransitionView` closures.
- Navigation backdrop and top edge effect driven by the visible content offset; saved stories offset;
  scroll to top; scroll to bottom for album collections.
- `MediaPickerAttachmentCarousel` embeds today's cell type; it moves to the new cell.
- The `.opportunistic` double delivery, the `TGMediaAsset` re-allocation and the `selectedItems()` array
  per bind go away with the new cell.

## Success measures

*My call* for the numbers; to be confirmed against the demo's readout:

- On device, with a large real library and with the 100k synthetic library: no dropped frames while
  flinging or scrubbing at the display's refresh rate, worst frame within one refresh interval in a
  steady scrub.
- Opening the picker shows the first screen of thumbnails without the second full rebuild that happens
  today, and nothing proportional to library size runs on main.
- Pinch zoom tracks the fingers with no frame drops at every level pair, including 3 ↔ 1.

## Left to the builder

- Module layout and names (the grid module, and how the engine is exposed).
- Exact pinch thresholds, settle curves, and how far ahead cells are bound and images cached.
- Whether level 1 morphs frames per cell or cross-fades only, as long as it looks continuous.
- Reuse-pool sizing, thumbnail request sizes per level, and the cache policy.
- The order of work inside stage 1, except that the level-1 size measurement comes first in the level-1 work.
