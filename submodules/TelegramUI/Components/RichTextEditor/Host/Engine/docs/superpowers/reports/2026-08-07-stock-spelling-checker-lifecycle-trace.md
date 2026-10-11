# Stock Spelling Checker Lifecycle Trace Report

## Outcome

The missing stock underline is caused by UIKit's cold asynchronous
`UITextChecker` lifecycle, not by the English input mode, misspelling data,
temporary-attribute rendering, or InputDec's custom canvas.

On iOS 26.5, the first one-shot departed-word request can reach
`UITextCheckingController checkSpellingForWordInRange:` while its lazily
allocated checker is still loading. `textChecker` returns `nil`, the request is
dropped, and waiting does not retry it. A later departed word runs the complete
native pipeline.

## Hopper findings

- `UITextCheckingController didChangeSelectionFromRange:` forwards the prior
  selection into selection-change spelling.
- `textChecker` constructs `UITextChecker` with
  `_initWithAsynchronousLoading:YES` and exposes it only after `_doneLoading`.
- `checkSpellingForWordInRange:` exits when that getter returns `nil`; it has no
  completion callback or retry branch.
- A ready check calls `+[UITextChecker keyboardLanguages]`, which derives its
  languages from the shared input-mode controller, then writes alternatives
  display style 2 for a misspelling.

## Live differential evidence

Final live-only result:

- `.spelling-lifecycle-notification-green.xcresult`
- exported evidence: `.spelling-lifecycle-notification-attachments/`
- one test passed, zero failures, serialized with
  `-parallel-testing-enabled NO` and `-collect-test-diagnostics never`.

One-shot `mispelled ` trace:

- `didChangeSelectionFromRange:` observed;
- `checkSpellingForSelectionChangeFromRange:` observed;
- `checkSpellingForWordInRange:` observed;
- `textChecker` returned unavailable at 0.104 seconds;
- no `keyboardLanguages` call;
- no temporary rendering ranges;
- classification: `checkerUnavailable`.

Staged two-word trace:

- four checking-controller selection notifications;
- two departed-word checks;
- both checker getter results available;
- exact internal checking languages: `["en_US"]`;
- temporary rendering ranges: `{0,9}` and `{10,4}`;
- classification: `complete`.

All six test-only runtime hooks restored their original IMPs. The initial red
contract result is `.spelling-lifecycle-contract-red.xcresult`; the focused
contract green result is `.spelling-lifecycle-contract-green.xcresult`; the
semantic-notification red result is
`.spelling-lifecycle-notification-red.xcresult`.

The retained spelling-readiness regression result is
`.spelling-lifecycle-readiness-regression.xcresult`: 20 tests passed with zero
failures, serialized with `-parallel-testing-enabled NO` and diagnostics
collection disabled.

After the final source cleanup, `.spelling-lifecycle-final.xcresult` repeated
that exact selection: 20 tests passed with zero failures in 1.859 seconds.

## Scope and next repair

No production editor source or production private-API surface changed. The
diagnostic does not preheat UIKit, manufacture annotations, or alter method
arguments and results.

The next repair should change the stock readiness stimulus, not InputDec's
spelling implementation: depart one misspelled word to start UIKit's native
checker, allow its normal asynchronous loading interval, then depart a second
misspelled word and classify that second native result. This retains UIKit
end-to-end and avoids calling private `preheatTextChecker`.
