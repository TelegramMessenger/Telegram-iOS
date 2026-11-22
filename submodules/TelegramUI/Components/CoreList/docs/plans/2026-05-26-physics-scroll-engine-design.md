# Physics scroll engine (increment 2) — design

**Date:** 2026-05-26
**Status:** IMPLEMENTED / CURRENT

## Goal

Add a `PhysicsScrollEngine: ScrollEngine` that drives `CoreVirtualListView` through the owned,
reverse-engineered `ScrollPhysics` core instead of `UIScrollView`, for **arbitrary virtualized
content** (a long list that loads/unloads rows as you scroll — not scoped to the both-edges-fit
case). The work is **purely additive**: `CoreVirtualListView`, `UIKitScrollEngine`, and all 378
existing tests are untouched — they are the regression oracle that proves additivity. Deceleration
uses the `.stepped` (per-frame integration) path only; keyframe deceleration during virtualization
is increment 4. Ship alongside it a deterministic `TestScrollEngine` (the real `ScrollPhysics` core
through the `SyntheticClock`) and a list-demo engine toggle so the physics path can be felt live.

This is increment 2 of migrating the list onto the owned physics core (see
`2026-05-26-scroll-engine-seam-design.md` for the seam that increment 1 established).

## The key decision: additive now, clean later

Increment 1 flagged `openExtent` / the `10_000_000` virtual-content trick as a `UIScrollView`-ism
the physics increment would revisit. The realization that shapes this increment: that machinery
exists **only** because `UIScrollView` clamps `bounds.origin.y` to `[0, contentSize − viewport]`.
The 10M canvas + parking the loaded strip near ~5M + recentering all exist so an open edge sits far
away and is never hit during normal scrolling.

`ScrollPhysics` has **no clamp.** A 5M offset is just a number to it; rubber-band and the edge
spring only engage *past an edge*, and an open edge (`nil`) simply means "no edge that way → free
travel." So the physics engine can run in the **exact same coordinate scheme the list already
uses**, consume the `ScrollEngine` protocol unchanged, and handle arbitrary virtualized content —
without ever needing to be "clean" of `openExtent`. The wart is invisible to it.

Therefore:

- **Capability does not require reworking the abstraction.** `PhysicsScrollEngine` returns
  `openExtent = 10_000_000` (same as the UIKit adapter), so `computeContainerOriginY` produces
  identical container positions; the physics treats those large offsets as ordinary numbers.
- **The abstraction cleanup** (dropping `openExtent`, pushing the base/centering into each adapter)
  is still worth doing for cleanliness, but it is a **separate, behavior-frozen refactor** (the
  original increment 3). It does not gate capability, and it would churn every test that reads
  `containerOriginY`/`contentSize` directly (those encode the ~5M coordinate). Deferred.

Net: this increment adds new files only and leaves the behavior-frozen `UIScrollView` path and its
378-test safety net fully intact.

## What `UIScrollView` gives the list for free that the physics core must learn

The list relies on two `UIScrollView` behaviors that `ScrollPhysics` cannot currently express:

1. **Live edge updates.** When the list loads row 0 mid-interaction it calls `setEdges(min: …)`;
   `UIScrollView` takes the new `contentSize` and starts bouncing at the new boundary. But
   `ScrollAxis.min`/`max` are `let` — there is no way to move the bounce point without rebuilding the
   axis, and rebuilding mid-drag destroys the private `dragStartOffset`/`prevVelocity` the drag and
   release math depend on.

2. **Mid-flight re-base.** `applyShift(dy)` during a rebalance must move the physics core's internal
   `offset` (and, mid-drag, `dragStartOffset`, or the next `drag()` overwrites the shift). This is the
   exact analogue of how `UIScrollView`'s deceleration survives a `bounds.origin.y` shift — and it is
   the mechanism that makes free deceleration **into unloaded content** work: each frame steps, the
   list loads rows and re-bases, and the physics continues seamlessly.

### Why mutate `ScrollAxis` rather than replace it

Replacing the axis from the engine does **not** work: the designated initializer resets the dynamic
state (`velocity = 0`, `phase = .idle`, `dragStartOffset = 0`, `prevVelocity = 0`), and these change
events fire mid-deceleration — so a replace would zero the velocity and the fling would die the
instant a row loads or the container recenters. Carrying the velocity across would require widening
the init, and it still could not round-trip `dragStartOffset`/`prevVelocity` (fully `private`, the
engine cannot even read them). The only way to avoid editing `ScrollPhysics.swift` at all would be to
drive `RubberBand` + `Deceleration` directly from the engine, which **duplicates** `ScrollAxis`'s
reverse-engineered orchestration (the `0.75/0.25` release low-pass, the `0.0625` stop threshold, the
overscroll rule) in a second place that can drift from the validated core.

