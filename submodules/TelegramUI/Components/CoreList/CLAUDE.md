# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

> **How to use this file.** It is a map, not a substitute for the source. Each architecture section
> ends with a **`📖 Read before changing:`** list. Read those files and the matching design before
> editing that subsystem.

## Project

iOS UIKit demo (Swift 5, iOS 26.2 deployment target) showcasing `CoreVirtualListView`, a custom
virtualized scroll view that renders only a loaded window from a large item collection. Single Xcode
scheme: `CoreListDemo`. Test target: `CoreListDemoTests` (XCTest).

**This directory (vendored into telegram-ios) is the source of truth.** `~/Documents/CoreListDemo`
is a stale backup, not the live project. `CoreListDemo.xcodeproj` is committed here even though the
root telegram-ios `.gitignore` ignores `*.xcodeproj` — it is re-included via a `!CoreListDemo.xcodeproj`
negation in this directory's `.gitignore` (the same trick `Telegram/WatchApp` uses for `tgwatch.xcodeproj`),
so the demo + tests build and run on the K2 simulator directly from within telegram-ios. The project
uses `PBXFileSystemSynchronizedRootGroup`, so it tracks the `CoreListDemo/` + `CoreListDemoTests/`
sources on disk automatically (only `Info.plist` is a membership exception). `project.xcworkspace` and
`xcuserdata` stay git-ignored; xcodebuild regenerates the implicit workspace, so a fresh clone builds
with just the committed `project.pbxproj` + shared scheme. These files are **excluded from the Bazel
`CoreList` swift_library** (see `BUILD`), so the Telegram app build does NOT compile the demo/tests —
the xcodebuild suite below is their only build/verification surface.

## Build / Test

```bash
# Build
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' build

# Run all tests
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO -collect-test-diagnostics never test

# Run one test class
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO -collect-test-diagnostics never test \
  -only-testing:CoreListDemoTests/CoreVirtualListAnimationTests
```

Every test command must use all three mandatory options:

- `-destination 'platform=iOS Simulator,name=iPhone 17 Pro K2'` — use only the dedicated K2
  simulator. A generic similarly named simulator is a different device and may be in use.
- `-parallel-testing-enabled NO` — keep one boot target and deterministic execution.
- `-collect-test-diagnostics never` — **without this, any run with a failing test hangs forever.**
  xcodebuild defaults to `on-failure`, and on failure it blocks in
  `XCTHRunDestinationAllocator.collectSimulatorDiagnostics` gathering a sysdiagnose; with several
  simulators booted it effectively never returns. Measured on a deliberately-failing test:
  5.26s with the flag, still blocked after 240s without it (and only ~1.7s of CPU, so it is waiting,
  not working). A PASSING run exits in ~5s either way, which is what makes this so confusing — the
  hang appears only when you have something to fix.

The project uses `PBXFileSystemSynchronizedRootGroup`; files added under `CoreListDemo/` or
`CoreListDemoTests/` are discovered automatically without editing `project.pbxproj`.

## Architecture

Core files are `CoreVirtualListView.swift` (diff, settled window, rendering, transaction composition),
`ListAnimationModel.swift` (analytic state), `ListAnimationController.swift` (model/layer lifecycle),
`CoreAnimationCompiler.swift` (CA keyframe output), `Scheduler.swift` (deferred dirty flush), and the
scroll-engine seam.

### Scroll-engine seam

`CoreVirtualListView` consumes `ScrollEngine`; it does not touch `UIScrollView` directly. The seam
provides `offset`, programmatic `setOffset`/`applyShift`, edge declaration, user-scroll callbacks
(`onScroll` per-frame, plus `onWillBeginDragging`/`onDidEndDragging` when the pan reaches
`.began` and `.ended`/`.cancelled` — UIKit via `scrollViewWillBeginDragging` /
`scrollViewDidEndDragging`, physics via `handlePan`), `contentHost`, and
`containerOrigin(windowHeight:topLoaded:bottomLoaded:)`. The drag pair brackets the **finger-down
interval only**: neither fires for momentum, bounce or programmatic writes, so a host can maintain a
`ListViewImpl.isTracking` equivalent from them.

It also provides `shouldStopScrollingOnRelease`, consulted ONCE per release with the recognizer
velocity, before the engine decides whether momentum follows. It exists for a host whose release was
already claimed by something outside the list — the chat's history is dragged by the same finger that
interactively dismisses the keyboard, and that dismissal is decided in touch DELIVERY, so it is known
by the time the pan's `.ended` reaches the engine in action dispatch. **Suppression is expressed as a
zero-velocity release, not as skipping the release:** `ReleaseDecision` answers `.stop` for a zero
sample and expires the repeated-flick streak (what a genuinely slow release leaves behind), and `.stop`
while overscrolled still installs the spring-back — skipping `endDrag` instead would strand an
overscrolled list off its edge. `ListViewImpl.shouldStopScrolling` is the same hook on the other chat
backend, and `UIKitScrollEngine` honours it the UIKit way, by projecting `targetContentOffset` onto the
current offset. Covered by `ReleaseSuppressionTests`.

- `UIKitScrollEngine` is the production default and the only list component that knows
  `UIScrollView`. It owns the private 10,000,000-point virtual canvas and prevents programmatic
  offset writes from re-entering the user-scroll callback.
- `PhysicsScrollEngine` is an additive selectable backend with `.stepped` and `.keyframe`
  deceleration. A finger on moving content grabs the scroll and absorbs the stopping tap. **Those are
  two mechanisms on two different clocks, and only one of them is under this engine's control.** The
  STOP is `noteTouchDown` — touch delivery, which nothing can hold; the ABSORB is the forced `.began`
  (`shouldBeginImmediately`), which is plain UIKit gesture exclusion: the engine grants NO
  simultaneity to any recognizer, so a pan force-begun on moving content fails the content recognizer.
  There is deliberately no `shouldBeRequiredToFailBy` counterpart; see the arbitration gotcha below
  before adding either, or before moving anything onto the `.began` path.
- Both physics modes use `PhysicsScrollCore`. The keyframe mode renders deceleration through
  `KeyframeFlight`; coordinate-only rebases update its persistent shift without restarting the
  flight, while a true edge or trajectory-shape change rebakes with a seamless splice. A real edge
  change is a durable trajectory invalidation: it survives sampling-tick boundaries, coalesces with
  later edge changes, and is consumed only after one continuous rebake against the latest bounds.
  A shift is translation-only while both edges are open. If either edge is finite, moving the
  engine offset while that edge stays fixed changes relative trajectory geometry, so the shift and
  latest edges are folded into one continuous re-bake. Pending invalidation outranks completion of
  the obsolete sampler or CA trajectory, preserving analytic current position and velocity whenever
  motion remains. Only an edge that can REACH the flight's remaining path counts as a real change:
  the deceleration integrator is edge-independent until the path crosses an edge, so the declared
  edges plus the baked offset band identify the motion, and a change outside that band leaves the
  flight — and the animation the render server is already playing, with its completion — untouched.

The UIKit-backed suite remains the core-list additivity oracle. The physics-backed list path is
covered by `PhysicsListIntegrationTests` plus the physics and keyframe unit suites. The Virtual List
demo defaults to `PhysicsScrollEngine` with keyframe deceleration; UIKit and stepped physics remain
selectable from the engine control.

`ScrollEngine.offset` is **the physics scroll position, advanced once per frame** by whichever driver is
running — never a sample of a running animation. See the gotcha below and
`docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md`.

📖 **Read before changing:** `ScrollEngine.swift`, `UIKitScrollEngine.swift`,
`PhysicsScrollEngine.swift`, `PhysicsScrollCore.swift`, `KeyframeFlight.swift`, and designs
`docs/plans/2026-05-26-scroll-engine-seam-design.md`,
`docs/plans/2026-05-26-physics-scroll-engine-design.md`,
`docs/plans/2026-05-26-keyframe-list-deceleration-design.md`, and
`docs/plans/2026-05-28-trackpad-list-engine-design.md`.

### Virtual content and settled window

The list declares scrollable limits through `engine.setEdges(min:max:)`. `UIKitScrollEngine` maps an
open edge to its private virtual canvas and a fully bounded list to a tight viewport-aware range.
The plain `container` holds loaded live views:

- top loaded: minimum edge 0 and container origin 0;
- bottom loaded: the engine supplies the bottom-aligned origin;
- neither edge loaded: the engine supplies its neutral origin and `applyShift` preserves screen
  position across container rebases.

A row declaring `pinsToBottomEdge` is held against the viewport's bottom edge. **That is two
mechanisms answering two different questions, and collapsing them into one number is the defect family
this replaced** — the analogue of `ListViewImpl`'s `experimentalSnapScrollToPinnedItem` +
`calculatePinToEdgeTopInset`:

- **`holdsPinnedRow` — a latch, answering WHERE the row goes.** Engaged by an explicit `scrollTo` at
  `lowestPinnedItemIndex` (`ListView.swift:2737`); released on `engine.onWillBeginDragging`
  (`:879`), on the pinned row leaving the collection, and on a full replace. Release is **permanent**
  for that pin: scrolling back to the edge does not re-engage it, and only a new `scrollTo` does. The
  release is the TOUCH, not the movement, so every programmatic offset write — self-update flushes,
  inset changes — keeps the pin. While engaged, `resolveAnchor` returns a `.resolved` `ResolvedAnchor`
  on the pinned row (directly below the `scrollTo` branch, so an explicit jump still wins and
  `preserveVisibleContent` does not). Its placement reads **only the pinned row's own height**, so it
  has no loading precondition — anchoring on a row loads it.
- **`bottomEdgePinSlack` — extra top-inset slack, answering whether there is scroll ROOM to rest
  there.** Positive only while the content above the pin is shorter than the viewport;
  `max(0, …)`-clamped exactly as `ListView.swift:1134` clamps it. Derived from the built window's own
  geometry, reading only intra-window offsets so it is answerable inside the very alignment step that
  consumes it, and folded into an effective top inset at three points: `buildWindow`'s `topEdge`,
  `loadedEdgeRange`'s `minimum` (the one that makes it survive user scrolling and self-update flushes,
  since render and rebalance both go through there), and `rebuildFromScratch`'s initial offset.
  `applyChanges` compensates inset changes against that effective edge rather than the raw inset.

The two are **matched by construction**, which is why the clamp cannot strand the anchor: the pin's
target sits exactly `visibleArea − span + ext` points past the natural minimum, the same expression the
slack returns. Positive and the edge extends by precisely that much; negative and the target is already
inside the natural range.

**Never un-clamp the slack.** It was, briefly, to make the edge hold the row without a latch. A
negative slack is placement leaking into a scroll-range quantity: it reached `loadedEdgeRange`'s
minimum and extended the range into empty space, so on device a tall streaming reply could not be
scrolled down to at all — it overscroll-bounced. **And the slack must stay latch-INDEPENDENT**, since
release happens at finger-down: a range that shrank with it would move content under the user's finger
before the drag had travelled a point.

`isStrictlyPinnedToBottomEdge` answers "is the row held", and reads the **latch** plus a presented-frame
check that the animation has landed. Not geometry: with a latch there is no such thing as a row at the
edge by coincidence, and the old `slack != 0 || ext > 0` guard reads false in exactly the tall-content
regime where the pin is most firmly held. `ChatControllerLoadDisplayNode.swift:900-904` uses it to
decide whether **sending a message drops the pin**, so it is not only the scroll-to-bottom button that
depends on it.

`appendUntilPinnedRowLoaded` still exists and runs only while the latch is **disengaged** (an engaged
latch anchors on the pinned row, making it window member zero). Its `window.height < visibleArea` bound
is **correct** under the clamped slack — once the rows above the pin alone exceed the viewport the
slack is zero regardless of the pinned row's height. It was patched once on the theory that it was
defective; the patch made device behaviour worse and was reverted. Do not patch it again.

**A released anchor rides the EFFECTIVE top edge (`inset + slack`), and that is what absorbs a
streaming reply's growth.** The slack shrinks by exactly what the content above the pin gains, so an
anchor holding its distance from that edge lets the reply extend into the room the slack gives up
while the pinned row — and all the history below it, which is what the user is reading — holds still.
That is already what happens resting at the edge, which is why only the released state was ever wrong.
Held at an ABSOLUTE offset instead, nothing takes up the retreat and every point of growth pushes the
rows below: measured as pinned 200 → 250 → 300 → 350 → 400 → 440 for reply 100 → 340, and reported
from the device as the chat drifting upward mid-stream. The settle clamp then cancelled only the part
that crossed the edge, which is the same absorption arriving late, partially and in one jerk —
+100, **+40, +60**, +100 for four equal 100pt steps, drift-tug-drift-tug. Once `span` reaches the
viewport the slack clamps at zero and there is nothing left to spend, so the growth pushes; that
regime is unchanged.

Mechanically it is one addend, and it lives in **`buildWindow`'s `pinSlackBaseline`** because it needs
the NEW window's slack, which exists nowhere earlier. `topInsetDelta` carries the geometry half and
structurally cannot see this one — both of its samples read `oldWindow` and the old items, so they
differ only when `logicalSize` or `viewportInsets` changed. It is deliberately NOT gated on
`compensatesInsetChange` — a caller whose own drag owns the movement still wants growth absorbed rather
than pushed under its finger.

