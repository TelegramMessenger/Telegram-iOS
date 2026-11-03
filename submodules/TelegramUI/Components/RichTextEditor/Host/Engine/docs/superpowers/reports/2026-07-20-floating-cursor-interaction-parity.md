# Floating-cursor interaction parity on iOS 26.5

Status: **verified on the pinned simulator; private and runtime-specific**

## Outcome

`IDBlockTextView` now follows UIKit's floating-cursor pipeline across independent block layouts.
UIKit owns the keyboard trackpad gesture, native cursor/session, selection anchor and extent,
loupe/handles, and autoscroll timer. The clean-room editor owns canonical rich-document mapping,
per-block TextKit 2 layout, viewport publication, and the stable selection-presentation container.

The final current-head gate passed **209/209 with zero skips**. The inherited UI gate passed
**31/31 with zero skips**. The inherited parity gate passed **11/12**; its sole retained failure is
the pre-existing native spelling-pixel density difference (custom 104 red pixels, stock 162,
tolerance 12). Floating cursor, selection extension, structural-boundary, mixed-BiDi, scrolling,
and lifecycle methods all passed. After independent whole-slice approval, a fresh current-HEAD
bottom-edge selection-extension proof passed **1/1 with zero skips**.

This is not a general-device claim. Dark mode, Dynamic Type, landscape, iPad, physical devices,
autocorrection acceptance/rejection, inline prediction, IME, dictation, and hardware-key
navigation remain unverified.

## Runtime identity and evidence boundary

- Xcode 26.5 (`17F42`), iOS Simulator 26.5 (`23F73`), arm64.
- macOS 26.4 (`25E246`).
- iPhone 17 Pro simulator `404DA68C-E273-46A5-8F6C-B3BF556B80D6`.
- UIKit contracts are recovered from the iOS 26.5 simulator `UIKitCore` Hopper document.
- Addresses below are file-relative simulator-image offsets. They are not device VM addresses.
- The final pass consumed the established ledger; it did not independently reopen every Hopper
  procedure. No unavailable offset is reconstructed or inferred.
- A distinct keyboard floating-cursor cancellation selector was not recovered. That absence is
  recorded as live-runtime-only evidence, and no selector or ABI was invented.

## Recovered ownership, ABI, and coordinate spaces

