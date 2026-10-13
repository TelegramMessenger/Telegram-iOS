# Trackpad on the list engine (`PhysicsScrollEngine`) — increment 4b — design

**Date:** 2026-05-28
**Status:** IMPLEMENTED / CURRENT, with one mechanism superseded 2026-08-04

> **Superseded detail.** This document refers in passing to `shouldBeRequiredToFailBy` as part of the
> touch tap-absorption path (§ "Fix", and the "Touch tap-stop path is orthogonal" note). That
> delegate method no longer exists: the engine now grants no gesture simultaneity at all and declares
> no failure dependency, so absorption is plain UIKit exclusion. See the arbitration gotcha in
> `CoreList/CLAUDE.md`. Everything here about `shouldReceive(event:)` and the trackpad path is
> unchanged and still current.

## 1. Goal & scope

Bring **`PhysicsScrollEngine`** — the `ScrollEngine` that drives `CoreVirtualListView` via the owned
`ScrollPhysics` core — to the same **trackpad** fidelity the standalone `PhysicsScrollView` already
has: a faithful replica of `UIScrollView`'s continuous indirect-scroll handling, on both the
`.stepped` and `.keyframe` deceleration paths. This is increment **4b** of the migration roadmap
(see CLAUDE.md "Increment roadmap & status").

- **In scope:** continuous two-finger trackpad scroll on the list engine — drag-follow, edge
  rubber-band with the correct trackpad coefficient, post-lift inertia (Approach-2 momentum), and
  **catch-on-finger-rest** (resting fingers over a decelerating list stops it at once).
- **Out of scope:** discrete mouse-wheel, pointer/scrollbar drag, the X-axis directional lock
  (decoded but unmodeled), and `applyChanges` during a keyframe decel (increment 4c).
- **Non-negotiable:** the reverse-engineered physics (`ScrollPhysics`, `Trajectory`, `RubberBand`)
  are **not** modified — the trackpad coefficient (`RubberBand.trackpadCoefficient = 0.715`) and the
  finger-rest mechanism (`shouldReceive(event:)`) already exist from the 2026-05-25 trackpad work;
  4b only *wires* them into the list engine. Additive: `UIKitScrollEngine` stays the default.

## 2. Background — what already transfers for free

`PhysicsScrollEngine` and `PhysicsScrollView` share the same `PhysicsPanGestureRecognizer`, which
sets `allowedScrollTypesMask = .continuous` in its `init`. So the list engine's pan **already**
accepts two-finger trackpad scroll and feeds it through `handlePan(.began/.changed/.ended)` →
`PhysicsScrollCore.drag/endDrag` → the same physics. Concretely, already working on the list engine
today:

- **Basic trackpad scroll + Approach-2 momentum** (drag → release → decelerate), on both `.stepped`
  and `.keyframe`. Trackpad momentum was found (2026-05-25 §11) to arrive as a normal active-drag →
  release → deceleration, which routes through the existing `startDeceleration()`.
- **The `.began` flight-catch.** `handlePan(.began)` already does `if flight != nil { catchFlight() }`
  (added for the keyframe / tap-stop work), and `.stepped` catches via `core.beginDrag()`'s rebuild.
  So once a trackpad scroll *moves*, an in-flight decel is caught — independent of touch-down.

This leaves exactly **two gaps** between the list engine and `PhysicsScrollView`'s trackpad feel.

## 3. The two gaps and their fixes

### 3.1 Trackpad rubber-band coefficient (the one real physics difference)

