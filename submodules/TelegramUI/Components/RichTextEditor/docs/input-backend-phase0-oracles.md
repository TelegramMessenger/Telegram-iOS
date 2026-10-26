# Phase 0 oracle registry — RichText input backend seam

Every Phase-4 routing task cites the gate for its category from this table instead of
re-deriving one. A test in `T/Characterization/OracleRegistryTests.swift` fails if a
named class disappears, so a rename cannot silently drop a gate.

Every count below is a mechanical `grep -c 'func test' <file>` on the file as it stands on
`richtext/input-backend-seam` at the time this manifest was written (Task 8). Where a file
covers more than one category, it is listed (and counted) under each — that is intentional
double-filing, not double-counting toward any one category's total.

| Category | Gate classes | Measured test count |
| --- | --- | --- |
| a. text/range primitives | `CanvasTextInputTests` (5), `TextPositionTests` (2), `CanvasTokenizerTests` (8), `CaretRenderableTests` (7), `TextInputWitnessMatrixTests` (53, Task 4) | 75 |
| b. directional selection | `BaseDirectionTests` (4), `RTLCaretTrackingTests` (4), `DirectionalSelectionCharacterizationTests` (3, Task 4) | 11 |
| c. delegate/facade order | `EditingInputDelegateBracketTests` (4), `SelectionDragCoalescingTests` (3), `DelegateTraceCharacterizationTests` (23, Task 3) + `FacadeCallbackTraceCharacterizationTests` (4, Task 3) | 34 |
| d. undo coalescing | `UndoCoalescingTests` (14), `UndoBufferIsolationTests` (7) | 21 |
| e. Return/Backspace boundaries | `DoubleReturnExitTests` (34), `BlockQuoteEditTests` (52), `CanvasPullQuoteEditTests` (34), `CodeBlockEditingTests` (14), `DetailsBoxReturnTests` (2), `CanvasTableCellBackspaceTests` (1), `CanvasTableBackspaceDeleteTests` (7), `CanvasTableBackspaceSelectTests` (7), `CanvasStructuralTests` (13) | 164 |
| f. marked text | `MarkedTextTests` (27), `MarkedTextTraceCharacterizationTests` (10, Task 7) | 37 |
| g. autocorrect/prediction | `AutocorrectUnderlineTests` (10), `NativeTextCheckingClientTests` (10), `AutocorrectOriginCharacterizationTests` (3, Task 7) | 23 |
| h. geometry | `ComposerSelectionGeometryTests` (11), `SelectionHighlightTests` (10), `CanvasHitTestTests` (2), `CanvasEditMenuPositionTests` (4), `GeometryWitnessMatrixTests` (23, Task 5) + `TableScrollGeometryCharacterizationTests` (5, Task 5) | 55 |
| i. touch/loupe/handles/menu | `SelectionInteractionTests` (26), `TableControlsTests` (57), `CanvasSelectionMenuTests` (32), `CanvasHitTestTests` (2, shared with h), `EditMenuAutoDismissTests` (8), `CanvasEditMenuPositionTests` (4, shared with h) | 129 |
| j. floating cursor/autoscroll | `FloatingCursorTests` (17), `TransientCaretViewTests` (3), `ScrollCaretOnEditTests` (7) | 27 |
| k. clipboard/structural | `CanvasClipboardTests` (24), `RTFConversionTests` (24), `CanvasCellStructuralTests` (4), `CanvasSelectAllTableDeleteTests` (6), `CanvasReplaceRangeTests` (6) | 64 |
| l. responder/window detach | `ResponderLifecycleCharacterizationTests` (15, Task 6) + `WindowDetachCharacterizationTests` (5, Task 6), `RichTextEditorViewTests` (27) | 47 |
| m. spelling annotations | `SpellCheckTapTests` (15), `SelectionDrivenSpellCheckTests` (9), `NativeTextCheckingClientTests` (10, shared with g), `NativeTextCheckingResolverTests` (2), `NativeTextCheckingLiveTests` (1), `AutocorrectUnderlineTests` (10, shared with g) | 47 |

