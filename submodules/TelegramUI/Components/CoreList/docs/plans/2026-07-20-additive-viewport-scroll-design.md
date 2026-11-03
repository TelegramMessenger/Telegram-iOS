# Additive viewport animation for programmatic scrolling

**Date:** 2026-07-20
**Status:** IMPLEMENTED / CURRENT
**Extends:** `2026-07-20-list-animation-model-design.md`

**Implementation record:** Task 1 geometry `25d63f8`; Task 2 model/controller/compiler/sampling
`0a4f337`; Task 3 overlap integration `cd05a17`; Task 4 carousel/mixed passes `e8ea87d`; Task 5
interruption/interaction lifecycle `b86e927`; Demo/documentation verification `5972200`; final
settled carry-owner pruning and regression coverage `e783719`.

**Final verification:** 67/67 focused viewport tests and 314/314 complete K2 tests passed; the Debug
build and log-driven Slow Animations Demo sequence succeeded. Final whole-range review found no
remaining Critical, Important, or Minor issues.

## Context

Before this implementation, the granular animation rewrite had deliberately retained the core list operations
while removing the old animation machinery. Item position, height, and opacity followed a small model-owned
property contract, but `scrollTo` had no general animation property. A nearby target could appear to move
through surviving row tracks; a distant target whose loaded window had no identities in common with the old
window appeared immediately. Consequently the Demo app's **Jump to 40** and **Top** controls did not animate.

The repository already contains the two relevant proven ingredients, but not one unified contract:

- the retired carousel placed the outgoing loaded window beside the destination and animated both strips;
- keyframe physics renders an analytic additive trajectory on `contentHost.layer.bounds.origin.y`.

This design makes programmatic scrolling a first-class property of `ListAnimationModel`. It retains the old
carousel geometry for non-overlapping windows, but gives both overlap and carousel transitions the same
analytic replacement, CA compilation, clock, generation, and no-op rules as item properties.

## Goals

1. Animate every changed, positive-duration `scrollTo` between non-empty windows with production
   `CAKeyframeAnimation` output.
2. Keep the scroll engine's offset as the settled logical state and represent unfinished programmatic motion
   as an independent additive viewport correction.
3. Scroll naturally between overlapping loaded windows without double-counting concurrent item motion.
4. Use the old carousel transition for non-overlapping windows, without creating or traversing intermediate
   rows.
5. Let user drag, bounce, and deceleration operate on the settled destination without catching, cancelling,
   restarting, or retiming the programmatic track.
6. Preserve C0 continuity when a later `scrollTo` replaces an active one.
7. Preserve the exact active viewport track across unrelated list mutations such as insert, delete, move,
   resize, and content updates.
8. Test analytic/model and Core Animation parity, including additive composition with a changing layer model.

## Non-goals

- Traversing every logical row between distant source and destination indices.
- Making a user drag catch the programmatic animation at its presentation position.
- Velocity-continuous retargeting. Like item properties, a changed target guarantees C0 continuity only.
- A production display-link renderer for programmatic scrolling.
- `UIViewPropertyAnimator`.
- Reintroducing the retired KFModel, causer, tombstone, claim, band, or container-slide animation machinery.
- Keeping an outgoing carousel window fully virtualized after the settled destination starts responding to
  user input. Its relationship to the destination during such input is intentionally best-effort.

## Core contract

The engine owns the settled logical offset. The animation model owns an additive correction:

```text
rendered viewport offset = engine logical offset + viewport correction
```

An animated `scrollTo` builds and renders the destination, writes the engine to the destination immediately,
and starts or replaces a viewport correction that decays to zero. The compiler emits the correction as an
additive keyframe animation on `contentHost.layer.bounds.origin.y`.

This separation is load-bearing. A user gesture changes the engine's logical offset underneath the existing
correction. The programmatic track keeps its generation, curve, phase, and deadline and completes on its
original schedule. On completion, removing a zero-valued additive animation reveals the user-modified settled
state without a jump.

## Model and compiler

`ListAnimationModel` gains:

```swift
ListAnimationOwner.viewport
ListAnimatedProperty.viewportOffset
```

The viewport property uses the existing scalar `ListAnimationTrack`, smoothstep curve, duration scaling, and
generation rules:

- unchanged resolved endpoint: exact no-op;
- changed positive-duration endpoint: replace from the analytic current value to zero;
- changed zero-duration endpoint: settle immediately;
- stale completions cannot clear a replacement or tear down its transient content.

The viewport owner binds to `engine.contentHost.layer`. `CoreAnimationCompiler` emits
`viewportOffset` under its own stable key as an additive `CAKeyframeAnimation` on `bounds.origin.y`, requests
high refresh rate, and uses the same controller-local clock as the other properties. Its key remains distinct
from the physics-flight key, so the two additive animations can coexist.