`PhysicsScrollCore.makePhysics(offset:)` builds its axes with `ScrollAxis`'s default
`c = RubberBand.touchCoefficient` (0.55). Trackpad overscroll uses the looser
`RubberBand.trackpadCoefficient` (0.715) — the single physics difference root-caused in the
2026-05-25 work (touch's 0.55 diverged 54–65px on trackpad spring-back). `PhysicsScrollView.makePhysics`
already selects `pan.isIndirectScroll ? .trackpadCoefficient : .touchCoefficient`; the list engine's
core does not, so trackpad overscroll on the list is currently wrong.

**Fix.** Thread the per-gesture indirect signal into the core, mirroring the existing `updateScale`
seam:

- `PhysicsScrollCore`: add `private var coefficient: CGFloat = RubberBand.touchCoefficient` and
  `func updateRubberBandCoefficient(_ c: CGFloat)`. `makePhysics(offset:)` passes `c: coefficient`
  to **both** axes (x is a no-scroll axis, so it is symmetry only — matches `PhysicsScrollView`).
- `PhysicsScrollEngine.handlePan(.began)`: beside `refreshScale()`, call
  `core.updateRubberBandCoefficient(pan.isIndirectScroll ? .trackpadCoefficient : .touchCoefficient)`.
  By `.began`, `isIndirectScroll` is already correct for this gesture (touch's `touchesBegan` cleared
  it to `false`; trackpad, which fires no `touchesBegan`, leaves it `true`), and the recognizer's
  `reset()` restores it between gestures — so the stateful coefficient never leaks from a trackpad
  gesture into a following touch gesture.

The coefficient only matters during the **drag** phase (the rubber-band); the deceleration
spring-back is c-independent (fixed `ln(0.99)` stiffness, per 2026-05-25 §11). `makePhysics` is the
single build site (`beginDrag`, `resumeBounceIfOverscrolled`, `cancelDeceleration`), so a coefficient
set at `.began` covers the drag that produces the overscroll.

### 3.2 Catch-on-finger-rest for trackpad (§12 public-API mechanism)

Resting two fingers over a decelerating/flighting list must stop it immediately (UIScrollView feel),
but trackpad delivers **no touch-down** (so `onTouchDown`/`shouldBeginImmediately` never fire for it)
and the pan only reaches `handlePan(.began)` on the first scroll *movement*, never on a pure
finger-rest. `PhysicsScrollView` solved this (2026-05-25 §12) with the **public**
`UIGestureRecognizerDelegate.gestureRecognizer(_:shouldReceive:)` (the `UIEvent` overload): UIKit
offers the indirect-scroll event to the recognizer the instant fingers land, while `state ==
.possible` — the public equivalent of `touchesBegan`. No private API.

**Fix.** `PhysicsScrollEngine` is already the pan's `UIGestureRecognizerDelegate` (for the tap-stop
`shouldBeRequiredToFailBy` / `shouldRecognizeSimultaneouslyWith`). Add the `UIEvent` overload:

```swift
func gestureRecognizer(_ gr: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
    if gr.state == .possible { catchMotionForFingerRest() }
    return true   // never block the event
}
```

with a new private helper unifying the engine's two modes:

```swift
private func catchMotionForFingerRest() {
    if flight != nil { catchFlight() }                       // keyframe: snap model to live + remove anim
    else if core.isDecelerating { stopDisplayLink(); core.cancelDeceleration() }   // stepped: hold position
}
```

The `.possible` gate confines it to finger-down (it must never fire mid-drag, which would null the
motion). The stepped branch holds the content where it caught and fires no `onScroll` (nothing moved,
so no rebalance is needed). This is the engine analogue of `PhysicsScrollView.catchContent`, extended
to the engine's keyframe-vs-stepped split.

## 4. Interactions (no conflict)

- **Touch tap-stop path is orthogonal.** The `shouldReceive(event:)` `UIEvent` overload is consulted
  by UIKit only for the indirect-scroll event (2026-05-25 §12: "isn't used for touches"), so it does
  not interfere with the touch tap-absorption (`shouldBeginImmediately` + `shouldBeRequiredToFailBy`),
  which stays touch-only. Trackpad does not tap rows, so tap-absorption is irrelevant to trackpad.
- **Accepted catch-latency floor.** The trackpad finger-rest catch halts ~1–2 frames later than
  `UIScrollView` — trigger timing, not the stop (`.keyframe`/`.stepped` halt identically once caught).
  This is the documented floor of the public approach (2026-05-25 §12), inherited unchanged.

## 5. No structural demo change

The Virtual List demo's 3-way engine toggle (UIScrollView / Physics·step / Physics·keyframe) already
exists, and trackpad drives whichever engine is selected automatically once the wiring above is in
place. At most a one-line caption note; no structural change.

## 6. Testing

- **Deterministic (added).** A `PhysicsScrollCoreTests` case for the trackpad coefficient: with
  `updateRubberBandCoefficient(.trackpadCoefficient)` set, a fixed top-edge overscroll drag resists
  **less** than the touch coefficient (looser rubber-band), and a release springs back to the edge.
  This is the one real physics difference and is fully unit-testable through the pure core — no
  `UITouch`, mirroring `test_loadedTopEdge_overscrollDrag_rubberBands_andSpringsBack` and the
  `TrackpadScrollPhysicsTests` ground-truth value (0.715).
- **Not unit-tested (precedent).** The finger-rest catch is gesture-arbitration + `CADisplayLink`
  layer, which the synthetic harness structurally cannot exercise (no real `UITouch`/indirect-scroll
  event) — exactly as the 2026-05-25 §12 finger-rest catch and the tap-stop work. Validated by
  **suite-green (additive, all existing tests pass)** + an **on-device trackpad check** confirming:
  scroll/flick/overscroll feel, correct (looser) overscroll, and finger-rest stops a decelerating
  list on both modes.

## 7. Follow-up resolution — trackpad rest-then-lift bounce-resume

Originally deferred at parity with `PhysicsScrollView` §12, then resolved during 4b's on-device
sweep (the user hit it immediately on a real bounce). The fix took three landings — recording the
full path because the dead ends matter for anyone touching this seam later.

