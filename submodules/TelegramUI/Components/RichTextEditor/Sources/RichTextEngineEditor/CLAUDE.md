# The engine editor ("Input V3")

`RichTextEngineEditorView` maps Core's `Document` onto the vendored InputDec engine; Debug Settings ▸ "Input V3"
(`ExperimentalUISettings.useInputDecEngine`) selects it, and it owns the composer's edit menu. It loads with the package
guide (`RichTextEditor/CLAUDE.md`: overview, build/test, shared verification traps, Core, the V2 metrics contract, caret
reveal, chat contracts, private UIKit names). Siblings: `Sources/RichTextInputDecUpstream/CLAUDE.md` (the engine; read
`PROVENANCE.md` before editing it), `Sources/RichTextInputDecObjC/CLAUDE.md` (the kernel),
`Sources/RichTextEditorUIKit/CLAUDE.md` (the legacy canvas editor, whose rules this one often ports).

## Map

| Where | What |
|---|---|
| `RichTextEngineEditorView.swift` | the wrapper: `currentRoles`, `applyEngineParallelBlocks`, `remakeBridge`, `rerenderPresentation` |
| `Sources/RichTextInputDecHost/TGIDObservingBlockTextView.m` | the engine view that IS the `UITextInput`; every `tgid_*` hook |
| `EngineBlockRole.swift`, `EngineBlockShape.swift` | roles (`ancestry` of `EngineAncestor` + `position`) and shapes |
| `EngineDocumentBridge.swift` | roles ↔ engine blocks: `engineRepresentation`, `block(for:from:)`, `flatten`, `oneLineText`, `renderMapper(for:)` |
| `EngineBlockSpacing.swift` | rhythm and insets, baseline drop, whole-point snap |
| `+SurfaceGate.swift`, `+BackspaceRules.swift` | keystroke decisions, `replaceAcrossBlocks`, `adoptRolePlan`; `backspaceJoinRules` |
| `+Settle.swift`, `+EditPrimitives.swift` | settle, `normalisePresentation`, derived-view checks; `replaceFlat`, `performHostStructuralEdit` |
| `+Ancestry.swift`, `EngineRoleNeighbour.swift`, `EngineDocumentTree.swift` | `ContainerContents`, `RoleNeighbour`, ancestry walks |
| `+Containers.swift`, `+ContainerDecoration.swift`, `+Details*.swift`, `+QuoteCollapse.swift`, `CollapsedQuote*.swift` | container commands, bands, details, folded quotes |
| `EngineTableGrid.swift`, `+Table*.swift`, `+RunCaretReveal.swift`, `+RunTouchGate.swift` | tables (`syncTableFrames` in `+TableLayout`, `syncRunScrollOffsets` in `+TableEdits`) |
| `+Media*.swift`, `+ListMarkers.swift`, `+ButtonRows.swift`, `+InlineButtons.swift`, `+Formulas.swift`, `+CustomEmoji.swift` | atoms and markers |
| `+UndoStack.swift`, `+Clipboard.swift`, `+DragAndDrop.swift` | `EngineUndoSnapshot`/`EngineUndoManager`, `clipboardSelection()` |
| `+GlobalPositions.swift`, `+Selection.swift`, `+ComposerHost.swift`, `+ArticleHost.swift`, `+HostInsert.swift`, `+Accessibility.swift` | Core's axis, the composer's flat axis, host verbs |
| `EngineDerivedViewExpectation.swift`, `+DerivedPlacement.swift`, `RichTextEngineUnimplemented.swift` | DEBUG self-checks; remaining traps |
| Tests | `Host/Tests/Engine/` (`Engine…Tests`), repo-root `Tests/ComposerHarness/Tests/` (`Harness…Tests`), `Host/Engine/` (`ID…Tests`) |

The remaining `richTextEngineUnimplemented` traps are `Block.<case>` arms in `EngineDocumentBridge` that no modelled
case reaches (`grep -rn richTextEngineUnimplemented Sources/`).

## Build and test

- `Scripts/hostapp.sh test` runs both schemes, `InputDecHost` (the editor's suites) and `InputDecEngine`: a change under
  `Sources/RichTextInputDecUpstream/` must pass the engine's contracts too. The engine's suites, oracle host and
  fixtures are in `Host/Engine/` (`README.md`; alone: `xcodebuild test -project Host/InputDecHost.xcodeproj -scheme
  InputDecEngine … -parallel-testing-enabled NO`). Test engine changes there.
- The InputDec trees are ordinary source, edited here. `IDProjectSmokeTests` forbids any mention of `UITextView` or a
  private canvas class/selector in the engine source, comments included. Swift calls the kernel only through
  `TGRichTextInputDecPerform` / `TGRichTextInputDecPerformReturningObject` (it raises `NSException`).
- Fixtures citing upstream `.xcresult` run records check only the path's shape (`IDIsUpstreamRunArtifactPath`); don't
  make them existence checks (an empty directory of the right name passes). The cited Hopper markdown is versioned here
  and keeps its on-disk assertion.

## Verification traps

- **Derived views are checked against the roles.** `verifyPresentationIsDerived` checks attributes;
  `verifyDerivedViewsAreComplete` checks every view pool by key, per layout, against `EngineDerivedViewExpectation`
  (cell → grid, chrome, placement; title → chevron, separator; ancestor → decoration; list item → marker), derived from
  the ROLES, never from the sync pass under check. Media is excluded on purpose. A new pool needs a field; the wiring is
  pinned (`derivedViewVerificationCount`). `derivedViewPlacementDrift()` checks each view's frame and SUPERVIEW by
  re-reading the producers' own placement functions (`gridChromePlacement`, `structuralChromeFrame`,
  `attachmentOverlayPlacement`; a second derivation would be the defect), also from `engineDidLayout` (guarded by
  `isPlacingDerivedViews` and `layer.needsLayout()`, without the existence check).
- **A trap inside a test kills the process while the summary can still say "N tests, 0 failures"**: count case names.
- `HostConfigurationConsumerTests` wants a reader in `Sources/` for every `public var` of the two host-configuration
  files and every `public static let …: CGFloat` on a shape; `DeferredConfigurationRegisterTests` checks deferred
  members name their rung. A mention satisfies both, so neither sees setter-only wiring (see "Quote geometry").
- **Selection geometry:** UIKit grows the rects carrying the logical endpoints by 1pt and integralizes them: assert
  coverage with a cap, never equality with a decoration frame. Stock-parity contracts compare through
  `IDSelectionRectExpectedFromStock` (covered sides moved to the line edge; sides are LOGICAL, direction is the LINE's:
  a Hebrew block's rect reports `NSWritingDirectionLeftToRight`). The differential corpus compares `selectionRects` only
  between our own hosts (`IDFieldIsComparableAcrossHostKinds`, keyed on host kind and field, never a scenario); stock is
  compared by area (`testEverySelectionStockHighlightsIsHighlightedHereToo`).
- **Pixels:** an ink scan resolves to one device pixel (1/3pt at 3×). `drawHierarchy(afterScreenUpdates:)` is black
  off-screen; use `layer.render(in:)` over an opaque fill (`EngineInkMeasurement.swift`), which ignores `maskedCorners`.
- **Environmental failures:** `InputDecEngine` can fail in bulk on `((windowScene) != nil)`, and the spelling family on
  a loaded simulator: re-run the scheme alone. `Host/Engine/README.md` records the suite's known failures.
- **Driving:** a table run's deceleration catch cannot be tested end to end (`isDecelerating` stays false under an
  animated `setContentOffset`; AXe calls are ~1s apart, a coast ~0.8s). A stock view added to the app window gets no
  taps (`Display`'s window `hitTest:`). The edit menu reads the pasteboard, so the paste alert eats the next synthesized
  tap. Host-coupled loops do not exist in a hostless harness: `sample <pid> 2` on the app process finds them.

## The model: roles, shapes and the bridge

### Roles hold structure only; the `Document` is derived from them
- `EngineBlockRole` is `ancestry` (enclosing `EngineAncestor`s, quote or details, outermost first) plus `position`
  (`.standalone`, `.secondary`, `.tableCell`). The view caches `currentRoles`, one per ENGINE block: a `BlockQuote` is
  one model block over N engine blocks, every other container is 1:1. `currentBlocks` is a projection by engine index.
- A role holds shapes (`EngineBlockShape`, `QuoteShape`, `TableShape`, `EngineContainerShape`), which have no text
  field: the engine's storage is the one copy of the text, and `document`/`currentBlocks` are rebuilt from roles plus
  `engine.attributedBlocks` on every read (`EngineDocumentBridge.block(for:from:)`). Don't copy text into a role; a pass
  may read the storage at use.
- Regroup (`EngineBlockRole.document(roles:blocks:)`) closes containers that are not a prefix of a role's ancestry (by
  id, so two adjacent quotes stay two) and opens the rest. Mutators write back through `applyEngineParallelBlocks(_:)`;
  assigning `Document(blocks:)` dissolves every quote.
- Flat geometry sums engine block lengths (`flatOffset(ofRoleAt:)`, `flatLength(ofRoleAt:)`).
- A block belongs to container Q iff Q is in its ancestry (children, nested lines, Q's author); spans
  (`span(of:around:)`), bands, spacing, coverage and author presence ask that. `container`/`containerID` is the
  immediate leaf container (the block, a second line's owner, a cell's table).
- A fresh block inherits its predecessor's ancestry, except after an author line (the quote's parent):
  `freshBodyRole(within:)`. Never assume the only ancestor is a quote (`innermostAncestor`, not `ancestry.last?.quote`).

