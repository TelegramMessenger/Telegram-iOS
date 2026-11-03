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
6. **The recorder is BLIND to whether the responder wants a keyboard at all — added by Task F2,
   which is what that blindness cost.** `IDTextInputStateRecorder` records `firstResponder`
   (`state[@"firstResponder"] = @(input.isFirstResponder)`) and nothing else about the responder's
   *input* status. There is no `isEditable` field, and `IDTextInputScenario`'s whitelist of
   comparable fields does not contain one, so none of the 410 recorded `.inputDec` differences could
   have seen that the ID canvas answered UIKit's `-isEditable` witness with `false` where stock and
   Legacy answer `true` — the difference that meant **no keyboard ever appeared** under the flag.
   The corpus agreeing on every character of text it typed is not evidence that a user could have
   typed any of it. `IDKeyboardActivationTests` closes this specific axis outside the corpus (and
   documents why it must: `keyboardWillShowNotification` does not fire in this test host even for a
   plainly editable `UITextView`, measured, so the appearance itself is unobservable here and a
   private `-_requiresKeyboardWhenFirstResponder` reading — calibrated against two real
   `UITextView`s — is the instrument). Adding the field to the recorder would be inert without also
   editing the pinned corpus scenarios to request it, which is why the closure is a separate suite
   rather than a new comparison field.

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

---

## 8. The `.inputDec` section — Task D4b

**Measured 2026-08-26**, same corpus (68 scenarios / 612 transactions, `richtext/inputdec-backend`,
base `ad297799b6`), run for the first time against the `.inputDec` backend instead of legacy. Two
legs, on two different simulators, both included below because the numbers are **identical** between
them (see §8.4 — no ABI drift was found).

| | |
| --- | --- |
| Leg 1 ("certified band") | `iPhone 17 Pro K3` — `FA6F7462-AA97-42FE-9E57-8DA0593CE756` — iOS 26.5, build **23F73** (the corpus's own capture build; matches the kernel's one certified OS) |
| Leg 2 ("uncertified band") | `iPhone 17 Pro K2` — `A33A46AF-33DC-4D8E-8026-51473ED5D615` — iOS **27.0**, build 24A5408d |

**Device substitution, recorded because it departs from the brief's literal text.** The brief named
"K3, then K1 (iOS ≠ 26.5)" for the two legs. Measured directly on this host: **K1 and K3 are BOTH
26.5/23F73** (`LegacyDifferentialTests.test_theRunningSimulatorIsTheCorpusCaptureBuild` passed
unmodified on both UDIDs) — the only device on this host that is genuinely not 26.5 is **K2**, on iOS
27.0. K1 was therefore not usable as an "iOS ≠ 26.5" leg at all; K2 is the substitute, and it is what
the brief's own intent asked for (a real, uncertified OS band to check decision 2's floor against).