**(1) `shouldReceive(event:)` forces `state = .began`.** UIKit only fires `shouldReceive(event:)`
**once per gesture, at finger-down** (§12 was right about that — it is *not* re-consulted on lift).
So there is no public lift-only signal. The only way to drive a bounce-resume on lift is to make the
recognizer enter `.began` at finger-down so UIKit naturally transitions it through
`.ended`/`.cancelled` on the natural finger-lift — at which point `handlePan(.cancelled)` →
`core.endDrag()` returns `.decelerate` for an overscrolled offset (regardless of a prior
`beginDrag`, per `ScrollAxis.endDrag` lines 60–63), and `startDeceleration()` springs back via a
fresh keyframe flight. Public-API analogue of touch's `shouldBeginImmediately` path.
*Dead end ruled out first:* `UIScrollEvent.phase` is not in the iOS public SDK (the symbol exists
in the framework's TBD but is not declared in any importable header — only published on macOS).

**(2) `catchFlight` reordered.** Pre-fix `catchFlight` nulled `flight` and bumped
`flightGeneration` *after* `removeAnimation(forKey:)`. The CA completion block's stale-generation
guard works for *async* completion only. The forced-`.began` trackpad path turned out to hit a
window where the completion fires synchronously during `removeAnimation` — the guard then passed
the not-yet-bumped generation, `finalizeFlight` ran, and `core.setOffset(f.settledOffset)` +
`onScroll(settledOffset)` jumped the list to the post-animation rest position at the moment of
catch. Reorder: invalidate `flight` (so `finalizeFlight`'s own `guard let f = flight` short-
circuits) and bump the generation **before** `removeAnimation`. Belt-and-suspenders against both
sync and async completion.

**(3) Track our own translation baseline on the forced-`.began` path.** On-device NSLog tracing
showed the recognizer's translation at our forced `.began` carried the **stale cumulative value
from the prior flick** (e.g., `trans=272.17`), and `pan.setTranslation(.zero, in: host)` from the
delegate is **silently ignored for indirect-scroll** (the recognizer's translation for trackpad
scroll isn't governed by the standard touch translation accumulator that `setTranslation` adjusts).
UIKit then fired `.changed` with that stale value, and `core.drag(272, 0)` re-applied the rubber-
band on top of the already-rubber-banded live offset → the list visibly jumped deep into overscroll,
and `handlePan(.cancelled)` then `launchFlight`d a fresh bounce from the deeper position. Fix:
`shouldReceive(event:)` sets a `trackpadForcedBegan` flag before forcing `.began`; `handlePan(.began)`
captures the recognizer's stale translation as `trackpadTranslationBaseline`; `handlePan(.changed)`
feeds `core.drag` with `(rawTrans − baseline)` so drag math sees the delta **since the catch**, not
the cumulative since the prior gesture; and no-movement `.changed` events (`delta == 0 && vel == 0`)
on the forced path are skipped — `core.drag(0, 0)` on the held overscrolled offset would otherwise
re-apply the rubber-band to `dragStartOffset` (which IS already rubber-banded) and compress further.
The flag is reset on `.ended`/`.cancelled`, so touch's natural-hysteresis `.began` keeps its current
raw-translation semantics. Verified on-device by the user after the fix landed (`20313f1`).

**Why the fix is gated to the forced-`.began` path.** For a natural touch `.began` from the
hysteresis threshold, the recognizer's translation is *the post-hysteresis movement*, which IS the
real translation the drag math needs. Subtracting it as a baseline would silently lose the first
~10pt of every touch flick — a UIScrollView fidelity regression. The flag confines the baseline
math to the case where the translation is provably stale (we forced `.began` from a delegate, the
recognizer didn't reset). Touch is unaffected.

## 8. Remaining deferred follow-up

- **Real-device trackpad validation.** All trackpad ground truth is from the Simulator (2026-05-25
  §11 sim-vs-device caveat); a real iPad may differ, and `isIndirectScroll` would need revisiting if
  the device delivers trackpad via synthesized touches.

## 9. Implementation order

1. `PhysicsScrollCore`: `coefficient` field + `updateRubberBandCoefficient` + thread into
   `makePhysics`.
2. `PhysicsScrollEngine`: set the coefficient at `handlePan(.began)`; add the `shouldReceive(event:)`
   delegate + `catchMotionForFingerRest()` helper.
3. `PhysicsScrollCoreTests`: trackpad-coefficient overscroll test.
4. Build + full suite (iPhone 17 sim, `-parallel-testing-enabled NO`); confirm additive (green).
5. On-device trackpad manual check (the gesture-layer parts the harness can't reach).
6. Update CLAUDE.md (Architecture "scroll-engine seam" + roadmap status: 4b ✅, next is 4c).