### Structural edits carry their role plan
- The change notification rebuilds roles by identity unless the edit carried a plan: a structural edit goes through
  `replaceFlat(_:with:adopting:)`, adopted by position in that edit's own notification. Never build a plan from
  post-edit roles (one removed a role past the end). `adoptRolePlan` is for structure changes without an edit; a count
  mismatch asserts.
- Edit before the controller's own edit (gate) or after it (settle), never nested in it or inside the change
  notification: for a nested edit the controller re-inserts its newline, moves its caret, delivers notifications a pass
  late and spins the run loop inside its insert. UIKit's private should-change delegates are never consulted; one
  run-loop cycle's edits are one undo group.
- A host command issuing structural edits outside the gate wraps them in `performHostStructuralEdit` (captures the
  pre-edit roles, keeps the gate out, settles once). Without it, Tab out of a trailing table's last cell sent a `"\n"`
  the gate read as Return in a cell, losing the outer plan.

### Ask the structural question, not the raw one
- `containerDepth` counts CONTAINERS; only the spacing walk, `childUnits`' depth and "inside any container" use it.
  Quotes: `enclosingQuoteCount` (the host's `blockQuoteDepth`), `innermostEnclosingQuote` (the toggle), `isInsideAQuote`
  (the 15pt mapper). Indent: `EngineAncestor.contentIndent(styleSheet:)`.
- **Neighbours:** `currentRoles[i ± 1]` is storage order; navigation asks `RoleNeighbour` (`neighbour(after:)` /
  `(before:)`: `.sameLeafContainer`, `.sibling`, `.ownLineOfEnclosingContainer`, `.outsideContainer(_, beyond:)`,
  `.documentEdge`). Never `default:` in a switch over it, so a new edge or container kind fails to build. Plan
  arithmetic, `containerSpan` loops, settle's rejoin and the spacing walk stay raw. `moveCaretPastDetails` keeps
  `roleIsOwnedLineOfAnEnclosingContainer`; `applyBackspaceAtARegionBoundary` needs both its typed and its ancestry test
  (`test_aParagraphAfterADetailsStaysOutsideItThroughBothDoors`). `EngineRoleNeighbourTests`.
- **A container's own lines are not its children** (a quote's span ends with its author, a details' begins with its
  title). `ContainerContents`: `ownedLines`, `leadingOwnedLine`, `trailingOwnedLine`, `firstChildRole`/`lastChildRole`
  (a childless container reports its owned line as both), `isEmpty` (every child a bare empty direct paragraph),
  `ownedLinesAreEmpty` (a typed title counts, an author never), `holdsContent`. It and `childUnits` are the ONLY child
  enumeration; `EngineBlockRole.isOwnedLine(of:)` is the ownership test, keyed on `containerID`, never kind. Never index
  a span to find a child; raw `span(of:)` is for extents (`EngineContainerContentsTests`).

