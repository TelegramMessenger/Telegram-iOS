# TextKit-Neutral Cross-Block Caret Navigation Report

## Outcome

This slice completes exact one-step horizontal and vertical caret navigation across independent blocks in `IDDocumentLayoutCoordinator`. It also compares complete signed and multi-step UIKit callbacks against that neutral path in DEBUG builds. `IDRichTextLayoutController` remains the production authority: no production return value was redirected, and no established TextKit navigation code was deleted.

The neutral path now covers LTR, RTL, mixed BiDi, composed emoji, short and empty blocks, consecutive empty blocks, positive and negative offsets, multi-step callbacks, fixed vertical anchors, separator crossings, unmounted destinations, and revision changes. Exact results fail closed when required geometry or capabilities are missing or malformed.

## Neutral interface delta

`IDBlockLayoutSnapshot.h` gained one project-owned capability and query:

- `IDBlockLayoutCapabilityBaseWritingDirection`
- `-baseWritingDirectionAtPosition:` returning `IDBlockWritingDirection`

The neutral header still imports only Foundation and Core Graphics. It contains no UIKit, TextKit, private selector, or Objective-C runtime vocabulary. `IDTextKit2BlockLayoutProvider` remains the only translation layer for `NSWritingDirection`, `UITextStorageDirection`, and `UITextLayoutDirection`; raw runtime access is forbidden there as well.

The provider remains block-local. It does not inspect neighboring blocks, document separators, mounted-view state, or the coordinator.

## Horizontal separator behavior

The coordinator first asks the source snapshot for one local visual-navigation step. When local TextKit cannot produce a destination, the coordinator asks that snapshot for the base writing direction at the current position and maps visual left/right to logical backward/forward movement.

The fallback moves by exactly one composed-character sequence in the canonical projected string. A structural newline therefore behaves as a real separator stop: one callback crosses one separator boundary, including around RTL and empty blocks. It never scans past an adjacent short, empty, unavailable, or unsupported block. The destination block must have a current, valid snapshot even though no mounted canvas is required.

Horizontal anchors are converted from document X to source-local X before the snapshot query. A successful local result is converted back to document X. Separator fallback preserves the incoming document anchor and affinity.

## Vertical adjacent-block behavior

The coordinator accepts a same-block vertical result only when finite source and destination carets prove at least `0.5` points of progress in the requested direction. A same-line or non-progressing local result is treated as a block exit.

On exit, exactly the immediately adjacent block is selected from the source's ordered identifiers. Moving down probes its downstream start edge; moving up probes its upstream end edge. The edge caret supplies the target Y, while the caller's document-space X is converted through the destination block origin and resolved with that block's point hit-testing snapshot.

This makes long-short-long and empty-block navigation deterministic without creating a joined-document TextKit layout. The implementation does not skip an adjacent block when its geometry is unavailable.

## Anchor and revision transaction

Coordinator anchors are always document-space X values; snapshot anchors are block-local X values. Horizontal local navigation may update and return its document anchor. Vertical navigation preserves the caller's original document X across every one-step transition.

Each attempt captures one document revision and validates source identity, revision, validity, capabilities, and requested bounds before and after provider callbacks. The same checks cover base direction, caret geometry, local navigation, destination caret geometry, origin lookup, and destination point hit testing. Invalid enum values, nonfinite origins/rectangles/anchors, wrong identities, missing capabilities, and out-of-bounds offsets fail closed.

A synchronous revision change restarts the whole source/destination transaction once. A second revision change returns a nonexact result at the conservative current source position, with the current revision, requested affinity, and input document anchor. No intermediate stale destination is published.

## Virtualization and failure behavior

Cross-block navigation consumes immutable snapshots and project-owned document origins. It never mounts a view or reaches into a neighboring TextKit graph. Tests prove that a real TextKit destination can remain unmounted while horizontal and vertical crossing still return exact results.

Unavailable or malformed source/destination snapshots return `nil`; a repeated revision race returns a typed nonexact result. The coordinator never throws for missing snapshot data, skips over a failed block, or accepts stale geometry. This preserves the virtualization seam needed by a table- or list-backed rich editor.

## UIKit shadow differential

In DEBUG builds, `IDRichTextLayoutController` repeats the neutral one-step primitive for the absolute value of the UIKit callback offset, reverses direction for negative offsets, carries affinity on every step, carries horizontal anchors, and retains one fixed vertical document X. It compares complete-result presence, canonical offset, affinity, revision, and final anchor within `0.001`.

The shadow skips only nonexact neutral output or a traversed mounted canvas whose actual stack origin disagrees with the project-owned origin. Mutation tests independently alter destination, affinity, and anchor and prove each mismatch raises `NSInternalInconsistencyException`.

