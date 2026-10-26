# Minimal Private Input Kernel Pass 1

Status: **Pass 1 complete on iOS 26.5 build 23F73**

## Evidence boundary

- Starting commit:
  `ec29c35c675876d9a11d2133e197221d1a59d95c`
  (`docs: plan minimal private input kernel pass 1`).
- Simulator: iPhone 17 Pro K3,
  `FA6F7462-AA97-42FE-9E57-8DA0593CE756`.
- Runtime: iOS 26.5, build `23F73`.
- The worktree already contained unstaged implementation, test, script,
  fixture, and Hopper-ledger changes when Pass 1 began. Those changes belong
  to the preceding IME/traits work and are not claimed by Pass 1.
- Generated `.xcresult`, log, summary, and audit files are retained locally
  and are not committed.

## Reference fast baseline

Command:

```sh
xcodegen generate
Scripts/run-text-input-fast.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  --output .minimal-kernel-pass1-baseline-fast
```

Result from
`.minimal-kernel-pass1-baseline-fast/summary.json`:

| Result | Passed | Failed | Skipped | Test duration |
| --- | ---: | ---: | ---: | ---: |
| Passed | 212 | 0 | 0 | 9.765 seconds |

This is the semantic reference control for the extraction. It includes the
existing stock/custom deterministic differential, lifecycle contracts,
inline-formatting differential, private-UIKit contracts, and source audits.

## Reference real-keyboard baseline

Command:

```sh
Scripts/run-text-input-keyboard-sentinels.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  --output .minimal-kernel-pass1-baseline-keyboard
```

Aggregate result from
`.minimal-kernel-pass1-baseline-keyboard/summary.json`:

| Result | Passed | Failed | Skipped | Wall duration |
| --- | ---: | ---: | ---: | ---: |
| Passed | 12 | 0 | 0 | 366 seconds |

All method summaries identify the pinned simulator, iOS 26.5, and build
`23F73`. English passed 10 methods, Japanese passed one, and Simplified
Chinese passed one. `inline-dismiss-before-boundary` used one authorized
keyboard-readiness retry and then passed. No semantic failure was retried.

The baseline covers:

- Autocorrection accept and pre-commit reject.
- Inline prediction accept and dismiss.
- Floating-cursor normal end and selection extension.
- Bold typing, autocorrection, prediction, and marked-text rich-trait
  preservation.
- Japanese Return commit followed by Undo.
- Simplified Chinese Pinyin candidate commit.

## Initial private-surface audit

Commands:

```sh
rg -n 'NSClassFromString|NSSelectorFromString|objc_msgSend|class_getInstanceVariable|object_getIvar|method_setImplementation' \
  App TextView PrivateUIKit Tests UITests \
  > .minimal-kernel-pass1-baseline-private-surface.txt
rg -n '_UITextLayoutControllerBase|_UITextKit2LayoutController|UITextInputController|UITextInteractionAssistant|UIAutoscroll|\+0x50' \
  App TextView PrivateUIKit Tests UITests docs/hopper \
  > .minimal-kernel-pass1-baseline-private-symbols.txt
```

The raw-operation audit contains 656 lines:

| Tree | Occurrences |
| --- | ---: |
| `PrivateUIKit` | 453 |
| `Tests` | 186 |
| `UITests` | 17 |
| `App` | 0 |
| `TextView` | 0 |

Counts by operation token are:

| Token | Occurrences |
| --- | ---: |
| `NSClassFromString` | 31 |
| `NSSelectorFromString` | 386 |
| `objc_msgSend` | 231 |
| `class_getInstanceVariable` | 8 |
| `object_getIvar` | 12 |
| `method_setImplementation` | 4 |

Production raw runtime access is already confined to `PrivateUIKit`, but is
not capability-scoped. Its coarse ownership is:

| Current file | Raw occurrences | Pass 1 classification |
| --- | ---: | --- |
| `IDPrivateUIKit.m` | 350 | mixed input, interaction, autoscroll, traits, checking, responder actions, reference layout, and test instrumentation |
| `IDPrivateUIKit+TextLayoutCanvas.m` | 82 | reference-only concrete canvas/rendering/attachment infrastructure |
| `IDPrivateUIKit+RichTextLayout.m` | 19 | input construction, incoming rich-layout ABI, annotations, temporary attributes, and cursor test trace |
| `IDBlockTextView+PrivateCallbacks.m` | 2 | incoming callback bridge |

