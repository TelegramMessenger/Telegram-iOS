# iOS 26.5 Inline-Prediction Lifecycle Parity

## Result

`IDBlockTextView` matches stock `UITextView` for the complete English (US)
inline-prediction lifecycle slice on iOS 26.5 (23F73).

| Lifecycle | Interior | Before boundary | After boundary |
|---|---:|---:|---:|
| Accept | Pass | Pass | Pass |
| Dismiss, then type | Pass | Pass | Pass |
| Accept, then first and second Backspace | Pass | Pass | Pass |

The frozen stock fixture types `i look forward `, observes UIKit's marked
suffix `to` at canonical range `{33,2}`, and accepts it with one physical
software-keyboard Space. Acceptance produces `…look forward to  ` with the
caret at UTF-16 offset 36. Dismissal uses UIKit's
`removeInlineTextCompletionPrompt` path and then types `x`. The deletion
lifecycle compares the first Backspace (`…to  ` to `…to `) and second
Backspace (`…to ` to `…t `) as separate phases.

## Ownership boundary

UIKit owns candidate generation, marked presentation, timing, policy,
acceptance, dismissal, learning, and deletion behavior. InputDec does not
contain a prediction model, prompt view, recognizer, timer, or
fixture-specific mutation path.

The custom editor supplies canonical UTF-16 storage, independent block
projection, layout, geometry, and drawing. Its one `UITextInputController`
continues to own selection and marked-text transactions. The only production
repair was the stock forwarding surface:

```text
IDTextView / IDBlockTextView
  setAttributedMarkedText:selectedRange:
    -> UITextInputController setAttributedMarkedText:selectedRange:
```

The attributed value and `NSRange` pass through unchanged. The selector is a
required fail-closed iOS 26.5 compatibility contract.

## Hopper recovery

The complete trace and assembly notes are retained in
`docs/hopper/UIKitCore-iOS26.5.md`. The recovered marked-text path is:

| Offset | Owner and relevant ABI |
|---|---|
| `0x165a3cc` | `UIInlineTextCompletionController _updateTextCompletionPrompt:executionContext:` derives the suffix and requests marked presentation. |
| `0xfb6bc0` | `+[UIKeyboard presentsInlineTextCompletionAsMarkedText]` selects the marked-text presentation path. |
| `0xfd7950` | `UIKeyboardImpl presentTextCompletionAsMarkedText:` forwards one object argument. |
| `0x7c9968` | `_UIKeyboardStateManager presentTextCompletionAsMarkedText:` consumes styled strings and selection and returns `BOOL`. |
| `0x7a66ac` | `_setAttributedMarkedText:selectedRange:inputString:lastInputString:searchString:compareAttributes:` takes an object, `NSRange`, four objects, and `BOOL`, then returns an integer status. |
| `0x1615af8` | `UITextView setAttributedMarkedText:selectedRange:` is `void` with object plus `NSRange` and forwards unchanged. |
| `0x10c7790` | `UITextInputController _setAttributedMarkedText:selectedRange:` retains the styled intermediate value. |
| `0x15ee62c` | `UITextInputController setAttributedMarkedText:selectedRange:` is `void` with object plus `NSRange`. |
| `0x15ede9c` | The controller's keyboard-aware marked implementation performs one coordinated storage transaction and invalidates layout. |

Space acceptance runs through `_UIKeyboardStateManager` at `0x7baf48` and
`0x7bb1c8`, then the inline controller policy/commit chain at `0x165bb10`,
`0x165bbe8`, `0x165be94`, `0x165bc7c`, and `0x165b8b4`. Dismissal runs
through `0x1659b44`, `0x7c9b34`, `0x7cb038`, and `0xfd85bc`. The alternate
direct-tap entries at `0xfd6dd8` and `0xfd70bc` do not reproduce the physical
Space transaction for this marked-text fixture. Immediate completion undo is
owned by `UIInlineTextCompletionController` at `0x165c468`.

Ranges at the editor boundary are `UITextRange` objects backed by canonical
UTF-16 offsets; the styled intermediate selection is `NSRange`. Prediction
geometry is the ordinary `firstRectForRange:` result in text-view content
coordinates. No separate prediction canvas participates in this iOS 26.5
path.

## Authoritative matrix

The final inline-prediction runner erases and reboots one pinned simulator
before every host execution. It never creates or clones a simulator, refuses
overlapping XCTest, passes `-parallel-testing-enabled NO`, preserves every
attempt, and validates the exact device and OS build. A fixed 20-second
post-boot readiness window lets the freshly erased on-device language model
start. Only the exact native-offer-absent failure may retry, at most three
times; semantic failures and crashes remain immediately fatal.

```sh
Scripts/run-inline-prediction-complete-matrix.sh \
  FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  .inline-prediction-task6-complete-matrix-attributed3 \
  26.5 23F73
```

- Result: 36/36 stock/custom comparisons and 72/72 independently erased host
  executions passed.
- Retries: zero; every host passed on attempt 1.
- Evidence root:
  `.inline-prediction-task6-complete-matrix-attributed3/`.