**Two conditions gate the baseline, and the second one is the subtle one.** Only a `.fixed` anchor
takes it: a `.resolved` one (an explicit `scrollTo`, or the latch itself) computes placement from the
geometry the pass is building, and the `pinsLoadedTop` branch translates onto `topEdge` outright. And
only an anchor **above** the pinned row — an anchor above the pin has to MOVE by the spend to deliver
the invariant, while one at or below the pin delivers it by HOLDING, its old screen position already
being the right answer because nothing above it can displace it. Projecting there moves it by the whole
slack delta. That is not hypothetical: it is the pass that ENDS a stream. The typing draft carrying
`TypingDraftMessageAttribute` is replaced by the real cloud message
(`ChatHistoryListNode.swift:2240`), so index 0 departs, `topItemWasDeleted` sends `resolveAnchor` past
it to the first survivor — the pinned row — and the final message measuring differently from the last
draft moved the pin by exactly that difference. Reported as one small jerk at the end of streaming, and
"usually" because the two often measure the same. `testTheDraftBecomingTheRealMessageDoesNotMoveThePin`
locks it.

Because the anchor moves with the edge, a parked user's distance from the declared minimum is
invariant and they can no longer be clamped at all. Three things are known NOT to work here, and
re-deriving them is expensive:

1. **Collapsing the slack at finger-up** yanks a short-reply chat ~210pt on any small drag-and-lift.
   Benign only when the slack is already small — i.e. when there was nothing to fix.
2. **Reserving the room the user is standing in** (a stored floor under the slack, gated on the drag
   event) does stop the tug, and is the wrong cure: it freezes the effective edge, so the growth it
   was meant to protect goes straight back into pushing the rows below, and the chat drifts for as
   long as the user stays parked. Absorption removes the clamp's reason to fire instead of outvoting
   it. Built, device-tested and abandoned; it needed a stored value, an event gate, three retirement
   rules and three guards, all to outvote a clamp that then had no reason to fire.
3. **Fixing only the settle clamp** reaches one of two movers: `buildWindow`'s `topEdge` feeds
   `alignTopIfUnderfilled`, which places the window before the clamp ever runs. Anything acting on the
   effective edge must act on both, which is why the projection is a window translate rather than an
   offset correction.

Also unresolved and **unreproduced**: a mid-stream send reportedly snaps although the pin survives. An
engaged latch should be immune, so suspect that `isStrictlyPinnedToBottomEdge` reading the PRESENTED
frame answers false mid-animation, `ChatControllerLoadDisplayNode.swift:900-904` nils
`pinToTopStableId`, and the `lowestPinnedItemIndex == nil` release fires — which is **permanent**, and
cannot tell a transient absence from a real one.

`docs/superpowers/specs/2026-08-04-corelist-pin-to-edge-design.md` (telegram-ios repo root) describes
the **superseded** slack-only mechanism; this section is the current contract.

`activeWindow` is a pure settled `Window` value containing contiguous `(index, view, frame)` items.
It is the loaded projection of the current item collection, not animation state. Frames are
container-local; `minY` may be negative, and `render()` places each view at
`frame.minY - window.minY`. Absolute content Y is therefore
`containerOriginY + frame.minY - window.minY`.

Transaction windows are built once in final projected viewport coordinates against
`-preloadMargin ... logicalSize.height + preloadMargin`. Loaded-edge constraints are resolved during
that bounded traversal; render-time container parking is membership-neutral. User-scroll
rebalancing uses the same projected load band. When a container rebase is required, the engine
offset and any exit-overlay children receive the same shift so their visible positions do not jump.
For size/inset transitions, the shared anchor's old-to-new absolute content-Y delta identifies that
coordinate-only rebase. Without an explicit `scrollTo`, a top-inset change projects the resolved anchor
point by `newTopInset - oldTopInset` before the one-pass window build, preserving the anchor's settled
distance from the inset edge — unless the caller passes `compensatesInsetChange: false`, which drops
**only** that addend so content holds its screen position while the inset edge moves under it (see
`applyChanges` below). Window construction traverses toward lower indices and clips at the loaded
top first, then traverses toward higher indices and clips at the loaded bottom; top wins for an underfilled
collection. The completed projected window is the sole source of the new settled engine offset. The
anchor coordinate shift is used only to cancel container parking in the additive viewport track. Shared rows do
not receive compensating position tracks, and captured overscroll is restored only after settled edge
resolution as presentation-only state; moves keep ownership of their geometry.

`applyChanges(anchorMode: .preserveVisibleContent)` is an opt-in infinite-loading policy. It selects
the loaded item crossing the old top-inset edge from settled geometry and preserves that identity's
own distance from the inset edge. A moved identity remains the witness; a departing identity falls
back to the nearest loaded survivor below, then above. The policy never measures old off-screen rows,
never post-corrects the engine offset, and yields to explicit `scrollTo` and normal finite-edge
clipping. `.automatic` retains the finite-list edge behavior.

`reachedLoadedEdges` exposes which finite collection edges the settled viewport currently reaches,
and `onLoadedEdgeReached` reports only transitions into those states. Load-line observation is
independent of content insets and engine limits. The top line is `loadedEdgeMargin`; the bottom line
is `logicalSize.height - loadedEdgeMargin`. Positive margins load later, negative margins load
earlier, and overscroll is excluded by using the settled clamped engine offset. The list recomputes
the deduplicated state after construction, mutation settlement, user-scroll rebalancing, and margin
changes. This is an observation seam only: pagination, batching, and item creation remain
caller-owned.

**Host-facing embedding seam** (used by the TelegramUI `ChatHistoryListViewBackend` adapter):
`onVisibleWindowChanged` fires after each user-scroll rebalance; `onLoadedEdgeReached` reports
edge transitions (above); `willBeginDragging` / `didEndDragging` fire on interactive drag start and end
(forwarded from `ScrollEngine.onWillBeginDragging`/`onDidEndDragging`; the analogues of
`ListViewImpl.beganInteractiveDragging`/`endedInteractiveDragging`, and together the finger-down
interval a host needs to reproduce `ListViewImpl.isTracking`); `shouldStopScrolling` forwards to
`ScrollEngine.shouldStopScrollingOnRelease` so a host can decline the momentum of a release it has
already spent elsewhere (above).
`loadedItemViews` is a **non-copying** `Sequence` over the settled window's item views in ascending
index order — it walks `activeWindow.items` in place (a COW snapshot; no array built, no element
copied, safe to mutate the list mid-iteration), the iterator-based analogue of
`ListViewImpl.forEachItemNode`. It visits only loaded rows, never off-screen entries or exit-overlay
ghosts. `loadedItemView(at:)` is its index-keyed sibling, resolving one collection index to its loaded
view (nil outside the settled window) — this view owns `activeWindow` and is therefore the authority on
the index ↔ view mapping, so hosts must use it instead of walking `loadedItemViews` to a position
inferred from `loadedIndexRange`. `loadedItemEntries` is the same in-place walk as `loadedItemViews`
but yields `(index, view)` pairs, for hosts that need each row's collection index during a full-window
pass (computing a visible range, say) without counting iterations — array position equals collection
index only while the window still starts at 0.

`animateInsertedBlock(identities:origin:transition:)` slides a run of rows in from just beyond one edge
of where they settled, as one rigid block — every named row takes the same offset, so the run keeps its
spacing for the whole travel. **The host names the EDGE (`CoreListBlockOrigin`, stated in content order,
not on screen — a rotated host reads the cases the other way round) and this view measures the
DISTANCE** (the block's own total settled height, reserved space included), because the heights come
from the very pass the call follows. Unloaded rows are skipped: no layer, and nothing to see. It exists
because an entering row otherwise appears in place, which is correct for the model and wrong for a chat;
`CoreListChatHistoryBackend` calls it for messages arriving at the newest edge. **It is list-owned
deliberately** — a host installing its own additive position animation would have it read back as a
CoreList track by `capturePresentedPositionOffsets()` at the next pass (see the granular-animation
contract), and going through `transitionPosition` is also what lets an overlapping arrival compose with
the slide already in flight. Safe to call straight after `applyChanges`: it defers onto the same
scheduler behind a pass that was itself deferred for re-entrancy, which a synchronous window read could
not survive.

**Row geometry is a pair, and picking the wrong half is silent.** `presentedFrame(of:)` is where a row
IS — the default, and what a host must use instead of `convert(_:from:)` (see the
`contentHost.bounds.origin.y` gotcha below). `settledFrame(of:)` is where it WILL BE once the
animations in flight finish; it is exactly `presentedFrame` without the correction. A host wants
settled in one situation only: reporting the OUTCOME of a pass it just submitted, alongside that
pass's transition, so a consumer animating on that transition arrives where the content will. At that
moment presented is the *pre-animation* position and nothing re-reports when the animation lands —
there is no per-frame hook outside user scrolling. Both are ancestor-path-agnostic, so a row carried
by `crossingOverlay` converts correctly either way. Reporting presented at a transaction point is a
real shipped bug, not a hypothetical: see "Content offsets" in
`docs/chat/corelist-chat-history-backend.md`.

`visibleRectUpdated(_:)` on `CoreListItemView` pushes each loaded row the part of itself inside the
viewport, in the row's own coordinate space, or `nil` when it is not visible. It fires after the final
engine offset is installed in `applyChanges` and `rebuildFromScratch`, and at the end of
`handleUserScroll`, using the projection `rebalanceActiveWindow` uses (settled frames at the live
engine offset), against the FULL
viewport rect: inset space is visible, interactive list space. During a programmatic animated viewport
move it therefore reports the destination, which is the window that pass already loaded; there is no
display link here to sample an in-flight animation. Do not publish from `render()`: mutation passes
have installed the new window there but still carry the old engine offset, so destination rows can
remain incorrectly invisible until the next user scroll. A row leaving the live window is notified `nil`
by one uniform rule — the notifier holds weak references to the views it last reported visible — which
covers rebalance unloads, ghost-block members and the transient exit-overlay carry alike. It has a
default no-op, so item views opt in. `CoreListNodeHostView` (TelegramUI) maps it onto
`ListViewItemNode.visibility`.

📖 **Read before changing:** `CoreVirtualListView.Window`, `buildWindow`, `render`,
`rebalanceActiveWindow`, `loadedEdgeRange`, and design
`docs/plans/2026-03-21-virtual-list-rewrite-design.md`, plus
`docs/superpowers/specs/2026-07-22-projected-anchor-inset-transition-design.md` for inset transitions.

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

`compensatesInsetChange: false` drops the `newTopInset - oldTopInset` anchor projection and nothing
else — the new insets still drive content x/width, the viewport band, the load band and the
loaded-top pin, so at the loaded top index 0 still rides the inset edge. It is the analogue of
`ListViewImpl` zeroing `offsetFix` while tracking (`Display/Source/ListView.swift:3276`) — which
likewise still assigns `self.insets` and still runs `snapToBounds`. It exists for an inset change
produced by the user's own in-progress drag, where compensating on top of the scroll doubles the
finger's travel; deciding that a pass is such a case is caller policy (`CoreListChatHistoryBackend`
does, from `willBeginDragging`/`didEndDragging`). Do NOT emulate it with
`additionalScrollDistance: -topInsetDelta`: a non-zero distance halts momentum and opts the pass out
of `pinsLoadedTop`, so the loaded top stops tracking the inset edge.

`CoreListScrollTarget` carries the target index and a **resolver** rather than a fixed offset:
`resolve(measuredHeight, view)` returns the row's settled Y as an offset from the top inset edge
(projected screen target = `viewportInsets.top + returned value`). It is called exactly once, inside
`buildWindow`, immediately after the anchor row is measured — the only point at which a
height-dependent placement (bottom-align, center, make-visible) can be computed for a target outside
the loaded window, which is what a host's far jump always is. The closure must be pure with respect
to the list: it may read geometry, never mutate the collection or re-enter `applyChanges`.
`CoreListScrollTarget(index:pointOffset:)` is the constant-resolver shorthand and is exactly the old
tuple. This keeps every host-specific placement semantic in the host —
`CoreListChatHistoryBackend` resolves `ListViewScrollPosition` there, including
`scrollPositioningInsets` and quote rects, and CoreList learns none of it.

All mutations flow through one transaction. A pass:

1. serializes re-entrant requests and applies `newSize` to `logicalSize`;
2. validates unique identities and computes survivors, inserts, deletes, and LIS-derived moves;
3. captures one transaction clock and the old settled live state, including analytic position, height,
   and opacity values;
4. reconciles changed content in reused views and remeasures dirty rows at the current width;
5. resolves the anchor and builds the new settled window, reusing survivor and move views;
6. transfers loaded departures to the exit overlay, then renders final live frames and scroll edges
   with implicit layer actions disabled;
7. binds newly loaded layers, independently transitions every loaded survivor whose settled position or
   height changed, and starts opacity-only fades for genuine inserts.

Insertions, removals, replacements, moves, and mixed passes compose from those independent rules.
The old container-wide animation path is gone. Every loaded survivor is evaluated on every pass. Final
settled frames are written immediately; each changed settled position and height then transitions
independently from its analytic current presentation on the pass duration and curve, even if that property
had no prior track. An unchanged endpoint remains an exact no-op.

📖 **Read before changing:** `CoreVirtualListView.applyChanges`, `ItemDiff`, `settledState`,
`makeExit`, `attachLive`, and `docs/plans/2026-07-20-list-animation-model-design.md`.

### Granular animation contract

