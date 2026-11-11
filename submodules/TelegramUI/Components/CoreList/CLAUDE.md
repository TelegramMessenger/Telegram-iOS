# CLAUDE.md

> **How to use this file.** A map, not a substitute for the source. Each architecture section ends with
> **`📖 Read before changing:`** — read those files and designs before editing that subsystem.

## Project

iOS UIKit demo (Swift 5, iOS 26.2 target) of `CoreVirtualListView`, a virtualized scroll view that renders
only a loaded window of a large collection (TelegramUI's chat-history backend is built on it). Scheme
`CoreListDemo`, XCTest target `CoreListDemoTests`.

`CoreListDemo.xcodeproj` is committed via a `!CoreListDemo.xcodeproj` negation in this directory's
`.gitignore`; `project.xcworkspace`/`xcuserdata` stay ignored. `PBXFileSystemSynchronizedRootGroup` picks
up files under `CoreListDemo/` and `CoreListDemoTests/` without editing `project.pbxproj` (`Info.plist` is
the one membership exception). Demo and tests are excluded from the Bazel `CoreList` swift_library
(`BUILD`): the Telegram build never compiles them, so the xcodebuild suite is their only verification.

## Build / Test

```bash
# Build
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro K2' build

# Run all tests
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro K2' \
  -parallel-testing-enabled NO -collect-test-diagnostics never test

# Run one test class
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro K2' \
  -parallel-testing-enabled NO -collect-test-diagnostics never test \
  -only-testing:CoreListDemoTests/CoreVirtualListAnimationTests
```

Every test command needs all three: the dedicated **iPhone 18 Pro K2** destination
(`E643A78E-DB62-4DA4-9F54-BD0836F434AF`; a similarly named simulator is a different device; if K2 is unavailable,
stop and ask); `-parallel-testing-enabled NO`; and
`-collect-test-diagnostics never` — without it a run with a failing test hangs effectively forever in
`XCTHRunDestinationAllocator.collectSimulatorDiagnostics`, while passing runs exit normally.

## Architecture

Core files: `CoreVirtualListView.swift` (diff, settled window, rendering, transaction composition),
`ListAnimationModel.swift` (analytic state), `ListAnimationController.swift` (model/layer lifecycle),
`CoreAnimationCompiler.swift` (CA output), `Scheduler.swift` (deferred dirty flush), and the
scroll-engine seam.

### Scroll-engine seam

`CoreVirtualListView` consumes `ScrollEngine` and never touches `UIScrollView`. The seam: `offset`,
`setOffset`/`applyShift`, `setEdges(min:max:)`, `contentHost`,
`containerOrigin(windowHeight:topLoaded:bottomLoaded:)`, `onScroll` (per frame), and
`onWillBeginDragging`/`onDidEndDragging` at the pan's `.began` and `.ended`/`.cancelled`. The drag pair
brackets the finger-down interval only (never momentum, bounce or programmatic writes), so a host can
derive `ListViewImpl.isTracking` from it.

`shouldStopScrollingOnRelease` is consulted once per release, with the recognizer velocity, before the
momentum decision — for a host whose release was claimed elsewhere (the chat's interactive keyboard
dismissal). **Suppression is a zero-velocity release, not a skipped one:** `ReleaseDecision` answers
`.stop` and expires the repeated-flick streak, and `.stop` while overscrolled still springs back (skipping
`endDrag` would strand the list off its edge). `UIKitScrollEngine` projects `targetContentOffset` onto the
current offset. `ReleaseSuppressionTests`.

- `UIKitScrollEngine`: the default engine, the only list component that knows `UIScrollView`. Private
  10,000,000-pt virtual canvas; programmatic offset writes must not re-enter the user-scroll callback.
- `PhysicsScrollEngine`: `.stepped` (main-thread display-link physics) or `.keyframe` (render-server
  flight), both on `PhysicsScrollCore`; embedding hosts get it via `init(forEmbedding:deceleration:)`. A
  finger on moving content grabs it by **two mechanisms on two clocks**: the STOP is `noteTouchDown`
  (touch delivery, unholdable); the ABSORB of the stopping tap is the forced `.began`
  (`shouldBeginImmediately`), plain exclusion — the engine grants no simultaneity and deliberately has no
  `shouldBeRequiredToFailBy`. Read the limbo gotcha before adding either or moving anything onto `.began`.
- `PhysicsScrollEngine` and `ScrollFlight` are public so `MediaGrid` can scroll on the same engine; the `ScrollEngine` protocol stays module-internal. `applyShift` and `reanchorDragToCurrentPosition` are public for MediaGrid's library changes, which re-base the offset and edges mid-drag or mid-flight. `shouldStopScrollingOnRelease` is public so MediaGrid can release a drag it cancelled on rotation at zero velocity. `isScrollEnabled` (setting `false` first calls `haltMotionInPlace()`, then disables the pan) exists for hosts that run their own gestures, such as a pinch.
- `.keyframe` plays `KeyframeFlight`. A coordinate-only rebase updates its persistent shift without a
  restart, but only while both edges are open; with a finite edge, shift and latest edges fold into one
  continuous rebake. A real edge change is a durable invalidation (survives sampling ticks, coalesces,
  consumed by one rebake/splice against the latest bounds) and outranks completion of the obsolete
  trajectory. Only an edge that can REACH the remaining path counts: a change outside the declared-edges +
  baked-offset band leaves the flight and its CA animation/completion untouched.

The UIKit-backed suite is the additivity oracle; physics is covered by `PhysicsListIntegrationTests` and
the physics/keyframe unit suites. The demo defaults to `PhysicsScrollEngine` `.keyframe`.

📖 **Read before changing:** `ScrollEngine.swift`, `UIKitScrollEngine.swift`, `PhysicsScrollEngine.swift`,
`PhysicsScrollCore.swift`, `KeyframeFlight.swift`; `docs/plans/2026-05-26-scroll-engine-seam-design.md`,
`…-physics-scroll-engine-design.md`, `…-keyframe-list-deceleration-design.md`,
`docs/plans/2026-05-28-trackpad-list-engine-design.md`.

### Virtual content and settled window

`UIKitScrollEngine` maps an open edge onto its canvas and a bounded list to a tight viewport-aware range.
The `container` holds loaded live views: top loaded → minimum edge 0, origin 0; bottom loaded → the
engine's bottom-aligned origin; neither → its neutral origin, `applyShift` preserving screen position
across rebases.

`activeWindow` is a pure settled `Window` of contiguous `(index, view, frame)` — never animation state.
Frames are container-local (`minY` may be negative); `render()` places a view at `frame.minY - window.minY`,
so absolute content Y = `containerOriginY + frame.minY - window.minY`.

- A pass builds its window once, in final projected coordinates, against
  `-preloadMargin ... logicalSize.height + preloadMargin` (rebalancing uses the same band): lower indices
  clipped at the loaded top, then higher ones at the loaded bottom; top wins when underfilled. The window is
  the sole source of the new settled offset; container parking is membership-neutral; a rebase shifts the
  engine offset and exit-overlay children equally.
- The shared anchor's old→new content-Y delta identifies a size/inset pass's coordinate-only rebase and only
  cancels container parking in the viewport track. Shared rows get no compensating tracks; captured
  overscroll is restored after edge resolution, presentation-only.
- Without `scrollTo`, a top-inset change projects the anchor by `newTopInset - oldTopInset` (unless
  `compensatesInsetChange: false`).
- Mutation anchors use the engine offset clamped to the loaded edges; rubber-band displacement never
  influences anchor identity, direction or pinning. At the loaded top, a mutation pins index 0 to offset 0.

`.preserveVisibleContent` (opt-in infinite loading; `.automatic` keeps finite-edge behaviour) keeps the
loaded item crossing the old top-inset edge at its distance from that edge — a moved identity stays the
witness; a departing one falls back to the nearest survivor below, then above. It never measures old
off-screen rows or post-corrects the offset, and yields to `scrollTo` and finite-edge clipping.

`.preserveCentredContent` (opt-in, News's Compact ↔ Expanded morph) keeps the loaded row crossing the OLD
visible centre line (midway between the inset edges) at its midpoint's distance from the line: the new
geometry's line, or the old one under `compensatesInsetChange: false`. It is a `.resolved` anchor, placed from
the row's NEW measured height on the pixel grid, so the row's position and height ride one curve and its
midpoint stays still through the morph. A row that crossed the line still crosses it (top at or above, bottom
below), so a reversal finds the same row; a departing one hands over to the nearest survivor below, then above.
`.preserveVisibleContent`'s semantics: no loaded-top pin, the underfill alignments clip both ends, no momentum
halt, no viewport track. Below `scrollTo`, the pin latch and a scroll hold; not for pinned lists.
`CentredAnchorTests`.

`.preserveItem(identity)` (opt-in, News's per-row Expand / Collapse swipe) keeps that row's top at its distance
from the top inset edge, but never above the edge: a row partly under it lands on it, so a collapsed row stays
in view. A `.fixed` anchor (the placement needs no new height), projected exactly as `.preserveVisibleContent`'s
witness (inset compensation, pin slack, `additionalScrollDistance`), with the same end clipping, no halt and no
viewport track. A row the old window did not load, one wholly above the edge, or one leaving makes the pass a
`.preserveVisibleContent` one. `PreservedItemAnchorTests`.

`reachedLoadedEdges`/`onLoadedEdgeReached` (transitions only): lines at `loadedEdgeMargin` and
`logicalSize.height - loadedEdgeMargin` (positive loads later), independent of insets and engine limits,
overscroll excluded; recomputed after construction, settlement, rebalancing and margin changes.
Observation only — pagination is caller-owned.

#### Bottom-edge pin (`pinsToBottomEdge`)

Two mechanisms answer two questions (cf. `ListViewImpl`'s `experimentalSnapScrollToPinnedItem` +
`calculatePinToEdgeTopInset`); merging them into one number is a known defect family.

- **`holdsPinnedRow`, a latch: WHERE the row goes.** Engaged by `scrollTo` at `lowestPinnedItemIndex` (one whose
  `pinsRow` is set, the default); released, **permanently** for that pin, on a user-driven scroll
  (`engine.onWillBeginDragging`, or a `scroll(by:)` that can move at the presented position), a scroll hold arming on
  another row (the user jumped elsewhere; `testAHeldJumpToAnotherRowReleasesThePin`), the row leaving, or a full
  replace. Programmatic writes keep it; a jump that holds nothing (a yielding landing on the newest edge) keeps it too.
  While engaged, `resolveAnchor` returns `.resolved` on the pinned row (below `scrollTo`, above
  `preserveVisibleContent`), placed from its own height only (no loading precondition).
- **`bottomEdgePinSlack`, top-inset slack: is there ROOM.** Positive only while content above the pin is
  shorter than the viewport; `max(0, …)`-clamped; read from intra-window offsets and folded into the
  effective top inset at `buildWindow`'s `topEdge`, `loadedEdgeRange`'s `minimum` and
  `rebuildFromScratch`'s initial offset. `applyChanges` compensates inset changes against that edge.

They are **matched by construction**: the pin's target sits `visibleArea − span + ext` past the natural
minimum, which is what the slack returns. **Never un-clamp the slack** (negative slack extends the range
into empty space; a tall reply became unreachable) and **keep it latch-independent** (release is at
finger-down; a shrinking range would move content under the finger).

`isStrictlyPinnedToBottomEdge` = latch + presented-frame check that the animation landed; the chat uses it
to decide whether sending drops the pin (`ChatControllerLoadDisplayNode`). `holdsPinnedRowAtBottomEdge` is the latch
alone, landed or not: the chat backend makes no message-widget resize target while it holds, since every pass
re-places the held row. Only a `scrollTo` with `pinsRow` (the default) arms the latch: a target that keeps a row in place
passes false, or one aimed at a released pin's row would arm it again (`testATargetThatDoesNotPinLeavesAReleasedLatchReleased`). `appendUntilPinnedRowLoaded`
runs only while disengaged and its `window.height < visibleArea` bound is correct — do not patch it.

**A released anchor rides the EFFECTIVE top edge (`inset + slack`)**, so a streaming reply grows into the
slack it gives up while the pinned row and history below hold still (at an absolute offset, growth pushes
the rows and the settle clamp tugs). Once `span` fills the viewport the slack is 0 and growth pushes, by
design. It is one addend, `buildWindow`'s `pinSlackBaseline` (needs the NEW window's slack, which
`topInsetDelta` cannot see), not gated on `compensatesInsetChange`, and applied only to a `.fixed` anchor
**above** the pinned row: one at or below it holds by itself, and projecting it moves the pin — e.g. when
the `TypingDraftMessageAttribute` draft becomes the real message and `resolveAnchor` lands on the pinned
row (`testTheDraftBecomingTheRealMessageDoesNotMoveThePin`).

The three approaches already known not to fix the released state:
1. Collapsing the slack at finger-up yanks a short-reply chat ~210pt on any drag-and-lift.
2. Reserving the room the user stands in (stored floor, drag-gated) freezes the edge, so growth pushes
   again while parked.
3. Fixing only the settle clamp misses `buildWindow`'s `topEdge` → `alignTopIfUnderfilled`, which places
   the window first; act on both (hence a window translate, not an offset correction).

**Open, unreproduced:** a mid-stream send reportedly snaps. Suspect `isStrictlyPinnedToBottomEdge` reads
false mid-animation, the chat nils `pinToTopStableId`, and the `lowestPinnedItemIndex == nil` release fires
— permanently.

#### Stacking from the bottom (`stacksFromBottom`)

`ListViewImpl.stackFromBottom` for a non-rotated host (the chat's inline bot results list): a whole collection that fits
between the insets rests on the BOTTOM inset edge. One slack, `stackFromBottomSlack` (`max(0, bottom edge − top edge −
window height)`, zero unless the whole collection is loaded), is folded into `buildWindow`'s whole-collection placement
(`placeWholeCollection`, also wherever the anchor left a fitting window: a row that grew can push the last one past the
bottom edge) and `loadedEdgeRange`'s minimum, as `max` with the pin's slack. For a collection that fits that minimum is
exactly the natural maximum, so the scroll range is the one resting offset. Set it before the first rows: a pass measures
the old placement with the current value. `StackFromBottomTests`.

#### The scroll hold (`CoreListScrollHold`)

A `scrollTo` may carry a hold: a visible-area edge (`topInset`, `bottomInset`, `visibleCenter`) and a point
in the row. The landing pass records `rowPoint − edge` in its SETTLED geometry (a clamped jump is held where
it landed); `resolveAnchor` re-places the row there on every later pass (`.resolved`, below the pin latch,
above `preserveVisibleContent`). Keyed by identity, never index.

- **A landing clamped against an end is held against that end**: at the newest edge (window from index 0,
  settled offset on the natural minimum) by minY from `topInset`, at the oldest by maxY from `bottomInset`; newest wins.
- **`yieldsToNewestEdge` arms nothing on the newest edge** (the chat's unread line), so the list follows that
  edge and arrivals push content up; not arming is the whole mechanism (the landing scroll already released
  earlier holds and zeroed `holdSlack`). Elsewhere it arms normally.
- Released by: a drag beginning (`onWillBeginDragging`; physics: `.began` after hysteresis, or at once on
  moving content — a tap keeps it), any later `scrollTo`, the identity leaving, a full replace,
  `rebuildFromScratch`, `releaseScrollHold()`, a `scroll(by:)` that can move at the presented position.
- Arming one on a row other than the pinned row releases the pin latch, so the two never hold at once (the pin
  latch, which `resolveAnchor` ranks above the hold, would otherwise undo the jump on the next pass).

While held, `buildWindow` skips the underfill alignments and loaded-top pin; `heldWindowSlack` turns their
gaps into scroll room (`holdSlack`, both edges, ≥0, measured against the unfolded edges), folded into
`topEdge` (`+ holdSlack.min`), `bottomEdge` (`− holdSlack.max`) and `loadedEdgeRange`, and zeroed by every
scroll, full replace and `rebuildFromScratch`. After release it only shrinks to what the offset still needs
(`retireHoldSlack`), so release never moves content under the finger, and the `topEdge`/`bottomEdge` folds
keep a later pass from aligning onto the natural edge. It retires at the end of every `applyChanges`,
on non-flight `handleUserScroll` frames, and once when a flight ends (`onFlightChanged(nil)`). **Never on a
flight's ticks** (each retire re-declares an edge on the flight's path, rebaking `KeyframeFlight` every
frame). `resolveAnchor`'s newest-edge shortcut reads the natural edge (`includesHoldSlack: false`), which
matters when `pinsLoadedTop` declines (nonzero `additionalScrollDistance`).

`ScrollHoldTests` pins the hold, releases, clamped landing, yield and newest-edge retirement
(`UIKitScrollEngine`) and the flight case (`TestScrollEngine` `.keyframe`). **Not covered:** oldest-edge
retirement, the `rebuildFromScratch` release, pin + hold slack together; the chat's `PhysicsScrollEngine`
release/retire path is unchecked on device.

#### Host-facing embedding seam

For TelegramUI's `CoreListChatHistoryBackend` and the News feeds:
- `onVisibleWindowChanged` (after each rebalance); `onLoadedEdgeReached`; `willBeginDragging`/
  `didEndDragging` (the finger-down interval); `shouldStopScrolling` → `shouldStopScrollingOnRelease`.
- `scroll(by:)`: a user-driven scroll with no drag (the chat's two-finger selection auto-scroll, via
  `scrollWithDirection`). A drag frame without the finger: if the step can move (judged at the presented
  position, clamped to the declared edges, never pulled back from overscroll), it releases the pin latch and
  the hold, halts momentum, writes the offset and runs `handleUserScroll` (rebalance, slack retirement,
  `onVisibleWindowChanged`; at most `preloadMargin` per call, so it cannot pass an edge not yet declared,
  up to one frame of flight travel after catching a keyframe flight);
  a step that cannot move at the presented position changes nothing. Not an `additionalScrollDistance`
  pass, which after the latch's release re-anchors on the natural newest edge and drops a short reply's pin
  slack in one jump. `ScrollByTests`.
- `lastTouchCaughtMovingContent` (`PhysicsScrollEngine` only): whether the latest touch landed on a flight or a
  deceleration and stopped it; set at touch-down, kept until the next. A host's tap selection reads it at the lift, as
  the drag's `.began` can be held until then by an ancestor's pop recognizer.
- `viewportAnimationOffset`: what a pass's viewport track still adds to the content host's `bounds.origin.y` (model
  clock), a flight's motion excluded; a view on a content motion mirror reads its mirror's presented motion less this
  as the flight's part, which a later pass does not fold into its own track (`ViewportAnimationOffsetTests`).
- `isScrollDecelerating` (at `didEndDragging`, every mode); `isScrollFlightActive` (`.keyframe` only);
  `didEndScrolling` fires when a flight ends AND when `.stepped`/UIKit deceleration rests
  (`onDidEndDecelerating`; `SteppedDecelerationEndTests`).
- `loadedItemViews`: non-copying, in-place walk of `activeWindow.items` in index order (COW, safe to mutate
  mid-iteration); loaded rows only, never ghosts. `loadedItemView(at:)` is the index ↔ view authority —
  never infer a position from `loadedIndexRange`. `loadedItemEntries` yields `(index, view)`.
- `animateInsertedBlock(identities:origin:transition:)` slides a run in from beyond one edge as one rigid
  block (unloaded rows skipped). **The host names the EDGE (`CoreListBlockOrigin`, content order — reversed
  for a rotated host); the list measures the DISTANCE** (the block's settled height, reserved space included). List-owned on purpose: a host's own additive
  animation would be read back as a CoreList track by `capturePresentedPositionOffsets()`, and
  `transitionPosition` composes overlapping arrivals. Safe right after `applyChanges` (same scheduler).
- `addContentMotionMirror(_:)` (`ContentMotionMirror.swift`; `PhysicsScrollEngine` only, false otherwise): the content
  host's layer repeats on registered mirror layers every model write of its `bounds.origin.y` and every
  `bounds.origin.y` animation added or removed (a drag's writes, a flight, its brake and re-emit, a pass's viewport
  track), without their completions, so a view outside the list rides the content's motion; it places its own content
  at `contentFrame(of:)`, a row's frame in the content's coordinates. A survivor's own slide in a pass (its additive
  `position.y` track, while the offset jumps) is the row's, not the content's: a view that must follow a row copies it
  from the row's layer (the inline results panel's glass does). A follower placed from per-frame callbacks trails a render-server flight by
  the commit's frame or two (measured up to 60 pt, the inline results panel's glass). `ContentMotionMirrorTests`.
- **Row geometry is a pair, and picking the wrong half is silent.** `presentedFrame(of:)` is where a row IS
  — the default, used instead of `convert(_:from:)`. `settledFrame(of:)` is where it WILL BE; only for
  reporting a just-submitted pass's outcome alongside its transition. Both are ancestor-path-agnostic. See "Content offsets" in
  `docs/chat/corelist-chat-history-backend.md`.
- `CoreListItemView.visibleRectUpdated(_:)`: the row's part of the FULL viewport (insets count; `visibleRectInsets`
  ends the band sooner, for a list running on under the keyboard), in its own coordinates, or `nil`; fired after the final offset is installed in `applyChanges`/`rebuildFromScratch`
  and at the end of `handleUserScroll` (settled frames at the live offset; an animated move reports the
  destination). Don't publish from `render()` (old offset). Departures get `nil` via weak refs to the
  last-visible views. Default no-op; `CoreListNodeHostView` maps it to `ListViewItemNode.visibility`.

