# Clean-Room Vertical Autoscroll Evidence Report

**Status:** Task 1 oracle frozen

**Reference runtime:** iOS 26.5 build 23F73

**Starting commit:** `076b9dad28263dd5371473334c96d1c77bdc2564`

## Scope and dirty-state boundary

This report accompanies the clean-room vertical-autoscroll implementation
plan. Task 1 records UIKit truth before any project-owned engine exists.

The starting worktree already contained unrelated edits in:

- `PrivateUIKit/IDPrivateUIKit.h`
- `PrivateUIKit/IDPrivateUIKit.m`
- `Tests/IDPrivateUIKitTests.m`
- `docs/hopper/UIKitCore-iOS26.5.md`

Those edits belong to the preceding text-input-traits work. Task 1 changes to
overlapping files are staged hunk-by-hunk. Generated `.xcresult` bundles are
local evidence and are not committed.

## Baseline

The initial combined baseline exposed one deterministic test-injection defect:
`testFocusedCollapsedSelectionPublishesOnceAfterSettledLayout` replaced
`view.id_interactionAssistant`, while commit `e975053` had moved
`selectionChanged` dispatch into `IDUIKitInteractionCapability`. The
capability therefore continued to call its original assistant and the spy saw
zero calls.

The test now temporarily replaces
`view.id_interactionCapability.privateAssistant`, which is the actual dispatch
owner. No production behavior changed. The isolated corrected test passed in:

```text
.vertical-autoscroll-baseline-collapsed-green.xcresult
```

The complete baseline was then rerun serially:

```sh
Scripts/with-inputdec-simulator-test-lock.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 -- \
  xcodebuild test \
    -project InputDec.xcodeproj \
    -scheme InputDec \
    -destination 'platform=iOS Simulator,id=FA6F7462-AA97-42FE-9E57-8DA0593CE756' \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    -resultBundlePath .vertical-autoscroll-task-1-baseline-green.xcresult \
    -only-testing:InputDecTests/IDPrivateUIKitTests \
    -only-testing:InputDecTests/IDBlockTextViewIntegrationTests \
    -only-testing:InputDecUITests/IDBlockTouchSelectionUITests/testTrailingHandleHeldAtBottomAutoscrollsAndExtendsSelection \
    -only-testing:InputDecUITests/IDBlockTouchSelectionUITests/testLeadingHandleHeldAtTopAutoscrollsAndExtendsSelection
```

Result: 75 passed, zero failed, zero skipped. Both physical leading/top and
trailing/bottom handle holds moved the viewport, extended the expected logical
endpoint, and quiesced after release.

## Test-only UIKit oracle

`IDPrivateUIKit` now exposes a test-only, ABI-checked boundary around real
`UIAutoscroll`. It can:

- Construct and start the UIKit object.
- Read `target`, `scrollContainer`, `point`, `directions`,
  `repeatInterval`, `count`, `active`, and `disabled`.
- Identify the active timer without retaining it in the returned snapshot.
- Set `disabled` and deterministically invoke `timerFired:` for ordering
  tests.
- Invalidate the object.

Every getter/control method has an explicit test-only manifest member.
Production manifests and runtime reports are unchanged. Test-only inventory
increased from 15 to 25 members.

The focused oracle result is:

```text
.vertical-autoscroll-task-1-oracle-controls-green.xcresult
55 passed, 0 failed, 0 skipped
```

The eight strict manifest/source-audit tests pass in:

```text
.vertical-autoscroll-task-1-manifest-green.xcresult
8 passed, 0 failed, 0 skipped
```

## Frozen UIKit truth

