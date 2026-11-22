# UIScrollView scroll physics — instruction-level analysis

**Status:** CURRENT REFERENCE

**Source:** UIKitCore (iOS 26.2, arm64e), reverse-engineered via Hopper (HopperMCPServer).
**Corrections dated 2026-08-10** come from a later, SYMBOL-BEARING UIKitCore image (ivar names such as
`_horizontalVelocity`, `_previousVerticalVelocity`, `_fastScrollMultiplier` are present), which is what
made the guarded low-pass and the fast-scroll mechanism visible at all. Addresses in those sections are
from that image and do not match the `0x1896…` addresses elsewhere in this document.
**Goal:** exact replication of UIScrollView's linear scroll physics in a standalone class to drive `CoreVirtualListView`.
**Method:** Hopper pseudo-code gives structure/control-flow, but its ARM64 decompiler **drops FP/SIMD math** (emits `brk` / bare `asm {}` blocks). All numeric formulas below are reconstructed from the **assembly** and presented as clean math. Argument semantics are verified from **call sites**, not the (misleading) private selector names.

Status legend: ✅ exact (decoded from asm) · 🟡 partial · ⬜ not yet done.

---

## 0. Foundational model

- **`contentOffset` IS the scroll view's `bounds.origin`.** `setContentOffset:` pixel-rounds (`_roundedProposedContentOffset:`), early-outs if unchanged (epsilon compare ~2.2e-16), then `setBounds:` (origin = offset) — which shifts every subview — then `_notifyDidScroll` → delegate `scrollViewDidScroll:`, plus indicator/accessory/layout-guide updates. ✅ (structure; rounding/clamp math ⬜ §6)
- All motion is per-axis and symmetric; X and Y run the same code with different ivar offsets.
- Coordinate convention below: `min`/`max` are the clamped offset bounds for the axis, `range` is the visible bounds dimension (used as the rubber-band asymptote scale).

---

## 1. Rubber-band (overscroll) ✅

From `__UIScrollViewRubberBandOffsetWithoutDecorationForOffset` (the math behind `-[UIScrollView _rubberBandOffsetForOffset:maxOffset:minOffset:range:outside:]`).

```
clampedMax = max(maxOffset, minOffset)            // maxOffset forced >= minOffset
if |range| < ~2.2e-16:            return offset    // guard /0
if minOffset <= offset <= clampedMax: return offset
else if offset > clampedMax:                       // past bottom/right
    d = offset - clampedMax
    return clampedMax + range·(1 - 1/(1 + c·d/range))
else: // offset < minOffset                        // past top/left
    d = minOffset - offset
    return minOffset - range·(1 - 1/(1 + c·d/range))
// out-param `outside` (BOOL*) set YES whenever a rubber-band branch is taken
```

- **Coefficient `c`** (`__UIScrollViewRubberBandCoefficient`): default **0.55**; style-index variants 0.715, 0.5, 0.4, 0.17; gamepad path uses a separate limit %. ✅
- This is the canonical `(1 − 1/(x·c/d + 1))·d` form.

**2-D wrapper** `_rubberBandContentOffsetForOffset:outsideX:outsideY:` ✅ — calls the 1-D formula per axis with `min`/`max` from §6 and `range` = the bounds dimension (`bounds.size`), applies the §6 screen-scale pixel rounding, and honors `alwaysBounceHorizontal/Vertical`.

---

## 2. Deceleration ✅

The per-frame driver `_smoothScrollSyncWithUpdateTime:` runs on a `CADisplayLink`. Each tick, per axis:

```
dt_ms = (now − lastUpdateTime) × 1000        // time integrated in MILLISECONDS
if dt_ms < 1.0: return                        // sub-ms frames skipped
```

It dispatches to one of **three** variants by flags:
- `_getBouncingDecelerationOffset:…`  — bounce enabled (decoded below)
- `_getStandardDecelerationOffset:…`  — bounce disabled ⬜ (expected: same free-decel, hard clamp at min/max)
- `_getPagingDecelerationOffset:…`    — paging ⬜