📖 **Read before changing:** `Window`, `buildWindow`, `render`, `rebalanceActiveWindow`, `loadedEdgeRange`;
`docs/plans/2026-03-21-virtual-list-rewrite-design.md`.

### `applyChanges`: the sole mutation entry point

```swift
func applyChanges(items: [CoreListItem]? = nil,
                  newSize: CGSize? = nil,
                  newInsets: UIEdgeInsets? = nil,
                  scrollTo: CoreListScrollTarget? = nil,
                  additionalScrollDistance: CGFloat = 0.0,
                  anchorMode: CoreListAnchorMode = .automatic,
                  compensatesInsetChange: Bool = true,
                  transition: CoreListTransition)
```

- **`compensatesInsetChange: false`** drops only the inset anchor projection (cf. `ListViewImpl` zeroing
  `offsetFix` while tracking), for an inset change made by the user's own drag — caller policy
  (`CoreListChatHistoryBackend` decides from the drag callbacks). Don't emulate it with
  `additionalScrollDistance: -topInsetDelta`: that halts momentum and drops `pinsLoadedTop`.
- **`CoreListScrollTarget`**: an index plus a resolver `resolve(measuredHeight, view)` returning the row's
  settled Y from the top inset edge, called once inside `buildWindow` right after the anchor row is measured.
  It must not mutate the list or re-enter. `CoreListScrollTarget(index:pointOffset:)` is the constant form;
  placement semantics (`ListViewScrollPosition`, quote rects) stay in the host. `direction` decides carousel
  travel when no old identity survives.
