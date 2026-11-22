# `Tests/RichTextEditorUIKitTests/StockParity/` — what is ported, and every deviation

Task P1. These suites certify **Telegram's host** against **stock `UITextView`** — the same oracle
upstream certifies its own host against. Until this directory existed, the only oracle for the
InputDec backend was the user typing on a simulator: five rounds of hands-on testing, each finding
exactly one defect, each found only once the previous fix exposed it, while ~3000 in-tree tests
stayed green throughout because none of them crossed this seam.

This file follows the conventions of `Tests/DifferentialSupport/PROVENANCE.md`, the existing
vendored-InputDec harness in this package. Read that one first if you have not.

## Upstream

| | |
| --- | --- |
| Repo | `/Users/isaac/Documents/InputDec` (read-only; never edited, built, or written to by this task) |
| Commit | `fdad9ca519f5f27a07362e00dc6cefdcb73ca369` |
| Commit date | 2026-08-24 21:39:34 +0200 — *"feat(export): script the telegram-ios behavior-kernel snapshot"* |
| Ported on | 2026-08-26 |
| Simulator | iPhone 17 Pro K1 (`CA0A2186-0F4A-425B-B3B1-9B61E5FF01A9`), the `Scripts/iostest.sh` default |

## Per-file origin

| This directory | Upstream origin | upstream md5 | upstream lines | approach |
| --- | --- | --- | --- | --- |
| `IDInlineFormattingStockOracleParityTests.swift` | `Tests/IDInlineFormattingStockOracleTests.m` | `940c4e3fc319e0e05d7985ca1609564f` | 279 | transliterated; stock arm verbatim, two host arms added |
| `IDBlockTouchSelectionParityTests.swift` | `Tests/IDBlockTouchSelectionParityTests.m` | `9afe427f983ac66f7d81d68fc76753e8` | 444 | transliterated; 5 of 6 tests ported, 1 dropped |
| `IDBlockSpellingIntegrationParityTests.swift` | `Tests/IDBlockSpellingIntegrationTests.m` | `2a4a3ece87c1e808a89c00b4641c2b5e` | 541 | 1 of 12 tests ported, 11 dropped; + 1 calibration written here |
| `IDStockParityHarness.swift` | — | — | — | **written here**, not vendored |
| `PROVENANCE.md` | — | — | — | **written here** |

`IDStockParityHarness.swift` has no upstream counterpart: upstream's equivalents are inline in each
`.m` file (`makeCustom:stock:`, `hostCustom:stock:`, `attributesWithBold:…`). It is factored out
because three suites share it and because the character-axis map (below) must be applied identically
by all of them.

---

## Deviation 1 — the port is **Swift**, not Objective-C

Forced, not chosen. `RichTextEditorUIKitTests` is a Swift test target; SwiftPM cannot mix Objective-C
into an existing Swift target, and the assertions need `@testable import RichTextEditorUIKit`, whose
Swift surface (`RichTextEditorView.init(frame:inputBackend:)`, `canvasForTesting`,
`RichTextInputContractViolation`, `toggleBold()`) has no Objective-C projection. The only ObjC target
in this package is `Tests/DifferentialSupport`, which is PROVENANCE-governed and must not absorb
new files.

**Consequence, stated plainly:** "near-verbatim" means *semantically* verbatim. Every upstream
assertion that survives is the same claim about the same values; none is a byte-for-byte copy. That
is weaker than the `Tests/DifferentialSupport` vendoring, where the md5 is the guarantee. The
mitigation is this file plus the per-test doc comments, which name the upstream test each ported test
came from.

## Deviation 2 — three arms, where upstream has two (or one)

Upstream compares its host against stock. This port compares **stock**, **Telegram+InputDec** and
**Telegram+Legacy**, and classifies every divergence:

| verdict | meaning |
| --- | --- |
| `MATCH` | InputDec agrees with stock |
| `PORT-DEFECT` | Legacy agrees with stock, InputDec does not — **the port introduced this** |
| `PRE-EXISTING` | neither Telegram backend agrees with stock — the editor never matched here |
| `PORT-IMPROVEMENT` | InputDec agrees and Legacy does not |

The Legacy control is not decoration. The earlier differential corpus recorded 514 differences,
**194 of them shared with Legacy** — pre-existing canvas behaviour with nothing to do with this port.
Without a control every one of those is charged to the port, overstating its cost by ~38%.

`PRE-EXISTING` still **fails the test**. It is a real divergence from the oracle this suite exists to
certify against; downgrading it to a pass would be the silent loosening the task brief forbids. The
tag says who to bill, not whether it counts.

## Deviation 3 — comparisons run on the **character axis**, via the existing in-tree map

Upstream's host is canonically dense: its `UITextInput` position axis is a plain character count, so
upstream compares `-offsetFromPosition:beginningOfDocument toPosition:p` directly against an
`NSString` index. Telegram's axis is **sparse** — a top-level paragraph boundary occupies TWO
position slots while the projected text emits one `"\n"`, and `beginningOfDocument` is raw 1
(measured 2026-08-24, `Tests/DifferentialSupport/include/IDTelegramCharacterAxis.h`).

A verbatim offset comparison would therefore fail on **axis skew** rather than on the behaviour under
test. Every ported comparison runs through `IDTelegramCharacterIndexForPosition` /
`IDTelegramTextRangeForCharacterRange` — the map written for exactly this in Task 9c. It is exact on
the stock arm by construction (for a `UITextView` the prefix length IS the offset), it needs no
Telegram type, and all three arms run it unchanged.

**This deviation is itself under test.** `IDInlineFormattingStockOracleParityTests.test_0_…` is a
calibration that reproduces the headline InputDec defects **without calling the map at all** (the
caret is placed by `RichTextEditorView.moveCaretToDocumentEnd()`, production API). It exists because
"the harness aimed one character off" is the first and most reasonable objection to those findings.

## Deviation 4 — geometric probes are derived **per arm**, not shared

Upstream derives a probe `CGPoint` from the stock arm's caret rects and applies the same point to
both arms. It can: both of its arms are TextKit-shaped and lay the same text out at the same y.

Telegram's cannot. `BlockLayoutEngine` pins every paragraph's line box
(`minimumLineHeight == maximumLineHeight`, from `RichTextRenderMetrics`) while a stock `UITextView`
uses the font's natural leading, so for the same font and width the arms wrap at different y. A
stock-derived y applied to the host lands on a **different line**, and the failure would read
"hit-testing is broken" when the truth is "the line heights differ" — the most misleading red this
suite could produce.

