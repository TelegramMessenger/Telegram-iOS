# The differential-corpus baseline — Phase 0b, Task 9d

**Measured 2026-08-24** on this branch (`richtext/input-backend-seam`), against the **legacy**
input backend. Stage 2's Stage D re-runs this corpus and compares against exactly these numbers, so
every figure below is stated as a count, not as prose.

The oracle drives the vendored InputDec corpus through two arms — a stock `UITextView` and the
Telegram editor — and diffs their snapshots with the vendored comparator. What it is for is finding
places where the editor's `UITextInput` behaviour differs from the platform's. It found nine such
places. Eight are characterised below and named in `TelegramDifferentialExpectations`; the ninth is
an **open editor defect** and is why one of the four family tests is RED.

---

## 1. The pinned pair

| | |
| --- | --- |
| Simulator device | **`iPhone 17 Pro K1`** — `CA0A2186-0F4A-425B-B3B1-9B61E5FF01A9` (the device `Scripts/iostest.sh` defaults to) |
| Simulator runtime | **iOS 26.5, build `23F73`** |
| Runtime identifier | `com.apple.CoreSimulator.SimRuntime.iOS-26-5` — **shared with the beta `23F5069b`, which is also installed on this host** |
| Engine | both — the suite was run on TK2 and on TK1 (`TK1=1`) and reports identically |

**The identifier does not pin the build, and that is the whole problem.** `simctl list devices`
groups both 26.5 runtimes under one bare `-- iOS 26.5 --` heading, and a device's `device.plist`
records only the identifier (verified for K1). From outside the process there is no way to tell which
of the two a device will boot; the booted runtime root
(`/Library/Developer/CoreSimulator/Volumes/iOS_23F73`) is visible only from the running process's own
open file handles. A run on the beta would decode the corpus happily and report **stock UIKit's own**
behaviour changes as Telegram's.

So `LegacyDifferentialTests` asserts the build **from inside the test process**, and **fails loudly
with expected-vs-actual rather than skipping** — a skipped differential run reads as a pass in every
summary that matters. The expected build is parsed out of the corpus's own
`provenance.targetRuntime`, so a re-captured corpus moves the assertion with it.

### Reading the build from inside the simulator: three of the four obvious sources are wrong

Measured 2026-08-24, all four side by side in one process:

| Source | Value | Verdict |
| --- | --- | --- |
| `ProcessInfo.processInfo.operatingSystemVersionString` | `Version 26.5 (Build 23F73)` | **correct** — Foundation resolves the runtime's `SystemVersion.plist` under `$SIMULATOR_ROOT` |
| `$SIMULATOR_ROOT/System/Library/CoreServices/SystemVersion.plist` → `ProductBuildVersion` | `23F73` | correct — used as the independent cross-check |
| `sysctlbyname("kern.osversion")` | `25G76` | **WRONG — the host Mac's kernel build** |
| `/System/Library/CoreServices/SystemVersion.plist` → `ProductBuildVersion` | `25G76` | **WRONG — the host Mac.** An absolute path is not redirected into the runtime |
| `SIMULATOR_RUNTIME_VERSION` (env) | `26.5` | a version, never a build |

`kern.osversion` is what the plan's Step 3b suggested; it is right on a device and wrong in a
simulator, which runs on the host's kernel and in the host's filesystem namespace. `25G76` is a
perfectly plausible-looking build string — adopting either wrong source and then "fixing" the
resulting permanent failure by comparing against `25G76` would yield an assertion that passes on
**both** iOS 26.5 runtimes and therefore certifies nothing. That is the exact vacuity Step 3b exists
to prevent, reached by an entirely reasonable-looking route.

### The corpus's provenance is not one string (Task 9a's finding, re-confirmed)

`provenance.targetRuntime` has **two spellings**, split exactly on the family boundary:

* all **14** inline-formatting scenarios: `iOS 26.5 (23F73), K3`
* the other **54** scenarios: `iOS 26.5 (23F73)`

Both are pinned EXACTLY by the vendored decoder — not prefix-matched — and this is the only place the
corpus names a capture **device**. Recorded here so a future re-capture does not silently normalise
one spelling into the other. The test parses the parenthesised build, which tolerates both without
flattening either.

---

## 2. Per-family counts

Scenario and transaction counts are the corpus's own (decoded through the vendored
`IDLoadTextInputScenarios`); everything right of them was measured by this run.

