# Return–Backspace spelling geometry callback evidence

## Status and scope

`DONE_WITH_CONCERNS`. The implementation commit is `9861bdd` (`fix: recover
spelling range and geometry callbacks`), and the initial evidence/documentation
head reviewed for this fix wave was `9ed64ac`. The Return–Backspace recovery,
controller/ABI/canvas regressions, complete block UI class, native spelling
appearance/clearing test, and generic simulator build are green. The freshly
measured spelling-marker pixel-density comparison remains the one retained
failure described under **Limitations**.

All simulator evidence in this report used iPhone 17 Pro simulator
`404DA68C-E273-46A5-8F6C-B3BF556B80D6`, iOS 26.5 (`23F73`), arm64.

## Root cause and recovered contract

The deletion path had two consecutive clean-room contract gaps:

1. `dictationLanguageForSelectedText` could drive `attributedTextInRange:` into
   the singular `characterRangeForTextRange:` callback with nil. Stock sends
   `unionTextRange` to that nil argument and returns `NSMakeRange(0, 0)` when
   the union is nil. The clean-room controller instead rejected nil as a
   foreign concrete range, so the deterministic UI test initially crashed
   before reaching spelling-marker cleanup. The recovered singular callbacks
   now return `{0,0}` only for nil while continuing to reject non-nil foreign
   range classes.
2. Once deletion reached spelling cleanup, `UITextInputController` sent the
   missing private selector `boundingRectForCharacterRange:` to its weak layout
   controller receiver. The receiver is loaded through weak storage at input-
   controller offset `0xf8`; the argument is a canonical `NSRange`, and the
   return is a `CGRect`. The exact arm64 Objective-C ABI is
   `{CGRect={CGPoint=dd}{CGSize=dd}}32@0:8{_NSRange=QQ}16` for
   `- (CGRect)boundingRectForCharacterRange:(NSRange)range`.

The current Hopper document was `UIKitCore`. Procedure info, disassembly, and
pseudocode were re-queried before provenance was written. The iOS 26.5
simulator file-relative evidence is:

| Address | Reconfirmed evidence |
| --- | --- |
| `0x15eb4e0` | Entry of `-[UITextInputController removeSpellingMarkersFromWordInRange:]`; reads the style annotation, requires value `2`, removes it, requests bounds, and invalidates the input view |
| `0x15eb5ac` | `removeAnnotationAttribute:forRange:` send for `NSTextAlternativesDisplayStyleAttributeName` |
| `0x15eb5c8` | `boundingRectForCharacterRange:` send after loading weak receiver storage at `self + 0xf8` |
| `0x15eb5cc` | First instruction after the geometry send and therefore the absent-callback crash return address |
| `0xc416b4` | Entry of `-[_UITextKit2LayoutController boundingRectForCharacterRange:]`; calls `textRangeForCharacterRange:` and forwards to `boundingRectForRange:` |
| `0xc40928` | Entry of `-[_UITextKit2LayoutController boundingRectForRange:]`; sends `unionTextRange`, enumerates standard segments with `RangeNotRequired`, unions the frames, and offsets by text-container origin |
| `0x15eb054` | Entry of `-[UITextInputController checkSpellingForWordInRange:]`; pseudocode confirms `addTextAlternativesDisplayStyle:0x2` after a misspelling result |
| `0xc40d74` | Entry of `-[_UITextKit2LayoutController characterRangeForTextRange:clippedToDocument:]`; sends `unionTextRange` and returns `{0,0}` when the resulting union is nil |

The clean-room implementation preserves independent per-block TextKit 2
graphs. It unions standard segment frames inside each participating block,
converts those results to the text input view's host coordinates, and then
unions the block results. The mandatory selector and exact aggregate ABI are
preflighted before controller use.

## TDD evidence

### Task 1 UI RED

Command:

```bash
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-task17-ui-red \
  -resultBundlePath .derivedData-task17-ui-red/Result.xcresult \
  -only-testing:InputDecUITests/IDBlockTextViewUITests/testReturnThenBackspaceWithSpellingMarkerMergesWithoutCrashing
```

