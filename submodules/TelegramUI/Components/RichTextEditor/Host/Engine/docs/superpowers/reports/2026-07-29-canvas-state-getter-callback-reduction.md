# Canvas State-Getter Callback Reduction Report

## Runtime and scope

This Stage 1 pass was executed against UIKitCore and UIFoundation from iOS
26.5 build 23F73 on the pinned iPhone 17 Pro K3 simulator
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`.

The exact canvas selector family was:

- `textColor`
- `isEditable`
- `isEditing`

`textContainerUsageDidChangeToSize:` was explicitly excluded and remains a
separate notification pass. Telegram integration and TextKit 1 compatibility
remain deferred.

Every simulator XCTest invocation used
`-parallel-testing-enabled NO` and was serialized through
`Scripts/with-inputdec-simulator-test-lock.sh`. Differential and keyboard
runners use the same lock and nonparallel Xcode setting.

## UIKitCore and UIFoundation caller graphs

UIKitCore contains the following selector stubs:

| Selector | Stub | ABI | Complete UIKitCore sends |
| --- | ---: | --- | ---: |
| `textColor` | `0x22cea60` | `@16@0:8` | 91 |
| `isEditable` | `0x2229960` | `B16@0:8` | 75 |
| `isEditing` | `0x22299c0` | `B16@0:8` | 247 |

Relevant concrete or forwarding implementations include:

- `-[_UITextContainerView textColor]` at `0x1624ce0`
- `-[_UITextContainerView isEditable]` at `0x1624e14`
- `-[_UITextContainerView isEditing]` at `0x1624e50`
- `-[UITextInputController isEditable]` at `0x15e9364`
- `-[UITextInputController isEditing]` at `0x15e9398`
- `-[_UITextKit2LayoutController isEditable]` at `0xc41ce8`
- `-[UIResponder isEditable]` at `0x10c7ebc`
- `-[UIResponder isEditing]` at `0x10c7f08`

UIKitCore has no concrete `_UITextLayoutCanvasView` implementation for any
member of the family. The one statically visible concrete-canvas
`isEditing` send at `0xc09ccc` loads the canvas's weak context and gates the
hover-effects layer rather than sending to canvas `self`.

UIFoundation from the same runtime contains none of the three exact selector
names in Objective-C metadata, method lists, message stubs, strings, or full
disassembly. Its nearby `NSTextStorage._isEditing` selector is a distinct
family.

The complete static inventories were not sufficient for `isEditing`.
Post-removal runtime instrumentation exposed this live generic receiver path:

```text
-[IDTextLayoutCanvasView(PrivateCallbacks) isEditing]
-[UITextInputController isEditing]
-[UITextInputController _shouldHandleResponderAction:withSender:]
IDPrivateInputShouldHandlePaste
-[IDTextView(TextInputConformance) canPerformAction:withSender:]
```

The input controller's weak text-input receiver resolves to
`IDTextLayoutCanvasView` through InputDec's layout-controller/text-container
graph. That receiver provenance corrects the initial static assumption that
the input controller always forwarded state to the outer editor.

The complete address lists, receiver derivations, and return-value uses are
recorded in `docs/hopper/UIKitCore-iOS26.5.md`.

## Before/after canvas inventory

Before this pass, `IDTextLayoutCanvasView+PrivateCallbacks` owned all three
forwarders. After certification it owns only:

```objc
- (BOOL)isEditing {
    return [self id_isEditing];
}
```

The production delta removes two methods and eight net source lines:

- removed `textColor`
- removed `isEditable`
- retained `isEditing`

No removed selector was renamed, moved, dynamically resolved, or recreated
through a forwarding hook.

## Required non-canvas providers

The pass preserves public and project-owned providers on `IDTextView`,
`IDBlockTextView`, `IDBlockLayout`, interaction contexts, and UIKit
controllers. It also preserves all three project methods:

| Project method | Preserved semantics |
| --- | --- |
| `id_textColor` | exact context color; `UIColor.labelColor` for nil context |
| `id_isEditable` | exact context editability; `NO` for nil context |
| `id_isEditing` | exact optional context editing state; `NO` for nil or nonparticipating context |

## Independent getter classifications

| Canvas selector | Final classification | Decision |
| --- | --- | --- |
| `textColor` | concrete-UIKit-only | remove the canvas forwarder |
| `isEditable` | public-or-project-duplicate | remove the canvas forwarder; inherited `UIResponder.isEditable` may still answer normal lookup |
| `isEditing` | externally-required | retain the canvas-owned override and exact Boolean ABI |

The retained override is semantically significant. Inherited
`UIResponder.isEditing` reports whether the canvas itself is first responder;
InputDec's override reports the editing state of its context. UIKit's input
controller consumes the latter while deciding responder-action availability.

## Behavioral repair

The initial three-method removal passed focused state, rendering, interaction,
backend, rich-text, and IME checks, but the broader input gate exposed one
failure:

`IDTextViewTests/testCopyCutAndPasteAvailabilityAndMutations` returned `NO`
for paste availability after a successful cut.

The exact method reproduced in isolation. Restoring `isEditable` alone still
failed. Restoring `isEditing` alone passed and produced the live stack above.
The final partition and contracts were corrected per member; the other two
getters stayed removed.

An older attachment-coordinator test also assumed that both private editing
spellings forwarded to context. It was updated to exercise project-owned
`id_isEditable` and the retained private `isEditing` callback separately.
No production behavior was changed for that stale test.

## Rendering, interaction, responder, and backend evidence

| Gate | Result bundle | Passed | Failed | Skipped | Result interval |
| --- | --- | ---: | ---: | ---: | ---: |
| Pre-change focused baseline | `.canvas-state-getter-task-1-baseline.xcresult` | 130 | 0 | 0 | 2.781 s |
| Project semantic characterization | `.canvas-state-getter-task-2-characterization.xcresult` | 4 | 0 | 0 | 4.781 s |
| Rendering, canvas, invalidation, parity, and block view | `.canvas-state-getter-task-5-rendering.xcresult` | 110 | 0 | 0 | 5.279 s |
| Corrected editing, interaction, responder, backend, rich text, and IME | `.canvas-state-getter-task-5-input2.xcresult` | 77 | 0 | 0 | 2.687 s |
| Corrected selector and paste regression gate | `.canvas-state-getter-task-5-corrected-contracts-and-paste.xcresult` | 6 | 0 | 0 | 2.823 s |

The intentional initial contract RED and the failed removal probes are
retained as diagnostic artifacts. They are not final passing evidence.

## Unit, fast, and keyboard gates

| Gate | Evidence | Passed | Failed | Skipped | Duration |
| --- | --- | ---: | ---: | ---: | ---: |
| Complete `InputDecTests` | `.canvas-state-getter-task-6-all-units2.xcresult` | 798 | 0 | 0 | 19.001 s XCTest; 23.083 s result interval |
| Fast stock/reference/minimal differential | `.canvas-state-getter-task-6-fast/summary.json` | 236 | 0 | 0 | 13.586 s |
| Real system keyboards | `.canvas-state-getter-task-6-keyboard/summary.json` | 24 | 0 | 0 | 773 s wall |
| Final runtime/source contracts | `.canvas-state-getter-task-6-final-contracts.xcresult` | 8 | 0 | 0 | 0.012 s XCTest; 4.041 s result interval |
| Post-keyboard full-unit diagnostic | `.canvas-state-getter-task-6-final-verification.xcresult` | 792 | 6 unique methods | 0 | 47.771 s result interval |
| Post-keyboard checker-excluded corpus | `.canvas-state-getter-task-6-final-units-excluding-checker.xcresult` | 792 | 1 aggregate-only iPad method | 0 | 19.477 s result interval |
| Isolated iPad method | `.canvas-state-getter-task-6-final-ipad-layout-isolated.xcresult` | 1 | 0 | 0 | 2.181 s result interval |

The keyboard gate contains 20 English, 2 Japanese, and 2 Chinese sentinels.
Two English inline-prediction methods required a keyboard-readiness retry and
then passed on attempt two. The harness preserved those retry artifacts.

## Known harness conditions

- Simulator haptic-library warnings remain environmental and nonfatal.
- UIKit observation-feedback and outstanding-text-storage-change diagnostics
  occur in stock/custom differential tests without assertion failures.
- The complete unit target passed 798/798 before the real-keyboard harness.
  A fresh post-keyboard run then reported the five documented spelling-pixel
  methods plus the known aggregate-only iPad threshold. This is external
  checker/layout harness state, not a state-getter regression.
- With exactly those five spelling methods excluded, 792/793 passed and the
  iPad method was the sole failure. The exact unchanged iPad method then
  passed alone 1/1.
- Result bundles and runner outputs remain untracked and unstaged.

## Preserved private families

This pass did not change text-container origin, viewport, rendering-surface,
attachment, emphasis, selection, interaction, writing-tools, spelling,
environment, rich-text, prediction, IME, floating-cursor, or autoscroll
families.

## Deferred notification pass

`textContainerUsageDidChangeToSize:` remains implemented in
`IDTextLayoutCanvasView+PrivateCallbacks` and still forwards to
`id_textContainerUsageDidChangeToSize:`. Its classification and possible
reduction remain the next separate canvas callback pass.

## Commits

- `14afae1` `docs: classify canvas state getter callbacks`
- `9417242` `test: lock canvas state getter behavior`
- `a4bddb7` `test: require classified canvas state getter boundary`
- `51c42e7` `test: distinguish inherited canvas state getters`
- `57a7668` `refactor: remove redundant canvas state getters`
- `f123bc2` `fix: retain required canvas editing state`
- `7927b4f` `test: align canvas state forwarding contract`
