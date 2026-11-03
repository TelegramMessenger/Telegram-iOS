# List animation model from scratch

**Date:** 2026-07-20
**Status:** IMPLEMENTED / CURRENT — the base model landed on 2026-07-20, the general survivor geometry
composition rule landed in `3995c25`, and off-screen height rebind now reconciles retained state with fresh
measured geometry.
**Supersedes for future animation work:** the KFModel fold-then-emit animation architecture. The core list,
window, diff, anchor, view-reuse, and scrolling operations remain authoritative and are not being redesigned.

## Context

The production animation path has accumulated pass-wide folds, structural corpses, claims, presentation
corrections, clock preservation rules, property-specific horizons, and CA re-emission exceptions. These rules
can make individual regressions green, but a later unrelated pass can still perturb an older motion. The
failure is architectural: a pass rebuilds a scene and then tries to recover which portions of prior animation
state must survive.

This design discards the animation model and starts from the behavior of a conventionally laid-out scroll
view: core list operations produce absolute settled item frames, and only item properties whose settled values
changed are animated. Animation is granular per stable item identity and property. Assigning the same target
is a strict no-op.

## Goals

1. Preserve all core list behavior: identity diffing, anchor resolution, window construction, measurement,
   content reconciliation, view reuse, virtualization, scroll loading, and scroll physics.
2. Replace the current animation engine with a small, general `ListAnimationModel` that can grow to cover all
   animated properties without becoming a second layout engine.
3. Drive production motion exclusively with `CAAnimation` / `CAKeyframeAnimation`.
4. Make animation interruption granular:
   - unchanged target: preserve the existing analytic and CA tracks exactly;
   - changed target: replace only that item/property from its current analytic presentation to the new target
     on the current pass duration and curve.
5. Support insertion, removal, move/reorder, replacement, resize/content/self-update geometry, and mixed
   identity-diff passes under one property-granular composition rule.
6. Detect any divergence between the analytic model and emitted Core Animation in tests.

## Explicit continuity contract

The model guarantees **C0 continuity** for a changed target: the replacement begins at the exact analytic
presentation value at the transaction boundary. It does not guarantee velocity continuity for that affected
property. Restarting the current pass curve may reset its velocity; the user explicitly accepts this.

An unchanged target is stronger: it is a true no-op. Its existing track, phase, curve, deadline, generation,
and CA animation remain untouched.

This distinction is the central composition rule. An unrelated operation cannot restart an unchanged item or
property merely because both occurred in the same list pass.

## Non-goals

- Velocity- or acceleration-continuous retargeting.
- Logical-height, overlap, insertion-block, corpse, claim, footprint, band, or boundary models.
- A production display-link renderer.
- `UIViewPropertyAnimator`.
- Compatibility with the KFModel animation representation or its animation-specific test corpus.

## Architecture

### 1. Existing core list

`CoreVirtualListView` keeps owning data reconciliation and settled layout. An apply pass still:

1. computes the identity diff;
2. resolves the pass anchor;
3. measures and builds the new window;
4. reuses/reconfigures views;
5. renders the new settled window and scroll edges.

The new animation integration observes the old and new settled item states around that existing transaction.
It does not calculate item order, height accumulation, claims, or anchor geometry.

### 2. `ListAnimationModel`

`ListAnimationModel` is UIKit-free and uses explicit animation owners. A live owner is keyed by
`CoreListItem.identity`; a departing overlay receives a fresh exit-owner id so an old fading incarnation and a
newly reinserted live incarnation of the same item identity can coexist. The model stores the last settled
target and, when active, one analytic track per animated property. The current properties are:

- additive vertical position offset for live items;
- absolute visual height for live items;
- opacity for inserted and departing items.

The type name is intentionally general. Position, height, opacity, scale, or future properties can share its
identity/generation/clock rules without changing the layout contract.

Each track contains:

- a monotonically increasing generation;
- `from` and `to` values;
- immutable start time, duration, and curve;
- analytic `value(at:)` and completion state.

The transaction supplies the curve as well as the duration. The implementation uses the list's current
smoothstep curve; the model owns that curve definition and the compiler samples it rather than substituting a
different Core Animation timing function.

There is at most one active track per identity/property. This is not an additive event ledger: when the same
property's target genuinely changes, the old track is replaced from its current analytic value. Position
geometry uses an additive correction relative to the settled model-layer endpoint; height uses an absolute
`bounds.size.height` track.

### 3. `CoreAnimationCompiler`