### No rendered block holds U+000A; roles are recovered by identity
- `engineRepresentation` passes every rendering through `withoutBlockSeparators` (a space in a one-line field, `U+2028`
  elsewhere): a cell's or code / pull-quote body's newline is `U+2028` in the engine, `\n` in the model. `engineText`
  (every body render, the set's door) runs Core `normalisedLineBreaks` and can SHORTEN text (CRLF → one break): never
  assume it preserves length. The gate's typed text is not normalised (`HarnessSetCarriageReturnTests`).
- The document setter records identity → role split-aware (`recordBlockIdentitiesAfterReplacingSpan`): a block the
  engine split on `U+000A` gives its role to its FIRST engine block. A role count that disagrees at layout is rebuilt
  from the engine's identities (`recoverRolesFromEngineIdentities`, a debug assertion); an unknown block becomes a body
  paragraph at its predecessor's depth. Don't zip positionally (`HarnessRoleRecoveryByIdentityTests`, via
  `testHookRenderedBlocks`, `testHookExpectsRoleCountMismatch`).

### One-line fields hold no line break of any kind, on every door
`EngineBlockRole.isOneLineField`: a code language, a details title, a quote's or pull quote's author (a caption is
multi-line); a new one-line field joins it. `EngineDocumentBridge.oneLineText` turns every whitespace run holding a
`Character.isNewline` into ONE space, applied by the render (`languageLine`, `authorLine`, `detailsTitleLine`), the
read-back, the gate (any delivery; `oneLineFieldText`) and settle (`settleLineBreaksInOneLineFields`: a commit, a
cross-block replacement). A raw "\n" there becomes an engine separator: two engine blocks for one role, a debug trap at
`TableLayout.swift:65`, and the last block lost from what is sent (`HarnessNewlineInOneLineFieldCrashTests`). A lone
"\n" is the Return key and keeps each field's own rule.

## Presentation and layout

### Where presentation goes
- The canvas renders each block from `block.attributedText`; there is no render-time hook. Styling that may be sent is
  written into the document and stripped on read-back; styling that must not be sent, or changes without an edit (a
  spoiler's hide), goes through `IDBlockLayout.displayDecorator`; anything font-shaped uses
  `IDInlineTextBaseFontAttributeName`, the pre-substitution face the bridge stamps. Presentation is a function of role
  and model, never carried by text. Views over text (emoji, dust) are placed from `id_rectsForCanonicalRange:`;
  `NSTextAttachmentViewProvider` cannot be made to fire.
- **Never read `.font` off `engine.attributedBlocks`** to reason about a style: it is the face CoreText substituted
  (`.SFArabic-Regular`, `.SFUI-Semibold`). Use `EngineBlockSpacing.pinnedBoxFont` (the base-face marker, bold/italic
  stripped, inline code's monospace kept) or the bridge. `EngineScriptLineHeightTests` must drive the TYPED path
  (`engine.insertText` per character) to prove the marker is maintained.
- The marker is in `allowedTypingAttributeNames` (`IDBlockTextView.m`) beside `.font`; test it on the typing attributes
  (KVC, `EngineTypingUndoCoalescingTests`), since `normalisePresentation` stamps it back before text reads.
- A substituted face is always re-seated on its base family on read-back (`withCarriedTraitsOnFallbackFaces`):
  `boldIsAmbient` distrusts a bold substitute, so a bold heading's Thai face would swallow the user's Bold.
- Every bridge swap goes through `remakeBridge`, never an inline construction: it carries `showsButtonRowMenuAffordance`
  (stamped from whether a host listens), which changes button-row measurement.

### Presentation changes re-render in place, as one attribute edit
- `rerenderPresentation(of:)`: every applier that swaps the bridge (theme, render metrics, code / quote / pull-quote /
  media geometry) writes only attributes when the characters are the same, so selection and marked range survive (a
  document set would end the composition and move the caret). The typing attributes and an open composition's
  `id_compositionTypingAttributes` are translated value by value (`id_translateTypingAttributesUsingBlock:`), or the
  read-back takes the old palette for an explicit colour. A change of characters (the formula renderer) takes a set.
- Each `tgid_mergeAttributes` re-projects the whole document, so every presentation pass (`normalisePresentation`,
  `rerenderPresentation`, `rerenderButtonRowAtoms`, any new one) collects `PresentationEdit`s for one
  `applyPresentationEdits` (host `tgid_mergeAttributeEditsInCanonicalRanges:attributes:removingKeys:`;
  `HarnessPresentationPassScalingTests`); `rederiveAtomPresentation` uses one
  `tgid_transformAttributesInCanonicalRange:usingBlock:` (`HarnessAtomFormatScalingTests`). Batch edits touch block TEXT
  only.
- A per-block loop never asks a question that walks the blocks (`canonicalStart(ofBlock:)`, `flatOffset(ofRoleAt:)` are
  O(N)): use the identity cache (`tgid_indexOfBlockIdentifier:`, `tgid_canonicalStartOfBlockIdentifier:`) or walk
  offsets alongside. `engine.attributedBlocks` and `engine.tgid_blockIdentifiers` build an array per read. The canvas
  pass does not re-insert a view already in place (`updateForDocumentChange:width:`).
- Empty-line attributes are per SHAPE (`cachedLineAttributes(for:)`; an uncached probe renders the whole ancestry). An
  empty block's typing attributes come from the bridge by identity (`installEmptyLineProviders`; by position while a set
  is landing).

### A block's FRAME is a line box; the rhythm below it is the renderer's
`StyleSheet` pins every line box to V2's pitch; V2 measures `ceil(ascender + |descender|) + (lines − 1) × pitch`, and
TextKit bottom-aligns a line inside a pinned box.
- **`.safe` (current):** `EngineDocumentBridge.v2BaselinePlacedStyle` re-pins the box to `ceil(ascender + |descender|)`
  and carries `pitch − box` as `lineSpacing` below each line, so the dead band sits between lines; used height equals
  V2's item and `trailingLineBoxOverhang` answers 0 for every stacked role.
- **`.off` (supported rollback), styles it declines (`pitch <= ceil(fontBox)`), attachment lines:** `EngineBlockSpacing`
  subtracts `trailingLineBoxOverhang(atRole:)` from what it deposits below a block through one `spaceBelow` helper,
  exactly once per boundary; insets may be negative; an attachment line offers no overhang (`EngineParagraphRhythmTests`
  drives both arms).
- **`applyV2BaselineShift`** returns the remaining drop (`pinned − fontBox`) as a net-zero inset pair, per ROLE
  (font-dependent); don't replace it with one host nudge
  (`test_theSafeArmsResidualIsFontDependentSoAHostNudgeCannotBePrecise`). Placed roles are excluded (the engine applies
  their insets inside the host frame).
- A text block's canvas is its glyph box (top = V2's item top, bottom = the last descender): a gap measured from
  `frame.maxY`, or an inset compared with a design constant, reads `constant ± drop` and must say so. Before
  re-recording goldens, assert the expected shape (only `inset` lines move, as net-zero pairs).

### Every block origin sits on a whole point, so selection rects abut
UIKit quantizes selection rect HEIGHTS to whole points, so a fractional origin leaves a seam (1/3pt is not enough).
`EngineBlockSpacing.snappedToWholePoints` is fed by `v2BaselineDrop` (snapped inside itself), the code language line
taking the body `.paragraphStyle`, the inset array and placed reservations (snapped once, BEFORE
`applyV2BaselineShift`), a media atom declaring `mediaAtomFont`'s descent, and `textContainerInset(forContentMargins:)`
(top margin snapped, remainder to the bottom: 4.5/5.5 → 5/5; horizontal untouched). The baseline is thus within half a
point of V2's. Don't round only the selection rects. Assert abutment
(`EnginePixelAlignmentTests.test_consecutiveSelectionRectsAbut`); "on the grid" assertions passed over a visible seam.

## Editing

### Keystrokes are decided at the surface gate, before the controller edits
- Text reaching `insertText:` / `replaceRange:withText:` goes through `tgid_textInputGate`; `+SurfaceGate.swift`
  forwards it (a newline in a cell or a code / pull-quote body becomes `U+2028`) or issues its own top-level edits and
  vetoes it. Return in a cell or a language line is a caret move with no undo step; legacy's double Return exits and
  un-makes. Selection deletions (`deleteBackward` with a selection, `cut:`) arrive as `replaceRange:withText:@""`. The
  host's own edits pass untouched.
- EVERY text-entry door goes through the gate (route a new one; both marked-text doors are). A selection covering a
  table only in part refuses typed text, and every paste route asks the same predicate (`rangeCoversATableOnlyInPart`):
  the engine's own paste is a storage edit the gate never sees.
- Hardware Return (`\r`, `⌘\r`) is claimed when a host sets `onHardwareReturn`; declined, it is `insertText("\n")` on
  the gated surface. Shift+Return in a cell inserts `U+2028`. Return-then-text in one delivery at a non-empty heading's
  start is split into its keystrokes (`isAtStartOfNonEmptyHeading`, `typeAtCaret(deciding:at:)`); other deliveries go
  whole. A replacement's inherited attributes stop at the first newline (`tgid_attributeReplacement:`).
- A host-decided keystroke (caret-door Backspace rule, gate veto, structural command) gets no `textInputDidChange:`, so
  it calls `endHostDecidedKeystroke`, or `isEngineEditInFlight` sticks and no caret move ends a typing run.

### Settle runs after every edit
`+Settle.swift`, from `engineDidFinishEdit`; never while an undo snapshot is restored or during a fold (a fold test
needs a keystroke afterwards). It declares minted blocks by rule (a quote child, an author tail as body, a dictation
split rejoined); turns an orphaned EMPTY second line into a body paragraph (Select All + Backspace over a code block
leaves the language line's identity); settles author lines, language lines, one-line fields, details bodies and atom
integrity; re-derives the presentation of every touched or re-roled block (`normalisePresentation`: text merged into a
cell takes its face); re-adopts the typing attributes. Ambient bold/italic are told from the user's by the base-font key
the bridge stamps on header cells and author lines.

### One Backspace rule table for both doors
UIKit delivers Backspace at a block's start as a caret OR as the range covering the join, unpredictably. Every rule for
that position is in `backspaceJoinRules`, walked by `tgid_deleteBackwardHandler` (caret) and `decideTextInput` (gate);
add rules only there.
- A rule fires at its role's START (`caret == flatOffset(ofRoleAt:)` ≡ `rangeIsTheJoinBefore`), owns its guards, never
  reads the caret from `engineSelectedRange` (the join range at the gate) and lands the caret itself
  (`unwrapContainer(caretLanding:)`). A caret INSIDE an atom unit is not in the table.
- Delivery is the door's (`BackspaceRuleOutcome`: `.handledOwingADelivery` when the mutation reached nobody); a delivery
  inside a rule notifies twice. The gate marks `structureTouchedThisEdit` for its veto path.
- The range door asks `applyDissolveOfEmptyContainer` first; its LEAF arm (empty code block, pull quote, 1×1 table →
  paragraph) records its own step (`recordUndoStepForStructuralChange`; `EngineEmptyContainerDissolveUndoTests`).
- `EngineBackspaceDoorEquivalenceTests` (same roles, text and caret through both doors) must put the selection on the
  join first, as UIKit does.

### Return and Backspace at a block's start
- Return at offset 0 of a non-empty heading inserts an empty body paragraph above and keeps the heading
  (`decideReturnAtStartOfHeading`; `HarnessHeadingReturnAtStartTests`); mid/end Returns make a body tail with cleared
  `fontSize`. Backspace at a heading's start below an EMPTY standalone paragraph of the same container removes that
  paragraph (`headingAfterEmptyParagraph`; `HarnessHeadingReturnBackspaceTests`).
- Return at the start of a non-empty list item opens a fresh unchecked item ABOVE; the item keeps role, identity and
  `checked` (`decideReturnInListItem`; `HarnessChecklistReturnAtStartTests`). The top exit is asked first.

### Cross-block replacement (`replaceAcrossBlocks`)
Legacy's one rule (`applyReplaceOutcome`), ported and refined:
- Refused: an endpoint inside a table the range covers only in part.
- A container wholly inside the range is dropped with its own lines; blocks between the endpoints go; a partly covered
  leaf keeps its remainder; a quote's endpoint child merges like a paragraph; across cells it is one edit inside each
  cell, last to first (`replaceAcrossCells`).
- **Deleting whole lines keeps the line after them:** from a standalone paragraph's offset 0 to a later block's offset
  0, the blocks before go and that block keeps role, identity and text (`deletesWholeLinesBefore`, first after the
  refusals; not for a composition, whose deletion is typing; `HarnessWholeLineDeletionTests`). Elsewhere the survivor
  takes the first block's role, else the end's, else a fresh body paragraph.
- A truncate never keeps a dropped unit's endpoint role: with one endpoint a leaf or title and the other's unit covered
  whole, the unit goes and the entered block absorbs the text (`HarnessWholeTableEditIntoSecondaryLineTests`). A range
  ending in a quote's author truncates there (`endIsLeaf`; `HarnessQuoteBodyIntoAuthorRangeTests`); one starting in an
  author merges the next block's tail into it; one entering a details title truncates.
- Host edits take the typing attributes of the live selection: put it back first (`truncateAroundMediaUnits`;
  `HarnessTypingIntoCaptionFormattingTests`). Never re-insert kept text as a string; moved text gets its attributes back
  (`restoreStyleFlat`). Open defect: `settleMediaAtomIntegrity` moves a tail beside a media atom into the caption as a
  plain substring (bypass path only).
- A non-empty range's end is exclusive when deciding which blocks it touches (`touchedBlockIndices(for:)`,
  `touchedParagraphIndices(for:)`, as `NSString.paragraphRange(for:)`); a caret at either edge touches the block
  (`HarnessBlockCommandSelectionEndTests`).

### The caret goes after everything inserted, and the document grows a line if it must
The engine's `replaceRange` applies it (paste and AI-compose; legacy's paste is unchanged). If the content ends in a
block other than body/header (every top-level paragraph style but `.caption` and `.pullQuote`; a list item is body) AND
lands at the document's end, a body line is added below for the caret. Mid-document nothing is added and the caret goes
to the start of the following block.

### `insertDocument` lands where the caret is, at any depth
`insertDocument` (AI generate, attach a file, the style insert) renders within the caret's ancestry
(`EngineDocumentBridge.engineRepresentation(for:within:)`); don't build top-level roles and re-parent them (quoted text
renders through the quote mapper). An empty paragraph in a quote is consumed like a top-level one; a cell, a container's
own line and a non-paragraph shape are not, and a caret in a cell places after the table (`containerSpan`,
`owningTable`). The caret's role is resolved before the framing, so an unresolved caret fires no settle or `onChange`.

### The global position axis is Core's
`selectedGlobalRange()` and `replaceRange(from:to:with:)` work on Core's axis (`DocumentTree`, `PositionResolver`) and
must never trap (`RichTextAttachmentScreen` calls them for AI). `EngineBlockRole.position` maps exhaustively onto
`TextNodeRef`; `replaceRange` IS `Document.replacingRange`, one undo step. A formula is its LaTeX in the model and one
`U+FFFC` in the engine once a renderer is registered (`modelRuns(readingBack:)`): read the engine, never `offset −
roleStart`. `nil` means nothing is selected; a text-less role answers its block span (`PositionResolver.blockSpan`,
outermost first: a code block and its paragraphs share a `BlockID`); a caret in a gap resolves to the nearest text
position, forward first, scanning outward (`EngineGlobalPositionTests`).

### IME compositions are typing
- Over a selection, the gate decides the deletion first (`tgid_resolveSelectionBeforeComposition`, both marked-text
  doors); over a partly covered table the composition does not start. Deletion and composition are one undo step
  (`tgid_isResolvingCompositionSelection`).
- The commit gets the typing attributes the composition STARTED with, then (at a caret) the typed-text policy. A rule
  resolving the selection elsewhere must select what typing would replace and call
  `tgid_noteCompositionTypingAttributesOfSelection` (`HarnessCompositionFromMediaStopTests`).