So the minimal, encapsulation-preserving move is two **additive state-transition methods on
`ScrollAxis`**, authored inside the type (where they can copy the private state), changing **no
constant or formula**:

```swift
// in ScrollPhysics.swift, struct ScrollAxis
private(set) var min: CGFloat        // was `let`
private(set) var max: CGFloat        // was `let`

/// Move the bounce points without disturbing the dynamic state (offset/velocity/phase/
/// dragStartOffset/prevVelocity). The analogue of a `UIScrollView` contentSize change.
mutating func setBounds(min: CGFloat, max: CGFloat)

/// Rigidly re-base the axis (offset and the in-progress drag anchor move together), so a
/// rebalance reposition mid-drag/mid-decel composes. The analogue of a `bounds.origin.y` shift.
mutating func shift(by dy: CGFloat)
```

## Architecture

```
                CoreVirtualListView  (UNCHANGED — consumes the existing ScrollEngine protocol)
                          │  offset / setOffset / applyShift / setEdges / onScroll / contentHost / openExtent
        ┌─────────────────┴───────────────────────┐
        │                                          │
  UIKitScrollEngine                         PhysicsScrollEngine   (NEW, production, .stepped, touch)
  (UNCHANGED, default)                              │
        │                                    ┌──────┴───────┐
  UIScrollView                         PhysicsPanGR   CADisplayLink (stepping)
                                              │              │
                                        PhysicsScrollCore  (NEW, shared seam glue over ScrollPhysics)
                                              │
                                         ScrollPhysics  (+ additive ScrollAxis.setBounds/shift)
                                              ▲
                                        PhysicsScrollCore
                                              │
                                       TestScrollEngine  (NEW, test support, deterministic via SyntheticClock)
```

### `PhysicsScrollCore` (new — shared so production and tests exercise the same glue)

A small object owning the `ScrollPhysics` (active y-axis; x is a no-scroll axis with `min == max`)
and implementing the seam operations over it. Both `PhysicsScrollEngine` and `TestScrollEngine` are
thin wrappers around it, differing only in their **trigger source** (real pan + display link vs.
synthetic `simulate*` + manual `tick`). This guarantees the deterministic tests cover the **shipping**
integration glue, not a parallel reimplementation.