| Boundary | Recovered procedures | Contract used by InputDec |
| --- | --- | --- |
| Public forwarding | `UITextView` begin/update/update:animated:/end at `0x1613e0c`, `0x1613e54`, `0x1613e9c`, `0x1613ef4` | Forward hosted points and end to the one interaction assistant; no editor-owned cursor renderer. |
| Assistant session | begin `0x1569a7c`, update `0x1569ba4`, end `0x1569e3c` | UIKit owns the active native session and normal-end ordering. |
| Modern presentation | display begin/fade `0xc6eb04`, `0xc6f5fc`; session update/clamp/fade/invalidate `0xa49d00`, `0xa4a264`, `0xa4a16c`, `0xa49e94`, `0xa4a0f4` | Native cursor view, clipping, spring/fade animation, and invalidation remain UIKit-owned. |
| Legacy presentation | begin/clamp/update/end `0x157dcc8`, `0x157dec0`, `0x157e1dc`, `0x157e84c` | Older selection-view floating caret remains a UIKit-owned fallback; clean-room code does not draw it. |
| Collapsed/extended selection dispatch | `0x1567cf8`, `0x1567e78`, `0x1567f0c` | Assistant sends hosted points to the active selection controller and resets/restores granularity as recovered. |
| Selection anchor/extent | `0x1576660`, `0x1576d44` | UIKit owns fixed base, moving extent, inversion, and optional endpoint flipping in canonical range space. |
| Keyboard ranged-selection switch | added touch `0x1088508` (call `0x1088578`), pan `0x10885f4` (switch `0x1088dd4`), controller switch/restart `0x107f5f4`, `0x1080118`; inactive Shift branch `0x1088d04`, `0x1088e50` | The second simultaneous touch switches the same keyboard trackpad gesture into ranged selection; the measured path is not synthetic Shift. |
| Keyboard acceleration/forwarding | `0x1084cc0`, `0x108640c`, `0x1085f48`, `0x107f8d0` | Per-event nonlinear acceleration is accumulated and the synthesized cursor location is then forwarded unchanged to the input delegate. Simulator VM addresses were not recorded. |
| Autoscroll | assistant start/tick/cancel `0x1569e88`, `0x156a160`, `0x156a020`; scroll-host start/cancel `0x161a040`, `0x161a278`; `UIAutoscroll` `0x17c4f28`, `0x17c5210`, `0x17c52cc` | Hosted point is converted once; native tick changes offset, then resolves the extent in the new viewport and publishes selection. The native 0.075-second owner remains UIKit's. |
| Selection cancellation | `0x15690a4`, `0x156ce34`; existing assistant `resignedFirstResponder` `0x15694a0` | Range cancellation and range-adjustment cancellation end their interactions; later call-graph recovery proves `0x15694a0` is not the stock text-view resign route. |
| Responder cleanup | `0x160fdfc` -> `0x160fccc`; display deactivation `0x1564e08`, `0xc6de0c`, `0xc6b690`, `0xc6db70..94` | Resign follows the recovered cleanup chain and does not call assistant `resignedFirstResponder`. |
| Graph destruction | assistant detach `0x156563c`; forced gesture cleanup `0x1565d8c` | Destruction sends `detach:YES`; it does not impersonate normal cursor end. |
| Container routing | `_updateFirstTextView` `0x15e6574`, point mapping `0x15ec46c`, caret mapping `0x15f089c`, inner host setter `0x16258b8` | `IDBlockStackCanvasView` is the weak interaction-container host. Container-local input subtracts `textContainerOrigin` once and public caret output adds it once. |
| Vertical navigation anchor | input-controller acquisition `0x15eed9c..0x15eee28`, TextKit 2 consumption `0xc3c400..0xc3c460` | UIKit preserves the insertion rectangle's container-local `minX`. InputDec's public insertion rectangle is stack-local, so the rich controller converts that X from the stack into each source or destination block canvas before calling its independent TextKit graph. Canvas frame and bounds origins are therefore honored exactly once. |

Every private floating-cursor send has an exact ABI preflight and a wrong-signature negative test.
Private selector definitions, runtime inspection, and typed sends remain under `PrivateUIKit/`.

## Interaction and publication behavior

The live keyboard tests synthesize one physical HID record containing the measured spacebar path;
selection-extension and lifecycle cases add a simultaneous second path to that same record. HID
synthesis is test-only. Production contains no XCTest event-record classes or private HID support.

Cursor-only LTR evidence retained these canonical ranges:

```text
custom: initial={46,0} held={48,0} moved={18,0} ended={18,0} quiesced={18,0}
stock:  initial={46,0} held={49,0} moved={18,0} ended={18,0} quiesced={18,0}
```

The one-offset held difference is an asynchronous sample boundary; both moved, ended, and
500-ms-quiesced results match exactly. Both editors remained collapsed and the custom presentation
container identity stayed stable.

Selection extension began at `{46,0}`. The retained stock checkpoints were `{45,1}`, `{43,3}`,
`{40,6}`, `{40,7}`, `{40,9}`, `{40,11}`, and `{40,12}`. The fixed logical role changed only when
the moving extent crossed it: end 46 before crossing, then start 40. Stock and custom matched the
final range, endpoint roles, reversal behavior, and quiesced state.

Structural-boundary and mixed-BiDi evidence includes:

- cursor callback reversal stops `11 -> 25 -> 0`;
- boundary selection ended at `{15,25}` in both editors and included each virtual newline once;
- the Hebrew fixture began from `{15,5}`, retained its logical anchor through reversal, and matched
  stock at target UTF-16 offset 17;
