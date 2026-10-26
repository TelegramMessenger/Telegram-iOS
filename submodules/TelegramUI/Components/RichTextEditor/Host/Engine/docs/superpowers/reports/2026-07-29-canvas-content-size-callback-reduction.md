# Canvas Content-Size Callback Reduction Report

## Outcome

InputDec no longer implements or declares
`textContainerUsageDidChangeToSize:` or
`id_textContainerUsageDidChangeToSize:`. Canvas content size is now published
once, through the project-owned completed-viewport-layout path. The final
source inventory finds neither removed spelling in `App`, `TextView`,
`PrivateUIKit`, or `Tests`.

All final evidence was captured on the pinned iPhone 17 Pro K3 simulator,
UDID `FA6F7462-AA97-42FE-9E57-8DA0593CE756`, running iOS 26.5 build 23F73.
Every simulator XCTest command used `-parallel-testing-enabled NO` and the
repository's serialization lock.

## Removed private surface

The pass removed:

- `-[IDTextLayoutCanvasView(PrivateCallbacks)
  textContainerUsageDidChangeToSize:]`;
- `-[IDTextLayoutCanvasView id_textContainerUsageDidChangeToSize:]`;
- the project bridge declaration from
  `IDTextLayoutCanvasViewInternal.h`;
- the removed private selector from the broad private-callback smoke
  allowlist.

No forwarding, dynamic resolution, alternate spelling, or compatibility
alias recreates either method.

## Retained project-owned architecture

`textViewportLayoutControllerDidLayout:` remains the completed-layout
boundary. It invokes `id_updateContentSizeIfNeeded`, which reads
`usageBoundsForTextContainer`, validates the complete rectangle and its
derived maxima, clamps negative extents to zero, deduplicates against
`cachedContentSize`, and calls `contentSizeDidChange` only for a new valid
size.

`IDTextView` retains the public/project-owned host side:
`contentSizeDidChange` calls `id_applyCanvasContentSize:`, reconciling the
canvas frame and scroll content size. `IDBlockLayout` retains its independent
block sizing path. The removed callback is not replaced by another private
UIKit dependency.

## Hopper caller and receiver evidence

Hopper analysis of UIKitCore iOS 26.5 build 23F73 found the callback stub at
file-relative `0x22cec80` and three sends:

- `_UITextLayoutCanvasView updateContentSizeIfNeeded` at `0xc0a5a8`, with
  the send at `0xc0a624`, targets the canvas's separate `context` object;
- `UIFieldEditor _applyCorrectTextContainerSize:` at `0x15bb488`, with the
  send at `0x15bb5d4`, targets the concrete field editor;
- `UITextField textContainerUsageDidChangeToSize:` at `0x15c2fe8` forwards
  to its concrete field editor.

Concrete providers also exist on `UIFieldEditor`, `UITextField`, and
`_UITextContainerView`. None makes InputDec's custom canvas a receiver.
UIFoundation from the same runtime contains no matching selector string,
method metadata, implementation, or message stub.

## Runtime sender and ordering evidence

Temporary instrumentation covered viewport layout, insertion, deletion,
independent-block split and merge, and narrow-to-wide host reflow.
`.canvas-content-size-task-1-characterization.xcresult` passed 4/4 and
recorded 11 completed-layout publications.
`.canvas-content-size-task-1-reflow-characterization.xcresult` passed 1/1
and recorded 6 more. The private callback count was zero across all 17
completed-layout events. These are behavioral/runtime sender observations;
no rerun was required, and the temporary instrumentation was removed.

The pre-change behavioral baseline
`.canvas-content-size-task-1-baseline.xcresult` passed 105/105 with zero
failures and skips. No rerun was required.

## Geometry normalization contract

The project publisher accepts only a finite usage rectangle whose derived
maximum X and Y are also finite. It computes:

```text
width  = max(CGRectGetMaxX(usageBounds), 0)
height = max(CGRectGetMaxY(usageBounds), 0)
```

Invalid input leaves both `cachedContentSize` and the host unchanged.
Repeated valid sizes do not republish. This preserves origin-bearing usage
bounds rather than treating only `usageBounds.size` as the content extent.

The initial characterization bundle
`.canvas-content-size-task-2-characterization.xcresult` intentionally
reported 3 passed and 2 failed tests, with zero skips. The two expected RED
failures proved that the old callback path normalized nonfinite input
differently from the required completed-layout publisher. No rerun was
required to establish RED.

## Focused RED/GREEN evidence

`.canvas-content-size-task-3-contracts-red.xcresult` intentionally failed
2/2 selector/source contracts with zero skips while the callback and bridge
still existed. This was the expected static-structure RED state, not a build
failure.

After removal, `.canvas-content-size-task-4-focused-green.xcresult` passed
7/7 with zero failures and skips. The final repetition,
`.canvas-content-size-task-6-final-contracts.xcresult`, also passed 7/7.
Neither GREEN gate required a rerun. These bundles jointly prove runtime
publication semantics and the source/selector boundary.

## Canvas and host geometry verification

The GREEN contracts cover initial completed layout, origin-aware
normalization, invalid and overflow rejection, deduplication, and host
application. They also cover a return followed by backspace restoring the
original canvas/scroll geometry and width reflow settling to finite final
geometry.

The final exact-tree all-unit bundle
`.canvas-content-size-task-7-final-all-units.xcresult` passed 805/805 with
zero failures and skips. It includes the added IME host-layout geometry
contract. No rerun of this final unit bundle was required.

## Independent-block and rich-text verification