- Holds the `ScrollPhysics`, the `contentHost` reference, and a sink `(CGFloat) -> Void`.
- **User-driven motion** (`drag`, `step`) writes `contentHost.bounds.origin.y` *and* fires the sink
  (→ the engine's `onScroll`).
- **Programmatic writes** (`setOffset`, `applyShift`) write `bounds.origin.y` and update the physics
  offset (via `shift`) but **never** fire the sink. Suppression is trivial here — there is no
  `UIScrollView` delegate to re-enter, so no `isProgrammatic` flag is needed (unlike the UIKit
  adapter).
- `setEdges(min:max:)` → `physics.y.setBounds(...)`. An **open edge** (`nil`) maps to a **far
  sentinel** (`offset ± 1e7`), refreshed on each `setEdges`/`shift` so it is never reachable before
  the next rebalance moves it — the same "unreachable bound" trick `UIScrollView` uses internally,
  with the existing rubber-band/deceleration math untouched.
- `beginDrag`/`drag(translation:recognizerVelocity:)`/`endDrag()`/`step(dtMs:)` delegate to
  `ScrollPhysics`.

*Plan-time verification (load-bearing):* confirm `Deceleration`/`RubberBand` behave with a far
sentinel bound (they spring only past an edge, so a ~1e7-away edge should yield pure free decel) —
read `Deceleration.swift` and `Projection.swift` to confirm no overflow or projected-target weirdness.
Fallback: a clamped/relative sentinel.

### `PhysicsScrollEngine: ScrollEngine` (new — production, `.stepped`-only, touch)

The only new file that drives the list with owned physics. Mirrors `PhysicsScrollView`'s `.stepped`
driver but drives `contentHost.bounds.origin.y` (not `contentView.frame.origin.y`), so the list's
layout math is byte-for-byte unchanged.

- `contentHost` = a plain `UIView`. The list parents `container` + exit snapshots into it, and
  `offset == contentHost.bounds.origin.y`. A plain `UIView`'s `bounds.origin.y` shifts its subviews
  exactly as a `UIScrollView`'s does, and exit snapshots (siblings of `container`) ride
  `bounds.origin.y` but not `container` repositioning — identical to today.
- Owns a `PhysicsScrollCore`, a `PhysicsPanGestureRecognizer`, and a stepping `CADisplayLink`.
- `handlePan`: `.began` → catch any in-flight decel + `beginDrag`; `.changed` → `core.drag`;
  `.ended`/`.cancelled` → `core.endDrag()` → start the stepping link if `.decelerate`. Touch-down
  (`onTouchDown`) catches a moving decel when a finger lands (stop where the finger caught it).
- `step(link)`: `core.step(dtMs: one display frame)` → write offset → fire `onScroll` → the list
  rebalances (loads/unloads rows) and `applyShift`s; the mutated axis makes edge-appearance and
  re-base compose frame-by-frame. Settling stops the link.
- `offset` getter returns the **current scroll position** (= `bounds.origin.y` in `.stepped`),
  defined abstractly so the increment-4 keyframe getter can return the live trajectory sample.
- `openExtent = 10_000_000` (so the list's container math is identical to the UIKit path).
- Trackpad and `.keyframe` are explicitly out of scope here (future increments).

### `TestScrollEngine: ScrollEngine` (new — test support, deterministic)

A deterministic `ScrollEngine` driving the **real** `ScrollPhysics` core through the `SyntheticClock`
— no pan recognizer, no `CADisplayLink`. Strictly higher fidelity than today's `TestableScrollView`
(which hand-rolls spring/decel approximations): new tests validate the list against the actual
reverse-engineered physics.

- `contentHost` = a plain `UIView`; owns a `PhysicsScrollCore` + the `SyntheticClock`.
- `simulateDrag(translation:velocity:)` / `simulateFlick(velocity:)` / `simulateRelease()` →
  `core.beginDrag`/`drag`/`endDrag` (inputs shaped like the recognizer's: cumulative translation in
  points, velocity in points/second).
- `tick(dt:)` → if decelerating, `core.step(dtMs: dt * 1000)` → write offset → fire `onScroll`.
- `openExtent = 10_000_000`.

## Data flow

- **User drag:** pan `.changed` → `core.drag` → write `bounds.origin.y` → `onScroll(offset)` → the
  list's `handleUserScroll` → `rebalanceActiveWindow` (loads/unloads rows; `applyShift`s the offset by
  the container delta, which `shift`s the physics offset so position is preserved).
- **Release + deceleration/bounce:** pan `.ended` → `core.endDrag()` → stepping link → each frame
  `core.step` writes `bounds.origin.y` and fires `onScroll`; free-travel (open edge → far sentinel)
  decelerates without bouncing while the list progressively loads rows; when the list loads a real
  edge it calls `setEdges`, the axis `setBounds`, and the next `step` springs at the new boundary.
- **Programmatic (`setBoundsOriginY`/`applyChanges` jumps):** `engine.setOffset(y)` → write `bounds`
  + `shift` the physics offset; no `onScroll`.
- **`render()` edges:** `engine.setEdges(min:max:)` → `core` maps to `physics.y.setBounds` (open →
  far sentinel).

## Harness wiring (additive)

- The existing `VirtualListDriver`/`VirtualListFixture` keep `UIKitScrollEngine(TestableScrollView)`
  **verbatim** — the 378 tests do not change.
- **Minimal generalization** of the driver: `sample()` reads `engine.offset` instead of
  `scrollView.bounds.origin.y` (bit-identical for the UIKit path, since
  `UIKitScrollEngine.offset == scrollView.bounds.origin.y`, so the 378 traces are unchanged); the
  driver takes a `tickEngine` closure (`{ scrollView.tick($0) }` for UIKit, `{ testEngine.tick($0) }`
  for physics). Add a physics convenience init/fixture reusing all the `Trace`/assertion machinery.
- **Fallback** if the generalization ripples into the 378: a fully parallel physics driver/fixture.
  The 378-green run is the oracle that decides.

## Demo

A `UIScrollView | Physics` `UISegmentedControl` in `ViewController`'s top bar. On change, rebuild
`listView` with the chosen engine (`CoreVirtualListView(engine: UIKitScrollEngine())` vs.
`PhysicsScrollEngine()`) and re-apply items + size. Mirrors `PhysicsScrollDemoViewController`'s
stepped/keyframe control — the way to feel the physics engine drive the real list.

## Testing

- **`ScrollAxisMutationTests`** — `setBounds`/`shift` preserve the dynamic state, move the bounce
  point, and re-anchor the drag (a `shift` mid-drag composes with the next `drag()`).
- **`PhysicsScrollCoreTests`** — seam ops over physics: `setOffset`/`applyShift`/`setEdges`,
  free-travel on an open (far-sentinel) edge, edge-appears-then-bounces.
- **`PhysicsScrollEngineTests`** (via the physics fixture) — drag/flick/decelerate/bounce drive the
  list; the window rebalances during a free-travel deceleration; a mid-flight `applyShift` composes
  with no visible jump; arbitrary content (taller than the viewport, partially loaded) scrolls
  end-to-end and settles. Reuses `assertContiguousEveryFrame` / `assertNoVisibleJump` / `assertEndsAt`.
- **Build/test:** iPhone 17 simulator only, `-parallel-testing-enabled NO`.
- **The 378 existing tests must stay green** — the additivity oracle.

## Scope

**In:** `PhysicsScrollEngine` (`.stepped`, touch), `PhysicsScrollCore`, the additive
`ScrollAxis.setBounds`/`shift`, `TestScrollEngine` + the physics fixture, the demo toggle, and the new
tests.

**Out (named so they do not creep in):**
- Keyframe deceleration during virtualization — increment 4 (see below).
- Trackpad (indirect) scroll on the list engine — later.
- `openExtent` removal / the container-centring abstraction cleanup — its own behavior-frozen
  refactor (the original increment 3).

## Forward-compatibility (so increment 4 is a clean extension, not a rework)

Keyframe-during-virtualization is increment 4 because the baked path assumes fixed edges and snaps
the model to `finalOffset`, which fights live edge-discovery and container re-basing. The unifying
principle that makes it tractable — and which this increment must not foreclose — is:

> **Every animation carries an explicit start time and is sampleable at the current instant.** On any
> change (edge appears, re-base, item resize), *catch* (sample the live offset/velocity at
> `now − startTime`), mutate state (`setBounds`/`shift`), *rebake*, and *relaunch* with
> `beginTime = now`. Because `Trajectory.build` is the `.stepped` integrator run ahead, a rebake from
> a frame-tick sample with new conditions is bit-for-bit "live integration that learned about the
> change at that tick."

This discipline already exists in the codebase (the analytic slide store's explicit `beginTime` +
layer-local time; `Trajectory.positionKeyframeAnimation(beginTime:)`; `PhysicsScrollView`'s
`flightStartLocalTime` + trajectory sampling). The commitments this increment honors so increment 4
extends cleanly:

1. **`engine.offset` means "current scroll position," not "the layer's model value."** `.stepped`
   makes them coincide; keyframe-later makes the getter return the live sample.
2. **`onScroll` fires once per *visible* frame regardless of driver** (stepping link now, sampling
   link later) — the list's rebalance is identical either way.
3. **`setBounds`/`shift` are the mode-agnostic mutation substrate** — `.stepped` feeds them to the
   next `step()`; `.keyframe` will feed them to a rebake (`catchFlight` → `setBounds`/`shift` →
   `launchFlight`).

The one subtlety banked for increment 4: between vertices the trajectory interpolates linearly and
stores pixel-rounded offsets, so a sub-frame rebake carries ≤0.5px slop; rebaking on a frame boundary
(where changes are processed anyway) stays exact, and a full-precision offset alongside the rounded
write removes it entirely if needed.

## Natural next increments (not part of this spec)

3. `openExtent` removal / container-centring abstraction cleanup (behavior-frozen refactor).
4. Keyframe deceleration during virtualization (rebake-on-change, composed with list mutation
   passes), plus trackpad on the list engine.

## Post-implementation notes

Landed across commits for `ScrollAxis.setBounds`/`shift` → `PhysicsScrollCore` → `PhysicsScrollEngine`
→ `TestScrollEngine` → harness → integration tests → demo toggle → docs. The pre-existing tests
stayed green throughout (additivity confirmed); the new suites add the physics-engine coverage.
Findings worth carrying forward:

- The shared frame sampler (`buildListFrame`) made the physics driver a thin reuse rather than a
  duplicate; the UIScrollView path is bit-identical because `engine.offset == bounds.origin.y`.
- The far-sentinel open-edge mapping (`offset ± 10M`, refreshed each `writeOffset`/`setEdges`) is the
  engine-internal equivalent of the list's `openExtent`; it never overflows because `Deceleration`
  only compares against the bounds and `rebalanceActiveWindow` re-declares edges after every
  `applyShift`. The bottom-edge (`maxEdge`/bottom-only) spring-back was added as an integration test
  and passes — the large bottom coordinate behaves like any other.
- Review follow-ups hardened three things beyond the core spec: catching on touch-down clears the
  core's residual `.decelerating` phase (`PhysicsScrollCore.cancelDeceleration`), and the demo toggle
  tears down the outgoing engine's display link (`PhysicsScrollEngine.tearDown`) so a mid-decel swap
  doesn't leave it stepping a detached host.

### For the keyframe increment (4)

`engine.offset` is the abstract current position, `onScroll` fires per visible frame, and
`setBounds`/`shift` are the mode-agnostic mutation substrate — so a keyframe driver fires `onScroll`
from the sampling link and consumes `setBounds`/`shift` via a `catchFlight → rebake → relaunch`
(explicit `beginTime` each time), which is bit-equivalent to the `.stepped` path at frame ticks.
