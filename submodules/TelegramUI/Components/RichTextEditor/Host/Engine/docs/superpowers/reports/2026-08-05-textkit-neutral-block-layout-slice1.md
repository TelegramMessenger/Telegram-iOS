# TextKit-Neutral Block Layout Slice 1 Report

## Outcome

Slice one establishes a project-owned, TextKit-neutral geometry boundary for independent text blocks while preserving the existing UIKit/TextKit 2 implementation as the active authority. The new model, adapter, document coordinator, and DEBUG shadow comparisons cover caret geometry, point hit testing, enclosing line ranges, and one-step visual navigation within a block. No production return value was switched to the neutral path in this slice.

The focused slice gate and bounded semantic gate pass. The complete unit target has two failures that predate and are outside this slice; excluding exactly those two tests produces a clean 849-test regression gate. The failures and their ownership are recorded below rather than hidden or repaired as unrelated work.

## Neutral public surface

`IDBlockLayoutSnapshot.h` is the neutral per-block contract. It imports Foundation and Core Graphics only and exposes project-owned values for:

- UTF-16 positions and ranges with explicit affinity;
- layout constraints, directions, writing direction, and capabilities;
- line identity, caret geometry, point hit testing, line ranges, and visual navigation;
- immutable snapshots and providers keyed by stable block identity.

The contract contains no UIKit, TextKit, Objective-C runtime, selector, or private-framework vocabulary. Its implementation is also isolated from UIKit translation. `IDTextKit2BlockLayoutProvider` is the sole adapter introduced by this slice and owns the conversion between neutral enums/values and TextKit 2 concepts.

## Snapshot generation and staleness

`IDBlockLayout` now maintains separate content-revision and layout-generation counters. Content revision advances with block text/content changes. Layout generation advances whenever the produced geometry can change, including content updates and layout-constraint changes.

Each adapter snapshot captures the block identifier, UTF-16 length, document revision, content revision, layout generation, constraints, used size, and supported capabilities. A snapshot remains valid only while its source block identity, text length, content revision, and layout generation still match. The document coordinator also checks the current document revision before and after a query, retries once when a synchronous revision change is observed, and otherwise returns a typed nonexact/failure result instead of publishing stale geometry.

## TextKit 2 adapter parity

`IDTextKit2BlockLayoutProvider` implements the four slice-one capabilities against the existing independent `IDBlockLayout` TextKit 2 stack:

- caret rectangles preserve local UTF-16 offset, affinity, writing direction, and line identity;
- point hit testing preserves composed-character boundaries and native affinity;
- line-range lookup preserves TextKit's resolved affinity;
- left, right, up, and down movement preserve native visual-navigation results and the vertical anchor offset.

Fixture coverage includes LTR, RTL, mixed BiDi, composed emoji, empty text, independent blocks, ambiguous caret sides, and multi-hop navigation. UIKit/TextKit direction types appear only in this adapter layer.

## Document coordinator and virtualization

`IDDocumentLayoutCoordinator` maps between canonical document offsets and block-local neutral positions through `IDCanonicalTextProjection`. Its source protocol supplies only ordered block identifiers, an optional mounted snapshot, a document-space block origin, and nearest-block lookup for a document point.

Caret rectangles are translated from block-local to document coordinates. Point queries select the nearest available block and translate into its local coordinates. Line ranges are translated back to canonical ranges without including structural separators. Slice-one visual navigation deliberately resolves only movements that remain inside the current block; cross-block movement is reserved for the next slice.

This source protocol is the virtualization seam: unmounted blocks may return no snapshot without forcing the coordinator or neutral model to depend on a view, layout manager, or TextKit class. Missing capability, invalid generation, or stale revision fails closed.

## UIKit shadow integration

`IDRichTextLayoutController` owns a document coordinator built over the same block document and stack canvas. In DEBUG builds it compares established UIKit/TextKit results with neutral results for insertion rectangles, point hit testing, line ranges, and one-step within-block visual navigation.