- **`additionalScrollDistance`**: points, positive moves content DOWN (cf. `ListViewImpl.transaction`),
  applied to the anchor before window construction, so it composes with clipping, carries and `scrollTo`.
  Nonzero halts momentum (under `.automatic` only; the preserve modes keep a fling) and opts out of the
  loaded-top pin; at the top edge a downward displacement is clipped, an upward one honoured.

A pass: (1) serializes re-entrant requests, applies `newSize`; (2) validates unique identities, diffs
survivors/inserts/deletes/LIS moves; (3) captures one transaction clock and the old settled state;
(4) reconciles content in reused views, remeasures dirty rows; (5) resolves the anchor, builds the window
reusing survivor/move views; (6) moves loaded departures to the exit overlay, renders final frames and edges
with implicit actions disabled; (7) binds new layers, transitions every survivor whose settled position or
height changed, fades genuine inserts.

📖 **Read before changing:** `applyChanges`, `ItemDiff`, `settledState`, `makeExit`, `attachLive`,
`docs/plans/2026-07-20-list-animation-model-design.md`.

### Granular animation contract

`ListAnimationModel` is the sole presentation authority (Foundation, CoreGraphics, and QuartzCore only to
evaluate system springs). At most one analytic track per `ListAnimationOwner` × `ListAnimatedProperty`:
additive x/y position offsets, absolute width/height, opacity, one shared additive viewport offset. Live
owners are `CoreListItem.identity`; each departure gets a fresh exit-owner serial, so a fading old
incarnation and a new live one coexist. A `ListAnimationTrack` has a rising generation, `from`, `to`,
immutable start time, duration and its own curve.

