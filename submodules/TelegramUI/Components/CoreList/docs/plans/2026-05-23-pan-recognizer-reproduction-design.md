# Pan Gesture Recognizer Reproduction — Design

**Status:** IMPLEMENTED / CURRENT

**Goal:** Faithfully reproduce UIScrollView's pan gesture recognizer (translation + velocity) as a pure, no-UIKit struct, validated against recorded ground truth, so the scroll-physics replay is driven from the *same touch-level inputs* UIScrollView consumes. This removes the display-link / `setContentOffset` sampling artifacts we kept hitting (the one-frame decel-start lead, the touch-up velocity, the deep-overscroll handoff): every one of them came from sampling the wrong layer.

**Background:** analysis-doc §7 decodes the recognizer. `velocityInView` = `W1·current + W2·previous`, each sample a per-touch-event centroid finite-difference `(end − start)/dt`; `translationInView` = cumulative centroid delta. The current harness records `setContentOffset` writes (downstream) and reads translation/velocity *at those write times* — the wrong cadence.

## Architecture — three layers, each recorded and validated

- **Layer 0 (touches):** raw touch centroid + timestamp + phase, per touch event — the recognizer's input.
- **Layer 1 (recognizer):** translation, velocity, state — reproduced by a pure `PanRecognizer`, validated against recorded outputs to ~0.
- **Layer 2 (physics):** the existing `ScrollPhysics`, driven by the validated recognizer at the real event timeline.

## Components

### 1. Touch-level recording (extend the swizzler + `GestureRecording`)
- Extend `UIScrollViewPhysicsSwizzler` from `setContentOffset:` to the recognizer's `touchesBegan:/Moved:/Ended:/Cancelled:withEvent:` (call through to the original first).
- Per touch event, append a `TouchSample { t, centroid, phase }`:
  - `t` = `UITouch.timestamp` (the event's time, the recognizer's clock).
  - `centroid` = `panGR.location(in: scrollView)` read *after* the original — the recognizer's centroid in view coords (the scene-ref → view convert is folded in, so we reproduce in view space).
  - `phase` = began / moved / ended / cancelled.
  - Also capture the recognizer's post-update outputs as **ground truth**: `translation` (`translation(in:)`), `velocity` (`velocity(in:)`), `state`.
- Add `touches: [TouchSample]` to `GestureRecording` (alongside the existing `frames`; `releaseTime` already captured). Keep `frames` (the `setContentOffset` trajectory) as Layer 2 ground truth.

### 2. `PanRecognizer` (pure struct, CoreGraphics only)
Reproduces §7 in **view coordinates** (matching `location(in:)`):
- State: `startCentroid`, `refCentroid`, `lastTouchTime`, `currentSample`, `previousSample` (each sample `{start, end, dt}`).
- `began(centroid, t)`: `startCentroid = refCentroid = centroid`, `lastTouchTime = t`, clear samples.
- `moved(centroid, t)`: `dt = t − lastTouchTime`; if `dt > 0`: `previousSample = currentSample`; `currentSample = {start: refCentroid, end: centroid, dt}`; `refCentroid = centroid`; `lastTouchTime = t`.
- `translation` = `centroid − startCentroid`.
- `velocity` (pts/s, matching `velocityInView`) = `W1·current.v + W2·previous.v`, where `sample.v = (end − start)/dt`; the previous term applies only if `previousSample` exists and `previousSample.dt > 2⁻²³`.
- Units: outputs pts/s like `velocityInView`; the `ScrollPhysics` boundary keeps its existing `−v·0.001` (pts/s → pts/ms) conversion.

### 3. W1 / W2 calibration
Hopper didn't name the weights, and the simulator binary differs from the decoded device binary — so **calibrate empirically**. From recorded touches compute `current.v` and `previous.v` per event; the recorded `velocity` output = `W1·current.v + W2·previous.v`. Least-squares fit `(W1, W2)` over all events (per axis — must agree). Bake the fitted constants into `PanRecognizer`; a calibration test asserts the fit residual ≈ 0 (which also confirms the 2-sample-blend model is right).

### 4. Validation (`RecognizerReplay`)
Feed recorded touches → `PanRecognizer` → assert its `translation` and `velocity` match the recorded recognizer outputs to ~0 per event. This validates Layer 1 in isolation.

### 5. Rewire `ScrollReplay` (Layer 2)
- **Drag:** per touch event, `recognizer.moved(centroid, t)` → `translation` → `physics.drag`. Driven by `touches`, not by `setContentOffset` frames.
- **Handoff:** the `.ended` touch event → the recognizer's final `velocity` → `physics.endDrag` at the exact touch-up instant.
- **Deceleration:** still display-link-driven (not touch-driven), so it replays against the recorded decel `frames`' dt timeline, seeded by the recognizer's release velocity.
- **Gate:** replay `contentOffset` vs recorded `frames` (`maxDivergence`) — now expected ~1px with **no** alignment/seeding shims.

## Scope
- **In:** touch recording, `PanRecognizer` (translation + velocity), W1/W2 calibration, Layer-1 validation, rewiring drag + handoff, re-recording the 4 gestures with touches.
- **Out (phase 2):** directional lock / X-axis (the 20°/70° angle gates are decoded — additive later); multi-touch (centroid already handles it; we record single-finger gestures).

## Risks
- **`_adjustSceneReferenceLocation` transform:** for a full-screen scroll view the scene-ref → view transform is ~identity, and `location(in:)` already returns view coords, so reproducing in view space should match `translation(in:)`. The Layer-1 validation catches it if not (then we model the adjustment).
- **Calibration assumes the 2-sample blend:** the fit residual being ~0 is the proof; if it isn't, the velocity model needs revisiting (e.g. >2 samples).