The established controller remains authoritative and its returned values are unchanged. Shadow comparison is skipped only when the neutral result is explicitly nonexact, navigation crosses a block boundary, or a mounted canvas view has a coordinate transform whose origin differs from the project-owned neutral document origin. Assertion diagnostics include the operation stage, canonical offset, document revision, block identifier, and both established and neutral values. A mutation-style test proves divergent geometry triggers the assertion.

## Focused, unit, and semantic verification

All Simulator XCTest commands were serialized through `Scripts/with-inputdec-simulator-test-lock.sh` with `-parallel-testing-enabled NO`. Verification used iPhone 17 Pro K3, UDID `FA6F7462-AA97-42FE-9E57-8DA0593CE756`, iOS 26.5 build 23F73.

- Baseline: `.neutral-layout-slice1-task1-baseline.xcresult` — 22 passed, zero failed/skipped.
- Final focused slice: `.neutral-layout-slice1-task9-focused-final.xcresult` — 82 passed, zero failed/skipped.
- Ownership repair focus: `.neutral-layout-slice1-task9-inventory-repair-green.xcresult` — 4 passed, zero failed/skipped.
- Complete unit target: `.neutral-layout-slice1-task9-all-units-repair1.xcresult` — 849 passed, 2 failed, zero skipped, 851 total. The failures are `IDBlockTextViewTests/testEmptyBlockExposesConfiguredDefaultsToNativeTypingAndInsertion`, from the pre-existing dirty empty-block trait synchronization work, and `IDFloatingCursorContractTests/testStockOracleHostContainsNoPrivateRuntimeKnowledgeOrSyntheticLifecycleCounters`, from the pre-existing `<objc/message.h>` use in `StockOracleHost/main.m`. Neither file or behavior belongs to this slice.
- Scoped complete unit regression gate excluding exactly those two unrelated tests: `.neutral-layout-slice1-task9-all-units-scoped-green.xcresult` — 849 passed, zero failed/skipped.
- Bounded semantic gate: `.neutral-layout-slice1-task9-fast/summary.json` — 248 passed, zero failed/skipped in 12.236 seconds.

Two consecutive `xcodegen generate` runs produced the identical project hash `ec5754815e9184855b27ce84134d104b4a4b0eab3a39a7b1eebccf851caa18b8`. `git diff --check` passed.

## Private-surface delta

The private API surface delta is zero. The behavior manifests remain exactly:

- 127 minimal production contracts;
- 53 reference-only contracts;
- 25 test-only contracts, comprising 15 diagnostics and ten autoscroll-oracle contracts.

The slice adds project-owned neutral layout types and a public TextKit 2 adapter. It adds no selector strings, raw runtime lookup, private headers, private classes, or new manifest entries.

## Worktree preservation

All unrelated tracked and untracked work present before this slice was preserved. In particular, the existing private-callback, input-trait, IME script/fixture, private UIKit, and Hopper documentation edits were not staged or rewritten. Generated `.xcresult` bundles and semantic output remain untracked evidence and are not part of the commits.

The eight files protected by the baseline hash audit remained byte-identical throughout the slice: both private behavior manifests, `IDPrivateUIKit.h/.m`, `IDPrivateUIKit+RichTextLayout.h/.m`, and `IDPrivateUIKit+TextLayoutCanvas.h/.m`.

## Required next slice

The next slice should implement cross-block horizontal and vertical caret navigation through `IDDocumentLayoutCoordinator`. It should define separator-edge transitions, preserve affinity and vertical anchor state across independent block layouts, handle unavailable/unmounted destination snapshots explicitly, and shadow the results against the current UIKit authority before changing production return values.

This slice does not claim that selection ranges, selection drawing or handles, annotations, attachments, backend switching, TextKit 1 support, or private-API removal are complete.