- At an atom's stop it is placed once, when it starts (`tgid_compositionCaretResolver` →
  `resolveAtomStopBeforeComposition`): at the caption's start, or on a body line minted with undo registration off and
  `lastSettledUndoSnapshot` reset, so the composition's step reverts the line; a composition ending empty removes it
  unrecorded (`tgid_compositionDidEmptyHandler`; `HarnessAtomStopCompositionTests`).
- Marked text holding "\n" in a one-line field is flattened (`tgid_markedTextFilter` + `oneLineText`); the composition
  stays open (`HarnessCompositionNewlineInOneLineFieldTests`).
- Open hazard: a deferred host `document` set can land inside a composition and ends it only if the replaced span
  reaches the marked text (`HarnessCompositionAcrossQuoteEndTests`).

### Typing attributes: stock behaviour, except on empty lines and after a format command
- A command that restyles the selected text re-adopts the typing attributes: `recordingInlineFormatStep` ends with
  `tgid_adoptTypingAttributesOfSelectedText` (UIKit's `_invalidateTypingAttributes`; copying the first character's
  attributes would carry markers the allowed set keeps out). A new restyling command outside it must ask the same
  (`HarnessTypingOverFormattedSelectionTests`). A selection deleted through the gate re-derives them from the caret
  (`tgid_rederiveTypingAttributesAfterSelectionDeletion`).
- Typing over a selection starting on an EMPTY line types as a caret on that line (override of
  `id_adoptEmptyBlockTypingAttributesIfNeeded`; deliberately not stock: `HarnessDarkThemeEmptyLineTypingColourTests`).
  Straight after an inline format command, while the selection is unchanged (`tgid_formatCommandSelection`), the first
  selected character's traits apply on top (`HarnessFormatOverEmptyLineSelectionTypingTests`). That record is typing
  state an undo restores (`EngineUndoSnapshot`, `applyUndoSnapshot`); any new typing state kept beside the document
  belongs in the snapshot.
- A changed non-empty block's separator takes its last character's attributes on every path
  (`id_restoreAttributedBlocks:changedRange:`, `id_transformTextAttributesInCanonicalRange:`): after Link over a line's
  end the separator is linked (`HarnessCompositionAfterLinkFromLineEndTests`).
- Typed-text policy: links are not drawn underlined, so an underline continues (`HarnessUnderlinedLinkTypingTests`);
  text leaving a link takes its BLOCK's colour (`cachedLineAttributes(for:)`), also at a block start before a link
  (`HarnessTypedTextBeforeLinkColourTests`). The read-back drops the inline-code fill from a non-code run
  (`withoutCarriedPresentation`).
- Inline format ranges widen to composed characters (`composedCharacterRange`; `HarnessFormatSplitSurrogateTests`);
  typed edits don't (stock doesn't). Every structural "\n" search is LITERAL (`NSLiteralSearch` / `.literal`): a
  separator before a combining mark is one composed sequence; `components(separatedBy:)` is safe, `replacingOccurrences`
  without `.literal` is not (`HarnessAuthorLineMidClusterCrashTests`).

## Selection and positions

### Block selection rectangles
- **Measured against each block's SLOT** (canvas plus the space `blockInsets` reserves; slots tile), per SEGMENT
  (`IDDocumentLayoutCoordinator`): a segment reaches the slot's leading edge when its line is covered from its start,
  the trailing edge when covered to its end, the top on the first line with `extendHead`, the bottom on the last with
  `extendTail`. A selection ending mid-paragraph stops at the glyph.
- Padding inside a block's own box is washed with its content; rhythm outside only when the selection reaches past
  (`selectionBoxForBlockIdentifier:`; `CGRectNull` = all rhythm).
- **A selected break on an EMPTY line draws a mark** (`IDBlockTextGeometry`): 0.22 of the line (floor 4pt) wide,
  `ascender − descender` tall, bottom-aligned in `usedSize`, sized in `IDBlockLayout`; never the pinned box (it reaches
  into the line above); empty lines only. It is excluded from endpoint promotion. A head-only zero-length range yields a
  mark on an empty block, carrying the head boundary role (which the validator requires) and no logical endpoint, and
  nothing on a full one.
- **Highlight:** a selected separator is offered to BOTH neighbours (the block before extends its tail, the block after
  its head); the head yields to a separator the tail claimed. Ownership is settled per claim, never by suppressing a
  block (an empty block IS only a separator).
- **Endpoints: exactly one rect claims each logical endpoint**; a second trips the duplicate-endpoint guard
  (`IDRichSelectionGeometryResultIsValid`) and nothing draws. A selection that STOPS at a separator ends at the next
  line's start: `id_selectionGeometryAttemptForCanonicalRange` suppresses the previous block's `separatorTail` end
  claim; the mark carries the end on an empty next line, else a zero-width endpoint rect is synthesized above the
  coordinator. Neuter either half and the selection vanishes.
- All-or-nothing: `exact = NO` / nil drops every segment (no highlight, no handles, menu at infinity). In
  `selectionSegmentsForLocalRange:` a zero-width segment is nothing to draw, not a failure: a lone `U+2028` widens to
  its line's end, a character drawing nothing (a leading RTL mark) is dropped with its endpoint handed on, a tail on an
  atom filling its line draws the mark at the edge (`HarnessBidiMarkSelectionGeometryTests`). `CGRectIsEmpty` is not the
  test (true at zero height). Diagnose by logging each `exact = NO` / `return nil`.
- `selectionBoxes`: a block whose visible box is wider than its column declares it, filled verbatim from the frame its
  decoration got (`syncContainerDecorations`, `syncMediaViews`; minX/width read); don't compute a matching outset;
  writing it does not lay out. Never for a placed cell, a button row or a collapsed quote. A placed run's leading rhythm
  belongs to its first row (`closeRun`).
- Known look: the handle spans the whole rect carrying the endpoint, reaching into the rhythm above. Splitting that rect
  was reverted; a retry must keep the boundary role on the band, and a break mark emits no bands.

### Selection state UIKit reads
- **A host set re-seats the selection before `textDidChange:`** (`tgid_replaceBlocksInRange:`,
  `tgid_setAttributedBlocks:`): kbd builds its state from the selection then, and old offsets against new text aborted
  it in `TIRevisionHistory` (`HarnessInputDelegateContractTests`).
- **A tap places the caret under the finger:** UIKit snaps a tap to a word edge, then shows the menu for a tap that did
  not move the caret. `TGIDObservingBlockTextView` overrides `_findBoundaryPositionClosestToPosition:withGranularity:`
  for WORD granularity (only tap placement calls it); `EngineTapCaretPlacementTests` keeps stock's snap as a control.
- An untracked anchor's clamp is sticky (`IDRichTextAnchor`, `id_snapshotCanonicalOffsetClampedToLength:`). UIKit's
  tokenizer answers a block's END as an empty line; `TGIDLineEndCorrectingTokenizer` corrects that one answer.
