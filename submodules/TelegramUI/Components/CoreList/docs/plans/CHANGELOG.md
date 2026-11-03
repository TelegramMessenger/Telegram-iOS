# Plans changelog

This is the concise landed-work digest for the current granular stable-identity/property animation
architecture. `CLAUDE.md` contains the current contract; retained designs contain rationale; Git
history contains removed experiments, execution plans, and superseded architectures.

## Current direction

Settled window layout and animated presentation are separate authorities. Core list operations write
final frames; `ListAnimationModel` owns analytic state per stable identity/property;
`ListAnimationController` owns model/layer binding and generation-safe lifecycle; and
`CoreAnimationCompiler` renders those tracks as explicitly timed keyframes.

Unchanged targets are exact no-ops. Changed properties retarget from their analytic current value
for C0 continuity. Position is additive relative to settled geometry; width, height, and opacity are
absolute; one controller-local transaction clock and one already-scaled duration feed each pass.
Departures use rigid ghost blocks with boundary witnesses. Virtualization crossings retain only
endpoint-window survivors and never measure extra rows. Programmatic distant scrolling uses one
additive viewport track and adjacent outgoing/incoming carousel windows.

The foundational authorities are
[`2026-07-20-list-animation-model-design.md`](2026-07-20-list-animation-model-design.md) and
[`2026-07-20-additive-viewport-scroll-design.md`](2026-07-20-additive-viewport-scroll-design.md).
Current extensions are retained under `docs/superpowers/specs/`.

## Landed work

- **2026-09-29 — a second jump reversed mid-flight lands on the first's outgoing strip**: carousel
  adjacency placed the incoming window against the loaded window only, so a jump back the way an
  in-flight jump came landed exactly on that jump's strip, still parked in `carouselExitOverlay`,
  and carried both coincident for the whole travel (300pt of overlap on a 300pt viewport). The
  outgoing band now includes every viewport-anchored strip, and those strips' exit tracks are
  re-timed onto the pass that now carries them, so a late reversal leaves no empty band and an
  immediate jump leaves no strip frozen over the destination. `CarouselChainOverlapTests`.
- **2026-08-03 — a completion Core Animation never sends**: the exit overlay's teardown hangs on a
  CA completion, and **Core Animation does not run an animation whose `fromValue` equals its
  `toValue`** — it changes nothing, the render server has nothing to schedule, and
  `animationDidStop` is never sent (with `isRemovedOnCompletion = false` the animation just sits on
  the layer). Two tenants ride equal-endpoint tracks BY DESIGN: a non-fading exit
  (`beginExit(fadesOut: false)` — every departing row of a full-replace carousel) installs
  `opacity: o -> o` purely to own a teardown deadline, and a viewport re-target onto the
  displacement already in flight yields `viewportOffset: 0 -> 0`, whose completion runs
  `finishViewportGeneration`. Both stranded their content in `exitOverlay`, which sits above
  `container` and takes no touches — stale rows drawn over live ones, permanently. It presented in
  the chat as the outgoing strip of a scroll-to-bottom sticking over the conversation.
  `ListAnimationController.install` now drives such a track's completion from the ANALYTIC deadline
  (`ListAnimationTrack.deliversNoCoreAnimationCompletion`), which is the rule the architecture
  already states: the model is the presentation authority, the compiler is an output renderer, and a
  model-owned completion must not depend on whether Core Animation found the animation worth
  running. Only equal-endpoint tracks arm a timer — a moving track still rides its callback, so a
  pass does not pay dozens of timers — and `finalize` removes the pending record first, so the two
  paths cannot double-fire. Note the model-level no-op guard was NOT enough and had already been
  deliberately bypassed: `beginExit` routes around the equal-target early-out precisely so the track
  exists, with a comment explaining that returning `.unchanged` would leak every member — the
  emitted animation then leaked them anyway. Three defences all missed it: `assertOverlayInvariants`
  passes because the view IS owned (by an owner that can never be reaped), the test harness runs
  `emitsAnimations: false` so it never exercised completion delivery at all, and `DEBUG` is not
  defined for Swift in the app's Bazel build, so the assertions are compiled out of the app.
  `NoOpAnimationCompletionTests` locks both cases plus a non-vacuity guard that a moving track arms
  no timer.