- Exit `65`; executed 1, passed 0, failed 1, skipped 0.
- Bundle: `.derivedData-task17-ui-red/Result.xcresult`.
- The spelling annotation and post-Return two-block assertions passed. Delete
  then terminated the app, leaving the final post-Delete status wait as the
  sole test failure. The fresh crash was the earlier nil singular-range gap:
  `IDRichTextLayoutController characterRangeForTextRange: failed: range has a
  foreign concrete class` on the
  `characterRangeForTextRange:` → `attributedTextInRange:` →
  `dictationLanguageForSelectedText` path.

### Task 2 nil singular-range RED/GREEN

RED command:

```bash
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-task17-nil-range-red \
  -resultBundlePath .derivedData-task17-nil-range-red/Result.xcresult \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests/testNilTextRangeConvertsToZeroLikeIOS265NilUnionRange
```

- Exit `65`; executed 1, passed 0, failed 1, skipped 0.
- Bundle: `.derivedData-task17-nil-range-red/Result.xcresult`.
- The first nil conversion threw the foreign-concrete-class exception, so the
  explicit non-nil foreign-range assertion was not reached.

GREEN reran the same selected test with:

```text
-derivedDataPath .derivedData-task17-nil-range-green
-resultBundlePath .derivedData-task17-nil-range-green/Result.xcresult
```

- Exit `0`; executed 1, passed 1, failed 0, skipped 0.
- Bundle: `.derivedData-task17-nil-range-green/Result.xcresult`.
- Both nil calls returned `{0,0}`, and the final assertion still proved that a
  non-nil foreign concrete range is rejected.

### Task 2 geometry/selector/ABI RED/GREEN

RED command:

```bash
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-task17-contract-red \
  -resultBundlePath .derivedData-task17-contract-red/Result.xcresult \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests/testNilTextRangeConvertsToZeroLikeIOS265NilUnionRange \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests/testSpellingBoundingRectUsesStandardTextKitSegments \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests/testSpellingBoundingRectComposesIndependentBlocksInHostCoordinates \
  -only-testing:InputDecTests/IDRichTextLayoutControllerContractTests/testRichLayoutRecoveredCallbackABIsAcceptExactCleanRoomSignatures \
  -only-testing:InputDecTests/IDRichTextLayoutControllerContractTests/testRichLayoutRecoveredCallbackABIsRejectEachWrongButPresentSignature \
  -only-testing:InputDecTests/IDPrivateUIKitTests/testRichLayoutCompatibilityReportListsEveryMissingP0Selector
```

- Exit `65` during test compilation; executed 0, passed 0, failed 0, skipped 0.
- Bundle: `.derivedData-task17-contract-red/Result.xcresult`.
- The intended missing contract was the only compile failure:
  `IDBlockLayout` did not declare `boundingRectForLocalRange:` and
  `IDRichTextLayoutController` did not declare
  `id_boundingRectForCharacterRange:`.

GREEN reran the identical six-test selection with:

```text
-derivedDataPath .derivedData-task17-contract-green
-resultBundlePath .derivedData-task17-contract-green/Result.xcresult
```

- Exit `0`; executed 6, passed 6, failed 0, skipped 0.
- Bundle: `.derivedData-task17-contract-green/Result.xcresult`.
- The standard-segment geometry, multi-block host composition, mandatory
  selector inventory, exact ABI acceptance, and wrong-present ABI rejection
  all passed.

### Task 2 focused UI and source GREEN

The original Task 1 test reran with
`.derivedData-task17-ui-green/Result.xcresult`: exit `0`; executed/passed 1,
failed/skipped 0. It reached the post-Backspace canonical text
`hello mispelled `, one block, and collapsed selection at offset 16.

The three focused architecture audits ran with
`.derivedData-task17-source-green/Result.xcresult`: exit `0`;
executed/passed 3, failed/skipped 0. An additional exact-owner audit at
`.derivedData-task17-owner-exact-green/Result.xcresult` passed 1/1.

### Final-review diagnostics RED/GREEN