The compiler maps a model track to one explicitly timed CA keyframe animation. Production movement is always
Core Animation; a display-link sampler may exist only as a diagnostic or test primitive.

For vertical position:

- the item layer is written to its settled endpoint;
- the model stores the presentation correction relative to that endpoint;
- the emitted `position.y` keyframe animation is additive and decays that correction to zero.

For height, the item layer is written to its settled bounds and the emitted `bounds.size.height` keyframe is
absolute, from the analytic current visual height to the new settled height. Opacity is also absolute. Both
follow the same generation and replacement rules.

The compiler sets an explicit begin time and duration in the same local clock used by the analytic model.
Slow Animation scaling is applied once before both model and CA receive the duration. It is never applied a
second time by the compiler.

Core settled-frame writes run with implicit layer actions disabled. This design does not wrap the whole apply
pass in `UIView.animate`; only the compiler adds the explicitly selected property animations.

### 4. Exit overlay

A removed view leaves the live window and is reparented into a stable overlay hosted in the scrolling content
coordinate space. The overlay freezes the view's current analytic absolute position and visual height while
it fades. It has no structural footprint and no relationship to later window layout.

## Canonical coordinate contract

Scrolling must not look like a property-target change. Position tracks are therefore stored as additive
offsets relative to the current settled item position, rather than as persistent viewport coordinates.

At one apply boundary and one engine offset:

1. derive the old settled screen position;
2. sample the old analytic additive offset;
3. derive `currentVisible = oldSettled + oldOffset`;
4. render the new settled position;
5. derive `newOffset = currentVisible - newSettled`;
6. replace the changed position track with `newOffset -> 0`.

The additive offset is invariant under subsequent parent scrolling. This also absorbs window/container
rebasing without requiring a container-wide animation.

The old container animation path is removed. Visible item movement is granular per item.

Height uses the same boundary rule without an additive coordinate transform:

1. sample `currentVisualHeight` from the owner's analytic height state;
2. write the new settled bounds immediately;
3. if the settled height changed, replace the height track with
   `currentVisualHeight -> newSettledHeight` on the pass clock.

Position and height are evaluated and replaced independently. Neither depends on whether the other property
changed or already had an active track.

## Transaction rules

### Surviving identities

Every loaded identity present before and after the pass is evaluated, whether or not its geometry property
already has an active track:

- **Same settled position:** perform no model mutation and no layer animation call. Equality is evaluated in
  the canonical settled coordinate with a `1e-6pt` epsilon, so harmless floating-point reconstruction cannot
  restart a track.
- **Changed settled position, animated pass:** sample its current analytic presentation, write the new settled
  frame, and replace only its position track with the newly derived additive correction on the pass clock.
- **Same settled height:** within the same `1e-6pt` epsilon, perform no model mutation and no layer animation
  call, preserving the exact height track, generation, phase, curve, deadline, and CA key.
- **Changed settled height, animated pass:** sample its analytic current visual height, write the new settled
  frame, and replace only its absolute height track on the pass clock.
- **Changed geometry, immediate pass:** write the new settled frame and settle only each directly affected
  position or height track.

A move/reorder keeps the same view and identity, transitions each changed geometry property independently,
and does not fade.

### Inserted identities

An inserted view:

- is installed immediately at its final settled absolute frame;
- has full visual bounds immediately;
- receives no position or height animation;
- has model opacity set to the final value and receives a `0 -> 1` fade on the pass clock.

There is no logical-height or overlap state. Contiguous inserted rows appear as full-height final rows and fade
on their respective pass clocks. A later insertion remains full-height and fade-only; any already-present
loaded survivor whose settled position changed transitions under the general survivor rule.

### Departed identities

Before reconciliation releases a departed view:

1. sample its current analytic position, height, and opacity;
2. transfer that presentation into a fresh exit owner;
3. place it in the exit overlay at that same absolute content position and freeze its visual height;
4. replace its opacity track from the sampled value to zero on the pass clock;
5. tear it down when that exact opacity generation completes.

The departing view does not move or resize with structural changes from the new window.

### Mixed passes

Insert, removal, replacement, and move rules are independent and run in the same transaction. A replacement
is therefore an outgoing fade plus an incoming fade. Every surviving identity animates only if its own settled
position or height changed.

Resize, content reconciliation, and self-update write final settled frames immediately. Every loaded survivor
whose settled position or height changed then starts or replaces that property from its analytic current
presentation on the captured transaction time, pass duration, and model-owned smoothstep. Each unchanged
endpoint is an exact no-op, preserving its track, generation, phase, curve, deadline, and CA key. Unrelated
identity/property tracks are untouched.

