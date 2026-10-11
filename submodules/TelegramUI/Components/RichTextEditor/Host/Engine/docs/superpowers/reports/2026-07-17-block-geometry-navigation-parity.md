# Block Geometry and Navigation Parity Evidence

Date: 2026-07-17

## Reviewed system

- Device: iPhone 17 Pro simulator, UUID `404DA68C-E273-46A5-8F6C-B3BF556B80D6`.
- Runtime: iOS 26.5, build `23F73`, arm64.
- Xcode SDK shown by the build: iPhoneSimulator 26.5, build `23F73`.
- Reviewed range: `c287e6d^..b933e56` (`03dfaacba1387ddb32cbc5e429eac128d92d9aec` as the lower boundary through `b933e5658b6ca0f4db38d1e472f5e8e9b747d366`).
- Definitive runtime matrix code/test head: `c5a72cf`. The only later change, `b933e56`, adds `TextView/IDBlockTextGeometry.m` to the existing test-only production-source audit inventory; its corrected audit result is recorded below. No production file changed after the runtime matrix.

## Definitive verification matrix

### 1. Complete block geometry parity class

Command (non-quiet because the first quiet runner did not finalize):

```sh
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-task16-parity-corrected-final \
  -resultBundlePath .derivedData-task16-parity-corrected-final/Result.xcresult \
  -only-testing:InputDecTests/IDBlockTextViewParityTests
```

- Exit: `65`, solely because the allowed spelling-pixel ROI method is red.
- Counts: 12 executed, 11 passed, 1 failed, 0 skipped, 0 expected failures, 0 unexpected failures.
- Complete result: `.derivedData-task16-parity-corrected-final/Result.xcresult`.

Every method in the class:

| Method | Result |
| --- | --- |
| `testCanonicalRangesWordParagraphAndBoundaryNavigationMatchStock` | Passed |
| `testDirectSelectedTextRangeReplacementResetsPreferredVerticalX` | Passed |
| `testEveryCaretOffsetMatchesStockInVisibleHostCoordinates` | Passed |
| `testMarkedTextEditingAndUndoRangesMatchStock` | Passed |
| `testMixedBiDiHorizontalMovementUsesVisualClusterAdjacency` | Passed |
| `testNativeSpellingPixelCountsMatchStockInCanonicalWordROI` | Failed: custom red pixels 104, stock 162, tolerance 12 |
| `testNativeStructuralSplitMergeAndUndoPreserveRichAttributeRuns` | Passed |
| `testPointHitsNeverReturnInsideComposedCharacterCluster` | Passed |
| `testPublicLiveRangeRebasesWhileNativeSnapshotRangeStaysAtOriginalOffsets` | Passed |
| `testSelectionAcrossStructuralNewlineAndRTLBlockMatchesStockEdges` | Passed |
| `testVerticalMovementRetainsPreferredXAcrossShortLineAndReturn` | Passed |
| `testVirtualNewlineSidesAndComposedClusterNavigation` | Passed |

The BiDi method initially exposed a stale test oracle, not a production regression. For `abc אבג def`, range `{4, 3}`, a pinned stock probe returned one selection rectangle with LTR writing direction, exactly like the custom view. Commit `c5a72cf` replaced the hardcoded RTL assertion with direct custom-versus-stock count and direction comparisons. Focused GREEN was 1/1, exit 0, at `.derivedData-task16-bidi-oracle-green-final/Result.xcresult` before the complete class run above.

### 2. Controller, recovered ABI, and canvas regressions

```sh
xcodebuild test -quiet -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-task16-contract-final \
  -resultBundlePath .derivedData-task16-contract-final/Result.xcresult \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests \
  -only-testing:InputDecTests/IDRichTextLayoutControllerContractTests \
  -only-testing:InputDecTests/IDTextLayoutCanvasParityTests
```

- Exit: `0`.
- Counts: 46 executed, 46 passed, 0 failed, 0 skipped, 0 expected failures.
- Breakdown: 32 rich-controller tests, 7 recovered-contract/ABI tests, and 7 canvas parity tests.
- Complete result: `.derivedData-task16-contract-final/Result.xcresult`.

