# Canvas Lifecycle Callback Reduction Report

## Runtime and scope

This pass was certified on iOS 26.5 build 23F73 using the `iPhone 17 Pro K3`
simulator (`FA6F7462-AA97-42FE-9E57-8DA0593CE756`) and the open UIKitCore
image in Hopper.

The scope was exactly:

- `_performViewportLayout:`
- `_viewportWillLayout`
- `_viewportDidLayout`
- `_removeUnusedElementViews`
- `updateContentSizeIfNeeded`
- `flushElementViews`

The removal applies to the shared `IDTextLayoutCanvasView` used by both the
reference and minimal behavior backends. No selector was renamed, moved to
another object, or retained behind a runtime adapter.

## Hopper caller graph

Hopper reproduced the following live UIKitCore stubs and complete caller
sets:

| Selector | Stub | Complete callers |
| --- | ---: | --- |
| `_performViewportLayout:` | `0x2165340` | `-[_UITextLayoutCanvasView textRangeForBounds:layoutIfNeeded:]`; `-[_UITextLayoutCanvasView layoutSubviews]` |
| `_viewportWillLayout` | `0x21b2600` | `-[_UITextLayoutCanvasView _performViewportLayout:]`; `-[_UITextLayoutCanvasView textViewportLayoutControllerWillLayout:]` |
| `_viewportDidLayout` | `0x21b25e0` | `-[_UITextLayoutCanvasView _performViewportLayout:]`; `-[_UITextLayoutCanvasView textViewportLayoutControllerDidLayout:]` |
| `_removeUnusedElementViews` | `0x21727e0` | `-[_UITextLayoutCanvasView flushElementViews]`; `-[_UITextLayoutCanvasView configureCustomTextRenderer]`; `-[_UITextLayoutCanvasView _viewportDidLayout]` |
| `updateContentSizeIfNeeded` | `0x22dcfa0` | `-[_UITextLayoutCanvasView _viewportDidLayout]`; `-[UITextView textInputDidChange:]` |
| `flushElementViews` | `0x22035a0` | `-[UITextView setCustomRenderController:]` |

Assembly receiver tracing—not caller names alone—classified all six as
concrete-UIKit-only:

- the `_UITextLayoutCanvasView` methods preserve entry `self` and send to it;
- both `UITextView` callers load the private `_containerView`, obtain its
  `canvasView`, and send to that retained result;
- no caller obtains an arbitrary
  `NSTextViewportLayoutControllerDelegate`;
- no caller can obtain an `IDTextLayoutCanvasView`.

InputDec is a direct `UIView` subclass and never instantiates UIKit's concrete
`_UITextLayoutCanvasView`. Exact instruction addresses and receiver registers
are retained in `docs/hopper/UIKitCore-iOS26.5.md`.

## Before/after source inventory

The pre-change production inventory contained 12 occurrences, all in
`PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m`:

- six category declarations;
- six forwarding implementations.

The post-change audit over `App`, `TextView`, and `PrivateUIKit` contains zero
occurrences. Runtime tests also prove that `IDTextLayoutCanvasView` neither
responds to nor owns a method for any of the six selectors.

These selectors were not enumerated members in the checked-in behavior
capability manifest, so the manifest member totals do not change. The
production source/runtime callback surface is nevertheless strictly smaller.

## Removed callbacks

The following compatibility bridges were deleted:

- the private viewport-layout wrapper that optionally published changed
  viewport bounds and then called `performViewportLayout`;
- private will/did viewport forwards;
- private unused-surface eviction and content-size forwards;
- the private flush forward.

The removal is shared by both behavior backends because both use the same
project canvas class and category. No backend-specific replacement was added.

## Retained public delegate path

`IDTextLayoutCanvasView (PrivateCallbacks)` still conforms to
`NSTextViewportLayoutControllerDelegate`.

The retained public delegate callbacks continue to forward directly to
project-owned lifecycle methods:

- `textViewportLayoutControllerWillLayout:` calls
  `id_viewportWillLayout`;
- `textViewportLayoutControllerDidLayout:` calls
  `id_viewportDidLayout`;
- the public viewport-bounds and rendering-surface delegate callbacks remain
  unchanged.

This preserves TextKit viewport participation without advertising the six
concrete UIKit canvas selectors.

## Project lifecycle ordering

New characterization probes verify that InputDec's independent state machine
remains canonical:

```text
performViewportLayout
  → will
  → evict
  → content
  → did
```

One explicit viewport pass completes exactly one transaction, increments
`completedViewportLayoutCount` once, and leaves
`performingViewportLayout == NO`.

Project flush remains:

```text
id_flushElementViews
  → evict
  → flush
```

It leaves zero visible surfaces, unused fragment keys, and unused external
surfaces. Existing recursive-entry coverage also remains green.

## Rendering, geometry, and attachment evidence

`.canvas-lifecycle-task-5-rendering.xcresult` executed 113 tests with:

- 113 passed;
- 0 failed;
- 0 skipped.

This gate covers fragment rendering, invalidation, custom render surfaces,
attachment coordination, anchored attachment geometry, block layout, canvas
parity, spelling annotation integration, and stock/custom block-view parity.
The native spelling-pixel assertions passed without changing their thresholds
or tolerances.

## Backend and lifecycle evidence

`.canvas-lifecycle-task-5-lifecycle.xcresult` executed 67 tests with:

- 67 passed;
- 0 failed;
- 0 skipped.

This gate covers canvas lifecycle, block editor integration, reference/minimal
backend behavior, minimal lifecycle release stress, interaction ownership,
inline formatting differential behavior, and IME composition lifecycle.

No test oracle depended on a removed selector, and no production or test-only
repair was required after removal.

## Unit, fast, and keyboard gates

All simulator invocations were serialized through the repository lock with
parallel testing disabled.

| Gate | Evidence | Passed | Failed | Skipped | Duration |
| --- | --- | ---: | ---: | ---: | ---: |
| Complete unit target | `.canvas-lifecycle-task-6-all-units.xcresult` | 766 | 0 | 0 | 18.140 s test time |
| Fast stock/custom differential | `.canvas-lifecycle-task-6-fast/summary.json` | 227 | 0 | 0 | 11.465 s test time |
| Real-system-keyboard sentinels | `.canvas-lifecycle-task-6-keyboard/summary.json` | 24 | 0 | 0 | 743 s wall time |
| Fresh post-keyboard unit target | `.canvas-lifecycle-task-6-final-units.xcresult` | 760 | 6 | 0 | 47.506 s result interval |
| Post-keyboard unit target excluding five checker methods | `.canvas-lifecycle-task-6-units-excluding-checker.xcresult` | 760 | 1 | 0 | 19.099 s result interval |
| Aggregate-order iPad method, isolated | `.canvas-lifecycle-task-6-ipad-layout-isolated.xcresult` | 1 | 0 | 0 | 1.980 s result interval |

The keyboard total comprises 20 English, 2 Japanese, and 2 Chinese
reference/minimal sentinels. The runner recorded two keyboard-readiness
retries before a green result:

- English `inline-accept-minimal`, attempt 1;
- English `inline-dismiss-before-boundary`, attempt 1.

Both retry artifacts remain under their method's
`readiness-attempts/attempt-1` directory. No assertion was weakened and no
test was skipped.

## Known harness conditions

The first complete unit run was fully green: all 766 tests passed. A fresh
complete run after the real-system-keyboard suite reproduced the two
previously documented simulator-state conditions:

- Five checker-pixel methods failed while waiting for native red spelling
  markers. The retained `spelling-diagnostics` attachment from
  `IDBlockTextViewParityTests` records `redTotal: 0` and no nonempty red rows
  for both the stock `UITextView` and InputDec editor over the same word and
  ROI. The checker-excluded invocation then passed 760 of 761 tests.
- The sole remaining failure was
  `testRegularIPadLayoutUsesHorizontalControlRowsAndReachableEditor`, whose
  aggregate-run editor height was 878 points against the existing
  greater-than-900 threshold. The exact unmodified method passed 1 of 1 when
  immediately rerun in isolation, classifying it as order-dependent.

Thus the fresh post-keyboard evidence contains no product-only spelling
divergence, no lifecycle-callback regression, and no skipped test. The tests,
thresholds, and assertions were not changed to obtain these results.

Simulator logs also contain normal system-owned diagnostics such as missing
simulator haptic pattern assets, transient text-storage layout warnings, and
keyboard service messages.

## Preserved private families

This pass did not change ownership or implementation for:

- text attachments and paragraph-anchored attachments;
- text emphasis and selection presentation;
- interaction assistant, loupe, handles, floating cursor, or edit menu;
- input-controller, typing-trait, checking, autocorrection, prediction, IME,
  paste, or dictation behavior;
- custom layout, fragment drawing, invalidation, or autoscroll;
- the reference-only concrete UIKit layout/canvas adapters.

The public viewport delegate category and every project-owned `id_*`
lifecycle method remain.

## Deferred next reduction

The next private-surface pass should select a new, independently bounded
callback family and repeat the same sequence:

1. live Hopper stub/caller/receiver proof;
2. semantic characterization independent of selector spelling;
3. runtime and production-source absence contracts;
4. reference/minimal differential and real-keyboard certification.

No additional callback is classified as removable by this report.

## Commits

- `094cf6f` — classify the six callbacks with live Hopper receiver evidence;
- `4717a98` — lock project lifecycle order and flush quiescence;
- `6bb75b4` — add runtime and production-source removal contracts;
- `a9eaa21` — remove the six private lifecycle callbacks;
- `57a0d5c` — certify the reduction with unit, differential, and keyboard
  evidence;
- the final verification addendum follows this document.