Programmatic movement is entirely CA-rendered. No display link samples or writes this track. Existing
keyframe-physics sampling remains responsible only for its existing physics/virtualization integration.

## Transaction sequence

For a pass containing `scrollTo`:

1. Capture one controller-local transaction time.
2. Sample the engine's current logical offset and the current analytic viewport correction.
3. Halt any pre-existing user momentum at its logical live offset, preserving the current programmatic
   correction.
4. Reconcile items and size, resolve the explicit target anchor, and build the destination window using the
   existing core list operations.
5. Determine overlap mode from stable loaded identities and derive the boundary correction as described below.
6. Render the destination and write the engine's settled/clamped destination offset with implicit layer actions
   disabled.
7. Install or replace only the viewport property.
8. Apply independent item position, height, and opacity transitions.

The actual engine offset after edge declaration and clamping is the viewport track's settled endpoint. This
preserves top, bottom, short-content, resize, and nonzero `pointOffset` behavior.

## Overlapping windows

The overlap case applies when the old and destination loaded windows share at least one stable item identity.
The current anchor is the pre-pass anchor resolved by the existing core list rules, mapped by identity into the
post-pass item order. Use it as the shared reference when it is loaded in both windows. Otherwise use the
nearest shared row on the travel side of that anchor, falling back to the nearest shared row on either side.
This deterministic reference defines the coordinate mapping between the independently rebased old and new
windows:

```text
R = new reference-row settled content-Y - old reference-row settled content-Y
```

Let the old engine offset and current viewport correction be sampled at the transaction time. The replacement
viewport track starts at:

```text
viewport from = old engine offset
              + current viewport correction
              + R
              - new settled engine offset
```

Every shared row's position transition receives `old settled content-Y + R` as its mapped old endpoint. If a
row already has an analytic position correction, the normal item transition samples and preserves it. At the
boundary this gives:

```text
new row presentation - new viewport presentation
    = old row presentation - old viewport presentation
```

Thus the viewport carries the bulk scroll while row tracks carry only structural residuals. Pure scrolling
does not create row movement; a simultaneous insert, delete, move, resize, or content change cannot double-count
the viewport delta.

Old-window rows that are absent from the destination loaded window are retained temporarily in the scrolling
overlay. They keep full opacity and ride the viewport track out of view. Destination-only rows ride into view
with the destination window. Only genuine data insertions and deletions use the normal independent opacity
rules.

## Non-overlapping windows: carousel

The carousel case applies when the loaded identity intersection is empty. The real index distance is ignored:
intermediate rows are neither created nor traversed.

The complete outgoing loaded window is retained as one rigid strip. Direction compares the requested target
with the current anchor mapped into the post-pass order. If that anchor no longer exists, the existing anchor
resolver's nearest-survivor fallback supplies the comparison point. Direction is therefore defined separately
for every pass rather than attached intrinsically to an operation.

Let `oldVisibleTop` be the outgoing window's rendered top, `newVisibleTop` the destination window's settled
top, `oldStripHeight` the outgoing loaded-window height, and `newWindowHeight` the destination loaded-window
height. The old carousel adjacency is retained. Its former container translation is negated when expressed as
a `bounds.origin.y` correction because increasing the bounds origin moves content upward on screen:

```text
forward/down viewport from = newVisibleTop - (oldVisibleTop + oldStripHeight)
backward/up viewport from  = newVisibleTop + newWindowHeight - oldVisibleTop
```

- Forward/downward travel places the outgoing strip immediately above the destination window. The old
  carousel formula uses the outgoing strip height and the old/new visible tops.
- Backward/upward travel places the outgoing strip immediately below the destination window. The old carousel
  formula uses the destination window height and the old/new visible tops.

The resulting formula directly supplies the viewport correction. Because the destination and outgoing strip
are both descendants of `contentHost`, the single viewport animation moves them as one contiguous rigid
carousel. Neither strip fades merely because of the scroll transition.

The outgoing views bind to transient owners so later destination virtualization may load the same live
identities without sharing a layer binding. Coordinate rebases shift transient strips using the same known
content-coordinate correction as the destination. They are not remeasured or revirtualized during a gesture;
their visual relationship after the user modifies the settled destination is best-effort.

## Interaction and replacement

### User input

A user drag does not catch programmatic scrolling. It begins from the already-settled destination and changes
only the engine's logical state. The viewport track is an exact no-op with respect to the gesture: no generation,
CA key, phase, curve, or deadline changes.

On release, stepped physics may continue changing the layer model while the viewport correction remains
additive. Keyframe physics may install its own additive `bounds.origin.y` animation under a separate key. The
analytic programmatic and physics states remain separate, and their CA output composes.

