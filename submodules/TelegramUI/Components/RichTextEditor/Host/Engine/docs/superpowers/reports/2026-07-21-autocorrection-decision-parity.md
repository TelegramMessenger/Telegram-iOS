# iOS 26.5 Autocorrection Decision Parity

## Result

`IDBlockTextView` matches stock `UITextView` for the complete 21-row English (US)
autocorrection decision matrix on iOS 26.5 (23F73). UIKit owns candidate generation,
presentation, acceptance, rejection, learning, and immediate correction undo. InputDec supplies
the canonical multi-block document, custom layout/drawing, geometry, and recovered host forwarding.

| Decision | Interior | Before boundary | After boundary |
|---|---:|---:|---:|
| Accept with Space | Pass | Pass | Pass |
| Accept with punctuation | Pass | Pass | Pass |
| Accept by candidate tap | Pass | Pass | Pass |
| Reject before commit | Pass | Pass | Pass |
| Space, then immediate undo | Pass | Pass | Pass |
| Punctuation, then immediate undo | Pass | Pass | Pass |
| Candidate tap, then immediate undo | Pass | Pass | Pass |

Each row compares chronological phases, canonical text, block values, selection/affinity, marked
range, structural newlines, checking ranges, candidate state, responder/keyboard state, and
correction geometry. Rejection must survive a following Space; undo rows compare both Backspaces.

## Isolation and repeatability

Keyboard learning survives ordinary relaunches. The authoritative runner erases before every host
half, retains both result bundles, exports immutable attachments, and compares them offline. It
runs all rows twice in both host orders. The runner now also reads every xcresult summary and
requires exactly one passed test, zero failures/skips/expected failures, the requested simulator,
and the pinned OS version/build before declaring a host execution successful.

- Evidence: `.autocorrection-task6-complete-matrix-green2/`
- Result: 84/84 comparisons, 168/168 host executions, zero skips.
- Device: iPhone 17 Pro K3, iOS 26.5 (23F73),
  `FA6F7462-AA97-42FE-9E57-8DA0593CE756`.
- Runner/comparator: `Scripts/run-autocorrection-complete-matrix.sh` and
  `Scripts/compare-autocorrection-results.py`.

The exact authoritative matrix command was:

```sh
Scripts/run-autocorrection-complete-matrix.sh \
  FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  .autocorrection-task6-complete-matrix-green2
```

During final review, all 168 retained summaries were read directly with
`xcrun xcresulttool get test-results summary --compact`; every bundle reported
`Passed`, `totalTestCount=1`, `passedTests=1`, `failedTests=0`, and
`skippedTests=0` on iOS 26.5 (23F73).

## UIKit contracts

The Hopper ledger is `docs/hopper/UIKitCore-iOS26.5.md`. Key contracts include
`UITextView _deleteBackwardAndNotify:` at `0x1613b90` (`v@:B`),
`UITextInputController _performWhileSuppressingDelegateNotifications:` at `0x15edd90`
(`v@:@?`), and `UIKBInputDelegateManager` conformance/deletion paths at `0xbe4e14`, `0xbe5a94`,
and `0xbead40`. Formal `UIKeyboardInput` adoption selects UIKit's legacy deletion route.
Runtime lookup, protocol mutation, and typed dispatch remain confined to `PrivateUIKit/`.

## Verification and limits

- Review units: 478 passed, zero failures/skips, excluding only the pre-existing spelling-pixel
  oracle, in `.autocorrection-review-all-units-green1.xcresult`.
- Review inherited UI: 86 passed, zero failures/skips, with the isolated autocorrection class
  excluded to prevent keyboard-history contamination, in
  `.autocorrection-review-inherited-ui-green1.xcresult`.
- XcodeGen produced project hash
  `6438b5ce2e379a058588b889d2a26ddf402c153771022fc1945e23d5bbdbfca6` twice.
- Generic simulator build and `git diff --check` passed.

The exact fresh aggregate commands were:

```sh
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=FA6F7462-AA97-42FE-9E57-8DA0593CE756' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath .autocorrection-review-all-units-green1.xcresult \
  -only-testing:InputDecTests \
  -skip-testing:InputDecTests/IDBlockTextViewParityTests/testNativeSpellingPixelCountsMatchStockInCanonicalWordROI

xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=FA6F7462-AA97-42FE-9E57-8DA0593CE756' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath .autocorrection-review-inherited-ui-green1.xcresult \
  -only-testing:InputDecUITests \
  -skip-testing:InputDecUITests/IDAutocorrectionDecisionUITests

xcodebuild build -quiet -project InputDec.xcodeproj -scheme InputDec \
  -destination 'generic/platform=iOS Simulator'
```

## Final review and proof

The whole slice was reviewed against `2704fda`. Production ownership, all 21 decisions,
atomic block replacement/rebasing, private ABI provenance, exact source manifests, and retained
evidence were inspected. The review found and resolved two Important harness issues and one Minor
documentation issue:

- matrix scripts trusted `xcodebuild` exit status without enforcing zero skips or the pinned
  device/build;
- the versioned status parser did not enforce the exact nested candidate and keyboard schemas;
- the planned final proof selector did not exist, and the report lacked final command/SHA/proof
  details.

The fixes are in reviewed implementation commit `718ccc2`. At that commit,
`git status --porcelain --untracked-files=no` was empty; all untracked evidence was preserved.
The validator has five executable Python contract tests, including skip, count, boolean-type,
device, OS-version, and OS-build rejection. The Objective-C contract gate has adversarial nested
schema coverage.

After review, the simulator was shut down, erased, booted, and the corrected non-overlapping HID
proof ran with:

```sh
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=FA6F7462-AA97-42FE-9E57-8DA0593CE756' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath .autocorrection-review-final-hid-green1.xcresult \
  -only-testing:InputDecUITests/IDAutocorrectionDecisionUITests/testCustomBeforeBoundaryUndoSpaceMatchesStock
```

Result: 1 passed, zero failures/skips, iOS 26.5 (23F73). The preserved result is
`.autocorrection-review-final-hid-green1.xcresult`; its validated compact summary is
`.autocorrection-review-final-hid-green1-summary.json`.

The retained spelling limitation is a stock/custom marker pixel-density difference; native marker
behavior passes. Inline prediction and non-English/IME composition remain outside this slice.
