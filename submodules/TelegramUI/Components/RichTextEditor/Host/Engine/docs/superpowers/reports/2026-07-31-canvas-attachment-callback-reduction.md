# Canvas Attachment Callback Reduction Report

## Outcome

InputDec no longer implements, declares, forwards, dynamically sends, or
manifests the private UIKit attachment notification family:

- `didLayoutTextAttachmentView:inFragmentRect:`;
- `didAddTextAttachmentViews:`;
- `didRemoveTextAttachmentViews:`.

Attachment placement and viewport lifecycle are now owned by
`IDTextCanvasAttachmentCoordinator` and published through the weak, typed,
project-owned `IDTextCanvasAttachmentLifecycleSink` protocol. The final source
inventory finds none of the removed private spellings or their former helper
and contract identifiers in production or test sources.

All final runtime evidence was captured on the pinned iPhone 17 Pro K3
simulator, UDID `FA6F7462-AA97-42FE-9E57-8DA0593CE756`, running iOS 26.5 build
23F73. Every simulator XCTest invocation used `-parallel-testing-enabled NO`
and the repository serialization lock.

## Removed and retained private surface

The pass removed the three private receiver methods from the canvas,
text-view, and block-layout callback surfaces; their internal declarations;
the `IDPrivateCanvasDidLayoutAttachmentView`,
`IDPrivateCanvasDidAddAttachmentViews`, and
`IDPrivateCanvasDidRemoveAttachmentViews` dynamic-send helpers; and the
`reference.attachmentDidLayout`, `reference.attachmentDidAdd`, and
`reference.attachmentDidRemove` behavior contracts.

No alias, forwarding target, method resolver, notification, KVO path, or
alternate spelling recreates the removed family. Ordinary
`NSTextAttachmentViewProvider` placement and paragraph-anchored attachment
bounds, provider, drawing, enumeration, surface ownership, z-order, and hit
testing remain unchanged.

## Project-owned lifecycle architecture

`IDTextCanvasAttachmentCoordinator` is the sole owner of attachment view
identity, fragment-local frame assignment, previous/current viewport sets,
remove-before-add diffs, and flush. Its `lifecycleSink` is a weak
`id<IDTextCanvasAttachmentLifecycleSink>` reference.

The project protocol deliberately uses unrelated vocabulary:

```objc
- (void)id_attachmentView:(UIView *)view
    didLayoutInFragmentFrame:(CGRect)fragmentFrame;
- (void)id_attachmentViewsDidEnterViewport:(NSSet<UIView *> *)views;
- (void)id_attachmentViewsDidLeaveViewport:(NSSet<UIView *> *)views;
```

`IDTextLayoutCanvasView` binds a conforming context as the sink, records each
provider view after the rendering surface supplies its frame, and finishes the
viewport transaction once. `IDTextView` consumes the observations, while
`IDBlockLayout` forwards the same typed project protocol through its weak host
boundary. UIKit selector spellings are absent from this graph.

## Hopper caller and receiver evidence

Hopper analysis of UIKitCore iOS 26.5 build 23F73 found one live stock send
for each selector:

| Selector | Stock caller and send | Receiver | InputDec reachable |
| --- | --- | --- | --- |
| `didLayoutTextAttachmentView:inFragmentRect:` | `_UITextLayoutCanvasView` fragment-configuration block at `0xc09df4`, send `0xc09e40` | captured context of the concrete stock canvas | no |
| `didAddTextAttachmentViews:` | `-[_UITextLayoutCanvasView _viewportDidLayout]` at `0xc0825c`, send `0xc084dc` | the stock canvas's separate context | no |
| `didRemoveTextAttachmentViews:` | the same stock `_viewportDidLayout`, send `0xc084b0` | the same separate stock context | no |

The layout ABI is void return plus object and `CGRect`; arm64 passes the four
rectangle doubles in `d0`-`d3`. Add and remove are void return plus one object.
Concrete `_UITextContainerView` and `UITextField` implementations are no-ops;
`UISearchTextField` implementations are search-token-specific. InputDec owns
its viewport delegate and never enters the stock canvas implementations.
UIFoundation from the same runtime has no matching selector strings, method
metadata, implementations, or message stubs. Each selector was therefore
independently classified `safe-to-remove`.

