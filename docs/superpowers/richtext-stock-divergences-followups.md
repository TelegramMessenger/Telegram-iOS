# Divergences from stock UIKit that stage 1 deliberately did NOT change

**Written 2026-08-24, at the Phase-6 gate.** The Phase-0b differential oracle compares the editor against
stock UIKit over 68 real IME/autocorrect/prediction scenarios. It found one **correctness defect**, which
was fixed, and three **behavioural divergences**, which were not. This file records why, so nobody re-opens
them as seam regressions and so the product owner has a precise list.

## The distinction that decides all four

Stage 1's charter is **zero behaviour change**. So the test is not "does this differ from stock" — several
things do — but **"is this something the seam introduced, or something the seam merely routed?"**

- **Introduced, or plainly wrong output → fix.** The marked-text replace bug produced a *wrong document*
  (`"country"` where `"countryBeta"` was correct). No characterization test pinned the broken output, so
  fixing it changed nothing any pin had frozen. Fixed in `d636d9b808`.
- **Pre-existing and PINNED IN PHASE 0 → do not touch.** Phase 0 (Tasks 3–8) ran *before any seam work* and
  exists to freeze the editor's behaviour so later tasks cannot alter it silently. A divergence pinned there
  is, by construction, behaviour the branch is forbidden to change — and changing it would break the very
  tests whose job is to catch unintended change.

All three below are the second kind. **Each was verified as Phase-0-pinned before this disposition was
written**, not assumed.

---

## 1. Extra `selectionDidChange` during a live composition — **the one most worth a keyboard-level look**

**What differs.** On `setMarkedText`, stock emits `[textWillChange, textDidChange]`; the editor emits that
*plus* `selectionWillChange`/`selectionDidChange`. On a programmatic `replace(_:withText:)` or
`insertText(_:)`, stock emits **nothing at all** while the editor emits a full text+selection bracket per
mutation.

**Why it matters.** Unsolicited selection traffic during a composition is exactly what perturbs
autocorrection and inline prediction — the keyboard can read it as the user having moved the caret.

**Why stage 1 did not change it.** `legacySetMarkedText`'s body is **pre-seam and untouched** (Task 29
renamed the witness, not the body). The two-bracket shape — a `notifyingContentChange` text bracket plus a
separate, unsuppressed `notifyingSelectionChangeIgnoringCoalescing` — is pinned **by exact equality** in
`DelegateTraceCharacterizationTests.test_setMarkedText_emitsATextBracketThenASeparateSelectionBracket`
(created `5ffebe533b`, Task 3) and `MarkedTextTraceCharacterizationTests
.test_compositionBeginUpdateCommit_traceAndRevisions` (created `5c87b4059c`, Task 7).

**The expectation entry is honest about it**: named `NOT BLESSED`, and its predicate is a **subsequence**
test — a notification the editor *fails* to send still fails the run. It excuses extra events, never missing
ones.

## 2. No selection rects for a collapsed range

Stock returns a rect for a caret-width selection; the editor returns none. Pinned by
`GeometryWitnessMatrixTests` (created `f181ab8879`, Task 5). Lower stakes — it affects callers that ask for
selection geometry at a caret — but it is the same category.

## 3. No undo step for an uncommitted composition

Stock registers one; the editor does not, so undo during a live composition behaves differently. Pinned by
`MarkedTextTraceCharacterizationTests` (Task 7).

---

## What a follow-up project would need to do

Not simply "fix them". Each of the three is **frozen by a Phase-0 pin**, so changing one means:
1. deciding the new behaviour is correct — for (1) that is a keyboard-level question about what UIKit's
   input system does with selection notifications mid-composition, and is best answered on a device;
2. **re-recording the affected characterization expectation, in a commit that says so** — the Phase-6 gate
   asserts no expectation changed *after its creating commit*, so an intentional change must be visible and
   argued, not slipped in;
3. re-running the differential corpus, which will now *report the change*, and removing or narrowing the
   corresponding expectation entry.

That third step is the point of having built the oracle: after this branch, a change to any of these three
is **measurable against stock** rather than a matter of opinion.

## Also recorded: two unexercised capability claims

`set-traits` (0 of 612 transactions) and `annotationRanges` (0 of 68 scenarios) are asserted capabilities the
corpus never drives, and only one execution order was run. They are claims, not coverage, and are labelled
as such rather than counted as passes.