### Velocity / offset units
`velocity` is stored in **points per millisecond** (gesture velocity in pts/sec is divided by 1000 at capture). With that, `rate·(1−rate^dt)/(1−rate) ≈ dt`, so `Δx ≈ velocity·dt` as expected.

### `_getBouncingDecelerationOffset` — verified signature
Selector param names are misleading; from the call-site register setup in `_smoothScrollSyncWithUpdateTime:` (`0x1896d63dc` / `0x1896d6630`):

```
// "…DecelerationOffset:" param = dt_ms ; "forTimeInterval:" param = currentOffset
BOOL bouncingDecel(double dt_ms, double currentOffset, double *runningOffset /*in-out*/,
                   double min, double max, double rate, double lnRate /* = ln(rate) */,
                   double *velocity /*in-out*/)
//   rate     = decelerationFactor  (0.998 normal / 0.99 fast), per-ms
//   vScale   = _fastScrollMultiplier ivar (default 1.0), multiplies the per-frame distance
//              — NOT _velocityScaleFactor, which is a distinct ivar this function never reads
//              (corrected 2026-08-10: read at 0x17a85f8 and 0x17a86a4, both `_fastScrollMultiplier`)
//   returns  finished? (YES → driver calls _stopScrollingNotify:pin:)
```

Regime selected by whether `currentOffset ∈ [min, max]`:

**(A) IN-BOUNDS — free deceleration**
```
if velocity == 0 or NaN: goto SETTLE
decay = rate^dt_ms                       // = exp(dt_ms·lnRate); 2-term Taylor x·(0.5x+1)+1 when |dt_ms·lnRate| < 0.5
Δx    = velocity · rate · (1 − decay)/(1 − rate) · vScale
newOffset = *runningOffset + Δx
if newOffset still within [min,max]:
    *runningOffset = newOffset
    velocity      *= decay
    // (consumed all dt_ms → done this frame)
else:                                    // crosses an edge mid-frame
    edge          = crossed bound (min or max)
    timeToBound   = dt_ms · (edge − currentOffset)/(newOffset − currentOffset)
    remainingTime = dt_ms − timeToBound
    // integrate free-decel only up to the edge:
    decay'        = rate^timeToBound
    *runningOffset = currentOffset + velocity·rate·(1−decay')/(1−rate)·vScale   // == edge
    velocity      *= decay'
    // then fall through to spring with remainingTime
```

**(B) OUT-OF-BOUNDS / mid-frame remainder — spring return** (`remainingTime` = sub-frame time past edge)

> **The spring term carries NO `vScale`** (corrected 2026-08-10, `0x17a8784`). Only the free-deceleration
> distance (`0x17a85f8`) and its to-the-edge sub-step (`0x17a86a4`) are multiplied. Invisible while the
> multiplier is 1.0, which is why the original pass recorded it on both.
```
edge     = (offset < min) ? min : max
springK  = exp(remainingTime · ln(0.99))   // bounce stiffness = FIXED 0.99/ms, independent of decelerationRate
decayRem = rate^remainingTime
// (one flag path clamps velocity to [−3,+3] first)
offset = edge + springK·(offset − edge)
       += velocity · rate · springK · (1 − decayRem)/(1 − rate) · vScale
velocity *= decayRem · springK
```
`ln(0.99) = −0.01005…` — the `-0.01005` constant in the binary is exactly `ln(0.99)`.

**Reaching the spring, or settling, resets the fast-scroll streak** (`0x17a87bc`, `0x17a8844`):
`_fastScrollCount = 0`, `_fastScrollMultiplier = 1.0`. Every deceleration ends in one of the two, so the
multiplier only ever survives into a gesture that begins BEFORE the previous flight finished.