`ListAnimationModel` is the sole presentation authority. It depends only on Foundation, CoreGraphics
and QuartzCore — the last solely to evaluate the two system springs through the same
`CASpringAnimation` CA renders — and stores at most one analytic track per stable
`ListAnimationOwner` and `ListAnimatedProperty`. Live owners use
`CoreListItem.identity`; every departure receives a fresh exit-owner serial so a fading old
incarnation and a newly inserted live incarnation with the same identity can coexist. The current
properties are additive horizontal/vertical position offsets, absolute visual width/height, opacity,
and one shared additive viewport offset.

Each `ListAnimationTrack` has a monotonically increasing generation, `from`, `to`, immutable start
time, duration, and a track-owned `CoreListTransition.Animation.Curve`. The transaction rules are
strict:

- unchanged settled position (within `1e-6pt`) is a true no-op: the exact track, generation, phase,
  curve, deadline, and installed CA animation survive untouched;
- unchanged settled x/width/height (within `1e-6pt`) is the same exact no-op for each independent track;
- a changed animated property replaces only that owner/property from its analytic current value,
  guaranteeing C0 continuity; velocity continuity is intentionally not promised;
- a changed zero-duration property settles immediately, while an unrelated zero-duration pass
  cannot erase an unchanged track;
- every loaded survivor whose settled position changes starts or replaces its position track from analytic
  current visible Y, whether or not it already had a position track;
- every loaded survivor whose settled height changes starts or replaces an independent height track from
  analytic current visual height, compiled as absolute `bounds.size.height`;
- inserted rows are installed at their complete final x/y/width/height geometry, seed that complete geometry
  in the analytic model, and fade from 0 to 1; they receive no position or extent animation;
- structural animation membership uses the union of old rendered survivors and the new settled
  viewport-plus-preload window. A survivor present at only one endpoint keeps or receives one live view and
  inherits only the nearest unmoved shared survivor's settled displacement; its own analytic correction
  remains independent. Old-only survivors remain under the scrolling crossing overlay until exact
  position-generation completion, while new-only survivors animate in the live container. No item outside
  that union is loaded or measured, and `activeWindow` remains the pure settled window;
- when no eligible shared survivor witnesses a missing crossing endpoint, contiguous unmoved survivors in
  the same structural region use one boundary translation. The anchorward run edge clears both the raw
  retention threshold and the settled loaded-window extent, and all known member spacing is preserved;
  ownership, tracks, and completion remain per identity. This fallback never expands the settled window or
  measures unloaded geometry;
- a **full-replace carousel** — an explicit `scrollTo` whose old and new loaded windows share no
  identity, AND whose **destination window** is entirely new content — fades nothing at either end.
  Incoming rows install at full geometry and full opacity, and departing rows ride their ghost block
  at the opacity they had. It is one rigid travel between two strips, already owned by the shared
  additive viewport track; the fades only appear because a host expressing a jump as delete-all +
  insert-all makes every row look genuinely new or genuinely departed. `ListViewImpl` slides its
  `temporaryPreviousNodes` out at full opacity too. **The destination window is the right unit, and
  this predicate has been wrong in BOTH directions:** plain loaded-window disjointness fades a
  genuinely new row inserted among survivors where you are travelling to, while whole-*collection*
  disjointness never fires for a real host — chat's non-message rows carry constant identities (the
  unread separator is `4 << 40`) that survive any replace, so one always lives somewhere. What
  decides it is whether anything in the destination was already there. A non-fading exit still
  installs an opacity track with the pass duration — `replace` does not early-out on an equal
  endpoint — so the teardown deadline, generation, binding and completion ledger are unchanged;
- moved identities retain their view and identity and animate each changed geometry property independently;
- resize, inset changes, content reconciliation, and self-update write final settled frames immediately,
  then animate each changed survivor x/y/width/height independently on the pass duration and curve.

Position tracks are additive corrections relative to the current settled endpoint. At a pass
boundary the list samples `oldSettled + oldOffset`, renders the new settled position, and replaces
the changed track with `(currentVisible - newSettled) -> 0`. Because the correction is parent-space
independent, scrolling and coordinate rebasing do not look like target changes.

Width and height tracks are absolute visual extents. At a pass boundary the list samples the analytic
current extent, writes the new settled bounds, and replaces only a changed extent track. Horizontal and
vertical position/extents compose independently, and writing any same settled endpoint is a strict no-op.

`ListViewportGeometry` contains only the list's received size and full `UIEdgeInsets`; the list never
derives parent-space position. Insets define settled content x/width and vertical edges but remain visible,
interactive list space. Size/inset passes resolve one final engine offset and replace one shared additive
viewport track from its analytic current correction whenever the projected, edge-clipped window changes
the viewport target; an unchanged target is an exact no-op. Overlapping geometry, scroll-to, live rows,
crossing carries, carousel carries, and ghost members all use property-level retargeting from the same
transaction clock. Load membership remains the outer viewport plus preload margin, and unavailable
endpoints are never loaded or measured merely to animate them.

`ListAnimationController` owns model-to-layer bindings, applies Slow Animations scaling exactly once,
and passes one captured local clock to every mutation in a list pass. Stable property keys replace
only the affected CA animation. Completions capture the track generation and binding; stale
completions cannot clear a replacement, remove a rebound layer, or tear down a reinserted live view.
Before a layer binds to another owner, all controller-owned keys are removed. If an off-screen owner
becomes live again, `rebind` first reconciles retained height state with the freshly measured/rendered
layer height. An unchanged height target within `1e-6pt` keeps the exact original height track, phase,
deadline, generation, and CA metadata. A changed target settles only height to the fresh geometry and
invalidates only its stale height track/completion; this also covers retained height state without an
active height track. Every remaining track is emitted using its original phase and deadline. An active
unbound owner retains its analytic state through that deadline; the controller schedules a generation-
and binding-safe reap at the analytic completion time, without a display link. Rebinding or replacing
the generation makes the scheduled callback inert.

One property-granular exception applies while an owner is unbound: if a structural pass changes the
owner's predecessor identity set, its position correction safely settles to zero before render/rebind
because unloaded geometry cannot supply an exact retarget endpoint. This includes an owner that enters
the new loaded window in the same pass. Its height and opacity tracks are untouched. An off-screen owner whose
predecessors are unchanged keeps the exact original position track, phase, and deadline.