| Family | Scenarios | Transactions | Checkpoints | Contract fields | Compared fields | Field comparisons | Execution failures | Differences | Explained | **Unexplained** |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| ime | 24 | 256 | 100 | 14 | 12 | 864 | 0 | 240 | 240 | **0** |
| autocorrection | 21 | 177 | 51 | 14 | 12 | 756 | 0 | 144 | 144 | **0** |
| inline-formatting | 14 | 98 | 56 | 7 | 7 | 294 | 0 | 18 | 18 | **0** |
| inline-prediction | 9 | 81 | 30 | 14 | 12 | 324 | 0 | 108 | 72 | **36** |
| **total** | **68** | **612** | **237** | — | — | **2238** | **0** | **510** | **474** | **36** |

* *Checkpoints* is the stock arm's snapshot count (all three arms produced the same count for every
  scenario — a mismatch would have been reported as a `checkpoints` difference and none was).
* *Field comparisons* counts `(scenario, field, host-pair)` triples: `fields × 3 pairs` per scenario.
* *Differences* counts the same triples. The vendored comparator **returns on the first inequality**,
  so at most one difference is reported per triple and only the FIRST diverging checkpoint of it —
  these are counts of diverging (scenario, field, pair) triples, not of disagreeing values.
* **Every difference in the table is a stock-vs-Telegram one. The reference-vs-minimal pair agreed on
  every field of every scenario** — 0 of 510. That is the determinism / execution-order result (see
  the caveat below on what it does and does not mean).

### Per-difference-class counts

| Class (the `TelegramDifferentialExpectations` entry name) | ime | autocorr | inline-fmt | inline-pred | total |
| --- | ---: | ---: | ---: | ---: | ---: |
| `caret-origin-differs-because-the-arms-use-different-text-metrics` | 48 | 42 | – | 18 | 108 |
| `editor-returns-no-selection-rects-for-a-collapsed-range` | 48 | 42 | – | 18 | 108 |
| `editor-notifies-the-input-delegate-where-stock-stays-silent` | 48 | 42 | – | 18 | 108 |
| `editor-registers-no-undo-step-for-an-uncommitted-composition` | 40 | – | – | 18 | 58 |
| `editor-does-not-model-selection-affinity` | 48 | – | – | – | 48 |
| `undo-restores-the-pre-edit-caret-where-stock-re-selects-the-restored-range` | – | 18 | – | – | 18 |
| `editor-has-no-pending-caret-format` | – | – | 18 | – | 18 |
| `editor-finalizes-a-live-composition-when-it-resigns-first-responder` | 8 | – | – | – | 8 |
| **UNEXPLAINED — `canonical` + `blocks`** | – | – | – | **36** | **36** |

Each entry's full reason is at its declaration in
`Tests/RichTextEditorUIKitTests/Differential/TelegramDifferentialExpectations.swift`. **"Explained"
means the difference is understood and attributable — not that it is desirable.** Three of the eight
are flagged at their declaration as candidate defects worth a separate look:
`editor-returns-no-selection-rects-for-a-collapsed-range`,
`editor-notifies-the-input-delegate-where-stock-stays-silent`, and
`editor-registers-no-undo-step-for-an-uncommitted-composition`.

---

## 3. THE OPEN FINDING — marked-text replace over-deletes by the composition's length

**All 9 inline-prediction scenarios diverge on `canonical` and `blocks`. This is an editor defect,
not a harness artifact, and `test_inlinePredictionFamilyMatchesStock` is RED because of it.**

Minimal reproduction, isolated 2026-08-24 (both arms driven by identical calls; the harness's aim was
verified to round-trip exactly on both, `aim {33,2} → textInRange "to" → roundTrip {33,2}`):

```
document      "AB  \nXYZ"                      (caret at character 3, between the two spaces)
setMarkedText "to"  selectedRange {0, 0}       -> both arms: "AB to \nXYZ", markedRange {3,2}
replace       {3, 2}  with "to "
   stock  -> "AB to  \nXYZ"      (replaced exactly the 2 marked characters)
   editor -> "AB to XYZ"         (replaced 4 — it consumed 2 further characters, including the "\n")
```

The over-deletion is **exactly the marked text's length**, and it is governed by the composition
caret, not by block structure:

