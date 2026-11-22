# Canvas Text-Container-Origin Callback Reduction Report

## Runtime and scope

This pass classified the two private text-container-origin callbacks on
`IDTextLayoutCanvasView` independently:

- `invalidateTextContainerOrigin`
- `textContainerOrigin`

The authoritative target was UIKitCore and UIFoundation from iOS 26.5 build
23F73. Runtime verification used iPhone 17 Pro simulator
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`. Every direct simulator XCTest command
was serialized through `Scripts/with-inputdec-simulator-test-lock.sh` and used
`-parallel-testing-enabled NO`.

The intended reduction boundary was only
`PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m`. Legacy text-view,
block-editor, block-layout, and context origin providers were explicitly out
of scope.

## Hopper caller graph

UIKitCore contains no implementations named
`-[_UITextLayoutCanvasView invalidateTextContainerOrigin]` or
`-[_UITextLayoutCanvasView textContainerOrigin]`. The selectors use shared
Objective-C message stubs:

| Selector | UIKitCore stub | ABI |
| --- | ---: | --- |
| `invalidateTextContainerOrigin` | `0x2227200` | `v@:` |
| `textContainerOrigin` | `0x22cec40` | `{CGPoint=dd}@:` |

UIKitCore's four local invalidation callers all target concrete
`_UITextContainerView` instances. That local graph was not sufficient to
classify the canvas bridge, however. A removal probe crashed in UIFoundation,
which supplied the missing cross-framework graph:

| UIFoundation procedure | Address/send | Receiver derivation |
| --- | ---: | --- |
| `-[NSLayoutManager(NSPrivate) _updateUsageForTextContainer:addingUsedRect:]` | `0x21d8c` / `0x21f5c` | Sends to the supplied container's `textView` after used-rect mutation |
| `-[NSLayoutManager(NSPrivate) _recalculateUsageForTextContainerAtIndex:]` | send `0x226ec` | Sends to the selected container's `textView` after recomputing usage |
| `-[NSTextLayoutManager updateLayoutWithTextLayoutFragment:addition:]` | `0x43b58` / `0x44178` | Sends to the `NSTextContainer` entry after updating its used rectangle |
| `-[NSTextContainer(NSPrivate) invalidateTextContainerOrigin]` | `0xa5460` / tail branch `0xa5464` | Loads the private text-view ivar at offset `0x10` and forwards the selector |

InputDec registers `IDTextLayoutCanvasView` as the `NSTextContainer` private
text view. The UIFoundation tail-forward therefore reaches the canvas during
ordinary TextKit 2 layout.

The decisive getter path is
`-[UITextInputController _characterPositionForPoint:]` at `0x15ec46c`, with
the send at `0x15ec584`. UIKit enumerates the layout manager's text
containers, calls `textView`, checks whether the arbitrary result responds to
`textContainerOrigin`, and subtracts the returned point before character hit
testing. InputDec's registered canvas is that result. The complete UIKitCore
getter caller table and receiver provenance are recorded in
`docs/hopper/UIKitCore-iOS26.5.md`.

## Before/after canvas inventory

The canvas category contained one implementation of each selector before the
pass:

```objc
- (void)invalidateTextContainerOrigin {
    [self id_invalidateTextContainerOrigin];
}

