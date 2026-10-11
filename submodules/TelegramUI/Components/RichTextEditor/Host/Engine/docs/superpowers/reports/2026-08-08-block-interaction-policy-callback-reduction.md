# Block Interaction-Policy Callback Reduction

Date: August 8, 2026  
Runtime scope: iOS 26.5, build 23F73  
Simulator: `FA6F7462-AA97-42FE-9E57-8DA0593CE756`

## Outcome

Four private callbacks and their four interaction-host ABI requirements were
permanently removed from `IDBlockTextView`:

| Selector | Final decision | Missing-selector behavior |
| --- | --- | --- |
| `_updateSelectionGestures` | `safeFallback` | UIKit never sends this lifecycle selector to the duck-typed block host; project lifecycle uses `id_updateSelectionGestures`. |
| `_isInteractiveTextSelectionDisabled` | `safeFallback` | UIKit guards the hosted-delegate send and treats absence as `NO`. |
| `hasEditableSelection` | `safeFallback` | Recovered callers target UIKit's active `UITextSelection`, not the block host. Public `isEditable` remains authoritative for the hosted editor. |
| `_textKit2CanvasDidLayout` | `safeFallback` | The unconditional canvas-context send ends at `IDBlockLayout`; its second hop to the outer block host is guarded and absence is a no-op. |

This is true surface reduction, not runtime masking. The normal Release binary
has no corresponding `IDBlockTextView(PrivateInteractionCallbacks)` methods,
the interaction-host ABI table has no corresponding rows, and no forwarding or
dynamic-resolution substitute was added.

## Baseline

The worktree was already an exploration tree with unrelated tracked and
untracked changes. At entry the index was empty, `git diff --check` was clean,
and no XCTest process was active. The pass did not stage, reset, clean, commit,
or discard any of that state.

The focused baseline `.interaction-policy-reduction-task1-baseline.xcresult`
passed 83/83 with zero failures or skips. Baseline inventories were 127 minimal
production members, 53 reference-only members, and 24 test-only members.

| Baseline surface | Git object SHA-1 |
| --- | --- |
| production behavior contract | `d2143fb0a8d056793885a4a1ea117d93a83fff59` |
| test-only behavior contract | `bca0b918c3d6f490772834379244a78f682d94c0` |
| `IDBlockTextView+PrivateCallbacks.m` | `c1f85e5fa731d5d4f572762ea1c015d3d4b251f2` |
| `IDBlockTextView+Interaction.m` | `a542a4eedc08b79729855a767ad23aa32481344d` |
| `IDBlockLayout+PrivateCanvasCallbacks.m` | `0afc81e2e1166bbbb2a9435d1e37a423e0d6ef09` |
| `IDTextLayoutCanvasView+PrivateCallbacks.m` | `2570e3906e08e2ee83d373371c853a6887b1a134` |
| block interaction callbacks before the four deletions | `02a187788a2d2f2856518a0cdde1af6feada694d` |
| private UIKit bridge before the four ABI deletions | `3acf9af1ad33424179d640bb2fe0270723114afe` |

The last two values were verified from the exact pre-deletion method and ABI
rows retained in the source diff; the six protected non-target hashes were
unchanged at the final audit.

## Hopper recovery

The selected Hopper document was UIKitCore from iOS 26.5 build 23F73. All
addresses are file-relative. Full pseudocode, stub xrefs, receiver derivations,
and fallbacks are recorded under “Block interaction policy callback reduction
evidence” in `docs/hopper/UIKitCore-iOS26.5.md`.

| Selector | Implementation / stub | Recovered ownership and guard |
| --- | --- | --- |
| `_updateSelectionGestures` | `-[UITextView _updateSelectionGestures]` `0x161d01c`; stub `0x21acb60` | All relevant sends use concrete `UITextView`/`UITextField` lifecycle receivers. |
| `_isInteractiveTextSelectionDisabled` | `-[UITextView _isInteractiveTextSelectionDisabled]` `0x1610d88`; stub `0x2151cc0` | `UITextInteractionAssistant` probes the hosted delegate at `0x15664c4`, sends at `0x15664d0`, and supplies `NO` at `0x15664dc` when absent; assistant policy is at `0x1563840`. |
| `hasEditableSelection` | `-[UITextSelection hasEditableSelection]` `0x1576314`; stub `0x220c8a0` | Text-system xrefs use the active UIKit selection object. No recovered edit-menu, responder-action, Writing Tools, or selection path sends it to the editor host. |
| `_textKit2CanvasDidLayout` | `-[_UITextContainerView _textKit2CanvasDidLayout]` `0x1624f28`; no-op `-[UITextField _textKit2CanvasDidLayout]` `0x15c2fcc`; stub `0x219d740` | The stub's sole xref is the unconditional send at `0xc08580` in `-[_UITextLayoutCanvasView _viewportDidLayout]` to the canvas context. InputDec's canvas context is `IDBlockLayout`; only its guarded, no-op-fallback second hop could reach the outer editor. |