- affinity and normalized insertion/selection geometry matched at the asserted checkpoints;
- UIKit keyboard acceleration is nonlinear per delivered event (`0x1084cc0`), so independent
  stock/custom HID runs may have different intermediate points; exact semantic ranges and bounded
  callback-point margins are the parity oracle, not bit-identical raw event interpolation.

The tall-document cases covered both directions and both modes. Lower cursor advanced from
canonical 1600 through the measured final callback at 1728. Upper cursor started at 891 and ended
at 0. Both selection-extension cases retained the opposite endpoint at canonical 900. Each
retained sequence requires monotonic content offset and active endpoint (plateaus allowed), strict
first-to-last progress, identical stock/custom physical waypoints and terminal ranges, and no
selection or offset mutation during the 500-ms post-lift window.

The current-head release samples are:

| Direction/mode | Initial | Retained progress | Quiesced stock/custom result |
| --- | --- | --- | --- |
| Upper cursor | selection `{891,0}`, offset `{0,715}` | active endpoint descends through `836, 807, 780, …, 6, 4, 2, 0`; viewport reaches the top band | selection `{0,0}`; custom offset `{0,7}`, stock `{0,0}` |
| Lower cursor | selection `{1600,0}`, offset `{0,1065}` | active endpoint advances through `1632/1655, 1687, 1723/1724, 1725, 1727, 1728`; viewport advances through the lower band | selection `{1728,0}`; custom offset `{0,1295}`, stock `{0,1303}` |
| Upper selection | selection `{900,0}`, offset `{0,715}` | moving start retreats through `862/845, 807, 789, 752` while fixed endpoint remains 900 | selection `{752,148}`; custom offset `{0,8}`, stock `{0,0}` |
| Lower selection | selection `{900,0}`, offset `{0,445}` | moving end advances through `917, 955, 972` while fixed endpoint remains 900 | selection `{900,72}`; custom offset `{0,1295}`, stock `{0,1303}` |

The minor terminal viewport-offset differences are the already-characterized custom/stock safe
inset bands; canonical endpoints are exact. Complete timestamped sequences, including every
plateau and atomic callback record, are the eight exported
`{custom,stock}-floating-scroll-{upper,lower}-{cursor,selection}-samples` text attachments.

For every scroll tick the custom publication order is:

```text
contentOffset -> completed block layout -> visible rectangle
              -> assistant selection invalidation -> one backend presentation
```

The published snapshot contains the new offset, visible rectangle, and current block origins.
Viewport-only layout does not mutate canonical selection. The presentation container remains one
stable object while its UIKit backend can be replaced.

## Lifecycle truth

| Termination | Immediate stock/custom contract | Settled contract |
| --- | --- | --- |
| Normal lift | Native autoscroll is cancelled; session is invalidated; responder remains focused. | Selection/offset stable after 500 ms. |
| Resign or keyboard dismissal | Responder becomes false; selection freezes. | Keyboard absent; selection and presentation stable. |
| Window detach | Window becomes nil and responder false. | Selection unchanged. |
| Editable off | Editable false and responder false. | Selectable remains true; selection unchanged. |
| Selectable off | Selectable/editable/responder false; gestures removed; assistant getter nil. | No duplicate/reappearing gestures or delayed mutation. |
| Release attempt after normal end | Hosted graph is replaced; assistant session is cleared. | Pinned stock runtime retains weak editor/assistant/container/inactive-autoscroll references. |
| Release attempt after interruption | Force-detached graph retains an invalid session in the observed stock presentation graph. | Same pinned-runtime retention; no live timer or active session. |

The release rows report observed iOS 26.5 retention, not deallocation. The exact phase snapshots are
atomic app/stock-host publications rather than dictionaries fused by the UI test across time.
Action, held, ended/immediate, exact action-up+500 ms, and post-keyboard-lift+500 ms phases record
selection, affinities, responder/keyboard state, presentation fingerprints, container identity,
session validity, autoscroll state, and recognizer identity-subset parity.