The symbolic audit contains 246 lines. Stable token counts are:

| Token | Occurrences |
| --- | ---: |
| `_UITextLayoutControllerBase` | 12 |
| `_UITextKit2LayoutController` | 39 |
| `UITextInputController` | 130 |
| `UITextInteractionAssistant` | 64 |
| `UIAutoscroll` | 8 |

Task 4 will replace this coarse inventory with a one-owner-per-member
production manifest and a separate test-only manifest. These starting counts
are measurements, not claims that every occurrence is a distinct private
dependency.

## Known retained differences

The deterministic fast suite has no accepted semantic difference: its
normalized stock/custom comparisons are green.

One visual fact remains intentionally outside that semantic control. The
previous complete native spelling parity run measured 104 red marker pixels
for the custom editor and 162 for stock in the canonical word ROI, exceeding
the tolerance of 12. Separate native UI evidence proves spelling annotations
appear and clear correctly; the retained difference is dotted-marker density,
not missing checking, annotation cleanup, or geometry.

Floating-cursor evidence also permits previously characterized asynchronous
sample-boundary and terminal viewport-offset differences while requiring
identical logical selection, lifecycle completion, and quiescence. Pass 1 must
not broaden those tolerances or convert diagnostic capability data into a
semantic exemption.

## Pass 1 success comparison

At final certification, compare fresh stock/reference/minimal evidence against
this baseline:

```text
normalized(stock) == normalized(reference)
normalized(stock) == normalized(minimal)
normalized(reference) == normalized(minimal)
```

Success additionally requires the minimal compatibility surface to contain no
concrete UIKit layout controller, private canvas map, private rendering,
anchored attachment, or test-only contract.

## Final architecture result

Pass 1 adds an explicit behavior-backend boundary while leaving `reference`
as the public default. `minimal` constructs `UITextInputController` directly
over the clean-room `IDRichTextLayoutController`; it never constructs
`_UITextLayoutControllerBase` or `_UITextKit2LayoutController` and never
accesses the private `+0x50` canvas map. Layout, drawing, selection
presentation, and block structure remain project owned.

Private behavior is divided into ten strict capabilities:

| Capability | Members | Mode | Fallback |
| --- | ---: | --- | --- |
| `inputController` | 42 | mandatory | Reject construction before first-responder activation |
| `typingAttributes` | 9 | mandatory for the requested rich slice | Plaintext semantics when the rich capability is not requested |
| `incomingCallbacks` | 47 | mandatory | Reject construction before UIKit can call an incompatible host |
| `interaction` | 14 | optional | Project-owned selection presentation |
| `floatingCursor` | 3 | optional, depends on interaction | Ordinary selection |
| `autoscroll` | 3 | optional | Project scroll policy |
| `checking` | 2 | optional | Editing without native checking annotations |
| `prediction` | 1 | optional | Ordinary marked text |
| `paste` | 5 | optional | Project-owned paste path |
| `dictation` | 1 | optional | Phrase-text insertion |

Each capability is validated before activation. Reports distinguish
`unavailable`, `rejectedContract`, `available`, and `active`, include observed
ABIs and dependency/fallback data, and become detached snapshots during
teardown. Raw private lookup and messaging is confined to
`PrivateUIKit/BehaviorKernel` or the retained reference adapters; `TextView`
contains none.

## Final manifest inventory and delta

The deterministic final inventories are:

| Category | Members |
| --- | ---: |
| Minimal production capabilities | 127 |
| Minimal mandatory capabilities | 98 |
| Minimal optional capabilities | 29 |
| Reference-only concrete behavior | 53 |
| Test-only diagnostics | 15 |
| Concrete UIKit layout/canvas/rendering members reachable by minimal mode | 0 |

The production per-capability counts are shown in the architecture table
above. Of the 127 minimal entries, 125 are required within their selected
capability and two are selector-optional. Capability optionality is a
different axis: the complete 29-member interaction/floating/autoscroll/
checking/prediction/paste/dictation set can be masked independently.

