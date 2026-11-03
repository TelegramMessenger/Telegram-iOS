# TextKit-Neutral Selection Geometry Authority Report

## Outcome

InputDec now has one production authority for non-collapsed selection geometry:
`IDDocumentLayoutCoordinator`. Block layout providers produce UIKit-free local
segments, the coordinator validates and aggregates those segments in document
coordinates, and `IDRichTextLayoutController` performs the sole UIKit adapter
step. The previous controller-owned block walk and DEBUG duplicate oracle were
deleted.

The completed slice is represented by commits `6f1577c` through `e3a9c32`:

- `6f1577c` characterized neutral selection geometry;
- `d46db19` introduced neutral block selection segments;
- `764e86e` introduced eligibility generations;
- `eb983d8` aggregated document selection geometry;
- `908d46b` matched UIKit's upstream separator ownership;
- `8ed47e3` added authority contracts and shadow comparison;
- `7a0380e` restored an independent comparison oracle;
- `81abb5b` switched production to the neutral authority;
- `ac87a97` stabilized bounded/offscreen authority behavior;
- `2594e1e` added mutation-tested single-authority audits; and
- `e3a9c32` deleted the duplicate implementation paths.

All final selection-specific, semantic, public interaction, Release, and
real-keyboard gates passed on the iOS 26.5 simulator. No private bridge or
private behavior manifest was changed by this slice.

## Neutral block and document result models

`IDBlockSelectionSegment` is the block-level result. It contains a local UTF-16
range, an unclipped local rectangle, a boundary role, local endpoint ownership,
neutral writing direction, vertical-layout state, and layout generation. The
type lives in the neutral block snapshot layer and contains no UIKit or private
UIKit vocabulary.

`IDDocumentSelectionSegment` is the projected document-level result. It carries
the block identifier, canonical range, boundary role, unclipped document
rectangle, direction, vertical state, and exact logical-start/logical-end
ownership. `IDDocumentSelectionGeometry` binds the ordered segments to the
canonical selection, document revision, and captured source geometry generation.

The block provider owns glyph/layout interpretation. The coordinator owns
canonical projection, ordering, separator composition, eligibility validation,
and transaction consistency. UIKit conversion is deliberately outside both
neutral models.

## Eligibility generation and virtualization boundary

`IDDocumentGeometryEligibilitySnapshot` atomically captures a nonzero geometry
generation and ordered eligible block identifiers. A selection query asks only
for the identifiers declared in that snapshot. It does not infer eligibility by
walking the entire document or by probing arbitrary blocks.

The standalone `IDBlockStackCanvasView` is an all-block mounted stack, so its
source-declared eligibility is currently every ordered block layout. The bounded
test sources are different by design: they explicitly declare only a subset of
document blocks and prove that the coordinator requests only that subset. This
is the contract a virtualized Telegram source should implement; the test subset
is not evidence that the standalone stack itself virtualizes blocks.

Geometry generation advances when origins, content revisions, layout
generations, or document content size change. The coordinator captures the
eligibility snapshot, block origins, and block snapshots as one logical
transaction. A revision, origin, or eligibility-generation race rejects the
attempt. The coordinator retries that whole transaction once and returns `nil`
after a second race. A valid selection with no eligible visible segments returns
an exact geometry object containing an empty segment array, not a failure.

## UIKit characterization and midpoint authorization

Stock `UITextView` characterization covered wrapped LTR, RTL and mixed BiDi,
composed emoji clusters, empty blocks, reversed endpoint roles, structural
separator-only selections, and large selections whose visible geometry changes
while the canonical range remains fixed.

Before the authority switch, the neutral result ran in shadow against an
independent copy of the established algorithm. The final independent shadow
gate passed 122/122 in
`.neutral-selection-geometry-task7-independent-oracle-shadow-full1.xcresult`.
The midpoint core gate passed 142/142 in
`.neutral-selection-geometry-task7-midpoint-core-adjusted.xcresult`; touch and
floating midpoint gates each passed 6/6 in
`.neutral-selection-geometry-task7-midpoint-touch.xcresult` and
`.neutral-selection-geometry-task7-midpoint-floating.xcresult`.

An earlier mixed-BiDi Shift+Arrow failure was reproduced at the exact pre-slice
baseline and treated as environmental rather than hidden. The final combined
post-deletion public run subsequently passed that case and all 14 companion
cases.

## Production authority switch