| Variation | Result |
| --- | --- |
| `selectedRange {0, 0}` (caret at the START of the composition) | **diverges** |
| `selectedRange {2, 0}` (caret at the END of the composition) | agrees |
| replacement `""`, `"to"`, `"to "` | diverges identically — the replacement text is irrelevant |
| range far from any paragraph boundary (`"ABCDEFGH  IJ\nXYZ"`) | **diverges** — so it is not about boundaries |
| no marked text at all | agrees |

That last row is why the whole IME family passes on these fields while the whole inline-prediction
family fails: **IME compositions put the caret at the END of the marked text (`selectedRange`
`{1,0}`/`{2,0}`) and inline-prediction puts it at offset 0** — which is the correct idiom for a
suggestion shown *after* the caret. The corpus separates the two cases by construction, and that is
what made the defect visible.

Where to look: `LegacyRichTextInputBackend+Insertion.swift:64` (`replace(_:withText:)`) →
`DocumentCanvasView+UITextInput.swift:105` (`legacyReplace`) → `editing { applySelectionReplaceOutcome(…) }`.
`performEditing` opens with `finalizeMarkedText()`, so the composition is COMMITTED before the
mutation runs, and the `lo`/`hi` computed from the incoming range are consumed afterwards. A commit
that moves text by the composition's length while the caller holds pre-commit offsets fits the
measured signature exactly, but this task did not confirm the line and **fixing it is not Phase 0b's
job**. It is recorded here, and the family test stays red until it is fixed or a decision is recorded
against it.

**Do not close this by widening an expectation.** The difference is a wrong document, produced by a
sequence a real inline-prediction keyboard performs.

---

## 4. The two limitations (verbatim from the Phase 0b preamble)

> 1. **Telegram has no single `NSTextStorage`.** `DocumentCanvasView` is block-structured with
>    per-leaf-region layout, so the storage-dependent comparison fields (`blocks`, `inlineRuns`) are
>    declined under the legacy backend. Stage 2's storage façade gives `.inputDec` the full field set
>    — an asymmetry between host kinds, not a regression.
>
> 2. **The corpus's provenance is iOS 26.5 / 23F73.** The runner re-derives stock behavior live rather
>    than comparing against goldens, so it does not go stale the way a golden corpus would — but stock
>    `UITextView` behavior *does* change across OS versions, and those changes surface as differences
>    that are not Telegram's fault. Pin the simulator OS and record the pinned pair.

**How limitation 1 actually came out, which is better than it predicted.** Task 9b took option (a) —
`observedTextStorage` IS populated, as a validated read-only pull projection
(`IDTelegramProjectedTextStorage`) — so **neither `blocks` nor `inlineRuns` is declined**. Both are
compared for every scenario whose contract names them. What *is* declined is a different, smaller
pair, and for a different reason:

| Declined field | Why (short form; the full reason is `IDTelegramDeclinedComparisonFieldReasons()`) |
| --- | --- |
| `storageMutationTrace` | The projection's `-refresh` swaps its backing outright, so it can never post `NSTextStorageDidProcessEditingNotification`. A trace built from our own refresh calls would describe *when the recorder sampled*, not when the editor edited. |
| `traits` | The contract's census is all **ten** `UITextInputTraits` members; the canvas implements **six** (all ten are `@optional`; `UIView` implements none). The ten-key dictionary cannot be formed, and a six-key one is a different measurement wearing the same name. What can be read is published under `telegramReadableTraits`, and the construction-time apply-and-read-back census under `telegramUnappliedTraits`. |

Cost of the declines, measured: the 14 inline-formatting scenarios lose **nothing** (neither field is
in their contract); the other 54 lose **2 of 14**. All 68 still compare `canonical`, `blocks`,
`selection`, `canUndo`, `canRedo`.

Limitation 2 is what §1 is about.

---

## 5. Comparator behaviours a reader must know (catalogued by Task 9c, confirmed here)

These are properties of the **vendored** `IDTextInputDifferentialRunner.m`. None is a defect; all
four change what a green result means, and a later reader who rediscovers them as bugs will waste a
day.

1. **`nil == nil` is agreement.** `IDCompareTextInputSnapshotPair` decides equality with
   `leftValue == rightValue || [leftValue isEqual:rightValue]` over `snapshot.state[field]`, so a
   field absent from BOTH sides reports agreement **on something nobody measured**. This is why a
   declined field must be *removed from the comparison list* (`IDTelegramComparableFields()`), not
   merely omitted from the snapshot. "Absent, never defaulted" prevents a false *value*; it does not
   prevent a false *agreement*.