The initial raw audit contained 656 runtime-operation occurrences and 246
symbol-reference lines. Those counts measured source occurrences rather than
distinct dependencies. The checked-in manifests replace that coarse count
with one owner per member. No selector moved between the production,
reference-only, or test-only manifest categories after the Task 4 inventory
was frozen in `f9b90d4`; later extraction changed call ownership, not manifest
classification. The final reference canvas-map provenance was refined from
the generic operation label `object_getIvar` to the occurrence-specific
`IDCanvasMap` adapter that owns the recovered `_textLayoutCanvasMap` access.
That is neither a moved selector nor a claimed surface reduction.

Sorted local inventories used for this comparison were generated from:

```text
PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json
Tests/Fixtures/UIKitBehaviorTestOnlyContracts-iOS26.5.json
.minimal-kernel-pass1-baseline-private-surface.txt
.minimal-kernel-pass1-baseline-private-symbols.txt
```

## Final source-audit result

At implementation head
`52d8fa896567d74c12edf8fd01c620cae5d8c7e2`, the required audits prove:

- No `_UITextLayoutControllerBase`, `_UITextKit2LayoutController`,
  `_UITextLayoutCanvasView`, `+0x50`, canvas getter, or canvas setter occurs
  in `PrivateUIKit/BehaviorKernel`.
- No `objc_msgSend`, `NSClassFromString`, `class_getInstanceVariable`, or
  `method_setImplementation` occurs in `TextView`.
- No `_internalTextLayoutController`, `UIKeyboardImpl`,
  `method_setImplementation`, or generic `object_getIvar` provenance occurs
  in the production manifest.
- The 53 concrete layout/canvas members remain explicitly reference-only.
- The 15 diagnostic inspection/swizzle members remain explicitly test-only
  and never contribute to a production capability report.

The source/manifest contract suite
`.minimal-kernel-pass1-task-13-contracts-complete2.xcresult` passed 118 tests
with zero failures or skips. It also verifies exact iOS/build metadata, unique
ownership, live source/evidence links, zero forbidden symbols in the behavior
kernel, zero raw runtime access in `TextView`, and the counts above.

## Final semantic and real-keyboard certification

The fresh final fast command was:

```sh
Scripts/run-text-input-fast.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  --output .minimal-kernel-pass1-final-fast-complete
```

`.minimal-kernel-pass1-final-fast-complete/summary.json` records `Passed`, 216
passed, zero failed, zero skipped, and 11.665 seconds of XCTest time. The
three-way stock/reference/minimal normalized semantic corpus has no accepted
difference.

The fresh final real-keyboard command was:

```sh
Scripts/run-text-input-keyboard-sentinels.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  --output .minimal-kernel-pass1-final-keyboard
```

`.minimal-kernel-pass1-final-keyboard/summary.json` records `Passed`, 24
passed, zero failed, zero skipped, and 784 seconds wall time. English passed
20 methods, Japanese passed two, and Simplified Chinese passed two. Every
method summary identifies simulator
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`, iOS 26.5, build `23F73`.
`inline-accept-minimal` and `inline-dismiss-before-boundary` used only the
runner's authorized keyboard-readiness retry; no semantic failure was
retried.

The final slice covers both reference and minimal backends for:

- Autocorrection acceptance and pre-commit rejection.
- Inline-prediction acceptance and dismiss-then-type.
- Floating-cursor normal completion and selection extension.
- Bold typing, correction, prediction accept/reject, and marked-text rich
  traits.
- Japanese Return commit followed by Undo.
- Simplified Chinese Pinyin candidate commit.

## Fault and lifecycle coverage

The optional fault matrix masks both absence and wrong ABI for interaction,
floating cursor, autoscroll, checking, typing attributes, prediction, paste,
and dictation. Mandatory input construction and delegate adoption reject
before first-responder activation. Lifecycle stress covers 500 editor
construct/activate/detach cycles plus 100 post-allocation interaction
constructor failures, including marked text, active selection, queued
selection display, and an unended floating cursor. Weak-owner and
delayed-callback checks pass, and detach remains idempotent and reverse
ordered.

## Scope boundary after Pass 1

This is an iOS 26.5/build 23F73 certification only. The Telegram port, iOS
16–25 UIKit-driver compatibility, limited TextKit 1 support, and further
private-surface reduction are deferred. No Telegram source or old-iOS path
was changed during Pass 1. Unrelated pre-existing worktree changes remain
outside this report and outside the Pass 1 commits.
