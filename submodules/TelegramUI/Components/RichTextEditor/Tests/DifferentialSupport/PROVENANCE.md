# `Tests/DifferentialSupport/` — what is vendored, and what must never be edited

Phase 0b's differential-corpus oracle. Half of this directory is **vendored byte-for-byte** from a
separate codebase; the other half is written here. The split is the whole point, so it is recorded
at the site rather than only in the plan.

## Vendored verbatim — DO NOT EDIT, DO NOT REFORMAT, DO NOT FIX WARNINGS

Source: `/Users/isaac/Documents/InputDec` (read-only; copied 2026-08-23, Task 9a).

| Vendored path | Origin | md5 |
| --- | --- | --- |
| `include/IDTextInputScenario.h` | `Tests/TextInputDifferential/IDTextInputScenario.h` | `eec20a3bed636fdab416ddc39560f6af` |
| `include/IDTextInputDifferentialRunner.h` | `Tests/TextInputDifferential/IDTextInputDifferentialRunner.h` | `7a0220070f14cfefc60a0304b1e508c4` |
| `include/IDTextInputTestHost.h` | `Tests/TextInputDifferential/IDTextInputTestHost.h` | `016d56bcfa552474d5b7f58c20cd2403` |
| `include/IDTextInputStateRecorder.h` | `Tests/TextInputDifferential/IDTextInputStateRecorder.h` | `ee49e824499388cc57d97c1c7f310413` |
| `include/IDTextInputTransactionDriver.h` | `Tests/TextInputDifferential/IDTextInputTransactionDriver.h` | `8716a8495b9111c09f3e2f10bf50b767` |
| `IDTextInputScenario.m` | `Tests/TextInputDifferential/IDTextInputScenario.m` | `a6038e5c6db4308e67fbb72e4520cb43` |
| `IDTextInputDifferentialRunner.m` | `Tests/TextInputDifferential/IDTextInputDifferentialRunner.m` | `18263950aefe118d86e6d56d14333975` |
| `TextInputScenarios/ime-ios26.5-v1.json` | `TestFixtures/TextInputScenarios/…` | `364c5d26054f1afc42d0b241b1c1608f` |
| `TextInputScenarios/autocorrection-ios26.5-v1.json` | `TestFixtures/TextInputScenarios/…` | `823c9115df101e67a41ced50e9deeb63` |
| `TextInputScenarios/inline-formatting-ios26.5-v1.json` | `TestFixtures/TextInputScenarios/…` | `ef713738906b13233114387e1b1e1345` |
| `TextInputScenarios/inline-prediction-ios26.5-v1.json` | `TestFixtures/TextInputScenarios/…` | `aa0b7e7194b871ebec9d3b66aa5437f2` |

**An edited vendored file is no longer an oracle.** The only property that makes this corpus worth
carrying is that neither it nor its decoder was written against our editor. Re-verify with
`md5 -q` against the origin before trusting a differential result; re-vendoring means recopying and
updating this table, never patching in place.

## Written here — the three host-specific pieces (Tasks 9b, 9c, 9d)

`IDTextInputTestHost.m`, `IDTextInputStateRecorder.m` and `IDTextInputTransactionDriver.m` are
**not** vendored, and that is deliberate. Their InputDec originals are coupled to InputDec's own
editor (4 / 9 / 3 references to `IDBlockTextView` and friends, measured 2026-08-23), and the
coupling branches on `kind != IDTextInputHostKindStock` — so a new Telegram host kind would fall
into the *existing* non-stock path and be force-cast to an InputDec type. The five headers are
coupling-free (0 hits each), which is what makes the split buildable: vendor every `.h`, vendor the
two neutral `.m`, write the three coupled `.m` against the same `@interface`s.

Accepted consequence, recorded so it is not forgotten: the comparison then runs on *our* sampling
code. The oracle stays independent of the **editor** but is no longer independent of **us**. The
corpus — 68 scenarios / 612 transactions of real IME, autocorrection, inline-prediction and
inline-formatting sequences captured against stock UIKit — remains the genuinely independent asset.

## Two limitations that travel with this corpus

1. **Telegram has no single `NSTextStorage`.** `DocumentCanvasView` is block-structured with
   per-leaf-region layout, so the storage-dependent comparison fields (`blocks`, `inlineRuns`) are
   declined under the legacy backend. A declined field must be **absent** from the snapshot, never
   defaulted — a defaulted field is a false comparison, which is worse than a missing one.
   **Task 9b resolved this concretely; see "The `observedTextStorage` decision" below.**