For a non-collapsed `UITextRange`, `IDRichTextLayoutController` projects the
canonical range once and calls
`selectionGeometryForCanonicalRange:` exactly once. It verifies document
revision and exact result identity, then converts each document rectangle from
the block stack into the requested view. Invalid or raced results return `nil`;
there is no controller retry or alternate geometry calculation.

The presentation path distinguishes failure from exact emptiness. `nil` keeps
the prior selection snapshot pending and requests another layout pass. A
nonnull geometry result with zero rectangles publishes exact empty visible
geometry. Collapsed selections remain on the existing caret authority and were
not folded into the selection transaction.

The final authority suite passed 266/266 in
`.neutral-selection-geometry-task8-authority-green2.xcresult`. Both the initial
switch and the later deletion state built successfully in Release under
`.neutral-selection-geometry-task8-release-derived` and
`.neutral-selection-geometry-task10-release-derived`.

## Deleted direct implementation

The controller no longer owns a second non-collapsed selection implementation.
The retired code included direct block iteration, per-block `IDBlockLayout`
lookup, local range calculation, canvas-to-view conversion, endpoint fallback,
shared-direction bookkeeping, the DEBUG established-result helper, and shadow
serialization/comparison.

`IDNeutralSelectionGeometryAuthorityViolations` audits the real source and
mutation fixtures. It rejects an obsolete helper, an alternate return path, a
controller retry/fallback, and direct controller block/canvas geometry. The
five final audit tests passed, and the broader post-deletion focused gate passed
156/156 in `.neutral-selection-geometry-task10-focused-green2.xcresult`.
Release-symbol inspection found no legacy helper symbol.

## Exact endpoint, BiDi, separator, and empty-block semantics

Logical endpoint ownership is assigned from canonical coverage, never from the
first or last visible rectangle. If a logical endpoint is offscreen, no visible
substitute receives its flag. Reversed selections therefore preserve logical
roles independently of visual rectangle order.

Block segments preserve their own neutral writing direction and vertical state.
The UIKit adapter applies the public `UITextSelectionRect` direction convention
observed in the stock differential while retaining the exact per-segment data in
the neutral result. Mixed-BiDi endpoint roles and reversal passed both unit and
public stock comparisons.

A selected structural newline is represented once. UIKit characterization
showed that separator tail geometry belongs to the upstream block; the neutral
composition mirrors that ownership. Empty middle blocks, separator-only LTR and
RTL selections, and upstream tail extension all have explicit passing tests.
Composed-character ranges remain UTF-16/canonical-range correct.

## Large selection and offscreen endpoint evidence

Select All continues to operate on the complete canonical range even when the
geometry source declares only a bounded subset. Formatting, undo, text lookup,
and deletion use the canonical selection, not the visible rectangles.

The bounded-source unit tests prove all of the following:

- only source-declared eligible identifiers are queried;
- eligibility does not expand merely because the canonical selection is large;
- offscreen logical endpoints remain unclaimed by visible segments;
- wholly offscreen valid selections publish exact empty geometry; and
- a missing, wrong-generation, or raced participating snapshot invalidates the
  whole result.

The public large-document test selected the complete stock and custom documents,
scrolled both, and verified that canonical selection stayed fixed while visible
geometry changed. It passed as part of the final 15/15 combined interaction run.

## Touch, loupe, autoscroll, and floating-cursor evidence

The final serial public-consumer artifact is
`.neutral-selection-geometry-task11-public-consumers.xcresult`: 15 passed, zero
failed/skipped, 423.683 seconds of test time. It covers public selection
rectangles, mixed-BiDi endpoint roles, large Select All, both native handles,
cross-boundary and BiDi handle drags, top/bottom selection autoscroll, the native
loupe, floating selection anchor retention and reversal, structural-newline
counting, and mixed-BiDi floating behavior.

UIKit continues to own the transient interaction pipeline. The neutral geometry
authority supplies exact geometry to that pipeline; this slice does not yet
replace selection highlight or handle presentation.

## Unit, semantic, Release, and keyboard verification

All simulator commands used `-parallel-testing-enabled NO` and the repository's
single-simulator lock. Runtime was iOS 26.5 build 23F73 on iPhone 17 Pro K3,
UDID `FA6F7462-AA97-42FE-9E57-8DA0593CE756`.

- Baseline focused gate: 123/123 in
  `.neutral-selection-geometry-task1-focused-baseline.xcresult`.
- Neutral provider gate: 22/22 in
  `.neutral-selection-geometry-task3-provider-green6.xcresult`.