- An unchanged settled position/x/width/height (within `1e-6pt`) is a true no-op — track, generation, phase,
  curve, deadline and CA animation untouched; same-target writes return before touching model, CA key,
  completion ledger or layer.
- A changed property replaces only that owner/property from its analytic current value (C0, not velocity).
  Zero duration settles it immediately; an unrelated zero-duration pass cannot erase an unchanged track.
- **Every** loaded survivor whose settled position or height changes transitions from its analytic current
  presentation, even with no prior track (restricting to active tracks gives a delayed snap). Height is
  absolute `bounds.size.height`. This covers resize, inset change, reconciliation and self-update, which
  write final frames immediately first. Moves keep view and identity.
- Inserts install at full final geometry, seed the model, and fade 0→1 with no geometry animation.
- Membership is the union of old rendered survivors and the new viewport+preload window. A one-endpoint
  survivor keeps/gets one live view and inherits only the nearest unmoved shared survivor's displacement;
  old-only ones stay under the crossing overlay until position-generation completion, new-only ones animate in
  the live container. Nothing outside the
  union is loaded or measured. With no eligible witness, contiguous unmoved survivors of one region share a
  boundary translation (the anchorward run edge clears both the retention threshold and the settled window
  extent; spacing preserved; per-identity ownership; never expands the window).
- **Full-replace carousel** — `scrollTo` with disjoint old/new loaded windows AND a destination window of
  entirely new content — fades nothing: incoming rows at full opacity, departing ones ride their ghost block
  at their current opacity, the viewport track owns the travel (like `ListViewImpl`'s
  `temporaryPreviousNodes`). The **destination window** is the unit: window disjointness alone fades a new
  row among destination survivors; collection disjointness never fires in chat (constant identities like the
  unread separator `4 << 40` survive). A non-fading exit still installs an opacity track with the pass
  duration (deadline/completion unchanged).

Position tracks are additive corrections: sample `oldSettled + analyticOffset` (never the model layer or
viewport coordinates), render the new settled position, replace with `(currentVisible - newSettled) -> 0` —
parent-space independent, so scrolls and rebases are not target changes. Extents sample the analytic extent.
Axes compose independently.

`ListViewportGeometry` is only the received size and full `UIEdgeInsets` (no parent-space position); insets
set content x/width and vertical edges but stay visible, interactive list space. A size/inset pass replaces
the viewport track from its current correction iff the projected, clipped window moves the viewport target.
All carries and ghosts retarget per property on the same clock; unavailable endpoints are never loaded to
animate them.

`ListAnimationController` owns bindings, applies Slow Animations scaling exactly once, and passes one local
clock to every mutation of a pass. Stable keys replace only the affected animation. Completions capture
generation and binding, so a stale one cannot clear a replacement, unbind a rebound layer or tear down a
reinserted view; rebinding to another owner first removes all controller keys. `rebind` re-emits position
and opacity on their original start/deadline (restarting violates the stable-owner contract), and height too
if its target matches the fresh measurement within `1e-6pt`; otherwise height alone settles to the fresh
geometry. An active unbound owner keeps its state through its deadline, reaped by a generation/binding-safe
callback at analytic completion (no display link). Exception: if a structural pass changes an unbound
owner's predecessor set (including one entering the window), its position correction settles to zero;
height/opacity untouched.

#### `CoreListTransition` and curves

`CoreListTransition` (`CoreListDemo/Transition/`) is a copy of ComponentFlow's `ComponentTransition` (no Bazel
`deps`; the demo builds standalone). `CoreListTransitionBridge.swift`
(`TelegramUI/Components/CoreListComponentHost/Sources/`) maps it case-for-case to `ComponentTransition`
(zero duration → `.immediate`) and builds it from `ContainedViewLayoutTransition`. Production uses
`.easeInOut`; tests use `.linear` (`CoreListTransition.linear(duration:)`) as the contrast curve.
- `.spring` samples the adjusted bezier `(0.380, 0.700, 0.125, 1.000)`, what `CAAnimationUtils` emits for
  `kCAMediaTimingFunctionSpring` except at 0.5 and 0.3832 (iOS 26), which emit real `CASpringAnimation`s.
  Deliberately not ComponentFlow's `solve(at:)` (the 0.5 s spring). `.bounce` degrades to `.spring`.
- **The spring-kind predicate reads the LOGICAL duration** (resolved at construction, kept by `scaled(by:)`
  and the track); a Slow-Animations-scaled duration would silently pick the bezier.
- `.customSpring(mass:stiffness:damping:initialVelocity:)` mirrors Display's `.customSpring` (the chat's
  spring send transition): `Float`-quantized parameters, `duration = settlingDuration`, linear timing, down
  the `isSystemSpring` path so the settle reaches the pass as `speed`. `solve(at:)` is a closed form keyed to
  CA's `settlingDuration` (reported in the PARENT's time — divide by `speed`), with no overdamped branch
  (Display never sets `allowsOverdamping`). `CustomSpringParityTests`.
- System springs are evaluated via private `_solveForInput:` (runtime lookup in
  `CoreListSpringAnimation.swift`, argument `float` or `double` by build); `valueAt:` is Display's own
  category. Without the selector, model and emitter both fall back to the bezier.