2. **The corpus's provenance is iOS 26.5 / 23F73**, and `IDLoadTextInputScenarios` hard-rejects any
   other runtime string. The runner re-derives stock behavior live rather than comparing against
   goldens, so it does not go stale the way a golden corpus would — but stock `UITextView` behavior
   *does* change across OS versions, and those changes surface as differences that are not
   Telegram's fault. Pin the simulator OS and record the pinned pair.

## `IDTextInputDifferentialRunner.m` — COMPILED since Task 9d

Tasks 9a-9c kept it `exclude:`d in `Package.swift`, and the reason was not laziness. The runner
constructs `IDTextInputTestHost`, `IDTextInputStateRecorder` and `IDTextInputTransactionDriver`, and
until Task 9d only their headers existed. Xcode links a clang target as one relocatable object, not
as an archive with per-file granularity, so an object file nothing calls still contributes its
undefined symbols: with the runner compiled in, the test bundle failed to link on
`_IDTextInputTransactionErrorDomain` and the three `_OBJC_CLASS_$_…` symbols (measured 2026-08-23,
Task 9a). The file was untouched throughout — the `md5` above still verifies — and it always
*compiled* against these headers; only the link failed.

**Task 9d wrote the driver and removed the exclusion.** All three implementations now exist, the
runner links, and `LegacyDifferentialTests` drives it over all four corpus families.

## Build-system placement

The `RichTextEditorDifferentialHarness` target is declared in `Package.swift` only. It is in no
`products:` entry and is **not** in `BUILD` — Bazel compiles only the two `Sources` libraries, so
none of this reaches the app build. The test target depends on it under
`condition: .when(platforms: [.iOS])` because `IDTextInputScenario.h` opens with `@import UIKit;`
and the vendoring rule forbids adding a platform guard to it.


## The `observedTextStorage` decision (Task 9b) — what Task 9c inherits

`IDTextInputTestHost.h` requires `@property NSTextStorage *observedTextStorage` and
`IDTextInputStateRecorder.h` exports `IDNormalizedInlineRuns(NSTextStorage *)`, against an editor
that has no single storage. Task 9b took **option (a)** — the storage IS populated — but in a
strengthened form, because the naive form of it is wrong here.

**`IDTelegramProjectedTextStorage` is a validated, read-only PULL projection**
(`include/IDTelegramHostProvider.h`). Every `-refresh` asks the editor for the attributed twin of
`-[UITextInput textInRange:]` over the whole document, compares the result's string against what the
input itself reports for the same range, and — on any disagreement — empties the backing and records
`misalignmentReason`. It declines; it does not guess.

**Why the projection takes a `UITextRange` rather than being a whole-document mirror. MEASURED
2026-08-24 on the real editor:** the `UITextInput` position axis is **sparse**. A top-level paragraph
boundary occupies TWO position slots while the text projection emits ONE `"\n"`, so
`-offsetFromPosition:toPosition:` reads one MORE than the corresponding index into the projected
string, and another one more at each further boundary. For
`"Alpha middle omega\nSecond block remains unchanged."`: `documentSize` 53, `beginningOfDocument` 1,
`endOfDocument` 52 (span **51**) against a **50**-character projection; the second paragraph's first
character is offset **20** on the axis and index **19** in the string. A whole-document mirror indexed
by recorder-reported offsets would silently read the wrong character's attributes from the second
paragraph onward — and report the result as agreement. `TelegramDifferentialHostTests`
pins these numbers.

**What Task 9c inherits, precisely:**

| Snapshot field | Telegram host |
| --- | --- |
| `inlineRuns` | **available** — the projection is dense and index-aligned with stock's real storage |
| `typingInlineTraits`, ranged selection | **available**, but sample it by projecting the SELECTION's `UITextRange` (`id_attributedTextProjection`), never by indexing the whole-document storage with the selection's offsets |
| `typingInlineTraits`, collapsed selection | **the vendored fallback is unavailable** — `textStylingAtPosition:inDirection:` is an `@optional` `UITextInput` member that `UITextView` implements and `DocumentCanvasView` does not |
| `annotationRanges` | not requested by any of the 68 scenarios (`comparesAnnotations` is NO throughout) |
| `storageMutationTrace` | **DECLINE.** The projection never posts `NSTextStorageDidProcessEditingNotification`, deliberately: a trace assembled from our own refresh calls would describe when the recorder sampled, not when the editor edited. An empty trace is a *defaulted* value, so the field must be omitted, not zeroed |
| `traits` | consult `id_unappliedTraits`. Four of the ten `UITextInputTraits` members do not exist on the editor (all ten are `@optional`; `UIView` implements none) and the six that do have no-op setters, so the ten values a recorder reads do NOT describe what the scenario asked for |