The green contract methods include `testUIKitBaseConnectionIMPsUseTheCleanRoomConnectionSlot`, which checks the Task 13 connection ivar at offset `sizeof(void *)`, and both `testRichLayoutRecoveredCallbackABIsAcceptExactCleanRoomSignatures` and `testRichLayoutRecoveredCallbackABIsRejectEachWrongButPresentSignature`, which retain the Task 14 selector and ABI declarations.

### 3. Complete block UI class

```sh
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-task16-block-ui-final \
  -resultBundlePath .derivedData-task16-block-ui-final/Result.xcresult \
  -only-testing:InputDecUITests/IDBlockTextViewUITests
```

- Exit: `0`.
- Counts: 4 executed, 4 passed, 0 failed, 0 skipped, 0 expected failures.
- Complete result: `.derivedData-task16-block-ui-final/Result.xcresult`.
- Methods: return/split/caret visibility, boundary merge, shift-arrow structural selection, and visible native spelling red pixels all passed.

### 4. Native spelling appearance and removal

```sh
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-task16-spelling-ui-final \
  -resultBundlePath .derivedData-task16-spelling-ui-final/Result.xcresult \
  -only-testing:InputDecUITests/IDTextLayoutCanvasUITests/testNativeSpellingMarkerAppearsForMisspellingAndClearsAfterCorrection
```

- Exit: `0`.
- Counts: 1 executed, 1 passed, 0 failed, 0 skipped, 0 expected failures.
- Complete result: `.derivedData-task16-spelling-ui-final/Result.xcresult`.

This proves that a misspelling receives a visible native marker and correcting it removes the marker. Therefore the sole block parity red is limited to exact red-pixel density in its ROI, not missing appearance or failure to clear.

### 5. Generic simulator build

```sh
xcodebuild build-for-testing -quiet -project InputDec.xcodeproj -scheme InputDec \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .derivedData-task16-build-final
```

- Exit: `0`.
- Quiet output: empty, so no warning was emitted.
- Test counts/skips and `.xcresult`: not applicable to `build-for-testing`; artifacts are under `.derivedData-task16-build-final`.

### 6. Production architecture audits

The first audit run correctly found that Task 1's new `TextView/IDBlockTextGeometry.m` was absent from the exact source inventory. That focused RED executed 3 methods with 2 passing and the inventory method failing. Commit `b933e56` added that one path so it is now scanned by the existing no-forbidden-rendering audit.

Corrected command:

```sh
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-task16-source-audit-corrected-final \
  -resultBundlePath .derivedData-task16-source-audit-corrected-final/Result.xcresult \
  -only-testing:InputDecTests/IDProjectSmokeTests/testProductionSourceDoesNotReferenceUITextView \
  -only-testing:InputDecTests/IDProjectSmokeTests/testEveryExperimentalImplementationHasExactOwnersStorageAndNoForbiddenRendering \
  -only-testing:InputDecTests/IDProjectSmokeTests/testExperimentalProductionDoesNotReferenceOrConstructNativeLayoutController
```

- Exit: `0`.
- Counts: 3 executed, 3 passed, 0 failed, 0 skipped, 0 expected failures.
- Complete result: `.derivedData-task16-source-audit-corrected-final/Result.xcresult`.

Additional static checks:

```sh
rg -n 'UITextView' App TextView PrivateUIKit --glob '*.[mh]'
```

Exit `1`, with no matches. Production contains no `UITextView` reference.

```sh
git diff --unified=0 c287e6d^..HEAD -- App TextView PrivateUIKit | \
  rg -n '^\+.*(\[NSTextLayoutManager new\]|\[\[(NSTextLayoutManager|NSTextContentStorage|NSTextStorage) alloc\]|UITextView)'
```

Exit `1`, with no matches. Task 16 introduced no stock text view, content/storage graph, layout-manager allocation, or continuous canonical shadow layout.

```sh
rg -n '\[NSTextLayoutManager new\]|\[\[NSTextStorage alloc\]' TextView/IDBlock*.m
```

Exit `0`; the only results are the existing per-block `NSTextStorage` and `NSTextLayoutManager` allocations in `TextView/IDBlockLayout.m` at lines 44 and 46. Geometry is answered from independent block graphs.

## Behavior-to-test mapping