- **2026-08-02 — `settledFrame(of:)`, the other half of `presentedFrame(of:)`**: `presentedFrame(of:)`
  landed as *the* host geometry accessor, on the reasoning that a host asking where a row is wants
  where it is. That is right for every per-frame read and wrong for exactly one: a host reporting the
  OUTCOME of a pass it just submitted, alongside that pass's transition. At that instant the pass has
  been applied but its animation has moved nothing, so presented is the pre-animation position — and
  because there is no per-frame hook outside user scrolling, nothing re-reports when the animation
  lands. `settledFrame(of:)` is the sibling for that case: exactly `presentedFrame` without the
  correction, i.e. what a bare `convert` returns, but named so the choice is deliberate rather than
  the mistake `presentedFrame` exists to prevent. It changes nothing inside CoreList. The chat backend
  is the first consumer and shows why it matters: reporting presented at its transaction point left
  the scroll-to-bottom button on screen after a jump and made it appear when the keyboard opened at
  the bottom of a chat — measured at ~270pt against a settled `-0.0`. See "Content offsets" in
  `docs/chat/corelist-chat-history-backend.md`.

- **2026-07-31 — a carousel's ghost blocks take no boundary witness**: a full-replace carousel gives
  every departing row a ghost block, and `initialGhostWitness` — finding no surviving predecessor,
  which a full replace guarantees — fell through to proposing `newItems[0]` (or, at the far end,
  `newItems.last`). That proposal *resolves* exactly when the destination window reaches a collection
  edge, so the departed strip acquired a position track onto the head of the incoming window and
  walked across it while the shared viewport track carried both. The rule it broke was already stated
  for the incoming side — the additive viewport track is a carousel's exclusive vertical-motion owner
  — and a carousel's departed strip has no live neighbourhood to attach to anyway: its destination is
  a different region of the collection, which is what made the pass a carousel. Blocks are born
  `.unresolved`, so declining to attach one is the whole fix; `resolve` then returns the block's own
  `settledRootY` and the equal-endpoint `transitionGhostBlock` is an exact no-op. Found as a chat
  jumping from far in the past to the newest message: 348pt of overlap on a 400pt strip at 75% of the
  travel. Every mid-collection jump stayed rigid, which is why nothing caught it — the carousel suites
  all sit at index 50, and `ProgrammaticScrollAnimationTests` asserts strip adjacency but keeps the
  same collection, so its old rows become viewport carries rather than ghosts.
  `FullReplaceCarouselStripSeparationTests` locks both collection edges, a mid-collection control, and
  the mechanism (`witness == .unresolved`, no ghost position track). The debugging note worth keeping:
  sampling `ListAnimationModel` for the two strips' screen bounds across the travel and asserting the
  overlap turned an eyeballed "heavy intersection" into a number and a named owner in one 15ms run.

- **2026-07-28 — inset compensation is suppressible while dragging**: `applyChanges` gained
  `compensatesInsetChange` (default `true`), and the seam gained `ScrollEngine.onDidEndDragging` →
  `CoreVirtualListView.didEndDragging` so a host can close a finger-down interval at all — only
  drag-*begin* existed. `false` drops the `newTopInset - oldTopInset` anchor projection and nothing else:
  the new insets still drive content x/width, the viewport band, the load band and the loaded-top pin, so
  index 0 still rides the inset edge. That split is what `ListViewImpl` does when it zeroes `offsetFix`
  while tracking (`Display/Source/ListView.swift:3276`) — it still assigns `self.insets` and still runs
  `snapToBounds` — and it is why the newest message keeps following the keyboard down under suppression.
  This fixed a real chat defect rather than buying parity: the chat's keyboard is dismissed interactively
  by a window-level pan that recognizes SIMULTANEOUSLY with the history list's scroll pan
  (`Display/Source/WindowContent.swift:1332` and `:254`), so one downward drag reached the list twice —
  as a scroll delta and as a smaller bottom inset — and the history moved by roughly twice the finger's
  travel. The trap worth remembering is that `additionalScrollDistance: -topInsetDelta` looks like the
  same thing and is not: a non-zero distance halts momentum and opts the pass out of `pinsLoadedTop`, so
  the newest message would stop tracking the inset edge — the one case that must keep working. Deciding
  that a pass is drag-caused stays caller policy (`CoreListChatHistoryBackend` maintains its own
  `isTracking`); this view exposes only the switch. 593 tests, clean Bazel build, manually verified in the
  chat.