So each point is derived from the arm it is applied to (`IDStockParity.pointInsideCharacter`), and
what is compared across arms is the **resolved character index**. The claim asserted is upstream's
real one — *a point inside character N's glyph resolves to N, and all three arms agree on N* —
expressed so it survives differing line boxes. This is **not** the weaker "each arm agrees with
itself": the index is still compared across arms.

### 4a — probes sit at 0.25 / 0.75 of a glyph, not 0.5

Upstream probes at **exactly** the glyph midpoint, where the two caret positions are equidistant and
"the closest position" is a tie-breaking *policy*, not a hit-test result. Measured 2026-08-26: stock
breaks that tie **upward** (the midpoint of character 35's glyph resolves to 36); both Telegram arms
break it **downward** (35).

A first draft probed at 0.5 and asserted that stock resolves to 35 — an assertion that is simply
false, was **mine and not upstream's**, and reported "the ORACLE moved" for a claim upstream never
makes. It is recorded here because it is exactly the kind of invented-oracle error this file exists
to make visible.

The tie is still tested, as its own test
(`test_closestPositionTieBreakingAtTheExactGlyphMidpoint`), compared across arms only, with no
oracle self-consistency claim — which is precisely upstream's claim there.

## Deviation 5 — the setUp scene

Upstream's `setUp` discovers an existing `UIWindowScene.keyWindow` with a `rootViewController` and
`XCTAssertNotNil`s both. A SwiftPM xctest bundle has no app delegate and therefore no such window,
so `IDStockParity.host(_:in:)` creates its own — the convention every other UIKit suite in this
target already uses (`IDKeyboardActivationTests.makeWindow`). It still attaches to a real
`UIWindowScene` when the process has one.

## Deviation 6 — a vacuity guard upstream does not have

Every probe returns a `<...>` placeholder when it cannot produce a reading
(`<closestPosition returned nil>`, `<no glyph geometry>`, …). Three arms that all decline compare
**equal** and would report a clean pass having measured nothing. `IDStockParity.assertField`
therefore fails any comparison where any arm produced a placeholder, tagged `[DECLINED]`, and the
"no selection" sentinel is deliberately spelled `(no selection)` rather than `<none>` so a real
reading never trips it.

---

## Dropped upstream assertions

**An undocumented divergence from upstream is worse than a missing test**, because a later reader
takes a ported test as upstream's own claim. Everything dropped is here.

### From `IDInlineFormattingStockOracleTests.m`

| Dropped | Where | Why |
| --- | --- | --- |
| every `snapshot:` dictionary `@"typing"` read | all 6 tests | `typingAttributes` is a `UITextView` member with no `UITextInput` counterpart; `-textStylingAtPosition:inDirection:` is `@optional` and unimplemented on `DocumentCanvasView`. Where upstream's claim was *observable through typed characters* it is re-expressed that way (tests 2 and 4 assert the typed character's traits instead); where it was only readable as a dictionary it is gone. |
| all FOUR `@"typing"` reads — `explicit`, `moved`, `returned`, `typed` | `testStockExplicitTypingOverrideMovementAndReturnAtEnd` | four specific instances of the above. **Task P1 recorded this as "two of five"; it is four of EIGHT** — corrected in Task P2 after re-deriving both numbers from upstream (`sed -n '/testStockExplicitTypingOverrideMovementAndReturnAtEnd/,/^}/p' IDInlineFormattingStockOracleTests.m \| grep -c XCTAssert` = 8, the same with `grep -c '@"typing"'` = 4). The four surviving assertions were always the same four; only the count was wrong. |
| `canUndo` / `canRedo` snapshot **fields** | `testStockUndoRedoRestoresFormattingAndTypingState` | the host's undo manager is injected (`undoManagerOverride`) and its grouping is the test's, not the view's; comparing the two managers' flags compares the harness to itself. `canUndo`/`canRedo` are still asserted **per arm as preconditions** — an arm that recorded nothing undoable would "restore" trivially and read as agreement. |
| `IDNormalizedInlineRuns(...)` **run-array** equality between snapshots | tests 5 and 6 | kept **verbatim on the stock arm**; re-expressed on the host arms as per-character trait names, because the host has no single `NSTextStorage` spanning the document. In test 5 the re-expression is **stronger** than upstream's (`traits == [["italic"]]` rather than `before != after`, which is trivially satisfiable) — recorded as a re-expression, not a loosening. |
| `IDNormalizedInlineRuns(...)[2][@"traits"] == @[]` | `testStockExplicitCaretToggleThenInsertAndReturn` (`IDInlineFormattingStockOracleTests.m:158-161`) | **Not dropped any more — PORTED in Task P2**, on the stock arm only, which is where a run-ARRAY read is expressible (it is derived from one `NSTextStorage`; the host has none spanning the document). Task P1 dropped it with no record at all; the P1 review caught the omission. It adds little over the per-character read beside it — the point is that it is now either ported or recorded, never silently absent, because an undocumented divergence is what a later reader mistakes for upstream's own claim. |
| upstream's `NSLog` of each snapshot | all 6 tests | a log, not an assertion. Nothing is lost. |

### From `IDBlockTouchSelectionParityTests.m`

| Dropped | Why |
| --- | --- |
| **`testTestOnlyLoupeSequenceMatchesStockSizeOffsetAndMovement` — the whole test** | Driving it needs an `objc_msgSend` cast to the private 6-argument `-loupeGestureWithState:location:translation:velocity:modifierFlags:shouldCancel:`, three of whose arguments are `CGPoint`-returning blocks and one an out-`BOOL *`. **Swift cannot form that call** — `objc_msgSend` is not callable through a `@convention(c)` cast in Swift — so the port needs an Objective-C shim, and this is a Swift-only test target (deviation 1). Assertions lost: the loupe's size vs stock's (±4pt), its offset from the caret (±2pt), and its movement delta (±2pt). Partial cover remains: `IDKeyboardActivationTests.test_theAppReachableInstallationStateHasEveryThunkLive` pins that the host publishes a non-nil `interactionAssistant` at all. **To restore it**, add one ObjC shim file exposing `IDSendTestLoupeGesture` to Swift; that is a new target, not an edit to the vendored harness. |
| `IDCaptureWindowScene` screenshots and their `XCTAssertTrue(image.CGImage != NULL)` | Upstream captures two window-scene images per arm and asserts only that they are non-null; the real assertions are on `_UITextMagnifiedGlassLoupeView` frames. Dropped with the test above. |
| upstream's merge of tests 1 and 2 into one fixture | **not a drop** — both upstream tests make the same claim at different probe indices, and both claims are asserted here (`test_closestPositionResolvesTheCharacterItsGlyphContains` covers upstream's index set; `test_closestPositionResolvesTheSameCharacterAfterARelayout` preserves upstream's separate re-frame-then-probe path, which is a genuinely different code path). |