## Discrepancies found against the brief's hypothesis (Task 8)

The brief's file lists for categories *d, e, i, j, k, m* were re-derived against what is
actually on disk. Every file in every one of those six rows was opened and read in full
(not just its function names). Two corrections came out of that:

- **Category e (Return/Backspace boundaries): `DetailsBodyEditTests` does NOT belong here
  and has been dropped from the gate-class list.** Reading the file
  (`T/DetailsBodyEditTests.swift`, 8 tests) shows every test exercises a *format/insert
  command* (`setParagraphStyle`, `setList`, `insertTable`, `insertDetailsBlock`,
  `insertMedia`, `makeCodeBlock`, `makePullQuote`, `wrapInBlockQuote`) landing inside a
  details body rather than at the top level — i.e. it is a container-routing regression
  suite, not a Return/Backspace boundary suite. It asserts nothing about Enter or
  Backspace. The genuine Return-boundary gate for details is `DetailsBoxReturnTests`
  alone (2 tests: single- vs. double-Return escaping the details body), which remains in
  the list.

- **Category e (Return/Backspace boundaries): `CanvasReplaceRangeTests` (6 tests) does NOT
  belong here either — it has been re-homed to category k (clipboard/structural).** The
  original filing was justified as "the cross-block range-replace engine Backspace/paste
  ultimately route through," which is checkable and false. Tracing the call graph
  (`grep -n` over `Sources/RichTextEditorUIKit/Canvas/`):
  - `deleteBackward()` calls `applyReplaceOutcome(globalFrom:globalTo:text:)`
    (`DocumentCanvasView+UITextInput.swift:686,883,904`) — a **different** function,
    defined at `DocumentCanvasView+Editing.swift:93`. Backspace never reaches
    `replaceRange`.
  - Ordinary paste (fragment/RTF/plain) calls `applySelectionReplaceOutcome`
    (`DocumentCanvasView+Clipboard.swift:122,150`) — also not `replaceRange`.
  - `replaceRange(globalFrom:globalTo:with:)` (`DocumentCanvasView+Editing.swift:841`) is
    called from exactly two places: the public façade `RichTextEditorView.replaceRange`
    (`RichTextEditorView.swift:509-510`), and `pasteMarkdownTwoStep`'s step 2
    (`DocumentCanvasView+Clipboard.swift:178`) — the host-injected markdown-on-paste hook,
    a narrow special case, not paste generally.

  So `CanvasReplaceRangeTests` genuinely tests the façade-level / markdown-paste-injected
  `replaceRange` API, not a Return/Backspace boundary. Its actual content — replacing an
  arbitrary global range with a `Document` fragment, including the whole-table-drop
  behavior on both orientations of a mixed range and the one-undo-step guarantee — is
  cross-block **structural replacement**, which is what category k's "clipboard/structural"
  name covers (the API is also literally reached from the clipboard/paste path above), so
  it was re-homed there rather than dropped outright.

Both corrections drop category e's total from the brief's implied 178 down to the verified
**164** (removing `DetailsBodyEditTests`'s 8 and `CanvasReplaceRangeTests`'s 6), and raise
category k's total from the brief's implied 58 up to **64** (adding `CanvasReplaceRangeTests`
back in under its correct category).

Every other file named in the brief for categories *d, e, i, j, k, m* was opened and
confirmed to assert what its category claims; every measured count above matches the
brief's prediction exactly except the two rows corrected above:
`UndoCoalescingTests` 14, `UndoBufferIsolationTests` 7, `DoubleReturnExitTests` 34,
`BlockQuoteEditTests` 52, `CanvasPullQuoteEditTests` 34, `CodeBlockEditingTests` 14,
`DetailsBoxReturnTests` 2, `CanvasTableCellBackspaceTests` 1,
`CanvasTableBackspaceDeleteTests` 7, `CanvasTableBackspaceSelectTests` 7,
`CanvasStructuralTests` 13, `SelectionInteractionTests` 26, `TableControlsTests` 57,
`CanvasSelectionMenuTests` 32, `CanvasHitTestTests` 2, `EditMenuAutoDismissTests` 8,
`CanvasEditMenuPositionTests` 4, `FloatingCursorTests` 17, `TransientCaretViewTests` 3,
`ScrollCaretOnEditTests` 7, `CanvasClipboardTests` 24, `RTFConversionTests` 24,
`CanvasCellStructuralTests` 4, `CanvasSelectAllTableDeleteTests` 6, `SpellCheckTapTests` 15,
`SelectionDrivenSpellCheckTests` 9, `NativeTextCheckingClientTests` 10,
`NativeTextCheckingResolverTests` 2, `NativeTextCheckingLiveTests` 1,
`AutocorrectUnderlineTests` 10.