### Later `scrollTo`

A later `scrollTo` first catches user-driven momentum at its logical live offset. It then samples the old
viewport property analytically and replaces that property from the current rendered boundary. C0 continuity is
required; velocity continuity is not.

Any still-visible outgoing carousel or overlap strips are carried into the replacement generation instead of
being removed at the pass boundary. The new active window may contribute another transient strip. These strips
remain until the current generation settles; safe analytic off-screen pruning may be added as an optimization,
but is not required for correctness.

A stale completion from an earlier generation cannot remove carried strips. The current generation's
completion removes only its matching transient strips.

### Unrelated passes

An apply pass without `scrollTo` never replaces or settles the viewport property. Inserts, deletes, moves,
resizes, reconciliation, self-updates, and zero-duration unrelated passes affect only their changed item
properties. This exact no-op is the required fix for sequences such as `Top -> Del/Add`.

### Same target

If the resolved settled viewport endpoint and coordinate mapping are unchanged, a repeated `scrollTo` is an
exact no-op. If a user drag changed the engine's logical settled offset, requesting the earlier destination is
a changed target and starts a replacement from the current analytic presentation.

## Lifecycle and cleanup

- The viewport layer has one controller binding and one stable CA key.
- Reset, rebuild-from-scratch, engine replacement, and teardown remove that key and every transient scroll
  strip.
- A positive-duration completion is owner-, property-, generation-, binding-, and strip-specific.
- Zero-duration scrolling installs only the destination and tears down transient strips immediately.
- Empty-source or empty-destination operations have no two-window transition and retain the existing immediate
  rebuild/exit behavior.
- Duration scaling occurs exactly once in `ListAnimationController`.

## Testing

### Model tests

- viewport same-target exact no-op;
- changed-target C0 replacement from the analytic current correction;
- zero-duration settlement and generation behavior;
- logical engine movement underneath an unchanged viewport track;
- coordinate-rebase invariance;
- stale completion rejection and transient-strip ownership.

### Compiler parity

- `viewportOffset` compiles to additive `bounds.origin.y` keyframes under its own key;
- arbitrary-phase values match `ListAnimationModel`;
- a paused real layer presents the analytic value;
- changing the layer's settled `bounds.origin.y` mid-flight changes the base while preserving the exact
  additive correction;
- programmatic and physics-style additive animations on the same key path sum correctly;
- slow-duration and explicit begin-time parity.

### List integration

- overlapping scroll in both directions, including rows with active position/height/opacity tracks;
- overlap plus insert, delete, move, resize, reconciliation, and nonzero `pointOffset`;
- Jump to 40 and Top use carousel geometry and never instantiate intermediate rows;
- forward/backward carousel with unequal old/new window heights;
- `newSize`, item diff, and combined item-diff-plus-resize carousel passes;
- `Top -> Del/Add` preserves the exact viewport model track, CA generation, phase, and deadline;
- a second `scrollTo` during overlap or carousel has no boundary jump and ignores stale completions;
- a drag during programmatic motion changes the settled destination without touching the viewport track;
- release into stepped and keyframe physics composes with the viewport track;
- virtualization/rebasing follows the settled destination while transient strips remain best-effort;
- same-target no-op, zero duration, top/bottom clamp, and teardown/reset.

The deterministic harness remains the authority. Production correctness is checked through analytic state and
CA parity rather than presentation-layer feedback.

## Demo checkpoint

The Demo app's **Jump to 40** and **Top** controls continue using their existing `0.3s` duration. Under Slow
Animations:

1. nearby overlapping jumps scroll naturally;
2. Jump to 40 / Top carousel between the two loaded windows without flashing intermediate rows;
3. `Top -> Del/Add` leaves the Top motion unchanged;
4. dragging during either mode moves the settled destination while the programmatic transition finishes;
5. a second Jump/Top retargets continuously.

Temporary state logging may dump logical offset, analytic viewport correction, loaded identities, carousel
strip placement, generation, and CA keys. Screenshot and video recording are not correctness oracles.

## Success criteria

1. Every changed animated `scrollTo` between non-empty windows has a model-owned analytic viewport track and
   CA keyframe output.
2. Overlapping scrolling and granular row animations compose exactly at transaction boundaries.
3. Non-overlapping scrolling uses a contiguous old-style carousel with no intermediate-row traversal.
4. User drag/physics modifies settled state without catching or mutating the programmatic track.
5. A later scroll target replaces continuously; unrelated passes are exact viewport no-ops.
6. Model/CA parity detects any divergence, including model-layer changes during additive playback.
7. The retained full K2 test suite passes, and the Slow Animations Demo checkpoint matches the approved visual.