**SETTLE test**
```
snapped = round(offset to 1/scale)         // pixel snap
if snapped within 0.5 px of the bound (and velocity negligible):
    return YES        // finished → driver stops the timer
return NO             // keep ticking
```

### Driver post-step (`_smoothScrollSyncWithUpdateTime:`)
After computing the new offset/velocity it writes them back, then `setContentOffset:` (→ bounds.origin), and if `finished` calls `_stopScrollingNotify:pin:`. Also tracks rubber-banding statistics and a velocity low-pass for telemetry. The per-axis bound `min`/`max` passed in are `_minimumContentOffset` / `_maximumContentOffset` adjusted for revealable content padding (`_maxTopOffsetAdjustedForRevealableContentPadding:`).

> **Decel hand-off: the first step is exactly one frame (resolved 2026-05-24).** `_endPanNormal` sets the decel `lastUpdateTime = CACurrentMediaTime − 1/maxFPS` and then calls `_smoothScrollWithUpdateTime:(now)` synchronously — so the **first deceleration step integrates exactly one display frame (`1/maxFPS`), regardless of the actual release-to-first-callback gap.** That step decays the hand-off velocity by `rate^(1/maxFPS)` (≈ `0.998^16.67 = 0.967` at 60Hz) before the bulk of the decel. Omitting it (integrating the raw blend velocity from frame 0) overshoots the landing by ~3% (≈67px on a medium flick). The hand-off velocity itself is the §4 blend `0.75·prev + 0.25·latest` of the per-frame `velocityInView`; `vScale` (`ivar 0x1ea7983c4`, the decel velocity-term multiplier) is set to **1.0** on the normal path. Confirmed end-to-end: replaying drag → release → free-decel → edge bounce → spring-back lands within **≤2.6px** of the recorded real trajectory with no alignment shims.

> **Validation (Plan 2 fixture regression).** With the artifacts isolated, every component matches the real `UIScrollView`: rubber-band exact (maxErr 0), flick **landing** ≤1px, free-deceleration + spring/bounce **trajectory** ≤3px (frame-aligned), spring-back from a deep overscroll ≤1px (seeded from the real release offset to remove the deep-overscroll drag-reconstruction skew). The **velocity clamp to ±3 pts/ms** in the spring path (`fminnm 3` / `fmaxnm −3`, flag-gated) is **not** applied for a free flick into the edge — adding it unconditionally *increased* divergence — so it is gated to a mode the canonical flicks don't hit; it is intentionally omitted from the replica.

---

## 3. Live-drag path ✅
`handlePan:` is a state dispatcher: **Began** → `_resetScrollingWithUIEvent:`, zero all four velocity
ivars, **then `_updatePanGesture` immediately**; **Changed** → `_updatePanGesture` (the drag math);
**Ended/Cancelled** → `_prepareToPage…` + `_endPanNormal:` (§4).

> **Corrected 2026-08-10 (`0x17a1718`).** The original entry omitted that case 1 falls straight into
> `_updatePanGesture`, so **`.began` contributes a full velocity sample and applies its own
> translation** — it is a drag callback, not merely a state transition. It also mis-attributed the
> zeroing: `_resetScrollingWithUIEvent:` (`0x17b11ec`) records `_startOffsetX`/`_startOffsetY` and
> touches no velocity state at all; the zeroing lives in `handlePan:` case 1 and in
> `_beginTrackingWithEvent:` (`0x17b12e4`, previous pair only).
>
> This was the whole of the CoreList short-flick defect: an engine that treats `.began` as setup only
> runs a gesture one sample behind UIKit, and a flick with one `.changed` releases at `0.25·v` instead
> of `0.75·v₀ + 0.25·v₁`.

