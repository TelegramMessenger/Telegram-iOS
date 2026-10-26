# Keyframe deceleration during virtualization (increment 4a) — design

**Date:** 2026-05-26
**Status:** IMPLEMENTED / CURRENT

## Goal

Give `PhysicsScrollEngine` a `.keyframe` deceleration mode (alongside the existing `.stepped`) so the
list's post-release flick/bounce is a **precomputed render-server `CAKeyframeAnimation`** instead of a
per-frame main-thread integration — the literal north star of the whole `UIScrollView`→`ScrollPhysics`
migration. The payoff: while the list is decelerating, the content keeps moving smoothly **even when
the main thread is busy loading/laying out rows**, because the render server plays the baked path and a
time-indexed sampling link only *reports* the live offset (a dropped tick self-corrects).

The keyframe path itself was already built and validated in `PhysicsScrollView`: the `Trajectory`
value type, the additive baked animation, the layer-local-time sampler, catch/finalize, and the
generation guard. This increment wires
that path into the **virtualizing** engine, whose one new problem `PhysicsScrollView` never had is that
the list **re-bases its scroll coordinate mid-flight** (every rebalance that repositions the container
or discovers a real edge). The resolution is **rebake-on-change with a seamless splice** (§3).

This is increment 4a of the migration. See `2026-05-26-physics-scroll-engine-design.md`
(increment 2) for the engine and its "Forward-compatibility" section, which prescribed the
rebake-on-change discipline this spec realizes. The prior increment established the clampless base-0
coordinate the physics runs in; that completed plan remains available in Git history.

## Scope

**In:** `.keyframe` mode on `PhysicsScrollEngine` (Option A coordinate, §2); the seamless
rebake/splice on a coordinate-changing rebalance (§3); redefining the `handleUserScroll` delta-clamp so
it no longer kills the flight (§4); view-removal-mid-flight teardown (§4); a deterministic
`TestScrollEngine` `.keyframe` sampling mode + `PhysicsListFixture` rebake tests (§5); the demo toggle.
`.stepped` stays the default and is untouched; the 402 existing tests stay green (additive).