- Eligibility gate: 90/90 in
  `.neutral-selection-geometry-task4-eligibility-green2.xcresult`.
- Coordinator gate: 57/57 in
  `.neutral-selection-geometry-task5-coordinator-green3.xcresult`.
- Final independent shadow gate: 122/122 in
  `.neutral-selection-geometry-task6-shadow-green4.xcresult`.
- Post-switch unit repair gate: 61/61 in
  `.neutral-selection-geometry-task9-post-ui-units.xcresult`.
- Post-deletion focused gate: 156/156 in
  `.neutral-selection-geometry-task10-focused-green2.xcresult`.
- Fast semantic gate: 264/264, zero skipped, 17.086 seconds in
  `.neutral-selection-geometry-task11-fast`.
- Final public/touch/floating gate: 15/15 in
  `.neutral-selection-geometry-task11-public-consumers.xcresult`.
- Post-keyboard authority gate: 110/110 in
  `.neutral-selection-geometry-task12-post-keyboard-focused.xcresult`.

The unscoped unit target reported 931 passed and two unrelated failures in
`.neutral-selection-geometry-task11-all-units.xcresult`. Both were predeclared
by the plan and diagnosed before exclusion:

- `testEmptyBlockExposesConfiguredDefaultsToNativeTypingAndInsertion` belongs
  to the separate in-progress input-traits/default-typing work; and
- `testStockOracleHostContainsNoPrivateRuntimeKnowledgeOrSyntheticLifecycleCounters`
  rejects the pre-existing English-US keyboard forcing code in
  `StockOracleHost/main.m`.

With only those exact methods excluded, the complete unit target passed
931/931, zero skipped, in
`.neutral-selection-geometry-task11-all-units-scoped.xcresult`. No geometry,
spelling-pixel, pasteboard, or layout test was excluded.

The real-system-keyboard certification passed 24/24, zero failed/skipped, with
749 seconds wall time in
`.neutral-selection-geometry-task12-keyboard-sentinels`. Its aggregate is 20
English, two Japanese, and two Simplified Chinese cases. It covers stock/custom
normal and minimal paths for autocorrection accept/reject, inline prediction
accept/dismiss, floating cursor and selection extension, bold formatting across
autocorrection/prediction/marked text, Japanese return commit plus undo, and
Chinese candidate commit. Two readiness-only first attempts were retained:
`inline-accept-minimal` and `inline-dismiss-before-boundary`; both passed on
attempt 2. No semantic outcome was retried. The artifact contains 24 unique
one-test summaries plus provisioning, learning-reset, and aggregate summaries.

## Private-surface and deterministic-generation delta

The protected private inventories remain exactly `127` capability members, `53`
reference-only members, and `25` test-only capability members. Protected hashes
remain, in the recorded order:

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

The committed diff from `c7ee427` through `HEAD` is empty for `PrivateUIKit`
and `Tests/Fixtures/UIKitBehaviorTestOnlyContracts-iOS26.5.json`. XcodeGen
produced SHA-256
`ec5754815e9184855b27ce84134d104b4a4b0eab3a39a7b1eebccf851caa18b8`
twice and left `InputDec.xcodeproj/project.pbxproj` unchanged. The complete
`git diff --check` is clean.

## Worktree preservation

The exploration repository already contained unrelated tracked edits and many
untracked result artifacts. They were not reset or cleaned. Remaining tracked
work includes private callback/input-traits work, keyboard scripts and fixtures,
tests, and Hopper notes. The report and selection-geometry commits do not claim
those remaining worktree changes.

One overlapping pre-existing input-traits synchronization hunk in
`IDBlockTextView.m` was present when the production authority switch was staged
and is included in `81abb5b`; related private/test edits remain in the worktree.
This is recorded explicitly so a later traits pass can reconcile that history
without mistaking it for selection geometry.

## Next custom-highlight presentation slice

The next slice should retain `IDDocumentLayoutCoordinator` as the only geometry
authority and replace only presentation. A project-owned selection overlay can
consume exact document segments, clip/draw highlights against independently
mounted or table-hosted blocks, and defer or selectively replace handles while
UIKit continues to drive gestures, loupe, keyboard selection, autocorrection,
and floating-cursor lifecycle.

That work should begin with a presentation protocol whose inputs are the
committed neutral document result plus viewport/host transforms. It must not
reintroduce canonical projection, block iteration, endpoint reassignment, or a
second layout calculation in the overlay. Large selections should stay
canonical and cheap: only source-declared eligible segments are materialized,
while selection editing continues to address the full document range.
