# TextKit-Neutral Navigation Authority Switch Report

## Outcome

Directional caret navigation in `IDRichTextLayoutController` now has one production authority: `IDDocumentLayoutCoordinator`. The controller translates the UIKit callback into project-owned values, invokes the coordinator's exact one-step primitive for every requested step, validates the complete result, and returns only the neutral destination. There is no production fallback to the former document-level TextKit traversal.

The former traversal remains for one stabilization slice in DEBUG builds only. It computes an independent oracle result and asserts parity, but it cannot supply, repair, or replace the production result. A release build and preprocessor-aware source contracts prove the established traversal is absent from production compilation.

This slice changes caret-navigation authority only. It does not change point hit testing, line ranges, selection drawing or handles, annotations, attachments, rendering, TextKit 1 behavior, or Telegram integration.

## Production authority and data flow

`-[IDRichTextLayoutController id_positionFromPosition:inDirection:offset:affinity:anchorPositionOffset:]` now performs the complete callback transaction:

1. It validates the source position and strictly translates UIKit direction and affinity values. Unknown enum values fail instead of being coerced.
2. It reverses the requested direction for a negative signed offset and iterates the absolute step count in the controller. The coordinator remains an exact one-step primitive.
3. Every step calls `-[IDDocumentLayoutCoordinator visuallyAdjacentPositionFromCanonicalOffset:affinity:direction:anchorPositionOffset:]`.
4. Horizontal movement carries the document anchor returned by each step. Vertical movement supplies the original caller document X to every step, including long-short-long and multi-block traversal.
5. The controller validates every returned neutral position before advancing the transaction. It publishes no intermediate destination.
6. Only after every step succeeds does it construct the returned `IDRichTextPosition`, preserving the source anchor's `tracksChanges` semantics.

Providers remain block-local. Cross-block decisions consume neutral snapshots, canonical projection, ordered block identifiers, and project-owned document origins. The authority path does not mount a view, inspect a neighboring TextKit graph, scan past an unavailable adjacent block, or create a joined-document TextKit layout.

The authority tests deliberately inject a coherent but different neutral destination while making the DEBUG oracle ineligible. Horizontal destination, vertical destination and affinity, signed and multi-step movement, and tracked-anchor behavior all follow the coordinator result. Atomicity tests prove a later failed step returns `nil` rather than exposing an earlier successful step.

## Fail-closed validation

The production controller returns `nil` for every malformed or unverifiable transaction covered by this slice:

- absent or nonexact coordinator output;
- a stale document revision, including a revision change observed after an exact coordinator return;
- invalid UIKit or neutral direction/affinity values;
- nonfinite input or returned anchors;
- a destination beyond the current canonical length;
- disagreement between canonical identity and block-local identity;
- a later invalid step in a signed or multi-step callback.

A nonfinite caller anchor is rejected before the coordinator is called. Multi-step movement validates all steps against the transaction revision and constructs a position only at the end. There is no legacy recovery path and no partially advanced caret.

## Retained DEBUG oracle

The stabilization oracle is enclosed by DEBUG preprocessing and consists of:

- `id_establishedNavigationFromPosition:direction:offset:affinity:anchorPositionOffset:finalDocumentAnchor:`;
- `id_adjacentClusterOffsetFromOffset:direction:`;
- `id_compareNeutralNavigationFromPosition:originalDirection:signedOffset:neutralResult:neutralFinalAnchor:affinity:anchorPositionOffset:traversedBlockIdentifiers:stage:`;
- navigation use of `IDRichMountedCanvasMatchesNeutralOrigin` and the traversed-block diagnostic list.

The oracle repeats the former document-level TextKit/block-layout algorithm independently. When mounted canvas origins still match the published project origins, it compares presence, canonical destination, affinity, final anchor, and revision with the neutral result. Mismatch assertions are diagnostic only; the neutral result remains the authority.

