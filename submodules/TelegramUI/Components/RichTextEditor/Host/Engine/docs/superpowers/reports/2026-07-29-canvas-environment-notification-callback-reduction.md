# Canvas Environment Notification Callback Reduction Report

## Runtime and scope

This reduction targets UIKitCore from iOS 26.5 build 23F73 and InputDec's
`IDTextLayoutCanvasView`. It removes only the private
`isEditingDidChange`, `observeEnclosingScrollView`, and `_traitsChanged`
forwarders after tracing every UIKit entry to a concrete UIKit-owned canvas.
No selector was renamed, moved, dynamically resolved, or replaced through
forwarding.

All retained evidence used iPhone 17 Pro simulator
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`. Every direct simulator test disabled
parallel testing and ran through the repository's simulator lock.

## Hopper caller graph

| Selector | Stub/final implementation | Complete UIKit entry | Receiver proof | State effect |
| --- | --- | --- | --- | --- |
| `isEditingDidChange` | stub `0x22299e0`; implementation `0xc09150`; ABI `v@:` | `-[UITextView becomeFirstResponder]`; `-[UITextView _cleanUpForResignFirstResponder]` | Both callers load `UITextView._containerView`, send `canvasView`, and send to that retained concrete UIKit canvas at `0x160fa10` and `0x160fd44`. | Tail-calls `requestHoverEffectsUpdate` (`0xc09174`), which schedules layout only when the concrete `_hoverEffectsLayer` exists. |
| `observeEnclosingScrollView` | stub `0x2246720`; implementation `0xc06d28`; ABI `v@:` | `-[_UITextContainerView setEnclosingScrollView:]` | The caller stores its weak scroll view, loads its own `_canvasView` ivar, and sends at `0x1624db4`. `_UITextContainerView` is allocated only by `-[UITextView _newContainerViewWithFrame:textContainer:textLayoutController:]`. | If the concrete canvas context reports an overridden enclosing scroll view, installs a geometry-change observer. |
| `_traitsChanged` | registered action; implementation `0xc07e0c`; ABI `v@:` | `-[_UITextLayoutCanvasView configureCustomTextRenderer]` | The registration loads the selector at `0xc07d8c`–`0xc07d90` and passes preserved concrete canvas `self` as both receiver and target at `0xc07d94`–`0xc07da0`. | Reads the concrete canvas trait collection, updates custom-renderer display scale, and invalidates renderer display when needed. |

The trait action correctly has no direct message-stub caller. Its registration
and target registers are the caller proof. InputDec neither allocates
`_UITextContainerView` nor exposes its canvas through a stock `UITextView`
container.

## Before/after source inventory

Before removal, each private selector had exactly two production occurrences:
one declaration and one implementation in
`PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m`. The total private
source surface was six occurrences and three runtime instance methods.

After removal, the token-boundary scan across `App`, `TextView`, and
`PrivateUIKit` reports zero occurrences for all three selectors. Runtime
contracts report zero responding methods and zero `class_getInstanceMethod`
results.

The project-owned inventory remains:

- `id_isEditingDidChange`: declaration, implementation, and two direct
  `IDTextView` responder-transition calls.
- `id_traitsChanged`: declaration, implementation, and one direct
  display-scale trait-registration call.
- `id_observeEnclosingScrollView`: declaration and implementation only, with
  no production caller.

## Selector classifications

| Selector | Classification | InputDec reachability |
| --- | --- | --- |
| `isEditingDidChange` | `concrete-UIKit-only` | No UIKit caller can obtain an InputDec canvas; InputDec uses its direct `id_` entry. |
| `observeEnclosingScrollView` | `concrete-UIKit-only` | The sole receiver is `_UITextContainerView._canvasView`; InputDec does not construct that container. |
| `_traitsChanged` | `concrete-UIKit-only` | The registered target is the concrete `_UITextLayoutCanvasView` that owns the renderer token. |

## Removed callbacks

Commit `1da5b5b` deletes exactly three declarations and three forwarding
implementations from
`PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m`. No project behavior
or other production file changed in that commit.

## Retained callbacks

The project-owned `id_isEditingDidChange`, `id_traitsChanged`, and
`id_observeEnclosingScrollView` methods remain. All neighboring UIKit-facing
canvas callbacks remain unchanged, including viewport delegate entry,
rendering-surface creation/configuration, attachment coordination, emphasis
and writing-tools state, temporary-attribute invalidation, text-container
origin, context accessors, and interaction-geometry completion.

## Project-owned editing, trait, and dormant scroll behavior

Semantic probes established current behavior before removal:

- Editing change is quiescent without a hover layer and requests one layout
  when the hover layer exists.
- Trait change publishes `layout`, `display`, `layout`; the final layout is
  the existing consequence of canvas `setNeedsDisplay`.
- The dormant scroll hook publishes one viewport event followed by one layout
  event per explicit call.
- Attach, detach, and reparent calls produce three identical
  viewport/layout pairs, calculate the active host's viewport, return to
  canvas bounds while detached, and do not retain the former scroll host.
- First-responder transitions still hide and reveal the project hover layer
  through direct editor-owned editing calls.

`id_observeEnclosingScrollView` remains dormant. This pass did not invent KVO,
notifications, a scroll-host property, or a production caller.

## Rendering, geometry, lifecycle, and backend evidence

| Evidence | Result bundle | Passed | Failed | Skipped | Duration |
| --- | --- | ---: | ---: | ---: | ---: |
| Pre-change canvas baseline | `.canvas-environment-task-1-baseline.xcresult` | 85 | 0 | 0 | 2.781 s |
| Semantic characterization | `.canvas-environment-task-2-characterization.xcresult` | 39 | 0 | 0 | 3.236 s |
| Trait source boundary | `.canvas-environment-task-2-source-boundary.xcresult` | 1 | 0 | 0 | 2.163 s |
| Intentional RED absence contract | `.canvas-environment-task-3-red.xcresult` | 0 | 2 test methods | 0 | 2.465 s |
| Post-removal canvas/editor gate | `.canvas-environment-task-4-green.xcresult` | 41 | 0 | 0 | 2.703 s |
| Rendering, invalidation, attachment, parity | `.canvas-environment-task-5-rendering.xcresult` | 70 | 0 | 0 | 3.062 s |
| Interaction, lifecycle, backend parity | `.canvas-environment-task-5-lifecycle.xcresult` | 59 | 0 | 0 | 5.437 s |

The RED run produced six runtime assertion failures—two per selector—and one
source assertion failure whose only matches were the three methods in the
private callback file. The summary counts those as two failed test methods.
After removal, no repair was required.

## Unit, fast, and keyboard gates

| Gate | Evidence | Passed | Failed | Skipped | Duration |
| --- | --- | ---: | ---: | ---: | ---: |
| Complete unit target | `.canvas-environment-task-6-all-units.xcresult` | 775 | 0 | 0 | 21.027 s |
| Fast stock/reference/minimal differential | `.canvas-environment-task-6-fast/summary.json` | 230 | 0 | 0 | 11.316 s |
| Real-system-keyboard sentinels | `.canvas-environment-task-6-keyboard/summary.json` | 24 | 0 | 0 | 783 s wall |

The keyboard total comprises 20 English, 2 Japanese, and 2 Chinese tests.
Both reference and minimal paths passed.

## Known harness conditions

The keyboard runner retained readiness retries for
`english/inline-accept-minimal` and
`english/inline-dismiss-before-boundary`; each passed on its second attempt.
Simulator logs also contained familiar haptic-library, RTI-session, and UIKit
observation-feedback diagnostics without test failures.

All spelling-pixel tests passed in the complete unit run, so no checker
exclusion or shared zero-pixel diagnostic was needed. The iPad layout
exception path was also unnecessary.

## Preserved private families

This pass did not alter `UITextInteractionAssistant`, `UITextInputController`,
checking, autocorrection, prediction, paste, dictation, IME, fragment drawing,
autoscroll, selection presentation, attachments, emphasis, writing tools,
text-container usage, or text-container-origin callbacks. It also did not
change either UIKit behavior backend.

## Deferred next reduction

The bounded next candidate is the text-container-origin pair
`invalidateTextContainerOrigin` and `textContainerOrigin`. It requires its own
complete Hopper caller/receiver proof and semantic geometry baseline before
either selector can be classified; this report makes no removability claim.

## Commits

- `6270fd4` — `docs: classify canvas environment callbacks`
- `c8278a0` — `test: lock canvas environment notification behavior`
- `8599200` — `test: require project-owned canvas environment entry`
- `1da5b5b` — `fix: remove private canvas environment callbacks`
- This report is committed separately as
  `docs: certify canvas environment callback reduction`.
