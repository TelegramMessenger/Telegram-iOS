#!/bin/bash
# Runs the backend seam suites on BOTH layout engines, SERIALIZED on one simulator.
# The spec's Phase-6 gate is scoped to the backend semantic suite, not the 1623-test legacy suite
# (deviation D20): several legacy tests pin TextKit-2 numbers and belong to the engines themselves.
#
# The suite list is DERIVED from the tree: every `final class <Name>: XCTestCase` declared under
# Tests/RichTextEditorUIKitTests/{Characterization,InputBackend,Support,Differential,InputDec}. No
# task ever edits a hard-coded list, so a suite added by Tasks 20-44 cannot silently miss the matrix.
#
# TASK 9d ADDED THE FOURTH ROOT. Phase 0b's differential suites lived under `Differential/` from Task
# 9a onward and were discovered by NOTHING until now — the Phase-6 gate names all four roots and says
# the gate "certifies every class under T/{Characterization,InputBackend,Support,Differential}", so
# three roots was the script disagreeing with the gate it serves.
#
# TASK B1 ADDED THE FIFTH ROOT (`InputDec`). ADD, do not replace — a straight paste of an older task
# brief's 4-line ROOTS block here would silently DROP the `Differential` root and its 4 suites from
# every matrix run (nothing fails; the matrix just quietly covers less). `InputDec/` already held two
# suites (`ContractManifestTests`, `ExceptionGuardTests`, from Tasks A6/A8) that were never in the
# matrix because this root didn't exist yet — this task both registers the root and adds a third
# suite (`CanvasSubclassPerformanceTests`), so the discovered count jumps by 3, not 1.
set -o pipefail
ROOTS="Tests/RichTextEditorUIKitTests/Characterization
Tests/RichTextEditorUIKitTests/InputBackend
Tests/RichTextEditorUIKitTests/Support
Tests/RichTextEditorUIKitTests/Differential
Tests/RichTextEditorUIKitTests/InputDec"
discover() {
  for r in $ROOTS; do
    [ -d "$r" ] || continue
    # The alternation on the BASE class is required, not cosmetic: decision 10 makes the eight
    # contract suites `class …: BackendContractCases`, and Phase 0b adds differential suites.
    # A suite the regex misses is silently NOT run — `-only-testing:` on an absent class is not
    # an error — so the matrix would report success having certified nothing.
    #
    # TASK C3 added `BackendSemanticContractCases` (this task's own parameterised base — see
    # `Tests/…/InputDec/BackendSemanticContractCases.swift`) AND the eight STAGE-1 CONCRETE
    # contract-suite names (`Backend{Mutation,Revision,Publication,Selection,MarkedTextPolicy,
    # Reentrancy,AttachDetach,EditPolicy}ContractTests`). The eight are needed for a reason this
    # task's own brief got wrong: its Step 6 assumed adding `BackendContractCases` to the
    # alternation would ALSO surface Step 7's eight `IDBackend*ContractTests` subclasses — but
    # `grep` matches only the class's DIRECT stated base on one line, and Step 7's subclasses
    # extend the stage-1 CONCRETE classes (`class IDBackendMutationContractTests:
    # BackendMutationContractTests { … }`), not `BackendContractCases` itself. Without their own
    # alternation entries those eight grandchildren are silently never discovered — proven
    # empirically in this task: adding only `BackendSemanticContractCases` (the task supplement's
    # literal "minimal edit" ruling) leaves the count at 72 with all eight `IDBackend*ContractTests`
    # classes missing from the list; the full alternation below measures 80. See `task-C3-report.md`.
    grep -rhoE '^(final )?class [A-Za-z0-9_]+: (XCTestCase|BackendContractCases|BackendSemanticContractCases|BackendMutationContractTests|BackendRevisionContractTests|BackendPublicationContractTests|BackendSelectionContractTests|BackendMarkedTextPolicyTests|BackendReentrancyTests|BackendAttachDetachTests|BackendEditPolicyTests)' "$r" \
      | awk '{print "RichTextEditorUIKitTests/"$(NF-1)}' | sed 's/:$//'
  done | sort -u
}
SUITES="${SUITES:-$(discover)}"
COUNT=$(echo "$SUITES" | grep -c .)
echo "=== matrix over $COUNT suites"
# Tripwire: after Phase 4 the discovered set is large. A collapse to a handful means the discovery
# globs stopped matching (a directory rename), which would make the gate vacuous.
# FINAL BRANCH REVIEW: the default was 13 against a discovered 55 — 42 suites could vanish and this
# tripwire would still pass. Gate item 9 says Task 9d set this to the measured count; Task 9d is part of
# Phase 0b and NEVER RAN, so the placeholder survived. Set to the measured 55.
# TASK 9d (Step 5): re-measured at 59 and set here. The +4 is the `Differential/` root this task added
# to ROOTS above — DifferentialCorpusLoadTests, TelegramDifferentialHostTests,
# TelegramDifferentialRecorderTests (Tasks 9a-9c) and LegacyDifferentialTests (this task). Confirm with
# the gate's own command, which uses the same alternation and the same four roots:
#   grep -rhoE '^(final )?class [A-Za-z0-9_]+: (XCTestCase|BackendContractCases)' \
#     Tests/RichTextEditorUIKitTests/{Characterization,InputBackend,Support,Differential} \
#     | awk '{print $(NF-1)}' | sed 's/:$//' | sort -u | wc -l
#
# TASK B1: re-measured at 62 and set here (controller-verified on this tree, superseding the B1
# brief/supplement's stale 49→52 arithmetic — this repo's 4-root total was already 59, not 49, before
# this task ran). The +3 is the newly-registered `InputDec/` root: ContractManifestTests (A6) +
# ExceptionGuardTests (A8), both pre-existing but never discovered until this task registered the
# root, plus this task's own new CanvasSubclassPerformanceTests. Confirm with the gate's own command
# over all five roots:
#   grep -rhoE '^(final )?class [A-Za-z0-9_]+: (XCTestCase|BackendContractCases)' \
#     Tests/RichTextEditorUIKitTests/{Characterization,InputBackend,Support,Differential,InputDec} \
#     | awk '{print $(NF-1)}' | sed 's/:$//' | sort -u | wc -l
#
# TASK C3: re-measured at 80 and set here (controller-verified via this file's own `discover()`
# pipeline, not a re-implemented regex — see `task-C3-report.md`). C0-C2 had already brought the
# pre-C3 count to 69; this task's own two new files (`BackendSemanticContractCases` + its two
# subclasses) add 3, and the eight new `IDBackend*ContractTests` subclasses (Step 7, decision 10)
# add 8 more — 69 + 3 + 8 = 80. Confirm with `Scripts/matrix.sh 2>&1 | head -1`.
#
# TASK D1: re-measured at 104 and set here (same `discover()` pipeline — piping through `head -1`
# to read just the count is UNSAFE now and must not be used again: the old default of 80 was BELOW
# the true 104, so `head -1` closing the pipe after one line no longer forces the SIGPIPE-before-
# the-check timing the C3 measurement relied on, and a `Scripts/matrix.sh 2>&1 | head -1` observed
# here during this task actually started running the real per-suite loop on the (then still
# undifferentiated) default device before the pipe closed. The C0-C13/R1-R12 tasks (24 tasks) grew
# the count 80 → 104: 36 of the 104 are `ID*` (the InputDec backend's own suites — Family1-11,
# the harnesses, the eight `IDBackend*ContractTests` grandchildren, and the newer
# `IDTextEditorBackend*`/`IDClientBridgeSelectorConformanceTests`/`IDTextStorageFacadeTests` additions),
# 68 are everything else (legacy + shared contract/differential suites). Confirm with
# `Scripts/matrix.sh 2>&1 | tee /tmp/matrix.log | head -1` (redirect to a file, never bare `head`,
# so a low/stale floor can't silently kick off a real run before you've seen the count) or, cheaper,
# by re-running this file's own `discover()` in a subshell.
if [ "${MATRIX_MIN_SUITES:-104}" -gt "$COUNT" ]; then
  echo "matrix.sh discovered only $COUNT suites, expected >= ${MATRIX_MIN_SUITES}"; exit 2