2. **It returns on the FIRST inequality, scanning snapshot indices outermost.** One
   permanently-differing field at snapshot 0 masks every later snapshot AND every later field of that
   scenario. `storageMutationTrace` and `traits` are in 3 of the 4 families' contracts, so passing
   `scenario.comparisonFields` verbatim fails at snapshot 0 on `traits` and hides the rest —
   `test_theUnfilteredFieldListFailsAtTheFirstSnapshotOnADeclinedField` pins exactly that.
   **Consequence for this run:** the family tests call the comparator **once per field**, with a
   single-element `comparisonFields` list, so one diverging field cannot hide the others. Within a
   field, only the first diverging checkpoint is reported.
3. **`MIN(left.count, right.count)`** bounds the snapshot walk; a count mismatch is reported
   afterwards as a synthetic `checkpoints` difference. (None occurred: no `checkpoints` difference
   was reported for any scenario, so all three arms produced the same snapshot count throughout.)
4. **`diagnosticFields` are skipped outright** — `behaviorCapabilities` and `behaviorDetached` are
   never compared, whatever a scenario's contract says.
5. **Geometry tolerance applies to `caretRect` and `selectionRects` only**, recursively through
   dictionaries and arrays, and requires identical key sets. The corpus sets it to **1.0** for ime /
   autocorrection / inline-prediction and **0** for inline-formatting (which compares no geometry).

---

## 6. Caveats — what an AGREEMENT here does not mean

1. **`IDTextInputHostKindMinimal` is not a second backend.** The vendored enum has three cases and
   the vendored runner executes all three; Telegram has ONE input implementation, so the factory
   builds a fresh, independently constructed editor for both non-stock kinds. The reference-vs-minimal
   pair is a **determinism / execution-order check** — the runner drives the two at different points
   of its order, so a difference there means state leaked across instances or the result depended on
   when it ran. The measured 0-of-510 is a real and useful result *as that*. Reading it as "two
   backends agree" would be exactly the false comfort this phase exists to prevent. When a second
   Telegram input backend exists it takes the `Minimal` slot and the check becomes a real one.
2. **The oracle is independent of the EDITOR, not of US.** Only the corpus and two of the five
   Objective-C pairs are vendored; host construction, state sampling and transaction driving are
   Telegram-side code (the reshaped Phase 0b's accepted trade). The corpus — 68 scenarios / 612
   transactions of real IME, autocorrection, inline-prediction and inline-formatting sequences
   captured against stock UIKit — is the genuinely independent asset.
3. **`annotationRanges` is never requested.** No scenario in the corpus names it (measured over all
   68), so `comparesAnnotations` is NO throughout and the recorder's annotation path is written but
   unexercised — a capability claim, not a result.
4. **The `selection` axis is MAPPED, not compared raw.** The editor's `UITextInput` position axis is
   structural (it counts the non-renderable token slots between blocks), so it diverges from stock's
   character axis past every paragraph boundary. `IDTelegramCharacterAxis` converts both arms onto the
   character axis before anything is reported, with **no residue** — so `selection` and `markedRange`
   compare exactly, and there is deliberately NO expectation entry excusing them. (There could not
   usefully be one: `selection` is a comparison field of all 68 scenarios and 58 of the 68 touch a
   paragraph boundary, so an entry would have excused ~85% of the corpus on a field every scenario
   compares.)
5. **Only one execution order was run** (`Stock, Reference, Minimal`). The vendored runner also
   supports the reverse; it is not part of this baseline.

---

## 7. Reproducing this

```sh
cd submodules/TelegramUI/Components/RichTextEditor
Scripts/iostest.sh RichTextEditorUIKitTests/LegacyDifferentialTests          # TextKit 2
TK1=1 Scripts/iostest.sh RichTextEditorUIKitTests/LegacyDifferentialTests    # TextKit 1
```

Expected today: **6 tests, 1 failure** — `test_inlinePredictionFamilyMatchesStock`, on the 36
unexplained `canonical`/`blocks` differences of §3. Identical on both engines. Every count in §2 is
printed by the run itself, one `=== DIFFERENTIAL <family>` block per family.

If a new header is added under `Tests/DifferentialSupport/include/`, Swift will report
`cannot find … in scope` while the `.m` compiles without a diagnostic — the umbrella module's
prebuilt `.pcm` is not invalidated when a header appears in the umbrella *directory*:

```sh
find ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex \
    -name 'RichTextEditorDifferentialHarness*.pcm' -delete
```