- `Curve.solve(at:)` has no 0.997 clamp (unlike Display's `bezierPoint`) and bisects after Newton, to match
  CA through the tail. `Curve.custom` carries `Float` and is inexact; payload-free curves are exact `Double`.

CoreList uses **no `CATransaction`**: it writes only UIView-backed layers (null actions outside animation
blocks), and completions attach via `CAAnimation.setCoreListCompletion`.

#### Resuming from the screen

**A new animation resumes from what the layer is RENDERING, not the model's analytic value.** The model runs
on the pass clock and CA on the next commit, so the model leads by δ; with two authorities on one seam (a
growing row's `.height` plus the next row's `.positionY`; the chat's item node sizing itself from
`presentation()`) the lead compounds.
- `ListAnimationModel.resumeValue` asks a provider from `ListAnimationController`; `value(for:property:at:)`
  stays the settled answer (window building, `bottomEdgePinSlack`, `finalize`). Keep them separate.
- `.height`, `.width`, `.opacity`: the presented value.
- `.positionY`: presented minus the **COMMITTED** base. The transaction's first row-base write (pass entry, or
  a rebalance that changes the window) records `layer.position.y` for every live owner with a running
  position track (`beginModelWrites`); a zero-size commit sentinel tells whether anything has been committed
  since. An owner whose track or binding this transaction replaced is forgotten and resumes analytically.
  Idle rows are never sampled. The snapshot is taken at pass entry by `capturePresentedPositionOffsets()` and
  cleared in `applyChanges`' `defer`. Presented − model would be wrong: a pass or rebalance earlier in the
  same runloop turn that grows or shrinks the window at its top re-bases the rows without a commit, and
  that rebase would read as motion. `SameTransactionResumeTests`.
  Only `.live` owners (`ListAnimationOwner.hasPassWrittenPositionBase`): attachments (`renderAttachments()`
  rewrites their base every render) and `.exit`/`.transient`/`.ghostBlock` (rebased from `render()`) have a
  per-frame base that `presentation()` trails. `AttachmentResumeBaseTests`.