- (CGPoint)textContainerOrigin {
    return [self id_textContainerOrigin];
}
```

Both implementations remain unchanged after the pass. No selector was
renamed, moved, dynamically forwarded, resolved, or replaced. The before and
after canvas inventory is therefore:

| Canvas selector | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `invalidateTextContainerOrigin` | 1 | 1 | 0 |
| `textContainerOrigin` | 1 | 1 | 0 |

## Required non-canvas providers

The final source audit confirms that all required non-canvas providers remain:

- `IDTextView` supplies its text-container inset.
- `IDBlockStackCanvasView` converts its origin into the outer host.
- `IDBlockTextView` converts the block stack's origin into editor coordinates.
- `IDBlockLayout` supplies the per-block canvas-context origin.
- `IDPrivateCanvasContextTextContainerOrigin` reads the context origin used by
  rendering, attachment, emphasis, caret, selection, and viewport geometry.

The source-preservation contract also passed in
`.canvas-origin-task-6-final-contracts.xcresult`.

## Independent selector classifications

| Canvas selector | Classification | Reason | Decision |
| --- | --- | --- | --- |
| `invalidateTextContainerOrigin` | **externally-required** | UIFoundation forwards from the managed `NSTextContainer` to its registered private text view during TextKit 2 used-rect updates | Retain unchanged |
| `textContainerOrigin` | **externally-required** | `UITextInputController` and other geometry paths send to arbitrary registered coordinate hosts, including InputDec's canvas | Retain unchanged |

The initial UIKitCore-only invalidation classification was disproved by the
runtime removal probe. Removing the bridge caused
`NSInvalidArgumentException` in
`-[NSTextLayoutManager updateLayoutWithTextLayoutFragment:addition:]`. Local
UIFoundation disassembly then established the exact cross-framework receiver
chain above. The corrected classification and evidence were committed in
`148d5da`.

## Removed canvas callbacks

None. This pass found no safely removable member of the two-selector family.
No empty removal commit was created.

## Retained canvas callbacks

Both callbacks remain because both have external framework callers:

- `invalidateTextContainerOrigin` forwards to the project-owned layout
  invalidation entry.
- `textContainerOrigin` forwards to the project-owned context-origin getter.

The final runtime contract verifies that both selectors remain present with
two Objective-C arguments and the exact `void`/`CGPoint` return ABI.

## Project-owned origin and invalidation behavior

New semantic tests lock behavior without invoking or naming the private
selectors:

- `id_textContainerOrigin` returns the exact fractional context value and
  falls back to `CGPointZero` when the context is nil.
- `id_invalidateTextContainerOrigin` requests exactly one canvas layout.
- A nonzero `textContainerInset` places and sizes the canvas once, preserves
  the same origin through scrolling, and keeps viewport conversion in canvas
  coordinates.
- Source tests positively preserve every out-of-scope origin provider.

The characterization gate
`.canvas-origin-task-2-characterization.xcresult` passed 44 tests with zero
failures or skips in 3.071 seconds.

## Rendering, geometry, interaction, and backend evidence

| Gate | Evidence | Passed | Failed | Skipped | Duration |
| --- | --- | ---: | ---: | ---: | ---: |
| Pre-change geometry baseline | `.canvas-origin-task-1-baseline.xcresult` | 103 | 0 | 0 | 7.294 s |
| Retained callback focused gate | `.canvas-origin-task-4-retention-green.xcresult` | 47 | 0 | 0 | 3.696 s |
| Canvas rendering/geometry, checker oracle excluded | `.canvas-origin-task-5-canvas-geometry-excluding-checker.xcresult` | 69 | 0 | 0 | 2.709 s |
| Block/input geometry and backend parity | `.canvas-origin-task-5-input-geometry.xcresult` | 75 | 0 | 0 | 5.555 s |
| Final selector/source contracts | `.canvas-origin-task-6-final-contracts.xcresult` | 4 | 0 | 0 | 4.249 s |

The canvas gate covers fragment surfaces, invalidation, attachments,
emphasis, caret, selection, viewport, content size, and stock geometry. The
block/input gate covers independent block origins, insertion and navigation
geometry, interaction ownership, caret autoscroll, reference/minimal backend
behavior, and lifecycle stress.

No production repair was required after both callbacks were retained.

## Unit, fast, and keyboard gates

The complete unit run
`.canvas-origin-task-6-all-units.xcresult` executed 782 tests in 50.857
seconds:

- 776 passed;
- 6 methods failed;
- 0 skipped.

Five failures were the repository's documented checker-service condition.
The simulator's installed `UITextChecker` recognized the English misspelling,
but the native temporary spelling renderer produced zero red pixels. The
stock `UITextView` oracle and InputDec both produced zero. The exact
stock/custom parity method reproduced the same result in isolation in
`.canvas-origin-task-5-spelling-isolated-retry1.xcresult`.

The prescribed checker-excluded run
`.canvas-origin-task-6-units-excluding-checker.xcresult` executed 777 tests:
776 passed, and only the documented aggregate iPad demo-layout threshold
failed. The exact unmodified iPad method then passed in isolation in
`.canvas-origin-task-6-ipad-layout-isolated.xcresult` (1 passed, zero failures
or skips). No assertion was weakened.

The fast stock/reference/minimal differential
`.canvas-origin-task-6-fast/summary.json` passed 232 tests with zero failures
or skips in 11.683 seconds.

The real-system-keyboard runner
`.canvas-origin-task-6-keyboard/summary.json` passed all 24 sentinels with
zero failures or skips:

| Group | Passed | Duration |
| --- | ---: | ---: |
| English | 20 | 623.556 s |
| Japanese | 2 | 39.270 s |
| Chinese | 2 | 41.114 s |

The total runner wall duration was 781 seconds. The
`inline-accept-minimal` and `inline-dismiss-before-boundary` cases each used
one expected keyboard-readiness retry and then passed. Their first-attempt
artifacts remain under the corresponding `readiness-attempts/attempt-1`
directories.

## Known harness conditions

Two pre-existing simulator-wide conditions recurred:

1. Native spelling-marker drawing was unavailable for both stock and custom
   editors despite the English checker recognizing the word.
2. `testRegularIPadLayoutUsesHorizontalControlRowsAndReachableEditor` measured
   an editor height of 878 instead of greater than 900 only in the aggregate
   unit process; the exact method passed in isolation with unchanged code.

These results were retained as evidence. Tests and thresholds were not
changed, and neither condition implicates the canvas origin callbacks.

## Preserved private families

This pass did not change:

- text-container registration or private TextKit graph construction;
- `UITextInputController` and interaction-assistant integration;
- canvas rendering-surface callbacks;
- attachment and emphasis callbacks;
- viewport lifecycle or environment notification callbacks;
- block-layout canvas callbacks;
- autocorrection, inline prediction, IME, floating cursor, or autoscroll
  behavior;
- the project-owned `id_textContainerOrigin` or
  `id_invalidateTextContainerOrigin` methods.

## Deferred next reduction

The next reduction should select another narrowly bounded canvas callback
family and repeat the same cross-framework analysis. UIKitCore-local xrefs
must not be treated as complete when TextKit ownership crosses into
UIFoundation. No further origin reduction should be attempted: both members
of this family are now proven external ABI requirements.

## Commits

| Commit | Purpose |
| --- | --- |
| `cf6d93e` | Plan the canvas text-container-origin reduction |
| `b7595b1` | Record the initial UIKitCore caller classification |
| `f50dc87` | Lock project-owned origin and invalidation behavior |
| `6156bf0` | Add classification-dependent runtime/source contracts |
| `148d5da` | Correct the cross-framework classification and retain both callbacks |

The working tree contained unrelated user changes and historical result
artifacts throughout this pass. Only task-specific documentation and test
hunks were staged in the commits above; no result bundle or runner output was
staged.