`_updatePanGesture` per drag-Changed (asm `0x189675a78`–`0x189675d18`):
```
1. translation = [panGR translationInView:self]          // taken at float (32-bit) precision (fcvt round-trip)
2. startOffset = ivars 0x1ea798470/474                    // content offset captured at drag begin (anchor)
3. proposedOffset = startOffset − translation             // content moves opposite the finger

4. // velocity, in points/MILLISECOND (the documented delegate unit), per axis:
   prevVelocity = velocity                                // 0x4c0→0x4c4, 0x4c8→0x4cc (saved for the §4 release filter)
   velocity     = −[panGR velocityInView:self] × 0.001    // 0x4c0/0x4c8 ; pts/s→pts/ms (×0.001), negated

5. (optional) delegate _scrollView:adjustedUnconstrainedOffsetForUnconstrainedOffset:…   // if a scroll observer exists
6. if _allowsBounce:  offset = _rubberBandContentOffsetForOffset(proposedOffset)   // §1, applied per axis
   else:              offset = _clampScrollOffsetToBounds(proposedOffset)          // hard clamp to [min,max]
7. [panGR setTranslation:inView:]                          // reconcile recognizer translation with the constrained offset
8. setContentOffset:(offset)                               // → bounds.origin (§0/§6)
```
- The `−×0.001` is the exact pts/s→pts/ms conversion (`S` = unnamed ivar `0x1ea798450`; value pinned by the public delegate contract "velocity in points per millisecond" + `velocityInView:` being pts/s). `velocityInView:` here is also reused for the discrete/threshold logic in §4.
- 2-D `_rubberBandContentOffsetForOffset:outsideX:outsideY:` = the §1 1-D formula per axis, fed `min`/`max` (§6) and `range` = bounds dimension, with the §6 pixel-rounding; honors `alwaysBounceHorizontal/Vertical`.

## 4. Velocity capture + release thresholds ✅
From `_endPanNormal:` assembly (exact).

**Low-pass filter** (`0xa498`–`0xa4d0`; `0x179f94c` in the symbol-bearing image), per axis — and
**GUARDED**: it runs only if at least one of the two PREVIOUS-axis velocities is non-zero.
```
if (previousHorizontalVelocity != 0 || previousVerticalVelocity != 0) {     // corrected 2026-08-10
releaseVelocity = 0.75·prevFrameVel + 0.25·latestFrameVel   // 0.75 = 0x3fe8…, 0.25 = 0x3fd0…
// prevFrameVel   = ivar 0x1ea7984c4 (the PRIOR drag frame's velocity, saved each frame — §3), weight 0.75
// latestFrameVel = ivar 0x1ea7984c0 (the most-recent drag frame's velocity), weight 0.25
//   → result stored to 0x1ea7984c0 = what projection (§5) and deceleration (§2) read
}   // else: the RAW latest velocity is released, unblended
```
> **The guard fires for a gesture that reached release with no `.changed` event.** `handlePan:` case 1
> zeroes both pairs and then takes one sample, so `previous` is still zero at that point — such a flick
> is released at full strength rather than at a quarter.
> ✅ **Resolved (Plan 2 fixture regression):** the **0.75** weight lands on `0x4c4` (the **previous** drag-frame velocity), 0.25 on `0x4c0` (the latest) — i.e. `releaseVelocity = 0.75·previous + 0.25·latest`. Confirmed empirically: the `medium-flick` fixture's free-deceleration **lands within ~1px** of the real `UIScrollView` with this weighting, vs a **~23px** undershoot when reversed. The `ScrollPhysics` replication core uses this weighting.
>
> ⚠️ **Corrected 2026-08-10.** This paragraph used to end "the two agree when `prevVelocity == 0`",
> which is false — they give `0.25·v` and `0.75·v`. What actually happens at `prevVelocity == 0` is
> that the guard above skips the blend entirely and the raw latest velocity is released.