The final-review RED added the readonly internal callback counter, exact block
status schema expectation, exact style-`2` assertions before and after Return,
and the post-Backspace counter increase oracle before any production
diagnostics were added:

```bash
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-task17-final-review-red-2 \
  -resultBundlePath .derivedData-task17-final-review-red-2/Result.xcresult \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests/testSpellingBoundingRectComposesIndependentBlocksInHostCoordinates \
  -only-testing:InputDecTests/IDProjectSmokeTests/testBlockLaunchScenarioConstructsBlockGraphDirectlyAndExposesExactJSONSeed \
  -only-testing:InputDecUITests/IDBlockTextViewUITests/testReturnThenBackspaceWithSpellingMarkerMergesWithoutCrashing
```

- Exit `65`; executed 3, passed 0, failed 3, skipped 0.
- Bundle: `.derivedData-task17-final-review-red-2/Result.xcresult`.
- The controller test failed because the diagnostic key did not exist, and the
  smoke/UI tests failed because `spellingGeometryRequests` was absent. The
  live status snapshots nevertheless showed exact spelling style `2` before
  Return and again after Return with two blocks, so the binding oracle was not
  weakened.

The first diagnostic implementation proved the unit counter and JSON schema,
then exposed that the caret after the fixture's trailing space described an
empty current word and therefore did not enter UIKit's spelling-marker removal
branch. The final fixture sends a real left-arrow key event to place the caret
at the end of the still-annotated misspelling before Return. The fresh combined
GREEN command was:

```bash
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-task17-final-review-all-final \
  -resultBundlePath .derivedData-task17-final-review-all-final/Result.xcresult \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests/testSpellingBoundingRectComposesIndependentBlocksInHostCoordinates \
  -only-testing:InputDecTests/IDRichTextLayoutControllerContractTests/testRichLayoutRecoveredCallbackABIsAcceptExactCleanRoomSignatures \
  -only-testing:InputDecTests/IDRichTextLayoutControllerContractTests/testRichLayoutRecoveredCallbackABIsRejectEachWrongButPresentSignature \
  -only-testing:InputDecTests/IDProjectSmokeTests/testBlockLaunchScenarioConstructsBlockGraphDirectlyAndExposesExactJSONSeed \
  -only-testing:InputDecUITests/IDBlockTextViewUITests/testReturnThenBackspaceWithSpellingMarkerMergesWithoutCrashing
```

- Exit `0`; executed 5, passed 5, failed 0, skipped 0.
- Bundle: `.derivedData-task17-final-review-all-final/Result.xcresult`.
- The live test retained exact style `2` before and after Return, then observed
  the geometry request count increase after Backspace before accepting the
  final original text, one block, and collapsed merge-point selection. The
  same bundle also passed second-block-only and cross-block host geometry,
  exact ABI acceptance, all three wrong-present signatures, and exact JSON
  seed/schema coverage.

## Final verification commands

### Controller, ABI, and canvas regression group

```bash
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-task17-contract-final \
  -resultBundlePath .derivedData-task17-contract-final/Result.xcresult \
  -only-testing:InputDecTests/IDBlockLayoutTests \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests \
  -only-testing:InputDecTests/IDRichTextLayoutControllerContractTests \
  -only-testing:InputDecTests/IDPrivateUIKitTests \
  -only-testing:InputDecTests/IDTextLayoutCanvasParityTests
```

### Complete block UI class and native spelling clear

```bash
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-task17-ui-final \
  -resultBundlePath .derivedData-task17-ui-final/Result.xcresult \
  -only-testing:InputDecUITests/IDBlockTextViewUITests \
  -only-testing:InputDecUITests/IDTextLayoutCanvasUITests/testNativeSpellingMarkerAppearsForMisspellingAndClearsAfterCorrection
```

### Complete block parity class

```bash
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-task17-parity-final \
  -resultBundlePath .derivedData-task17-parity-final/Result.xcresult \
  -only-testing:InputDecTests/IDBlockTextViewParityTests
```

### Generic simulator build