Static recovery classified all four as eligible for a real paired-withdrawal
experiment. It did not by itself authorize deletion.

## Paired experiment controls

Each candidate had a method-withdrawal control and a matching ABI-row control.
The controls allowed exactly one selector per experimental build. Eight
negative compile probes proved that neither half could be enabled alone:

| Selector | Method-only result | ABI-only result |
| --- | --- | --- |
| `_updateSelectionGestures` | selector-specific “withdrawal controls must be paired” compile failure | same compile failure |
| `_isInteractiveTextSelectionDisabled` | selector-specific pairing compile failure | same compile failure |
| `hasEditableSelection` | selector-specific pairing compile failure | same compile failure |
| `_textKit2CanvasDidLayout` | selector-specific pairing compile failure | same compile failure |

Test-first contract artifacts for the four controls each failed 0 passed / 1
failed before the control existed, then passed 1/1 after implementation:

- `.interaction-policy-reduction-task2-update-gestures-{red,green}.xcresult`
- `.interaction-policy-reduction-task2-interactive-disabled-{red,green}.xcresult`
- `.interaction-policy-reduction-task2-editable-selection-{red,green}.xcresult`
- `.interaction-policy-reduction-task2-canvas-layout-{red,green}.xcresult`

The source-control audit likewise progressed from
`.interaction-policy-reduction-task2-source-red.xcresult` to
`.interaction-policy-reduction-task2-source-green.xcresult`.

## Differential authorization

Every true-absence variant removed both the method and ABI row. The unit gates
were:

| Withdrawn selector | Unit result |
| --- | --- |
| `_updateSelectionGestures` | 26 passed, zero failed/skipped |
| `_isInteractiveTextSelectionDisabled` | 26 passed, zero failed/skipped |
| `hasEditableSelection` | 26 passed, zero failed/skipped |
| `_textKit2CanvasDidLayout` | 34 passed, zero failed/skipped |

The stock/custom action oracles passed 2/2. The live UI evidence was run
serially with real UIKit interaction ownership:

| Withdrawn selector | Common UI | Selector-specific UI |
| --- | ---: | ---: |
| `_updateSelectionGestures` | 2/2 | 4/4 |
| `_isInteractiveTextSelectionDisabled` | 2/2 | 4/4 |
| `hasEditableSelection` | 2/2 | 4/4 |
| `_textKit2CanvasDidLayout` | 2/2 | 8/8 |

These gates covered native handles, loupe, selection geometry, floating cursor,
autoscroll, editable/selectable transitions, responder actions, canvas layout,
and independent-block scrolling. No isolated confirmation failure existed for
any candidate; therefore none was classified `required`. The fixed-order final
authorization fixture is
`Tests/Fixtures/BlockInteractionPolicyCallbackAuthorization-iOS26.5.json`.
Its contract was first red in
`.interaction-policy-reduction-task4-authorization-red.xcresult` and then green
1/1 in `.interaction-policy-reduction-task4-authorization-green.xcresult`.

## Permanent deletion

The permanent runtime contract was deliberately red before deletion. It
reported the four methods, four `respondsToSelector:` results, and four ABI rows
still present (12 failing assertions) in
`.interaction-policy-reduction-task5-runtime-red.xcresult`. The permanent
source audit was independently red in
`.interaction-policy-reduction-task5-source-red.xcresult`.

The four Objective-C methods, four ABI rows, all experiment controls, pairing
diagnostics, and compile-only helper branches were then deleted. The focused
normal-build gate passed 16/16 in
`.interaction-policy-reduction-task5-permanent-focused.xcresult`.

## Final verification

| Gate | Result |
| --- | --- |
| complete `InputDecTests` | 976 passed, zero failed/skipped in `.interaction-policy-reduction-task6-all-units.xcresult` |
| exact high-fidelity consumers | 19 passed, zero failed/skipped in `.interaction-policy-reduction-task6-consumers.xcresult` |
| fast semantic gate | 272 passed, zero failed/skipped in 14.82 seconds; no retry |
| optimized Release simulator build | succeeded for arm64 and x86_64 |