`CoreListTransition` (`CoreListDemo/Transition/`) is the module's animation descriptor: a
self-contained copy of ComponentFlow's `ComponentTransition` value model, vendored because CoreList
has no Bazel `deps` and the demo builds standalone. The case shape is identical, so
`ComponentTransition.init(_ CoreListTransition)` — in
`TelegramUI/Sources/CoreListChatHistoryBackend.swift`, the only consumer — is a case-for-case map.
It deliberately does NOT round-trip a zero duration: CoreList means "immediate" by it, so the
conversion yields `.immediate` rather than a zero-length animation.
`applyChanges(…, transition:)` is the only mutation entry point; the parallel duration-only overloads
are gone. Production uses `.easeInOut` throughout, and the tests keep `.linear` (via a test-only
`CoreListTransition.linear(duration:)`) as the contrast curve their curve-identity assertions need.
`.spring` samples the app's **adjusted** spring bezier `(0.380, 0.700, 0.125, 1.000)` — what
`CAAnimationUtils.swift:119` emits for `kCAMediaTimingFunctionSpring` at any duration other than the
two it special-cases with real `CASpringAnimation`s (0.5, and 0.3832 on iOS 26); at exactly those
durations CoreList approximates. Note this is deliberately NOT what ComponentFlow's own `solve(at:)`
returns (`listViewAnimationCurveSystem`, which samples the 0.5s spring), so ComponentFlow's analytic
and emitted springs agree only at duration 0.5 — CoreList is analytic-first, so it follows the
emitted curve. `.bounce` is not a unit curve (ComponentFlow's own `solve` asserts on it) and degrades
to `.spring`.

CoreList uses **no `CATransaction` at all**. Every layer it writes is UIView-backed — it creates no
standalone `CALayer` — and a UIView's layer returns a null action by default outside an animation
block, so there is no implicit animation to suppress. (`SimpleLayer`/`nullAction` exists for
standalone layers, which CoreList has none of.) Animation completions attach to the animation itself
through `CAAnimation.setCoreListCompletion`, a copy of Display's `CALayerAnimationDelegate`, rather
than to a transaction. See
`docs/superpowers/specs/2026-07-27-corelist-transition-design.md`.

**A new animation resumes from what the layer is RENDERING, not from the model's analytic value.**
`ListAnimationModel.resumeValue` consults a provider `ListAnimationController` installs over its layer
bindings; `value(for:property:at:)` is untouched and still answers settled geometry, which window
building, `bottomEdgePinSlack` and the `finalize` deadline all depend on. The two are separate methods
so a future change cannot convert the settled consumers by accident.

The model's clock is the pass clock and Core Animation's is the commit that follows, so the analytic
value sits systematically ahead of the screen. That is invisible while one authority owns a layer and
becomes a compounding drift the moment two do — the chat's hosted item node sets its own box from
`presentation()`, and the row and the node diverged one-signed up to 3.2pt per streamed token.

**The provider answers for the ABSOLUTE properties — `.height`, `.width`, `.opacity` — with the
presented value.** Those are the same quantity in the same space as the model's, so there is nothing to
convert and no base to be wrong about.

**And `.positionY` is sampled only for owners whose base a PASS writes —
`ListAnimationOwner.hasPassWrittenPositionBase`, true for `.live` and nothing else.** Pass entry proves
that *this* pass has not moved the base; it proves nothing about a writer that runs BETWEEN passes, and
`renderAttachments()` is exactly such a writer — it rewrites every attachment's frame on every render,
including every user-scroll frame, because a parked attachment stays parked on screen only by moving its
base with the content. `presentation()` therefore trails an attachment's model by one frame of base
movement, and reading that as a contribution starts the next animated pass a whole frame of displacement
away from where the row is drawn. Shipped as a chat whose gutter avatars and date pills snapped, then
animated into place, at the touch-up of an interactive keyboard dismissal: the parked pill's layer read
`model=573.00 presented=515.33` **with no animation on it at all**, and it jumped 57.66pt. The
per-frame passes a drag emits are immediate and settle at once, so the misread costs nothing until the
one ANIMATED pass at lift inherits it — which is why it looks like a dismissal-only defect.
`.exit`, `.transient` and `.ghostBlock` are excluded for the same reason (`shiftExitOverlayChildren`
rebases every overlay child's `position.y` from `render()`, which a scroll rebalance reaches without a
pass); no defect has been observed there, but the property this samples is not true of them either.
Note "committed" is not the bar and could not be: a base written last turn may not have been PRESENTED
when this turn samples, so a per-frame-written base can never be differenced against `presentation()`.
`AttachmentResumeBaseTests` locks both the seam and the rendered position; it needs a scene-attached
window, since a windowless fixture resolves no presentation layer and passes vacuously.

**`.positionY` is answered too, but from a snapshot taken at PASS ENTRY, never sampled in the
provider.** An additive contribution is `presented − the base the render tree was committed against`,
and the only handle on that base is the layer's model value. A pass overwrites it long before any
transition installs: `render()` writes every window item's NEW settled frame
(`CoreVirtualListView.swift:2870`) and the transitions install ~550 lines later (`:2022`); the
crossing-carry path writes the new position explicitly one statement before its own call (`:3012`). So
sampling *there* yields `contribution − (this pass's displacement)`, and `transitionPositionOffset`
adds the displacement back onto `oldSettledY` — **counting it twice**. That shipped once, as a chat
whose every row below a growing message snapped one whole growth backwards and then animated 2× the
distance into place. It looked like an anchorPoint problem and was not; rows carry
`anchorPoint = (0, 0)`, which is what made `presented − model` look like a safe read in the first place.
`ListAnimationController.capturePresentedPositionOffsets()` takes the snapshot before the pass writes
anything — the order `CoreListTransition.setPositionY` (`Transition/CoreListTransition.swift:178`)
already uses — and `applyChanges` clears it in the same `defer` as the rest of the per-pass state.

**Why it became necessary: a model-resumed property and a screen-resumed one disagree about where
"now" is by δ, and the seam the eye watches is their SUM.** A growing row's bottom against the row
below it is one `.height` (screen) plus one `.positionY`, so every re-target lost `δ × velocity` there
and it accumulated — measured as a seam opening 1.9pt over ten 20pt growth steps under a released pin,
~24pt without one, and reported from the device as micro-wobble under a streaming reply. Isolating it
is a one-line experiment: make `.height` decline too and the seam closes to exactly 0.000. This is what
retired the old reasoning that position had "no second authority to drift against" — its own row's
height is one.

`.positionX` and `.viewportOffset` still decline, and the hoist does NOT fix them: their reasons are
not the ordering one. `.positionX` — the transition gets bare `contentX` while the layer gets
`contentX + positionOffsetX`, and that offset is the track's own contribution rather than a within-pass
constant; resolve that disagreement first. `.viewportOffset` — its model is written by the physics
engine outside the commit cycle, so `presented − model` can straddle a frame, and at fling speed a
frame is a lot of points. Measure before switching either on.

Windowless layers resolve no presentation layer, so nothing is captured, the provider returns nil and
the analytic path is taken — which is why the existing suite keeps its exact model-vs-CA assertions
unchanged. `PresentedPositionResumeBaseTests` locks the position arithmetic (one displacement, never
two) at both the seam and end-to-end through a `CoreVirtualListView` in a real rendering window;
`PresentationResumeSamplingTests` locks which properties are sampled; `PresentedResumeSeamTests` locks
the rendered seam between a growing row and the row below it across in-flight re-targets, which is the
consequence the arithmetic exists to protect.

**That same property makes the whole suite blind to this provider, and a test to catch it is vacuous
by default.** `VirtualListFixture` never enters a render tree, so its rows take the analytic path and
the dozen-plus exact `positionTrack(…).from` assertions in `CoreVirtualListAnimationTests` — any one of
which would have caught a doubled displacement on sight — simply never executed the sampled code.
`testFixtureLayersHaveNoPresentationLayer` pins that blindness rather than removing it, deliberately,
and the only test with both a rendering window and a real list pass
(`testRealCACompletionTearsDownExitWithoutAnalyticReap`) asserts teardown and no geometry. So a test
here needs **a scene-attached window AND an owner actually bound to that layer** — the provider guards
on both and returns nil before its switch otherwise, which is how the original
"these properties must not be sampled" test passed against the very defect it named. Assert a sampled
property is non-nil in the same test as the witness. Verify by mutation, not by reading.

**Three forms of this have been shipped and reverted**, all the same mistake — one subtraction mixing
two spaces, or two bases. `.viewportOffset` as `presented - settled`: the viewport's model
`bounds.origin.y` is the live scroll position driven by the physics engine, never the settled offset.
`.positionY` as the presented POSITION with the model subtracting `newSettledY`: the model is handed
`containerOriginY + localY` (`CoreVirtualListView.swift:2818`) while the layer is handed `localY`
(`:3121`). `.positionY` as `presented - layer.position.y` **evaluated inside the provider**: right
spaces, wrong base, as above. The first two jumped the whole list on device; the third doubled every
displacement.

Note what separates the third from what ships now, because they are the same subtraction: WHEN it is
evaluated. At pass entry the layer's model value is still the base its render tree was committed
against; ~570 lines later it is this pass's new settled position. A future change that moves the
capture later, or adds a second capture after any settled write, re-creates the reverted form exactly.

`CoreAnimationCompiler` is an output renderer, never an authority. It builds through the shared
`makeCoreListAnimation` factory — a copy of `CAAnimationUtils.makeAnimation`'s branch tree — so what
CoreList emits is what every other Telegram surface emits: a `CABasicAnimation` with a
`CAMediaTimingFunction` for bezier curves, and a real `CASpringAnimation` for the two system-spring
durations (0.5, and 0.3832 on iOS 26). It then adds the model-path properties the factory does not
set: `fillMode = .both`, `isRemovedOnCompletion = false`, the generation metadata, and — alongside it
— `CoreListAnimation.startTime` (the model track's declared phase axis) and
`CoreListAnimation.preservesPhase` (the origin policy the emission chose). It leaves `beginTime`
UNSET, so Core Animation resolves it at the commit, on the same clock as every other animation in the
app; the one exception is `ListAnimationController.rebind`, which passes
`CoreListAnimationOrigin.explicit` (see the gotcha below). Position is additive on
`position.x`/`position.y`, width/height absolute on `bounds.size.width`/`bounds.size.height`, opacity
absolute, all on the track's own curve and already-scaled duration. **`CAKeyframeAnimation` is emitted in exactly two places, and both play a
baked trajectory rather than a curve:** the physics deceleration flights (`KeyframeFlight`,
`Trajectory+Keyframe`, the two physics engines), and attachment flight tracks
(`CoreVirtualListView+Attachments.installAttachmentFlightTracks`), which compose the same trajectory
with an attachment's own solve so a floating header stays glued to the content the render server is
moving. Nothing else may emit one.
Interruption never reads layer presentation state back into the model. Production uses no display-link list
renderer and no `UIViewPropertyAnimator`.

Loaded genuine departures are grouped by contiguous old-collection runs into rigid ghost blocks under the
non-interactive, footprint-free `exitOverlay`. Each block has one stable wrapper and one additive position
owner; member views keep fixed sampled local frames and independent fresh exit owners that fade opacity only,
so a reinserted live identity can coexist safely with its departure. Each block-ledger boundary link stores
both the ghost's attached local edge and a live/ghost `minY` or `maxY` witness edge, then resolves
`root = witnessBoundary - localEdge`. Geometry/order passes retain a usable link or migrate both sides toward
that pass's independently resolved anchor, including ghost-to-ghost handoff when a live carrier departs. A
ghost above the pass anchor therefore rides its `maxY` on the following boundary's `minY`, while a genuine
same-pass or delayed replacement carries the ghost at matching `minY` edges.

**A carousel pass attaches no boundary witness at all.** Its departed strip has no live neighbourhood
left to attach to — the destination is a different region of the collection, which is what made the
pass a carousel — and the shared additive viewport track already owns the travel for the outgoing
strip exactly as much as for the incoming one. Blocks created there stay `.unresolved` and hold their
remapped roots; this is the outgoing counterpart of the destination-only-survivor rule above. See the
gotcha below for what a witness does there. **A viewport-anchored block refuses a witness outright**
(`GhostBlockLedger.canSetWitness`): declining at creation only covers blocks born in that pass, and
with two carousels in a row the geometry/migration path re-linked the FIRST strip onto the second's
block, resolving both to the same screen Y — the old window landing exactly on top of the new one.
Refusing in the ledger is the only way to state "never" about a graph edge.

**And a carousel's exit content is parked in the VIEWPORT, not in content space.** `exitOverlay` is a
child of `engine.contentHost`, so the user's finger moved the outgoing strip too: jump to a disjoint
region, drag back toward the side the strip sits on, and it travels along superimposed on the
destination's own messages for the whole pass. Measured on an 800pt viewport at the production 1.15s
curve, visible stale content grew from 96pt to 776pt, every visible pixel of it over a live row.
(Dragging the *other* way sweeps the strip off-screen and was always clean — which is exactly how a
first probe of this reads as "no bug".) Ghost wrappers and viewport carries born in an
`isCarouselScroll` pass are promoted into `carouselExitOverlay`, a sibling of `contentHost` ordered
BELOW it, at `contentY − transactionOffset` — forced, not chosen, by equating the two renderings
(`contentY − (offset + correction)` in the content host, `mirrorY − correction` in the mirror). The
promotion is ONE hand-off after every parking site, because `makeGhostBlock` runs before
`transactionOffset` is even captured, and its membership is PASSED IN, never derived from carry
generation — the viewport block re-stamps every live carry, including ones an earlier content-space
pass parked, and promoting one of those freezes content-space content on screen. Departing
attachments need no entry: `PriorRun.memberIdentities` holds only LOADED members and a full replace
departs the whole window as one run, so they already travel inside a ghost wrapper.
`ListViewImpl` has always done this — `temporaryPreviousNodes` go into the list view itself at their
final frames and travel on one additive `sublayerTransform` (`Display/Source/ListView.swift:3625-3634`,
`:3803`), below the live nodes — and CoreList had taken only the opacity half of that parity. A
residual crossing remains on a short viewport and is inherent (a held strip and sliding content must
cross): 48/10 peak/mean against 179/65 for content-anchoring, which is what the z-ordering is for.

**The outgoing strip is everything on its way out, not just the loaded window**
(`carouselOutgoingStrip`). A carousel still in flight has its own outgoing strip parked in
`carouselExitOverlay`; jump again, back the way the first jump came, and adjacency against the loaded
window alone puts the incoming window exactly where that strip is drawn. The two ride the same track,
coincident, for the whole pass: 300pt of stale-over-live overlap on a 300pt viewport, and in a chat,
where rows are transparent, the previous window drawn through the new one. Same-direction chains
were always clean, because the parked strip sits on the far side, and so was any second jump made
after the first had settled. So adjacency uses the union of the loaded window and every
viewport-anchored strip. **That strip then has to live as long as the track now carrying it**
(`retimeCarouselExitStrips` → `retimeExit`): its own deadline belongs to the pass that parked it, so a
reversal just before that pass ends would remove it mid-travel and leave its band empty, 300pt blank
at worst. Viewport carries already get the same from the generation re-stamp; a ghost block's
lifetime is its members' exit tracks, re-timed onto this pass's
transition, which also tears them down at once on an immediate jump rather than leaving them frozen
in the viewport over the destination. `CarouselChainOverlapTests` covers all four direction pairs,
mid-flight and settled, the late reversal, the immediate jump, and the chat's own jump straight back
to the newest messages, where the incoming rows share identities with the parked strip.

Mutation anchors use the engine offset clamped to the currently known loaded edges. Rubber-band displacement
is presentation-only: it is restored to the displayed engine offset after settled geometry is resolved and
must not influence anchor identity, direction, or edge pinning. At the settled loaded top edge, an ordinary
mutation pins new collection index 0 to point offset 0.

A deletion-only block keeps its creation boundary open while a survivor provisionally carries that edge. A
later genuine insertion landing exactly at the block root becomes the spatial carrier and seals the boundary,
making delayed replacement match same-pass replacement. A same-pass inserted occupant seals immediately, so
unrelated later insertions cannot steal its ghost.

Pure user and programmatic scrolling are exact witness no-ops: the scrolling hierarchy or viewport track
moves ghost wrappers without replacing their block-position tracks. Coordinate rebases and overlay remaps
instead shift every wrapper and its ledger `settledRootY` by the same exact delta while preserving witness,
generation, phase, curve, and deadline. Member opacity completion does not wait for block motion. An empty
referenced block persists as a nonvisual spatial node until its dependents finish, after which cascading
collection removes its graph edge, wrapper, position owner, and ledger entry.

Production keyframes for position call `preferHighRefreshRate()`. `Info.plist` must retain
`CADisableMinimumFrameDurationOnPhone = true`; without it, ProMotion devices cap app-driven refresh.

### Programmatic viewport scrolling

Programmatic `scrollTo` writes the settled engine endpoint immediately and emits one model-owned additive
`viewportOffset` bounds track on `contentHost.layer`. The old and destination loaded identity sets select
overlap geometry for shared rows or a one-window carousel for disjoint windows; distant jumps instantiate
neither intermediate rows nor intermediate windows. Gestures change the settled logical engine state beneath
the unchanged viewport correction. A later target replaces the viewport property from its analytic current
value for C0 continuity. A pass with neither `scrollTo` nor a geometry-induced target change is an exact
viewport no-op that preserves its generation, CA key, phase, curve, deadline, and transient carries.
An explicit `scrollTo.pointOffset` is relative to the received top inset: its projected screen target is
`viewportInsets.top + pointOffset`. This conversion happens before projected window construction, so same-pass
inset changes, loaded membership, edge clipping, crossing carries, and carousel placement all use one final
coordinate system.
`additionalScrollDistance` is a caller-chosen displacement of that same viewport, in points, positive moving
content DOWN — the analogue of `ListViewImpl.transaction`'s parameter of the same name, folded into the same
addend as the inset compensation (`Display/Source/ListView.swift:3275`) so one pass can re-inset and scroll by
a delta as a single movement. It displaces the resolved anchor before window construction rather than writing
an offset afterwards, so it composes with edge clipping, loaded membership, crossing carries, and an explicit
`scrollTo` (which positions content first, the displacement then moving it). A non-zero value halts momentum
for the same reason `scrollTo` does, except under `.preserveVisibleContent` — ListViewImpl's stationary-item
branch does not halt either. It also opts the pass out of the loaded-top pin, which would otherwise swallow the
displacement whole; ListViewImpl's equivalent (`snapToBounds`) only closes a gap above the top item, so a
downward displacement at the top edge is clipped by both and an upward one is honoured by both.

The viewport correction is **one track with more than one output layer**:
`ListAnimationController.addViewportMirrorLayer(_:)` registers extra layers that receive the identical
emission, and `carouselExitOverlay` is the only production mirror. A mirror carries the animation and
nothing else — no binding, no model state, no settled write, no completion — which is sound only
because `writeEndpoint` already returns early for `.viewportOffset`: the engine owns `contentHost`'s
settled `bounds.origin.y` and the model contributes purely the additive correction, so a mirror's own
`bounds.origin.y` rests at 0. One generation, one phase, one deadline. A second owner with a duplicate
track was rejected — two tracks describing one motion is the same failure family as
`enableUnreadAlignment`, `itemNodeFrame` and `settledContentOffsets`. **A replacement STEPS that
correction** (`replacementFrom` is the current correction plus `oldSettled − newSettled`, absorbing the
settled-base move so content stays continuous); content-space children ride it through the engine's own
write to `contentHost.bounds.origin`, mirror children do not, so `shiftCarouselExitChildren` rebases
them by the correction sampled either side of the mutation. Without it, two carousels in a row stacked
both strips.

Every changed positive-duration viewport replacement first remaps all detached overlay content from the old
rendered viewport coordinate base into the replacement base. The exact mapping subtracts the engine shift
once and applies equally to carousel carries, crossing survivors, and ghost blocks; no viewport-producing
branch may replace the track without this boundary remap.

Carousel travel direction comes from comparing the current anchor's position in the new order against
the target index. When no old identity survives into the new collection — a full replace, which is
how a host expresses a jump to a disjoint region — there is no witness to compare, and
`CoreListScrollTarget.direction` supplies the answer; `nil` keeps the historical `.forward`. A
present witness always wins, mirroring `ListViewImpl`, which computes the offset geometrically from a
surviving anchor node and consults its own `directionHint` only when that yields nothing
(`Display/Source/ListView.swift:3590`).

Carousel adjacency is computed from normalized loaded-strip tops
(`containerOriginY - renderedViewport`), never by subtracting `Window.minY` again after render
normalization. Forward travel places the incoming loaded top at the outgoing loaded bottom; backward
travel places the incoming loaded bottom at the outgoing loaded top.

For a non-overlapping carousel, the additive viewport track is the exclusive vertical-motion owner for
destination-only survivors. A simultaneous geometry or structural membership transition must not route those
rows through incoming crossing-survivor position inference; the destination remains one rigid final-layout
strip. Genuine insert opacity and independent horizontal/extent properties still compose normally.

📖 **Read before changing:** `ListAnimationModel.swift`, `ListAnimationController.swift`,
`CoreAnimationCompiler.swift`, the animation transaction in `CoreVirtualListView.swift`, and
designs `docs/plans/2026-07-20-list-animation-model-design.md` and
`docs/plans/2026-07-20-additive-viewport-scroll-design.md`, plus
`docs/superpowers/specs/2026-07-21-ghost-block-boundary-witness-design.md` for departed-block motion and
`docs/superpowers/specs/2026-07-22-projected-anchor-inset-transition-design.md` for geometry rebases.

### Self-update and view reuse

A view's `onContentDidChange` marks its index dirty and schedules one coalesced flush through the
injected `Scheduler`. The flush re-enters `applyChanges` and remeasures exactly the dirty rows.
The flush writes final settled geometry immediately even when the callback requests animation, then each
changed survivor position and height property transitions independently on that flush duration. Unchanged
identity/property tracks remain intact.

`buildWindow` reuses a view from the old window for survivors and move endpoints. A reused view is
reconfigured with `apply(to:)` only when `isEqual` is false, before measurement. Rows loaded
by scrolling are attached to their stable owner; known owners rebind after height reconciliation,
preserving eligible position/opacity tracks and unchanged-target height tracks without restarting them,
while new owners seed settled state.

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

`identity` is the stable animation key AND the diff key: it drives survive/insert/delete/move matching
and the uniqueness invariant. `isEqual(to:)` is **value/content equality** for an already-identity-matched
survivor — the engine reconfigures a survivor (`apply(to:)` + remeasure) iff `!isEqual`. It has **no
default** (equality-by-identity is almost never correct in production, so every item states its content
equality explicitly); an identity-only item still opts in by writing `isEqual` to compare just its
identity field(s). `apply(to:transition:)` updates a reused view in place (default: no-op).
`update(width:transition:)` lays out the row and returns its measured height.

`pinsToBottomEdge` declares that this row is held against the viewport's BOTTOM edge, with the list
declaring whatever extra top-inset slack that needs (see "Virtual content and settled window"). It
defaults to `false` — honest rather than conservative, unlike `isEqual`, since a row that says nothing
about pinning is not pinned. When several loaded rows declare it the LOWEST index wins, matching
`ListViewImpl`'s `lowestPinnedIndex`.

Both receive the enclosing pass's `CoreListTransition`, so a row can animate its own internals on the
same curve and duration as its outer geometry. It is non-immediate in exactly two cases, both meaning
"this row has to RE-LAY-OUT and has a prior layout to animate from": its **content was reconciled** in
the pass — a reconciled survivor, or an animated self-update flush (`reconciledIdentities`) — or the
pass **changed `contentWidth`**, so `buildWindow` re-measures every loaded row at a new width
(`contentWidthChangedInPass`).

The second is not a special case of the first, and omitting it was a real bug: a horizontal inset or a
viewport-width change reconciles nothing, yet every row reflows — a bubble rewraps its text, its
subviews move. `ListAnimationModel` owns the row's OUTER frame and animates that, but it knows nothing
about where a label sits inside a bubble, so row internals snapped while the frame animated. Note the
asymmetry that explains: the older "purely outer geometry" reasoning is correct for a **vertical**
inset change, which leaves `contentWidth` alone so nothing re-measures, and wrong for a horizontal one.

Everything else receives `.immediate`: a view **created in this pass** (`freshViewsThisPass` — nothing
to animate from, and this exclusion outranks the width case), and, while the width is unchanged,
scroll-in loads, unchanged survivors and off-screen remeasures, none of which relayout. Scroll-driven
rebalancing changes neither content nor width, so its rows stay `.immediate` for free.

`contentWidthChangedInPass` compares `contentWidth` across the pass's geometry assignment
using the same `0.5` epsilon `CoreListNodeHostView.update(width:transition:)` uses to decide whether to
relayout at all. **The two must agree** — drift either way gives a row that animates without
relayouting, or relayouts without animating.

**The inference is per-PASS, which constrains callers.** A host that installs a geometry change in one
pass and animates the relayout in the next leaves the animated pass with no delta to infer from, and
nothing in `measureTransition` can recover it — by then the layout is already correct. `ListViewImpl`
has no such constraint because its equivalent, `ListViewUpdateSizeAndInsets.customAnimationTransition`,
is an instruction rather than an inference (`Display/Source/ListView.swift:1791`). Submit the geometry
change and its animation in the same pass; the chat does.

`update` must return the settled height either way, and may be called twice in one pass (dirty
remeasure, then window construction) — the transition's setters early-out on an equal target, so the
second call is a no-op.

**Attachments follow the same rule**, through `attachmentMeasureTransition(serial:isFreshView:)`:
reconciled content (`reconciledAttachmentSerials`) or a changed `contentWidth`, with a freshly created
view outranking both. The width case matters at least as much here — a chat date pill CENTRES itself
in the width it is given, so any viewport resize (rotation, Split View) moves it across the screen.
Both per-pass sets are cleared together
at the pass boundary; `reconciledAttachmentSerials` was for a long time never cleared at all despite a
comment saying otherwise, which left any attachment that reconciled once measuring with the pass
transition on every later animated pass.

**A live attachment view is laid out exactly once per pass, and `measuredAttachmentHeight` must keep it
that way.** A `.reservesSpace` run is measured twice — once during stacking to size its reserve, once by
`resolveAttachments` for real. The probe used to reuse the live view, and since
`update(width:transition:)` both measures AND lays out, that laid the view out at the target with
`.immediate`; the real measure then found every setter already at its target and, because transition
setters early-out on an equal target, animated nothing. Reserving attachments could not animate their
internals at all — width change or content change. The probe now measures a THROWAWAY built from
`run.representative`, which also fixes a staleness: the old reuse measured the live view BEFORE
`apply(to:)` reconciled it, so a run whose content changed reserved space for its previous content.
Cost is one view construction per reserving run per pass, and zero for a list with no reserving
attachments (the chat backend is `.overlay` throughout).

📖 **Read before changing:** `DemoRow.swift` and
`docs/plans/2026-05-31-item-content-reconcile-design.md`.

## Demo app

`SceneDelegate` installs two production demo tabs: **Virtual List** (`ViewController`) and
**Physics Scroll** (`PhysicsScrollDemoViewController`). The Virtual List tab retains manual controls
for inserts/deletes, edge deletes, replacement and delayed replacement, reorder and delayed
reorder/size, immediate growth, mixed-operation chaos, top/jump navigation, a 300pt animated top-inset
toggle, and all three scroll engines. `ViewController` lays the list out at the controller's full bounds and
submits only size and insets as list-owned viewport geometry. It expresses overlaid controls and safe-area
chrome through a layout-derived chrome inset, then component-wise adds independent animated test deltas. Demo
controls mutate only those deltas, so removing a test inset restores the current chrome baseline exactly.

Four deterministic mixed-action controls submit vertical inset plus Jump40, horizontal inset plus
replacement, first-item size plus move, and reversible horizontal inset plus first-item size plus five-row
changes in one `applyChanges` pass. Each uses 0.5-second ease-out timing and keeps the inset guide on the
same transition.

An opt-in `Auto Load` toggle demonstrates caller-owned bidirectional loading. The controller
coalesces newly reached top/bottom edges on the next main-queue turn, deduplicates them across
separate queued and in-flight sets, and returns each accepted request after a 0.2-second response
delay. A response prepends five fresh rows for the top edge, appends five for the bottom edge, and
applies simultaneous edges in one zero-duration `.preserveVisibleContent` pass. An accepted response
still applies if scrolling leaves its edge while it is in flight. After each response, the controller
rechecks the settled reached-edge set; every continuation is a fresh request with its own 0.2-second
delay. Disabling the mode advances a generation and suppresses queued or delayed responses, while
scroll-engine replacement preserves enabled state and an existing in-flight request without
duplication. The mode defaults off. `CoreVirtualListView` remains a policy-free edge observer.

`PhysicsScrollView` is the standalone custom-scroll consumer of `ScrollPhysics`; it does not use
`UIScrollView`. Its gesture path supports touch and continuous trackpad input, and deceleration is
runtime-selectable between stepped and keyframe modes.

## Scroll physics replica

`CoreListDemo/ScrollPhysics/` is a standalone, UIKit-free value-model replica derived from UIKitCore
on iOS 26.2. Core files implement per-axis drag, deceleration, rubber banding, projection, and offset
math; `ReleaseDecision.swift` owns the gesture-RELEASE path (velocity capture, the guarded 2-D
decelerate/stop decision, and the repeated-flick multiplier), which is two-dimensional and
gesture-lifetime and therefore deliberately not on `ScrollAxis`. `PanRecognizer.swift` handles input. `Trajectory.swift` and
`Trajectory+Keyframe.swift` bake rate-independent linear keyframe playback and seamless splicing.
Recording support and tests live under the corresponding production/test folders.

📖 **Read before changing any physics constant or formula:**
`docs/plans/2026-05-22-uikit-scrollview-physics-analysis.md` and
`docs/plans/2026-05-23-pan-recognizer-reproduction-design.md`.
The formulas come from assembly; decompiler SIMD/FP pseudocode is not authoritative.

## Tests

The deterministic harness in `CoreListDemoTests/TestSupport/` injects `SyntheticClock`,
`ListAnimationController` with CA emission optionally disabled, `TestScheduler`, and UIKit- or
physics-backed engines. `VirtualListDriver`/`VirtualListFixture` and
`PhysicsListDriver`/`PhysicsListFixture` expose settled and analytic state without making Core
Animation an authority.

- `ListAnimationModelTests` specify strict unchanged no-op, C0 position/extent replacement and track curves,
  generations, immediate settlement, and off-screen state.
- `CoreAnimationCompilerParityTests` compare model samples with compiled keyframes, including an
  actual paused layer check.
- `CoreVirtualListAnimationTests` cover insert, remove, replacement, move, mixed passes, view reuse,
  overlay teardown, unchanged-track preservation, full viewport-geometry retargeting, and scrolling while active.
- `PresentationResumeSamplingTests` and `PresentedPositionResumeBaseTests` cover the presented-value
  provider: which properties it samples (absolute only), that an absolute re-issue resumes from the
  screen both at a bare layer and through a real list pass, and that a position track starts one
  displacement from the screen rather than two. **They are the only tests that reach the provider at
  all** — every other suite runs windowless, so `presentation()` is nil and the analytic path is taken,
  which `testFixtureLayersHaveNoPresentationLayer` pins deliberately. A test here needs a
  scene-attached window AND an owner bound to that layer, or it returns nil at the provider's guard and
  passes vacuously; assert a sampled property is non-nil in the same test as the witness. Verify by
  mutation — the "these properties are not sampled" test shipped green against the very defect it
  named.
- `MixedPassStressTests` run a bounded fixed-seed grammar over structural, row-geometry,
  viewport-geometry, programmatic-scroll, and attachment-run changes. They verify transaction-boundary
  C0 continuity, exact unchanged-track preservation, installed CA/model metadata parity for observed
  owners, settled window integrity — including reservation gaps and the attachment invariants (unique
  serials, member ranges inside the loaded range, one space-reserving attachment per edge per
  boundary, deterministic sort order) — and carry/ghost teardown. Failures report the seed, pass, and
  full action prefix; minimize any production failure into the owning focused suite before fixing it.
  **Attachments are opt-in** (`MixedPassScenario(…, includesAttachments: true)`) and draw from a
  SEPARATE RNG: the scenario is a shared seeded generator and some focused suites replay its exact
  sequence, so putting attachment draws in the main `rng` silently hands every one of them a different
  scenario. `testTheGrammarActuallyExercisesAttachments` is the non-vacuity guard — every other
  assertion here is conditional on what the grammar happens to produce.
- Core-window, content, engine, and physics suites retain non-animation behavior coverage.

## Non-obvious gotchas

- Core Animation layer properties are settled endpoints during animation; analytic queries come
  from `ListAnimationModel`. Only compiler parity tests inspect actual layer presentation output.
- One pass must capture one controller-local time from the bound layer's
  `convertTime(CACurrentMediaTime(), from: nil)`. Layer-local time, not raw media time, preserves
  analytic/CA agreement when Simulator Slow Animations changes layer speed. Sampling once per row
  creates clock skew and breaks cross-property transaction guarantees.
- **Every emitted CA animation leaves `beginTime` IMPLICIT, so the commit resolves it.** That is what
  puts a CoreList track on the same clock as everything a host can write — `ContainedViewLayoutTransition`
  / `CAAnimationUtils`, and CoreList's own executor path (`CALayer.animate` stamps an origin only in
  its unreachable `delay != 0` branch). Measured: every animation added in one runloop turn resolves
  to one origin, the model path and the executor path included, so a pass's tracks stay mutually exact.
  The model's own phase axis rides `CoreListAnimation.startTime` metadata instead, which is exact with
  no commit — needed because a layer outside the render tree never resolves an origin at all
  (`beginTime` stays 0 forever, `presentation()` nil), which is every windowless test fixture.
  - **The exception is `rebind`**, re-emitting an in-flight track onto another layer: `fillMode = .both`
    holds `from` before-begin, so an implicit origin would replay the whole curve. It stamps
    `CoreListAnimationOrigin.explicit` with the origin Core Animation RESOLVED for the animation it
    replaces (read back off the layer, or remembered by `captureResolvedOrigins` when the binding was
    dropped), **not** `track.startTime` — the two differ by the producing pass's commit delay, and
    stamping the model's clock would jump the curve forward by that much on every rebind and desync
    the row from its still-bound neighbours.
  - **Two sites must NOT be swept into a grep-driven change here**, both deliberately past origins on
    a different clock: the attachment flight keyframes (`CoreVirtualListView+Attachments`, key
    `coreListAttachmentFlight`) and the physics trajectories (`PhysicsScrollEngine`,
    `Trajectory+Keyframe`, `SplicedTrajectory`), which re-install with a past origin on every rebake
    precisely so a mid-flight rebake resumes at its current phase.
    - **A flight's LAUNCH is explicit for its own reasons, not just the rebake's** — worth stating,
      because `launchFlight` is the one of the two where an implicit origin looks obviously fine.
      `beginTime` there is not the animation's private business: it is `KeyframeFlight.startTime`, the
      flight model's clock, which `liveOffset`, `isComplete`, `beginTick`, `braked(stoppingAt:)` and
      the `multiplierResetTime` comparison all measure against — and which `TestScrollEngine` supplies
      from a `SyntheticClock` with no CA in the process at all. An implicit origin hands that value to
      CoreAnimation, leaving the model to guess it or read it back after the commit, and a layer
      outside the render tree resolves none (`beginTime` stays 0 forever), which is every windowless
      fixture. It is also worse where it looks better: an implicit origin resolves to the COMMIT,
      so it drifts with whatever else the release turn cost — `endDrag`, the bake, then the host's
      `applyChanges` off `didEndDragging` — while the presented frame stays put on the vsync grid,
      costing `velocity × turnCost` of backward bias, variable and largest exactly when the app is
      busiest. `localNow()` is captured in a touch handler at the top of the turn, right after a
      vsync, so it is phase-locked to that grid.
    - **Why `localNow()` is the RIGHT explicit value is a cancellation, not a coincidence.** The
      trajectory's `t = 0` is the offset as of the LAST DRAG UPDATE, one frame before the release
      turn; the animation is first presented one frame later (D ≈ 1). Anchoring at the release turn's
      start makes those two one-frame errors cancel — which is also why the release hand-off had
      nothing left to compensate and had to be rewound (see `launchFlight`).
  - **The residual, named:** the model now LEADS the screen by the commit delay δ for any query that
    compares a model sample against the screen at the same instant (`presentedFrame(of:)`). δ is the
    rest of `applyChanges` plus the rest of the runloop turn — it contains the pass's own main-thread
    cost, so it is neither constant nor bounded by a measurement of one pass shape; it has been
    measured only on the demo, never on the chat surface. Two consequences follow and are accepted
    rather than fixed: a retarget's residual discontinuity is `velocity × (δ_new − δ_old)` instead of
    the old `velocity × δ`, which is smaller when consecutive passes cost the same and can exceed it
    (and change sign) when they do not — this is what the presented-position capture removes for
    `.positionY` specifically, by resuming that property from the screen rather than from the leading
    model, and it still applies to any query or property that does not; and an equal-endpoint track
    completing on its analytic
    deadline now finishes δ BEFORE its CA-driven siblings from the same pass, so a ghost block can
    tear down that much before it finishes moving. Do NOT resolve the `presentedFrame` lead by
    redirecting hosts to `settledFrame(of:)` — that is a different value with its own shipped failure
    mode (see "Row geometry is a pair"). The only real fix shares one commit-resolved origin between
    the model and CA, which nothing does today.
  - **Do NOT re-stamp `ListAnimationTrack.startTime` to the resolved commit time.** `install` arms
    `scheduleAnalyticCompletion(deadline: startTime + duration)` at the moment of install and never
    re-reads the track, and that timer is one-shot; a `startTime` moved forward makes it fire early,
    `model.complete` returns false, `finalize` re-inserts the pending, and nothing in production ever
    re-drives it. The victims are exactly the tenants that deadline exists for — the non-fading
    full-replace carousel exit strip and the `viewportOffset: 0 -> 0` re-target — and the whole suite
    is blind to it, because `VirtualListFixture` defaults to `emitsCA: false` and drives teardown from
    the model clock.
  - `InsetRectOverlayAnimator` is `.atCommit` too, and it pays a cost the model path does not: it
    samples `from` from the RENDER SERVER (`layer.presentation()`), so an implicit origin costs it a
    `velocity × δ` step on every retarget of an in-flight guide, where the explicit stamp was
    continuous by construction. Accepted — the guide must share the list's clock, and every other
    presentation-sampled emitter in the module already pays it. Do not "fix" a visible step there by
    re-stamping.
- Duration scaling happens only in `ListAnimationController`; the compiler receives the final
  duration and must not scale again.
- Same-target position and extent writes must return before touching the model, CA key, completion ledger,
  or layer.
- A changed position starts from `oldSettled + analyticOffset`, not the model layer and not viewport
  coordinates; this is what preserves continuity through scroll/container rebases.
- Every loaded survivor with a changed settled position or height must transition from its analytic current
  presentation, even without a prior track; restricting geometry composition to active tracks creates a
  delayed resize/content/self-update snap.
- Position and height tracks compose independently. Final settled frames are model-layer endpoints, while
  the additive `position.y` and absolute `bounds.size.height` animations preserve the boundary presentation.
- Rebinding position or opacity uses the original start/deadline. Height does too when its retained target
  matches the freshly measured settled height within epsilon; a changed off-screen height instead settles
  to fresh geometry and invalidates only stale height state. Restarting a preserved curve when a row scrolls
  back on-screen violates the stable-owner contract.
- Exit teardown is owner-, generation-, binding-, and view-specific. Exit position and height are frozen at
  sampled member-local geometry; identity alone is insufficient because reinsertion may coexist with a
  fading departure. Contiguous members move only through their stable block wrapper, whose additive position
  owner rides a live/ghost boundary witness.
- **A ghost block created in a carousel pass must take no witness, and the failure is destination-
  dependent.** `initialGhostWitness` walks back for a surviving predecessor and, finding none — which
  a full replace guarantees — falls through to proposing `newItems[0]` (or, at the far end,
  `newItems.last`). That proposal *resolves* precisely when the destination window reaches a
  collection edge, and the departed strip then gets a position track onto the head of the incoming
  window and visibly walks over it while the viewport track carries both. Every mid-collection jump
  stays rigid, because both edge rows are unloaded and the witness stays `.unresolved` — so the
  suites that cover carousels could not see it: `ProgrammaticScrollAnimationTests` asserts strip
  adjacency but keeps the same collection (old rows become viewport carries, not ghosts), and
  `CarouselFadeSuppressionTests` does full replaces but only checks opacity, always at index 50. It
  surfaced as a chat jumping from far in the past to the newest message: 348pt of overlap on a 400pt
  strip at 75% of the travel. `FullReplaceCarouselStripSeparationTests` locks both collection edges,
  the mid-collection control, and the mechanism (`witness == .unresolved`, no ghost position track).
- Ghost witnesses migrate toward the current pass anchor, not a remembered direction. Pure scroll must not
  reconsider witnesses or replace block tracks; coordinate-only remaps must shift wrapper model positions and
  ledger roots by the same exact delta. Empty referenced blocks remain spatial nodes until dependents finish.
- A crossing carry released by the shared viewport track must migrate from the old viewport generation to
  every replacement generation. Replacing the viewport property invalidates the old completion; retaining
  that stale release generation leaks the carry after all analytic tracks settle. An immediate viewport
  replacement releases those carries immediately.
- Resize/content/self-update writes final settled geometry immediately, then changed survivor position and
  height properties transition independently; unrelated active position, height, or opacity tracks remain
  exact no-ops.
- `UIScrollView` clamps `bounds.origin.y` assignments; tests must establish content limits before
  writing non-zero offsets.
- Trackpad indirect scroll ignores `pan.setTranslation(.zero)`; keep the explicit translation
  baseline in the physics engine.
- **The gesture-release path is a 2-D, gesture-LIFETIME decision, and `.began` is a velocity sample.**
  `ReleaseDecision` owns it (`ScrollPhysics/ReleaseDecision.swift`), not `ScrollAxis`: the
  decelerate/stop threshold is `vx² + vy²` evaluated on the RAW latest sample before the low-pass, the
  0.75/0.25 low-pass is GUARDED on the previous-axis pair being non-zero, and the repeated-flick
  multiplier outlives a gesture — while `PhysicsScrollCore.beginDrag` rebuilds `ScrollPhysics` from
  scratch every gesture, so anything stored there would need hand-maintaining. `-[UIScrollView
  handlePan:]` case 1 zeroes the four velocity ivars and then calls `_updatePanGesture` **immediately**,
  so `.began` contributes a full sample and applies its translation; treating it as setup only ran every
  gesture one sample behind UIKit and released a short flick — one or two `.changed` events — at a
  QUARTER of its velocity. Measured: ~370pt where UIKit travels ~1493pt. A force-begun pan is the
  exception and feeds nothing, because it is a catch on moving content rather than a flick start.
  `Deceleration.spring` must NOT apply `vScale`; only the free-decel term and its to-the-edge sub-step
  do.
- **A dead axis must not answer questions about a live one.** `ScrollPhysics.step` ORs the two axes'
  "ended a deceleration" flags — correct in itself, one axis reaching its edge really is an end. But
  `PhysicsScrollCore` pins x to a DEAD axis (offset 0, `min == max == 0`, no velocity), and
  `Deceleration.settled()` calls an in-bounds axis settled the moment its velocity is under the floor.
  So x reported "ended" on every frame it was ever stepped and the OR was unconditionally true. Since
  the core clears the repeated-flick streak on exactly that signal, the FIRST deceleration frame after
  every release cleared it — in both drivers (`.stepped` on the display link's first callback,
  `.keyframe` on the single hand-off step before the bake). The streak could never reach the three
  consecutive fast flicks growth requires, so `_fastScrollMultiplier` sat at 1 forever and a burst of
  flicks carried **0.99×** a single flick where UIScrollView compounds to 1.9× and beyond. `ScrollAxis.step`
  now gates the flag on the deceleration having actually been RUNNING (decelerating, and either above
  `Deceleration.velocityFloor` or displaced past an edge and still springing back — the exact complement
  of `settled()`). Note the failure was invisible to every existing streak test because they flicked
  repeatedly WITHOUT ever stepping the integrator between flicks; the regression tests now drive a burst
  both ways, and `test_theFourthFlickOfABurstTravelsFartherThanTheSameFlickAlone` states it as distance.
- **A harness that drives the engine from a foreign recognizer must replay the engine's touch-down
  hookup too.** `core.beginTouchTracking` is reached only via `PhysicsScrollEngine`'s OWN
  `pan.onTouchDown`. The A/B comparison view deliberately drives the engine from
  `UIScrollView.panGestureRecognizer`, whose touches never route through it — so the streak never
  expired on a pause and `_fastScrollStartMultiplier` stayed pinned at 1, meaning the replica could not
  compound across a burst even with the physics correct. That reads as a physics difference that does
  not exist in the app. `PhysicsScrollEngine.noteTouchDown(at:)` exists for that hookup. (The
  trackpad/indirect path also never calls it — see `gestureRecognizer(_:shouldReceive:)`. Whether UIKit
  applies the fast-scroll multiplier to indirect scroll at all is **unverified**; do not "fix" that by
  analogy.)
- **A replay harness must drive the same entry point production drives, or it validates a driver nobody
  ships.** `ScrollReplay.replay` folds every recorded DISPLAY FRAME through `drag(...)`, including the
  first — so it behaved like UIKit whether or not the live engine fed its `.began` sample, and a suite
  holding the integrator to ≤3px against real `UIScrollView` traces could not see a 4× error in the
  release. The defect lived in the engine↔core seam and no fixture crossed it. `ScrollReplay.replayEvents`
  drives the per-EVENT touch stream the way `PhysicsScrollEngine.applyPanUpdate` does and is the seam
  oracle; `replay` remains the integrator oracle. `applyPanUpdate` takes its indirect-ness as a
  PARAMETER for the same reason — a `PhysicsPanGestureRecognizer` that has received no touches reports
  `isIndirectScroll == true`, so a synthetic gesture reading it off the recognizer would silently get
  the trackpad rubber-band coefficient.
- **`ScrollEngine.offset` is per-frame stable; never sample a running animation through it, and never read
  `contentHost.bounds.origin.y` as a position.** That layer value is the additive BASE of the emitted keyframe
  animation, parked at the trajectory's `finalOffset` for the whole flight — mid-flight it holds the flight's
  *destination*, hundreds to thousands of points from what is on screen. `PhysicsScrollCore.offset` returns
  `physics.y.offset` instead, which the active driver advances exactly once per frame (`.stepped` via `step`,
  `.keyframe` via `KeyframeFlight.beginTick`'s reseed). This is load-bearing because `CoreVirtualListView`
  reads the offset **three times** in one mutation pass (`:539`, `:849`, and `:1347` via `setBoundsOriginY`)
  and treats the difference as the shift the pass itself applied: any per-read drift becomes geometry error.
  When it sampled the flight, every mid-flight `applyChanges` re-placed the content where it was when the pass
  *started* — a backward lurch of `velocity × pass duration`, measured up to 185pt. Continuity needs
  *consistency*, not currency: one value used throughout cancels algebraically no matter how stale it is.
  A mutation pass calls `syncToPresentedPosition()` at entry, so it resolves against a current viewport;
  between ticks a plain `offset` read still trails the presented position by `velocity × (main-thread time
  since the last tick)`, which is what makes it stable. Halting momentum uses `haltMotionInPlace()` — never
  `setOffset(offset)`, which reads a stable value and then has it overwritten by the catch's instantaneous
  one (that cost 65pt of discontinuity on a `scrollTo` arriving mid-fling). Corollaries: the
  before/after differencing in `render()` / `applyEngineShift` must **stay** differences (`UIKitScrollEngine`
  genuinely clamps on a `contentSize` shrink, and the realized shift is the only correct amount); and any
  lurch test must measure against `TestScrollEngine.liveViewportOffset`, never `engine.offset`, or it passes
  by its own measuring stick freezing.
- **Stopping a render-server-played flight is a SWAP, not a removal.** A catch cannot take effect at the
  instant it is decided: the model write and the animation removal travel in one transaction, and that
  transaction is presented at the next frame the pipeline can produce, never the frame its value was
  sampled in. The render server keeps playing until it lands, so freezing the list at
  `flight.liveOffset(now: localNow())` hands it a value the screen has already passed and the content
  snaps *back* by `velocity × (that gap)` — measured 40pt one frame late and 79pt two frames late off a
  3000 pt/s release. The gap is the rest of the main-thread turn plus commit-to-display, which is why it
  reads as a barely-visible early stop on a pipeline that commits within its frame and as a real
  reversal on one that does not. `catchFlight(braking:)` therefore stops the flight at `brakeStopTime()`
  (the sampling link's `targetTimestamp` plus a frame of headroom) and swaps in the path
  `truncated(at:)` that instant, on the flight's own `startTime` — the same continuous-swap idiom
  `reemitFlightAnimation` uses, and truncation is exact before the cut, so whichever frame the swap
  lands on presents what the flight would have anyway. **`presentation()` cannot detect or fix this**:
  it is evaluated on the main thread at `CACurrentMediaTime()` and agrees with the analytic sampler to
  −0.02ms, so it describes the same instant the defect is already sampling, not scan-out. Bias the lead
  LATE: with a swap, landing early costs only a few more milliseconds of the flight's own motion, while
  landing late is the step — an asymmetry a plain forward-projected snap does not have (it turns an
  early landing into a forward jump instead). Only the interactive catches brake; `setOffset` /
  `haltMotionInPlace` / `tearDown` immediately impose their own position, and an additive brake residual
  would ride on top of that write. `FlightCatchContinuityTests` pins all of it, including the measured
  step as its own non-vacuity control. The deterministic engine harness is structurally blind here —
  `TestScrollEngine` has no render server, so its correct lead is zero and it keeps the hard stop.
- **Anything that displaces screen-space content must join `displacesViewport`, or it silently degrades
  to per-row tracks.** The predicate (`logicalSizeChanged || insetsChanged || hasAdditionalScrollDistance`)
  gates the ONE shared additive viewport track that owns a pass's displacement. Omitted from it, a pass
  that moves the settled engine offset reads as a pure coordinate rebase, and every loaded row animates
  its own position instead. That renders as the *same* rigid motion for the rows that happen to be loaded
  — which is what makes it so easy to ship — while ghost blocks, viewport carries, and rows entering the
  window stay behind, because they follow the viewport track and nothing else. It caught
  `additionalScrollDistance` during implementation: the shift was correct, exact, and animating on the
  right curve, through the wrong owner.
- **Core Animation never RUNS a `from == to` animation, so it never reports one stopping.** It
  changes nothing, the render server has nothing to schedule, and `animationDidStop` is never sent —
  with `isRemovedOnCompletion = false` the animation just sits on the layer forever. That is fatal
  here because a completion is not bookkeeping: it is the teardown trigger for every tenant of
  `exitOverlay`, and two of them ride equal-endpoint tracks BY DESIGN. A non-fading exit
  (`beginExit(fadesOut: false)` — every departing row of a full-replace carousel, i.e. the chat's
  scroll-to-bottom) installs `opacity: o -> o` purely to own a deadline; and a viewport re-target
  onto the displacement already in flight yields `viewportOffset: 0 -> 0`, whose completion is what
  runs `finishViewportGeneration`. Both stranded their content on top of the live rows, invisibly to
  every existing guard: `assertOverlayInvariants` passes because the view IS owned — by an owner
  whose reaping can never happen. `ListAnimationController.install` therefore drives such a track's
  completion from the ANALYTIC deadline (`ListAnimationTrack.deliversNoCoreAnimationCompletion`),
  which is also the rule the architecture already states — the model is the presentation authority
  and the compiler is an output renderer, so a model-owned completion must not depend on whether
  Core Animation found the animation worth running. Note the model-level guard is NOT enough and was
  already deliberately bypassed: `beginExit` routes around the equal-target early-out precisely so
  the track exists, and the comment there explains that returning `.unchanged` would leak every
  member — the emitted animation then leaked them anyway. `NoOpAnimationCompletionTests` locks both
  cases plus the "a moving track arms no timer" non-vacuity guard.
- **A zero duration is immediate, which is the opposite of ComponentFlow.** `ComponentTransition`
  treats only `.none` as immediate and animates `.curve(duration: 0, …)`. CoreList settles a
  zero-duration property immediately, and roughly half the test suite says "no animation" as
  `duration: 0`. Every branch must therefore test `CoreListTransition.isImmediate`; `if case .none`
  silently animates a pass that must not.
- **Slow Animations reaches the emitted animation as `speed`, not as a longer duration** — exactly
  as `CAAnimationUtils` does it. The model still reasons on the SCALED clock, because its deadlines,
  `isComplete(at:)`, and the controller's reap scheduling all live there; `CoreListTransition.scaled(by:)`
  records the factor it applied in `appliedDurationFactor`, `ListAnimationTrack` carries it, and the
  compiler divides it back out so the animation gets a logical duration plus `speed = 1/factor`. The
  two describe the same wall time. Applying it once per path is still the rule: the model path in
  `ListAnimationController`, the executor path in `CALayer.animate`, and the transition handed to
  items is always the LOGICAL one. For the same reason `ListAnimationController`'s settled-write helpers use
  `CoreListTransition.commit` directly rather than `.immediate` setters: the setters clear the
  matching standard animation key (`position`, `opacity`, `bounds.size.height`) as ComponentTransition
  does, and the executor installs ITEM-VIEW animations under exactly those keys, so a settled write
  would cancel a row's own fade.
- **`Curve.custom` carries `Float`, so it is not a route to exact curves.** `.custom(1/3, 0, 2/3, 1)`
  is `x²(3−2x)` in real arithmetic, but 1/3 and 2/3 round to float32 and every sample drifts by up to
  1.7e-8 — including at phase 0.5, where the ideal bezier is exactly 0.5. Payload-free cases
  (`.easeInOut`, `.linear`) use `Double` literals and are exact.
- **UIScrollView's one-frame release hand-off is a MODEL-WRITE driver's compensation, and a baked
  deceleration must NOT keep it — the commit-to-display delay already is it.**
  `-[UIScrollView _endPanNormal:]` sets the decel's `lastUpdateTime = now − 1/maxFPS` and then calls
  `_smoothScrollWithUpdateTime:(now)` SYNCHRONOUSLY (analysis §2, "Decel hand-off"). It needs that
  because its deceleration writes `contentOffset` once per frame exactly as the drag did: a value
  computed in one main-thread turn is presented a delay later, and the release turn itself produces no
  drag write, so without the step the content stalls for a frame. `.stepped` inherits the same shape
  from its display link's first callback and `ScrollReplay` models it as `firstDecelStepMs`. A baked
  `Trajectory` is a different kind of driver: the render server plays it from an explicit `beginTime`,
  evaluated at each frame's own PRESENTATION time, so the first frame the launch transaction lands on
  is ALREADY one delay into the path. Keeping the hand-off in the baked state double-counts that frame
  and the release steps FORWARD — measured 12pt at 120Hz and 23pt at 60Hz off a 3000 pt/s flick, twice
  that under the repeated-flick multiplier, and another full frame of travel for every extra frame of
  pipeline depth. That is a visible snap at the instant the finger lifts, and it is keyframe-only.
  `launchFlight` therefore runs `PhysicsScrollCore.applyDecelerationHandOff` **only as a settle probe**
  (next bullet) and rewinds the axis to the release state before baking; the rewind is exact, since
  `offset`/`decelerationVelocity` are full precision and `reseedDeceleration` is a pure
  (offset, velocity, phase) restore. It rewinds the CORE, not just the bake, because `engine.offset`
  feeds the list's own geometry and must describe the screen rather than lead it.
  - **Why it shipped the other way round, and why nothing caught it:** the evidence for the hand-off
    is a MODEL argument, and it is correct as one. Our model timeline and `UIScrollView.contentOffset`
    agree only WITH the hand-off — the pipeline delay cancels when model is compared against model,
    which is exactly what the A/B harness and every distance fixture do. The error exists only on the
    presented timeline, and the module's instruments cannot see that: `presentation()` is evaluated on
    the main thread at `CACurrentMediaTime()` and agrees with the analytic sampler to −0.02ms, so the
    `sampleTick` PROFILE probe reports no lag while the screen is a frame ahead. This is the same seam
    as the catch snap-back below, sign-flipped, and `FlightLaunchContinuityTests` is the mirror of
    `FlightCatchContinuityTests` — including its own non-vacuity control, which measures the
    un-rewound step in points.
  - **D, the commit-to-display depth, is a PLATFORM constant, and the Simulator is in a different
    regime from a device — do not tune the opening against it.** The residual this fix leaves is
    `(D − 1) × frameTravel`, so D decides whether there is anything left to correct.
    `CoreListDemo`'s Pipeline tab (`PipelineDepthProbe`, `Tools/measure-pipeline-depth.py`) measures it
    by differential: two bars ride one 900 pt/s ramp from a shared layer-local origin, RED moved by a
    per-frame model write and BLUE by a `CABasicAnimation` on an explicit `beginTime`, and their
    separation in one composited frame is `velocity × D`. **Measured on the Simulator: D = 0.01
    frames** — +0.19 ms, which is just the main-thread turn between the display-link callback and the
    commit. So there CoreAnimation evaluates the animation at the COMMIT's own time for the frame that
    commit produces, and the frame is presented on the spot.
    Taken at face value that would invert this fix: at D = 0 the release frame STALLS without a
    full-frame hand-off. It does not apply to a device, whose pipeline is real — and the device's
    regime is pinned by the report that produced this fix, which is only consistent with D ≈ 1: at the
    old 0.5-frame hand-off the release was seen to jump FORWARD, and under D = 0 that setting gives
    half a frame of advance where a frame is expected, which is a slowdown and cannot read as a jump.
    A direct device measurement still has not been taken (it needs the display captured over USB;
    `MTLDrawable.presentedTime`/`addPresentedHandler`, the one API that reported real scan-out, is
    gone from the iOS 27 SDK).
    - **Capture with `simctl io recordVideo`, never `simctl io screenshot`.** The screenshot path
      re-renders on demand instead of sampling a composited frame: its gap wandered between 0 and 37px
      with no stable value, while the red bar's own positions stayed cleanly quantized to exactly one
      frame of travel — i.e. the app side was provably fine and all the noise was the instrument.
      `recordVideo` taps per frame and lands a 1px standard deviation.
    - **Run the lead sweep every time.** `--sweep` commands a known offset on the animated bar, which
      must come back as an equal measured gap (measured: −8.333 → −8.33, 0 → +0.19, +4.167 → +4.44,
      +8.333 → +8.70, +16.667 → +17.04, +33.333 → +33.52 ms; slope 1.00, max residual 0.4 ms). A
      near-zero reading means nothing until a known offset is shown to move it, and this instrument's
      headline answer IS a near-zero reading.
  - **It is a real integration frame, so it can END the deceleration it was handed** — which is the
    whole reason the probe still runs, and why `launchFlight` re-checks `core.isDecelerating` after it
    rather than baking (the rewind happens only after that check, so it cannot reach these cases). `endDrag` reports `.decelerate` for
    two releases with nothing left to spend: a blend that CANCELS — the decelerate threshold reads the
    RAW latest sample and the 0.75/0.25 low-pass runs after it, so a finger reversing on its last sample
    releases above the threshold at ~0 pts/ms, below `Deceleration.velocityFloor` — and an overscrolled
    release already inside `settleTolerance`. Both settle inside the hand-off's own step, and building a
    `KeyframeFlight` from the resulting `.idle` core trips its precondition assert on device.
    The overscrolled one used to be an everyday gesture, and the pixel grid was why: the spring's rest
    is pixel-ROUNDED and a 3× grid has no vertex at an edge from the outside, so EVERY bounce, at every
    release speed, came to rest at exactly −1/3 pt and STAYED there. **That is fixed — see the settle
    clamp below — so a bounce now lands ON the edge and only a release made inside the tolerance
    reaches this state.** The precondition itself is unchanged and still live. At the tests' default
    scale 1 the old rest rounded to −0.0 instead, so a fixture that never sets a device scale could not
    see it at all. `.stepped` absorbs both cases silently in its first link callback, and
    `TestScrollEngine` cannot see either — it does not apply the hand-off at all — so this lives only on
    the `.keyframe` production path. `FlightLaunchPreconditionTests` locks it, through `applyPanUpdate`
    (the seam) and at the core.
- **A settle at an edge must land ON the edge — `Deceleration.settleIfNeeded` clamps it, and every
  `step` exit goes through that rather than through `settled()`.** The tolerance is what lets the
  spring stop in finite time (out of bounds, `settled()` accepts any rest within `settleTolerance`),
  but it must not leave the offset where it stopped: a real `UIScrollView` bounce lands exactly on
  `-contentInset`, and consumers are written against that guarantee. Unclamped, the ⅓pt grid parked
  every bounce at −1/3 pt permanently (above), and the resting overscroll then read as a live
  overscroll to anything with a tighter threshold. Measured on device: `ChatHistoryListNodeImpl` keeps
  its next-channel control while `visibleContentOffset() < -0.1`, so a resting −0.333 pinned a
  transparent 94pt host view over the bottom of every affected chat and swallowed taps there
  **permanently** — no later emission corrected it, because the list was genuinely at rest and this
  backend has no per-frame hook there. The control drew at zero expansion (`max(0.333 - 12, 0)`), so
  nothing appeared to be on screen. Note how far the symptom sits from the cause: a third of a point
  of physics residue, surfacing as dead touches in a chat. Anything downstream comparing an offset
  against a small threshold is exposed the same way.
- **The physics deceleration flights deliberately ignore the drag coefficient.** Every other CoreList
  animation honours Slow Animations; a fling or edge bounce does not. `Trajectory` bakes its path in
  real seconds and `boundsOriginKeyframeAnimation` installs it with `speed` at 1, so the toggle has no
  effect there — and the `.stepped` mode is likewise driven by real display-link deltas. This is
  accepted rather than verified: `UIScrollView`'s own deceleration is a physics simulation rather than
  a UIKit animation, so it plausibly ignores the coefficient too, in which case matching it is
  correct. Nobody has confirmed that against a real `UIScrollView`. If you make the flights honour the
  coefficient, scale the baked trajectory's playback (`speed`), not its sample times, and check the
  `KeyframeFlight` rebake/splice paths — they compare layer-local time against trajectory time and
  would drift if only one side were scaled.
- **The spring-kind predicate reads the LOGICAL duration.** `0.5` and `0.3832` select real
  `CASpringAnimation`s; every other duration gets the adjusted bezier
  `controlPoints(0.380, 0.700, 0.125, 1.000)`. CoreList pre-scales duration for Slow Animations, so
  resolving the kind from a scaled value would see `5.0` under a ×10 drag coefficient and silently
  emit a bezier — a divergence visible only under Slow Animations. `CoreListTransition` resolves it
  once at construction, `scaled(by:)` carries it through, and `ListAnimationTrack` stores what the
  transition resolved.
- **`Curve.solve(at:)` deliberately differs from Display's `bezierPoint`:** no 0.997 clamp, and a
  bisection fallback after Newton. CA keeps interpolating through a curve's tail, and the model must
  agree with what CA renders now that CA evaluates the bezier itself. (Measured: 4-iteration Newton
  was already exact to 4.4e-16; the clamp was the entire 2.9e-3 error.)
- **The model evaluates system springs through the private `_solveForInput:`**, resolved by an
  ObjC-runtime lookup in `CoreListSpringAnimation.swift`. Note `valueAt:` — which Display calls — is
  Display's OWN category in `UIKitUtils.m:24`, not an Apple selector, so `CASpringAnimation` does not
  respond to it here. The argument is `float` on some builds and `double` on others, which is why the
  lookup inspects the encoding. If the selector disappears, both the model and the emitter fall back
  to the adjusted bezier, degrading together rather than disagreeing.
- **A ghost block's `settledRootY` is its SAMPLED root, not its settled top.** Block formation freezes
  members at their analytic in-flight arrangement deliberately, so a row that departs mid-animation has
  a root nowhere near its settled position (measured 148.639 vs 50.0). It is the right value to render
  from and the wrong one to make decisions with: `initialGhostWitness` compares the run's OLD SETTLED
  top — from `oldState`, translated by `oldLiveEdgeCoordinateShift` into the pass's post-rebase space —
  against the successor's new settled `minY`, to decide whether the successor collapsed into the gap
  (share the top edge, block holds still) or went elsewhere (hang the block's bottom on it). Deciding
  that from the anchor's position instead is a proxy that fails exactly when the anchor is itself one of
  the departing rows, which is what made a head deletion slide the block down by its own height.
- **Never grant gesture simultaneity from the list's pan, and never declare a failure dependency on
  it.** These are one rule with two halves, and shipping either half cost a bug. UIKit resolves
  simultaneity as *either delegate says yes*, so a grant here overrides a refusal written somewhere
  this file never mentions: a nested scroll view's UIKit default, or `ContextGesture`'s explicit
  `other is UIPanGestureRecognizer -> false` (`Display/Source/ContextGesture.swift:66`). The list's
  pan IS a pan, so everything refusing pans is refusing it — and none of that is visible from the
  content side, which is what makes a grant unfindable. It shipped twice: an in-bubble carousel and
  the chat history both scrolling on one diagonal drag, then a bubble's long-press running its press
  animation and never activating. The second was the *repair* for the first: a grant needs
  `shouldBeRequiredToFailBy` to claw back what it handed out, and a dependency HOLDS a recognizer in
  `.possible` rather than failing it. A pan force-begun on moving content never fails until lift, so
  the held recognizer waits — while `ContextGesture` drives its press animation from its own
  `delayTimer` + `DisplayLinkAnimator`, which know nothing about arbitration and run on schedule.
  Animation without activation, ending in an early `reset()` or hanging until the finger lifts.
  `ListViewImpl` has neither construct: `ListViewScroller` denies everything but
  `ListViewTapGestureRecognizer` (`Display/Source/ListViewScroller.swift:15`) and declares no
  dependency anywhere, letting plain exclusion both absorb the stopping tap and cancel a pending
  press. Taps are nearly immune to the dependency form (they recognize on lift, the same instant the
  pan fails), so the demo's tap-only rows cannot catch a regression here.
  - **The mirror half: ANCESTORS declare it about us, so nothing time-critical may ride the forced
    `.began`.** `NavigationContainer` returns `shouldBeRequiredToFailBy == true` for every
    `UIPanGestureRecognizer` (`Display/Source/Navigation/NavigationContainer.swift:202`;
    `NavigationModalContainer:147` likewise), and our pan IS one — so the list's pan cannot RECOGNIZE
    until the interactive-pop `InteractiveTransitionGestureRecognizer` fails. That recognizer fails on
    ~2pt of off-axis travel, and for a dead-still finger not until it LIFTS (it overrides no
    `touchesEnded`, so the default pan failure at lift is what resolves it). A real drag is unaffected
    — it crosses 2pt long before our ~10pt hysteresis — but the forced `.began` is written at
    `touchesBegan` with ZERO translation, precisely the moment the dependency is guaranteed unresolved.
    With the flight catch on that path, the stop would therefore wait for the finger to move or lift,
    while `onTouchDown`/`onTouchUp` (touch delivery, unholdable) fire on time — leaving `handleTouchUp`
    to run with `sawDrag` still false and possibly launch a bounce before the held `.began` arrives to
    `beginDrag` on it. **This consequence is DERIVED, not observed** — the dependency and the pop pan's
    failure timing are both read off the source, and no device repro was captured (the investigation
    that found this was chasing a different symptom, which turned out not to involve this pan at all).
    The catch nevertheless belongs in `noteTouchDown` on its own merits: that is where
    `-[UIScrollView _beginTrackingWithEvent:]` stops its own deceleration, and it takes the stop off a
    path this engine does not control. `.began` keeps an idempotent catch for trackpad, which gets no
    touch-down at all. Absorption still rides arbitration and would still degrade while the pop pan is
    unresolved; the candidate cure (returning `true` from
    `disablesInteractiveTransitionGestureRecognizerNow` on the list's view while content moves, which
    makes `hasHorizontalGestures` `.strict` and fails the pop pan in its own `touchesBegan`) also kills
    the edge swipe for the duration of a fling and needs a device pass. The one thing NOT to do is
    answer it from this engine's own delegate.
  - **`delaysTouchesEnded` must stay `false`.** A freshly constructed recognizer defaults to `true`,
    and `UIScrollView.panGestureRecognizer` — what `ListViewImpl` scrolls on — is `false` (measured on
    iOS 26.2, and asserted as a control in `PhysicsScrollEngineTests`). Left at the default, the list's
    pan withholds every `UITouchPhaseEnded` from the views beneath it until it resolves. Row
    recognizers never notice (they receive touches regardless of hit-testing), which is what makes it
    invisible; a `UIControl` inside a row reads touch-up from the view, and chat's inline bot keyboards
    are real `UIButton`s.
- **Every view in the attachment chain must be a passthrough, and each level fails independently.**
  `AttachmentContainerView` spans the whole content area and is the topmost sibling in `contentHost`,
  and an attachment host typically spans the full content width — so any point one of them claims and
  does not use is a touch the rows never see. Both must answer `point(inside:)` from "would my content
  take this", never from "is this within my bounds": the container asks each subview, and a host asks
  its hosted content's `hitTest` (NOT its `point(inside:)` — a full-width hosted view says yes
  everywhere, which is the same bug one level down). Shipped as both halves at once. The container's
  `if super.point(inside:) { return true }` fast path made the chat's message bubbles receive no
  touches at all; fixing only that left the full-width gutter-avatar hosts blanking every bubble
  beside them. **Scrolling keeps working either way** — the pan recognizer lives on an ancestor, and
  ancestors see touches regardless of where hit-testing settles — so the list looks entirely healthy
  while nothing in it can be tapped. `AttachmentContainerHitTestTests` locks the container half;
  the host half lives in TelegramUI, which has no test target.

## Project conventions

- Work on `main` directly. The user explicitly opted out of worktrees and feature branches here.
- Planned task commits are authorized. Never amend or push unless explicitly asked.
- Stage only task-named files with explicit paths; never use `git add .` or `git add -A` because the
  tree may contain unrelated WIP.
- Use only the dedicated **iPhone 17 Pro K2** simulator. If it is unavailable, stop and ask.
- Every `xcodebuild ... test` command must include `-parallel-testing-enabled NO`.
- **Attachment stacking resolves INSIDE the solve, and it cannot live anywhere else.**
  `CoreListAttachedItem.stackingGroup` tags an attachment into a group; `stackingYield` names a group
  it defers to plus a minimum gap, and `AttachmentOffsetMap.y(atOffset:)` composes the partners'
  positions into its own — `min` over every OVERLAPPING partner (the overlap test is load-bearing:
  without it a partner far above wins the min unconditionally), iterated to a fixed point, clamped at
  the band top. The obvious implementation, a post-solve fix-up over view frames, is wrong for one
  reason: `composedKeyframe` SAMPLES `y(atOffset:)` to bake the CA track a momentum flight rides, so
  a nudge resolved anywhere else would be absent from that track and the attachment would ride
  un-nudged for the whole deceleration and snap at the end. **One level only** — a map that yields
  must not itself be a yield target — asserted, not merely documented. Two consequences that look
  free and are not: a yielding attachment's `stickDistance` measures against the adjusted bound (else
  one riding its run reports a full gap of stick and fades as though parked), and sibling z-order is
  re-asserted by `renderAttachments` on every render, because appending only unseen views left the
  order to whichever run entered the loaded window first.
- **An attachment's frame and its stick distance solve at DIFFERENT offsets, deliberately.**
  `renderAttachments` writes the frame at `attachmentSolveOffset` — the flight's destination while one
  plays, because the additive `CAKeyframeAnimation` supplies the displacement — and delivers
  `stickDistanceUpdated` at the live `engine.offset`, because nothing on the render server carries
  that value and a consumer deriving an appearance from it needs where the attachment IS. Solving the
  distance at the settled offset freezes it for the whole fling; solving the frame at the live offset
  doubles the travel. They agree because both go through `AttachmentOffsetMap.y(atOffset:)`, which is
  also what `composedKeyframe` bakes — asserted vertex-by-vertex in
  `AttachmentKeyframeParityTests.testStickDistanceDescribesTheRenderedPositionAtEveryVertex`.

## Documentation authority

`CLAUDE.md` is the repository map and concise current contract. Read the source files and retained
designs named by each subsystem before making a non-trivial change.

`docs/plans/` contains current foundational designs and reverse-engineering analyses.
`docs/superpowers/specs/` contains current extensions to those designs.
`docs/plans/CHANGELOG.md` is a compact digest of landed work in the current granular-animation era.
Completed execution plans, handoffs, result logs, proofs, and superseded architectures are retained
only in Git history.