**Threshold tiers** on `|v|²` (pts/ms; `0xa20c`–`0xa224`, `0xa798`; `0x179f6d8` in the symbol-bearing
image). **Corrected 2026-08-10:** the magnitude tested is `vx² + vy²` — a single 2-D quantity, not a
per-axis one — and it is evaluated on the **RAW latest** sample, BEFORE the low-pass above
(`0x179f6d8` precedes `0x179f94c` in control flow; the decelerate branch at `0x179fc7c` returns to the
shared tail that reaches the blend). Below the floor, all four velocity ivars are zeroed and there is
no deceleration at all.
| `|v|²` | `|v|` | behavior |
|---|---|---|
| < 0.0625 | < 0.25 pts/ms (250 pts/s) | **no deceleration** — velocity zeroed, snap/settle only |
| 0.0625 … 0.36 | 0.25 … 0.6 pts/ms | decelerate; reset consecutive-flick counter |
| ≥ 0.36 | ≥ 0.6 pts/ms | decelerate **and** increment `_fastScrollCount`, stamping `_fastScrollEndTime` — see "Repeated-flick acceleration" below |
(gamepad idiom == 6 bypasses the magnitude tiers. UIKit also skips the increment when `pagingEnabled`
is set, `0x179fcb8`.)

Also at `0x179f5e0`, before the tiers: UIKit **re-reads** `[pan velocityInView:self]` rather than trusting
the stored ivar, and zeroes both stored velocities if that fresh read is exactly `CGPointZero`.

### Repeated-flick acceleration ✅ (decoded 2026-08-10)

`_fastScrollMultiplier` is the §2 `vScale`. It is not a bare counter — it is a full mechanism:

**Growth**, in `_updatePanGesture` once `_fastScrollCount >= 3` (`0x179d8d4`–`0x179d94c`):
```
dist       = sqrt_float(dx² + dy²)          // cumulative drag translation; 32-bit sqrt at 0x179d904
multiplier = min(_fastScrollStartMultiplier
                 + (1 + (_fastScrollCount − 3)/2) · min(dist / 240.0, 0.9),
                 16.0)
```
The single-precision `sqrt` is real: the touch path does `fcvt s0` / `fsqrt s0` / `fcvt d0`, while the
discrete/trackpad path calls double `hypot` (`0x179db30`). The `240.0` divisor is hard-coded on the touch
path and preference-driven (`DiscreteFastScrollDistanceScale`, default `240.0`) on the discrete one.

**Four reset sites:**
- **Touch-down** — `_beginTrackingWithEvent:` (`0x17b1470`–`0x17b14d0`): if
  `event.timestamp > _fastScrollEndTime + 1.0` then `_fastScrollMultiplier = 1.0`,
  `_fastScrollCount = 0`; then `_fastScrollStartMultiplier = _fastScrollMultiplier`. The stamp is made
  at RELEASE, so the timeout means "one second since you last let go". Gated by `_scrollViewFlags` bit
  23 (`0x17b146c`), the same "this was a real drag with velocity" bit that gates the whole velocity
  block in `_endPanNormal` (`0x179f4f8`).
- **During the drag** — `_updatePanGesture` (`0x179d5d8`–`0x179d628`): a direction reversal on the
  scrolling axis, or `vx² + vy² < 0.0169` (|v| < 0.13 pts/ms). The recorded signs live in
  `_scrollViewFlags` bits 10 (horizontal, writer `0x179d674`) and 11 (vertical, writer `0x179d6a0`);
  the touch path's reversal test reads bit 11. Both reader and writer are guarded on the sample being
  non-zero.
- **At release** — the `< 0.36` tier above.
- **Inside the integrator** — §2's spring/settle resets.

**Discrete / paging flick** (`0xa30c`–`0xa3a0`): velocity component is clamped to **[−3, +3]** (`fcsel` vs 3.0 / `fmaxnm` vs −3.0) then scaled by **−0.66** (`double_value_minus_0_66`). Applies to trackpad/discrete (`flags & 0x2800 == 0x800`) and paging direction codes.

