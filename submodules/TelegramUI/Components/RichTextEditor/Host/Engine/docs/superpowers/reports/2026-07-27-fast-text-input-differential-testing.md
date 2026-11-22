# Fast Text-Input Differential Testing

## Result

InputDec now has three explicit verification tiers for the pinned iPhone 17
Pro K3 simulator, iOS 26.5 (23F73),
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`.

| Tier | Scope | Retained result |
|---|---|---|
| 1 — semantic differential | 54 versioned scenarios, stock/custom in both orders | 198/198 twice, zero skips, 8.185 s and 8.056 s |
| 2 — real-keyboard sentinels | 8 serialized English/Japanese/Chinese methods | 8/8, zero skips, 224 s wall |
| 3 — isolated certification | 24 IME + 21 autocorrection + 9 inline rows, two repetitions and both orders | 216 comparisons, 432 host executions |

Tier 1 proves that stock and custom editors respond equivalently to equal
semantic `UITextInput`, `UIKeyInput`, responder, trait, and Undo transactions.
Tier 2 proves representative integration with real system keyboards. Tier 3
remains the authority for isolated OS behavior.

Semantic replay does not claim to test candidate-bar UI, input-mode
activation, keyboard learning, keyboard-process readiness/timing, or native
prediction availability. Those remain real-keyboard responsibilities.

## Commands

Routine fast gate:

```sh
Scripts/run-text-input-fast.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  --output .text-input-fast
```

Representative real-keyboard gate:

```sh
Scripts/run-text-input-keyboard-sentinels.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  --output .text-input-keyboard-sentinels
```

Complete iOS 26.5 certification:

```sh
Scripts/run-text-input-ios26-certification.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  --output .text-input-ios26-certification
```

Every command acquires the same repository-wide K3 lock. Every
`xcodebuild test` path uses `-parallel-testing-enabled NO`; simulator
parallelization and overlapping XCTest processes are unsupported.

The certification wrapper runs, in order, the fast gate, keyboard sentinels,
complete IME matrix, complete autocorrection matrix, and complete inline
prediction matrix. It refuses an existing output root and writes distinct
child directories. Its final `summary.json` is emitted only after every child
summary is present and complete.

## Corpus and provenance

The shared corpus contains:

- 24 Japanese Romaji and Simplified Chinese Pinyin IME scenarios;
- 21 English (US) autocorrection accept, reject, and undo scenarios;
- 9 English (US) inline-prediction accept, dismiss, and delete scenarios.

The opt-in validator compares all 54 identifiers and terminal canonical
documents with preserved exported stock evidence:

```sh
Scripts/validate-text-input-scenario-provenance.py \
  --fixture-root TestFixtures/TextInputScenarios \
  --ime-evidence .ime-task9-complete-matrix-attempt5 \
  --autocorrection-evidence .autocorrection-task6-complete-matrix-green2 \
  --inline-prediction-evidence .inline-prediction-task6-complete-matrix-stable1
```

The retained cross-validation passed 24 IME, 21 autocorrection, and 9 inline
identifiers. The validator uses exported lifecycle, parity, manifest, and
status JSON only; it does not rewrite fixtures or require evidence during
ordinary unit tests.

Two narrowly documented keyboard-UI transformations are removed before the
semantic terminal comparison: candidate-bar acceptance immediately before a
structural newline adds one UIKit-owned spacer, and dismiss-by-typing consumes
the whitespace immediately before an inline offer. The semantic fixtures
freeze the equivalent direct text-input replacements, not those candidate-UI
whitespace policies. No other canonical normalization is allowed.

## Evidence and timing

- Consecutive current-head fast runs:
  `.fast-input-task9-fast-green2/summary.json` and
  `.fast-input-task9-fast-green3/summary.json`, each 198 passed, 0 failed,
  and 0 skipped, in 8.185 and 8.056 seconds.
- Keyboard sentinel:
  `.fast-input-task9-keyboard-sentinels-green1/summary.json`, 8 passed,
  0 failed, 0 skipped, 224 seconds wall and 187.164 seconds summed XCTest
  time. Inline dismissal used one allowed native-offer-readiness retry; no
  semantic failure retried.
- IME provenance/certification evidence:
  `.ime-task9-complete-matrix-attempt5/summary.json`, 24 logical rows,
  96 comparisons, and 192 host executions. The retained log timestamps span
  13,050 seconds; this demonstrates why Tier 3 is not a routine gate.
- Autocorrection evidence:
  `.autocorrection-task6-complete-matrix-green2/`, 21 logical rows,
  84 comparisons, and 168 host executions.
- Inline provenance evidence:
  `.inline-prediction-task6-complete-matrix-stable1/`, all 9 logical
  identifiers represented. The complete 36-comparison authority and its
  limits remain documented in
  `2026-07-23-inline-prediction-lifecycle-parity.md`.

All evidence roots are intentionally untracked research artifacts. Missing
preserved evidence makes provenance validation fail; it does not make the
portable unit suite fail.

The first broader unit attempt,
`.fast-input-task9-all-units-green.xcresult`, executed 559 tests: 555 passed
and four native-spelling-marker tests failed because the simulator had been
left in a non-English active input mode. The isolated rerun in
`.fast-input-task9-spelling-readiness-probe1.xcresult` reproduced zero red
pixels for both stock and custom editors. After the pinned keyboard provisioner
restored its fixed English fallback, the exact aggregate passed 559/559 with
zero failures/skips in `.fast-input-task9-all-units-green2.xcresult`. The RED
evidence is retained because it demonstrates that native spelling-marker tests
depend on active keyboard language, not only `UITextChecker` availability.
