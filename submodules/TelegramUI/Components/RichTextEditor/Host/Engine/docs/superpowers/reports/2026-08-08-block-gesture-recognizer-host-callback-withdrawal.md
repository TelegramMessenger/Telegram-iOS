# Block Gesture-Recognizer Host Callback Withdrawal Report

## Decision

`-[IDBlockTextView(PrivateInteractionCallbacks)
_textInputViewForAddingGestureRecognizers]` is a
`requiredNativeInteractionHost` on UIKitCore iOS 26.5 build 23F73. The method
and its single `IDInteractionHostABISpecs` row remain in ordinary builds.
This pass therefore makes no production private-selector reduction; it does
not describe retention as a reduction.

The paired withdrawn build was genuinely absent at the method, runtime, ABI,
and binary levels. It moved UIKit's interaction installation host from the
outer editor to `blockStack` and failed the mixed-BiDi handle-drag differential
twice: the custom selection ended at `{15,5}` while stock ended at `{15,2}`.
The ordinary retained build installed on `outer` and passed the same test
twice. The authorization record is
`Tests/Fixtures/BlockGestureRecognizerHostCallbackAuthorization-iOS26.5.json`.

Temporary method/ABI compile guards, pairing diagnostics, and all experiment
conditionals were removed after classification. The retained callback and ABI
row are unconditional ordinary source.

## UIKitCore recovery

All addresses below are file-relative addresses in UIKitCore from iOS 26.5
build 23F73. The complete pseudocode and xref ledger is in
`docs/hopper/UIKitCore-iOS26.5.md`.

| Address | Recovered role |
| --- | --- |
| `0x1615ff4` | `-[UITextView _textInputViewForAddingGestureRecognizers]`; returns the text view itself |
| `0x219d620` | selector stub for `_textInputViewForAddingGestureRecognizers` |
| `0x1566108` | `-[UITextInteractionAssistant setGestureRecognizers]`; contains the callback guard |
| `0x15661f8` | candidate-selector xref inside the guard path |
| `0x156460c` | `-[UITextInteractionAssistant initWithView:textInteractionMode:]` |
| `0x15663f4` | `-[UITextInteractionAssistant addGestureRecognizersToView:]`; graph installer |

The recovered fallback order is candidate callback, then
`externalInteractions.view`, then `textInputView`. With the block callback
retained, InputDec matches stock and installs on `outer`. With it absent,
UIKit falls through to `textInputView`, whose intentional block-editor value
is `IDBlockStackCanvasView`, and installs on `blockStack`.

## Topology evidence

The test-only topology snapshot observes `outer`, `blockStack`, and an optional
`external` host independently. It records presence and ancestry; recognizer
and interaction classes, identities, enabled state, and owners; baseline,
added, and removed identities; duplicate identity counts; the resolved
installation host; and live-host count. Schema version 1 also reports
`epochInstallationHost` and `stableForEpoch`.

Baseline reset freezes the identities for the current active epoch. A snapshot
is stable only when its installation host and identities still match that
baseline. UIKit legitimately replaces text-interaction identities during some
editable/selectable transitions, so transition checks require one correct
owner and no duplicates, then reset the epoch. Steady-state checks require
`stableForEpoch == true`.

Observed installation hosts were:

| implementation | installation host |
| --- | --- |
| stock `UITextView` oracle | `outer` |
| retained `IDBlockTextView` | `outer` |
| withdrawn `IDBlockTextView` | `blockStack` |

Graph teardown removes project text interactions but correctly leaves the
ordinary `UIScrollView` baseline interactions on `outer`. Teardown tests now
distinguish those retained baseline objects from leaked text-interaction graph
objects and still require assistant/view deallocation and zero duplicate
ownership.

## Differential classification

The withdrawn lifecycle and batched chrome paths initially remained green:

- `.gesture-host-withdrawal-task4-units-green2.xcresult`
- `.gesture-host-withdrawal-task4-lifecycle-green2.xcresult`
- `.gesture-host-withdrawal-task5-batched-ui-green2.xcresult`

The nine-test withdrawn touch matrix then passed 8/9 in
`.gesture-host-withdrawal-task5-touch-ui.xcresult`. Its sole failure was mixed
BiDi handle dragging. The failure was reproduced in isolation rather than
accepted as flake:

- withdrawn reproduction:
  `.gesture-host-withdrawal-task5-bidi-withdrawn-retry.xcresult`
- retained differential:
  `.gesture-host-withdrawal-task5-bidi-retained-differential.xcresult`
- retained confirmation:
  `.gesture-host-withdrawal-task5-bidi-retained-confirmation.xcresult`

Because the isolated semantic result followed callback presence and the host
changed exactly as UIKit's recovered fallback predicts, the stop condition was
met before running a redundant withdrawn floating-cursor matrix.

## Range-contract repairs discovered by live UIKit

The selectable/noneditable lifecycle revealed two UIKit-owned range forms
that the canonical controller must accept:

1. a foreign `UITextRange` wrapper whose two endpoints are live,
   document-owned `IDRichTextPosition` objects; and
2. a non-nil clear-selection range shell whose start and end are both nil.

`IDRichTextLayoutController` now accepts the first, normalizes the second to
`{0,0}`, and rejects a shell with exactly one nil endpoint. Native
`IDRichTextRange` validation and clipped projection use its stored endpoints
before consulting projection-sensitive public `start`/`end` accessors. This
preserves saturation for forged tracked endpoints and prevents projection
overflow while retaining strict document-identity validation.

The focused repair artifact
`.gesture-host-withdrawal-task7-focused-repairs.xcresult` passed 5/5.

## Permanent contracts

The required branch is protected by:

- `testBlockGestureRecognizerHostCallbackRemainsRequiredOnIOS265`;
- `testBlockGestureRecognizerHostRequirementInfrastructureIsExact`;
- `testBlockGestureRecognizerHostAuthorizationFixtureIsPinnedAndComplete`;
- runtime ABI/source audits that require the block method and its one ABI row;
- topology lifecycle, reconstruction, teardown, and deallocation contracts;
- the unchanged flat `IDTextView` provider and the protected block callbacks
  `interactionAssistant`, `selectionContainerView`, `isEditing`, and
  `_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:`.

Permanent focused evidence includes:

- `.gesture-host-withdrawal-task6-required-contracts.xcresult`;
- `.gesture-host-withdrawal-task6-authorization-green2.xcresult`;
- `.gesture-host-withdrawal-task6-floating-contract-green2.xcresult`;
- `.gesture-host-withdrawal-task6-permanent-focused-green2.xcresult` — 90/90.

An exact source audit found neither
`ID_WITHDRAW_BLOCK_GESTURE_RECOGNIZER_HOST_CALLBACK` nor
`ID_OMIT_BLOCK_GESTURE_RECOGNIZER_HOST_ABI` in ordinary app, text, private
bridge, test, script, project YAML, or generated-project source.

## Final verification