- **A vertical walk out of lines lands on the document's edge, never nil** (`-[IDRichTextLayoutController
  id_positionFromPosition:inDirection:offset:…]`), only when the failing step's caret is on that edge's line; a nil
  makes UIKit substitute a position far up (`HarnessVerticalMoveAtDocumentEdgeTests`). Into or within a placed run it
  picks a ROW, then the member nearest the goal x (`verticallyAdjacentBlockIdentifierFromBlockIdentifier:`); no point
  probe.
- **A missing endpoint is the native controller's answer, not a violation:** UIKit hands unchecked positions to
  `textRangeFromPosition:toPosition:` and `emptyTextRangeAtPosition:`; a nil `from` is the document start, a nil `to` is
  `from`, as TextKit 2 (`HarnessExtendPastDocumentEdgeTests`). A foreign or expired position still raises.
  `_caretRectForOffset:` → `caretRectForPosition:` is one more unchecked hand-off, not reached by anything measured.

## Containers

`.code`, `.pullQuote`, `.blockQuote`, `.table`, `.media` and details round-trip through `EngineDocumentBridge` and draw
per-block decoration views. A block quote holds any block at any depth; quotes and details nest freely.

### Nesting, exits and quote commands
- **Depth is a render input:** quoted text uses the 15pt quote mapper at every depth (assign, never multiply); a nested
  block is indented by the SUMMED `contentIndent` of its containers, never `quoteIndent × depth`; a code child keeps the
  code face; a cell is placed, not indented. `probeBlock` wraps the probe in the ancestry; `probeShapeKey` carries the
  ancestry's KIND sequence.
- **Exits move one level and belong to the CHILD UNIT** (keyed on its first role). Return on an empty last child leaves
  the quote. Backspace at a lone child's start un-quotes one level (`unwrapQuote`); at the first of several, the unit is
  lifted out before the quote. Non-first second lines and the quote's author are walls; cells decline. Backspace after a
  nested quote is a wall (caret to its last child's end).
- Coverage is per ancestor, outermost first (`coveredUnit`); the survivor's ancestry is the longest common prefix.
- **Quote toggle** dissolves the deepest quote all touched blocks share (an author line counts), else wraps the touched
  TOP-LEVEL units; refused in a cell (legacy's composer nests on every tap). `wrapInBlockQuote`, `makeCodeBlock` and
  `makePullQuote` rebuild through the document setter (settle never runs), so each records one step via
  `recordUndoStepForStructuralChange`; unwraps are real edits.
- Bands re-sort by depth; nested code bands and media are flush with the quote's inner edge and never bleed.
  `insertTable` anchors through `Document.insertingBlock(_:after:)`, which descends into quotes.

### Quote geometry
- **Both sides held back** (legacy `BlockQuoteBox`, 16 / 22): the trailing half is a negative `tailIndent` in
  `EngineDocumentBridge.quoteIndented`, per level, not a block inset. `StyleSheet.quoteTrailingInset` is resolved at
  INIT as well as in the setter (setter-only wiring worked only in the article editor). The leading inset is the sheet's
  `quoteIndent` (16), not the host knob. Atoms subtract both (`atomHorizontalReduction`); a nested table adds
  `TablePlacement.containerTrailingInset`. A details adds no horizontal inset.
- **Capped:** quotes past `EngineAncestor.maxIndentedQuoteLevels` (8) add no indent, and `syncIndentedQuoteLevelLimit`
  sets `StyleSheet.indentedQuoteLevelLimit` so the text column (width minus `textContainerInset`) keeps
  `minimumQuotedColumnWidth`. Sum indents ONLY through `Sequence<EngineAncestor>.contentIndent(styleSheet:)` /
  `contentTrailingInset(styleSheet:)` (`HarnessDeepQuoteColumnTests`). Measure the column, never the editor's bounds; a
  width change re-renders only when it moves a whole level and a quote is that deep
  (`HarnessDeepQuoteNarrowColumnTests`).
- A leaf container's interior is declared twice, both required: `EngineBlockSpacing.layOut` and `leafInteriorPadding`
  (`test_theBandSitsTheSameDistanceBelowThePrecedingBlockInBothStates`).

### Author lines
- A quote shows its author field once it holds any child that is not an empty body paragraph (a table, code block, atom
  or nested quote counts however empty). `EngineDocumentBridge.flatten` (forward) and `authorLinePresenceThatIsWrong`
  (settle) must agree (`EngineBlockQuoteTests.test_settleAgreesWithTheForwardPassAbout…`). A PULL quote is not a
  container: its author follows its one block's length (`PullQuoteBox.shouldShowAuthor`); dispatch on the owner's kind.
- **An authored quote never loses its author.** Backspace on the break before an authored quote (`authoredQuoteWall`,
  ahead of the unwraps) only moves the caret to the block above; the commands still unwrap
  (`HarnessSeparatorBeforeQuoteDeletionTests`). A wider range emptying the body is caught by
  `settleOrphanedSecondaryLines`: an author line with text gets an empty primary minted above it
  (`mintEmptyPrimary(beforeAuthorLineAt:)`; `HarnessAuthoredQuoteWideRangeTests`). The author goes only with a range
  covering the quote (`containerIsCovered`); an empty orphaned author is removed with its quote.
- An author line keeps its runs (`Block.authorRuns` drops only bold, italic and the pinned size) and reads back at
  `.caption`; don't rebuild it from `flatText` (`HarnessAuthorLineEntityTests`).
- `test_deletingTheLastCharacterAfterAQuotedTableKeepsTheCaretInItsParagraph` uses two bare paragraphs on purpose.

### Details blocks (R7 details)
- The title is a SECONDARY REGION (`.secondary(owner: .details(shape), line: shape.titleLineID, kind: .detailsTitle)`,
  id `"<id>#title"`) in no child unit. A details indents only its title's glyphs (`titleGlyphIndent` 26); its body is
  flush; it still suppresses the media bleed.
- **A title is content; an author is a field:** every "has content" rule counts `.detailsTitle` (also for a parent whose
  only child is a folded details); coverage skips `.blockQuoteAuthor` and `.codeLanguage`; the empty dissolve is guarded
  against a titled details.
- **Folding MOVES the body into `DetailsShape.foldedChildren`** (`flatten` emits children only when `expanded`), so a
  folded details has no primary, and settle, `containerIsCovered` and boundary Backspace must not treat that as damage
  (rewriting the title loses the body). Don't keep the body in a side table by id. `setExpanded` re-sets the document; a
  caret in the body lands at the title's end. An expanded details always has a body (`settleDetailsWithoutBody`;
  `HarnessDetailsBodyCrossDeleteTests`).
- Ownership, not kind names: `isOwnedByAnAncestorContainer` drives `settleOrphanedSecondaryLines`, `coveredUnit` and the
  walk; `EngineDocumentTree` reaches any container via `ancestryChildren` (cells excluded). `unwrapContainer` drops a
  quote's author but keeps a details' title as a paragraph.
- **Exits:** Return in the title moves into the body; Return on the empty last child leaves. Backspace at the title's
  start unwraps one level; at the first body child's start it is a WALL (caret to the title's end); a wholly empty
  details un-details in place; checked innermost-first, before the quote walk. Boundary Backspace is a wall at both
  doors (`applyBackspaceAtARegionBoundary(at:)`, last before `replaceAcrossBlocks`; `consumeBackspaceAtARegionBoundary`)
  and keeps the empty paragraph that is its container's only child. A caption-less atom inserted as the last body item,
  with a block after the details, gets a trailing paragraph inside.
- **Drawing:** one 0.5pt hairline (`detailsSeparator`) at the span's bottom, on the details' column; no band. The
  chevron is its own tap (`textInteractionMayBegin` refuses over its own box only; `detailsChevron(at:)` deepest-first,
  ±12pt slop). `chevronSize` 18, `chevronLeadingInset` 3, `topInset` 6 both states, bottom 16 expanded / 17 folded,
  `titleBodyGap` 14. `EngineBlockSpacing` keys on the ANCESTOR (`unit.quote` is nil here); bottom deposits are
  placed-aware. `test_theTitleDoesNotMoveWhenFolding` is not inset coverage.
- `insertDetailsBlock` places through the DOCUMENT like `insertTable`; one undo step.
- **A third `EngineAncestor` case** touches `contentIndent`, `EngineBlockSpacing.interiorContributions`/`spacingKind`,
  `leafInteriorPadding`, `ancestryChildren`/`replacingAncestryChildren`, `ContainerDecorationKind`,
  `EngineDerivedViewExpectation`, `flatten`, `render(role:)`, `unwrapContainer`, `probeShapeKey` (`"q"`/`"d"`),
  `SecondaryRegionKind`, `isOwnedByAnAncestorContainer`; every `RoleNeighbour` switch then fails to build.

### A folded quote is an atom
- One model block is an `EngineAncestor` when open and `EngineBlockShape.collapsedQuote(QuoteShape)` when folded, so it
  inherits every atom rule via `atomUnitIndex`; don't model it as a preview line inside an open quote.
  `QuoteShape.foldedChildren`/`.author` are non-empty iff `collapsed`. The gate decides it with `isLeafBody` and
  `leafIsAChildContainer`; the region-boundary wall answers `false` only because the atom rules sit above it in
  `backspaceJoinRules`; typing at its gap goes through `decideTextInputAtAnAtomUnit`. Deliberate divergence from legacy:
  Backspace at its gap parks the caret at the atom's end and the next press selects.
- The preview is laid out by `BlockLayoutEngine` (via `RichTextLayoutSurface.swift`), not a `UILabel`, its origin
  carrying `rawFirstBaselineFromTop − firstLineBaselineFromTop`. A hidden spoiler's emoji has its VIEW hidden: glyphs,
  views and dust are decided in one pass by the existing reveal rule and asserted in one test case. Each non-text block
  is one inline SF Symbol (`CollapsedQuoteMarkers`). Truncation is the box's
  (`BlockLayoutEngine.capLines(_:truncating:)`): a truncating mode in the paragraph style caps at ONE line. No media
  thumbnails; legacy's three-line look.
- The collapse glyph is culled against its own live set; the expand glyph belongs to the preview; `derivedViewShortfall`
  traps if a glyph outlives its quote. The toggle's first caret arm claims the span's end (`inside` includes `after`).

### A code block is plain text; its language is held as typed
- A `Pre`/`Code` entity holds no other entity, so inline commands skip a code body (`inlineFormatTargetRanges`), the
  Format menu disables them there (`inlineFormatsReachSelection`), the bridge renders and reads it through
  `plainCodeRuns` (atoms as text), and settle treats its trait markers as presentation
  (`HarnessSendPathCodeFormattingTests`). If `Pre` ever carries formats, all four go.
- The language line is `.secondary(kind: .codeLanguage)` over a paragraph shape: ask `secondaryKind == .codeLanguage`
  too (`HarnessCustomEmojiIntoCodeLanguageTests`). The model holds the language exactly as typed (only an emptied line
  reads nil); the WIRE trims it (`chatInputCodeLanguageForSending`). Don't trim in the read-back or at settle
  (`HarnessCodeLanguageEdgeWhitespaceTests`).

### Inline exclusions
- **No run is inline code AND a link** (mention, date, URL): Monospace over a link (`inlineCodeReachesSelection`) and
  Link over inline code (`linkReachesSelection`) do nothing, also in the menu; content arriving with both keeps the
  entity (`withoutInlineCodeOverLinks`; `HarnessInlineCodeOverEntityTests`).
- **Italic over a pull quote's body** is a no-op and disabled in the menu (`italicReachesSelection`,
  `inlineFormatTargetRanges(excludingPullQuoteBodies:)`): the mapper reads italic back false there and V2 renders a pull
  quote italic regardless. The author line is not excluded. If either changes, Italic must work again
  (`HarnessPullQuoteItalicOverCodeTests`).

## Tables

### Placement
- `.table` owns one engine block per cell, placed by the host through the engine's `blockFrames`. `EngineTableGrid`
  solves with legacy's numbers (proportional `ColumnSpec` widths floored at 100, 6/14 paddings halved when `compact`,
  spans via `TableMap`). `syncTableFrames` solves columns on a set and rows from the engine's used heights, repeating
  (at most three passes) while the heights after its push differ (`HarnessTableWidthChangeRowHeightTests`).
- **One table, one run:** every table's first cell is in `placedRunStarts`. Grid rects and `placement dy` are relative
  to the table's own run anchor, placed by the engine at the stacking cursor; don't reintroduce a host `runOffset` sum.
  Tests comparing two tables convert to engine space and assert `minY >= previous.maxY` (`EngineTableScrollingTests`).
- **The space above a table is decided where it is placed:** `EngineBlockSpacing.layOut` cannot reserve on a placed
  first role, so it diverts it into `placedReservations` (by role index, accumulating, one pass; `tablePlacements` by
  `BlockID` persists). Don't re-derive it elsewhere, and don't write a grid-free `placedTopReservations` walk.
  `TablePlacement` (dy, indent, size) is the one value frames and chrome read; a missing one asserts.
- Bands union `tableFrame(forTableAt:)` (a quote band sits 8pt around a quoted table). A nested table is solved narrower
  by its ancestry's indents, added to cell frames and chrome once.
- `EngineTablePlacementGoldenTests` pins absolute geometry (relationship asserts pass wrong layouts); record goldens
  BEFORE changing geometry.

### Editing in a table
- Return and Tab (`moveCaretToNextTableCell`) move to the next cell, no undo step; past the last cell they ask whether
  the next role is a SIBLING of the table. Backspace at a cell's start travels; at the FIRST cell to the end of the
  enclosing container's leading line, else out of the container (`EngineTableEditingTests`). Cells draw no list markers.
- `replaceTable` runs under `isParkingCaretForStructuralSelection`, so an edit keeps the structural selection.
- Toolbar trait queries park the selection in each selected cell; `isProbingInlineTraits` (distinct from the parking
  flag, whose notification `replaceTable` needs) makes the funnel ignore them, else the article host loops at run-loop
  cadence; the four traits are read in one pass per cell (`InlineTraitQuartet`), cached
  (`test_readingTheToolbarsTraitsOverAStructuralSelectionSchedulesNothing`).

### Wide tables: the run, its clip and its offset
- A table wider than its column is a placed run (`IDPlacedRunScrollView`) scrolling inside the engine. The run's content
  view hosts the grid chrome (`TableChromeView`) and emoji/dust overlays. `TableStructuralChromeView` is parented to the
  ENGINE outside the run at the unscrolled origin, fed `contentOffsetX`/`visibleWidth`, re-synced from `engineDidLayout`
  each scroll tick, overhanging the top and right borders by `knobOverhang`, and places its contents at
  `structuralChromeTableOrigin` (not a constant).
- **Cells' clip:** `tableClipOutsets` → `placedRunClipOutsets`; top level opens to the editor's edge, nested stops at
  the container's interior. **Chrome's clip:** `tableClipX(forTableAt:)`, the cells' window opened by `gripGutter` (15);
  the chrome view IS that window. **Travel:** `placedRunColumnOutsets` (from `tableColumnOutsets`) rests the far edge on
  the column's. Keep the three separate; the outsets grow the scroll view without moving the run. A nested table is
  flush with its container's interior and its last row carries `gripHeight` (17) more bottom inset. Tests measuring
  grips set the app's ~16pt margin.
- The right border scrolls into view via `EngineTableGrid.trailingBorderExtension(for:)`. The run clamps and assigns
  frame/content size only on a geometry change (per-pass clamping kills the rubber band).
- **The offset is host-owned:** `runScrollOffsets` + `runScrollIdentities` (`syncRunScrollOffsets`) mirror each run's
  offset every settled pass; when the cell identities differ from the mirror's (a splice, which the engine clamps to
  zero) the host's value is pushed back. Runs not fully placed are skipped. `height(forWidth:)` ends with
  `pushRunScrollOffsets()`.
- **A run scrolls sideways to the caret** (`+RunCaretReveal.swift`): owed on a text/selection change
  (`tgid_caretRevealPending`) or a width change, spent in the wrapper's `layoutSubviews` after `syncRunScrollOffsets`
  (`revealSelectionEndInPlacedRun`; not in the host's pass, where a re-created table's cells are not yet at their
  widths; `HarnessComposerFuzzTests.testEngineFuzzSeed34WidthRoundTrip`), against the table's COLUMN, first column → 0,
  last → max; it updates `runScrollOffsets`. A height-only or identical pass leaves a manual scroll alone
  (`HarnessTableCaretRevealTests`). `RichTextCaretRevealSolver` stays vertical-only.

### Table chrome
- Both chromes are positioned views, never redrawn and never `contentMode = .redraw`
  (`test_noTableChromeClassOverridesDraw`, `test_noTableChromeViewAsksToRedrawOnResize`,
  `test_aScrollLeavesEveryChromeLayerWithNothingToDisplay`): a clipping rounded container of per-cell fills, one view
  per interior line SEGMENT (stopping at merged cells, so nothing is erased), the frame a layer border. The list marker
  is the editor's only `draw(_:)`.
- The structural chrome is live whenever the caret is in a table (`structurallyChromedTable()` → `tableAtCaret()`):
  grips and four resize knobs, each a `TableStructuralControlView` reconciled by KEY (shape + `HandleSide`), never by
  range; `drawnHandleRects`/`drawnKnobRects` describe visible children only.
- **Knobs are drawing only** (`isUserInteractionEnabled = false`; a 44pt hit box swallowed taps over the cell); the drag
  is one editor pan, `tableKnobPan`, beginning inside a knob box and capturing its knob at `began`. `point(inside:)`
  answers for GRIPS only (false while the table moves). `containsControl(at:)` backs `tableStructuralControlContains`,
  the veto keeping a text DRAG off grips and knobs and a tap off grips (`isTap` from the shim); don't derive it from
  `point(inside:)`, and test it with hit-testing (it sees only touches the text view receives). The run's scroll pan
  declines a knob touch only (`tgid_shouldBeginScrollPanHandler`; the text-interaction hook exempts the scroll pan on
  purpose).
- Grips are MIRRORED (`HandleSide` `leading`/`trailing`/`below` sets dot direction and the selected bar's rounded
  corners) and look like legacy's `drawHandleDots` (4pt dots, 3pt gap, `secondaryLabel`; inverted to `systemBackground`
  on an accent bar while selected). A row selection with grips both sides rounds no outline corner. Look tests assert
  one-sided rounding where declared (`shownBarCorners`).

### Catching a moving table
- A run is not in the touch's responder chain (touches land on `IDBlockStackCanvasView`); the catch is the run's
  `gestureRecognizer:shouldReceiveTouch:` for its OWN pan. Don't add a canvas recognizer (it fires but does not catch).
- The gate is `id_isAnimatingNow` (moved by its own animation within `id_animationGraceInterval`, 0.05s; motion recorded
  only while decelerating or dragging), not `isDecelerating`, which UIKit clears as its pan takes the touch.
  `-setContentOffset:` pins a caught run until the finger lifts or drags; only the run holding the caught touch settles
  on release (`IDRunCatchReleaseObserver`); a caught run skips the pan's direction test; "in flight" includes the
  catching finger (held weakly, reassigned per touch). `delaysContentTouches = NO` (as legacy) lands taps without the
  150ms delay and is not part of the catch.
- A catching tap presses nothing: overlay taps use `gatedTapRecognizer(action:)` (`EngineRunTouchGate` →
  `id_isPlacedRunInFlightForView:`, per view); the structural chrome declines the hit while its table moves.
- The article sheet's pan (`AttachmentContainer`) yields while a table scrolls (`isPanGestureEnabled()` reads
  `hasTableScrollInFlight`); the window holds two editors, so check which has the responder.

## Media

- `.media` is one `U+FFFC` with a `MediaTextAttachment` sized from the proposed line fragment (`MediaSlotGeometry` at
  legacy's canvas width; `mediaAtomFont` 1pt). Image/video/location add a caption line (`.mediaCaption`, `<id>#caption`,
  `.caption` style); audio and document have none. The hosted view sits on `id_attachmentFrame` (widened by
  `horizontalBleed` when spanning), pooled by block id, culled 50pt off-screen.