**Out (named so they don't creep in):**
- **`applyChanges` *during* a keyframe decel** — composing the render-server flight with concurrent
  list mutation animation. This is **increment 4c**, handled separately from this design.
- **Trackpad on the list engine** — the recognizer-coefficient + finger-rest-catch port from
  `PhysicsScrollView`. **Increment 4b**, a small independent spec (works against `.stepped` too).
- Changing any physics constant/formula; the X-axis; `.keyframe` as the *validated default* (it stays
  a selectable mode, like the demo toggle).

## Background: the two paths, side by side

`.stepped` (today's `PhysicsScrollEngine`): a `CADisplayLink` calls `core.step(dtMs:)` each frame →
writes `contentHost.bounds.origin.y = physics.y.offset` → fires `onScroll` → `handleUserScroll` →
`rebalanceActiveWindow` (loads/unloads rows; `applyShift`s the offset by the container delta, which
`physics.shift`s so position is preserved; `setEdges` when a real edge appears). The main thread *moves*
the content.

`.keyframe`: the render server moves the content. On release with `.decelerate`, bake the whole path
(`Trajectory.build(from: physics.y)`), snap the model to `finalOffset`, add the additive keyframe
animation, and start a **sampling** link that each frame reads `traj.offset(at: localT)` and fires
`onScroll` — so `rebalanceActiveWindow` runs *identically*. The only inversion: the offset is now the
trajectory, not a value the main thread writes (the `engine.offset` getter returns the live sample
during a flight — the abstract-current-position contract increment 2 committed to).

## 1. Architecture & lifecycle

The flight machinery lives in **`PhysicsScrollEngine`** (the production driver that owns the display
link and the layer), mirroring `PhysicsScrollView`. `PhysicsScrollCore` stays the physics owner
(`ScrollAxis` + `setBounds`/`shift` + the open-edge sentinel). `Trajectory`, `positionKeyframeAnimation`
(generalized to animate `bounds.origin.y` — §2), `localTime(of:)`, the generation guard, and the
idempotent dual-finalize are reused.

```
release (.decelerate) → launchFlight: model bounds.origin.y := finalOffset; add baked anim; start SAMPLING link
sampling tick → localT := now − flightStart; offset := traj.offset(at: localT); onScroll(offset)
                  → handleUserScroll → rebalanceActiveWindow
                       ├─ no coordinate change → return (render server keeps playing the baked path)
                       └─ applyShift'd / setEdges'd → rebakeWithSplice (§3)
                  if localT ≥ duration → finalizeFlight
CA completion (generation-guarded) → finalizeFlight        // dual trigger; finalizeFlight idempotent
touch-down / .began / view removal → catchFlight (snap model to live, remove anim) — §4
```

`engine.offset` during a flight returns `traj.offset(at: localT)` (not the model). `.stepped` is
unchanged: `engine.offset` is `bounds.origin.y` and `step` drives the loop.

## 2. Coordinate: animate `contentHost.bounds.origin.y` (Option A)

`PhysicsScrollEngine`'s contract is `offset == contentHost.bounds.origin.y` — the list's `absoluteBase`
math (`containerOriginY − window.minY`), container positioning, and exit-snapshot parenting all depend
on it. So the keyframe animation animates the **same property `.stepped` writes every frame**: the
host's `bounds.origin.y`. Only the *writer* changes (render server vs. main thread); the engine's
coordinate contract is untouched, and a bounds scroll moves `container` + exit snapshots together
exactly as `.stepped` does.

**Sign (derived):** `bounds.origin.y` increases *with* scroll-down, so — unlike `PhysicsScrollView`'s
`position.y`, which moves opposite the offset and is negated — the additive values are **not** negated:

- model `contentHost.bounds.origin.y := finalOffset` (set synchronously at launch);
- additive value at sample `i`: rendered = model + value, and we want rendered = `offset(tᵢ)`, so
  `value(tᵢ) = offset(tᵢ) − finalOffset`, ending at 0 at settle.

`positionKeyframeAnimation` is generalized to take the keyPath + value convention (or a sibling
`boundsOriginKeyframeAnimation(beginTime:)` is added); `PhysicsScrollView`'s `position.y` call is
unchanged.

**Plan-time verification (load-bearing):** confirm an **additive** `CAKeyframeAnimation` on keyPath
`"bounds.origin.y"` composes as expected on the host layer (additive position.y is well-trodden;
additive bounds.origin.y is less common). **Fallback** if additive-on-bounds misbehaves: a
**non-additive** keyframe with absolute `values = offset(tᵢ)` on `"bounds.origin.y"` (the model is then
inert during the flight; robustness against a stray model write is lost but the list never rewrites the
host's `bounds.origin.y` mid-flight anyway). Either way the screen-space continuity oracle (§5) pins it.

## 3. Rebake-on-change with the seamless splice

A sampling tick's `onScroll` makes the list rebalance. When that rebalance **changes the coordinate** —
`applyShift(dy)` (container repositioned; `|dy| > 0.5`) or `setEdges` changing a bounce edge — the baked
future is now wrong (it was computed under the old coordinate/edges) and must be rebaked. A *naive*
rebake (`beginTime = now`, `t=0 = sampled-live-offset`) injects a per-rebake seam: the live offset is
sampled on the main thread at `now` but the replacement animation isn't composited until ≈one frame
later, so the render server jumps by ≈`velocity·δ` each rebake, and over a fast flick (rows load often →
many rebakes) those accumulate into visible jitter.

**The fix — anchor the new animation in the past and replay the current animation's already-rendered
keyframes up to `now`:**

1. `localT = now − currentBeginTime`; read `liveOffset = current.offset(at: localT)`,
   `liveVel = current.velocity(at: localT)` (layer-local `now`).
2. Apply the new conditions to the physics via the existing stepped primitives: `core.applyShift(dy)`
   and/or `core.setEdges(...)` → `physics.y.offset` becomes the re-based live offset under the new edges.
3. **Bake the future:** `future = Trajectory.build(from: physics.y)` — its `t=0` sample is the re-based
   live offset; the path continues under the new conditions.
4. **Splice (pure `Trajectory` function):** produce `(spliced, newBeginTime)` where
   - `newBeginTime = max(currentBeginTime, now − historyWindow)` with `historyWindow = 1.0 s`;
   - samples for `t ∈ [newBeginTime, now]` are **copied frame-aligned from `current`** (same 1/120
     grid), **re-expressed into the new coordinate** (offset += the re-base `shift`, so the additive
     base is the new `finalOffset`);
   - samples for `t ∈ [now, …]` are `future`, joined at `now` where offset *and* velocity already match
     (the future was built from the live sample);
   - times are rebased so `spliced` is sampled as `offset(at: localTime − newBeginTime)`.
5. `removeAnimation` (old) → set model `bounds.origin.y := spliced.finalOffset` → `add` the spliced
   animation with `beginTime = newBeginTime` → bump generation → the sampling link keeps running.

**Why it is seamless.** CA never re-renders the deep past; the carried history's only job is to make the
animation's value+slope *entering* `now` identical to what was on screen, so the swap has nothing to be
discontinuous about. The offset coordinate *does* step by `shift` at the re-base, but `applyShift` moved
the container in lockstep (the same mechanism `.stepped` relies on), so **screen position is
continuous**. The `historyWindow` cap bounds the carried keyframe count; `max(currentBeginTime, …)`
never reaches before the flight began. Because most ticks make no coordinate change, most ticks don't
rebake — the baked path just plays.

**Frequency note (not in scope to optimize):** the splice makes rebake *frequency* correctness-neutral,
so 4a rebakes on every coordinate-changing rebalance. A later optimization could suppress free-scroll
re-bases on the keyframe path (the engine is clampless since increment 3, so the container need not
re-centre mid-flight — only real-edge appearance would rebake), shrinking rebakes to the rare top/bottom
approach. Out of scope here; noted so the splice isn't mistaken for the only lever.

## 4. Carried-forward hazards

- **Delta-clamp redefinition (CLAUDE.md's flagged increment-4 item).** `handleUserScroll`'s
  one-viewport delta clamp calls `engine.setOffset`, which in `.stepped` is fine but in `.keyframe`
  currently *stops* the flight (its `stopDisplayLink`). In `.keyframe`, `setOffset` during a live flight
  becomes a **catch-and-rebake**: snap the model to the live sample, `shift` the physics to the clamped
  offset, rebake+splice — never a hard stop. (Unreachable at realistic flick speeds — ~48 000 pt/s — but
  the keyframe path must *define* it rather than silently kill the flight.)
- **View-removal mid-flight (deferred from the keyframe doc → required here).** A runloop-retained
  sampling `CADisplayLink` (strong `target: self`) strands the engine/host if the list view leaves the
  window mid-flight. `PhysicsScrollEngine` must catch the flight + stop the link on
  `tearDown`/host removal (the engine already has `tearDown`; extend it to `catchFlight` first). The list
  wires it from `willMove(toWindow: nil)`/`removeFromSuperview` if the engine isn't otherwise torn down.

## 5. Testing

The risky logic is **pure and clock-driven**, so it is deterministic; only the CA playback is
render-server.

- **`TrajectorySpliceTests` (pure, no UIKit):** `newBeginTime = max(prevBegin, now−1.0)`; carried
  history equals the source vertices frame-aligned; the `+shift` coordinate re-expression; **offset and
  velocity continuity at the splice point**; the 1 s history cap bounds sample count; a rebake with
  `shift = 0` (pure edge-change) and with `shift ≠ 0` (re-base).
- **Deterministic end-to-end rebake (the high-value test).** Give `TestScrollEngine` a `.keyframe`
  sampling mode driven by the **`SyntheticClock`**: each `tick` computes `localT` from the synthetic
  clock, reads `traj.offset(at: localT)`, fires `onScroll`, and runs the **same** splice-rebake on a
  coordinate-changing rebalance — no CA, no real display link. Then `PhysicsListFixture` drives flick →
  free-travel → progressive rebalance-with-rebake → top/bottom-edge bounce and asserts
  `assertContiguousEveryFrame`, **screen-space no-jump across each rebake** (the `Trace` already composes
  the container presentation translation in `soundedForContainerSlide`; the keyframe analogue adds the
  animated `bounds.origin.y` presentation), and settle. This exercises the real rebake logic, not a
  reimplementation.
- **Parity:** the `.keyframe` synthetic engine and the `.stepped` engine, driven by the same flick,
  settle at the same window/offset within ≤1–2 px (same culture as the replica validation).
- **CA glue** (`add`/`remove`, the sampling link, finalize, the additive-bounds verification) stays thin
  → smoke + the frozen-layer (`speed = 0`) local-time read, per the keyframe doc's philosophy.
- **The 402 existing tests stay green** (additive; `.stepped` default and untouched).

## Edge cases

- **Degenerate trajectory** (`< 2` samples / `duration == 0`): snap to `finalOffset`, settle, no
  animation — the existing `launchFlight` guard.
- **A release with nothing left to play** (added 2026-08-11, with the UIScrollView release hand-off):
  `launchFlight` integrates one hand-off frame *before* the bake, and that frame can END the
  deceleration it was handed — so the `release (.decelerate) → launchFlight` arrow above is not
  enough to guarantee the `.decelerating` state `KeyframeFlight` asserts on. Two releases reach it
  with no motion: a low-pass blend that CANCELS (the decelerate threshold reads the raw latest
  sample, the 0.75/0.25 blend runs after it), and an overscrolled release already inside
  `Deceleration.settleTolerance` — which is an everyday gesture, because the pixel-rounded spring
  rest puts EVERY bounce exactly 1/3 pt outside the edge on a 3× device, so the next tap or slow
  release springs back from there. `launchFlight` re-checks `core.isDecelerating` after the hand-off
  and takes the same settle path as the degenerate case. `.stepped` absorbs both in its first link
  callback; `TestScrollEngine` applies no hand-off and so cannot see either.
- **Stale completion / catch during a rebake:** the generation guard + idempotent `finalizeFlight`
  already cover sampler-first / completion-first / catch-bumps-generation, exactly as in
  `PhysicsScrollView`; the splice bumps generation like a relaunch.
- **Rebake when the new edge makes the trajectory a spring-back** (a flick that crosses a freshly-loaded
  bottom edge): `Trajectory.build` from the post-`setBounds` axis already bakes the bounce — no special
  case (the bottom-edge integration test from increment 2 is the precedent).
- **Re-base larger than one viewport in a single tick:** can't happen — the sampler ticks per frame and
  `rebalanceActiveWindow` prepends/appends incrementally; if a future fast-path violates it, the §4
  delta-clamp catch-and-rebake covers it.

## Risks

- **Additive `bounds.origin.y`** (§2) — verified at plan time with a non-additive-absolute fallback.
- **Splice coordinate algebra** (the `+shift` re-expression) — the screen-space no-jump oracle (§5) is
  the pin; get it wrong and the test fails with an exact `shift`-sized jump at the rebake frame.
- **Rebake cost under a fast flick** — main-thread `build` + CA swap per coordinate-changing rebalance.
  Acceptable for 4a (between rebakes the render server is smooth, which is the whole point); the
  free-scroll-rebase-suppression optimization (§3) is the lever if it ever matters.

## Natural next increments (not part of this spec)

- **4b — Trackpad on the list engine:** port `PhysicsScrollView`'s `allowedScrollTypesMask`/`0.715`
  indirect coefficient + `shouldReceive(event:)` finger-rest catch to `PhysicsScrollEngine` (the
  `.began` flight-catch from this spec is its prerequisite for catching a keyframe flight on finger-rest).
- **4c — `applyChanges` during a keyframe decel:** the render-server flight composed with list
  mutation animation.

## Post-implementation notes

Landed across eight tasks (subagent-driven, two-stage review per task): `ScrollAxis.reseedDeceleration`
→ `Trajectory.spliced` + `boundsOriginKeyframeAnimation` → `PhysicsScrollCore.bakeTrajectory`/
`reseedDeceleration` → `KeyframeFlight` (the shared orchestrator) → `TestScrollEngine` `.keyframe` →
`PhysicsScrollEngine` `.keyframe` → `PhysicsListFixture` keyframe + integration tests → demo + docs.
Final state: **all 422 tests green**; `.stepped` stayed the default and the 419-test additivity oracle
held throughout. Findings worth carrying forward:

- **Additive `bounds.origin.y` (§2) held — no fallback needed.** The non-negated additive keyframe on
  `bounds.origin.y` composes correctly; the non-additive-absolute fallback was not required.
- **Continuity is algebraically exact (§3), not approximate.** The splice appends the splice-point
  vertex at `now` as `current.offset(at: localNow) + shift`, which equals the pre-rebake `liveOffset`
  by construction — so the swap has no value to be discontinuous about; the integration screen-no-jump
  oracle passed at the spec bound (90 pt) with no adjustment, and a 4000 pt/s flick exercises ~35
  rebalances/rebakes. Velocity is shift-invariant and continuous across the rebake (a `KeyframeFlight`
  unit test pins it).
- **`accumulatedShift` is load-bearing** (the keyframe analogue of `.stepped`'s `writeOffset`): without
  it, `handleUserScroll`'s `previousOffset`/delta would see a spurious shift-sized delta the tick after
  a re-base. Reset in both `beginTick` and `rebakeIfNeeded`; folded into the rebaked trajectory.
- **Review-hardened beyond the core spec:** (1) `ScrollAxis.reseedDeceleration` / `PhysicsScrollCore`
  document that they set only the `step`/`build` substate (no `dragStartOffset` / host-bounds write —
  the caller snaps); (2) `KeyframeFlight` debug-asserts `core.isDecelerating` in `init`/`rebakeIfNeeded`
  (a tripwire for the per-tick protocol the two engines consume), and its `generation` is scoped to
  within-flight rebakes (cross-flight launch/catch staleness is the engine's `flightGeneration`);
  (3) `TestScrollEngine.beginDrag` now catches a live flight (snap to live + null) — without it a new
  gesture mid-flight stranded a stale flight; (4) `PhysicsScrollEngine`'s degenerate-launch branch
  idles the core, and the re-entrant-catch-during-`onScroll` orphan is documented benign (the
  `reemitFlightAnimation` nil-guard no-ops it — no stray animation).
- **Delta-clamp (§4) resolved as a plain catch** (catch the flight, then `setOffset`) — the delta-clamp
  itself is unreachable at realistic flick speeds; a catch-and-rebake/relaunch was unnecessary.
- **Demo:** the Virtual List engine toggle is now 3-way (UIScrollView / Physics·step / Physics·keyframe)
  for live A/B.

Deferred by this design: trackpad on the list engine (4b); `applyChanges` during a keyframe
deceleration (4c); and the view-removal-mid-flight teardown is handled
engine-side (`tearDown` catches), but the *list* must call it on host removal (a 4b/4c wiring detail).