## Ownership gate

The fail-closed audit classifies exactly 40 production `.m` files and 35 production `.h` files.
Unknown or missing manifest entries fail. It requires exactly one block-editor assistant factory
call site plus one separately inventoried legacy flat-editor assistant factory call site, one canonical
`IDRichTextLayoutController` owner, one presentation-backend construction site, and callback
definitions only below `PrivateUIKit/`. It rejects production `UITextView`, private XCTest/HID
tokens, alternate assistant allocation/factory spellings, custom floating recognizers/views/layers/
drawing/displacement/anchors, display links, timers, and relocated private callbacks. The floating
state scan covers both implementations and headers. A separate source audit parses every runnable
test command in `README.md`, the current floating plan, and this final report across backslash
continuations and requires
`-parallel-testing-enabled NO` in that same logical command.

## Task 7 TDD and current-head verification

All authoritative `xcodebuild test` commands below used `-parallel-testing-enabled NO` and ran
without any other `xcodebuild` or XCTest process active. Earlier overlapped attempts were discarded.

| Purpose | Exit and summary | Retained result |
| --- | --- | --- |
| Audit-policy RED | exit 65; 0 passed, 4 failed, 0 skipped | `.derivedData-floating-task7-reviewfix-audits-red/Result.xcresult` |
| Same-canvas anchor RED | exit 65; 0 passed, 1 failed, 0 skipped | `.derivedData-floating-task7-reviewfix-anchor-same-red-3/Result.xcresult` |
| Cross-block anchor RED | exit 65; 1 passed, 1 failed, 0 skipped | `.derivedData-floating-task7-reviewfix-anchor-red/Result.xcresult` |
| Current audit plus same/down/up anchor GREEN | exit 0; 65 passed, 0 failed, 0 skipped | `.derivedData-floating-task7-reviewfix-strength-green-2/Result.xcresult` |
| Final documentation/source audit | exit 0; 62 passed, 0 failed, 0 skipped | `.derivedData-floating-task7-reviewfix-smoke-final-2/Result.xcresult` |
| Complete floating gate | exit 0; 209 passed, 0 failed, 0 skipped; 1255.775 s | `.derivedData-floating-task7-reviewfix-final-clean-2/Result.xcresult` |
| Inherited UI | exit 0; 31 passed, 0 failed, 0 skipped; 314.840 s | `.derivedData-floating-task7-reviewfix-inherited-ui/Result.xcresult` |
| Inherited parity | exit 65; 11 passed, 1 retained spelling-density failure, 0 skipped | `.derivedData-floating-task7-reviewfix-inherited-parity-clean/Result.xcresult` |
| Build for testing | exit 0 | `.derivedData-floating-task7-reviewfix-build/` |

The audit-policy RED contains four intentionally failing XCTest methods. Repeated failure lines in
the console were category assertions inside those methods, not additional tests.

The exact retained RED commands were:

```sh
xcodebuild test -quiet -parallel-testing-enabled NO -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-floating-task7-reviewfix-audits-red \
  -resultBundlePath .derivedData-floating-task7-reviewfix-audits-red/Result.xcresult \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipAuditRequiresTheInventoriedLegacyAssistantSite \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipAuditRejectsExtraBlockAssistantAllocation \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipHeaderAuditRejectsUnknownAndCustomFloatingState \
  -only-testing:InputDecTests/IDProjectSmokeTests/testRunnableMarkdownTestCommandAuditIsPerLogicalCommandAndFailClosed

xcodebuild test -quiet -parallel-testing-enabled NO -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-floating-task7-reviewfix-anchor-same-red-3 \
  -resultBundlePath .derivedData-floating-task7-reviewfix-anchor-same-red-3/Result.xcresult \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests/testVerticalAnchorFromInsertionBoundaryConvertsStackToSameCanvas

xcodebuild test -quiet -parallel-testing-enabled NO -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-floating-task7-reviewfix-anchor-red \
  -resultBundlePath .derivedData-floating-task7-reviewfix-anchor-red/Result.xcresult \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests/testVerticalAnchorFromInsertionBoundaryConvertsStackToSameCanvas \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests/testVerticalAnchorFromInsertionBoundaryConvertsStackToAdjacentAsymmetricCanvas
```