- The attachment is value-equal so a set's span diff keeps media blocks; `.attachment` is not a presentation key
  (`insertMedia`/`applyMediaShape` write it). Inline-atom attachments stay
  pointer-equal; the span scan compares them with `drawsTheSameAs` (see "Undo").
- **Backspace on media is TWO steps** (product decision): after the atom, at the caption's start, or a poster tap
  SELECTS the atom; the next drops atom and caption. The pre-edit selection decides; both doors reach
  `consumeBackspaceAtMediaUnit`. At the start of the block after a unit, Backspace travels to the caption's end and
  deletes that block only if it is an empty standalone paragraph (`applyBackspaceAtStartOfBlockAfterMediaUnit`).
- Insertion is against the caret's whole container span (`containerSpan(containing:)`): before it at offset 0, else
  after, never between its own lines; in quotes/details at the caret's depth; from a cell after the table
  (`planAtomUnitPlacement`). A range entering a unit keeps its atom and truncates only the caption
  (`truncateAroundMediaUnits`).
- The atom's stops are never typed into: offset 0 opens a paragraph above, offset 1 is the caption's start (or a
  paragraph below). Settle repairs bypass paths (`settleMediaAtomIntegrity`, `settleCaptionLinePresence`), dispatching
  on `MediaShape.isCaptionless`, never on whether a caption line exists; gate and settle share
  `insertCaptionLine(afterAtomAt:)`. A fresh block at the trailing stop is rejoined by `declareFreshBlocks`; at the
  leading stop roles are swapped back by which block carries the attachment.