**Handoff / kickoff** (`0xa614`, `0xa634`): `_scrollViewWillEndDraggingWithDeceleration:` (computes/clamps target, §5) → `_scrollViewDidEndDraggingForDelegateWithDeceleration:` → `_pushTrackingRunLoopModeIfNecessaryForReason:` + `_startTimer:1` → `CADisplayLink` → `_smoothScroll…` (§2). Also calls `_updateDecelerationLastOffsetScrollViewPoint:` at entry to seed the integrator's last offset.

## 5. Flick projection (targetContentOffset) ✅
From `_scrollViewWillEndDraggingWithDeceleration:` (inline, no helper). Verified from asm (target block at `0x1896d423c`–`0x1896d4278`).

It first caches `lnRate = log(decelerationRate)` per axis (`log` = stub `0x18d79d210`), then:

```
// v = filtered velocity ivar (pts/ms, set by _endPanNormal); vScale = _fastScrollMultiplier (1.0
// unless a repeated-flick streak is live — §4; read here at 0x179e95c, corrected 2026-08-10)
projectedDistance = sign(v) · (|v| − 0.01) / |lnRate| · vScale     // analytic integral of exp decay to the 0.01 cutoff
target            = contentOffset + projectedDistance
```

Exact, and it differs from the common WWDC form: UIKit divides by **`ln(rate)`**, not `rate/(1−rate)` (`1/|ln 0.998| = 499.5` vs `499`). The `−0.01` is a genuine **velocity floor of 0.01 pts/ms (10 pts/s)** — the projection integrates until speed decays to that cutoff, not to zero.