The source contract `testNeutralCrossBlockNavigationRemainsDebugShadowOnly` proves every coordinator navigation call in the controller remains inside a DEBUG preprocessor branch. It also requires the established production method to retain `caretStopFromLocalOffset:`, `baseWritingDirectionAtLocalOffset:`, and `id_adjacentClusterOffsetFromOffset:`. A mutation check placed a coordinator call outside DEBUG and demonstrated that the contract fails.

## Focused, unit, and semantic verification

All Simulator XCTest commands were serialized through `Scripts/with-inputdec-simulator-test-lock.sh` with `-parallel-testing-enabled NO`. Verification used iPhone 17 Pro K3, UDID `FA6F7462-AA97-42FE-9E57-8DA0593CE756`, iOS 26.5 build 23F73.

- Baseline: `.neutral-cross-block-task1-baseline.xcresult` — 66 passed, zero failed/skipped.
- Final focused gate: `.neutral-cross-block-task9-focused-final.xcresult` — 107 passed, zero failed/skipped.
- Complete unit target: `.neutral-cross-block-task9-all-units.xcresult` — 874 passed, two tests failed, zero skipped, 876 total. The failures are the pre-existing `IDBlockTextViewTests/testEmptyBlockExposesConfiguredDefaultsToNativeTypingAndInsertion` font-default mismatch and `IDFloatingCursorContractTests/testStockOracleHostContainsNoPrivateRuntimeKnowledgeOrSyntheticLifecycleCounters` detection of the pre-existing `<objc/message.h>` token. Neither belongs to this slice.
- Scoped unit gate excluding exactly those two tests: `.neutral-cross-block-task9-all-units-scoped-green.xcresult` — 874 passed, zero failed/skipped.
- Bounded semantic gate: `.neutral-cross-block-task9-fast/summary.json` — 249 passed, zero failed/skipped in 11.155 seconds.
- Task 8 final contracts: `.neutral-cross-block-task8-contract-green1.xcresult` — three passed, zero failed/skipped.

The two Task 8 mutation runs failed for the intended reasons: the neutral-boundary mutation named `IDDocumentLayoutCoordinator.m` and `NSSelectorFromString`; the authority mutation reported one coordinator navigation call outside DEBUG. Both temporary mutations were restored before final verification.

Two consecutive `xcodegen generate` runs produced the identical project SHA-256 `ec5754815e9184855b27ce84134d104b4a4b0eab3a39a7b1eebccf851caa18b8`. Generation left the tracked project unchanged, and `git diff --check` passed.

## Private-surface delta

The private API surface delta is zero. Inventories remain exactly 127 minimal production contracts, 53 reference-only contracts, and 25 test-only contracts. No private selector, bridge method, runtime lookup, private class, private header, or manifest member was added.

The baseline and final hashes match for both behavior manifests and for `IDPrivateUIKit.h/.m`, `IDPrivateUIKit+RichTextLayout.h/.m`, and `IDPrivateUIKit+TextLayoutCanvas.h/.m`.

## Worktree preservation

Unrelated tracked edits in the private-callback/private-UIKit layer, block text view and tests, IME scripts and fixtures, and Hopper notes were preserved and were never staged by this slice. Existing untracked reports, plans, result bundles, partial runs, and semantic evidence were not cleaned or committed.

The implementation commits contain only their task-owned source/tests. The generated `.xcresult` bundles and `.neutral-cross-block-task9-fast` directory remain untracked evidence.

## Required authority-switch slice

The next slice should switch production navigation in `-[IDRichTextLayoutController id_positionFromPosition:inDirection:offset:affinity:anchorPositionOffset:]` to the coordinator's repeated one-step results. At that point the current established TextKit/block-layout loop must move behind DEBUG and become the differential oracle; it should not be deleted immediately.

That authority switch requires the complete focused/unit gates plus real-system-keyboard and floating-cursor certification, because UIKit's input controller, selection interaction, and repeated movement callbacks will then consume neutral results end to end. Coverage must include hardware-key commands, loupe/drag movement, selection extension, BiDi, emoji, structural separators, empty blocks, virtualization, and revision races.

Only after those gates pass should the obsolete established navigation loop be deleted. The deletion scope is the old horizontal/vertical body in that controller method and `id_adjacentClusterOffsetFromOffset:direction:` if it has no remaining callers. Block-local TextKit geometry APIs and the adapter stay: they remain the implementation behind neutral snapshots. This report does not claim that selection drawing/handles, annotations, attachments, TextKit 1 support, or the Telegram port are complete.