### From `IDBlockSpellingIntegrationTests.m`

**One of twelve tests ported.** The one that matters:
`testMisspellingUsesNativeTemporaryPixelsAndCorrectionDropsBelowHalf` — the only end-to-end
assertion in the entire upstream corpus that would catch the user's open *"corrected words are not
underlined"* defect. All four of its claims are kept (marker appears; marker is NOT canonical
storage; correcting drops it below half; and — added here — the correction actually landed, without
which claim 3 passes trivially on an arm whose `replace` did nothing, which is exactly the failure
mode suite 1 found).

| Dropped | Why |
| --- | --- |
| `testAnnotationAnchorsRebaseAndHalfOpenRemovalSplitsLiveEntry`, `testCollapsedAnnotationIsRemovedAfterCanonicalReplacement`, `testMutationCompletionSynchronouslyPurgesCollapsedEntryAndReleasesValue`, `testWeakDocumentMutationObservationDoesNotRetainAnnotationStore`, `testAnnotatedSubstringStripsCanonicalShadowBeforeOverlayingAnnotation`, `testEmptyEndAndStructuralNewlineRangesCreateNoAnnotationEntries`, `testSameKeyOverlapsPreserveLatestLookupAndHalfOpenRemovalOrdering`, `testTextAlternativesDisplayStylePrivateKeyRoundTripsWithoutCanonicalStorage` | all eight assert directly on `IDRichTextAnnotationStore` — upstream **product source**, which Global Constraint 12 forbids porting. This port has no annotation store; the equivalent state lives in `TelegramAnnotationInputClient`, whose behaviour is covered by `IDTextEditorBackendClientBridgeCheckingAndAnnotationTests`. Note that the eighth is the one that pins `_NSTextAlternativesDisplayStyleAttributeName` carrying a **boxed integer** (`@1`) — that specific claim is NOT covered anywhere on this side and is the sharpest single gap this task leaves. |
| `testTemporaryPrivateWrappersPreserveExactKeyValueRangeAndRejectWrongCanvasABI` | tests upstream's own `IDPrivateRichAddTemporaryAttribute` / `…Remove` / `…Invalidate` wrapper functions and their canvas-ABI rejection. Those functions do not exist on this side (the export script strips `IDPrivateUIKit+RichTextLayout.*` as canvas-shaped). |
| `testStructuralNewlineInvalidationTargetsOnlyExactSecondBlockLocalRange`, `testCanonicalEditRefreshesOnlyAffectedBlockAndReplaysItsLiveTemporaryAttributes` | both reach into `IDBlockStackCanvasView` / `IDTextLayoutCanvasViewInternal` / `IDRichTextLayoutControllerInternal` to assert *which block's* temporary attributes were invalidated. Canvas-internal by construction; no `UITextInput` observable exists for "which block was invalidated". |
| `IDAttachSpellingObservation` XCTAttachment diagnostics | observability, not assertions. Every number they carried is in this port's failure messages instead. |

### Not ported at all (suites)

| Upstream suite | lines | tests | Status after Task P2 |
| --- | --- | --- | --- |
| `IDAutocorrectionDecisionContractTests.m` | 428 | **17** | **3 ported** (the atomicity group), 14 dropped. See the Task P2 section. Task P1's PROVENANCE said 13 tests; the real count is 17 (`grep -c '^- (void)test'`). |
| `IDBlockTextViewParityTests.m` | 969 | 15 | **10 ported**, 5 dropped. See the Task P2 section. |
| `IDFloatingCursorParityTests.m` | 846 | 12 | **re-expressed as 5 tests**, not ported. See the Task P2 section. |

## Why the third "zero-coupling" suite was not ported *(Task P1's reasoning — SUPERSEDED in part by Task P2, see below)*

The task brief's table records `IDAutocorrectionDecisionContractTests.m` as having **0
canvas/reference-backend imports**, which is true — and misleading. Its imports are
`IDBlockDocument.h`, `IDCanonicalTextStorageAdapter.h`, `IDCanonicalTextProjection.h`,
`IDRichTextAnchor.h`, `IDRichTextPosition.h`, plus `UITests/IDAutocorrectionDecisionTestSupport.h`.
Those are not the *canvas*, but they are upstream **product source**, which Global Constraint 12
forbids porting. Reading the file, its tests split three ways (**P1 counted 13; the file has 17**
— the corrected split is in the Task P2 section):

1. **One test is host behaviour and is portable** — `testAutocorrectionReplacementKeepsActiveSemanticTraits`
   (toggle bold, `insertText:`, `replaceRange:withText:`, assert the replacement is still bold).
2. **Seven tests certify upstream's own test scaffolding** — the 21-row decision matrix, the
   `IDParseAutocorrectionStatus` JSON schema parser and its rejection cases. Porting them would add
   seven guaranteed-green tests that assert nothing whatsoever about this port. That is manufactured
   green, and this programme has enough of it.
3. **Five tests assert on `IDCanonicalTextStorageAdapter` / `IDBlockDocument` internals** —
   `documentRevision`, `NSTextStorageDidProcessEditingNotification` counts, block-identifier
   stability. Re-expressible at the `UITextInput` level as replace-then-compare sequences, but the
   *atomicity* claims (one notification per correction) have no `UITextInput` observable and would
   have to be dropped, leaving thin text-equality tests.

Group 1's single claim is **already covered** by the ported inline-formatting suite (test 3 asserts
that a formatted selection's replacement inherits its formatting, and reports `PORT-DEFECT` on text
and `PRE-EXISTING` on traits). Porting the file to add group 1 and drop groups 2–3 would have been
one duplicate test and a large provenance surface. Recorded as a deliberate decision, not an
omission.

---

## Results at the time of writing (2026-08-26)

Run: `Scripts/iostest.sh RichTextEditorUIKitTests/<Class>`, iPhone 17 Pro K1.

| suite | tests | passing | failing | PORT-DEFECT | PRE-EXISTING |
| --- | --- | --- | --- | --- | --- |
| `IDInlineFormattingStockOracleParityTests` | 7 | 1 | 6 | 8 assertions | 3 assertions |
| `IDBlockTouchSelectionParityTests` | 6 | 5 | 1 | 0 | 1 assertion |
| `IDBlockSpellingIntegrationParityTests` | 2 | 1 | 0 | — | — (1 **skipped, NOT CERTIFIED**) |