- The computed `target` is clamped, then handed to `_performScrollViewWillEndDraggingInvocationsWithVelocity:targetContentOffset:unclampedOriginalTarget:` → delegate `scrollViewWillEndDragging:withVelocity:targetContentOffset:` (delegate may overwrite).
- **Paging** (when enabled): snaps target to `pagingOrigin + round((target − pagingOrigin)/pageStride)·pageStride` (`pageStride` from bounds dim − `_interpageSpacing`, revealable-padding adjusted); asm `0x1896d4ae4`/`0x1896d4b18`.
- A separate `exp()` block (`0x18d79cf60`, asm `0x1896d4c24`/`0x1896d4c78`) caches a **predicted deceleration duration** per axis into ivar `0x1ea7984f8` (used by async-scroll coordination), clamped to ≈0.999.
- libm stubs identified by use: `0x18d79d210 = log`, `0x18d79cf60 = exp` (the `x·(0.5x+1)+1` fast-path is exp's 2-term Maclaurin for `x ≥ −0.5`).

## 6. Offset application + clamping ✅

**Bounds (per axis), exact:**
```
minOffset = (baseOrigin − effectiveContentInset.{left,top})  pixel-rounded     // _minimumContentOffset
maxOffset = max( minOffset,
                 (contentSize + effectiveContentInset.{right,bottom})ₚₓ − bounds.size )   // _maximumContentOffsetForContentSize:
```
i.e. the usual `contentSize − bounds + inset`, **floored at `minOffset`** so a content smaller than the viewport pins to `minOffset` (no scroll). `baseOrigin` (`_minimumContentOffset`'s ivar pair `0x1ea79844c`) is normally 0.

**Pixel rounding** (`_roundedProposedContentOffset:`, exact) — applied per axis:
```
scale = screen scale (ivar 0x1ea7983d0)
if (flags 0x1ea7983ac+0x10) & 0x30:  return offset            // bypass (e.g. zoom/mode)
if |scale| < ~2.2e-16:               return offset            // guard
if scale == 1:                       return round(offset)     // frinta = round to nearest (ties to even)
else:                                f = floor(offset);  return f + round((offset − f)·scale)/scale
```
This same `frintm`(floor)/`frinta`(round) idiom is what `_minimumContentOffset` / `_maximumContentOffset` / the rubber-band 2-D wrapper / the deceleration settle all use.

**Application** (`setContentOffset:`, §0): pixel-round → early-out if unchanged (epsilon ~2.2e-16) → `setBounds:` with `origin = offset` (scrolls subviews) → `_notifyDidScroll` → delegate `scrollViewDidScroll:`.

**Hard clamp** (`_clampScrollOffsetToBounds:`, no-bounce drag path): per axis `clamp(offset, minOffset, maxOffset)`.

---

## 7. Gesture recognizer: translation & velocity ✅ (decoded 2026-05-23)

The values `_endPanNormal`/`_updatePanGesture` consume — `translationInView` and `velocityInView` — are produced by `UIPanGestureRecognizer` from the **touch centroid** sampled per touch event. Decoded so we can reproduce the recognizer itself (driving from raw touches), not just record its outputs.

**Per touch-move** (`-[UIPanGestureRecognizer touchesMoved:withEvent:]`, `0x18966a1b0`): compute the centroid of active touches (`_centroidOfTouches:excludingEnded:`) and read `event.timestamp`, then call `_centroidMovedTo:atTime:affectingTranslation:`.

**`-[UIPanGestureRecognizer _centroidMovedTo:atTime:affectingTranslation:]`** (`0x18966a9e0`) — the core:
```
adjusted = _adjustSceneReferenceLocation(newCentroid)      // sub-pixel / scene adjust
dt = t − _lastTouchTime
if dt > 0:                                                 // build a velocity sample
    _previousVelocitySample = _velocitySample              // shift current → previous
    _velocitySample        = sample{ start = _refCentroid (prior event's adjusted centroid),
                                      end   = adjusted,
                                      dt    = dt }          // recycles the old prev object
if affectingTranslation:
    _refCentroid (ivar 0x120) = adjusted                   // translation reference advances
    _lastUnadjustedSceneReferenceLocation (0x124) = newCentroid
_lastTouchTime = t
```
So a **velocity sample is the per-event centroid finite difference**: `start → end` over `dt`. `translationInView` is the cumulative `currentCentroid − gestureStartCentroid` (the `_refCentroid` chain).

**Sample → velocity** (`_convertVelocitySample:fromSceneReferenceCoordinatesToView:`, `0x189677454`): `v = (convertToView(end) − convertToView(start)) / dt`. Returns `(0,0)` if `dt` ≤ a tiny epsilon.

**`velocityInView:`** (`0x189677a84`) — a **two-event weighted blend**:
```
v = W1 · currentSample.v
if previousSample exists AND previousSample.dt > ~1.2e-7 (2⁻²³):
    v += W2 · previousSample.v          // else just W1·current
```
`W1 = double@0x18addf340`, `W2 = double@0x18addae88` — **calibrated `W1 = 0.2` (current), `W2 = 0.8` (previous)**, a normalised blend summing to 1. Fit to **machine precision** (max residual ~2.7e-12 pts/s) from recorded touches on the scroll-uncontaminated X axis (`velocity = 0.2·current.v + 0.8·previous.v`; the first move, with no previous sample, is just `0.2·current`). The `UIScrollViewPanGestureRecognizer velocityInView:` override (`0x1896773c4`) just selects/forwards this tracked sample (axis flags), so the value we record via `panGR.velocity(in:)` **is** this blend.

> **Centroid coordinate gotcha.** Sample positions must be captured in a FIXED reference (window). `location(in: scrollView)` is contaminated by `bounds.origin` (= content offset), so the coordinate system scrolls under a moving finger and the finite-difference velocity doubles up finger + scroll on the scrolling axis. The X axis (no horizontal scroll) is unaffected — which is why it calibrated cleanly while Y didn't, until the recorder switched to `location(in: nil)`.

**Scroll-view override** `-[UIScrollViewPanGestureRecognizer _centroidMovedTo:atTime:affectingTranslation:]` (`0x189676d5c`): before calling super (which builds the sample above), it applies **directional lock** — the pan angle (`atan` of dy/dx) against `0.349066 rad` (20°) and `1.22173 rad` (70°) gates whether X / Y scrolling engages, writing a 2-bit lock state (flag byte `0x1ed6de268`). This is the X-lock we'd been excluding; reproducing it would let us model both axes.

---

## Constants recovered (exact)
| Constant | Value | Where |
|---|---|---|
| Rubber-band coefficient (default) | 0.55 | `__UIScrollViewRubberBandCoefficient` |
| Rubber-band variants | 0.715 / 0.5 / 0.4 / 0.17 | same (style index) |
| Deceleration rate (normal / fast) | 0.998 / 0.99 per **ms** | public + model |
| Bounce-back stiffness | 0.99 per ms (`ln 0.99 = −0.01005`) | `_getBouncingDecelerationOffset` spring |
| Velocity low-pass blend | 0.75 new / 0.25 prev | `_endPanNormal:` |
| Recognizer velocity blend (§7) | 0.2 current / 0.8 previous sample | `velocityInView` (calibrated) |
| Flick cancel threshold | \|v\|² < 0.0625 (≈ \|v\| < 0.25) | `_endPanNormal:` |
| Directional/discrete flick scale | −0.66 · clamp(v, −3, +3) | `_endPanNormal:` |
| Decelerate vs stop threshold | \|v\|² ≥ 0.0625 (\|v\| ≥ 0.25 pts/ms) | `_endPanNormal:` |
| Repeated-flick accel threshold | \|v\|² ≥ 0.36 (\|v\| ≥ 0.6 pts/ms) | `_endPanNormal:` |
| Settle tolerance | 0.5 px (pixel-snapped) | `_getBouncingDecelerationOffset` settle |
| Velocity floor (projection) | 0.01 pts/ms (10 pts/s) | `_scrollViewWillEndDraggingWithDeceleration:` |
| Projection divisor | `ln(rate)` (not `rate/(1−rate)`) | same |
| exp() fast-path | 2-term Taylor `x·(0.5x+1)+1` when `x ≥ −0.5` | all decel exp() sites |
| Velocity unit / capture | points/ms; ivar = `−velocityInView·0.001` | `_updatePanGesture` (§3) |
| Drag mapping | `offset = dragStartOffset − translation` | `_updatePanGesture` (§3) |

## Open questions / to verify
- §7 sample-validity `dt` thresholds (`0x18addf348`, `0x18addad40`) and pan `_hysteresis` value (validate via the Layer-1 PanRecognizer fit residual).
- `_getStandardDecelerationOffset` (no-bounce) — expected: free decel (§2-A) with a hard clamp at min/max instead of the spring; decode to confirm.
- `_getPagingDecelerationOffset` — paging deceleration; decode to confirm vs the §5 paging snap.
- `_prepareToPageWithHorizontalVelocity:verticalVelocity:` — page target selection at release (paging only).

## Resolved
- **The §2 `vScale` is `_fastScrollMultiplier`, not `_velocityScaleFactor`** (2026-08-10). The latter is
  a distinct stored double that none of the paths in this document read; the former is read inside
  `_getBouncingDecelerationOffset` (`0x17a85f8`) and by the §5 projection (`0x179e95c`), and is driven
  by the repeated-flick mechanism in §4.
- **The §4 low-pass is guarded** on the previous-axis pair being non-zero (2026-08-10, `0x179f94c`).
- **The §4 threshold is raw, pre-blend and 2-D** (2026-08-10, `0x179f6d8`).
- **`.began` is a drag callback** — `handlePan:` case 1 runs `_updatePanGesture` immediately (2026-08-10,
  `0x17a1718`), and `_resetScrollingWithUIEvent:` touches no velocity state (`0x17b11ec`).
- Velocity unit = **points/ms** (documented delegate contract); stored as `−velocityInView·0.001` (§3).
- Rubber-band `range` = bounds dimension (§1 wrapper).
- Pixel-rounding idiom (§6) and min/max bounds (§6) — exact.
