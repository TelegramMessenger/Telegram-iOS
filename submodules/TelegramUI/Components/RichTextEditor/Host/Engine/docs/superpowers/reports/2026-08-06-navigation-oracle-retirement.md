# Navigation Oracle Retirement Report

## Outcome

`IDDocumentLayoutCoordinator` is now the sole directional-navigation
implementation and authority in both DEBUG and Release. The DEBUG-only
established TextKit traversal, its comparison helper, its alternate return
path, and its traversed-block bookkeeping have been deleted. There is no
fallback navigation implementation.

The implementation landed in three commits:

- `cdf8a02` — add stock/custom public navigation characterization;
- `8f4916d` — add the single-authority source contract and mutation proof;
- `c88151d` — delete the duplicate caret-navigation oracle and parity-only
  tests.

All slice-owned focused, public-interaction, semantic, Release, and
real-system-keyboard gates passed on iPhone 17 Pro K3
(`FA6F7462-AA97-42FE-9E57-8DA0593CE756`), iOS 26.5 build `23F73`, with
parallel simulator testing disabled.

## UIKit-driven stabilization evidence

Before deletion, the demo and stock-oracle hosts gained identical bounded
fixtures for horizontal BiDi/emoji/empty-block movement, vertical
long-short-long movement, and Shift-arrow extension/reversal/collapse. The
tests use public key dispatch and compare canonical selection state between
stock `UITextView` and `IDBlockTextView`; the hosts run sequentially.

`.navigation-retirement-task2-isolated-hosts.xcresult` passed all 3 new
families with 0 failures and 0 skips in 88.157 seconds. This evidence includes
LTR structural-newline traversal, mixed Hebrew visual movement, atomic family
emoji movement, consecutive empty blocks, preservation of the original
vertical document X, and selection reversal through multiple structural
newlines.

## Midpoint deletion authorization

The retained-oracle midpoint was green before any oracle code was removed:

| Gate | Evidence | Passed | Failed | Skipped | Duration |
| --- | --- | ---: | ---: | ---: | ---: |
| Focused units and public arrows | `.navigation-retirement-task3-midpoint-arrows-units.xcresult` | 109 | 0 | 0 | 111.172 s |
| Selection/loupe/handles | `.navigation-retirement-task3-midpoint-loupe-selection.xcresult` | 3 | 0 | 0 | 68.977 s |
| Floating cursor | `.navigation-retirement-task3-midpoint-floating.xcresult` | 9 | 0 | 0 | 323.080 s |

The earlier oracle-retained focused baseline
`.navigation-retirement-task1-focused-baseline.xcresult` passed 123/123 with
zero skips in 3.030 seconds. No DEBUG mismatch assertion fired in the public
characterization or midpoint runs, authorizing deletion.

## Deleted implementation and retained geometry support

`IDRichTextLayoutController.m` no longer contains
`id_establishedNavigationFromPosition:`,
`id_adjacentClusterOffsetFromOffset:`,
`id_compareNeutralNavigationFromPosition:`, or the
`traversedBlockIdentifiers` shadow state. Ten parity-only controller tests and
their now-unused scripted-oracle support were removed; the controller suite
changed from 67 to 57 tests while its authority, malformed-result, revision,
and geometry coverage remained.

`IDRichMountedCanvasMatchesNeutralOrigin` remains only for the unrelated
DEBUG geometry differentials in insertion-rectangle comparison and nearest
point-hit-test comparison. It is not a navigation implementation, return
path, or fallback.

The post-deletion focused gate
`.navigation-retirement-task5-focused-green.xcresult` passed 113/113 with
zero skips in 3.181 seconds. The iOS Simulator Release configuration also
built successfully during Task 5.

## Single-authority contract and mutation proof

The source contract isolates the directional-navigation callback slice and
requires exactly one coordinator-backed call and one return path in every
conditional branch. It rejects obsolete oracle symbols, alternate returns,
and comparison machinery.

The intended RED run
`.navigation-retirement-task4-contract-red.xcresult` failed its single test
against the retained oracle. The pure-audit mutation run
`.navigation-retirement-task4-audit-mutations-green.xcresult` then passed 2/2:
one mutation inserted an obsolete helper and the other inserted an alternate
return. After deletion, `.navigation-retirement-task6-post-ui-contract.xcresult`
passed all 3 authority tests, and the post-keyboard focused gate
`.navigation-retirement-task8-post-keyboard-focused.xcresult` passed 60/60
with no failures or skips in 2.067 seconds.

Deterministic units continue to cover unmounted/virtualized destinations,
stale document and layout revisions, malformed or incoherent snapshots and
results, nonfinite geometry, and atomic multi-step failure. Horizontal
multi-step movement carries returned document anchors; vertical multi-step
movement retains the original caller document X.

## Public arrows, selection, loupe, and floating cursor

All post-deletion public behavior gates matched the midpoint evidence:

| Gate | Evidence | Passed | Failed | Skipped | Duration |
| --- | --- | ---: | ---: | ---: | ---: |
| Arrow/Shift-arrow family | `.navigation-retirement-task6-public-arrows-green.xcresult` | 5 | 0 | 0 | 110.649 s |
| Selection/loupe/handles | `.navigation-retirement-task6-loupe-selection-green.xcresult` | 3 | 0 | 0 | 68.806 s |
| Floating cursor | `.navigation-retirement-task6-floating-green.xcresult` | 9 | 0 | 0 | 323.369 s |

These tests exercise UIKit-owned interaction end to end. This pass did not
change selection drawing, handles, point-hit-test authority, insertion
geometry, line-range authority, annotations, attachments, rendering,
autoscroll, TextKit 1, or Telegram integration.

## Unit, semantic, release, and keyboard verification

The complete unit target evidence is preserved without concealing harness
conditions:

- `.navigation-retirement-task7-all-units.xcresult`: 876 passed, 8 failed,
  0 skipped, 48.447-second result interval. The two expected unrelated
  failures were
  `IDBlockTextViewTests/testEmptyBlockExposesConfiguredDefaultsToNativeTypingAndInsertion`
  and
  `IDFloatingCursorContractTests/testStockOracleHostContainsNoPrivateRuntimeKnowledgeOrSyntheticLifecycleCounters`.
- `.navigation-retirement-task7-all-units-scoped.xcresult`: after excluding
  exactly those two methods, 876 passed, 6 failed, 0 skipped, 48.373-second
  result interval.
- The remaining six methods are the five previously documented native
  spellchecker-pixel methods plus the aggregate-order iPad demo-layout
  threshold. In
  `.navigation-retirement-task7-known-harness-isolated.xcresult`, the exact
  iPad method passed unchanged, while all five spelling methods reproduced
  the simulator-wide absence of native red pixels. The parity test recorded
  zero red pixels for both stock `UITextView` and the custom editor. No
  assertion, threshold, timeout, or test exclusion was changed.

Thus the plan's aspirational all-green scoped-unit gate was not met, but its
additional failures were directly reproduced as established non-navigation
harness conditions; no navigation-retirement test failed.

The bounded semantic gate
`.navigation-retirement-task7-fast/summary.json` passed 252 tests with 0
failures and 0 skips in 11.335 seconds, below its 30-second limit.

The real-system-keyboard aggregate
`.navigation-retirement-task8-keyboard-sentinels/summary.json` passed all 24
sentinels with 0 failures and 0 skips in 751 seconds wall time: 20 English
(599.328 seconds), 2 Japanese (32.063 seconds), and 2 Simplified Chinese
(32.753 seconds). English `inline-accept-minimal` and
`inline-dismiss-before-boundary` each used one supported readiness retry;
both first attempts are preserved under `readiness-attempts/attempt-1`.
There were no semantic retries. The output contains 24 unique one-test child
summaries plus provisioning, learning-reset, and aggregate summaries.

## Private-surface and deterministic-generation delta

This slice added no private selector, bridge method, private class, private
header, or behavior-manifest member. The final inventories exactly match the
baseline:

- production capability members: `127`;
- production reference-only members: `53`;
- test-only capability members: `25`.

The eight protected hashes remained, in order:

```text
d2143fb0a8d056793885a4a1ea117d93a83fff59
b6b7d08f1cf628a78d30f1a20347cd8dc4c5aacd
1e8932f895b1b34deaf62c282c979d30396f97e9
e6c83173a538ba6917b80606c9a0c27d36370a0a
1bd772ce241f64dbf012ad3d03b31a6950c0ed0a
6195c21d8ee6293946de7e44d67edd27aae3c375
86e2ace9c8a385d5f2009897b9dc0dfb61abbfc3
76fdd6e28dfbfa3e43fcd847e08dcefb217bf8a3
```

Two consecutive `xcodegen generate` invocations produced the same project
hash,
`ec5754815e9184855b27ce84134d104b4a4b0eab3a39a7b1eebccf851caa18b8`,
and left `InputDec.xcodeproj/project.pbxproj` unchanged. The committed range
from `4ed9255` through the implementation commits has no private bridge or
manifest delta attributable to this slice.

## Worktree preservation

The repository already contained extensive unrelated tracked modifications
and untracked exploration/test artifacts. They were neither cleaned nor
staged. Each implementation commit staged only its plan-owned source or test
files, and the report commit stages only this document. Generated `.xcresult`
bundles and runner output remain untracked.

## Next independent editor slice

Navigation-oracle retirement is closed and does not gate the next editor
slice. The next slice may independently reduce another private callback
family or advance custom rich-text layout/drawing, while treating
`IDDocumentLayoutCoordinator` as the single, stable cross-block directional
navigation authority. It should preserve the same public stock/custom arrow,
selection/loupe, floating-cursor, fail-closed unit, fast semantic, and
serialized real-keyboard gates appropriate to its scope.