```bash
xcodebuild build-for-testing -project InputDec.xcodeproj -scheme InputDec \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .derivedData-task17-build-final
```

## Final verification matrix

| Verification | Exit | Executed | Passed | Failed | Skipped | Result bundle / build path |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Controller/ABI/canvas group | `0` | 90 | 90 | 0 | 0 | `.derivedData-task17-contract-final/Result.xcresult` |
| Block UI class + native spelling clear | `0` | 6 | 6 | 0 | 0 | `.derivedData-task17-ui-final/Result.xcresult` |
| Complete block parity class | `65` | 12 | 11 | 1 | 0 | `.derivedData-task17-parity-final/Result.xcresult` |
| Generic simulator build-for-testing | `0` | N/A | N/A | N/A | N/A | No xcresult requested; `.derivedData-task17-build-final` |

The generic build ended with `** TEST BUILD SUCCEEDED **`. It emitted Xcode
environment/provisioning diagnostics, but no compiler warning from a changed
file in either the recovery implementation or the final-review diagnostic
fix.

## Architecture audit

- Independent block graphs remain: each `IDBlockLayout` initializer creates a
  new `NSTextContentStorage`, `NSTextLayoutManager`, and `NSTextContainer`, then
  connects only that block's storage, manager, container, geometry, and canvas.
- Standard segments are used: `IDBlockTextGeometry` calls
  `enumerateTextSegmentsInRange:type:options:usingBlock:` with
  `NSTextLayoutManagerSegmentTypeStandard` and
  `NSTextLayoutManagerSegmentOptionsRangeNotRequired`, filters non-finite
  frames, and unions the remaining rectangles.
- The UIKit-facing selector has one private owner. The source scan
  `rg -l --glob '*.m' '^[-+] \(CGRect\)boundingRectForCharacterRange:'
  TextView PrivateUIKit App | wc -l` returned `1`; that definition is in
  `PrivateUIKit/IDRichTextLayoutController+PrivateCallbacks.m`.
- Production contains no `UITextView`. The source scan
  `rg -l --glob '*.{h,m}' '\bUITextView\b' TextView PrivateUIKit App | wc -l`
  returned `0`.
- Task 2's focused source-audit bundle independently passed all three selected
  architecture tests with no skips.

## Documentation changed

- `docs/hopper/UIKitCore-iOS26.5.md`: appended the permanent deletion,
  geometry, ABI, and nil-range provenance.
- `docs/superpowers/reports/2026-07-17-return-backspace-spelling-geometry-callback.md`:
  records TDD, final commands/counts, architecture evidence, and limitations.

The ignored `.superpowers/sdd/task-3-report.md` was refreshed as the internal
handoff report but is not part of the documentation commit. The untracked
`SESSION_HANDOFF.md` was neither staged nor committed.

## Limitations

The fresh complete parity run, not Task 16's copied result, confirms that
`testNativeSpellingPixelCountsMatchStockInCanonicalWordROI` remains the sole
failure: custom 104 red pixels versus stock 162 with tolerance 12. The other
11 parity methods passed, and the separate native UI test proves spelling
markers appear and clear after correction. The retained gap is therefore exact
marker pixel density in that canonical ROI, not missing annotation, cleanup,
geometry callback, or Return–Backspace behavior.

## Self-review

- Re-read all seven Task 3 steps and matched each required field to this report.
- Reconfirmed every address/procedure assertion through the current Hopper
  `UIKitCore` document before appending provenance.
- Extracted final and historical counts with `xcresulttool`; no skip count was
  inferred from expected values.
- Verified the parity failure name, 104/162 counts, and tolerance 12 directly
  from the fresh Task 3 result bundle.
- Confirmed the final documentation diff contains only the requested Hopper
  section and this report; production and tests have no Task 3 diff.
- Confirmed `SESSION_HANDOFF.md` remains untracked and unstaged.

## Concerns

- Exact spelling-marker red-pixel density remains non-parity at 104 versus 162
  (tolerance 12). This is the sole fresh test failure and is explicitly allowed
  by the Task 3 brief when confirmed exactly.