### Zero duration

A zero-duration changed property settles immediately. A departure tears down immediately and an insertion is
fully opaque immediately. A same-target property is still a no-op; a zero-duration unrelated pass cannot erase
its existing animation.

## Track and layer lifecycle

- Every replacement receives a new generation.
- CA keys are stable per item/property; replacing a position, height, or opacity track replaces only that key.
- A completion captures its generation and acts only if it is still current.
- Stale completions cannot clear replacement tracks, tear down a rebound layer, or remove a reused view.
- Before a recycled layer binds to a different identity, all model-owned keys are removed.
- An identity may retain analytic state while off-screen. If it receives a layer again, the controller first
  compares the retained height target with the freshly measured/rendered layer height using the model epsilon.
  An unchanged target preserves and re-emits the exact original height track, phase, deadline, generation, and
  CA metadata. A changed target settles only height to the fresh geometry, clears only its stale height
  track/completion, and leaves position and opacity exact; the same rule applies when retained height state has
  no active height track. Every remaining track is emitted using its original phase and deadline.
- Settled tracks are reaped analytically after their deadlines. The model layer already contains the endpoint.
- Position, height, and opacity participate in recycle cleanup, rebind, unbound-owner deadline reaping, and
  stale-completion guards under the same property-granular lifecycle.

Interruption values come from `ListAnimationModel`, never from `layer.presentation()`. Core Animation is an
output renderer, not a source of state.

## Model/CA parity

The compiler and model must agree for every active identity/property at arbitrary times. A mismatch is a test
failure; production must not hide it by sampling the presentation layer back into the model.

Parity includes:

- value at birth, interior phases, deadline, and after settlement;
- explicit begin time and duration;
- additive position and absolute height semantics;
- replacement from the analytic current value;
- unchanged-target no-op behavior;
- slow-duration scaling;
- remaining-track attachment for a newly loaded or rebound layer;
- actual paused-layer presentation, not only inspection of generated keyframe arrays.

## Test strategy

### Remove legacy animation tests

Delete the test surface that specifies the retired animation machinery, including:

- `KFModel*` animation/model suites;
- `Keyframe*Emit*` suites;
- causer, band, kernel, corpse, claim, footprint, tombstone-animation, and old continuity suites;
- animation-only fixtures and helpers used solely by those engines.

Do not delete core behavioral coverage. Keep tests for identity diffing, anchor selection, window construction,
measurement, view reuse, content reconciliation, immediate rendering, scrolling, and scroll physics. Where an
`ApplyChanges` test mixes a useful core assertion with retired animation internals, retain the core assertion in
an immediate-render test and discard the animation-specific oracle.

### Add fresh tests

#### `ListAnimationModelTests`

- same target preserves the exact track/generation/clock;
- changed target replaces from the analytic current value;
- independent position and height replacement, including owners without prior tracks;
- insertion seeds final height without a height track, while exit creation freezes analytic current height;
- zero-duration behavior;
- stale completion generations are inert;
- off-screen state and remaining-phase attachment;
- deterministic insertion, removal, move, replacement, and mixed transactions.

#### `CoreAnimationCompilerParityTests`

- model samples equal compiled keyframe samples across arbitrary phases;
- position animations are additive relative to model endpoints;
- height animations are absolute on `bounds.size.height` and match analytic model samples;
- explicit clock and slow-duration parity;
- replacement and remaining-track emission;
- a paused real `CALayer` presentation test catches divergence in Core Animation itself.

#### `CoreVirtualListAnimationTests`

- single and contiguous insertion;
- insertion during an in-progress insertion;
- removal and repeated `Del/Add`;
- replacement crossfade;
- delayed and repeated move/reorder;
- overlapping mixed insert/remove/move passes;
- changed-target replacement versus unchanged-target preservation;
- delayed resize/content/self-update geometry with independent survivor position and height transitions;
- full-height fade-only insertion and analytic position/height freezing for exits;
- view reuse and exit-overlay teardown;
- scrolling while tracks are active.

These tests specify the new public behavior and must not reproduce KFModel's internal concepts.

## Verification checkpoint

The original Slow Animations checkpoint exercised:

- repeated inserts near and away from the pass anchor;
- insertion after an in-progress insertion;
- `Del/Add` spam;
- `−Top -> Del/Add`;
- delayed Swap 2-5 and repeated moves;
- mixed insert/remove/move passes;
- scrolling while animations remain active;
- delayed resize/content updates at their transaction boundaries.