The exact retained GREEN/current-gate commands were:

```sh
# Current source/ownership/header/serial-command audit plus same/down/up anchor GREEN.
xcodebuild test -quiet -parallel-testing-enabled NO -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-floating-task7-reviewfix-strength-green-2 \
  -resultBundlePath .derivedData-floating-task7-reviewfix-strength-green-2/Result.xcresult \
  -only-testing:InputDecTests/IDProjectSmokeTests \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests/testVerticalAnchorFromInsertionBoundaryConvertsStackToSameCanvas \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests/testVerticalAnchorFromInsertionBoundaryConvertsStackToAdjacentAsymmetricCanvas \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests/testVerticalAnchorFromInsertionBoundaryConvertsStackUpToAdjacentAsymmetricCanvas

xcodebuild test -quiet -parallel-testing-enabled NO -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-floating-task7-reviewfix-final-clean-2 \
  -resultBundlePath .derivedData-floating-task7-reviewfix-final-clean-2/Result.xcresult \
  -only-testing:InputDecTests/IDFloatingCursorContractTests \
  -only-testing:InputDecTests/IDFloatingCursorParityTests \
  -only-testing:InputDecTests/IDBlockTextViewIntegrationTests \
  -only-testing:InputDecTests/IDSelectionPresentationBackendTests \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests \
  -only-testing:InputDecTests/IDRichTextLayoutControllerContractTests \
  -only-testing:InputDecTests/IDPrivateUIKitTests \
  -only-testing:InputDecUITests/IDFloatingCursorUITests

xcodebuild test -quiet -parallel-testing-enabled NO -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-floating-task7-reviewfix-inherited-ui \
  -resultBundlePath .derivedData-floating-task7-reviewfix-inherited-ui/Result.xcresult \
  -only-testing:InputDecUITests/IDBlockTouchSelectionUITests \
  -only-testing:InputDecUITests/IDBlockTextViewUITests \
  -only-testing:InputDecUITests/IDTextLayoutCanvasUITests/testNativeSpellingMarkerAppearsForMisspellingAndClearsAfterCorrection

xcodebuild test -quiet -parallel-testing-enabled NO -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-floating-task7-reviewfix-inherited-parity-clean \
  -resultBundlePath .derivedData-floating-task7-reviewfix-inherited-parity-clean/Result.xcresult \
  -only-testing:InputDecTests/IDBlockTextViewParityTests
```

The complete bundle exported 293 evidence artifacts plus `manifest.json` to
`.floating-task7-reviewfix-final-clean-2-attachments/`. Exact historical commands and their invalid/diagnostic bundle
classification remain in `.superpowers/sdd/floating-task-1-report.md` through
`.superpowers/sdd/floating-task-6-report.md`; this report does not reconstruct missing shell exits.

Representative current-head visible artifacts are the custom/stock
`floating-cursor-{baseline,held,moved,ended}` PNGs, the
`selection-extension-prelift-{2,5,8}` and `selection-extension-ended` PNGs, and all eight
`floating-scroll-{upper,lower}-{cursor,selection}-held` PNGs. The manifest maps each suggested name
to its exported UUID filename; the report deliberately does not pretend those generated UUIDs are
stable API identifiers.

`xcodebuild build-for-testing` exited 0. Two consecutive `xcodegen generate` runs produced identical
project SHA-1 `6c9bd62f034f18d76af98c49dbe050c6794997cc`; the project diff was empty and
`git diff --check` exited 0.