`.canvas-content-size-task-5-blocks.xcresult` passed 62/62 with zero
failures and skips. It covers independent-block layout, split/merge, block
view behavior, rich-text layout, and the completed-layout host path. No
rerun was required. This is behavioral evidence that block-local layout
continues to own its geometry independently of the removed canvas callback.

## Interaction, spelling, and rendering verification

The focused behavioral gates were:

| Evidence | Passed | Failed | Skipped | Scope | Rerun |
| --- | ---: | ---: | ---: | --- | --- |
| `.canvas-content-size-task-5-canvas-host.xcresult` | 81 | 0 | 0 | canvas and host geometry | no |
| `.canvas-content-size-task-5-rendering.xcresult` | 76 | 0 | 0 | fragments, attributes, attachments, spelling, invalidation | no |
| `.canvas-content-size-task-5-interaction.xcresult` | 44 | 0 | 0 | selection, gestures, responder, and scrolling interaction | no |

Together with the 62 block/rich-text tests, the focused pass executed 263
tests with no failures or skips.

## Full unit and fast results

| Evidence | Passed | Failed | Skipped | Kind | Rerun |
| --- | ---: | ---: | ---: | --- | --- |
| `.canvas-content-size-task-6-all-units.xcresult` | 804 | 0 | 0 | complete unit behavior before fixture repair | no |
| `.canvas-content-size-task-6-all-units-final.xcresult` | 805 | 0 | 0 | post-repair complete unit behavior | no |
| `.canvas-content-size-task-7-final-all-units.xcresult` | 805 | 0 | 0 | final exact-tree complete unit behavior | no |
| `.canvas-content-size-task-6-fast/summary.json` | 237 | 0 | 0 | fast semantic differential behavior | no |
| `.canvas-content-size-task-6-ios26-certification-retry3/fast/summary.json` | 238 | 0 | 0 | certification fast differential behavior | no |
| `.canvas-content-size-task-7-smoke.xcresult` | 98 | 0 | 0 | final project/source smoke | no |
| `.canvas-content-size-task-7-final-audit.xcresult` | 3 | 0 | 0 | final selector and source boundary | no |

The certification fast run took 11.54 seconds. The final exact-tree unit run
executed its tests in 17.96 seconds and completed in 19.62 seconds.

## Differential and real-system-keyboard results

The aggregate certification summary is
`.canvas-content-size-task-6-ios26-certification-retry3/summary.json`.
It reports `Passed` for 216 stock/custom comparisons and 432 host
executions:

| Child evidence | Logical rows | Comparisons/tests | Host executions | Result |
| --- | ---: | ---: | ---: | --- |
| `ime/summary.json` | 24 | 96 comparisons | 192 | passed |
| `autocorrection/summary.json` | 21 | 84 comparisons | 168 | passed |
| `inline-prediction/summary.json` | 9 | 36 comparisons | 72 | passed |
| `keyboard-sentinels/summary.json` | 24 | 24 tests | n/a | passed |

Each comparison matrix ran two repetitions in both stock-custom and
custom-stock order. The real-system-keyboard gate passed 20 English, 2
Japanese, and 2 Simplified Chinese sentinels with zero failures and skips in
741 seconds. A few inline-prediction methods used the harness's allowed
keyboard-readiness retry; the successful attempt and retry evidence are
preserved.

## Environmental reruns

The first certification retry exposed a pre-existing fixture mismatch:
unrelated inline-formatting work had made a 36-point formatting row visible
for every scenario. That changed the custom IME editor's geometry while the
stock host remained unchanged. The repair is isolated in commits `0cd8710`
and `9658b8c`; direct stock/custom geometry then matched.

The next attempt showed a simulator environment failure rather than a text
semantic mismatch. The simulator inherited host preferences
`AppleLanguages = [en-US, ru-PT]` and
`AppleLocale = en_US@rg=ptzzzz`; repeated boots regenerated a Russian
keyboard and sometimes made `ru_RU` active, so the expected Latin key was
absent. A temporary, untracked `xcrun` wrapper normalized only the pinned
simulator after boot. It survived five consecutive boot checks, and the
previously failing custom Japanese after-boundary cancel method passed 1/1
in
`.canvas-content-size-task-6-ime-after-boundary-cancel-custom-environment-green.xcresult`.
Host Mac preferences were never changed.

The top-level retry-3 command was later interrupted after 39 IME host
executions. The supported IME `--resume` path reused completed evidence; the
remaining IME, autocorrection, and inline-prediction matrices then ran under
the same global serialization lock and pinned environment. Exact child
summaries and the aggregate summary record the complete passing result.
The temporary wrapper was removed after certification.

## Worktree preservation

The repository began and ended this pass with unrelated tracked changes in
the block editor, IME scripts and fixtures, private UIKit support, tests, and
the Hopper notebook, plus many untracked diagnostic artifacts. They were not
discarded, reformatted, or folded into this reduction. Only callback-specific
hunks are staged for the final report commit. Result bundles remain untracked.

## Remaining private canvas surface

The callback category still contains private viewport lifecycle, text
container origin, editing-state, rendering-surface, attachment, interaction
geometry, hover, writing-tools, display invalidation, temporary-attribute,
and emphasis callbacks. This pass makes no new claim about those independent
families.

The content-size path itself retains no private notification selector. Its
remaining dependencies are the project method
`id_updateContentSizeIfNeeded`, public/project-owned block delivery, and
TextKit's `usageBoundsForTextContainer`.

## Recommended next reduction pass

Next, classify the attachment notification family
`didLayoutTextAttachmentView:inFragmentRect:`,
`didAddTextAttachmentViews:`, and `didRemoveTextAttachmentViews:` together.
It is a narrower coherent family with observable custom-renderer consumers
and can be tested independently without reopening the now-closed
content-size publication path.