- `.positionX` and `.viewportOffset` decline (positionX's transition and layer disagree on
  `positionOffsetX`; viewportOffset's model is written outside the commit cycle). Measure before enabling.
- Don't (each shipped and was reverted): `.viewportOffset` as `presented − settled`; `.positionY` as presented
  minus `newSettledY` (model gets `containerOriginY + localY`, layer `localY`); `.positionY` as
  `presented − layer.position.y` inside the provider.

`PresentedPositionResumeBaseTests`, `PresentationResumeSamplingTests`, `PresentedResumeSeamTests`,
`SameTransactionResumeTests` (see Tests for why only these reach the provider).

#### Core Animation output

`CoreAnimationCompiler` is an output renderer, never an authority: `makeCoreListAnimation` (a copy of
`CAAnimationUtils.makeAnimation`) plus `fillMode = .both`, `isRemovedOnCompletion = false`, generation
metadata, `CoreListAnimation.startTime` and `.preservesPhase`; `beginTime` unset. Position additive on
`position.x/y`, extents absolute on `bounds.size.*`, opacity absolute, on the already-scaled duration (never
scale again). `CAKeyframeAnimation` is emitted only for baked trajectories: physics flights (`KeyframeFlight`,
`Trajectory+Keyframe`) and attachment flight tracks (`installAttachmentFlightTracks`). Apart from the resume
provider nothing reads presentation into the model; no display-link renderer, no `UIViewPropertyAnimator`.
Position keyframes call `preferHighRefreshRate()`; `Info.plist` must keep
`CADisableMinimumFrameDurationOnPhone = true`.

#### Ghost blocks (departures)

Loaded departures group by contiguous old runs into rigid ghost blocks in the non-interactive, footprint-free
`exitOverlay`: one wrapper and additive position owner per block; members keep sampled local frames and fade
on fresh exit owners. Teardown is owner-, generation-, binding- and view-specific (identity is insufficient).
- A boundary link stores the ghost's local edge and a live/ghost `minY`/`maxY` witness;
  `root = witnessBoundary - localEdge`. Passes keep a usable link or migrate both sides toward **that pass's**
  anchor (ghost-to-ghost handoff included). Above the anchor a ghost hangs its `maxY` on the next `minY`; a
  replacement carries it at matching `minY`.
- A deletion-only block's boundary stays open while a survivor provisionally carries it; a later insertion
  exactly at the root seals it (delayed = same-pass replacement); a same-pass occupant seals immediately.
- Scrolling never touches witnesses or block tracks; rebases and remaps shift wrappers and ledger
  `settledRootY` by one exact delta, preserving tracks. Opacity completion does not wait for motion; an empty
  referenced block stays a nonvisual node until its dependents finish, then is collected.
- **`settledRootY` is the SAMPLED root**, right to render from, wrong to decide with: `initialGhostWitness`
  compares the run's OLD SETTLED top (`oldState`, shifted by `oldLiveEdgeCoordinateShift`) with the
  successor's new `minY`, never the anchor (which may itself be departing).

#### Carousel passes

- **A carousel pass attaches no boundary witness** (its blocks stay `.unresolved`; the viewport track owns
  the travel). Otherwise `initialGhostWitness` falls through to `newItems[0]`/`.last`, which resolves exactly
  when the destination reaches a collection edge, and the strip walks over the new window.
  `FullReplaceCarouselStripSeparationTests`. **A viewport-anchored block refuses a witness outright**
  (`GhostBlockLedger.canSetWitness`), or a second carousel re-links the first strip onto its block.
- **Carousel exit content is parked in the VIEWPORT**: ghost wrappers and carries born in an
  `isCarouselScroll` pass move to `carouselExitOverlay`, a sibling BELOW `contentHost`, at
  `contentY − transactionOffset`, so the finger no longer drags the old strip over the destination. One
  hand-off after every parking site (`makeGhostBlock` runs before `transactionOffset` exists); membership is
  PASSED IN, never derived from carry generation (the viewport block re-stamps every live carry, including
  content-space ones an earlier pass parked). A residual crossing on a short viewport is inherent.
- **The outgoing strip is everything on its way out, not just the loaded window** (`carouselOutgoingStrip`):
  adjacency uses the loaded window plus every viewport-anchored strip, and that strip lives as long as the
  track now carrying it (`retimeCarouselExitStrips` → `retimeExit`; an immediate jump tears it down).
  `CarouselChainOverlapTests`.
- Direction: the current anchor's new position vs the target index; with no survivor,
  `CoreListScrollTarget.direction` (`nil` = `.forward`); a present witness always wins. Adjacency uses normalized strip tops
  (`containerOriginY - renderedViewport`, never subtracting `Window.minY` again): forward puts the incoming
  top at the outgoing bottom, backward the reverse.
- The viewport track alone moves destination-only survivors vertically; never route them through
  crossing-survivor inference (insert opacity and horizontal/extent properties still compose).

### Programmatic viewport scrolling

`scrollTo` writes the settled endpoint immediately and emits one model-owned additive `viewportOffset` track on
`contentHost.layer` (overlap geometry for shared rows, a one-window carousel for disjoint ones; nothing
intermediate is instantiated). Gestures move settled state beneath the correction; a later target replaces it
from its current value. A pass with no `scrollTo` and no geometry-induced target change is an exact viewport
no-op. `scrollTo.pointOffset` is relative to the received top inset, converted before window construction.

**Anything that displaces screen-space content must join `displacesViewport`**
(`logicalSizeChanged || insetsChanged || hasAdditionalScrollDistance`). Omitted, loaded rows animate one by one
(looks right) while ghosts, carries and entering rows stay behind.

**One track, several output layers:** `addViewportMirrorLayer(_:)`; `carouselExitOverlay` is the only mirror.
A mirror gets the animation only (no binding, model, settled write or completion — `writeEndpoint` returns
early for `.viewportOffset`). Never add a second owner with a duplicate track. A replacement STEPS the
correction (`replacementFrom` = correction + `oldSettled − newSettled`); mirror children don't ride the
engine's base write, so `shiftCarouselExitChildren` rebases them.

Every changed positive-duration viewport replacement first remaps all detached overlay content into the new
base (subtracting the engine shift once); no branch may skip it. A crossing carry released by the viewport
track migrates to every replacement generation (else it leaks); an immediate replacement releases carries.

📖 **Read before changing:** `ListAnimationModel.swift`, `ListAnimationController.swift`,
`CoreAnimationCompiler.swift`, the transaction in `CoreVirtualListView.swift`;
`docs/plans/2026-07-20-list-animation-model-design.md`, `docs/plans/2026-07-20-additive-viewport-scroll-design.md`.

### Self-update and view reuse

`onContentDidChange` marks the index dirty and schedules one coalesced `Scheduler` flush that re-enters
`applyChanges` and remeasures exactly the dirty rows (final geometry immediately, changed properties
animated). `buildWindow` reuses views for survivors and moves, calling `apply(to:)` only when `isEqual` is
false. Scrolled-in rows attach to their stable owner (known owners rebind; new ones seed settled state).

## Item protocol

```swift
protocol CoreListItem: AnyObject {
    var identity: AnyHashable { get }
    func view() -> UIView & CoreListItemView
    func isEqual(to other: CoreListItem) -> Bool
    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition)
    var pinsToBottomEdge: Bool { get }
}

protocol CoreListItemView: AnyObject {
    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat
    var onContentDidChange: ((_ animated: Bool) -> Void)? { get set }
}
```

- `identity`: animation and diff key, unique. `isEqual(to:)`: content equality of an identity-matched
  survivor (reconfigure iff `!isEqual`); **no default**, deliberately.
- `apply(to:transition:)` (default no-op) updates a reused view; `update(width:transition:)` returns the
  settled height and may run twice per pass (setters early-out on equal targets).
- `pinsToBottomEdge` (default `false`; see "Bottom-edge pin"): lowest loaded index wins (as `ListViewImpl`'s `lowestPinnedIndex`).

**The measure transition** is the pass's only when the row must re-lay-out from a prior layout: content
reconciled (`reconciledIdentities`) or `contentWidth` changed (`contentWidthChangedInPass` — a horizontal
inset or width change reflows every row). Otherwise `.immediate`: views created this pass
(`freshViewsThisPass`, which outranks width), scroll-in loads, unchanged survivors, off-screen remeasures.
- `contentWidthChangedInPass` and `CoreListNodeHostView.update(width:transition:)` share a `0.5` epsilon and
  **must agree**.
- It is inferred per PASS: submit a geometry change and its animation in the same pass.
- **Attachments follow the same rule** (`attachmentMeasureTransition(serial:isFreshView:)`,
  `reconciledAttachmentSerials`); both per-pass sets clear together at the pass boundary.
- **A live attachment view is laid out exactly once per pass**: `measuredAttachmentHeight` probes a
  `.reservesSpace` run with a throwaway from `run.representative`, never the live view (which would lay it
  out `.immediate` before `apply(to:)`).

📖 **Read before changing:** `DemoRow.swift`, `docs/plans/2026-05-31-item-content-reconcile-design.md`.

## Demo app

`SceneDelegate` installs **Virtual List** (`ViewController`: manual insert/delete/replace/reorder/growth/chaos/
jump controls, a 300pt animated top-inset toggle, four one-pass mixed-action controls at 0.5 s ease-out, all
three engines) and **Physics Scroll** (`PhysicsScrollDemoViewController`); a Pipeline tab hosts
`PipelineDepthProbe`. The list gets only size and insets; chrome is a layout-derived inset plus independent
test deltas, so removing a delta restores the chrome baseline exactly.

`Auto Load` (default off) is caller-owned bidirectional loading: reached edges coalesce on the next main-queue
turn, dedupe across queued and in-flight sets, and answer after 0.2 s with five rows per edge (both edges in
one zero-duration `.preserveVisibleContent` pass). An accepted response applies even if its edge was left;
continuations are fresh requests; disabling advances a generation; replacing the engine keeps state.
`CoreVirtualListView` stays policy-free. `PhysicsScrollView` is the standalone `ScrollPhysics` consumer
(touch + trackpad + mouse wheel, both deceleration modes).

## Scroll physics replica

`CoreListDemo/ScrollPhysics/`: a UIKit-free value-model replica of UIKitCore (iOS 26.2) — per-axis drag,
deceleration, rubber band, projection. `ReleaseDecision.swift` owns the 2-D, gesture-lifetime release path
(deliberately not on `ScrollAxis`); `PanRecognizer.swift` handles input; `Trajectory.swift`/
`Trajectory+Keyframe.swift` bake rate-independent keyframe playback and splicing. Formulas come from assembly;
decompiler SIMD/FP pseudocode is not authoritative.

📖 **Read before changing any physics constant or formula:**
`docs/plans/2026-05-22-uikit-scrollview-physics-analysis.md`, `docs/plans/2026-05-23-pan-recognizer-reproduction-design.md`.

## Tests

`CoreListDemoTests/TestSupport/` injects `SyntheticClock`, a `ListAnimationController` with optional CA
emission, `TestScheduler` and UIKit/physics engines; `VirtualListFixture`/`PhysicsListFixture` (+ drivers)
expose settled and analytic state. `VirtualListFixture` defaults to `emitsCA: false` (teardown from the model
clock); `TestScrollEngine` has no render server.

- Model and CA: `ListAnimationModelTests`, `CoreAnimationCompilerParityTests` (incl. a paused-layer check).
  List behaviour: `CoreVirtualListAnimationTests`, plus core-window, content, engine and physics suites.
- **The suite is blind to the resume provider.** Fixtures never enter a render tree, so `presentation()` is
  nil (pinned by `testFixtureLayersHaveNoPresentationLayer`). A provider test needs a scene-attached window
  AND an owner bound to that layer, or it passes vacuously; assert a sampled value is non-nil in the same
  test, and verify by mutation.
- `MixedPassStressTests`: fixed-seed grammar over structural, geometry, scroll and attachment changes,
  checking C0 continuity, track preservation, CA/model parity, window integrity, the attachment invariants
  (unique serials, member ranges inside the loaded range, one space-reserving attachment per edge per
  boundary, deterministic order) and teardown.
  Failures print seed and action prefix; minimize into a focused suite before fixing. **Attachments are
  opt-in** (`includesAttachments: true`) on a SEPARATE RNG (focused suites replay the main sequence);
  `testTheGrammarActuallyExercisesAttachments` is the non-vacuity guard. Anchor modes likewise
  (`includesAnchorModes: true`, a third RNG; `testTheGrammarActuallyExercisesTheAnchorModes`).

## Non-obvious gotchas

### Clocks and Core Animation

- **Clocks: the analytic slide clock is the layer's LOCAL time**: one time per pass from the bound layer's
  `convertTime(CACurrentMediaTime(), from: nil)`, never raw media time, so model and CA agree under Slow
  Animations; per-row sampling skews cross-property guarantees. Physics flights use layer-local time too
  (`localNow()`).
- Layer properties hold settled endpoints during animation; analytic queries go to `ListAnimationModel`.
- **`beginTime` stays IMPLICIT, so the commit resolves it**, on the clock of everything a host writes; one
  runloop turn shares one origin. The model's phase rides `CoreListAnimation.startTime` (an off-tree layer
  never resolves an origin — every windowless fixture).
  - **`rebind`** stamps `CoreListAnimationOrigin.explicit` (else `fillMode = .both` replays the curve) with
    the origin CA RESOLVED for the replaced animation (or `captureResolvedOrigins`), **not**
    `track.startTime`.
  - Keep out of grep-driven sweeps: attachment flight keyframes (`coreListAttachmentFlight`) and physics
    trajectories (`PhysicsScrollEngine`, `Trajectory+Keyframe`, `SplicedTrajectory`) re-install with past
    origins on every rebake.
  - **A flight's LAUNCH is explicit**: `beginTime` is `KeyframeFlight.startTime`, the clock `liveOffset`,
    `isComplete`, `beginTick`, `braked(stoppingAt:)` and `multiplierResetTime` use. Implicit would drift with
    the release turn's cost. `localNow()` from the top of the touch turn is vsync-locked, and right because
    the trajectory's `t = 0` (last drag update) and first presentation are each one frame off and cancel.
  - **Accepted residual:** the model LEADS the screen by the commit delay δ (unbounded, measured only on the
    demo) for model-vs-screen queries (`presentedFrame(of:)`); unresumed properties lose
    `velocity × (δ_new − δ_old)` per retarget, and an equal-endpoint track finishes δ early. Don't "fix" it by
    sending hosts to `settledFrame(of:)`; the real fix (one commit-resolved origin for model and CA) does not
    exist.
  - **Don't re-stamp `ListAnimationTrack.startTime` to the commit time:** `install` arms a one-shot
    `scheduleAnalyticCompletion(deadline: startTime + duration)`; firing early, `model.complete` fails and
    nothing re-drives `finalize`, stranding non-fading carousel exits and `viewportOffset: 0 -> 0` retargets
    (invisible with `emitsCA: false`).
  - `InsetRectOverlayAnimator` (`.atCommit`, `from` from `presentation()`) steps `velocity × δ` per retarget.
    Accepted; don't re-stamp.
- **Slow Animations reaches the emitted animation as `speed`, not as a longer duration**, as in
  `CAAnimationUtils`. The model works on the SCALED clock; `scaled(by:)` records `appliedDurationFactor`, the
  track carries it, the compiler divides it out (`speed = 1/factor`). Scale once per path (model:
  `ListAnimationController`; executor: `CALayer.animate`); items get the LOGICAL transition. Settled writes
  use `CoreListTransition.commit`, not `.immediate` setters, which clear the standard keys (`position`,
  `opacity`, `bounds.size.height`) and would cancel an item view's own animation.
- **A zero duration is immediate, which is the opposite of ComponentFlow.** Test
  `CoreListTransition.isImmediate`; `if case .none` animates a pass that must not.
- **CA never runs a `from == to` animation, so it never reports one stopping.** A non-fading exit
  (`opacity: o -> o`, every row leaving a full-replace carousel) and a `viewportOffset: 0 -> 0` retarget
  (whose completion runs `finishViewportGeneration`) depend on completions, so `install` drives such tracks
  from the ANALYTIC deadline (`deliversNoCoreAnimationCompletion`); `beginExit` bypasses the equal-target
  early-out on purpose. `assertOverlayInvariants` cannot see this leak. `NoOpAnimationCompletionTests`.

### Scroll engine and physics

- **`ScrollEngine.offset` is per-frame stable; never sample a running animation through it, and never read
  `contentHost.bounds.origin.y` as a position** (it is the keyframe animation's base, parked at the flight's
  `finalOffset`). `PhysicsScrollCore.offset` is `physics.y.offset`, advanced once per frame. A pass reads the
  offset three times and treats differences as its own shift — consistency, not currency. Passes call
  `syncToPresentedPosition()` at entry; halt with `haltMotionInPlace()`, never `setOffset(offset)`; the
  before/after differencing in `render()`/`applyEngineShift` must stay differences (`UIKitScrollEngine` clamps
  on a `contentSize` shrink). Lurch tests measure `TestScrollEngine.liveViewportOffset`, never `engine.offset`.
- **Stopping a render-server flight is a SWAP, not a removal**: the stop is presented frames after it is
  sampled, so freezing at `liveOffset(now:)` snaps back. `catchFlight(braking:)` stops at `brakeStopTime()`
  (link `targetTimestamp` + one frame) by swapping in `truncated(at:)` on the flight's own `startTime`. Bias
  late (early costs a few ms; late is the step). Only interactive catches brake;
  `setOffset`/`haltMotionInPlace`/`tearDown` impose their own position. `presentation()` cannot detect it.
  `FlightCatchContinuityTests`; `TestScrollEngine` keeps the hard stop.
- **A touch-down catch idles the physics too** (`core.cancelDeceleration()` in `catchMotionForFingerRest`): the drag
  that would rebuild it may never begin (an ancestor's pop recognizer wins, a tracking `UIControl` refuses it), and a core
  left `.decelerating` with no driver reported `isScrollDecelerating` until the next drag and took the next tap for
  another catch (`lastTouchCaughtMovingContent`). The streak is decided before it (`beginTouchTracking`).
  `CatchWithoutDragTests`.
- **UIScrollView's one-frame release hand-off is a model-write driver's compensation; a baked deceleration
  must NOT keep it.** (`-[UIScrollView _endPanNormal:]` steps once synchronously from
  `now − 1/maxFPS`; `.stepped` inherits it.) A baked `Trajectory` played from an explicit `beginTime` is
  already a delay in at its first presented frame, so the hand-off steps it FORWARD at lift. `launchFlight`
  runs `applyDecelerationHandOff` only as a settle probe, then rewinds the CORE exactly to the release state
  before baking (`engine.offset` must describe the screen). Model-vs-model checks (A/B harness, distance
  fixtures, `sampleTick`) cannot see it; `FlightLaunchContinuityTests` can.
  - **D (commit-to-display depth) is a platform constant; the Simulator is D = 0.01 frames, the device is
    inferred D ≈ 1 (unmeasured: `MTLDrawable.presentedTime` is gone from the iOS 27 SDK). Don't tune the
    opening against the Simulator.** The residual is `(D − 1) × frameTravel`. Measure with the Pipeline tab
    (`PipelineDepthProbe`, `Tools/measure-pipeline-depth.py`), captured via `simctl io recordVideo` (never
    `simctl io screenshot`, which re-renders), and always run `--sweep` (a commanded offset must come back as
    an equal gap) before trusting a near-zero reading.
  - **The probe step can END the deceleration**, so `launchFlight` re-checks `core.isDecelerating` before
    baking: `endDrag` reports `.decelerate` for a cancelling blend (threshold on the RAW last sample,
    low-passed velocity below `Deceleration.velocityFloor`) and for an overscrolled release inside
    `settleTolerance`; a `KeyframeFlight` from the resulting `.idle` core trips its precondition. Only
    `.keyframe` is exposed (`TestScrollEngine` applies no hand-off; test scale 1 hides pixel-grid effects).
    `FlightLaunchPreconditionTests`.
- **A settle at an edge must land ON the edge** (`Deceleration.settleIfNeeded`; every `step` exit goes through
  it, not `settled()`), as a `UIScrollView` bounce lands on `-contentInset`. Unclamped, a 3× grid parked
  bounces at −1/3 pt and `ChatHistoryListNodeImpl`'s `visibleContentOffset() < -0.1` check left an invisible
  94pt view eating taps. Anything thresholding an offset is exposed.
- **The bounce springs toward the edge the deceleration CROSSED** (`Deceleration.spring(dtMs:toward:)`), never one
  re-derived from the offset. A release on (or within rounding of) the min edge moving past it integrates to the edge
  in ~zero time and can still be `>= min`, which `offset < min` read as the max edge: at a chat's newest end (open max = the
  10,000,000 pt sentinel) a short quick flick whose pan began and ended at `tr=0` flew the list ~800,000 pt up its
  history (issue #99). `test_flickReleasedOnTheNewestEdge_withNoTranslation_staysAtThatEdge`.
- **Physics flights ignore Slow Animations** (accepted, unverified against `UIScrollView`): real-second
  trajectories at `speed` 1; `.stepped` uses real deltas. To change it, scale playback (`speed`), not sample
  times, and check `KeyframeFlight`'s rebake/splice time comparisons.
- **Release is a 2-D, gesture-LIFETIME decision, and `.began` is a velocity sample** (`ReleaseDecision`):
  threshold `vx² + vy²` on the RAW last sample before the 0.75/0.25 low-pass, which is guarded on a non-zero
  previous pair; the repeated-flick multiplier outlives the gesture (`beginDrag` rebuilds `ScrollPhysics`).
  `.began` contributes a sample and its translation (as `handlePan:` case 1; treating it as setup released
  short flicks at a quarter of their velocity); a force-begun pan feeds nothing. `Deceleration.spring` must
  NOT apply `vScale`; only the free-decel term and its to-the-edge sub-step do.
- **A dead axis must not answer for a live one**: x is a dead axis and `ScrollPhysics.step` ORs the axes'
  "ended" flags, so `ScrollAxis.step` reports one only if the deceleration was RUNNING (complement of
  `settled()`). Otherwise the streak clears every release and the multiplier stays 1. Streak tests must step
  the integrator between flicks; `test_theFourthFlickOfABurstTravelsFartherThanTheSameFlickAlone`.
- **Harnesses must drive production's entry points.** A foreign recognizer (the A/B view's
  `UIScrollView.panGestureRecognizer`) must call `noteTouchDown(at:)` or `core.beginTouchTracking` never runs
  and the multiplier sticks at 1 (the trackpad path never calls it either). `ScrollReplay.replay` is the integrator oracle; `ScrollReplay.replayEvents`
  drives events as `applyPanUpdate` does (the seam oracle). `applyPanUpdate` takes indirect-ness as a
  parameter (an untouched recognizer reports `isIndirectScroll == true`). Whether UIKit applies the
  fast-scroll multiplier to trackpad scroll is unverified — don't "fix" by analogy.
- `UIScrollView` clamps `bounds.origin.y` writes: set content limits before non-zero offsets in tests.
  Trackpad scroll ignores `pan.setTranslation(.zero)`: keep the engine's explicit translation baseline.
- **The mouse wheel shares the trackpad's indirect path.** `PhysicsPanGestureRecognizer` allows `.all`
  scroll types; with only `.continuous` the wheel never reached the pan and the chat history did not
  scroll on iPad. A wheel gesture gets no touch-down, the trackpad rubber-band coefficient, and the
  `shouldReceive(event:)` forced `.began` + translation baseline when a notch lands on moving content.
  **Unverified on a device** (the iPhone simulator takes no pointer input): whether a notch during
  momentum is swallowed or jumps back, how far each burst coasts, whether the first notch waits on
  `NavigationContainer`'s pop recognizer. Check those on an iPad with a mouse before changing this path.
  If bursts over-coast, the likely cause is `UIScrollView`'s discrete release clamp, which `ReleaseDecision`
  does not model (analysis §4, "Discrete / paging flick"). The News feeds share this recognizer.

### Gestures and touches

- **The limbo gotcha: never grant gesture simultaneity from the list's pan, and never declare a failure dependency on
  it.** A grant wins over refusals elsewhere (nested scroll views, `ContextGesture`'s
  `other is UIPanGestureRecognizer -> false`), so content and history scroll together; the tempting repair,
  `shouldBeRequiredToFailBy`, holds the recognizer in `.possible` until lift while `ContextGesture` runs its
  press animation on its own timers — animation without activation, the limbo. `ListViewImpl` has neither
  construct. Tap-only demo rows cannot catch a regression. `PhysicsScrollEngineTests`.
  - **Mirror half: ancestors declare it about us** (`NavigationContainer`, `NavigationModalContainer`), so the
    pan cannot recognize until the interactive-pop recognizer fails (~2pt off-axis, or at lift) — fine for a
    drag (~10pt hysteresis), unresolved at the forced `.began`. Nothing time-critical may ride `.began`
    (derived from source, not observed): the flight catch lives in `noteTouchDown`, `.began` keeps an
    idempotent catch for trackpad. Absorption still degrades meanwhile; the candidate cure
    (`disablesInteractiveTransitionGestureRecognizerNow` while content moves) kills the edge swipe during a
    fling and needs a device pass. Don't answer it from the engine's own delegate.
  - **A pan that FAILS reports the lift from `reset()`**: `PhysicsPanGestureRecognizer` reports it once (`PhysicsPanTouchUpTests`), or content caught
    overscrolled stays off its edge.
  - **`delaysTouchesEnded` must stay `false`** (the recognizer default is `true`; match
    `UIScrollView.panGestureRecognizer`; asserted in `PhysicsScrollEngineTests`), or `UIControl`s in rows
    (inline bot keyboards) never see touch-up.
  - **A scene deactivating cancels a pan that is not idle, and so does its activation if no finger came down
    since** (`sceneActivationChanged`, an `isEnabled` toggle; the drag ends at rest; a host-disabled pan stays off).
    Defensive, for #127 (iOS 27.2 devices: after Home and back the chat did not scroll until reopened); the cause is
    unconfirmed on a device, where a swipe Home starting on the list is suspected of leaving the pan holding a touch
    the system took. The simulator resets the pan itself and never showed it. `SceneActivationTouchResetTests`.
    It does not cover a still finger: there the two-finger selection pan and the back swipe stay `.possible` on the
    touch, so the pan, failed (or cancelled by this), is never reset. The main window lets go of every recognizer
    holding a touch at the same scene changes (Display's `WindowTouchRelease`, `TOUCH-RELEASE` trace lines), which
    covers both; reproduced on the simulator by withholding a touch's end from the window. The window runs after
    this handler (dispatched to the next turn), so a drag still ends here, at rest, and the window lets go of the rest.

### Attachments

- **Every view in the attachment chain must be a passthrough.** `AttachmentContainerView` answers
  `point(inside:)` by asking its subviews (never bounds); a host asks its hosted content's `hitTest`, not its
  `point(inside:)`. Scrolling still works when this breaks, so the list looks healthy with nothing tappable.
  `AttachmentContainerHitTestTests` covers the container; the TelegramUI host half is untested.
- **Attachment stacking resolves INSIDE the solve.** `CoreListAttachedItem.stackingGroup`/`stackingYield` (group + minimum gap);
  `AttachmentOffsetMap.y(atOffset:)` takes `min` over OVERLAPPING partners, iterated to a fixed point,
  clamped at the band top. A post-solve fix-up would be missing from the track `composedKeyframe` bakes for
  flights. **One level only** (asserted). A yielding attachment's `stickDistance` uses the adjusted bound;
  `renderAttachments` re-asserts sibling z-order every render.
- **Frame and stick distance solve at DIFFERENT offsets, deliberately**: the frame at
  `attachmentSolveOffset` (the flight's destination; the keyframe supplies the displacement),
  `stickDistanceUpdated` at the live `engine.offset`. Both via `AttachmentOffsetMap.y(atOffset:)`;
  `AttachmentKeyframeParityTests.testStickDistanceDescribesTheRenderedPositionAtEveryVertex`.

## Project conventions

- Stage task-named files by explicit path; never `git add .`/`-A`.
- K2 simulator and xcodebuild flags: see Build / Test.

## Documentation authority

This file is the concise current contract. `docs/plans/` holds foundational designs and reverse-engineering
analyses, `docs/plans/CHANGELOG.md` a digest of landed work;
everything superseded is in Git history.
