# PeerInfoVisualMediaPaneNode

## Media tab on MediaGrid (`PeerInfoMediaGridPaneNode`)

The profile's photo/video tab (`PeerInfoPaneContainerNode`, `.media`) runs on `MediaGrid`
(`submodules/TelegramUI/Components/MediaGrid`) when `context.usesSharedMediaGridV2`
(`AccountContext/Sources/SharedMediaGridV2.swift`): the app-config key `ios_killswitch_disable_shared_media_grid_v2`
or Debug Settings ▸ "Shared media: legacy grid" puts it back on `PeerInfoVisualMediaPaneNode` (SparseItemGrid). The
flag is read when the pane is created. Files, Voice/Video messages, Music and GIFs stay on their old panes. The screen
reaches either photo/video pane only through `PeerInfoVisualMediaPane` (`Sources/PeerInfoVisualMediaPane.swift`).

- **Levels** 3, 5 and 15 (`availableLevels`); 15 is an overview level as in the picker: a tap zooms to 5 around the cell,
  no pan-to-select, no long-press menu, no duration or live-photo badges (spoiler and sensitive blur stay). 15 still
  loads real previews (`compactLevelsRequestSharpImages`). The level stored in `VisualMediaStoredState` (2–12 from the
  old grid) maps 2–3 → 3, 4–7 → 5, 8+ → 15 (`mediaGridPaneLevelColumns`); a landed zoom stores 3, 5 or 15. Rotation and
  iPad keep the level (`isLandscape: false`).
- **Data** (`MediaGridPaneDataSource`): the index space is `SparseMessageList`'s total count (100 while nothing is known,
  as before). An index without a message is a hole: no image request, a shimmer cell. A state update becomes one
  `MediaGridChanges`: overlap indices whose message changed are `changed`, a count change inserts or removes at the end,
  so a hole fill never moves what is above the viewport. Hole loading keeps SparseItemGrid's rule: the hole anchor
  nearest the first visible empty index (a tie goes to the later anchor), direction `.later`, one at a time
  (`mediaGridPaneHoleToLoad`), driven by `onVisibleRangeChanged`. A content-type switch (photo/video filter) builds a new
  list and data source state and reloads at the top; results of the old list are dropped by a generation counter.
- **Images**: `DirectMediaImageCache` with the old width buckets (64/150/200/280 px by cell point width). Each `next`
  of its load signal is delivered degraded, the last one final at completion. The instant placeholder is
  `DirectMediaImageCache.blurredImmediateThumbnail(media:)` (the message's `immediateThumbnailData`, decoded and blurred
  off main in `prepareThumbnails`), served as MediaGrid's thumbnail; a message without one shows the shimmer. Cells are revealed **by rows**: a cell keeps its shimmer over
  whatever it already shows until every index of its row is ready (`mediaGridPaneRowIsReady`: the message is loaded and
  its blurred thumbnail decoded, or it has none), and a partial last row waits until the end of the list is known (not
  the placeholder count, not loading). Rows that become ready together fade their shimmer out top to bottom, 40 ms apart,
  within 0.3 s (`mediaGridPaneRevealDelays`). A cell's own image that arrives later fades in; a sharp image replacing a
  thumbnail crossfades (`CATransition`, 0.2 s). Anything set during the grid's binding pass (`isBinding`, a cache hit on a
  ready row) shows at once.
- **Header**: `tabBarOffset` is the covering inset, ported from SparseItemGrid's `scrollViewDidScroll` /
  `snapCoveringInsetOffset` (the snap of the covering inset only; SparseItemGrid's animated content-offset snap inside the
  top inset is not ported). `isScrollingLockedAtTop` maps to `MediaGridView.isScrollingLockedAtTop`; `transferVelocity`
  to `MediaGridView.transferVelocity` (a grid-owned decay with SparseItemGrid's formula).
- **Shared helpers**: the badge pieces of the old pane are module-internal under unique names (`VisualMediaDurationLayer`,
  `VisualMediaMonth`, `visualMediaRightShadowImage`, …) because `PeerInfoStoryPaneNode` keeps private ones with the plain
  names in the same module.

Tests: `:MediaGridPaneDecisionsTests` (host `swift_test`). On a Mac without `/private/var/select/developer_dir`, `bazel
test` cannot load XCTest for host tests; compile the two files with `swiftc -Xlinker -bundle` against the macOS
platform's XCTest and run the bundle with `xcrun xctest`.

**Not verified in the app**: hole loading and a scrubber jump into unloaded history (the test account's chats have
under 100 media, all local), the calendar jump, a forum topic.