The first complete-unit attempt exposed an adjacent pre-existing semantic
coupling rather than a callback dependency: `IDBlockTextView -selectAll:` used
menu availability as a direct-call precondition, while stock `UITextView`
allows programmatic `selectAll:` off first responder even though the menu action
is unavailable. The failed run had 973 passed and 2 failed. A stock
characterization was red in
`.interaction-policy-reduction-task6-programmatic-select-all-red2.xcresult`.
The minimal repair made direct `selectAll:` delegate to the interaction
capability without changing `canPerformAction:`; four focused contracts then
passed in `.interaction-policy-reduction-task6-select-all-repair-green.xcresult`
before the clean 976-test rerun.

The arm64 Release symbol audit found:

```text
present -[IDBlockTextView(PrivateInteractionCallbacks) selectionContainerView]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) _updateSelectionGestures]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) _isInteractiveTextSelectionDisabled]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) hasEditableSelection]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) _textKit2CanvasDidLayout]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) customRenderController]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) _convertPointFromRenderSpace:]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) _selectionContainerViewAboveText]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) _existingSelectionContainerView]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) _placeSelectionContainerView]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) _updateInteractionGeometry]
present -[IDTextView(PrivateInteractionCallbacks) _updateSelectionGestures]
present -[IDTextView(PrivateInteractionCallbacks) _isInteractiveTextSelectionDisabled]
present -[IDTextView(PrivateInteractionCallbacks) _textKit2CanvasDidLayout]
present -[IDBlockLayout(PrivateCanvasCallbacks) _textKit2CanvasDidLayout]
present -[IDTextLayoutCanvasView(PrivateCallbacks) _textKit2CanvasDidLayout]
```

No `ID_WITHDRAW_BLOCK_*`, `ID_OMIT_BLOCK_*`, or pairing-diagnostic string is in
the Release binary. Source and runtime contracts prove the block ABI rows and
forwarding substitutes are absent even though selector spellings correctly
remain for protected flat/canvas providers.

Final inventories remain 127, 53, and 24. Final Git object hashes are:

| Surface | Final SHA-1 |
| --- | --- |
| production behavior contract | `d2143fb0a8d056793885a4a1ea117d93a83fff59` |
| test-only behavior contract | `bca0b918c3d6f490772834379244a78f682d94c0` |
| `IDBlockTextView+PrivateCallbacks.m` | `c1f85e5fa731d5d4f572762ea1c015d3d4b251f2` |
| `IDBlockTextView+Interaction.m` | `a542a4eedc08b79729855a767ad23aa32481344d` |
| `IDBlockLayout+PrivateCanvasCallbacks.m` | `0afc81e2e1166bbbb2a9435d1e37a423e0d6ef09` |
| `IDTextLayoutCanvasView+PrivateCallbacks.m` | `2570e3906e08e2ee83d373371c853a6887b1a134` |
| `IDBlockTextView+PrivateInteractionCallbacks.m` | `cb0b47126526278e137f00c2fb0383c8f3debe99` |
| `IDPrivateUIKit.m` | `2e8a35602f29ecf51bcdd662163e92c06da77bd8` |
| authorization fixture | `499995aa215aafe7f19b77a86d8d068e766cb2a0` |

Two consecutive `xcodegen generate` runs produced
`0a8c4fdfd2840fafcfb238be0b5d67f11e8dddfc25cd307633e91e2b6a6eb0d9`.
The only generated-project delta from the clean baseline is the planned new
fixture: one file reference, one build-file reference, one fixture-group child,
and one test-resources entry. The pre-generation project hash was
`0d899d8134f9dcd59fa86ce98314a752602cdd8b1839e82651df3d20a14ff462`.
`git diff --check` passes and the index remains empty.

## Retained authority boundary and limitation

UIKit continues to own the input controller, interaction assistant, native
selection display, handles, loupe, floating cursor, and keyboard behaviors.
The project owns canonical block-document state, custom block layout and
drawing, public geometry, selection-presentation placement, vertical
autoscroll, and explicit `id_` lifecycle calls. The flat `IDTextView` private
providers and the inner block/canvas callback providers are intentionally
unchanged.

The authorization is specific to UIKitCore iOS 26.5 build 23F73 and the current
iOS 26 driver. Private receiver graphs, guards, or fallbacks can change on
another OS build. Cross-version support must retain per-version capability
preflight and repeat this same true-absence differential before applying these
conclusions to a different UIKitCore.