| Approved behavior | Green evidence |
| --- | --- |
| Task 1: two-point caret centered on TextKit insertion segment | `testTask16InsertionRectCentersTwoPointCaretOnTextKitSegment`; complete every-offset stock parity method |
| Task 1: exact fractional independent-block stacking | `testTask16IndependentBlocksStackAtFractionalTextKitAdvance`; complete every-offset stock parity method |
| Task 1: ambiguous RTL caret side follows native paragraph-forward resolution | `testTask16RTLAmbiguousInsertionsUseNativeParagraphForwardCaretSide` |
| Task 2: TextKit visual BiDi movement and affinity propagation | `testTask16BiDiBoundaryMovementUsesTextKitSelectionNavigation`; `testTask16MultiHopMovementCarriesNativeAffinityAndAnchorState`; complete mixed-BiDi parity method |
| Task 2: point interaction never returns an interior composed-cluster offset | `testTask16PointInteractionNeverReturnsInsideComposedCluster`; complete point-hit parity method |
| Task 2: virtual-newline fallback crosses exactly one structural boundary | complete `testVirtualNewlineSidesAndComposedClusterNavigation` |
| Task 3: TextKit selection segments compose across structural newlines | `testTask16StructuralNewlineSelectionComposesSegmentsBeforeAssigningFlags`; complete structural-newline selection parity method |
| Task 3: logical endpoint flags survive mixed-BiDi visual ordering | `testTask16MixedBiDiSelectionFlagsLogicalSegmentsLikeUIKit` |
| Task 3: separator-only LTR/RTL and empty-block tails match UIKit | `testTask16SeparatorOnlyLTRSelectionMatchesUIKitUpstreamTail`; `testTask16SeparatorOnlyRTLSelectionMatchesUIKitUpstreamTail`; `testTask16SeparatorAfterEmptyMiddleBlockFillsUpstreamLineFragment` |
| Task 4: caller-owned vertical anchor survives one multi-step callback | `testTask16OneVerticalCallbackPreservesCallerAnchorAcrossIndependentBlocks`; complete preferred-X parity method |
| Task 4: separate callbacks use separate caller anchors without persistent controller state | `testTask16SeparateVerticalCallbacksUseEachCallerAnchor`; complete direct-selection replacement parity method |
| Task 4: same-line vertical boundary crosses only the adjacent block | `testTask16SameLineVerticalBoundaryCrossesOnlyOneAdjacentBlock` |

## Test-oracle corrections

- `c5a72cf` changed the legacy BiDi selection direction assertion from hardcoded RTL to an exact stock `UITextView` comparison. The pinned stock probe was LTR for the LTR paragraph, matching the custom result.
- `b933e56` added Task 1's new geometry implementation to the exact production-source inventory, ensuring it participates in the no-forbidden-rendering and ownership audit.

Both changes are test-only. No production implementation was altered during Task 5.

## Incomplete runner and bundle attempts

- `.derivedData-task16-parity-final`: the required quiet full parity runner emitted no output and did not create an `Info.plist` after more than two minutes. It was terminated with exit 143; the bundle is incomplete and supplies no claimed count. The non-quiet definitive parity run above replaced it.
- `.derivedData-task16-bidi-oracle-red-final/Result.xcresult`: the focused stock probe staged an exact 1-test/1-failure result and logged stock `count=1`, direction LTR, but lingered during finalization and was terminated with exit 143. Its incomplete bundle is diagnostic only; the complete focused GREEN and complete class bundle are authoritative.
- `.derivedData-task16-source-audit-final`: the quiet audit runner emitted no output and did not finalize, so it was terminated with exit 143 and supplies no claimed count.
- `.derivedData-task16-source-audit-observed-final/Result.xcresult`: the non-quiet audit RED staged 3 executed, 2 passed, 1 failed before lingering during finalization and being terminated with exit 143. The complete corrected GREEN bundle above is authoritative.

## Remaining limitations outside this slice

- Exact spelling underline pixel density in the block parity ROI remains different from stock (104 versus 162 red pixels). Native marker appearance, visible red pixels, and removal after correction are independently green.
- An entirely empty independent TextKit graph can still provide no standard insertion segment; empty-document caret fallback parity was not part of Tasks 1–4.
- This is the standalone independent-block vertical slice. Integration with Telegram's production rich-text block model and custom rich rendering remains later work.