## Post-review current-HEAD proof

Independent whole-slice re-review approved commit `dc8acdf` with no Critical, Important, or Minor
findings. With no other `xcodebuild test` or XCTest process active, the following fresh serial
keyboard/HID proof then exited 0 and finalized **1/1 passed, 0 failed, 0 skipped** on the pinned
iOS 26.5 simulator:

```bash
xcodebuild test -quiet -parallel-testing-enabled NO -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-floating-current-head-final-dc8acdf \
  -resultBundlePath .derivedData-floating-current-head-final-dc8acdf/Result.xcresult \
  -only-testing:InputDecUITests/IDFloatingCursorUITests/testFloatingCursorSelectionHeldBelowViewportScrollsAndExtendsSelection
```

The finalized bundle is
`.derivedData-floating-current-head-final-dc8acdf/Result.xcresult`; `xcresulttool` reports iPhone
17 Pro, iOS 26.5 build `23F73`, arm64, and zero skips.

## Earlier slice provenance

These are historical outcomes reported by Tasks 1–6. Tasks 1–5 predate the current mandatory
serial-testing policy and are non-authoritative under that policy; their reports and bundles remain
unchanged as provenance. Task 6's cited authoritative reruns and Task 7's current-head evidence use
`-parallel-testing-enabled NO`. Where a historical report retains a literal command, it remains
unaltered; this summary does not reconstruct missing history from plan text.

| Slice | RED evidence | Latest relevant GREEN evidence |
| --- | --- | --- |
| Task 1 contract inventory | `.derivedData-floating-task1-red`: exit 65 at link, 0 tests | `.derivedData-floating-task1-green`: exit 0, 4/4; final scanner review 11/11 |
| Task 2 cursor-only HID | `.derivedData-floating-task2-red-3`: exit 65, 4 pass/1 fail | `.derivedData-floating-task2-green`: exit 0, 5/5; hardened live proof 1/1 |
| Task 3 selection extension | `.derivedData-floating-task3-red`: exit 65, 2 pass/1 fail | `.derivedData-floating-task3-green`: exit 0, 3/3; hardened inherited touch 3/3 |
| Task 4 boundary/BiDi | `.derivedData-task4-review-red`: exit 65, 0/3 | `.derivedData-task4-review-final2`: exit 0, 15/15; inherited unit/touch 162/162 and 8/8 |
| Task 5 scrolling/publication | `.derivedData-floating-task5-red`: exit 65, 36 pass/3 fail | `.derivedData-floating-task5-abi-final-combined`: exit 0, 41/41; inherited unit/touch 172/172 and 8/8 |
| Task 6 lifecycle | `.derivedData-floating-task6-red-2`: exit 65, 63 pass/2 fail | `.derivedData-floating-task6-review5-authoritative-final-{1,2}`: each exit 0, 130/130; inherited/input/touch 203/203, 24/24, 8/8 |

Task 2's earlier compile-defect REDs and stalled review attempt, Task 5's misnamed
`.derivedData-floating-task5-final-green` (actually 39 pass/1 fail), Task 5 overlapping/skipped
combined runs, and incomplete Task 6 diagnostics are explicitly excluded. Where an old shell exit
or finalized bundle was unavailable, the originating report labels it unavailable; none is
reconstructed here.

## Limitations and next input slice

The native spelling marker remains semantically correct but visually less dense than stock in the
retained pixel ROI. This is the only inherited parity failure. The first clean checker request can
also be delayed while the real language service initializes.

The reusable software-keyboard HID scheduler, exact status parser, atomic capture bracket, and
stock/custom host alignment are intentionally test-only. They are the handoff for the next input
slice: autocorrection rejection/acceptance first, then prediction and marked-text/IME composition.
Those features must earn their own stock/custom semantic and visible evidence; floating-cursor
success does not imply them.