## Runtime sender and ordering evidence

The pre-change baseline
`.canvas-attachment-callback-task-1-baseline.xcresult` passed 99/99. Temporary
instrumentation then covered ordinary provider placement, repeated layout,
viewport exit, coordinator flush, paragraph-anchored placement,
rendering-surface recovery, and independent-block forwarding.
`.canvas-attachment-callback-task-1-characterization-green1.xcresult` passed
7/7.

The characterization recorded 12 project layout events, three project enter
events, and two project leave events. It observed five private layout events
and one private add event, all immediately following the corresponding
project send and all received by `IDTextView`; it observed no UIKit-origin
sender. The initial characterization bundle contained no executed tests
because the simulator/Xcode launch did not establish the test session; the
preserved `green1` rerun is the behavioral evidence.

## Frame, identity, and batch contract

The rendering surface assigns the provider view's fragment-local frame before
the canvas enumerates it. The coordinator records the identical frame before
publishing the layout observation. Repeated layout preserves the view identity
and frame and does not duplicate an enter event.

At viewport completion, identity-set diffing publishes the immutable leave
batch before the immutable enter batch. A flush removes all previous and
current views from their superviews before publishing one immutable leave
batch. No mutable internal set escapes.

## Weak ownership and flush contract

The coordinator does not retain its lifecycle sink. Deallocating the sink
cannot create a coordinator/context cycle, and a later flush still removes
the owned views safely. Nil and nonconforming contexts produce no callback and
do not affect placement or cleanup.

## Independent-block forwarding

`IDBlockLayout` conforms to `IDTextCanvasAttachmentLifecycleSink` and forwards
the project methods through its existing weak host boundary. It preserves the
view identity, exact frame, immutable enter/leave sets, and event order. The
host is not retained, and deallocation is a safe no-op.

## Focused RED/GREEN evidence

| Evidence | Passed | Failed | Skipped | Meaning |
| --- | ---: | ---: | ---: | --- |
| `.canvas-attachment-callback-task-2-characterization.xcresult` | 25 | 0 | 0 | pre-change frame, identity, ordering, weak ownership, and block forwarding |
| `.canvas-attachment-callback-task-3-contracts-red.xcresult` | 0 | 3 | 0 | intentional RED: project protocol missing and private family still present |
| `.canvas-attachment-callback-task-4-green.xcresult` | 28 | 0 | 0 | first implementation GREEN |
| `.canvas-attachment-callback-task-4-focused-green2.xcresult` | 29 | 0 | 0 | complete typed-sink and removal GREEN |
| `.canvas-attachment-callback-task-6-final-contracts.xcresult` | 6 | 0 | 0 | exact contracts after real-keyboard state mutation |
| `.canvas-attachment-callback-task-7-final-audit.xcresult` | 4 | 0 | 0 | final protocol, receiver, source, and manifest audit |

The three RED failures were expected contract failures rather than build or
environment failures. They proved that the tests could detect both the absent
project protocol and the still-present private surface before implementation.

## Attachment and rendering verification

`.canvas-attachment-callback-task-5-canvas.xcresult` passed 88/88 and covers
the coordinator, canvas, editor, surface ownership, attachment provider
placement, scrolling, and flush. `.canvas-attachment-callback-task-5-rendering.xcresult`
passed 45/45 and covers fragment rendering, attributes, invalidation,
paragraph-anchored drawing, spelling, and attachment surfaces. Neither gate
reported a failure or skip.

## Interaction and rich-text verification

`.canvas-attachment-callback-task-5-interaction.xcresult` passed 48/48,
covering selection, gestures, responder, scrolling, interaction geometry,
autoscroll, and transient interaction. `.canvas-attachment-callback-task-5-blocks.xcresult`
passed 90/90, covering independent blocks, split/merge, rich-text layout,
typing attributes, and block-host forwarding. Both had zero failures and
skips.

## Full unit and fast results

The first complete unit run,
`.canvas-attachment-callback-task-6-all-units.xcresult`, reported 809 passed
and two failed structural inventory tests. The failures correctly identified
three removed manifest entries and the newly added public header count; they
were test-fixture drift, not runtime behavior failures. The narrow repair gate
first preserved two expected failures in
`.canvas-attachment-callback-task-6-audit-repair-green.xcresult`, then passed
2/2 in `...audit-repair-green2.xcresult` after the inventories were updated.