**One consequence of the vendored runner that Task 9d must confront.**
`IDCompareTextInputSnapshotPair` returns on the FIRST difference, scanning snapshots outermost. A
field that differs at snapshot 0 therefore hides every later snapshot's fields. And because the
comparison reads `snapshot.state[field]` for both sides, a field omitted from BOTH sides compares
`nil == nil` and passes **silently**. So "absent, never defaulted" is necessary but not sufficient:
the declined fields must be REMOVED from the list handed to the comparator, which is what
`IDTelegramComparableFields()` is for. **Task 9d resolved this and the resolution is not what this
paragraph originally said.** A declined field is not a named `TelegramDifferentialExpectations` entry
— an expectation is for a difference that was MEASURED and EXPLAINED, and a declined field is one
that was never measured at all. Putting the two in the same list would let a decline hide a
divergence. The declines carry their reasons in `IDTelegramDeclinedComparisonFieldReasons()` and are
recorded as a *caveat* in the expectations file; `LegacyDifferentialTests` pins the consequence of
getting this wrong (the unfiltered list fails at snapshot 0 on `traits`, masking the rest).

## The transaction driver (Task 9d) — the three deviations, and the fixed host bug

`IDTextInputTransactionDriver.m` replaces the origin's 3-hit file. The stock branch — including the
whole `toggleInlineTrait` typing-attribute / range-attribute machinery and its undo registration —
is a faithful reproduction of the original's, for the same reason the host's stock branch is: the
corpus re-derives stock behaviour LIVE, so an arm driven differently from the arm the corpus was
captured against is not measuring the same thing. Only InputDec's `IDInlineTextTraits` (from a
non-vendored header) becomes a file-local enum with the same bit values.

1. **Ranges are aimed with `IDTelegramTextRangeForCharacterRange`, never `positionFromPosition:offset:`**
   — the trap Task 9c measured. The document length a range is validated against is likewise the
   CHARACTER length (`[input textInRange:whole].length`), not `offsetFromPosition:toPosition:`, which
   on the editor measures the sparse axis and would admit a range one past the end.
2. **`set-traits` applies through `+[IDTextInputTestHost id_applyTraits:input:]`**, so the
   `respondsToSelector:` guard and the apply-and-read-back census exist in exactly one place. The
   driver keeps the original's *validation* (non-empty, keys a subset of the ten, values numeric).
   No scenario in this corpus carries a `set-traits` transaction (measured: 0 of 612).
3. **`toggleInlineTrait` on a non-stock host goes through `id_inlineTraitToggle`**, a block the Swift
   factory registers that calls the editor's own public `toggleBold()`/`toggleItalic()`/
   `toggleUnderline()`/`toggleStrikethrough()`. There is no neutral `UITextInput` spelling of "toggle
   bold over the selection", so the editor must answer for itself; a block keeps the driver free of
   any Telegram type. It is deliberately NOT compensated for a collapsed caret — see the
   `editor-has-no-pending-caret-format` expectation.

Driver errors name the HOST KIND. `-runScenario:order:error:` surfaces a driver failure by returning
`nil`, at which point the caller can no longer tell which of the three arms failed — and "the editor
cannot undo here and stock can" is a finding about the editor, not a broken scenario. Nothing
compares these strings.

**A latent bug in the host was fixed at the same time, and it is worth knowing about.** Task 9b's
`+hostWithKind:` set the scenario's INITIAL SELECTION with `positionFromPosition:offset:` — the same
trap. Measured over the corpus: **10 of the 68 scenarios have an `initialSelection.location` two or
more characters past a paragraph boundary** (the seven `after-boundary-*` autocorrection scenarios and
the three `after-boundary-*` inline-prediction ones — exactly the group written to exercise
post-boundary behaviour), and on those the host aimed one character early. It was MASKED, not
harmless: all 54 non-inline-formatting scenarios re-aim with a `set-selection` transaction before
their first checkpoint (measured 54/54), so no snapshot ever saw the wrong caret. The host now uses
`IDTelegramTextRangeForCharacterRange`, which is the identity on stock.

## Written here — the seam, and why it leaves the vendored files untouched