The general geometry-composition follow-up in `3995c25` passed its focused 76/76 tests and the full 278/278
suite, and post-fix Demo boundary logs confirmed continuity at the delayed pass. A later final review accepted
the loaded-pass geometry composition but found the off-screen height-rebind and height-lifecycle coverage gap
addressed by the follow-up below.
The off-screen height-rebind follow-up added real controller/list coverage for changed and unchanged height
targets, same-pass reentry, stale height completions, reset cleanup, height-only autonomous reaping, and exact
same-target CA no-op behavior. A deterministic install seam directly proves stale CA `PendingCompletion`
callbacks cannot clear a rebound replacement generation or its installed height key. The final focused
model/compiler/list checkpoint passed 85/85, and the retained full K2 suite passed 287/287 with zero failures.
Final read-only re-review found no Critical, Important, or Minor issues.

## 2026-07-23 seeded mixed-pass stress coverage

The integration suite now runs six checked-in seeds through 32 passes each. Its grammar combines blocks of
one to five inserts/removals/moves, replacement, content-height changes, horizontal and vertical insets,
viewport size, programmatic scroll targets, and explicit same-target passes. Durations include immediate,
smoothstep, and ease-out transitions; generated advances land at birth and at early, middle, and late phases,
with full settlement every eight passes and at each seed's end.

The oracle uses the existing synthetic clock and already loaded live/carry/ghost surfaces. It checks
transaction-boundary C0 continuity, exact unchanged-track preservation, replacement duration/curve/from
values, finite and contiguous settled windows, observed installed CA metadata against analytic tracks, and
complete carry/ghost/model teardown. It never reads `CALayer.presentation()`, expands the loaded window, or
measures extra items. User drag/deceleration remains in the dedicated physics suites, and the oracle does not
impose a blanket transient gap/overlap rule because full-height insert reveals and departures may
intentionally overlap.

The first bounded run exposed a general lifecycle defect: crossing carries owned by viewport generation 68
survived after the viewport property was replaced by generation 69, because replacement invalidated the old
completion without migrating the carries' release generation. The shared viewport-transition seam now
migrates every carry released by the previous generation to a positive-duration replacement and releases it
immediately for an immediate replacement. A focused inset-membership-then-scroll regression preserves the
failure independently of the generated sequence.

## 2026-07-23 infinite-loading anchor preservation

`applyChanges` now accepts a per-pass `.preserveVisibleContent` anchor mode for externally managed
infinite loading. The policy resolves against old settled geometry at the top-inset edge, records the
crossing loaded item's own inset-relative `minY`, and projects that distance through the new top
inset. Identity-preserving LIS moves map through `ItemDiff.moves`; a genuinely departing witness
falls back to the nearest loaded survivor below, then above, preserving the fallback's own old
position.

The policy is only an input to the existing one-pass final window build. It does not inspect old
off-screen items, measure toward a fallback, apply a post-layout engine correction, or create an
animation primitive. Normal top/bottom/underfill clipping remains authoritative when exact
preservation is impossible, and explicit `scrollTo` wins. Active analytic row and viewport tracks,
ghosts, crossing carries, CA compilation, and stepped/keyframe deceleration retain their existing
composition rules.

The Demo exposes separate `Load +5` and `Load -5` leading-page controls while retaining `+top` and
`-top` as automatic finite-list checks. Deterministic coverage includes loaded-top and mid-list
prepending, removal and moved-witness mapping, below/above fallback, inset and size changes, mixed
structural/content passes, no-extra-measurement fallback, overlapping animation, installed CA,
scroll-engine parity, active deceleration, and Demo identity restoration.

## Success criteria

1. Core list behavior and its retained tests remain intact.
2. The old animation engine and its animation-specific tests are gone.
3. Insert, remove, replacement, move, resize/content/self-update, and mixed passes follow the granular target
   rules above.
4. Writing the same target never restarts or replaces an animation.
5. Every changed loaded-survivor position or height begins at its analytic current presentation, even without
   a prior track, with no boundary jump.
6. Inserted views are full final height and fade only; exits freeze analytic current position and height and
   fade only.
7. All production movement is emitted through CA animations; no production display-link renderer or
   `UIViewPropertyAnimator` exists.
8. Model/CA parity tests, new integration tests, and the retained whole suite pass.
9. Rebinding an off-screen live owner never lets stale retained height state overwrite freshly measured
   geometry; exact height track preservation applies only when the fresh target is unchanged within epsilon.