Mutation tests independently alter oracle destination, affinity, and anchor and require `NSInternalInconsistencyException`. Authority tests separately make the oracle ineligible and prove the neutral result is still returned. `testNeutralCrossBlockNavigationIsProductionAuthorityWithDebugOnlyEstablishedOracle` parses active preprocessor branches, and a release build verifies that the established traversal does not compile into production.

## Public arrows and interaction behavior

Public arrow coverage drives the editor through the UIKit callback boundary rather than calling the coordinator directly. The collapsed caret sequence crosses structural separators in both directions at canonical offsets `3 -> 6 -> 7 -> 5`. Shift-arrow selection includes each structural newline exactly once and ends at the stock-compatible endpoint.

The combined arrow/unit interaction result, `.neutral-authority-task6-arrows-and-unit-interaction.xcresult`, passed 39 of 39 tests: 37 interaction units and two public UI arrow tests. The explicit unit interaction run `.neutral-authority-task6-unit-interaction.xcresult` passed 37 of 37. Loupe and selection-handle coverage in `.neutral-authority-task6-loupe-selection.xcresult` passed 3 of 3. Focused floating-navigation coverage in `.neutral-authority-task6-floating-navigation.xcresult` passed 5 of 5. All had zero failures and zero skips.

These gates preserve UIKit-owned interaction dispatch while allowing project-owned selection presentation later. This slice does not make UIKit's selection drawing or handles authoritative.

## Floating-cursor and real-keyboard certification

All keyboard tests used the pinned iPhone 17 Pro K3 simulator, UDID `FA6F7462-AA97-42FE-9E57-8DA0593CE756`, on iOS 26.5 build 23F73. XCTest execution was serialized through the global lock with `-parallel-testing-enabled NO`; no cloned or additional simulator was used.

The final persistent-device result, `.neutral-authority-task8-keyboard-sentinels-final/summary.json`, passed 24 of 24 tests with zero failures and zero skips in 771 seconds wall time:

- 20 English tests covering autocorrection accept/reject, inline-prediction accept/dismiss, floating cursor, selection extension, bold typing, formatting-aware autocorrection, prediction, and marked-text commit;
- two Japanese Romaji return/commit/undo tests;
- two Simplified Chinese Pinyin candidate-commit tests;
- normal and minimal behavior backends wherever required.

Every method has a distinct one-test child summary and `.xcresult`. Two supported keyboard-service readiness retries were retained: attempt 1 of `inline-accept-minimal` and attempt 1 of `inline-dismiss-before-boundary`; both passed on attempt 2.

The first diagnostic matrix exposed that formatting tests accepted Japanese Romaji as “ready” because it also presents Latin key identifiers. The repair makes both formatting hosts request the established English-US test input mode. A second diagnostic showed that globally re-forcing and reloading the stock formatting input mode suppresses its native correction candidate on iOS 26.5. The stock formatting host therefore selects English through its `textInputMode` subclass without executing that global reload path. The exact failed bold test, the autocorrection test, and an actual reject-then-formatting sequence all passed before the final matrix. This repair is confined to test hosts and adds no production private API.

After the keyboard matrix, `.neutral-authority-task8-post-keyboard-contract-final.xcresult` passed all 68 selected tests: the 67 controller tests plus the production-authority source contract, with zero failures or skips.

## Focused, unit, and semantic verification

The authority-switch evidence is:

- Task 1 focused baseline: `.neutral-authority-task1-focused-baseline.xcresult` — 107 passed, zero failed/skipped.
- Task 2 RED authority gate: `.neutral-authority-task2-red.xcresult` — all nine new tests failed for the intended old-authority behavior, producing 41 assertion failures before production edits.
- Task 3 controller gate: `.neutral-authority-task3-controller-green-final.xcresult` — 61 passed, zero failed/skipped.
- Task 4 validation/atomicity gate: `.neutral-authority-task4-validation-green.xcresult` — 67 passed, zero failed/skipped.
- Task 5 source contracts: `.neutral-authority-task5-contract-green-final.xcresult` — four passed, zero failed/skipped. The authority and oracle mutation runs are preserved as `.neutral-authority-task5-parser-authority-mutation-red.xcresult` and `.neutral-authority-task5-parser-oracle-mutation-red.xcresult` and failed for their intended source mutations.
- Task 7 focused gate: `.neutral-authority-task7-focused.xcresult` — 122 passed, zero failed/skipped.
- Complete unit target: `.neutral-authority-task7-all-units.xcresult` — 890 passed, two failed, zero skipped, 892 total.
- Scoped unit target excluding exactly the two unrelated failures: `.neutral-authority-task7-all-units-scoped.xcresult` — 890 passed, zero failed/skipped.
- Bounded semantic gate: `.neutral-authority-task7-fast/summary.json` — 250 passed, zero failed/skipped in 16.929 seconds.

The two complete-unit failures are pre-existing and unrelated to navigation authority:

- `IDBlockTextViewTests/testEmptyBlockExposesConfiguredDefaultsToNativeTypingAndInsertion`;
- `IDFloatingCursorContractTests/testStockOracleHostContainsNoPrivateRuntimeKnowledgeOrSyntheticLifecycleCounters`.

Two consecutive `xcodegen generate` runs produced the same project SHA-256, `ec5754815e9184855b27ce84134d104b4a4b0eab3a39a7b1eebccf851caa18b8`, and left the tracked project unchanged.

## Private-surface delta

The production private API delta is zero. Inventories remain exactly:

- 127 minimal production contract members;
- 53 reference-only contract members;
- 25 test-only contract members.

The protected hashes remain, in audit order:

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

No production selector string, runtime lookup, bridge method, private class, private header, or behavior-manifest member was added. The neutral coordinator and its block-local providers remain project-owned boundaries.

## Worktree preservation

The repository began and ended this slice with substantial unrelated tracked and untracked exploration work. Fourteen unrelated tracked paths remain modified, and existing evidence accounts for most of the untracked paths. None was cleaned, reverted, or staged by this slice.

Authority commits contain only the controller, authority tests/contracts, public-arrow test updates, and the isolated test-host keyboard repair. Generated `.xcresult` bundles, semantic output, diagnostic matrices, plans belonging to other slices, Hopper notes, and `SESSION_HANDOFF.md` remain untracked. No staged change or overlapping XCTest process remained at the report checkpoint.

## Stabilization slice and deletion scope

Release now has one implementation and one authority. DEBUG temporarily has two implementations solely to compare the neutral result with the established traversal. The next stabilization slice should add more UIKit-driven sequences without expanding the oracle, then delete the redundant implementation once those sequences remain green.

Deletion scope is deliberately narrow:

- remove `id_establishedNavigationFromPosition:direction:offset:affinity:anchorPositionOffset:finalDocumentAnchor:`;
- remove `id_adjacentClusterOffsetFromOffset:direction:` if it has no non-oracle callers;
- remove `id_compareNeutralNavigationFromPosition:originalDirection:signedOffset:neutralResult:neutralFinalAnchor:affinity:anchorPositionOffset:traversedBlockIdentifiers:stage:`;
- remove navigation-only origin eligibility and traversed-block diagnostics while retaining any origin support still used by other geometry differentials;
- delete parity-only tests `testDebugOracleDestinationMutationRaisesWithoutChangingAuthority`, `testDebugOracleAffinityMutationRaisesWithoutChangingAuthority`, `testDebugOracleAnchorMutationRaisesWithoutChangingAuthority`, the `testNeutralShadow...` navigation family, and source-contract clauses that require the oracle to remain;
- replace the temporary source contract with one that forbids the obsolete traversal in every build configuration.

The following slice must not delete block-local TextKit geometry/navigation providers: they remain the implementation behind neutral snapshots. It also must not conflate oracle deletion with selection presentation, annotations, attachments, TextKit 1 support, or Telegram integration; those remain separate work.