- **2026-07-28 — `additionalScrollDistance`**: `applyChanges` gained the `ListViewImpl.transaction`
  parameter of the same name — a caller-chosen viewport displacement in points, positive moving content
  down. It rides the same addend as the inset compensation (`Display/Source/ListView.swift:3275`), so a
  pass can re-inset and scroll by a delta as one movement, and it displaces the resolved anchor before
  window construction rather than writing an offset afterwards, which is what makes it compose with edge
  clipping, loaded membership, crossing carries, and an explicit `scrollTo`. A non-zero value halts
  momentum and opts the pass out of the loaded-top pin (which would otherwise swallow it whole); both
  match ListViewImpl, including its non-halt under a stationary anchor. The one non-obvious part was
  ownership: the first implementation shifted content correctly, exactly, and on the right curve, but
  through per-row position tracks instead of the shared viewport track, because it was missing from the
  predicate that decides who owns a pass's screen displacement — invisible in the rendered motion of the
  loaded rows, and wrong for ghosts, carries, and rows entering the window. That predicate is now the
  named `displacesViewport` with a gotcha in `CLAUDE.md`. The chat's only producer passes 0.0 and has
  since the repo's first commit, so this buys contract parity rather than behavior. 585 tests, clean
  Bazel build.

- **2026-07-28 — CAAnimationUtils parity**
  ([design](../superpowers/specs/2026-07-28-corelist-caanimationutils-parity-design.md)): CoreList
  stopped sampling curves into 240Hz keyframes. Both emitters now build through one shared factory
  holding a copy of `CAAnimationUtils.makeAnimation`'s branch tree, so a chat row under the CoreList
  backend moves exactly like one under `ListViewImpl` — including the real `CASpringAnimation` at
  duration 0.5, which CoreList previously rendered as a sampled bezier. The model's solver dropped
  Display's 0.997 clamp (the clamp was the entire 2.9e-3 error; 4-iteration Newton was already exact
  to 4.4e-16) and evaluates system springs through the private `_solveForInput:`. `setTransform`
  stopped hand-rolling element-wise matrix interpolation and now hands CA the endpoints. Keyframes
  remain only in the physics deceleration flights. Slow Animations now reaches the emitted animation
  as `speed` rather than a longer duration, again matching `CAAnimationUtils`; the model still reasons
  on the scaled clock, and the track carries the applied factor so the compiler can divide it back
  out. Verified by a paused-layer sweep per curve comparing rendered presentation against
  `track.value(at:)`, plus 575 tests and a full Bazel build. The physics deceleration flights still
  ignore the drag coefficient; that is an accepted limitation, documented in `CLAUDE.md`'s gotchas
  with what to check if it is ever changed.