Every simulator XCTest invocation used simulator
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`, the repository simulator lock, and
`-parallel-testing-enabled NO`.

| Gate | Result | Artifact |
| --- | --- | --- |
| focused final repairs | 5 passed, 0 failed/skipped | `.gesture-host-withdrawal-task7-focused-repairs.xcresult` |
| complete unit suite | 991 passed, 0 failed/skipped | `.gesture-host-withdrawal-task7-all-units.xcresult` |
| exact touch/floating/lifecycle selector list | 27 passed, 0 failed/skipped in 844.69 s | `.gesture-host-withdrawal-task7-ui.xcresult` |
| fast semantic gate | 278 passed, 0 failed/skipped in 12.497 s; no retry | `.gesture-host-withdrawal-task7-fast/fast-text-input.xcresult` |
| optimized build | succeeded | `.gesture-host-withdrawal-task7-release-derived` |

The 27-test gate retained exact stock differential behavior for public caret
and selection geometry, mixed BiDi and reversal, both selection handles,
structural-boundary dragging, loupe tracking, top/bottom handle autoscroll,
floating-cursor normal and cancellation lifecycles, editable/selectable
transitions, selection extension and reversal, structural newlines, mixed
BiDi affinity, three reconstruction sessions, viewport autoscroll, and the
selectable/noneditable Copy-menu cancellation/reentry lifecycle.

The Release product is a universal x86_64/arm64 simulator binary. `nm -a` and
the Objective-C metadata each show one
`IDBlockTextView(PrivateInteractionCallbacks)` provider and one protected
`IDTextView(PrivateInteractionCallbacks)` provider per architecture. `strings`
finds no experiment token. This agrees with the runtime ABI contracts.

## Manifests, hashes, and hygiene

Manifest counts remain 127 minimal production members, 53 reference-only
members, and 24 test-only members. Neither behavior manifest owns this exact
block callback, so neither was changed.

| Protected/boundary file | Entry SHA-1 | Final SHA-1 |
| --- | --- | --- |
| production behavior manifest | `d2143fb0a8d056793885a4a1ea117d93a83fff59` | unchanged |
| test-only behavior manifest | `bca0b918c3d6f490772834379244a78f682d94c0` | unchanged |
| flat interaction callbacks | `03408d1ac1a25608e51a1e84ef637502cde49a1d` | unchanged |
| block interaction callbacks | `cb0b47126526278e137f00c2fb0383c8f3debe99` | unchanged after removing temporary guards |
| private UIKit bridge | `2e8a35602f29ecf51bcdd662163e92c06da77bd8` | `d1de0dd88495b735412647ee4c26e1abe40d8a70` (topology diagnostics) |
| authorization fixture | new | `f224b6f7b90ea83e758796b0dba3b77f8b8d2c0c` |

Additional final Git-object hashes for intentionally modified evidence files:

| File | SHA-1 |
| --- | --- |
| `PrivateUIKit/IDPrivateUIKit+Testing.h` | `acf8aa617ca69ea12d792dc76fa9d8b1b4b0ec15` |
| `App/IDDemoViewController.m` | `2c7effb976544c3cc6531054dc30eec7015e8f07` |
| `UITests/IDSelectionCallbackReductionUITests.m` | `2ba09edce1f7a5039ee77499fbd213189778d371` |
| `Tests/IDInteractionCallbackWithdrawalTests.m` | `410791170fe92b2d21d53d9b15e2f2081e6d2218` |
| `Tests/IDBlockTextViewIntegrationTests.m` | `f47a35884c6def9111d51070fcbc614df3b3d1a0` |
| `Tests/IDFloatingCursorContractTests.m` | `dae76b694add0f389220fce0c918a8dcdb70c8b1` |
| `Tests/IDProjectSmokeTests.m` | `8e0635eaa74dfc82fe15bcdcc0badea810e4b381` |
| `Tests/IDRichTextLayoutControllerTests.m` | `7b1616a38d017c86371056cc174a4e20f090a109` |
| `TextView/IDRichTextLayoutController.m` | `50210ad85ba0b4e1e7232097a3c8e6b6e56000bc` |

Two consecutive `xcodegen generate` invocations produced the identical
`InputDec.xcodeproj/project.pbxproj` SHA-256
`d1a77a8e3c96175f47de9c28ae3d557fdda7d53eb7c1d8906e1207404be7fe09`.
`git diff --check` passes and the Git index is empty. The pre-existing dirty
exploration tree and unrelated artifacts were preserved.

## Scope limitation

This authorization is only for UIKitCore iOS 26.5 build 23F73. The retained
callback must be re-characterized on every UIKit family before changing its
status. Nothing in this report proves that deletion is safe—or that the same
fallback failure exists—on iOS 16 through iOS 25.