**The split is the finding.** Suite 2 is read-only (hit-testing, tokenizer granularity, composed
clusters, taps below content) and is almost entirely clean. Suite 1 is mutating (insert, delete,
replace, undo) and is almost entirely broken. The InputDec backend's **reads are right and its writes
are wrong.**

Every `PORT-DEFECT` in suite 1 is one story — an InputDec caret mutation lands wrong:

| scenario | stock / legacy | inputDec |
| --- | --- | --- |
| caret at document end, one backspace | `"a"` | `"ab"` (no-op) |
| caret at document end, insert `"X"` | `"abX"` | `"XXa"` |
| caret 1 of `"ab"`, insert `"X"` | `"aXb"` | `"aXX"` |
| select `{1,2}` of `"abcd"`, insert `"Z"` | `"aZd"` | `"aZ"` |
| backspace at caret 1 of `"ab"` | `"b"` | `""` |

plus a kernel witness failure on any scenario containing a Return:
`synchronizeAfterExternalChange: revision continuity violated — change describes oldRevision 3 →
newRevision 3, but this backend has adopted 5 — not adopted`.

`"XXa"` from a single `insertText` at what should be the document end is the sharpest of these: it
implicates `documentEndOffset` (`LegacyTextIdentity.globalOffset(of: endOfDocument)`) returning nil
for an ID-minted position, which is the same identity-mismatch family as the Task F1 caret crash.

The `PRE-EXISTING` rows are a different, older story: **the editor has no collapsed-caret typing
attributes at all.** `DocumentCanvasView+CharacterFormat.swift` states it outright — *"A collapsed
caret is a no-op (collapsed typing attributes are deferred)"* — so toggling bold at a caret and then
typing produces unformatted text on **both** Telegram backends. Stock `UITextView` has done this
since iOS 2. It is not an InputDec regression and must not be billed to the port.


---

## The spelling suite certifies NOTHING, and that is its finding

`IDBlockSpellingIntegrationParityTests` reports 1 passing, 0 failing, **1 skipped**. The skip is not
a convenience and must not be read as a pass.

**Stock `UITextView` paints zero misspelling-marker pixels in a SwiftPM xctest process.** With no
oracle there is nothing to certify either Telegram backend against, and three arms all reading zero
would compare *equal* and report a clean pass having measured nothing — so the test declines instead.

Two instrument bugs had to be fixed before that conclusion could be trusted, and both are recorded
because either one would have produced the same "environment limitation" verdict falsely:

1. **`drawHierarchy(in:afterScreenUpdates: true)` renders nothing** for a view whose window is not
   actually on screen — which is every window in an xctest process. It returned zero red pixels for
   a *known* red underline. Replaced with `layer.render(in:)`.
2. **The marker band was too tight.** A 10pt strip under `firstRect(for:)`'s bottom edge misses a
   marker drawn below the reported line box. Widened to the full line box plus 6pt.

`test_0_calibrationTheRedPixelCounterSeesAKnownRedUnderline` now applies a red underline through
public `NSAttributedString` attributes — no spell checker involved — and requires the counter to find
it. It **passes**, and it separates the two failure modes explicitly (`BLANK RENDER` vs
`RED PREDICATE`). Only because it passes can the skip be attributed to the environment.

**Consequence for the programme, stated plainly:** the user's open *"corrected words are not
underlined"* defect has no automated oracle in this test process and cannot acquire one here. It
needs either a device/app-hosted test target where UIKit will run the system text checker, or an
assertion further up the pipeline (e.g. that the host receives
`_NSTextAlternativesDisplayStyleAttributeName` with a boxed integer and forwards it as a temporary
rendering attribute) — which is the claim upstream's dropped
`testTextAlternativesDisplayStylePrivateKeyRoundTripsWithoutCanonicalStorage` makes, and the sharpest
single gap this task leaves.

---
---

# TASK P2 — the support layer, the substitution seam, and four more suites

Same upstream repo and commit as above (`/Users/isaac/Documents/InputDec` @
`fdad9ca519f5f27a07362e00dc6cefdcb73ca369`, 2026-08-24). Ported 2026-08-26 on iPhone 17 Pro K1
(`CA0A2186-0F4A-425B-B3B1-9B61E5FF01A9`).

Task P1 hand-adapted three suites and hit two walls: each suite needed bespoke adaptation, and
1,815 upstream lines were never reached. Task P2 removes the first wall by porting the SUPPORT
LAYER and building the substitution seam upstream's suites are written against, then uses it to
reach the rest.

**Every count in this section was derived with a command at the time of writing, not carried
forward from a report.** Task P1 propagated two wrong counts and this task's own brief inherited
one of them; the commands are shown inline so the next reader can re-run them.

## The substitution seam

Upstream obtains every parity subject through one pair
(`IDBlockTouchSelectionParityTests.m:117,149`):

```objc
- (UIWindow *)hostCustom:(IDBlockTextView *)custom stock:(UITextView *)stock;
- (void)makeCustom:(IDBlockTextView * __strong *)customResult stock:(UITextView * __strong *)stockResult;
```

Every suite then works against a `custom` and a `stock`. Porting a suite is only mechanical if the
port has the same pair, so `IDStockParityHarness.swift` now provides it with **Telegram's editor
substituted for `IDBlockTextView`**:

| type | role |
| --- | --- |
| `IDParityArm` | `.stock` / `.inputDec` / `.legacy` |
| `IDParitySubject` | one arm in the SAME shape whatever is behind it — `.view`, `.input` (a `UITextInput`), `.editor` / `.stock` for arm-specific reach-throughs |
| `IDParityFixture` | blocks + font + insets + arm size: one description, three constructions |
| `IDParityArms` | the three subjects, `.each` / `.eachInput`, `.focus(_:)` / `.unfocusAll()` |
| `IDStockParity.makeArms(_:in:)` | upstream's `makeCustom:stock:` + `hostCustom:stock:` |
| `IDStockParity.makeSubject(_:_:in:focused:)` | ONE arm, for suites that need a fresh subject per scenario |

### Deviation P2-1 — arms are hosted side by side in ONE window