A fresh-derived-data complete rerun,
`.canvas-attachment-callback-task-6-all-units-green2.xcresult`, passed 811/811
with zero failures and skips. The bounded fast gate at
`.canvas-attachment-callback-task-6-fast/summary.json` passed 239/239 with
zero failures and skips in 13.659 seconds.

The final project smoke inventory
`.canvas-attachment-callback-task-7-smoke.xcresult` passed 99/99 with zero
failures and skips.

## Differential and real-system-keyboard results

The aggregate summary is
`.canvas-attachment-callback-task-6-ios26-certification/summary.json`. It
reports `Passed`, 216 stock/custom comparisons, and 432 host executions on
the pinned runtime:

| Child evidence | Logical rows | Comparisons/tests | Host executions | Result |
| --- | ---: | ---: | ---: | --- |
| `fast/summary.json` | 54 semantic scenarios | 239 tests | n/a | passed |
| `keyboard-sentinels/summary.json` | 24 | 24 tests | n/a | passed |
| `ime/summary.json` | 24 | 96 comparisons | 192 | passed |
| `autocorrection/summary.json` | 21 | 84 comparisons | 168 | passed |
| `inline-prediction/summary.json` | 9 | 36 comparisons | 72 | passed |

Every complete matrix ran two repetitions in both stock-custom and
custom-stock order. IME covered Japanese Romaji and Simplified Chinese Pinyin
candidate commit, cancellation, ordinary commit, boundary positions,
return/undo, and responder loss. Autocorrection covered acceptance by space,
punctuation, and candidate, pre-commit rejection, and immediate post-commit
undo at interior and both block boundaries. Inline prediction covered accept,
dismiss-then-type, and accept-then-delete at the same positions. The inline
matrix completed every host on attempt 1.

## Environmental reruns

The initial top-level certification process was interrupted after the fast
and keyboard-sentinel gates and part of IME. The supported IME `--resume`
path skipped only complete preserved comparisons and finished the exact
96-comparison/192-host matrix. The runner used its ordinary keyboard-readiness
retry for two English inline sentinel rows; both later passed and all attempts
remain preserved.

The top-level aggregate script still expects an older eight-sentinel suite,
while the unrelated current harness contains 24 sentinels. No dirty runner
file was edited. The complete child runners ran serially under the global
lock, and the aggregate was generated with the same validation logic but the
accurate 24-sentinel count. The aggregate retained the exact child paths,
runtime, UDID, rows, comparisons, and host executions.

## Worktree preservation

The repository began and ended this pass with unrelated tracked changes in
the block editor, IME provisioning and fixture work, private UIKit support,
tests, and the Hopper notebook, plus extensive untracked diagnostic result
bundles. They were not discarded, reformatted, staged, or folded into the
attachment reduction. Each implementation commit staged only task files or
hunks; the final notebook hunk is staged independently from its pre-existing
IME changes.

## Remaining private attachment surface

The removed lifecycle notification family has no retained ABI adapter. The
custom renderer still uses separate private paragraph-anchored attachment
capabilities: `frameForAnchoredTextAttachment:associatedLayoutFragment:`,
`boundsForTextParagraphAnchoredAttachment:`,
`textAttachmentViewProviderForTextParagraphAnchoredAttachment:`, provider
`view`, `drawTextParagraphAnchoredAttachment:bounds:context:`,
`supportsAnchoredTextAttachments`, and `anchoredTextAttachments`. Those APIs
enable bounds discovery, view providers, drawing, and enumeration rather than
viewport lifecycle notification and were deliberately out of scope.

## Recommended next reduction pass

Classify `frameForAnchoredTextAttachment:associatedLayoutFragment:` next. It
is the narrowest remaining canvas-side attachment callback and can be tested
against the already locked ordinary/paragraph-anchored frame, scroll, and
provider identity contracts. If it is project-only vocabulary, replace it
with a typed project geometry seam before considering the deeper fragment
bounds/provider/drawing helpers as a separate family.
