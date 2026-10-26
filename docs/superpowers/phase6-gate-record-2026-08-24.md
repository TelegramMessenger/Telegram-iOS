# Phase 6 gate record — stage 1, `richtext/input-backend-seam`

**Run 2026-08-24 against `e786914e47`.** Every figure below is the output of the item's own command, run on this
tree. Where an item's command was wrong, that is recorded as a finding rather than worked around silently.

**VERDICT: every automatable item PASSES. The gate CANNOT be closed by this record**, because item 3's
manual half and completion bullet C2 require a human on a simulator, **The three named differences have since been DECIDED** (out of stage-1
scope, evidenced — Outstanding item 3). Nothing here is blocked; the remainder is not machine work.

---

## Two gate commands were themselves defective, and both are corrected in the plan

**Items 4 and 5 specified `swift test --filter RichTextEditorCoreTests.<Suite>`. That command selects
NOTHING on this toolchain and prints `Executed 0 tests, with 0 failures` — a vacuous pass.** I probed the
mechanism rather than assuming: `--filter` emits no summary line here **for any suite**, so it was never a
working command. A gate-runner following either item literally would have recorded green having tested
nothing. The suites are fine; only the command was wrong. Both now read
`Scripts/iostest.sh RichTextEditorCoreTests/<Suite>`.

**Item 10's grep over-reports.** `grep "@available(iOS 1[4-9]…"` counts **doc comments**; the two hits
under `InputBackend/` are both `///` lines discussing an iOS-18 property. Real raised-floor
**declarations**: **0**.

---

## Gate items

| # | Item | Result |
| --- | --- | --- |
| 1 | All pre-existing tests pass | **2737 executed (UIKit 2350 / 5 skipped + Core 387), 0 failures, 0 traps** — against a pre-seam floor of 1623 |
| 2 | Eight contract suites for `.legacy` | **all 8 green**: Mutation 9, Revision 6, Publication 8, Selection 7, MarkedTextPolicy 11, Reentrancy 15, AttachDetach 6, EditPolicy 6 — 68 tests, 0 failures |
| 3 | No intentional behavior/visual change | **automated half PASSES** (see the item's own corrected body: 15 commits touch `Characterization/`, 8 post-creation, all adjudicated — no asserted value moved). **Manual 22-item checklist OUTSTANDING — the user's.** |
| 4 | UIKit witnesses contain routing only | **RouterWitnessBodyTests 2 tests, 0 failures** (via the corrected command) |
| 5 | No private selector names in shared contracts | **InputBackendSourceBoundaryTests 33 tests, 0 failures**; allow-list is the **three** files of D11-as-amended |
| 6 | Backend identity lifetime-fixed | both named tests green in the full run; **`inputBackend =` reassignment offenders: 0** |
| 7 | External changes use explicit synchronization | **ExternalSynchronizationTests 22 tests, 0 failures**; BackendRevisionContractTests 6/0; `test_exactlyOneWritableSelectionAuthority` green |
| 8 | Bounded large-selection request proven | **BoundedSelectionGeometryTests 11 tests, 0 failures** (D26: proven, not adopted) |
| 9 | TK1 and TK2 pass the same suite | **118 legs — 59 tk2 / 59 tk1, ZERO asymmetry, 0 failures**; `MATRIX_MIN_SUITES` **59**, matching discovery |
| 10 | SwiftPM + Bazel at the iOS 13 floor | `swift build` 0; **app Bazel build exit 0, 3639 actions**; raised-floor declarations **0** |
| 11 | Contract suites backend-parameterised | `BackendContractCases` names the concrete backend only inside `makeBackend()` |
| 11b | The two D33 setters decided, not forgotten | **DECIDED: KEEP** — 7 call sites, 4 structurally required; rewritten item records it |
| 12 | Differential corpus green | **LegacyDifferentialTests 6 tests, 0 failures** — 4 families, 68 scenarios / 612 transactions; artifacts all present |
| 23 | D38's tautological guard decided before stage 2 | **stage 1 CANNOT fail this by construction** — it is a stage-2 entry condition, unchecked deliberately |

## Completion definition

| # | Bullet | Result |
| --- | --- | --- |
| C1 | Sole backend implementation | **exactly one** conformer in `Sources/` |
| C2 | Behavior unchanged | depends on item 3's manual half — **OUTSTANDING** |
| C3 | Backend exclusively owns input state and UIKit identity | authority + door rules at zero — **qualified by R6's KNOWN LIMITS**: the rule sees only what is *textually* minted or unwrapped; **type inference and typealias laundering are demonstrated holes** |
| C4 | Canvas is a thin router | ⚠️ **PARTIAL — D27.** `func legacy` residue: **39** |
| C5 | Clients own their domains | ⚠️ **PARTIAL — D27**, same row |
| C6 | Boundaries covered by tests | boundary suite 33/0; router-body suite 2/0 |
| C7 | TK1 + TK2 pass the shared suite | 59/59, zero asymmetry |
| C8 | SwiftPM + Bazel at the floor | both green |
| C9 | No InputDec production code or private API | **ObjC under `Sources/`: 0; `ID*`-named under `Sources/`: 0** (the Phase-0b harness is test-target-only, and Bazel's `BUILD` never sees it) |

---

## Outstanding — none of it machine work

1. **The 22-item manual checklist** (item 3 / C2), on a simulator with "Force Text Field v2" on.
2. **Three runtime checks no suite here can see:** autorepeat typing latency (Task 40b); an IME composition
   surviving rotation / keyboard-resize (Task 41); floating cursor + teardown mid-gesture, confirming no
   bright caret remains (Task 42).
3. ~~Three candidate defects awaiting a decision.~~ **DECIDED 2026-08-24 — see
   `docs/superpowers/richtext-stock-divergences-followups.md`.** All three were verified as **pre-seam
   behaviour PINNED IN PHASE 0** (Tasks 3, 5 and 7 — suites created *before any seam work*, whose purpose
   is to stop later tasks changing behaviour silently). Stage 1's charter is zero behaviour change, so
   altering any of them would be both the forbidden thing **and** a break of the tests that exist to catch
   it. Recorded as product follow-ups with what a change would actually require. **Not blockers, and they
   need nothing further from this branch.**
4. **Two unexercised capability claims:** `set-traits` (0 of 612 transactions) and `annotationRanges`
   (0 of 68 scenarios). Only one execution order was run.