**Harness note.** No fifth `IDTextInputHostKind` was added (the brief's own suggestion) —
`IDTextInputScenario.h` is vendored byte-for-byte (`Tests/DifferentialSupport/PROVENANCE.md`: "DO NOT
EDIT") and the enum's three existing cases already give `.inputDecRequired` a home: a *second* Swift
factory (`TelegramInputDecDifferentialInputFactory`, mirroring stage 1's `TelegramDifferentialInputFactory`)
is installed by `IDDifferentialTests` in place of the legacy one, so `Reference`/`Minimal` become two
independently constructed **ID-backed** editors for this suite — the exact "second instance, not a
second implementation" shape stage 1 already established for legacy. No vendored or already-generic
non-vendored file changed. Full reasoning in that factory's own header comment.

### 8.1 The comparable field set is NOT narrower than legacy's — the brief's asymmetry did not hold

The brief expected `.inputDec` to answer MORE fields than legacy (legacy declining `blocks`/
`inlineRuns` for lack of one `NSTextStorage`). That was true of the ORIGINAL Phase 0b plan, but Task
9b already closed the gap for legacy itself (`IDTelegramProjectedTextStorage`, a validated pull
projection over ANY `UIView<UITextInput>`) — so **both runs compare the identical field set**,
`IDTelegramComparableFields(scenario.comparisonFields)` (`storageMutationTrace`/`traits` declined for
both, nothing else). §8.2's counts are therefore directly comparable to §2's, field for field, with no
asymmetry to account for.

**One real construction-time gap this DID surface** (not a corpus divergence — a gap in the
LEGACY-only test-harness plumbing Task 9b/9c wrote): `legacyAttributedText(in:)`/
`differentialTypingAttributes(at:)` open a `UITextRange` via `LegacyTextIdentity.globalRange(of:)`,
which downcasts to legacy's own opaque `LegacyTextRange` and returns `nil` for anything else — so
under `.inputDec` the whole-document sanity check failed for EVERY scenario until fixed. The fix
(`TelegramInputDecDifferentialInputFactory.swift`) round-trips through PLAIN-TEXT LENGTH instead of a
raw `offset(from:to:)` shift, because the flat shift is wrong by a compounding amount at every
paragraph boundary (measured directly: a `+1` shift held for one paragraph and was wrong the moment a
second paragraph was added) — this is the SAME axis-conversion class named in the constraints,
encountered here in test-harness code rather than the production bridge.

### 8.2 Per-family counts (both legs — identical)

| Family | Scenarios | Transactions | Checkpoints | Field comparisons | Execution failures | Crashes | Differences | Explained | **Unexplained** | Test result |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| ime | 24 | 256 | 100 | 864 | 0 | 0 | 256 | 192 | **64** | FAIL |
| autocorrection | 21 | 177 | 51 | 756 | 0 | 0 | 144 | 144 | **0** | **PASS** |
| inline-formatting | 14 | 98 | 56 | 294 | 0 | 0 | 38 | 20 | **18** | FAIL |
| inline-prediction | 9 | 81 | 30 | 324 | 0 | 0 | 76 | 54 | **22** | FAIL |
| **total** | **68** | **612** | **237** | **2238** | **0** | **0** | **514** | **410** | **104** | 1/4 pass |

**Task D4c moved exactly one cell of this table**, by fixing the delete-backward no-op §8.3(d) left
red (see §8.7): `inline-formatting` is now **28 differences / 20 explained / 8 unexplained**, and the
total is **504 / 410 / 94**. Every other family is byte-identical before and after — measured, not
assumed, by running all four with and without the one-line fix (`ime` 256/192/64,
`autocorrection` 144/144/0, `inline-prediction` 76/54/22 on both sides).

**Task D4d then closed both remaining non-`ime` families** (§8.8), with two fixes: the dropped
marked-text-relative caret, and the backward-delete cluster-range axis. Measured on K1 (23F73):

| Family | before D4d | after D4d | Test result |
| --- | --- | --- | --- |
| ime | 256 / 192 / **64** | 256 / 192 / **64** | FAIL (unchanged) |
| autocorrection | 144 / 144 / **0** | 144 / 144 / **0** | **PASS** |
| inline-formatting | 28 / 20 / **8** | **20 / 20 / 0** | **PASS** |
| inline-prediction | 76 / 54 / **22** | **54 / 54 / 0** | **PASS** |
| **total** | 504 / 410 / **94** | **474 / 410 / 64** | **3/4 pass** |

`ime`'s 64 are byte-identical before and after — the whole residual is now that one family's
`*-after-boundary-*` composition-content class, §8.3(b).

**Task D4f closed `ime`, and with it the corpus** (§8.9), with two fixes: the renderable-position
snap on `position(from:offset:)`, and the composition commit's missing undo registration. Measured on
K1 (23F73), all four families in one invocation:

| Family | before D4f | after D4f | Test result |
| --- | --- | --- | --- |
| ime | 256 / 192 / **64** | **192 / 192 / 0** | **PASS** |
| autocorrection | 144 / 144 / **0** | 144 / 144 / **0** | **PASS** (byte-identical) |
| inline-formatting | 20 / 20 / **0** | 20 / 20 / **0** | **PASS** (byte-identical) |
| inline-prediction | 54 / 54 / **0** | 54 / 54 / **0** | **PASS** (byte-identical) |
| **total** | 474 / 410 / **64** | **410 / 410 / 0** | **4/4 pass** |

The three already-green families are byte-identical, measured in the same invocation rather than
inferred. Note the `ime` total DIFFERENCES fell 256 → 192 as well as its unexplained falling 64 → 0:
the 64 were not re-attributed to an expectation, they stopped occurring.

Compare to legacy's own §2 table: legacy's total differences were 510 (474 explained / 36
unexplained), 0 execution failures. `.inputDec`'s total is 514 differences (410/104) — a materially
different shape, not a superset or subset of legacy's — because most of legacy's 8 named causes are
canvas-level and reproduce identically here (§8.3), while `.inputDec` ALSO carries its own kernel- and
axis-specific causes legacy never had (geometry bypass, the new axis instances).

> **CORRECTED BY TASK F1 (2026-08-26) — the geometry bypass is GONE and the cluster was never
> unreachable.** The two `kernel-geometry-bypass-*` rows in §8.3(a) below have been reclassified into
> the shared-with-legacy class and renamed; the table is corrected in place, with the superseded
> claims kept verbatim so the mischaracterisation stays legible. What that characterisation cost is
> recorded in `DIVERGENCES.md` entry 19: "the kernel answers geometry from its own container" also
> means the kernel is the one being HANDED THE POSITION, and the canvas hands it a canvas-minted
> identity object that the kernel casts unchecked — `unrecognized selector`, and (because
> `reportKernelFailure` was fatal in DEBUG) a hard crash on the user's first tap with the flag on.
> Five tests had sat red on the unreachability claim for the whole programme; all five pass now.

### 8.3 Per-cause breakdown

**(a) Known-unreachable kernel limits — `DIVERGENCES.md`, attributed, not re-investigated:**

**This category is now EMPTY.** Both rows it used to hold were geometry, and Task F1 rerouted Family 2
off the kernel entirely (see the two reclassified rows in the shared-with-legacy table below). The
category heading is kept because the classification scheme is referenced from
`IDDifferentialExpectations.swift`'s own header, and because a future genuinely-unreachable kernel
limit belongs here — not because anything currently sits in it.

*Superseded, kept verbatim for the record (Task D4b's original rows, both DISPROVEN by F1):*

| ~~Cause~~ | ime | autocorr | inline-pred | Total | ~~Evidence~~ |
| --- | ---: | ---: | ---: | ---: | --- |
| ~~`kernel-geometry-bypass-caretRect`~~ | 48 | 42 | 18 | 108 | ~~`caretRect` diverges in BOTH size and origin (not just origin, unlike legacy) — the kernel lays out against its own unstyled synthetic container. R8 (cited in `DIVERGENCES.md`): zero calls through the `id_` geometry bridge, instrumented.~~ **F1: the counts were right and the mechanism was half-right — the kernel WAS answering, and should never have been asked. Routed at the geometry client, the SAME 108 differences now satisfy legacy's own strictly narrower predicate (caret SIZE must agree, only the origin moves), which this row explicitly declined to adopt. Measured, 0 unexplained.** |
| ~~`kernel-geometry-bypass-selectionRects-empty`~~ | 48 | 42 | 18 | 108 | ~~`selectionRects` for a collapsed range is an EMPTY array, 100% of occurrences (216/216 checked) — same root cause, this field's own shape.~~ **F1: still empty, still 108 — but now because `IDTextEditorBackend+Geometry.swift` maps the geometry client's segments and a collapsed range has none, which is legacy's mechanism verbatim. The observable shape never changed, which is exactly why the wrong mechanism went unnoticed.** |

**Shared-with-legacy — backend-agnostic canvas code, reproduced here because it is shared, not
because `.inputDec` introduces anything new** (a fourth class alongside (a)/(b)/(c), named because
none of those three describe it accurately):

| Cause | Scope | Count | Mechanism |
| --- | --- | ---: | --- |
| `caret-origin-differs-because-the-arms-use-different-text-metrics-inputdec` | ime, autocorr, inline-pred | 108 | **Added by F1** (was `kernel-geometry-bypass-caretRect`). Both backends now answer `caretRect(for:)` from the same host geometry client, so the only thing left between the arms is the font: stock is 17pt system, the editor is on the InstantPage-V2 chat-message metrics. Identical predicate to legacy's own row — width and height must be EQUAL, so a caret that changed size or vanished still fails the run. |
| `editor-returns-no-selection-rects-for-a-collapsed-range-inputdec` | ime, autocorr, inline-pred | 108 | **Added by F1** (was `kernel-geometry-bypass-selectionRects-empty`). `IDTextEditorBackend+Geometry.swift` maps the geometry client's segments; a collapsed range produces none, exactly as `LegacyRichTextInputBackend+Geometry.swift` does. NOT blessed — a real `UITextInput` conformance difference and a candidate defect, for both backends. |
| `editor-has-no-pending-caret-format` | inline-formatting | 20 | `characterFormatTargets()` returns `[]` for a collapsed caret (`+CharacterFormat.swift`) — never reads `inputBackend`. |
| `editor-does-not-model-selection-affinity` | ime | 48 | `TelegramGeometryInputClient` (one of the six clients BOTH backends share) returns `.downstream` unconditionally. |
| `editor-notifies-the-input-delegate-where-stock-stays-silent` | ime, autocorr, inline-pred | 108 | `notifyingContentAndSelectionChange` (`editing{}`'s bracket) is canvas-level. |
| `undo-restores-the-pre-edit-caret-where-stock-re-selects-the-restored-range` | autocorrection | 18 | The undo-registration selection policy (`performEditing`) is canvas-level. |

**(b) New instances of the axis-conversion class:**

| Cause | Scope | Count | Evidence |
| --- | --- | ---: | --- |
| ~~IME composition content corruption, "after-boundary" scenarios only~~ **ROOT-CAUSED AND FIXED — Task D4f, §8.9. It was TWO defects, not one, and only the first is the axis class** | ime | ~~64~~ → **0** (axis half 32; composition-undo half 32) | The row's own framing ("the 10 `*-after-boundary-*` scenarios") conflated two populations that happen to overlap. **32** were the 8 `*-after-boundary-*` scenarios × 6 fields — the axis class, and the doubled character: `position(from:offset:)` did not snap to a renderable slot, so the corpus's aim at the second paragraph's first character landed in the inter-paragraph gap, where `legacySetMarkedText` degrades composition to a plain insert. **The other 32** were the FOUR `*-return-commit-then-undo` scenarios × 8 fields — two after-boundary AND two BEFORE-boundary, which is what rules them out of the axis class: an `unmarkText` that never registered the composition's undo step. |

**(c) Unimplemented witness — found and FIXED in this task, not merely recorded:**

`IDTextEditorBackend.undoManager` (`IDTextEditorBackend.swift`) was a bare `var undoManager:
UndoManager? { nil }` — unconditional, not "nil only when detached" (the convention every neighboring
witness in the same file uses). `DocumentCanvasView.undoManager` (the `UIResponder` override) routes
straight through it, so EVERY ID-backed canvas answered "no undo manager" to hardware ⌘Z/⌘⇧Z,
shake-to-undo, the Edit-menu Undo/Redo, AND to this differential driver's own `host.input.undoManager
.canUndo` read — even when `effectiveUndoManager` held a genuinely registered step. **This was also
the crash's root cause** — see §8.5. Fixed: `var undoManager: UndoManager? { guard isAttached, let
host else { return nil }; return host.commandClient.undoManager }`, reusing the exact value
`performCommand(.undo/.redo, sender:)` already reached two members below (a precedented one-line fix,
not a broad one). Verified: (1) the crash is gone (§8.5); (2) the autocorrection family's whole
`undo-restores-the-pre-edit-caret…` divergence — 18/18 instances — is now explained rather than being
a `canUndo`-mismatched execution failure; (3) `IDBackendFamily7Tests`/`IDBackendFamily11Tests`/
`IDHarnessTests`/`BackendSemanticContractCases`/`IsSupportedTests` all still pass (18 tests); (4)
`IDBackendDifferentialTraceTests` still shows its pre-existing 16 failures — measured BYTE-IDENTICAL
with and without this fix (`git stash`), confirming no regression and no relation to this bug.

**(d) Genuinely new and uncategorised — the deliverable of this task, left red:**

| Cause | Scope | Count | Evidence |
| --- | --- | ---: | --- |
| ~~`deleteBackward()` becomes a no-op immediately after a `.toggleInlineTrait` command~~ **ROOT-CAUSED AND FIXED — Task D4c, §8.7** | inline-formatting (`delete-run-boundary`, `backspace-block-boundary`) | ~~18~~ → **8** (`blocks` 4, `selection` 4 and `typingInlineTraits` 2 now CONVERGE; `canonical` 4 and `inlineRuns` 4 remain, for a DIFFERENT reason — see the row below) | The hypothesis recorded here (a rejected, new-revision-stamped pre-warmed range) was TESTED AND IS FALSE: the `synchronizeAfterExternalChange` revision-continuity guard never fires on this path, and `RichTextInputContractViolation.reporter` records ZERO violations across both scenarios. The real mechanism is one branch of `TGRichTextInputDecTextStorageFacade.synchronizeMirrorWithDocumentIfNeeded` — §8.7 has the measurement. |
| ~~Mirror–document divergence after ANY applied backward delete (independent of the toggle; unmasked, not caused, by the D4c fix)~~ **ROOT-CAUSED AND FIXED — Task D4d, §8.8** (the mechanism is NOT the one guessed below: `replaceCharactersInRange:withString:` applies the kernel's range faithfully; the range it is HANDED is one axis wrong, because `id_rangeOfCharacterClusterAtIndex:type:` answered a plain-axis question on the structural axis) | inline-formatting (`delete-run-boundary`, `backspace-block-boundary`) | ~~8~~ → **0** | `delete-run-boundary`: stock `canonical` `"B"`, `.inputDec` `""`. `backspace-block-boundary`: stock `"AB"`, `.inputDec` `"A\n"`. In BOTH, the `blocks` field — read from the REAL document, not the mirror — now AGREES with stock, so the document mutation itself is correct and only the projection is wrong. `canonical`/`inlineRuns` reach the recorder through `text(in:)` → the kernel → `-[TGRichTextInputDecTextStorageFacade string]` → the mirror, and `replaceCharactersInRange:withString:` writes the KERNEL's proposed `plainRange` into that mirror while the document client applies its own delete semantics; when the two disagree the mirror drifts, and because that method then sets `_lastSyncedBridgeRevision = outcome.revision` the resync gate short-circuits forever after. Reproduced with NO formatting toggle at all (`IDBackendFormattingThenDeleteTests.test_deleteBackwardWithoutAFormattingToggle_stillMutatesTheDocument`, instrumented: `mirror == ""` while `blocks == ["B"]`), so it is a pre-existing, independent defect. Repairing it means re-opening R7's measured "do not proactively re-derive the mirror" trade-off, so it is left for its own task rather than folded into D4c. |
| ~~`selection` at the "offered" phase off by a UNIFORM +2~~ **ROOT-CAUSED AND FIXED — Task D4d, §8.8** | inline-prediction (all 9 scenarios) | ~~18~~ → **0** | `{location 33, length 0}` vs `{location 35, length 0}`, EVERY scenario, including `interior-*` ones with no paragraph boundary at all — so NOT the per-boundary axis class, as recorded here. Mechanism: `IDTextEditorBackendIntent.mutation(for: .markedText, …)` FABRICATED `selectedRangeInMarkedText` as `{text.utf16.count, 0}`, because the caller's `selectedRange` had no way to travel past the façade's raw `replaceCharactersInRange:withString:`. It now travels latched beside the intent. |
| ~~`canonical` merge mismatch, "accept-then-delete" scenarios crossing a boundary~~ **ROOT-CAUSED AND FIXED — Task D4d, §8.8; and the paragraphs were never merged** | inline-prediction (`before-boundary-accept-then-delete`, `after-boundary-accept-then-delete`) | ~~4~~ → **0** | NOT downstream of the `+2` above (fixing that left all 4 standing), and NOT a merge: `blocks` — read from the real document — agreed with stock throughout, so only the façade MIRROR read `"...to Later..."`. Same root cause as the row above it: the backward-delete cluster range. |

### 8.4 K2 (uncertified, iOS 27.0) vs K3 (certified, iOS 26.5/23F73) — no drift found

`IDTextEditorBackend.isSupported() == true` on K2 (confirmed via `IsSupportedTests
.test_theManifestIsRequired_butItsBuildDoesNotGateTheAnswer`, printing `isSupported() == true on
27.0, certified on 26.5`) — decision 2's floor DOES select the ID backend on a major OS version the
kernel was never certified against. All four families were re-run there in full. **Every count in
§8.2 and every named cause in §8.3 is IDENTICAL between the two legs** — same explained/unexplained
totals per family, same per-cause counts, 0 execution failures and 0 crashes on both. No K2-only
divergence was found, so per the task's own stopping rule this is NOT a "stop": there is no evidence
of a semantic ABI drift on this uncertified band. (This is a real, checked result, not an assumption —
the brief's own "single most valuable signal" instrument was run to completion on both legs.)

### 8.5 The crash — found, root-caused, fixed, and reverted-and-reconfirmed

The first `test_inlineFormattingFamilyMatchesStock` run crashed (`Test crashed with signal segv.`)
partway through the `undo-range-format` scenario. Bisected with the vendored
`IDTextInputTransactionDriver`/`IDTextInputTestHost` driven manually transaction-by-transaction (both
orders, both host kinds, with and without the preceding `toggleInlineTrait`): no manual reproduction
crashed, isolating the crash to something reachable ONLY through `IDTextInputDifferentialRunner`
itself (confirmed with a 4-transaction synthesised scenario via `DifferentialCorpus.synthesise` — the
`.undo` transaction was the trigger). Root cause: `host.input.undoManager` (`.canUndo`) was reading
the unconditional-`nil` `IDTextEditorBackend.undoManager` stub described in §8.3(c), so the driver's
`.undo` handling always took its "Undo is unavailable" branch regardless of the REAL, correctly
registered undo step on `effectiveUndoManager` — and something in the exact call chain the driver's
failure path takes only when reached through the compiled runner (not reproduced by any equivalent
manual driving) then crashed. Fixing the stub made the crash reproduce zero times across every
subsequent run of this task (all four families, both simulators, and the original crashing scenario
run in isolation) — `runner.run(...)` on the original scenario went from a signal-11 crash to
`RUNNER OK stock=4 reference=4 minimal=4`.

**Crashes stayed at 0 for the remainder of this task**, verified across: all four families on K3, all
four families on K2, and the isolated pre/post-fix reproduction of the originally-crashing scenario.

### 8.7 Task D4c — the delete-backward no-op, root-caused and fixed

**Symptom** (D4b's most severe finding, §8.3(d)): in the `.inputDec` backend, pressing backspace
immediately after toggling bold did nothing at all — the document was byte-identical before and
after, with no exception, no rejection anyone could see, and no contract violation.

**The recorded hypothesis was tested and is FALSE.** D4b guessed at
`IDTextEditorBackend.synchronizeAfterExternalChange`'s revision-continuity guard rejecting the
change. Instrumented with `RichTextInputContractViolation.reporter` installed for the whole
scenario, both scenarios record **zero** violations — that guard cannot fire here at all, because
`DocumentCanvasView.synchronizingExternalChange` reads `oldRevision` from
`inputBackend.state.documentRevision` itself (its own long comment says so), so the two are equal by
construction. The backend adopts the new revision correctly; its `state` is never stale.

**The real mechanism, measured.** A bold toggle is an ATTRIBUTE-ONLY change: `applyCharacterToggle`
(`DocumentCanvasView+CharacterFormat.swift`) runs inside `editing { }`, which bumps
`documentRevision` unconditionally (`+Editing.swift:384`, "one revision per editing transaction, even
for a no-op body"), while every character stays exactly where it was.

`TGRichTextInputDecTextStorageFacade.revision` is the baseline every KERNEL-DRIVEN mutation declares
to `prepareAndCommitReplacementInRange:text:intent:expectedRevision:…`, and
`TelegramDocumentInputClient.prepareMutation` opens with
`guard expectedRevision == revision else { return terminal(.revisionMismatch) }`
(`TelegramDocumentInputClient.swift:120`). `IDTextEditorBackend.insertText(_:)` refreshes that
baseline itself (`bridge.storage.revision = state.documentRevision`) — the kernel-driven witnesses
(`deleteBackward()`, `setMarkedText(_:selectedRange:)`) do not, and rely on
`synchronizeMirrorWithDocumentIfNeeded` to keep it fresh, exactly as R3's own comment on
`replaceCharactersInRange:withString:` claims it does.

It did not. That method has two full exit paths: the content-differs rebuild at its tail sets BOTH
`_lastSyncedBridgeRevision` AND `self.revision`; the `[self.mirror.string isEqualToString:text]`
"already in sync" fast path R7 added later set only the first. An attribute-only change is precisely
the case that lands on that path — same text, new revision — so the façade kept declaring the OLD
revision, `prepareMutation` returned `.terminal(.rejected(.revisionMismatch))`,
`replaceCharactersInRange:withString:` returned before its mirror mutation, and the rejection was
reported to `lifecycleClient.backendDidRejectMutation`, whose Telegram implementation is an **empty
method body** (`TelegramLifecycleInputClient.swift:44-45`). Hence "nothing at all".

Instrumented A/B on a real `.inputDec` canvas seeded with `"AB"`, driving `delete-run-boundary`
transaction for transaction (`canvas` = `DocumentCanvasView.documentRevision`, `backend` =
`IDTextEditorBackend.state.documentRevision`, `facade` =
`TGRichTextInputDecTextStorageFacade.revision`):

```
repair=false  seeded{canvas=1 backend=0 facade=1 blocks=["AB"]}
              toggled{canvas=2 backend=2 facade=1 blocks=["AB"]}      ← façade one revision behind
              deleted{canvas=2 backend=2 facade=1 blocks=["AB"]}      ← nothing happened, 0 violations
repair=true   toggled{canvas=2 backend=2 facade=1 blocks=["AB"]}
              (facade.revision = canvas.documentRevision)             ← the ONLY thing changed
              deleted{canvas=3 backend=3 facade=3 blocks=["B"]}       ← the delete lands
```

**The fix** is one branch of `synchronizeMirrorWithDocumentIfNeeded`
(`Sources/RichTextInputDecObjC/Host/TGRichTextInputDecTextStorageFacade.m`, telegram-ios-authored,
NOT a vendored path): the "already in sync" early return now adopts `self.revision` alongside
`_lastSyncedBridgeRevision`, restoring the invariant that both of the method's exit paths leave the
same thing behind. Chosen over refreshing the baseline inside `deleteBackward()` (the shape
`insertText(_:)` uses) because the fault is the façade's own inconsistency, and fixing it there also
covers `setMarkedText(_:selectedRange:)` and every future kernel-driven mutation instead of one
witness. R7's warning that the GATE must not read the public `revision` property is untouched and
still correct — that is about not being fooled by `insertText(_:)`'s independent write, a different
question from what a completed sync adopts.

**Pinned by** `Tests/RichTextEditorUIKitTests/InputDec/IDBackendFormattingThenDeleteTests.swift`
(both corpus scenario shapes, the no-toggle control, and a façade-revision assertion) and
`IDTextStorageFacadeTests.test_anAttributeOnlyRevisionBump_isAdoptedIntoTheMutationBaseline` (the
mechanism, one layer down, and UNGATED — it needs no certified runtime). Each was confirmed to fail
against the pre-fix façade and pass after.

**Verified not to move anything else:** `IDBackendDifferentialTraceTests` still shows its
pre-existing 16 failures with **byte-identical assertion messages** before and after (diffed, all 16
lines); all four differential families were run on both sides of the fix with only
`inline-formatting` moving, and only downward (38→28 differences, 18→8 unexplained); every other
`.inputDec` suite that can be run in isolation stays green (84 tests, 3 failures — all three the
differential families' own).

**Not fixed here, and now the only thing left in this family:** the 8 residual `canonical`/
`inlineRuns` differences are a mirror–document divergence on the delete path that is independent of
the toggle — see its own row in §8.3(d).

### 8.8 Task D4d — the dropped marked-text caret, and the backward-delete cluster-range axis

Two of §8.3(d)'s rows, plus the row D4c left open. Both fixes are one mechanism each, and neither is
the mechanism that had been guessed.

#### Finding 1 — the uniform `+2` selection offset at `offered` (18 instances, all 9 scenarios)

`setMarkedText("to", selectedRange: {0, 0})` at caret 33 left the caret at 35 instead of 33.

**What it was NOT.** Not the structural-vs-plain-text axis class: the error is a constant equal to
the marked text's own length in all nine scenarios, including the three `interior-*` ones that cross
no boundary, while an axis fault compounds per boundary. Not a loss in the kernel forward either —
`IDTextEditorBackend+TextBackend.swift`'s `setMarkedText(_:selectedRange:)` hands `selectedRange` to
`kernelInput?.setMarkedText(text, selectedRange:)` intact.

**What it was, file:line.** `IDTextEditorBackendIntent.swift:51` (pre-fix):

```swift
case .markedText:
    return .setMarkedText(text: NSAttributedString(string: text),
                          replacing: selection.normalizedRange,
                          selectedRangeInMarkedText: NSRange(location: text.utf16.count, length: 0))
```

a FABRICATED end-of-marked-text caret. It had to be fabricated: the private controller drives the
composing edit back through `TGRichTextInputDecTextStorageFacade.replaceCharactersInRange:withString:`
— a raw range replace carrying no marked-text-relative anything — and
`IDTextEditorBackendClientBridge.prepareAndCommitReplacement` rebuilds the mutation from
`(range, text, intent)` alone. Downstream, `DocumentCanvasView.legacySetMarkedText(_:selectedRange:)`
(`+MarkedText.swift`) honours whatever it is handed: it places the caret at
`lo + selectedRange.location`, so `{2, 0}` landed it 2 past the start.

The value is load-bearing TWICE. That same body derives
`isPrediction: selectedRange.location == 0 && selectedRange.length == 0`, which
`refreshPredictionStyling()` paints the grey inline-prediction ghost from — so the fabricated value
also made every system inline prediction present as a CJK composition.

**Fix.** The caret travels the way the intent already travels: latched beside it
(`IDTextEditorBackend.latchMarkedTextIntent(selectedRange:)`) and CONSUMED —
read-and-cleared — by `prepareAndCommitReplacement`, mirroring the façade's own unconditional
`currentIntent` reset, so a `.markedText` transaction arriving from anywhere else (the
`keyboardInput:shouldInsertText:isMarkedText:` canvas thunk at
`TGRichTextInputDecCanvasCallbacks.m:140` — measured by R10 never to fire, but still the only other
writer) cannot inherit a stale caret. `{text.utf16.count, 0}` survives as the no-latch fallback,
which is exactly what CJK composition asks for; a control test pins that it still holds.

Result: inline-prediction 76/54/22 → 58/54/4. All 18 `selection` instances converge.

#### Finding 2 — the 4 `canonical` "merges" survived Finding 1's fix, and are a different bug

The brief's hypothesis was that a caret 2 off makes `delete-backward` take the wrong character. **It
is false, and the fix proved it: all 4 instances stood unchanged afterwards.** Two independent
reasons it could never have been true — `selection` at the intervening `accepted` checkpoint already
AGREED with stock in both arms, and `blocks` (read from the real document via
`differentialTopLevelBlockTexts()`) agreed with stock at `terminal` too. Nothing merged. Only
`canonical` — which reaches the recorder through `text(in:)` → the kernel →
`-[TGRichTextInputDecTextStorageFacade string]` → the mirror — was wrong.

**Root cause, measured.** Temporary `NSLog`s in `id_rangeOfCharacterClusterAtIndex:type:` and in the
façade's `replaceCharactersInRange:withString:` (reverted before commit), driving the corpus
scenarios transaction for transaction on a real `.inputDec` canvas:

```
before-boundary-accept-then-delete, at `delete-backward` (caret at plain 36):
  clusterAtIndex index=35 -> plain {35,1} -> structural {36,1}
  facade replace range={36,1} intent=deleteBackward
  document blocks ["Earlier sentence. I look forward to", "Later block stays."]   CORRECT
  mirror         "Earlier sentence. I look forward to Later block stays."         deleted plain 36 = "\n"
```

Task D3c (`4f1ef36e21`) made TWO changes in ONE commit that contradict each other:

1. `TGRichTextInputDecLayoutController.id_rangeOfCharacterClusterAtIndex:type:` converts its answer
   plain → STRUCTURAL before returning;
2. `TGRichTextInputDecTextStorageFacade.replaceCharactersInRange:withString:` treats an incoming
   `.deleteBackward`/`.markedText` range as ALREADY PLAIN and skips conversion.

The kernel is a pure pass-through between them — it asks for the cluster before the caret and hands
that very range back as the replace range (instrumentation also shows it feeding the same value into
`id_textRangeForCharacterRange:`, whose own D3e comment independently records that the private
controller speaks the plain-text axis). So the mirror's delete landed `structural - plain` units late
on EVERY backward delete — at least 1, always, because of the document's own leading open token.

Why it hid for three tasks: only `canonical`/`inlineRuns` read the mirror while `blocks` reads the
document, so a wrong mirror looks like a partial divergence rather than a broken editor; and in the
corpus's `interior-accept-then-delete` the characters on both sides of the caret are spaces, so the
wrong delete produced an IDENTICAL string. Measured on plain "Alpha"/"Beta" it is unmissable:

| caret | document (correct) | mirror, pre-fix |
| --- | --- | --- |
| end of "Alpha" | `["Alph", "Beta"]` | `"AlphaBeta"` |
| start of "Beta" (a merge) | `["AlphaBeta"]` | `"Alpha\neta"` |
| `"Be|ta"` | `["Alpha", "Bta"]` | `"Alpha\nBet"` |

**Fix.** `id_rangeOfCharacterClusterAtIndex:type:` returns the plain range it computed — one axis in,
the same axis out. D3c's cited reproduction (a "start of Beta" backspace landing inside "Alpha") was
the pre-facade-exception behaviour, repaired by the OTHER half of that same commit; re-verified here
(`IDBackendBackwardDeleteMirrorTests`, 4 tests, all four failing before the change and passing after).

Result: inline-prediction 58/54/4 → **54/54/0 PASS**, and inline-formatting 28/20/8 → **20/20/0
PASS** — D4c's §8.7 residual was this same defect.

#### Verification

- All four families, one invocation, K1 (23F73): `ime` 256/192/64 (byte-identical to before),
  `autocorrection` 144/144/0 PASS, `inline-formatting` **20/20/0 PASS**, `inline-prediction`
  **54/54/0 PASS**. 3 of 4 families now pass; only `ime` is red.
- Every other `.inputDec` suite (44 classes, 283 tests, one invocation, `IDBackendFamily7Tests`
  excluded — it hangs on pasteboard access, pre-existing per D4c): **13 failing tests / 18 failures,
  the IDENTICAL set before and after**, measured by reverting all five changed sources to
  `53aa8c2f60` and re-running (273 tests then; the 10 new tests are the difference).
- `IDBackendDifferentialTraceTests`: **9 tests, 16 failures before and after — the count did not
  move.** Two of the sixteen MESSAGES changed, both from the cluster-range fix:
  `backspace-merges-paragraphs` content went from `"Alpha\neta"` (wrong) to `"AlphaBeta"` (correct,
  matching legacy), leaving only the event-ORDER divergence in that assertion; and
  `caret-across-paragraph-boundary` moved the ID-side caret from 11 to 8 against legacy's 9, an
  assertion that failed before and fails after for the same still-open reason the scenario's own
  comment names. Nothing regressed against STOCK: the corpus's `selection` field is 0 unexplained in
  three families and unchanged in `ime`.

### 8.9 Task D4f — the renderable-position snap, and the composition commit that registered no undo

`ime` was the last red family: **256 differences / 192 explained / 64 unexplained**, localised by D4b
to the `*-after-boundary-*` composition scenarios and presenting as doubled characters and leftover
composed text after undo. It was **two independent defects**, and the split does not follow the
scenario names: 32 fields were the plain-vs-structural axis class, 32 were not.

#### Finding 1 — `position(from:offset:)` did not snap to a renderable slot (32 fields)

**The axis table (the deliverable, and the thing that stops this recurring).** Every range or offset
crossing this seam, with the axis it RECEIVES and the axis its consumer ASSUMES:

| Site | Direction | Receives | Consumer assumes | State |
| --- | --- | --- | --- | --- |
| `id_characterRangeForTextRange:` | outgoing | structural (resolved positions) | the private controller indexes `-[…Facade string]`, i.e. PLAIN | converts, R7 |
| `id_attributedTextInRange:` | outgoing | structural | `documentPlainTextInRange:` takes STRUCTURAL | passes structural through, R7 |
| `id_textRangeForCharacterRange:` | incoming | PLAIN (controller bookkeeping over `mirror`) | `documentClampedOffset:` is a STRUCTURAL clamp | converts, D3e |
| `id_rangeOfCharacterClusterAtIndex:type:` | incoming index / outgoing range | PLAIN in | the kernel feeds the answer straight back as a PLAIN replace range | plain in, plain out, D4d |
| façade `replaceCharactersInRange:withString:` | incoming | structural, EXCEPT `.deleteBackward`/`.markedText`, which are already PLAIN | `mirror` is PLAIN; the document mutation is STRUCTURAL | intent-scoped conversion, D3c |
| `IDTextEditorBackendIntent.mutation(for:…)` `.deleteBackward` `proposedRange` | incoming | plain (from the façade) | **nothing** — `legacyApplyMutation` discards it | inert either way |
| `IDTextEditorBackendIntent.mutation(for:…)` `.setMarkedText` `replacing:` | incoming | `state.selection`, STRUCTURAL | `legacyApplyMutation` seats the canonical anchor/head, STRUCTURAL | agrees |
| **`id_positionFromPosition:offset:affinity:`** | outgoing | structural + a raw integer step | callers count one step = **one renderable position** (Legacy snaps; the corpus driver's `IDTelegramPositionForCharacterIndex` documents the map as "monotone and injective") | **was raw — THIS TASK** |
| `id_positionFromPosition:inDirection:…` | outgoing | structural | renderable | snapped since D3c |
| `id_beginningOfDocument` / `id_endOfDocument` | outgoing | structural | renderable | snapped since R7 |

The last untreated row was the stepping primitive itself. `LegacyRichTextInputBackend
.position(from:offset:)` is one line — `LegacyTextPosition(legacyCanvas.legacySnapToRenderable(n,
forward: offset >= 0))` — and the ID backend's counterpart clamped and stopped. Both drive the SAME
`DocumentCanvasView` over the SAME axis, so this was a divergence in one witness.

**Measured** (a temporary probe suite driving both backends in one process, on `["Alpha middle
omega", "Second block remains unchanged."]`; `plain(S)` is `documentPlainTextInRange:(0,S)`'s result
length, `R` marks a renderable slot):

```
plain(S)/renderable:  … 19:18R  20:19-  21:19R  22:20R …
legacy positionWalk (absolute):  … 19, 21, 22 …          <- skips the gap
inputDec positionWalk (absolute):  … 19, 20, 21, 22 …    <- visits it
```

Structural 20 and 21 share character index 19, so the map stopped being injective and the corpus's
own aim (`IDTelegramPositionForCharacterIndex`, which takes the FIRST position matching a character
index) resolved the second paragraph's first character to the gap slot.

**What that cost downstream is not in this file at all.** `DocumentCanvasView.legacySetMarkedText`
fails `isBodyParagraphPosition(lo)` for a gap caret and degrades composition to `commitMarkedText()`
plus a plain `insertText(_:)`. So the provisional character was committed as ordinary text, no
canvas-side `markedRange` was established, and the next composition update inserted BESIDE it — the
`blocks` divergence (`"kかSecond …"` against stock's `"かSecond …"`). The nested `insertText` also
drove a SECOND `replaceCharactersInRange:withString:` inside the first, and both frames applied the
same `{19,0} <- "k"` to the mirror — the `canonical` divergence (`"…\nkkSecond block remains
unchanged"`). Instrumented directly (temporary `NSLog`s in the façade, reverted before commit, the
file restored and re-verified byte-identical to `HEAD`):

```
PROBE-FACADE enter range={19,0} string=k intent=markedText
PROBE-FACADE enter range={20,0} string=k intent=insertText   <- NESTED, from the degraded path
PROBE-FACADE apply plainRange={19,0} string=k                 <- inner
PROBE-FACADE apply plainRange={19,0} string=k                 <- outer: the mirror takes it twice
```

**Fix:** `id_positionFromPosition:offset:affinity:` snaps through `TGSnapToRenderableOffset` with
`forward: offset >= 0`, matching Legacy member for member. `TGSnapToRenderableOffset` also gained the
cross-direction fallback `snapToRenderable` has always had (`forward ? (atOrAfter ?? atOrBefore) :
…`) — without it a `+1` step off the document's last renderable position answered
`documentUTF16Length`, which is never renderable, so the walk stepped one past the end where
legacy's stops.

**This also settled the caret-stepping question D4d self-disclosed.** Both consumers wanted the same
decision: `IDBackendDifferentialTraceTests`' `caret-across-paragraph-boundary` walked character
indices 5 → 6 → **6** and now walks 5 → 6 → **7**, exactly legacy's walk, and the scenario **no
longer appears in that suite's failure list at all**. D4d's own caveat — "not established that 8 is
better than 11" — is resolved: neither was right, because the step was never snapping.

#### Finding 2 — `unmarkText()` never registered the composition's undo step (32 fields)

The remaining four scenarios are `{japanese-romaji, simplified-chinese-pinyin} ×
{before, after}-boundary-return-commit-then-undo`, 8 fields each. **Two of them are BEFORE-boundary**,
which is what rules this out of the axis class: they failed identically to the after-boundary pair,
before and after Finding 1's fix, and only at the `terminal` (post-undo) checkpoint. Stock returns to
the original text and reports `canRedo == 1`; this backend kept the composed text and reported
`canRedo == 0` — an undo that popped an EMPTY group.

A composition's single undo step is registered by `DocumentCanvasView.commitMarkedText()`
(`+MarkedText.swift`), from the whole-document snapshot `legacySetMarkedText` captures at composition
START. That body is reachable only through `legacyApplyMutation`'s `.unmarkText` case — i.e. only
through the document client. `IDTextEditorBackend.unmarkText()` forwarded to the kernel (whose own
`unmarkText` mutates no character and so never reaches the storage façade) and then called
`commitMarkedTextStateIfComposing()`, which retires `state.markedRange` and nothing else.

The second half was equally quiet and equally well documented at the time it was written:
`IDTextEditorBackend.compositionSnapshot` was a hardcoded `nil` with a no-op writer, justified —
correctly, then — as "self-consistent: no caller can observe a difference," because nothing on this
backend read it. `commitMarkedText()` is that reader (`if let snap { registerUndo(…) }`), so a routed
`.unmarkText` alone would still have registered nothing. **Both halves had to land together**, which
is why they are one commit.

**Fix:** real `compositionSnapshotStorage` (matching `LegacyRichTextInputBackend`'s member exactly,
cleared in `detach()` and in `commitMarkedTextStateIfComposing()`), plus a narrow
`commitComposedTextInDocument()` that drives `.unmarkText` through
`prepareMutation`/`commitPreparedMutation`. `.unmarkText` is the one mutation case carrying neither
range nor text, so it cannot ride the façade's crossing point the way every other intent does.
**Order is load-bearing:** the document commit must run BEFORE
`commitMarkedTextStateIfComposing()`, which clears the very `state.markedRange` that
`commitMarkedText()`'s own guard reads back through `inputBackend.markedRange`.

#### What did NOT turn out to be this class

- **`backspace-merges-paragraphs`** (`IDBackendDifferentialTraceTests`), which the D4f brief asked
  about explicitly: **not this class, and not a content defect at all.** Both arms now report content
  `"AlphaBeta"` AND selection `6-6`; only the notification ORDER differs (`canvasContentSizeChanged`
  interleaves differently, and the legacy arm emits one more). That is the same shape as the corpus's
  own `editor-notifies-the-input-delegate-where-stock-stays-silent-inputdec` expectation family —
  canvas-level bracket ordering, not an axis or a mutation. Left as it is.
- **`.deleteBackward`'s `proposedRange`.** Worth recording because it looks like a live axis
  consumer and is not: `IDTextEditorBackendIntent` passes the façade's (plain) range into
  `.deleteBackward(selection:proposedRange:)`, and `DocumentCanvasView.legacyApplyMutation` discards
  it (`case .deleteBackward(let selection, _)`). Its axis cannot matter today, which is why D4d's
  change to the cluster range could not disturb the document side.

#### Verification

- **All four families, one invocation, K1 (23F73): `ime` 192/192/**0** PASS**, `autocorrection`
  144/144/0 PASS, `inline-formatting` 20/20/0 PASS, `inline-prediction` 54/54/0 PASS. **4/4.** The
  three already-green families are byte-identical to their D4d values.
- **Every `.inputDec` suite** (51 classes, one invocation, `IDBackendFamily7Tests` excluded — it
  hangs on pasteboard access, pre-existing per D4c): **315 tests, 17 failing tests / 33 failures**.
  Control-measured by reverting all three changed sources to `7b4f7df964` and moving the two new test
  files aside: **299 tests, 18 failing tests / 35 failures**. Diffed per test: the ONLY changes are
  `IDDifferentialTests.test_imeFamilyMatchesStock` 1 → 0 and
  `IDBackendDifferentialTraceTests.test_selectionScenariosMatch` 4 → 3. **No test's failure count
  increased and no new test fails.** (The 16-test difference is the two new files.)
- `IDBackendDifferentialTraceTests`: **9 tests, 16 → 15 failures.** The scenario that stopped
  diverging is `caret-across-paragraph-boundary`. The other 15 are unchanged.
- New suites, both `XCTSkipUnless(IDTextEditorBackend.isSupported())`-gated:
  `IDBackendRenderablePositionSteppingTests` (10 tests — **7 failed before the fix**, and the two
  controls plus the legacy-reference arm passed) and `IDBackendCompositionUndoTests` (6 tests — **5
  failed** with the Swift half reverted, both controls passing).

### 8.10 Task F4 — autocorrect and spelling: the differential corpus could not see any of it

A hand-report on a real debug build ("no autocorrect, no red underlines, both fine with the flag
off") that this document's own instrument is structurally blind to, and it is worth saying why: the
corpus compares DOCUMENT and SELECTION OUTCOMES of scripted witness calls. Autocorrection candidates
and spelling underlines are produced by agents OUTSIDE that loop — UIKit's keyboard, configured from
the private input controller's own `UITextInputTraits`, and a private checking controller driving the
canvas asynchronously. The autocorrection family being 144/144 and `IDDifferentialTests` 4/4 was true
before this task and stayed true after it; neither number moved, in either direction, for any of the
five defects F4 fixed. **A green differential run is evidence about outcome parity, and about nothing
that the OS drives on its own schedule.**

What actually found them, in order of yield:

1. **The upstream host source** (`~/Documents/InputDec`, the reference `IDBlockTextView` the kernel
   was developed against, which the vendored carve dropped). It answered "what must a host do that we
   do not do" directly, where four rounds of inference had not.
2. **A differential PROBE against Legacy in the test host** — not the corpus, just "build both arms,
   focus both, ask the same question, print both answers". `canvas.nativeChecker` non-nil vs nil;
   `text(in: nativeTextRange(...))` `" wrol"` vs `nil`; `spellCheckTargets` a real range vs
   `(nil, nil)`.
3. **Reading the private controller's own state** (`kernelInput.textInputTraits` through KVC), which
   is where the missing mechanism was visible as three zeroes.

`DIVERGENCES.md` entry 22 carries the full account of all five, plus a sixth (pre-existing) trap this
task found and closed, and the three of F3's five unverified-semantics rows that upstream has now
RESOLVED — all three of which this port still diverges on, deliberately and on the record.

### 8.6 Reproducing this

```sh
cd submodules/TelegramUI/Components/RichTextEditor
DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDDifferentialTests   # K3, certified band
DEVICE=A33A46AF-33DC-4D8E-8026-51473ED5D615 Scripts/iostest.sh RichTextEditorUIKitTests/IDDifferentialTests   # K2, uncertified band (iOS 27.0)
```

Expected today (after Task D4f — §8.9): **4 tests, 0 failures.** All four families pass.
(As recorded at D4b this was 3 failures; D4c closed part of inline-formatting, D4d closed the rest of
it plus all of inline-prediction, and D4f closed `ime`. The K2 leg has not been re-measured since
D4b, so the "no drift found" finding in §8.4 predates every fix from D4c onward.) This task ran each family
as its own `-only-testing:` invocation (8 total: 4 families × 2 simulators) rather than the whole
class in one call, to stay inside the 10-minute per-foreground-call budget while iterating on the
expectations table; a single `Scripts/iostest.sh RichTextEditorUIKitTests/IDDifferentialTests`
invocation completes in well under a minute per simulator (ime, the largest family, took ~2 seconds)
so there is no need to chunk it for a one-shot reproduction.