## Mixed-coverage disclosure — `BlockQuoteEditTests` / `CanvasPullQuoteEditTests` (category e)

Both files are legitimately filed under category e — each contains a large, genuine block
of Return/Backspace-at-quote-boundary tests (roughly half of each file: double-return exit
at the beginning/middle/end of the quote body and author, backspace un-quoting/outdenting/
merging at every child position, Select-All+Backspace resets, the `resolveBox`-misroute
regression suite). But **each file's remaining tests exercise other categories**, read in
full rather than assumed:

- **`BlockQuoteEditTests`** (52 tests) also covers: format-command no-ops/toggles
  (`test_wrapInBlockQuote_wrapsTwoParagraphs`, `…nestsWhenAlreadyInsideQuote`,
  `test_unwrapBlockQuoteLevel_*` ×2, `test_toggleBold_isNoOp_inAuthorRegion`,
  `test_wrapInBlockQuote_insideTableCell_isNoOp`); insert-command no-ops
  (`test_insertTable_caretInQuote_isNoOp_followingBlockUntouched`,
  `test_insertMedia_caretInQuote_isNoOp_followingBlockUntouched`); vertical/arrow
  navigation (`test_verticalNav_*` ×3, `test_arrowRight_intoNonEmptyBlockQuoteAuthor_…`);
  Tab navigation (`test_tab_*` ×4); tap placement
  (`test_tapInBlockQuoteAuthorArea_placesCaretInAuthor`); and toolbar/state queries
  (`test_currentState_caretInQuote_…`, `test_editorState_blockQuoteDepth`). These touch
  categories a (text/range), b (directional/vertical nav), h (geometry/tap), and i
  (touch placement) — not e.
- **`CanvasPullQuoteEditTests`** (34 tests) has the same pattern: a format-toggle command
  (`test_makePullQuote_togglesParagraphsIntoOneBlock_preservingFormatting`); author-region
  insert/replace routing that is plain text insertion, not Return/Backspace
  (`test_insertText_atEmptyPullQuoteAuthor_*` ×2, `test_replace_atPullQuoteAuthor_…`,
  `test_selectionReplace_viaInsertText_atPullQuoteAuthor_…`); typing-attribute checks
  (`test_pullQuote_emptyTypingAttributesAreItalic`, `…AreCentered`,
  `test_pullQuote_typingAttributesAtGlobal_returnsItalicWhenEmpty`); arrow nav and tap
  placement (`test_arrowRight_intoNonEmptyPullQuoteAuthor_…`,
  `test_tapInPullQuoteAuthorArea_*` ×2); composer flat-range primitives
  (`test_composerFlatRange_*` ×2, `test_composerSelectedRange_caretInsidePullQuote_…`);
  and framed-neighbor spacing geometry
  (`test_pullQuoteNeighbors_reserveExtraExternalMargin`). These touch categories a, g
  (autocorrect/prediction-adjacent typing attributes), h, and i.

Neither file is marked PARTIAL for category e — the Return/Backspace-boundary half of each
is on its own an ample, on-target gate — but a Phase-4 task citing either file for anything
beyond category e's boundary behavior should verify the specific test it wants, not assume
the whole file is in scope.

## Known gap — not coverable by any test (category i)