- Inserts are one edit (`replaceFlat(adopting:)` + `restyleFlat`); ••• verbs register their inverse by identity; •••
  Delete (`deleteMediaBlock`) leaves an empty paragraph.
- UIKit interaction is refused over a media host (`gestureRecognizerShouldBegin:`) except the scroll view's own pan and
  pinch; the host's tap takes only touches on itself. Quoted media is built with `horizontalBleed: 0`;
  `MediaTextAttachment.horizontalIndent` subtracts the head indent TextKit 2 ignores.

## Lists

- Markers are host views in the gutter (`+ListMarkers.swift`), never text (it would shift canonical offsets), pooled per
  block from `id_frameForBlock(at:)` in the engine's scroll content. Touch target ≥30pt
  (`EngineListMarkerGeometry.touchTarget`, `ListCheckboxHostView`); without a host provider a checklist draws Core's
  `☐`/`☑`. Ticking goes through `adoptRolePlan`, never a set.
- **A marker sits on the ENGINE's baseline** (bottom-aligned in the pinned box):
  `EngineListMarkerGeometry.baselineFromLineTop(font:pinnedLineHeight:)`, the ascender only when nothing is pinned;
  legacy's geometry assumes a corrected baseline. Its font is `bridge.renderMapper(for:)`'s (quoted items are 15pt). No
  `interiorPadding(...).top` term. Pinned against rendered ink, same glyphs in both columns, scan windowed.
- **An ordered list is one marker column and one text column per RUN** (`orderedListMarkerColumns()`, V2's
  `maxIndexWidth`): `syncLabelMarker` right-aligns labels in the run's maximum width (`1.` sits right of `2.`, as V2). A
  run ends at any role that is not an ordered item at the same level. The base indent reserves one character;
  `orderedMarkerExtraInset` adds `(characters − 1) ×` the advance of `0` as a BLOCK INSET recomputed every pass
  (`orderedListMarkerInsets()`: `syncContainerBlockInsets` adds it, `syncListMarkers` subtracts it), on the role's font,
  cells excluded. It relies on a horizontal block inset narrowing a stacked block's measure
  (`testHorizontalBlockInsetsNarrowTheTextMeasureOfAStackedBlock`).
- Numbering is Core's `ListNumbering.labels` from `currentRoles`; a container ends a numbered run; `labels` ignores
  `style`, so a quote is not its own numbering scope. A list continues among SIBLINGS only
  (`blockIDsNeedingListContinuation`: same ancestry; an owned line or a cell ends the run).

## Atoms: emoji, buttons, formulas

- **One atom per occurrence:** adjacent identical custom emoji have equal `ChatInputRun` attributes, so
  `runs(fromChatInputRuns:)` makes one atom per character and splits formula and pill runs
  (`HarnessAdjacentCustomEmojiRunTests`); never merge atom runs. Pin an atom's `.font` and `.paragraphStyle` with its
  `.attachment` (an inserted `U+FFFC` carries typing attributes).
- **Inline formats skip atoms:** B/I/U/S are never atom state; Spoiler is on an inline atom, not on a medium or row.
  After the engine's toggle or the spoiler transform, `rederiveAtomPresentation(touching:)` re-renders the touched
  attachment characters, presentation keys AND the four `IDInlineText*` trait markers
  (`HarnessAtomInlineFormatDriftTests`).
- **A button row is not a container:** `ButtonRowBlock` is a fifth `EngineBlockShape` (no ancestry, indent, band or
  unwrap rules), ONE attachment (`ButtonRowTextAttachment`, hosted `RichTextButtonRowView`) because
  `richTextPackButtonRow` wraps pinned to V2 (`RichTextV2ButtonParityTests`). `ButtonRowShape` carries the whole model
  (pill edits rewrite it, `applyButtonRowShape`). Reuse what `RichTextButtonSurface.swift` republishes; don't copy the
  arithmetic (`ButtonRowBackingView` is bound to `ButtonRowBox`). Its two stops are atom stops
  (`decideTextInputAtAnAtomUnit`); `settleButtonRowAtomIntegrity` lifts text beside it into paragraphs and makes it
  deletable (`HarnessButtonRowStopTypingTests`). The "…" affordance takes 34pt, so `onRequestButtonRowMenu` re-renders
  every row (`rerenderButtonRowAtoms`).
- An inline `textButton` pill draws only through its hosted view. Hosted rows and pills have their own tap recognizers,
  not `textInteractionMayBegin` (it fires on touch-down). Atom units share `planAtomUnitPlacement` and `atomUnitIndex`
  (`beforeAtomUnit`, `afterAtomUnit`, `consumeBackspaceInsideAnAtomUnit`); `mediaAtomIndex`'s gate callers are caption
  logic.
- **Formulas:** `registerFormulaRenderer` must reach the bridge's mapper, or formulas render as LaTeX unnoticed;
  registration rebuilds through the document (`applyFormulaRenderer`). A formula draws itself (`FormulaTextAttachment`).
  `standaloneFormulaRoleIndices()` ports `BlockBox.spacingKind` by reading storage. `insertFormula` makes a BLOCK and
  mints no trailing paragraph; `makeSelectionInlineFormula()` is the inline gesture. `insertInlineButton` mirrors
  `insertInlineFormula`: a cell is a paragraph like any other, a code block takes the label as plain text, an atom
  refuses. The tap target needs its transparent `layer.contents` (project `CLAUDE.md`, "iOS 26/27 windows and touch
  delivery").

## Text checking

- An accepted correction arrives as a plain `replaceRange:withText:`; UIKit's `_UITextChoiceAccelerationAssistant` draws
  the underline from `selectionRectsForRange:` at each rect's `baselineOffset`, which `IDRichTextSelectionRect` carries
  per LINE (TextKit 2 `baselinePosition` via `IDBlockSelectionSegment`; `EngineSelectionRectBaselineTests`).
- `id_requestTextGeometryAtPosition:` must call UIKit's block with all FOUR arguments (container, rect, baseline,
  position): the rect alone compiles and sends the underline to infinity. Baseline 0 means "no layout yet"; never raise.
- The selection container and `-textInputView` are ONE coordinate space: `IDNativeSelectionPresentationBackend` (and
  `IDTextView`) start where the block stack does (`EngineSelectionContainerSpaceTests`).
- `TGIDTextAlternatives` is the dictation surface; keyboard corrections never use it (`EngineTextAlternativesTests`).
- Testing: `axe type` is a hardware keyboard and never accepts a correction; tap on-screen keys (`axe touch --delay
  0.08`, one per 0.35s, ~2s before the space). The keyboard learns repeated words; an lldb stop mid-word kills the
  candidate. `IDAutocorrectionDecisionUITests` fail here for the hardware-keyboard reason (stock too).

## Caret and scrolling

When the caret is revealed is the host's decision (package guide, "The host decides when the caret is revealed").
- **The caret is drawn a turn late unless the engine flushes it** (UIKit moves it on a zero-delay timer).
  `-[IDBlockTextView layoutSubviews]` flushes via the public `layoutManagedSubviews` of
  `UITextSelectionDisplayInteraction` (`id_flushSelectionDisplayUpdate`) only after a DOCUMENT change
  (`id_selectionDisplayFlushPending`) or a changed wrap width / `textContainerInset` (the chat frames the editor outside
  `update`; `HarnessWidthChangeSelectionDisplayTests`); never after a selection-only change, which resets the keyboard
  selection anchor (only `IDBlockTextViewUITests` catches it). The host re-arms it when its own work moves the caret
  afterwards (`hostChangeAwaitingCaretDraw` → `drawTheCaretWithAHostChange` → `tgid_flushSelectionDisplayUpdate`): a
  command that rebuilds through the setter then places the caret, or `update(...)` moving the text geometry
  (`markCaretForRedrawIfHostGeometryMoved(from:)`; `caretRedrawCount`). `IDSelectionDisplayFlushParityTests` and
  `EngineCaretFollowsTypingTests` must not spin the run loop before asserting, and assert `cursorView` on both axes. The
  lag is one turn, never stuck.
- **The scrollable area is the visible area** (the article editor passes its bars and keyboard as `contentInset`, the
  composer `.zero`): `contentSize.height` is floored at frame minus insets in `TGIDObservingBlockTextView
  -setContentSize:`; `contentInsetAdjustmentBehavior = .never`; a changed top inset re-seats a scroll resting at the
  top; `scrollIndicatorInsets: nil` tracks the content insets; the placeholder's 4pt offset is the paragraph's leading,
  independent of the top inset (`EngineArticleInsetTests`).
- **A long press beside the caret needs the autoscroll TICK:** a loupe within 40pt of the caret puts the caret back on
  release unless the `autoscrolled` bit is set, which stock sets on the first tick in its 32pt bands. `startAutoscroll:`
  answers `autoscrollDidTick` wherever `IDVerticalAutoscrollStockSessionWouldStart` holds, after (never instead of)
  `autoscrollWillNotStart`; `updateVerticalAutoscroll:` reports every real tick (`HarnessLongPressCaretUITests`). That
  send (`setAutoscrolled:`) is not inventoried in `IDUIKitInteractionCapability`: add it by regenerating the pinned
  contract data (`Host/Engine/Scripts/generate-contract-data.py`). The harness's legacy focus press leaves its caret at
  the END; press twice for a fair control.