`IDTelegramHostProvider.h` (ours) declares a factory the Swift test target registers before any
scenario runs; the vendored `+hostWithKind:scenario:error:` calls it. The Telegram editor cannot be
built from Objective-C — `RichTextEditorView` is a plain Swift class with no `@objc`, its
`UITextInput` witness is `internal`, and SwiftPM gives an Objective-C target no Swift interop header
for a Swift target in the same package — and adding `@objc` to production code to make a test
constructible was rejected. A non-stock host with no factory registered FAILS rather than falling
back to stock: a run that compared stock against stock would be green and meaningless.

`IDTextInputHostKind` is vendored and has three cases; the vendored runner executes all three.
Telegram has ONE input implementation, so `IDTextInputHostKindMinimal` is a second, independently
constructed instance of the same editor and the reference-vs-minimal pair is a **determinism /
execution-order check, not a third implementation**. When a second Telegram input backend exists it
takes that slot and the check becomes a real one.

## The recorder's sampling contract (Task 9c) — what Task 9d must honour

### 1. Positions are reported on the STOCK CHARACTER axis, and the map is shared code

`IDTelegramCharacterAxis.{h,m}` (ours) is the single conversion, in both directions, and nothing else
may re-derive it. Forward:

    characterIndex(p) = [[input textInRange:(beginningOfDocument … p)] length]

`selection` and `markedRange` are reported through it, so both arms compare EXACTLY — the earlier
ruling to excuse the sparse axis as a named expectation was withdrawn (`selection` is a comparison
field of all 68 scenarios and 58 of the 68 touch a paragraph boundary, so excusing it would certify
almost nothing while reporting green).

**Residue: none.** Measured over every position the editor can reach: the map is monotone, injective,
and covers every character index exactly once.

**The inverse is the part that is easy to get wrong, and Task 9d's driver depends on it.**
`-positionFromPosition:offset:` does RAW-offset arithmetic and then snaps, so aiming at a character
index with it lands **one character early past every structural boundary** (measured:
`position(begin, +25)` → raw 26 → character **24**). Two of this task's own tests were written that
way and failed against a correct recorder. Realise a scenario's character-coordinate range with
`IDTelegramTextRangeForCharacterRange` instead.

### 2. Declined fields are DATA, not omissions — `IDTelegramRecorderPolicy.h`

`IDTelegramDeclinedComparisonFields()` = **`storageMutationTrace`, `traits`** (each with a stated
reason in `IDTelegramDeclinedComparisonFieldReasons()`), and
`IDTelegramComparableFields(scenario.comparisonFields)` is what a run must compare on. The recorder
computes its declines from CAPABILITY at every capture and publishes them in the snapshot under
`IDTelegramSnapshotDeclinesKey`; a test asserts the published list equals what a Telegram host
actually declines and that a stock host declines nothing.

Cost, measured: the 14 inline-formatting scenarios lose **nothing** (neither field is in their
contract); the other 54 lose exactly **2 of 14**. All 68 still compare `canonical`, `blocks`,
`selection`, `canUndo`, `canRedo`.

### 3. Two provider blocks, because the alternative was a downcast

`IDTelegramInputHandle` carries `blockTexts` and `typingAttributes` (Task 9c) alongside 9b's
attributed projection. Both are answered in Swift with `@testable` access, so the recorder needs no
Telegram type:

* **`blocks`** — the editor's own top-level block list, reproducing the vendored recorder's semantic
  (it read the custom view's real `attributedBlocks`, and split the canonical text only for STOCK).
  Splitting on both sides would have made `blocks` a restatement of `canonical`.
* **`typingInlineTraits` at a caret** — `typingAttributesAtGlobal`. **The editor has NO pending caret
  format** (`characterFormatTargets()` is empty for a caret, so `toggleBold()` there is inert) while
  stock carries the toggle in `typingAttributes`. That is a REAL divergence and the recorder reports
  it rather than declining — declining would have hidden it.

### 4. A new header in `include/` needs the module cache cleared

Adding `IDTelegramCharacterAxis.h` left Swift reporting `cannot find 'IDTelegram…' in scope` across
three consecutive clean-looking runs while the `.m` compiled without a diagnostic: the umbrella
module's prebuilt `.pcm` is not invalidated by a new header appearing in the umbrella DIRECTORY. Fix:

    find ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex \
        -name 'RichTextEditorDifferentialHarness*.pcm' -delete

It reads exactly like a missing declaration, and no amount of re-reading the header finds it.