Two of deviation D18's four survivals cannot be pinned by any test today, because no seam
exists to drive the private long-press handler without a `Sources/` change:

- The **loupe session lifecycle** (creating/tearing down the per-drag `UITextLoupeSession`).
- The **per-drag `UITextSelectionDisplayInteraction`** that `handleLongPress` creates fresh
  and removes on release (see `PKG/CLAUDE.md`, "Loupe grow-from-cursor + gliding shadow
  caret cursor").

Both are confirmed correct by code reading only (`DocumentCanvasView+FloatingCursor.swift`
/ the long-press handler), not by any executable test. A Phase-4 task routing category *i*
must treat this as an accepted, pre-existing hole — not something this registry's tests can
promote to "covered."

## TextKit 1 skip census

Filled in by Task 9. The only legitimate skip reasons are the three documented TK1 trade-offs in
`PKG/CLAUDE.md`: no spoiler text-hiding, no loupe, no inline predictions.

**Empirical result: zero new `skipOnTextKit1` call sites were needed.** The full suite
(`Scripts/iostest.sh`, 1800 tests as of this task — 1797 pre-existing + 3 new `EngineSkipTests`)
passes with **0 failures under a genuinely forced TK1 pass** (`TK1=1 Scripts/iostest.sh`,
verified to actually flip `BlockLayoutBackend.forceTextKit1` — see the environment-forwarding
finding below). The only difference between the unforced and forced runs is **one additional
skip** (5 → 6): `SpoilerReconcileTests.test_reveal_removesHide_andBumpsRenderVersion_soTextRepaints`,
which already carried a **pre-existing, Task-9-independent** `XCTSkip` keyed on
`textLayout as? BlockLayout` returning `nil` (`SpoilerReconcileTests.swift:37`, reason: "spoiler-hide
display is TextKit-2 only (disabled on the TK1 back-port)") — one instance of the documented
"no spoiler text-hiding" trade-off, caught by a type-check rather than the new
`isForcedTextKit1`/`skipOnTextKit1` helper this task adds.

**Census reconciliation.** The census (written at Task 8, before the mechanism existed) hypothesized
that the suite would need new engine-conditional skips across all three documented trade-offs. That
hypothesis was **wrong in scope, not in kind**: the three trade-offs are real (see `PKG/CLAUDE.md`),
but none of the "loupe" or "inline predictions" trade-offs have a **unit test** that exercises the
gap — the loupe is created/torn down by `handleLongPress` (already recorded as untestable without a
`Sources/` change, see "Known gap" above) and the inline-prediction ghost/dismiss logic is exercised
only through paths that don't depend on which `BlockLayoutEngine` is active. So there was nothing for
`skipOnTextKit1` to guard in the current suite; the helper exists for **Phase 4+ tests that do**
reach one of these gaps (its own `EngineSkipTests` are the only current call site, and those exist to
test the helper itself, not to skip a real trade-off). This is recorded here rather than fabricating
speculative skip sites — a `skipOnTextKit1` call with no corresponding failure would be dead code
masking nothing.

**Load-bearing environment-forwarding finding (verified empirically, not from the plan template).**
`TEST_RUNNER_RTE_FORCE_TK1=1` must be a genuine **shell/process environment variable exported before
invoking `xcodebuild`**, not a trailing `xcodebuild test ... TEST_RUNNER_RTE_FORCE_TK1=1` command-line
argument. Both forms were tried directly against this SwiftPM scheme; a diagnostic probe dumping
`ProcessInfo.processInfo.environment` inside the test process showed the trailing-argument form never
reaches the test runner (confirmed with three orderings and a generic `TEST_RUNNER_FOO=bar` control),
while `export`ing it first (or prefixing the invocation, e.g. `TEST_RUNNER_FOO=bar xcodebuild test
...`) does. `Scripts/iostest.sh` uses `export` for this reason — see the comment at its `TEST_RUNNER_`
line. Had this not been caught, every "TK1-forced" run in this project would have silently run under
TK2 the whole time, and the double-run mechanism this task builds would have been non-functional
while appearing to pass.