## Clipboard and drag

- **Copy and paste carry a `Document`** through legacy's `RichTextEditorClipboard.pasteboardItem(for:)` (fragment UTI,
  RTF, plain), so fragments cross editors. Hooks are on the engine view (`tgid_copyHandler`, `tgid_richPasteHandler`; NO
  falls through); Cut is copy plus an empty replacement through the gate (`tgid_cutRangeHandler`). Rich paste is asked
  FIRST. Paste is `Document.replacingRange`.
- **`clipboardSelection()` decides what a range holds once:** inside one caption or cell it is that region's text
  (`captionTextFragment`, `tableCellFragment`); otherwise it widens over every unit entered in part
  (`flatRangeExpandedOverUnits`) and every container the gate drops whole (`widenedOverDroppedContainers`, asking
  `containerIsCovered`). One range is extracted AND deleted, and the paste target uses the same rule: copy == delete ==
  paste (`HarnessCutIntoCaptionMediaDuplicationTests`). A partly covered table keeps the selection, so the gate refuses
  the cut. Unit edges map through `unitAwareGlobalPosition`; leave `globalPosition(atFlatOffset:)` as is.
- Copy/Cut/drag also write `oneLineFieldTextUTI` (the deleted range on one line: lines joined by one space, inline atoms
  as text, unit atoms as nothing) and `coveredTextFragmentUTI` (Core `extractFragmentAsCoveredText`), because a fragment
  carries a code language as metadata even for a body slice. A one-line field (`pastePlainTextIntoOneLineField`) pastes
  `oneLineFieldTextUTI`, else a flattened fragment, else the plain string (`HarnessFragmentIntoOneLineFieldTests`); a
  runs-only destination (cell, caption, pull-quote body) pastes `coveredTextFragmentUTI`, or a foreign fragment with
  languages as text (`withCodeLanguagesAsText`; `HarnessCodeLanguageIntoRunsRegionTests`).
- **The engine's own paste** is reduced in `combineItemAttributedStrings:` to what the model carries: no attachments or
  bare `U+FFFC`, line breaks normalised (a literal mirror of Core `normalisedLineBreaks`), the caret's typing attributes
  plus only trait markers, underline, strikethrough and link (`HarnessPastedForeignColourTests`). It lands 20–30ms after
  `paste:` (tests spin the run loop), so `handlePasteFromGeneralPasteboard` prepares first (resolves an atom stop,
  unrecorded; a cross-block deletion puts the baseline back so the paste's step undoes both,
  `HarnessCrossBlockPasteUndoTests`) and `tgid_pasteWillLandHandler` ends the typing run. Host paths read
  `EnginePasteSource`, which normalises line endings.
- **Drag and drop:** `UITextInteraction` installs neither half, so `+DragAndDrop.swift` adds `UIDragInteraction` /
  `UIDropInteraction`. A drop is a paste from the session (`insertPlainText(from:)`). A local move IS Cut + Paste in one
  `performAsOneUndoStep` and notification (`performLocalMove`), registered even when unchanged
  (`registeringWhenUnchanged:`); a refused move puts `documentAtLift` back; `destinationHolds` (also the drop proposal)
  refuses content the destination cannot hold (`HarnessLocalMoveContentLossTests`). A long press inside the selection is
  the drag's, elsewhere the loupe's (`tgid_shouldBeginGestureRecognizerHandler`); no non-empty selection, no drag.

## Undo

### The editor owns its undo stack
UIKit's granularity depends on the entry point (`insertText:` coalesces, `replaceRange:withText:` never), so the editor
keeps its own stack of `EngineUndoSnapshot` (a `Document`, a selection and typing state; roles derived, never stored),
installed as the engine's `undoManager` through `tgid_undoManagerOverride`: ⌘Z and the toolbar are one object.
- Typed runs coalesce by contiguity, as stock: a run continues while each edit starts where the last ended and replaces
  nothing; a replacement ends one and opens one; a caret move or a structural edit (`replaceFlat(_:with:adopting:)`)
  ends it; a composition is part of the run it was typed into. A sentence boundary and the typing↔deleting switch are
  not run ends. Settle's edits keep an open run; an attribute-only edit never registers twice against one baseline.
- NOTHING clears the history. A structural host command records one ordinary step with its captured before-state
  (`recordUndoStepForStructuralChange`: table insert, quote wrap, paste). `restyleFlat` registers no inverse;
  presentation is re-derived when a snapshot is restored.
- The bare `document` setter keeps history and moves the baseline. The host says what a set is: from OUTSIDE (Send's
  clear, draft sync) `discardUndoHistory()` after it (`HarnessExternalSetUndoTests`); on the user's behalf
  (autocomplete, emoji keyboard, date editor, Translate) `performAsOneUndoStep { document = … }`
  (`ChatRichTextInputNode.performUndoableInputChange`; `HarnessChatSideEditUndoTests`).
- The setter's span scan compares inline atoms by what they draw (`renderedBlocksAgree`, `drawsTheSameAs`); don't give
  emoji/formula/inline-button attachments value `isEqual` (equal adjacent attachments coalesce into one run); media, row
  and collapsed-quote attachments already have it.
- **A composition that opens a step holds it until it ends** (`pendingCompositionUndoStep`): registered on commit /
  empty / found unmarked at a settle if the document changed, else dropped; any other registration flushes it, an undo
  or an external set discards it. `EngineUndoManager` counts it in `canUndo` and registers it inside `undo()`
  (`test_aMultiStepCompositionIsStillOneStep`); for redo it counts as registered (`clearRedoStack()` when it opens;
  `HarnessRedoDuringCompositionTests`). `UndoManager` has no public clear-redo: register a throwaway action in a
  TOP-LEVEL group (event grouping suspended) and `removeAllActions(withTarget:)` it; in a nested group it would leave an
  empty group (an undo doing nothing).
- `groupsByEvent` stays ON: engine code (`IDInlineTextFormattingController`) registers into this manager and ungrouped
  registrations are rejected. `undo()`/`redo()` end with `deliverChangeNotificationNow()` (the scheduled one reads
  `canUndo` one step stale). No `unmarkText()` first (the engine closes a composition itself). Nothing is undoable
  before an edit. `appendUndoOperation:newGroup:` is a dead stub.
- `EngineTypingUndoParityTests` requires equal undo TRACES against a stock `UITextView`; don't replace it with counts.

## Host integration

- **A document set replaces only the span that differs** (by model id and rendered text;
  `tgid_replaceBlocksInRange:withAttributedBlocks:`), attaching to the preceding block so identities survive.
- **`onChange` fires exactly once per edit** (the composer lays out on each). Paragraph mutators (`setParagraphStyle`,
  `setList`, `setAlignment`, `indent`, `outdent`) and the list-continuation reconciliation restore the caret, which
  reaches `engineDidChangeSelection`: `deliveringOneChangeNotification` marks the delivery owed BEFORE the mutation.
  While a reconciliation is pending, `scheduleSelectionDrivenOnChange` defers to it. Keep both
  (`EngineChangeNotificationCountTests`, which counts over a window: see the package guide's verification traps).
- **Focus is the ENGINE's transition:** the wrapper never calls `super.becomeFirstResponder()`; a tap focuses the engine
  directly, reported by `engineDidBecomeFirstResponder`/`engineDidResignFirstResponder` (`wasFirstResponder` captured
  before `super`). The wrapper's overrides do not fire `onBecameFirstResponder` & co.
  (`test_focusIsReportedExactlyOncePerTransition`). Test taps via `editor.engine.becomeFirstResponder()`.
- **Inserts on the user's behalf** (`insertInlineRunsOnUsersBehalf`, `+HostInsert.swift`, behind the chat's
  `ChatRichTextInputNode.insertTextOnUsersBehalf`): plain text goes through `insertText`, so it equals typing; a custom
  emoji takes the spoiler of the character BEFORE the caret (`isSpoilerActive()` answers no at a caret inside a
  spoiler); a link run is typed, then `setLink`, shedding inherited inline code (`insertRunOnUsersBehalf`;
  `HarnessMentionIntoInlineCodeTests`). One undo step (`recordUndoStepForCommand` before the delivery) and one
  `onChange` (`deliveringOneChangeNotificationAcrossSteps`; `HarnessChatInsertStructureTests`).
- **The composer's flat axis mirrors `ChatInputContent`:** a details and a button row are off it
  (`ChatInputContent.blockFlatLength`; a caret there reads as the end); an atom counts by its MODEL length (formula →
  LaTeX, emoji → alt text, inline button 1) via `composerAxisSegments()`; an offset inside an atom snaps to its nearer
  edge, a range widens over it (`HarnessAtomComposerAxisTests`).

## Accessibility

- `accessibilityHint`/`Label` forward to the engine view, the element VoiceOver focuses (`axe describe-ui` also lists
  the hint on the container `Group`, which is never spoken).
- `+Accessibility.swift`: `accessibilityValue` reads custom emoji → alt text, formula → LaTeX, inline button → label,
  button row → labels joined by ", ", medium → `accessibilityMediaName(kind)` (nil reads nothing), collapsed quote → its
  preview text; every block is on this axis. `TGIDObservingBlockTextView` maps the AX selection
  (`_accessibilitySelectedTextRange`, `_accessibilitySetSelectedTextRange:`), snapping inside an atom's reading; line
  and column queries stay on the engine axis (`HarnessAccessibilityTests`, which call the private selectors because the
  AX bundle is not loaded).