- Contents: 72 xcresults, 72 validated compact summaries, and 36 comparator
  logs.
- Phase coverage: 12 five-phase acceptance comparisons, 12 six-phase
  dismissal comparisons, and 12 seven-phase deletion comparisons.
- Device: iPhone 17 Pro K3,
  `FA6F7462-AA97-42FE-9E57-8DA0593CE756`.
- Runtime: iOS 26.5 (23F73), English (US).

Every compact summary was independently revalidated with:

```sh
Scripts/validate-autocorrection-summary.py \
  SUMMARY.json FA6F7462-AA97-42FE-9E57-8DA0593CE756 26.5 23F73
```

## Inherited verification

All simulator tests below ran serially with no overlapping XCTest process.

| Gate | Result | Retained evidence |
|---|---:|---|
| Focused attributed-marked tests and fixture smoke | 3 passed, 0 failed/skipped | `.inline-prediction-task6-attributed-unit1.xcresult` |
| Lifecycle contracts and private bridge suite | 55 passed, 0 failed/skipped | `.inline-prediction-task6-contract-private-attributed1.xcresult` |
| Complete units except the retained spelling-pixel oracle | 497 passed, 0 failed/skipped | `.inline-prediction-task6-all-units-attributed1.xcresult` |
| Inherited UI excluding isolated autocorrection and prediction matrices | 86 passed, 0 failed/skipped | `.inline-prediction-task6-inherited-ui-attributed1.xcresult` |

The complete unit and inherited UI commands were:

```sh
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=FA6F7462-AA97-42FE-9E57-8DA0593CE756' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath .inline-prediction-task6-all-units-attributed1.xcresult \
  -only-testing:InputDecTests \
  -skip-testing:InputDecTests/IDBlockTextViewParityTests/testNativeSpellingPixelCountsMatchStockInCanonicalWordROI

xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=FA6F7462-AA97-42FE-9E57-8DA0593CE756' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath .inline-prediction-task6-inherited-ui-attributed1.xcresult \
  -only-testing:InputDecUITests \
  -skip-testing:InputDecUITests/IDAutocorrectionDecisionUITests \
  -skip-testing:InputDecUITests/IDInlinePredictionLifecycleUITests
```

The attributed-marked repair also requires the independently erased closed
autocorrection matrix to remain green. Its current-head rerun is retained at
`.inline-prediction-task6-autocorrection-regression-attributed1/`.

- Result: 84/84 comparisons and 168/168 independently erased host executions
  passed with zero failures or skips.
- Contents: 168 xcresults, 168 validated summaries, and 84 comparator logs.

## Limits

This result is specific to UIKitCore iOS 26.5 (23F73), the English (US)
keyboard, and the frozen fixture above. Japanese and Chinese IME composition,
dictation, hardware-key navigation, and other language models remain outside
this verified slice.

The pre-existing spelling-marker limitation remains: stock and custom use
the same native temporary spelling rendering, but their marker pixel density
is not identical in the strict screenshot oracle. That one pixel-density
test is excluded from the otherwise complete unit gate; native spelling
appearance and removal remain covered separately.

## Final review

The implementation baseline before the final attributed-marked repair was
`b4c64fb46dd75201600f75777207c6226adc4078`.

Whole-slice review found one Important issue: the required attributed-marked
selector was checked for presence, but the common object-plus-range bridge did
not reject a wrong-but-present ABI before dispatch. The focused RED called the
synthetic wrong method and failed three assertions in
`.inline-prediction-task7-object-range-abi-red1.xcresult`. The repaired bridge
now validates `void`, object, and exact `NSRange` encodings before its typed
send. Focused GREEN passed 4/4 in
`.inline-prediction-task7-object-range-abi-green1.xcresult`; the broader
current-head controller/editor/source review passed 172/172 in
`.inline-prediction-task7-review-contract-green1.xcresult`. No Critical,
Important, or Minor finding remains.

XcodeGen produced project hash
`e4e4954b711695d15e518f50af21df955c1daec0a6eaa8f08a2de14ada9a8ea1`
twice, with no tracked project diff. `git diff --check` and the generic iOS
Simulator build passed.

After review, K3 was shut down, erased, booted, and given the same 20-second
model-readiness window. The final real-HID
`testCustomBeforeBoundaryAcceptThenDeleteMatchesStock` proof passed exactly
one test with zero failures/skips on iOS 26.5 (23F73):

```sh
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=FA6F7462-AA97-42FE-9E57-8DA0593CE756' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath .inline-prediction-final-hid-attributed1.xcresult \
  -only-testing:InputDecUITests/IDInlinePredictionLifecycleUITests/testCustomBeforeBoundaryAcceptThenDeleteMatchesStock
```

The retained bundle is `.inline-prediction-final-hid-attributed1.xcresult`;
its validated compact summary is
`.inline-prediction-final-hid-attributed1-summary.json`.

The reviewed implementation commit is
`67a8a69a57decaa492ee33e8f07468e63f74ed0a`. Immediately after that commit,
`git status --porcelain --untracked-files=no` was empty. All untracked
xcresults, summaries, logs, and exported attachments remain preserved and
were not added to Git.