| Behavior | Observed iOS 26.5 rule |
| --- | --- |
| Target validation | Must respond to `updateAutoscroll:` |
| Container validation | Must be nonnil; optional `shouldAutoscroll` may reject |
| Scalar validation | Direction and repeat interval must both be nonzero |
| Disabled engine | Rejects and invalidates |
| Accepted start | Stores target/container/point/direction/interval, marks active, and schedules a repeating timer |
| Target ownership | Weak |
| Container ownership | Strong while active; released by invalidate |
| Coalescing | Same target and container, global point distance strictly below 70, same direction, equal interval |
| Coalesced mutation | Updates only the point |
| Threshold | Exactly 70 global points restarts |
| Coordinate space | Distance is measured after conversion to global coordinates |
| Timer | Immediate fire date, caller interval, current run loop, `NSDefaultRunLoopMode` |
| Tick order | Increments count before `updateAutoscroll:` |
| Restart count | Resets only when direction changes; interval-only restart preserves count |
| Invalidation | Idempotently clears timer and session state |
| Cadence sample | Immediate first callback and subsequent 75 ms callbacks within the declared 40 ms simulator tolerance |

These observations agree with the live Hopper assembly at:

```text
UIAutoscroll start      0x17c4f28
UIAutoscroll invalidate 0x17c5210
UIAutoscroll timerFired 0x17c52cc
UITextView start        0x161a040
assistant update        0x156a160
```

## Task 1 gate

Task 1 is complete when its scoped staged diff contains only:

- the corrected capability-owned test seam;
- the test-only UIKit oracle and truth tests;
- ten test-only manifest members and updated exact count;
- this report and the Hopper evidence update.

No clean-room production engine or minimal-backend routing is part of Task 1.

## Task 5 stock/mirror differential certification

The clean-room session engine was compared directly with iOS 26.5
`UIAutoscroll` through the ABI-checked test-only boundary. The comparator uses
a fresh UIKit engine and project engine for each of these 14 rows:

```text
valid start
zero direction
zero interval
policy rejection
coalesce at 0
coalesce at 69.999
cross-container global distance
restart at 70
direction change
interval change
two timer fires
target release
repeated invalidate
container release after invalidate
```

The rows compare acceptance, active/session state, stored point, direction,
repeat interval, count, target/container presence, timer coalescing versus
rescheduling, callback-visible count ordering, and ownership release. No
state-machine mismatch required an evidence-ledger clarification.

The same suite compares real repeating timers. The declared tolerances are
30 ms for the difference in first-fire latency and 25 ms for the difference
in median repeat interval; it does not compare exact wall-clock timestamps.

Authoritative result:

```text
.vertical-autoscroll-task-5-green.xcresult
2 tests passed, 0 failed, 0 skipped
14 state-machine rows
first-fire tolerance: 30 ms
median-interval tolerance: 25 ms
```

This is differential certification of the standalone engine only. Routing
the minimal editor backend through it remains a later task.

## Tasks 6–10 implementation outcome

Minimal mode now routes the UIKit assistant's `UITextAutoscrolling` entry
callbacks into `IDVerticalAutoscroll`. The project engine owns vertical-only
acceptance, public safe-band geometry, 75 ms cadence, scrolling, held-point
reprojection, logical endpoint extension, presentation publication, and
teardown. Reference mode continues to use the real iOS 26.5 `UIAutoscroll` as
the differential control.

The private surface after routing is:

| Category | Count |
| --- | ---: |
| Minimal production `UIAutoscroll` class/message operations | 0 |
| Minimal production private scroll-geometry reads | 0 |
| Minimal production assistant `updateAutoscroll:` sends | 0 |
| Retained private protocols | 1 |
| Retained incoming autoscroll callbacks | 2 |
| Retained assistant closure messages | 1 |
| Reference-only `UIAutoscroll` members | 3 |

The protocol is `UITextAutoscrolling`; the callbacks are
`startAutoscroll:` and `cancelAutoscroll`; the closure message is
`autoscrollWillNotStart`. The minimal manifest remains at 127 members
(98 mandatory and 29 optional): the old three-member concrete family was
replaced by a three-member entry boundary. The four eliminated private
geometry reads were implementation details, not separately counted manifest
members. The reference-only total is 56: 53 layout/canvas members plus three
legacy autoscroll members.

Implementation commits:

- `59802b4` — model private protocol entry capabilities
- `89b35bf` — add the clean-room engine
- `2e87a94` — mirror UIKit vertical geometry
- `8e0b5ae` — compare the clean engine with UIKit
- `82c0be0` — isolate the UIKit autoscroll entry
- `a8d29f7` — route minimal scrolling through the clean engine
- `18c30df` — extend the active logical endpoint
- `bfc040a` — complete lifecycle and teardown
- `4f83196` — certify physical vertical-autoscroll parity

## Physical trace certification

The serial physical matrix used a 2.5-second handle hold. Every trace showed
nonzero movement, one stable selection-container identity, a terminal inactive
sample, and no post-release offset or selection mutation.

| Direction/backend | Samples | Active | Median engine tick | Offset |
| --- | ---: | ---: | ---: | --- |
| Top/reference | 5 | 4 | 74.3 ms | 1297.3 → 8.0 |
| Top/minimal | 5 | 2 | 74.6 ms | 857.7 → 0.0 |
| Top/stock | 5 | 3 | callback sampled | 1296.3 → 0.0 |
| Bottom/reference | 5 | 3 | 74.2 ms | 11.7 → 1295.0 |
| Bottom/minimal | 5 | 2 | 67.7 ms | 212.7 → 1303.0 |
| Bottom/stock | 5 | 4 | callback sampled | 3.0 → 1303.0 |

Stock exposes assistant callback counts, not timer ticks, so its XCUI
observation interval is not reported as engine cadence. Reference/minimal
cadence divides elapsed observation time by engine tick-count delta.

Artifacts:

- `.vertical-autoscroll-task-10-physical-final.xcresult` — ten serial rows;
  nine passed, with one stock-only 0.5-point diagnostic tolerance failure.
- `.vertical-autoscroll-task-10-stock-top-tolerance.xcresult` — focused stock
  rerun passed after bounding the observed 2.07-point UIKit vertical
  handle-adjustment quantization at 3 points.
- `.vertical-autoscroll-task-10-backend-differential-green1.xcresult` —
  16/16 backend differential tests passed.
- `.vertical-autoscroll-task-10-ramp-unit-green2.xcresult` — 18/18 focused
  engine and selection-presentation tests passed.

## Task 11 final gates

Every simulator invocation was serial and used
`-parallel-testing-enabled NO`.

| Gate | Result | Artifact |
| --- | --- | --- |
| Exact manifest/minimal routing | 3 passed | `.vertical-autoscroll-task-11-manifest-focused-green.xcresult` |
| Scoped source/schema regressions | 4 passed | `.vertical-autoscroll-task-11-scoped-regressions-green.xcresult` |
| Fast semantic differential | 225 passed, 0 failed/skipped, 12.8 s | `.vertical-autoscroll-task-11-fast/summary.json` |
| Focused floating keyboard sentinels | 4 passed | `.vertical-autoscroll-task-11-sentinel-floating-*.xcresult` |
| Complete real-keyboard gate | 24 passed, 0 failed/skipped | `.vertical-autoscroll-task-11-keyboard/summary.json` |
| Complete unit suite | 730 passed, 25 failed | `.vertical-autoscroll-task-11-units-after-scoped-fixes.xcresult` |

The plan expected 216 fast cases; nine independently added editing scenarios
bring the current matrix to 225, and all 225 passed.

After fixing all seven unit failures attributable to this slice, 25
deterministic failures remain in unrelated in-progress dirty-tree work: one
native-spelling pixel comparison, 22 assertions in stale floating-cursor
contract tests that inject `id_interactionAssistant` instead of the current
`id_interactionCapability` owner, and two inline-formatting replacement
expectations. The representative forwarding test also fails in isolation at
`.vertical-autoscroll-task-11-unrelated-floating-isolated.xcresult`, so this
is not test-order contamination. Those concurrent files were preserved.

All 29 clean autoscroll engine/geometry tests, the 16 backend differentials,
the physical rows, the 225 fast cases, and the 24 real-keyboard methods are
green. This certifies the vertical-autoscroll slice but does not claim a
zero-failure global unit baseline for the unrelated dirty worktree.

The result is scoped to iOS 26.5 build 23F73. It does not claim cross-version
private-ABI compatibility. Horizontal autoscroll and the Telegram port remain
deferred.