- **2026-07-27 — `CoreListTransition`** (`2e50799` through `d31a0c8`;
  [design](../superpowers/specs/2026-07-27-corelist-transition-design.md)): replaced
  `ListAnimationSpec`/`ListAnimationCurve` with a vendored, ComponentTransition-shaped
  `CoreListTransition`. 146 `animationDuration:` and 68 `logicalDuration:` call sites collapsed onto
  one `transition:` parameter, which also fixed a latent wart where those paths hard-coded
  `smoothstep` regardless of the pass's curve. `smoothstep`/`easeOut` became `.easeInOut` — a real if
  small motion change — with `.linear` retained as the tests' contrast curve. `apply(to:transition:)`
  and `update(width:transition:)` now carry the pass transition, non-immediate only for rows whose
  content changed. All 20 `CATransaction` blocks were removed outright: completions moved onto the
  animation (a copy of Display's `CALayerAnimationDelegate`), and `setDisableActions` proved
  unnecessary because every layer CoreList writes is UIView-backed and returns a null action by
  default outside an animation block. Converted to `ComponentTransition` in
  `CoreListChatHistoryBackend`, which also derives its pass transition from the ListView
  transaction's own `scrollToItem`/`updateSizeAndInsets`/`options` rather than a hardcoded duration.
  `ListAnimationModel` remains the sole presentation authority, unchanged. 557/557 tests plus a full
  Bazel app build.

- **2026-07-24 — documentation authority cleanup**: reduced the checked-in documentation to current
  subsystem authorities, moved historical recovery to Git, normalized retained design status, and
  made `CLAUDE.md` the concise map of current contracts.

- **2026-07-24 — finite-edge shifts trigger terminal-safe keyframe re-bakes** (`bc7471f`,
  `57dae12`; [design](../superpowers/specs/2026-07-24-terminal-keyframe-edge-rebake-design.md)):
  keyframe shifts remain translation-only while both edges are open. With either edge finite, a
  shift becomes a durable trajectory-shape invalidation; pending invalidation outranks obsolete
  sampler/CA completion and rebakes once against the latest offset and bounds while preserving
  analytic current position and velocity. Focused serial K2 verification passed 54/54 tests and the
  complete suite passed 480/480.

- **2026-07-24 — delayed, deduplicated Demo auto-load responses** (`b851ffa`, `b0a634c`;
  [design](../superpowers/specs/2026-07-24-delayed-auto-load-response-design.md)): the Demo
  controller owns queued and in-flight edge requests, coalesces simultaneous edges, returns each
  accepted request after 0.2 seconds, and suppresses duplicates or stale disabled-mode responses.
  Each response uses one zero-duration `.preserveVisibleContent` transaction; the list remains
  policy-free. Focused verification passed 62/62 tests and the complete suite passed 477/477.

- **2026-07-24 — durable keyframe edge invalidation** (`0b9cf7a`;
  [design](../superpowers/specs/2026-07-24-durable-keyframe-edge-invalidation-design.md)): real edge
  changes now survive display-link tick boundaries, coalesce against the latest bounds, and are
  consumed only by a continuous trajectory splice. Pure coordinate shifts remain translation-only.
  Focused verification passed 43/43 tests and the complete suite passed 475/475.

- **2026-07-24 — Demo automatic edge loading** (`cc1487e`, `7226e06`, `86d5a42`, `79d3318`;
  [design](../superpowers/specs/2026-07-24-demo-auto-edge-loading-design.md)):
  `CoreVirtualListView` exposes deduplicated settled loaded-edge state at list-local load lines.
  The default-off Demo policy prepends or appends five rows and continues in bounded batches until
  neither edge is reached. Positive margins load later, negative margins earlier, and display-only
  overscroll does not affect observation. Complete verification passed 472/472 tests.

- **2026-07-23 — infinite-loading anchor preservation** (`7d81837`, `36865b3`, `6416b50`,
  `3d0c9a6`;
  [design](../superpowers/specs/2026-07-23-infinite-loading-anchor-preservation-design.md)):
  `.preserveVisibleContent` preserves the loaded identity crossing the settled top-inset edge at
  its own inset-relative position. A departing witness falls back below, then above; explicit
  `scrollTo` wins; finite edges still clip. No old off-screen row is measured and no post-layout
  correction is applied. Complete verification passed 455/455 tests.

- **2026-07-23 — seeded mixed-pass stress harness** (`cb39336`, `4eaf6a3`, `dfb3bda`,
  `3efaf15`;
  [design](../superpowers/specs/2026-07-23-seeded-mixed-pass-stress-harness-design.md)): a bounded
  fixed-seed grammar composes structural, row-geometry, viewport-geometry, and programmatic-scroll
  changes. It checks transaction-boundary C0 continuity, unchanged-track preservation, CA/model
  metadata parity, settled-window integrity, and carry/ghost teardown. The first run exposed and
  fixed viewport-release ownership that failed to migrate across a replacement generation.
  Complete verification passed 437/437 tests.

- **2026-07-22 — crossing-run boundary projection** (`de25629`, `5426f63`, `03a9fd2`,
  `c80416e`;
  [fallback design](../superpowers/specs/2026-07-22-crossing-run-boundary-fallback-design.md),
  [occupied-boundary design](../superpowers/specs/2026-07-22-crossing-run-occupied-boundary-design.md)):
  an unwitnessed contiguous crossing run receives one rigid best-effort translation. Its anchorward
  edge clears both the viewport-plus-preload threshold and the settled extent already occupied by
  the built window, preserving internal spacing without loading or measuring additional items.
  Complete verification passed 429/429 tests.

- **2026-07-22 — projected-anchor inset transitions** (`2333c2c`;
  [design](../superpowers/specs/2026-07-22-projected-anchor-inset-transition-design.md)): inset
  changes project the resolved anchor before the one-pass window build. Construction traverses to
  and clips the loaded top first, then the loaded bottom; the completed projected window alone
  determines the new settled offset. Complete verification passed 404/404 tests.

- **2026-07-22 — rigid carousel adjacency and detached-boundary remapping** (`9c31058`,
  `10716db`;
  [adjacency design](../superpowers/specs/2026-07-22-normalized-carousel-adjacency-design.md),
  [replacement design](../superpowers/specs/2026-07-22-viewport-replacement-detached-boundary-design.md),
  [exclusive-motion design](../superpowers/specs/2026-07-22-carousel-exclusive-row-motion-design.md)):
  disjoint programmatic-scroll windows use normalized loaded-strip geometry, remap detached overlay
  content once at viewport replacement, and leave destination-only rows under the shared viewport
  track as their exclusive vertical-motion owner.

- **2026-07-21 — composable viewport geometry** (`3c9c3aa` through `45d1365`;
  [design](../superpowers/specs/2026-07-21-viewport-geometry-animation-design.md)): the list receives
  size plus full insets without parent-position knowledge. Final geometry writes immediately, then
  independent x/y/width/height tracks and one shared viewport correction compose with structural,
  ghost, crossing, and carousel motion. Complete verification passed 389/389 tests.

- **2026-07-21 — per-identity virtualization crossing carries** (`2be66f1` through `2202614`;
  [design](../superpowers/specs/2026-07-21-crossing-survivor-carry-design.md)): survivors crossing
  the viewport-plus-preload membership boundary animate instead of instantly unloading or
  materializing. The settled active window remains pure; only the union of old rendered survivors
  and the new settled window participates, and no additional row is measured. Complete verification
  passed 376/376 tests.

- **2026-07-21 — settled-edge anchors and ghost attachments** (`c4f48b4`, `92884e3`,
  `3d5121d`;
  [design](../superpowers/specs/2026-07-21-settled-edge-anchor-ghost-attachment-design.md)):
  mutation anchors use clamped settled geometry, not presentation overscroll. At the loaded top,
  index zero pins below the top inset; departed blocks attach the correct local min/max edge to a
  live or ghost boundary. Complete verification passed 356/356 tests.

- **2026-07-21 — ghost-block boundary witnesses** (`2af9629` through `bc9dbcd`;
  [design](../superpowers/specs/2026-07-21-ghost-block-boundary-witness-design.md)): contiguous
  departures retain rigid sampled member geometry under one wrapper. Stable live/ghost boundary
  links migrate toward each pass anchor; deletion-only blocks remain open until an insertion
  occupies their root; referenced empty blocks remain spatial nodes until dependents finish.
  Complete verification passed 350/350 tests.

- **2026-07-21 — projected viewport window construction**
  ([design](../superpowers/specs/2026-07-21-projected-viewport-window-design.md)): transaction
  windows are built directly against the final projected viewport-plus-preload band, so later
  container parking cannot change virtualization membership.

- **2026-07-21 — additive viewport animation for programmatic scrolling** (`25d63f8` through
  `e783719`;
  [design](2026-07-20-additive-viewport-scroll-design.md)): settled engine state remains logical
  scroll authority while one analytic additive viewport correction animates `contentHost`.
  Overlapping windows use shared identities; disjoint windows use one adjacent carousel without
  intermediate rows. Gestures update settled state beneath the unchanged correction. Complete
  verification passed 314/314 tests.

- **2026-07-20 — granular animation model landed** (`4220850` through `08309c6`, followed by
  `b65942f`, `9b6e85f`, `d0b6021`, `3995c25`;
  [design](2026-07-20-list-animation-model-design.md)): introduced UIKit-free analytic tracks,
  strict unchanged-target preservation, changed-target C0 replacement, CA keyframe compilation,
  stable binding lifecycle, insertion fades, fresh exit owners, and independent survivor
  position/extent transitions. Later passes added off-screen height reconciliation and
  generation-safe autonomous cleanup. The former production animation architecture was removed.