Upstream's `hostCustom:stock:` puts both arms in a single `UIWindow` on a real `UIWindowScene`.
Task P1 gave each arm its own window. `makeArms` restores upstream's shape, and it is not cosmetic:
a loupe is presented into the SCENE and `IDWaitForLoupeInScene` scans every window of it, so with
arms in separate windows you cannot tell whose loupe you measured; and first-responder handoff
between arms (which `focus(_:)` performs, mirroring upstream's `custom.hidden = YES` discipline) is
only meaningful inside one key window.

Re-pointing `IDBlockTouchSelectionParityTests` onto it changed **no result**: still 5 passing, 1
failing, and the failure is the same `[PRE-EXISTING]` tie-break at the exact glyph midpoint.

### Deviation P2-2 — `makeSubject` exists alongside `makeArms`, and mixing them up is a real trap

The mutating suites cannot share one fixture: `IDInlineFormattingStockOracleParityTests`'s
calibration deliberately builds **two same-backend editors** so the second is not looking at the
first's mutation. Sharing them would silently gut the test.

There is a second reason, less obvious: constructing an `.inputDec` editor **attaches the kernel**,
so an arm built and never used can still push entries into the shared `ViolationLog` and turn
another arm's `assertNoKernelFailures` red for something that never ran. `makeSubject` builds
exactly the arm asked for.

## Per-file origin — the support layer (`Tests/StockParitySupport/`)

A new Objective-C SwiftPM target, `RichTextEditorStockParitySupport`, deliberately separate from
`Tests/DifferentialSupport` (which is PROVENANCE-governed as a byte-for-byte vendoring and must not
absorb new files).

| This directory | Upstream origin | upstream md5 | upstream lines | approach |
| --- | --- | --- | --- | --- |
| `include/IDStockParityPixels.h` | `Tests/IDTextCanvasTestSupport.h` | `54e63ef36ef86662b1c0210f1cc88903` | 26 | verbatim minus `IDTextCanvasFixture` |
| `IDStockParityPixels.m` | `Tests/IDTextCanvasTestSupport.m` | `1d95f3648c1d24a9e2a3eec1d9a52240` | 171 | verbatim from `IDWaitForCondition` down |
| `include/IDSpellingReadinessProbe.h` | `Tests/IDSpellingReadinessProbe.h` | `6327dfcf4158fd8902e4cd32b82eb3ec` | 129 | verbatim + 3 declarations under ONE fenced pragma (1 new function, 2 upstream file-statics given external linkage) |
| `IDSpellingReadinessProbe.m` | `Tests/IDSpellingReadinessProbe.m` | `9b9a0b0017a07d2ed1c694f3ed1d7612` | 1083 | verbatim + 4 mechanical edits (below) |
| `include/IDRichTextLayoutControllerContractProbe.h` | same name | `108f3fbc31980a41801e16cfa155295f` | 12 | verbatim |
| `IDRichTextLayoutControllerContractProbe.m` | same name | `bcb96460180b63683ce82ec7947aec7f` | 37 | verbatim |
| `include/IDStockParityLoupe.h` + `.m` | the file-statics atop `Tests/IDBlockTouchSelectionParityTests.m:1-88` | `9afe427f983ac66f7d81d68fc76753e8` | 444 (whole file) | bodies verbatim, given external linkage |
| `include/IDStockParityRuntime.h` + `.m` | — | — | — | **telegram-authored**, not vendored |

### Why the support layer is Objective-C

Two independent forced reasons, either sufficient:

1. `IDSpellingReadinessProbe.m` is 1,083 upstream lines that swizzle the private
   `UITextInputController` / `UITextCheckingController` through `method_setImplementation` and call
   originals through raw `IMP` casts. Transliterating it to Swift would destroy the one property
   that makes it an oracle — that it was not written by us.
2. Several parity assertions need an `objc_msgSend` cast Swift **cannot form at all**. The private
   `-loupeGestureWithState:location:translation:velocity:modifierFlags:shouldCancel:` takes three
   `CGPoint`-returning blocks and an out-`BOOL *`. Task P1 had to DROP a whole upstream test for
   exactly this.

### The four edits to `IDSpellingReadinessProbe.m`

1. `#import "IDTextCanvasTestSupport.h"` → `#import "IDStockParityPixels.h"`.
2. file-static `IDTemporaryRenderingRanges` → exported `IDStockTemporaryRenderingRanges`.
3. file-static `IDRunMainRunLoopForInterval` → exported, same name.
4. one appended function, `IDObserveSpellingLifecycleWithStimulus`, fenced under a
   `TELEGRAM ADDITION` pragma. It exists because upstream's lifecycle entry point takes a
   `UITextView *` and reads `editor.textLayoutManager`, which Telegram's host does not have — while
   the *hooks* are class-level swizzles on private UIKit classes and observe the checking pipeline
   whatever drives it.

No upstream body is otherwise altered.

### Dropped from the support layer

| Dropped | Why |
| --- | --- |
| `IDTextCanvasFixture` (`IDTextCanvasTestSupport.{h,m}`) | its designated initializer builds an `IDTextLayoutCanvasView` — upstream **product source**, which Global Constraint 12 forbids porting. Everything else in that file touches no product source. |
| `Tests/Fixtures/*.json` (8 files) | the brief lists them as "authorization fixtures several suites need", and that is true of suites this task does not port. Derived, not assumed: `grep -rln 'Fixtures\|SelectionCallbackAuthorization\|UIKitBehaviorTestOnlyContracts' Tests/*.m` names ten upstream suites, and **not one of them is a suite ported by P1 or P2**. Nothing in this directory reads a fixture, so vendoring them would add eight unreferenced resources and a provenance surface to keep in sync. |
| `IDBlockTextTestSupport.{h,m}` | 3 functions. `IDBlockTextTestDocument` builds an `IDBlockDocument` (product source). The other two are a 2-key attribute dictionary and an `NSAttributedString` convenience that `IDStockParity.makeStock` / `makeHost` already express in Telegram's own vocabulary. Porting them would add a second spelling of the same fixture. |

### Ported symbols with NO caller yet — recorded, not silently carried

Derived with
`for sym in …; do grep -rl "$sym" Tests/RichTextEditorUIKitTests --include='*.swift' | wc -l; done`
after fix round 1:

| symbol | callers | why it is carried anyway |
| --- | --- | --- |
| `IDRichTextLayoutControllerContractProbe` (whole file) | **0** | the task brief lists it explicitly in the support layer to port. It is a generic `NSProxy` selector recorder and it is the right instrument for the class of question Task H1 had to answer by runtime measurement (`setDelegate:` interrogating its delegate once and caching the answers). Carried deliberately, unused today. |
| `IDCountNontransparentPixels`, `IDRedPixelCountsByRow` | **0** | part of upstream's `IDTextCanvasTestSupport.m`, ported as one body. Deleting two functions out of a file whose value is that it is verbatim would trade a real property for a cosmetic one. `IDCountRedPixels` (same file, same predicate) IS in use. |
| `IDSpellingInputModeLease` + `IDSpellingInputModeDriving` | **0** | the brief lists the lease as the highest-value item, and the *finding* about it (upstream ships no real driver) is only checkable because the type is here to look at. |

Everything else the support layer exports now has a Swift caller. Three symbols that did not at the
end of the first round do now: `IDObserveSpellingLifecycleWithStimulus` — the ONE Telegram-authored
addition to the probe — drives
`IDBlockSpellingIntegrationParityTests.test_whichStepOfTheCheckingPipelineTheHostArmsReach`, which is
what localised the InputDec spelling defect to delivery rather than driving;
`IDHasCurrentInputMode` and `IDIsContinuousSpellCheckingEnabled` are in the diagnostics of the
oracle-feasibility and lifecycle tests respectively.

### `IDSpellingInputModeLease` — ported, and a caveat worth recording

The lease and its `IDSpellingInputModeDriving` protocol are ported verbatim. **Upstream ships no
real implementation of that protocol.** `grep -rn IDSpellingInputModeDriving Tests/ UITests/` in the
upstream tree returns the protocol declaration, the lease's own uses, and ONE fake inside
`IDSpellingReadinessProbeTests.m`. So the lease is a fully-tested state machine with no production
driver behind it — it does not, by itself, make a keyboard speak en-US, and the task brief's
expectation that it "forces English-US" is true only of a driver nobody has written.

It is moot here anyway: `IDCurrentInputModePrimaryLanguage()` already reports `"en-US"` in this
process (`IDSpellingOracleFeasibilityTests` step 1 asserts it).

## The spelling oracle — measured, not argued

`IDSpellingOracleFeasibilityTests.swift` (**written here**, not vendored; 6 tests, all passing) runs
upstream's probe unmodified in this process and reports every intermediate the classifier consults.
The answer is in the Task P2 report; the file records it in assertions so a change is caught.

Three measurement facts are encoded at their sites because each one, omitted, silently turns a
spelling test into a vacuous skip:

* **Sample after `ensureLayoutForBounds`.** TextKit 2 rendering attributes are populated by layout;
  sampling early reads empty. Same class as P1's `drawHierarchy` bug.
* **Warm up first.** The FIRST text view driven in a fresh process is never annotated — the checker
  loads asynchronously. This is exactly why upstream's own probe types a warm-up word
  (`warmupWord = @"mispelled"`) and measures a second one (`measuredWord = @"wrng"`).
* **The host arms need a caret move.** Both editors' checkers are selection-driven. On stock, typing
  the trailing space suffices. On the host arms a programmatic `insertText` through this harness
  does not reach `nativeCheckOnSelectionChange`: measured, BOTH host arms flag nothing after typing
  alone, and Legacy flags `{0, 9}` as soon as the caret moves past the word. They are therefore
  driven the way the in-tree `NativeTextCheckingLiveTests` drives them.

**Deviation P2-3 — the two arms answer the same predicate through different mechanisms.** The stock
arm's annotation is read from TextKit 2 rendering attributes; the host arms' from
`DocumentCanvasView.spellResults`, the side table `TelegramAnnotationInputClient.addAnnotation`
writes into. A `DocumentCanvasView` has no `NSTextLayoutManager` spanning the document, so there is
no shared mechanism. What is compared is the predicate — *is this word flagged as a transient
annotation?* — which is what the pixel test compared when a pixel was available.

## Per-file origin — the suites

| This directory | Upstream origin | upstream md5 | upstream lines / tests | ported |
| --- | --- | --- | --- | --- |
| `IDBlockTextViewParityTests.swift` | `Tests/IDBlockTextViewParityTests.m` | `4392211559ef060ea6b1f6157cb3c33b` | 969 / 15 | 10 |
| `IDFloatingCursorParityTests.swift` | `Tests/IDFloatingCursorParityTests.m` | `66a523ff4bd5669b3f201a0dd0e71824` | 846 / 12 | **0 — re-expressed as 5** |
| `IDAutocorrectionDecisionContractTests.swift` | `Tests/IDAutocorrectionDecisionContractTests.m` | `58e914ce4270d377b2a48cd12c05f47a` | 428 / 17 | 3 |
| `IDSpellingOracleFeasibilityTests.swift` | — | — | — | **written here** |

### Deviation P2-4 — vertical geometry is a LINE INDEX, horizontal is DISTANCE FROM THE LINE START

`IDBlockTextViewParityTests` upstream compares caret and selection rect ORIGINS at 1.0pt tolerance,
y included, because both of its arms are TextKit-shaped. Telegram's are not: `BlockLayoutEngine`
pins every paragraph's line box while stock uses the font's natural leading, so the arms wrap at
different y and their line boxes differ in height. A verbatim y comparison fails on line metrics and
reads as "caret geometry is broken" — P1 deviation 4 records the same decision for the touch suite.

So the swept quantity is the **rank of the caret's line among that arm's own distinct lines**, and
the **distance from the leftmost caret on that line** (which cancels each arm's own
`textContainerInset` and `lineFragmentPadding`). Both are compared ACROSS arms. What is genuinely
lost is absolute rect equality.

**A sub-deviation worth its own paragraph, because it produced a false red.** The first draft
expressed the horizontal tolerance by BUCKETING each measurement into a string and comparing
strings. A value a hundredth of a point either side of a bucket edge then reported a full-bucket
divergence, indistinguishable in the failure message from a real 1.5pt difference — and the caret
sweep failed that way. `IDStockParity.assertNumericArms` now compares element by element at
upstream's own 1.0pt tolerance, and the sweep passes. (An earlier wording claimed this was TIGHTER than the bucket it replaced; that is unverifiable from the history — the bucket was never committed — so the claim is withdrawn rather than restated.)

### Deviation P2-5 — one field per claim, never a composite string

`IDBlockTextViewParityTests`'s responder-loss test first reported one composite reading per arm. Any
single divergence then tainted every claim in it, and the classifier reported `PRE-EXISTING` for all
five claims because two host arms share ONE difference from stock (`resignFirstResponder()`'s return
value). Split per claim, the InputDec arm's double-commit of marked text is correctly billed
`PORT-DEFECT`. A composite reading is a classifier bug waiting to happen.

### Deviation P2-6 — `assertAgainstControl`, for when the oracle provably is not answering

A stock `UITextView` resolves EVERY programmatic `updateFloatingCursor(at:)` to the same offset —
the document end. It does not respond to that call outside a real gesture in this process. A first
run of the floating-cursor suite compared against it and reported `PRE-EXISTING` for all three
drags, billing a real InputDec regression to "the editor never matched stock here".

`IDStockParity.assertAgainstControl` makes the weaker claim explicit at every call site: it compares
InputDec against the SHIPPING Legacy backend only and says the port **changed** the behaviour, never
which behaviour is correct. Each drag test asserts it FIRST and unconditionally, then declines the
three-arm comparison with an `XCTSkip` carrying the stock reading as evidence. Throwing the whole
comparison away because stock is silent would have thrown away the finding with it.

It must never be used where stock can answer.

## Dropped — `IDBlockTextViewParityTests.m` (5 of 15 tests)

| Dropped | Why |
| --- | --- |
| `testReferenceBackendUsesMarkerFreeProjectSurfaces` | asserts on upstream's REFERENCE BACKEND, which Global Constraint 12 explicitly names as un-portable. |
| `testPublicLiveRangeRebasesWhileNativeSnapshotRangeStaysAtOriginalOffsets` | drives `-id_nativeRangeForCanonicalRange:` on `IDRichTextLayoutController` (product source) and compares `IDRichTextRange` snapshots. No `UITextInput` observable. |
| `testNativeStructuralSplitMergeAndUndoPreserveRichAttributeRuns` | builds an `IDBlockDocument` with a custom `NSAttributedStringKey` and reads run arrays back off `IDCanonicalTextStorageAdapter`. Product source both ends. |
| `testNativeSpellingPixelCountsMatchStockInCanonicalWordROI` | the pixel oracle is unavailable in this process (`IDSpellingOracleFeasibilityTests` step 3 measures it, and asserts the zero so a future OS that paints the marker fails the test). The claim it protects is covered instead by `IDBlockSpellingIntegrationParityTests.test_theAnnotationOracleFlagsAMisspellingAndClearsItOnCorrection`, through the annotation oracle. |
| `testPointHitsNeverReturnInsideComposedCharacterCluster` | **duplicate.** `IDBlockTouchSelectionParityTests.test_closestPositionNeverLandsInsideAComposedCluster` (Task P1) already ports the same claim, on a 👨‍👩‍👧‍👦 rather than a 👩🏽‍💻. Porting it again would add a second red for one defect. |

### Dropped assertions inside the 10 that ARE ported

| Dropped | Where | Why |
| --- | --- | --- |
| absolute caret / selection rect ORIGIN equality (1.0pt) | tests 1, 2, 3, 5, 7 | deviation P2-4. Replaced by line index + line-relative x, both compared across arms. |
| collapsed-rect WIDTH (±0.5) and HEIGHT (±1.0) | test 2 | the height IS the pinned line box this port cannot compare; the width of a collapsed rect is the caret width, which follows it. The flags and the count — upstream's real claims there — are kept verbatim. |
| `adjustedContentInset` / `contentOffset` equality | test 4 | compares two `UIScrollView`s. `RichTextEditorView` is a plain `UIView` hosting a canvas; there is no scroll view to read. |
| `undoManager.canUndo` cross-arm equality | test 11 | the host's undo manager is injected and its grouping is the harness's, so comparing the two managers compares the harness to itself. Same reasoning P1 recorded for the inline-formatting suite. |

## Dropped — `IDFloatingCursorParityTests.m` (12 of 12 tests; re-expressed as 5)

**This file is a re-expression, not a port, and says so at the top of the Swift file.** All 12
upstream tests reach the floating cursor through `custom.id_richLayoutController` (an
`IDRichTextLayoutController` — product source) and compare it against stock's private
`_internalTextLayoutController` through selectors like `cursorPositionAtPoint:inContainer:`,
`positionWithOffset:affinity:`, `affinityForPosition:` and
`visualSelectionRangeForExtent:point:inContainer:affinity:`. Telegram's host has neither object: it
routes the three public `UITextInput` entry points one line into the input backend.

So there is nothing on this side those assertions could be pointed at, and the constraint forbids
porting the object upstream uses. The 5 tests here assert upstream's CLAIMS — where a drag lands,
that a drag never mutates the document, how a structural boundary and an RTL run are crossed —
through `beginFloatingCursor(at:)` / `updateFloatingCursor(at:)` / `endFloatingCursor()`.

**What is NOT covered, stated plainly rather than implied:** every affinity comparison
(`affinityForPosition:` at each stop), and all of upstream's container-local point arithmetic.
Derived with `awk '/^- \(void\)test/{n=$0} /<selector>/{if(n!=l){print n; l=n}}'` over
`IDFloatingCursorParityTests.m`, not from memory:

| private selector | tests |
| --- | --- |
| `cursorPositionAtPoint:inContainer:` | **2** — `…ControllerConsumesContainerLocalPointsWithoutViewConversion` (:512), `…ControllerLocalPointDoesNotSubtractHorizontalInsetOrigin` (:621) |
| `affinityForPosition:` | **4** — `testSelectionExtensionCapturedHorizontalPointsMatchPositionAffinityAndGeometry` (:202), `…StructuralBoundaryCapturedVerticalPointsMatchStock` (:306), `testRichVisualSelectionNeutralCasesMatchStockWithoutMutatingDocument` (:412), `…MixedBiDiVisualSelectionUsesPointDerivedExtentAndAnchor` (:686) |

An earlier version of this paragraph said "four upstream tests are about that arithmetic
specifically" and then listed the affinity test among them. Wrong grouping, right conclusion: all 12
are declared dropped either way, so nothing was over-claimed as covered.

One test here (`test_unbalancedFloatingCursorCallsDoNotCrashOrMutate`) is **not upstream at all**
and is labelled as an addition. Upstream never drives the entry points out of order because its own
controller owns the sequencing; Telegram's host does not, and
`DocumentCanvasView+FloatingCursor.swift`'s own header records that the OS does not always deliver
`endFloatingCursor` (naming resign-first-responder and removal-from-window).

The three floating-cursor methods are `@optional` on `UITextInput`. An arm that did not implement
them would make every drag a silent no-op, and three no-ops compare EQUAL and pass — so a nil method
produces a `<...>` reading and trips the vacuity guard.

## Dropped — `IDAutocorrectionDecisionContractTests.m` (14 of 17 tests)

Task P1 declined the whole file. Its reasoning survives for 14 of the 17, re-derived here:

| group | count | ported? |
| --- | --- | --- |
| host behaviour (`testAutocorrectionReplacementKeepsActiveSemanticTraits`) | 1 | no — already covered by `IDInlineFormattingStockOracleParityTests` test 3 |
| upstream's own test scaffolding: the 21-row decision matrix and its row selection, the `IDParseAutocorrectionStatus` JSON schema and its five rejection cases, the candidate-absence error policy, the ordinary-prediction classification | 11 | no — they certify upstream's harness, not this port. Eleven guaranteed-green tests asserting nothing about Telegram is manufactured green. |
| correction ATOMICITY around a structural boundary | 5 | **3 ported** |

P1 under-weighted the atomicity group. Its claim — a correction replaces EXACTLY its token, leaves
the block structure intact, and rebases a caret sitting after it by the length delta — is precisely
the family where the InputDec backend has already been caught failing three separate ways. All three
ported members fail as `PORT-DEFECT`.

The two atomicity tests NOT ported
(`testDelimiterCommitThenImmediateDeletesStayOrderedAcrossBlockBoundaries`,
`testCandidateCommitThenOrdinaryDeletesRemainControllerIndependent`) drive upstream's
`IDAutocorrectionDecisionTestSupport` candidate machinery, which does not exist on this side.

**Dropped assertions inside the three that ARE ported:** upstream's `documentRevision == 1` and its
exactly-one-`NSTextStorageDidProcessEditingNotification` — the literal "in ONE transaction" half.
Both read `IDCanonicalTextStorageAdapter` / `IDBlockDocument` (product source) and neither has a
`UITextInput` observable. Kept is the observable consequence (exact text, intact structure,
correctly rebased caret) — what a user would notice; dropped is the transaction count — what a
profiler would.

## Results at the time of writing (2026-08-26, iPhone 17 Pro K1)

Every number below is read from an `Executed N tests` line and the per-test `passed`/`failed`/
`skipped` output of a targeted `Scripts/iostest.sh` run.

| suite | tests | passing | failing | skipped | PORT-DEFECT | PRE-EXISTING | vs-LEGACY | DECLINED |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `IDStockParityHarnessSelfTests` | 4 | 4 | 0 | 0 | — | — | — | — |
| `IDSpellingOracleFeasibilityTests` | 6 | 6 | 0 | 0 | — | — | — | — |
| `IDBlockTouchSelectionParityTests` | 7 | 5 | 1 | 1 | 0 | 1 | — | 0 |
| `IDInlineFormattingStockOracleParityTests` | 7 | 1 | 6 | 0 | 8 | 3 | — | 0 |
| `IDBlockSpellingIntegrationParityTests` | 4 | 2 | 1 | 1 | 2 | 1 | — | 1 |
| `IDBlockTextViewParityTests` | 10 | 6 | 4 | 0 | 2 | 3 | — | 0 |
| `IDFloatingCursorParityTests` | 5 | 2 | 3 | 3 | — | — | 3 | 0 |
| `IDAutocorrectionDecisionContractTests` | 3 | 0 | 3 | 0 | 5 | 0 | — | 0 |
| **total** | **46** | **26** | **18** | **5** | **17** | **8** | **3** | **1** |

### Fix round 1 — what the P2 review changed, and what it did NOT

Three Major defects, all in the instrument rather than in a finding:

1. **`IDBlockTouchSelectionParityTests`'s loupe presence claim hardcoded one arm to the literal
   `"true"`** — the only place in the harness where a verdict input was not a live reading. It
   misclassified in both directions: two failing host arms billed `PORT-DEFECT` (the hardcoded legacy
   `"true"` hid that Legacy failed too), and a legacy-only absence computed `.portImprovement`, which
   `assertField` did not fail on at all. Both host arms are now measured before anything is
   classified and the claim is one assertion over three live readings.
2. **The stock arm's claim-3 spelling reading was sampled after it lost first responder.**
   `makeSubject(focused: true)` asserts `becomeFirstResponder()`, which necessarily resigns the
   previous holder, and `IDStockParityRuntime.h` states that the checker does not run for a resigned
   view. The correction and its re-sample now happen BEFORE the calibration subject is built, and two
   guards assert the invariant (`isFirstResponder`, and that the correction actually landed) instead
   of assuming it. **The verdict did not change:** stock still clears the marker, Legacy still does
   not, so `[PRE-EXISTING] still flagged after correction` stands — now on a reading that is checked
   rather than trusted.
3. **The `<…>` vacuity guard was prefix/suffix-anchored and composed readings bypassed it.** See
   deviation P2-7.

`.portImprovement` also no longer falls through an `if`: `assertField` switches exhaustively over all
four verdicts, and port-improvement records an activity (it must not FAIL — InputDec agrees with the
oracle — but it must not be silent either, because it means the shipping backend diverges).

### Deviation P2-7 — declines are minted, and detected ANYWHERE in a reading

The vacuity guard is the property that makes a three-arm harness trustworthy, and it had a real
bypass. It matched `value.hasPrefix("<") && value.hasSuffix(">")` — a whole-value sentinel — while
`IDFloatingCursorParityTests` and `IDBlockTextViewParityTests` compose a reading from per-element
tokens. A decline for one element landed mid-string, the guard never fired, and three arms that all
failed at the same element compared EQUAL and passed having measured nothing at that element.

Every probe now mints declines through `IDStockParity.decline(_:)`, which wraps the reason in a
marker (`⟪DECLINED: …⟫`) that cannot occur in any reading this harness produces, and
`IDStockParity.isDeclined(_:)` searches for it anywhere in the value. **60** decline sites were migrated
(derived, not asserted: `git show 7c8e24fb2f -- '*.swift' | grep -cE '^\+.*IDStockParity\.decline\('`
= 60 added, 0 removed. Two earlier figures for this same sentence — 56 in the report and 57 in
review — were both wrong, in different directions; a third near-miss came from counting current
call sites instead of migrated ones, which is a different measurement than the sentence claims.)
mechanically across the five suites. The original whole-value `<…>` shape is STILL honoured, so a
site added later by hand is still caught.

Scanning for a bare `<…>` anywhere was deliberately rejected: readings embed
`String.debugDescription` of document text, and a fixture containing angle brackets would then be
permanently unable to assert anything. `IDStockParityHarnessSelfTests.test_3` pins that.

**`IDStockParityHarnessSelfTests` is new and exists for this.** `test_2` is the bypass written as a
test. Verified by reverting `isDeclined` to the old prefix/suffix form and re-running: 3 failures
under the old guard, 0 under the current one.

The three `IDFloatingCursorParityTests` skips are the same three tests that failed: each asserts its
control comparison, then declines the three-arm comparison because the oracle is silent (deviation
P2-6). A skip after a failure still records the failure.
