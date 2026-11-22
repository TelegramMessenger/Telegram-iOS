# Profile shared media on MediaGrid: design

## Intent

The profile's **Media** tab (photos and videos) and **Posts** tab (stories posted to the profile) run on
`SparseItemGrid` (`submodules/SparseItemGrid`). Its pinch zoom is the problem: any column count from 2 to 12 can be
chosen, and a zoom crossfades two whole scaled scroll views around one anchor cell instead of moving the cells. Ilya
wants these tabs to zoom the way the photo picker now does on `MediaGrid`
(`submodules/TelegramUI/Components/MediaGrid`): fixed levels, cells that flow between layouts during a pinch.

The picker's grid was built for a local photo library. Shared media is remote, sparse and paged, so the work is
mostly in loading: this design carries the current Shared Media loading rules over to MediaGrid rather than inventing
new ones.

## Goals

- Levels **3, 5, 15** only, in both tabs. 3 is the default. No level 1, no level 31 (31 over network media cannot be
  filled; 15 is close to today's 12 columns).
- MediaGrid's pinch and menu zoom transitions in place of SparseItemGrid's.
- Loading behaves as Shared Media does today (below), plus one improvement: an instant blurred placeholder.
- Everything the tabs do today keeps working (feature list below).
- Behind a killswitch, on by default, as the picker was; the SparseItemGrid path stays working and selectable.

## Non-goals

- No level 1 and no level 31; no aspect-ratio layout.
- No on-disk 48 px thumbnail store, no filler, no launch cache, no camera cell, no accessory view for these tabs.
  `DirectMediaImageCache`'s cached representations in mediaBox play the store's role.
- No change to how history is fetched from the server (`SparseMessageList`, `StoryListContext`): same requests, same
  hole sizes.
- The Files, Voice/Video messages and Music tabs (list rows, served by the same pane class) stay on SparseItemGrid.

## Anti-goals

- A tab that is worse than today at a scrubber jump into unloaded history: today it shows shimmers and fills them as
  holes load; it must not show white, wrong images or jump.
- A regression in any tab feature listed below, or in the profile header/paging integration.
- More network traffic than today for the same scrolling.

## Stages

1. **Media tab** (`PeerInfoVisualMediaPaneNode`, content type `.photoOrVideo` / `.photo` / `.video`). The hard part:
   holes, the scrubber and calendar, filters.
2. **Posts tab** (`PeerInfoStoryPaneNode`), after stage 1 is accepted. It gets its own short design then; what is
   known now is listed at the end.

Each stage ends with Ilya checking it in the app before the next one starts.

## How Shared Media loads today (to be kept)

- **Source.** `engine.messages.sparseMessageList(peerId:threadId:tag:)`: up to 200 newest tagged messages locally,
  plus a server skeleton (`getSearchResultsPositions`, up to 1000 positions and the total count) of anchors and
  unknown ranges. A channel migrated from a group merges a second segment.
- **Count.** Known once the skeleton arrives; 100 is shown until then. It can change as holes load.
- **Holes.** An index with no message is drawn as a shimmer. While a hole is visible, the hole anchor nearest the first
  visible empty index is loaded (`SparseMessageList.loadHole(anchor:direction:)`, about 100 messages), one at a time.
- **Images.** `DirectMediaImageCache.getImage` with width buckets by cell width (64, 150, 200, 280 px): a synchronous
  read of a cached representation of any bucket on first bind, otherwise an async fetch (progressive JPEG ranges when
  available), downscale, store. Video uses `videoCover`, else the file thumbnail. Spoilers use the blurred
  `immediateThumbnailData`. Arrival fades in.
- **Scrubber and calendar.** The scroller shows the month of the nearest item or hole anchor; tapping it opens
  `CalendarMessageScreen` (`sparseMessageCalendar`); `scrollToTimestamp` jumps among loaded items and flashes the
  target.

## Decided

- **Levels.** The grid takes a host-chosen set of levels; these tabs pass `[3, 5, 15]`. Pinch past 3 or 15 stops
  there (rubber-bands as at the ends today in the picker). The context menu's Zoom In / Zoom Out steps through the
  same set.
- **Stored level.** `VisualMediaStoredState` keeps a column count 2–12 per peer and tag. Mapping on read: 2–3 → 3,
  4–7 → 5, 8 and more → 15. New values are stored as 3, 5 or 15.
- **Level 15 loads real images.** In the picker 15 and 31 only show stored thumbnails. Here 15 requests sharp images
  (the 64 px bucket, as 12 columns do today). This becomes a host setting of which levels request sharp images, not a
  hardcoded "compact level" rule.
- **Holes in the grid.** MediaGrid gets the idea of an index without an item: such a cell shows a shimmer (the same
  look and colours as today) and makes no image request. The data source tells the grid when an index stops being a
  hole; the grid reports its visible range so the adapter can pick the hole to load, with today's rule (nearest hole
  anchor to the first visible empty index, one load at a time).
