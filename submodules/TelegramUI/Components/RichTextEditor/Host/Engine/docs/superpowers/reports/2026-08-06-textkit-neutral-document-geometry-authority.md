# TextKit-Neutral Document Geometry Authority Report

## Outcome

InputDec now has one production authority for document-wide caret, point-hit,
and enclosing-line geometry: `IDDocumentLayoutCoordinator`. The UIKit-facing
`IDRichTextLayoutController` translates validated neutral results into the
objects and sentinel values expected by UIKit, but it no longer calculates
those three geometry families from canvases or TextKit layouts itself.

The completed change is split into these commits:

- `f7b4151` — exact, revision-bound neutral geometry results;
- `bb6c02d` — UIKit characterization and large-selection coverage;
- `1508355` — RED production-authority contracts;
- `ba6c4a5` — production authority switch;
- `421f1f2` — mutation-tested single-authority source contract; and
- `36e4630` — deletion of the duplicate controller implementations.

The design and implementation plan are commits `2acf551` and `3deef9a`.
Every simulator XCTest run used iPhone 17 Pro K3
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`, iOS 26.5 build 23F73, the repository
simulator lock, and `-parallel-testing-enabled NO`.

## Exact neutral result model

The neutral boundary remains Foundation/Core Graphics only. It does not
import UIKit, TextKit, Objective-C runtime, private-framework, class-name, or
selector vocabulary.

`IDDocumentTextPosition` atomically carries block identity, the local
position including affinity, canonical UTF-16 offset, and document revision.
`IDDocumentCaretGeometry` adds a document-coordinate rect, optional stable
line identifier, and an exactness flag. `IDDocumentLineGeometry` adds the
canonical line range, resolved affinity, and exactness flag. All public
coordinator result initializers are private to the implementation, so callers
cannot assemble partially valid result objects.

Coordinator publication is fail-closed and revision-bound. A query retries
the whole transaction once if the document revision changes and returns nil
after a second change. Results are exact only when block identity, canonical
and local offsets, affinity, source capabilities, layout generation, and
document/content revisions agree. Nonfinite origins or rects, out-of-range
positions, structural-separator overflow, missing capabilities, and malformed
or stale snapshots are rejected.

The result-model commit's focused GREEN is included in the later authority
gates. The committed pre-change focused baseline,
`.neutral-geometry-task1-focused-baseline.xcresult`, passed 102/102 with zero
failures/skips.

## UIKit characterization and midpoint authorization

The demo and stock-oracle host exercise the same public interaction sequences
against independent blocks containing LTR, an empty block, RTL, an extended
grapheme cluster, and a trailing block. The large document fixture contains
120 blocks (`block 000` through `block 119`). Characterization locked caret
rectangles, tap-to-position results, enclosing-line ranges and affinities,
structural-newline keyboard movement, Shift-selection endpoints, and complete
select-all ranges across scrolling.

Before changing production authority, the midpoint evidence passed:

| Evidence | Scope | Passed | Failed | Skipped | Test duration |
| --- | --- | ---: | ---: | ---: | ---: |
| `.neutral-geometry-task4-midpoint-core.xcresult` | 98 core units and 3 public geometry tests | 101 | 0 | 0 | 87.1 s |
| `.neutral-geometry-task4-midpoint-touch.xcresult` | selection handles, loupe, edge autoscroll | 3 | 0 | 0 | 44.7 s |
| `.neutral-geometry-task4-midpoint-floating.xcresult` | floating-cursor families | 4 | 0 | 0 | 142.5 s |

This midpoint authorized the authority switch but not deletion. Duplicate
controller paths remained until the same interaction families passed with
neutral geometry in production.

## Production authority switch

The three UIKit-facing callbacks now each make exactly one coordinator query:

- insertion/caret geometry calls
  `caretGeometryForCanonicalOffset:affinity:` and returns its validated
  document rect or `CGRectNull`;
- point hit-testing calls `nearestPositionToDocumentPoint:` and creates one
  untracked rich position only after validating the returned identity,
  canonical offset, local offset, affinity, and revision; and
- enclosing-line lookup calls `lineGeometryForCanonicalOffset:affinity:` and
  creates the UIKit range from the validated canonical range or returns nil.

The controller preserves UIKit's characterized interaction text-container
output for caret queries. Shared validators round-trip results through
`IDCanonicalTextProjection` and reject invalid affinity, stale revision,
nonfinite geometry, out-of-range offsets, structural-separator overflow, and
post-return document mutation. There is no direct-layout fallback or retry in
the controller.

The intentional authority RED,
`.neutral-geometry-task5-authority-red2.xcresult`, failed 4/4 for only the
expected reasons: the production callbacks still owned direct geometry and
the three mutating coordinator doubles disagreed with the temporary DEBUG
oracles. After the switch,
`.neutral-geometry-task6-authority-focused-green.xcresult` passed 5/5 and
`.neutral-geometry-task6-authority-green2.xcresult` passed 96/96, both with
zero skips.

A generic iOS Simulator Release build succeeded after the switch. Inspection
of the Release objects found no DEBUG helper symbols.

## Deleted direct implementations

After post-switch interaction authorization, commit `36e4630` removed 322
lines of duplicate support from the controller and parity-only tests. The
deleted production/debug implementation family included:

- `id_establishedInsertionRectForPosition:`;
- `id_establishedNearestPositionAtPoint:`;
- `id_establishedTextRangeForLineEnclosingPosition:`;
- `IDRichMountedCanvasMatchesNeutralOrigin`;
- `IDRichShouldCompareEstablishedGeometry` and rect-comparison support; and
- controller tests whose sole purpose was comparing those duplicate paths.

Provider parity, malformed/stale-result, mutation, race, authority,
selection, and interaction tests remain. A second generic Simulator Release
build succeeded after deletion, and the removed DEBUG symbols were absent.

## Single-authority contract and mutation proof

`IDNeutralGeometryAuthorityViolations` is a pure source contract over the
isolated callback family. For caret, point, and line callbacks it requires
exactly one production and total coordinator query, the family validator,
one terminal return, and no direct layout primitive, conversion, mounted
canvas lookup, established helper, comparison gate, or retry/fallback path.
It also rejects the obsolete oracle names globally.

The contract itself is mutation-tested. Synthetic sources containing an
obsolete helper, an alternate return, or a retry fallback are rejected;
`.neutral-geometry-task8-audit-mutations-green.xcresult` passed 3/3. Against
the then-current real source,
`.neutral-geometry-task8-single-authority-red.xcresult` failed 1/1 solely on
the retained DEBUG oracle paths. After deletion,
`.neutral-geometry-task8-focused-green.xcresult` passed 113/113 with zero
failures/skips. The post-keyboard rerun,
`.neutral-geometry-task10-post-keyboard-focused.xcresult`, passed 90/90.

## Caret, hit-test, line, selection, loupe, and floating-cursor evidence

The first post-switch stabilization passed before duplicate deletion:

| Evidence | Scope | Passed | Failed | Skipped | Test duration |
| --- | --- | ---: | ---: | ---: | ---: |
| `.neutral-geometry-task7-public-green.xcresult` | public geometry/navigation | 7 | 0 | 0 | 162.6 s |
| `.neutral-geometry-task7-touch-green.xcresult` | native selection/loupe/autoscroll | 3 | 0 | 0 | 44.5 s |
| `.neutral-geometry-task7-floating-green.xcresult` | floating cursor | 4 | 0 | 0 | 142.7 s |
| `.neutral-geometry-task7-post-ui-units.xcresult` | post-interaction race/bounded-source units | 89 | 0 | 0 | 2.6 s |

After deletion, `.neutral-geometry-task9-public-consumers.xcresult` passed
12/12 in 288.3 test seconds with zero failures/skips. It covers stock/custom
caret and tap sequences, line-boundary Shift selection, structural-newline
arrow movement, the large select-all scroll case, native endpoint handles,
loupe tracking, trailing-handle autoscroll, floating-cursor normal release,
logical-anchor selection extension, independent-block crossing, and mixed
BiDi reversal.

## Large-selection and virtualization-seam evidence

`Cmd+A` is document state, not a request to materialize geometry for every
selected character. The 120-block UI fixture preserves the complete canonical
selection while scrolling. A bounded test snapshot source separately proves
that select-all does not request unavailable geometry, and coordinator tests
prove exact cross-block queries can use non-view snapshot providers.

This is deliberately not a claim that the standalone demo currently
virtualizes its production stack. `IDBlockStackCanvasView` still mounts the
standalone editor's all-block stack. The bounded source is a test seam that
locks the contract needed by a future virtualized Telegram host: canonical
selection may span the whole document while geometry is requested only for
the positions needed by the active interaction.

## Unit, semantic, Release, and keyboard verification

The complete unit-target attempt reached a simulator pasteboard deadlock in
`IDPrivateUIKitTests/testRuntimeGeometryAndCommandABIsMatchControllerContracts`:
the sampled main thread was blocked in `_UIConcretePasteboard string` on a
pasteboard semaphore. The wedged run was interrupted. The exact unchanged
method then passed in isolation in 0.016 seconds at
`.neutral-geometry-task9-pasteboard-isolation.xcresult`, establishing a
transient simulator-service condition rather than a geometry failure.

The plan's fixed scoped gate was then used without adding any exclusion.
`.neutral-geometry-task9-all-units-scoped.xcresult` passed 891/891 in 17.925
test seconds with zero runtime skips. Its eight predeclared exclusions are
the documented empty-block defaults, stock-host source-boundary, native
spelling-pixel, and regular-iPad aggregate-layout harness conditions; none is
owned by this geometry slice.

The bounded semantic gate at
`.neutral-geometry-task9-fast/summary.json` passed 257/257 with zero
failures/skips in 13.576 seconds, below its 30-second budget.

The real-system-keyboard certification at
`.neutral-geometry-task10-keyboard-sentinels/summary.json` passed 24/24 with
zero failures/skips in 762 wall-clock seconds on iOS 26.5 build 23F73:
20 English autocorrection, inline prediction, floating-cursor, and rich-text
formatting cases; two Japanese return/commit/undo cases; and two Simplified
Chinese candidate-commit cases. Each family includes the full editor and the
minimal host. There are 24 unique one-test child summaries plus provisioning,
learning-reset, and aggregate summaries (27 total).

Two first attempts—English `inline-accept-minimal` and
`inline-dismiss-before-boundary`—were retained under `readiness-attempts/`.
Both were bounded keyboard-readiness retries; their second attempts passed.
No semantic result was retried.

## Private-surface and deterministic-generation delta

No private bridge or behavior-manifest file changed in this slice relative
to design commit `2acf551`. Final inventories remain exactly:

- production capability members: 127;
- production reference-only members: 53; and
- test-only capability members: 25.

The protected hashes remain, in command order:

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

Two consecutive `xcodegen generate` runs produced
`ec5754815e9184855b27ce84134d104b4a4b0eab3a39a7b1eebccf851caa18b8`
for `InputDec.xcodeproj/project.pbxproj`, and the generated project retained
no diff.

## Worktree preservation

The repository entered this slice with unrelated tracked edits in private
UIKit support, the block editor, IME scripts and fixture, tests, and the
Hopper notebook, plus extensive untracked research artifacts. The six code
and test commits staged only slice-owned files or hunks. XcodeGen did not
modify the project file, and no unrelated tracked or untracked work was
removed, staged, or committed.

## Next selection-presentation slice

The next pass should make document selection presentation consume the same
neutral layout authority. Keep one canonical selection range independent of
materialization, request geometry only for visible or interaction-relevant
segments, and let a Telegram host supply bounded block snapshots. Start with
selection-rectangle aggregation and endpoint roles, then move selection
drawing/handles behind a project-owned presentation boundary while retaining
UIKit's interaction lifecycle until parity is locked.

That work must not reintroduce a second document-geometry implementation.
The coordinator remains the single authority for caret, point, line, and
cross-block navigation; selection presentation composes those neutral facts
rather than querying canvases directly.
