# Minimal Direct Fragment Rendering Report

Date: 2026-07-29
Runtime: iOS Simulator 26.5 (23F73), iPhone 17 Pro
Simulator: `FA6F7462-AA97-42FE-9E57-8DA0593CE756`

## Runtime

InputDec already owned its fragment renderer. Both the reference and
minimal-kernel block editors realize the exact base project class
`IDTextRenderingSurfaceView`; neither needs a UIKit fragment-view subclass.

The private `isLayoutFragmentView` category method was removed from
`IDTextRenderingSurfaceView`. It was not forwarded, moved to an adapter, or
retained under another class. A production source audit over `App`,
`TextView`, and `PrivateUIKit` has zero definitions, sends, or string
references to that selector.

Focused runtime tests created visible surfaces through both behavior
backends, required at least one surface, asserted exact class identity, and
asserted that every surface does not respond to
`isLayoutFragmentView`. Both tests passed.

## Hopper callers

The iOS 26.5 UIKitCore image contains exactly two call sites for the
`isLayoutFragmentView` message-send stub at file-relative `0x222bd80`:

| Call site | UIKit caller | Effect when true |
|---|---|---|
| `0xc081c4` | `-[_UITextLayoutCanvasView _removeUnusedElementViews]` | Send `teardown` before removing a stale keyed view |
| `0xc083e8` | `-[_UITextLayoutCanvasView _viewportDidLayout]` | Send `setNeedsDisplay` to a realized keyed view |

The ordinary native surface implementation,
`-[_UITextLayoutFragmentViewBase isLayoutFragmentView]` at `0x5bed74`,
returns true. The paragraph-anchored wrapper implementation at `0xd0688c`
returns false.

InputDec does not run either UIKit canvas implementation. Its recovered
incoming callbacks forward to project-owned
`id_removeUnusedElementViews` and `id_viewportDidLayout` implementations.
Those implementations already know the contents of the project-owned keyed
surface map and directly perform teardown and redraw without querying the
marker. The marker therefore supplied no behavior to either InputDec
backend.

## Removed private ABI

The removed production surface was:

```objc
@implementation IDTextRenderingSurfaceView (RecoveredPrivateCallbacks)

- (BOOL)isLayoutFragmentView {
    return YES;
}

@end
```

No replacement production type or selector was introduced. This pass
reduces the private API surface by one incoming instance selector while
leaving the renderer, surface map, TextKit layout fragments, and drawing
implementation project-owned.

## Test-only oracle repair

Two tests had incorrectly reused the UIKit marker to discover InputDec
surfaces:

- The layout-canvas parity collector now uses
  `IDTextRenderingSurfaceView` class identity while inspecting InputDec and
  retains the marker query only while inspecting stock UIKit.
- The attachment coordinator test now asserts project surface class
  identity and marker absence instead of sending the removed selector.

The source/runtime contract tests separately prevent the production selector
from returning: the surface class must not install it, and production source
must contain no definition or send.

## Rendering, spelling, and geometry evidence

The focused surface, geometry, invalidation, attachment, and non-spelling
parity tests passed after the test-oracle repair. In particular:

- visible fragment surface count and frames matched stock within the
  retained one-display-pixel tolerance;
- before/after-scroll surface snapshots matched;
- selection and caret geometry matched;
- surface reuse, eviction, teardown, redraw, clipping, drawing, and
  attachment hosting remained green;
- reference and minimal editors both used exact
  `IDTextRenderingSurfaceView` instances without the marker.

The simulator's spell-checker service did not generate red underline pixels
for unit-test hosts during this run. The strict spelling tests were not
weakened:

- the stock/custom differential recorded both stock `UITextView` and
  InputDec at zero red pixels;
- a retry after the complete real-keyboard run produced the same result;
- five checker-dependent test methods consequently remain red in retained
  result bundles.

This is a missing shared oracle prerequisite, not an observed stock/custom
rendering divergence. The production change does not touch checking,
temporary attributes, layout-fragment drawing, or spelling annotations.

## Lifecycle and backend evidence

The focused lifecycle/backend gate passed 70 tests with zero failures and
zero skips. It covered:

- attachment providers and anchored attachments;
- emphasis and selection-container ordering;
- surface churn and removal;
- independent block layout and reflow;
- reference/minimal backend selection and fallback;
- behavior-kernel lifecycle and release stress;
- inline formatting differentials;
- IME lifecycle contracts.

No production repair was required after removal of the selector.

## Unit, fast, and keyboard gates

All simulator XCTest invocations were serialized and included
`-parallel-testing-enabled NO`.

| Gate | Result | Evidence |
|---|---|---|
| Production selector audit | Passed | Zero matches in `App`, `TextView`, or `PrivateUIKit` |
| Backend runtime contract | Passed | 2 passed, 0 failed, 0 skipped |
| Lifecycle/backend focus | Passed | 70 passed, 0 failed, 0 skipped |
| Complete unit invocation | Retained environmental failures | 756 passed, 6 failed methods, 0 skipped |
| Unit corpus excluding five checker-dependent methods and one separately exercised order-dependent layout method | Passed | 756 passed, 0 failed, 0 skipped |
| Isolated iPad demo-layout method | Passed | 1 passed, 0 failed, 0 skipped |
| Fast stock/custom differential | Passed | 226 passed, 0 failed, 0 skipped; 11.765 test seconds |
| Real-system-keyboard sentinels | Passed | 24 passed, 0 failed, 0 skipped; 743 wall seconds |

The complete unit invocation's sixth failure was an order-dependent demo
layout threshold (`878` observed versus `>900` expected). Its immediate
isolated rerun passed without code changes. The other five failed methods
were the checker-pixel family described above.

The keyboard runner recorded two recognized readiness retries:

- `inline-accept-minimal`, attempt 1;
- `inline-dismiss-before-boundary`, attempt 1.

Both passed on attempt 2. The final matrix comprised 20 English, 2 Japanese,
and 2 Simplified Chinese tests across reference and minimal backends.

## Preserved UIKit capabilities

This pass intentionally changed no ownership or implementation for:

- private canvas incoming callbacks;
- native selection presentation, selection containers, or handles;
- attachments, paragraph-anchored attachments, or emphasis surfaces;
- the UIKit input controller and checking controller;
- autocorrection, inline prediction, dictation, or IME composition;
- interaction assistants, loupe behavior, floating cursor, or selection
  gestures;
- custom TextKit layout, block composition, or fragment drawing.

The 226-test fast differential and 24-test real-keyboard matrix provide
end-to-end evidence that these retained capabilities continue to operate
through both behavior backends.

## Deferred Pass 2 work

The next reduction should begin with another Hopper-backed caller inventory
of the remaining private canvas callback cluster. A selector should be
removed only when all UIKit callers and InputDec forwarding paths prove that
project-owned code already supplies the behavior. Selection, attachment,
emphasis, input-controller, and interaction-assistant surfaces remain outside
this pass and must retain their existing differential gates.

The checker-service readiness issue should be treated as test-harness work:
preserve the strict pixel assertions and establish a deterministic stock
underline prerequisite before using the five spelling methods as a mandatory
aggregate gate.

## Commits

- `8d2e859` — `docs: plan minimal direct fragment rendering`
- `7c97560` — `docs: simplify direct fragment marker removal`
- `716494a` — `test: require clean fragment surface ABI`
- `e49fc21` — `fix: remove private fragment surface marker`
- `e478b09` — `test: certify marker-free fragment rendering`