- **Instant placeholder (new).** A loaded message's `immediateThumbnailData` (or the story's equivalent) is decoded,
  blurred and shown at once as the cell's thumbnail while the real preview loads, instead of a shimmer. A message
  without one shows the shimmer until its image arrives.
- **Loading stays in the app.** MediaGrid's sources keep their import rule (no Display, SwiftSignalKit, Postbox,
  TelegramCore). A data-source adapter in the PeerInfo area maps `SparseMessageList` state to `MediaGridDataSource`,
  computes `MediaGridChanges` between snapshots (or reloads when a diff is not cheap), and serves images through
  `DirectMediaImageCache` keyed by message (story) id and media, never by index.
- **Level 15 is an overview level, as in the picker (Ilya).** A tap at 15 zooms in to 5 around the tapped cell instead
  of opening the gallery. My calls following from that: no pan-to-select and no long-press menu at 15; cells bind with
  MediaGrid's compact detail (no duration or live-photo badges; spoiler and sensitive blur stay, since they hide
  content); a selection made at 3 or 5 is kept while at 15, its checks hidden. The features listed below are required
  at 3 and 5.
- **Rotation and iPad (my call).** The level is a column count at every width, as today: rotation and iPad keep it
  (the host passes `isLandscape: false` always, so `rotated(toLandscape:)` never moves it). The stored level is one
  value, written only by a zoom.
- **Scope (my call).** Every use of `PeerInfoVisualMediaPaneNode` with `.photoOrVideo`, `.photo` or `.video` is in stage
  1 behind the one flag: the profile tab, the media-only shared-media screen, Saved Messages per-peer media, forum
  topics, channels migrated from groups.
- **Hole fills (my call).** The index space is the skeleton's count. A hole load turns shimmer indices into items in
  place (`changed`); nothing above the viewport moves. Only a change of the total count goes through `apply` with
  inserts or removals, which keeps the top visible item's position, as MediaGrid does for library changes.
- **Killswitch.** A server flag on by default plus a Debug Settings toggle, read when the pane is created, as
  `ios_killswitch_disable_media_grid_v2` / "Media picker: legacy grid" do for the picker (the builder picks the names).

## Features that must keep working (stage 1)

- Tap to open the gallery, with its transition in and out and hidden media while the gallery is open.
- Selection mode with checks and pan-to-select; the selection panel and its actions.
- Long-press context menu with its shrink animation; Zoom In / Out; the photo/video filter (which recreates the list).
- Badges: video duration (short style in small cells), live photo, spoiler blur, sensitive-content blur.
- Scrubber with month labels, the fast-scroll calendar tooltip, the calendar screen, scroll to date.
- The profile header and tab bar integration: covering inset offset, tab bar offset, scroll offset reporting,
  velocity transfer, lock at top, brief touch disabling, hit testing for paging between tabs.
- Empty state and the status line with counts.

## Left to the builder

- How MediaGrid represents holes in its API (an optional per-index flag, a separate protocol, or something else), as
  long as the picker's behaviour is unchanged.
- How the stored-level setting and the sharp-at-level setting are named and passed.
- Whether the adapter diffs snapshots or reloads, per update kind, judged by what keeps the viewport still.
- The date for an index inside an unknown range (nearest anchor, or interpolated between anchors); the scrubber label
  must never be blank where today's is not.
- Splitting the Media pane class (grid tabs vs list tabs) or branching inside it.
- Where the blurred instant placeholder is decoded (off main) and cached.

## Stage 2 (Posts), known so far

- Source `PeerStoryListContext` (pinned, archive, folders), pages of 100 with a single hole at the end; count from
  server or cache.
- Cells at 0.81 aspect; two centred columns over a blur when there are two items or fewer.
- Levels 3, 5, 15, as Media.
- Extra features to keep: reorder by drag with shaking (pinned stories and folders), folder tabs, archive, hashtag
  and location search, bot previews, view counts, privacy and pinned badges, story viewer transitions, the transition
  back from the media editor for a pending upload, selection with delete.
