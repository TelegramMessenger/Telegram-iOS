# Scroll-engine seam — design

**Date:** 2026-05-26
**Status:** IMPLEMENTED / CURRENT

## Goal

Begin migrating `CoreVirtualListView` off `UIScrollView` and onto the owned, reverse-engineered `ScrollPhysics` core (eventually `PhysicsScrollView`'s engine). This first increment introduces the **seam** that makes that swap possible and does **nothing else**: extract a `ScrollEngine` protocol, adapt today's `UIScrollView` behind it (`UIKitScrollEngine`), and refactor the list to talk to the engine — with **zero behavior change** and all 319 existing tests still green.

## North star (out of scope here)

Drive `CoreVirtualListView`'s scroll/deceleration through `ScrollPhysics` and the keyframe path so the
list keeps rendering smoothly even when the main thread is busy loading or laying out rows, and so
the project owns its scroll behavior end-to-end instead of inheriting `UIScrollView`'s. This seam
design establishes the swap point; the retained physics and keyframe designs own the later
trajectory, edge, and coordinate-rebase behavior.

## Why a seam first (not a spike on the hard parts)

The migration is a large, multi-subsystem change. Rather than chase the scary coordinate-space problems first, we establish a clean abstraction boundary — mirroring how the codebase already injects `ListAnimator`, `Scheduler`, and `TestableScrollView`. Pinning down the (deliberately tiny) contract the list needs from a scroll engine de-risks everything downstream and proves the list does not actually depend on `UIScrollView`'s API beyond a small surface.

## The surface the list uses from `UIScrollView` today

Enumerated from `CoreVirtualListView.swift`:

1. **Reads** `scrollView.bounds.origin.y` as the scroll position — `scrollViewDidScroll`, `rebalanceActiveWindow` (`:1411`), `applyChanges` anchor resolution (`:388`, `:422`).
2. **Writes** `bounds.origin.y` programmatically, always wrapped in `isUpdating` to suppress the re-entrant callback — `setBoundsOriginY` (`:1748`), the delta clamp (`:1398`), the rebalance reposition shift (`:1465`).
3. **Sets** `contentSize` — the 10M virtual-height trick + the tight collapse when both edges fit (`render :1705`, `rebuildFromScratch :231`).
4. **Consumes** `scrollViewDidScroll`.
5. **Hosts** `container` inside the scroll view, plus exit snapshots added to the scroll view (not the container) so they don't ride container repositioning (`:222`, `:1730`).
6. Receives pan + momentum + rubber-band + bounce for free.

That is the entire contract.

## Architecture

A `ScrollEngine` protocol that `CoreVirtualListView` consumes (chosen over merging the list into `PhysicsScrollView`, or embedding `PhysicsScrollView` wholesale — keeping *physics* and *virtualization* as two independently-testable concerns, consistent with the existing DI seams). The seam speaks **physics-semantic** vocabulary (a scroll offset + edges + a shift), not `UIScrollView`'s (`bounds.origin.y` + `contentSize`): the 10M `contentSize` is a workaround for `UIScrollView` needing a finite content size, and the physics core has no such constraint, so the trick is confined to the `UIScrollView` adapter where it belongs.

### The `ScrollEngine` protocol

```swift
protocol ScrollEngine: AnyObject {
    /// Current scroll position in the engine's offset coordinate.
    var offset: CGFloat { get }

    /// Fires ONLY on user-driven scroll (drag/momentum/bounce). Programmatic
    /// writes never re-enter this — the adapter absorbs today's `isUpdating` dance.
    var onScroll: ((_ offset: CGFloat) -> Void)? { get set }

    /// Programmatic absolute write (≈ today's `setBoundsOriginY` + the delta clamp).
    func setOffset(_ y: CGFloat)

    /// Programmatic relative shift — the rebalance reposition (≈ `bounds.origin.y += shift`).
    func applyShift(_ dy: CGFloat)

    /// Declares the scrollable extent as edges; either may be open (nil = unbounded /
    /// no bounce on that side). Replaces `contentSize`.
    func setEdges(min: CGFloat?, max: CGFloat?)

    /// Where the list parents `container` and exit snapshots (snapshots must NOT ride
    /// container repositioning, so they sit here, above the container — as today).
    var contentHost: UIView { get }

    /// The open-coordinate magnitude the list uses to centre the container when neither
    /// edge is loaded (today's `virtualContentHeight`). UIScrollView needs a finite
    /// extent; physics won't — see "Known seam point" below.
    var openExtent: CGFloat { get }
}
```

Two deliberate moves:

- **Edges replace `contentSize`.** The list declares *where the bounce points are* — top loaded → `min: 0`; bottom loaded → `max: <content bottom> − viewport`; neither → both nil. The `UIKitScrollEngine` adapter translates that back into `contentSize`, **reproducing today's `computeContentSize` exactly**. The future physics adapter maps edges straight to `ScrollAxis.min/max` with no `contentSize`.
- **Programmatic writes own the re-entrancy guard.** `setOffset`/`applyShift` suppress `onScroll` internally, so the list stops juggling `isUpdating`; `onScroll` now means *"the user moved it,"* full stop.

### Edge ↔ contentSize mapping (the adapter)

In the offset coordinate, `UIScrollView` always bounces at `[0, contentSize.height − viewport]` with the content glued to those bounds by the container's position. So the adapter reproduces today's numbers:

- **Both edges bounded** (both edges loaded): `contentSize.height = max(viewport, (max − min) + viewport)` — the tight collapse, honoring the small-content viewport floor (`max(logicalSize.height, window.height)` today).
- **Either edge open** (single edge loaded, or neither): `contentSize.height = openExtent` (the 10M coordinate). The list positions the container to glue the loaded edge (if any) to the matching `UIScrollView` bound, exactly as `computeContainerOriginY` does today; the open side's bound sits ~10M away and is effectively unreachable.

`computeContentSize` either moves into the adapter or stays in the list as the helper that derives the edges — the plan picks whichever keeps the diff smallest; the existing small-content tests pin the floor either way.

### Data flow

- **User scroll:** `UIScrollView` pans/decelerates/bounces → its `bounds.origin.y` changes → adapter's `scrollViewDidScroll` fires `onScroll(offset)` (only when not programmatic) → list's handler runs today's `scrollViewDidScroll` body: delta-clamp to `logicalSize.height` (corrective write via `engine.setOffset`), update `previousOffset`, `rebalanceActiveWindow()`.
- **Rebalance reposition:** list computes the container shift → `engine.applyShift(shift)` (suppressed) → snapshots shifted → `render()`.
- **`render()` / `rebuildFromScratch`:** list computes window layout + container origin (unchanged, using `engine.openExtent`) → `engine.setEdges(min:max:)` → adapter sets `contentSize`.
- **Programmatic scroll (`setBoundsOriginY`):** `engine.setOffset(y)` (suppressed) + `previousOffset = y`.

### `UIKitScrollEngine` (new file)

The only place that knows about `UIScrollView`:

- Wraps an injected `UIScrollView` (defaults to a fresh one; the demo and tests pass theirs). Owns all config currently in `setup()` (`bounces`, indicators off, `contentInsetAdjustmentBehavior`, the debug border).
- Is the `UIScrollViewDelegate`: `scrollViewDidScroll` fires `onScroll(scrollView.bounds.origin.y)` **unless** a private `isProgrammatic` flag is raised — `setOffset`/`applyShift` raise it around their writes (today's `isUpdating`, encapsulated).
- `offset` ↔ `bounds.origin.y`; `setEdges` ↔ `contentSize` (per the mapping above); `contentHost` is the scroll view; `openExtent` returns `10_000_000`.

### List changes (mechanical; no logic moves)

- Init swaps the injected `scrollView: UIScrollView` for `engine: ScrollEngine` (default `UIKitScrollEngine()`). `setup()` parents `engine.contentHost`, adds `container` into it, keeps sizing the host to the list's bounds.
- Every `bounds.origin.y` read → `engine.offset`; every programmatic write → `engine.setOffset`/`engine.applyShift`. The `isUpdating` field and its three wrappings are deleted.
- `scrollViewDidScroll(_:)` → an `onScroll` closure holding the same body.
- `render()`/`rebuildFromScratch` call `engine.setEdges(...)` instead of setting `contentSize`. `computeContainerOriginY` unchanged (sources the 10M constant from `engine.openExtent`).
- Exit snapshots add to `engine.contentHost` (`:1259`, `:1730`); the snapshot shift loop is unchanged.

Net: `CoreVirtualListView` imports no knowledge of `UIScrollView`; all of it lives behind one small adapter.

## Known seam point (physics increment's concern)

`openExtent` and the list's "centre the container at `openExtent/2` when neither edge is loaded" branch of `computeContainerOriginY` are a `UIScrollView`-ism (it needs a finite `contentSize`). Kept **exactly as today** here. The physics engine won't need a 10M coordinate, so the container-centring / coordinate re-baselining strategy changes in that later increment. Flagged, not touched.

## Testing

**The behavior-frozen contract: all 319 existing tests stay green, unchanged in intent** — they prove the seam extraction changed nothing.

- **Harness wiring (option (a) — wrap, don't replace):** `VirtualListFixture`/`VirtualListDriver` construct `UIKitScrollEngine(scrollView: TestableScrollView(...))` and inject it. The driver keeps a direct reference to the `TestableScrollView` so `tick(dt:)` drives its deterministic `.programmatic`/`.decelerating`/`.rubberBand` modes exactly as today; the engine's delegate turns each resulting `bounds.origin.y` change into an `onScroll`. Fixture churn is construction + any accessor that read `fixture.scrollView` now reaching through the engine (or the fixture exposing the underlying `TestableScrollView` for the driver).
- **New focused unit tests — `UIKitScrollEngineTests`:** the adapter in isolation. `setOffset`/`applyShift` suppress `onScroll`; a genuine `bounds` change fires it; `setEdges(0, nil)` / `(nil, max)` / `(min, max)` / `(nil, nil)` each produce the right `contentSize` (including the small-content viewport floor); `contentHost`/`openExtent` are wired.
- **Build/test:** iPhone 17 simulator only, `-parallel-testing-enabled NO`.

## Scope

**In:** the `ScrollEngine` protocol + `UIKitScrollEngine` + the mechanical list refactor + `UIKitScrollEngineTests`.

**Out (named so they don't creep in):**
- No physics engine and no `TestScrollEngine` — next increment.
- No change to the container-centring strategy / the `openExtent/2` neither-edge branch — physics increment.
- None of the three keyframe-doc hard parts (virtual-content trick under physics, rebalance vs. baked keyframe coordinate, mutations during render-server decel).

## Natural next increments (not part of this spec)

1. **(this spec)** `ScrollEngine` seam + `UIKitScrollEngine`, behavior-frozen.
2. `PhysicsScrollEngine` + `TestScrollEngine` for the simple both-edges-fit case (drag + bounce + deceleration drive the list, no open-coordinate trick).
3. Open-coordinate / container-centring rework under explicit physics edges.
4. Keyframe deceleration during virtualization, composed with list mutation animation.