fi
# Device split. Every ID suite runs on K3; everything else on K1 (the repo's designated testing sim).
#
# CORRECTED BY TASK D4b: K1 and K3 are BOTH iOS 26.5 on this host (only K2 is 27.0), so this split is
# a LOAD-BALANCING/convention choice, NOT an OS-band comparison. Task D1's original comment here
# claimed a K1 run of an ID suite would show "how far the certified ABI travels" — false: K1 *is* the
# certified band. The real cross-band answer came from D4b running the 612-transaction corpus on K2
# (iOS 27.0): identical per-family counts, no crashes. If you want an uncertified-OS leg, use K2.
# The split is derived from the discovered suite NAME — no second list to keep in sync, and a new
# ID suite lands on the right device for free.
#
# DECISION 2 (2026-08-17) changed what a K1 run of an ID suite MEANS. The gate is now a 17.0
# floor, not an exact build match, so on K1 `isSupported()` may well answer YES and the ID suites
# will really execute rather than XCTSkip. That is not a bug — it is the first evidence of how far
# the certified ABI travels, and Task D5 requires it to be recorded. Do NOT "fix" this by pinning
# ID suites away from K1; if anything, an uncertified-OS run is now the more informative leg.
K1=CA0A2186-0F4A-425B-B3B1-9B61E5FF01A9
K3=FA6F7462-AA97-42FE-9E57-8DA0593CE756
# TASK D1 pasteboard-stall exclusion. `IDBackendEditPolicyTests` and `IDBackendFamily7Tests` each
# contain `test_allowsPasteFalse_makesCanPerformPasteFalse`, which stalls ~175s-12min on a real
# system "Allow Paste" permission dialog once it reaches the live kernel — found by Task R1,
# re-confirmed by R2, left deliberately failing (not fixable in this environment) by R12; see
# `Sources/RichTextEditorUIKit/InputBackend/InputDec/DIVERGENCES.md`, R12's "Cluster 11" writeup
# (`task-R12-report.md`, "Cluster 11 — paste `canPerformCommand`, the pasteboard-dialog hazard").
# Both suite names match `ID*`, so without this exclusion BOTH would route to K3 and run TWICE
# each (tk2 + tk1) — four stalls, ~12+ minutes of pure hang on top of an already-long matrix.
# Excluded HERE by TEST NAME, not by suite (each suite has other tests that must still run), the
# same mitigation R1/R2/R12 already used via `-skip-testing`. An undocumented exclusion in a
# coverage script is how suites silently stop being covered — this comment is that documentation.
PASTE_SKIP="-skip-testing:RichTextEditorUIKitTests/IDBackendEditPolicyTests/test_allowsPasteFalse_makesCanPerformPasteFalse -skip-testing:RichTextEditorUIKitTests/IDBackendFamily7Tests/test_allowsPasteFalse_makesCanPerformPasteFalse"
BASE_EXTRA="${EXTRA:-}"
fail=0
# ENGINES defaults to both, unchanged from every prior invocation of this script. The override
# exists ONLY so a caller can split an otherwise-single ~208-suite run (104 suites x 2 engines,
# each suite its own `xcodebuild` invocation) across more than one foreground shell call when a
# calling harness enforces a wall-clock cap per call — e.g. `ENGINES=tk2 Scripts/matrix.sh` then
# `ENGINES=tk1 Scripts/matrix.sh`. Both calls are still single, blocking, foreground invocations;
# nothing here backgrounds anything. Not used, and not needed, for a normal interactive run.
for engine in ${ENGINES:-tk2 tk1}; do
  if [ "$engine" = "tk1" ]; then export TK1=1; else unset TK1; fi
  for s in $SUITES; do
    case "$s" in
      RichTextEditorUIKitTests/ID*) leg=inputDec; DEVICE=$K3 ;;
      *)                            leg=legacy;   DEVICE=$K1 ;;
    esac
    export DEVICE
    case "$s" in
      RichTextEditorUIKitTests/IDBackendEditPolicyTests|RichTextEditorUIKitTests/IDBackendFamily7Tests)
        export EXTRA="${BASE_EXTRA:+$BASE_EXTRA }$PASTE_SKIP" ;;
      *)
        export EXTRA="$BASE_EXTRA" ;;
    esac
    echo "=== $engine $leg $s"
    Scripts/iostest.sh "$s" || fail=1
  done
done
exit $fail
