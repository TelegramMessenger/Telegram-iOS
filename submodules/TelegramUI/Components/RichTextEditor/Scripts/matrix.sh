#!/bin/bash
# Runs the backend seam suites on BOTH layout engines, SERIALIZED on one simulator.
# The spec's Phase-6 gate is scoped to the backend semantic suite, not the 1623-test legacy suite
# (deviation D20): several legacy tests pin TextKit-2 numbers and belong to the engines themselves.
#
# The suite list is DERIVED from the tree: every `final class <Name>: XCTestCase` declared under
# Tests/RichTextEditorUIKitTests/{Characterization,InputBackend,Support,Differential}. No task ever
# edits a hard-coded list, so a suite added by Tasks 20-44 cannot silently miss the matrix.
#
# TASK 9d ADDED THE FOURTH ROOT. Phase 0b's differential suites lived under `Differential/` from Task
# 9a onward and were discovered by NOTHING until now — the Phase-6 gate names all four roots and says
# the gate "certifies every class under T/{Characterization,InputBackend,Support,Differential}", so
# three roots was the script disagreeing with the gate it serves.
set -o pipefail
ROOTS="Tests/RichTextEditorUIKitTests/Characterization
Tests/RichTextEditorUIKitTests/InputBackend
Tests/RichTextEditorUIKitTests/Support
Tests/RichTextEditorUIKitTests/Differential"
discover() {
  for r in $ROOTS; do
    [ -d "$r" ] || continue
    # The alternation on the BASE class is required, not cosmetic: decision 10 makes the eight
    # contract suites `class …: BackendContractCases`, and Phase 0b adds differential suites.
    # A suite the regex misses is silently NOT run — `-only-testing:` on an absent class is not
    # an error — so the matrix would report success having certified nothing.
    grep -rhoE '^(final )?class [A-Za-z0-9_]+: (XCTestCase|BackendContractCases)' "$r" \
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
if [ "${MATRIX_MIN_SUITES:-59}" -gt "$COUNT" ]; then
  echo "matrix.sh discovered only $COUNT suites, expected >= ${MATRIX_MIN_SUITES}"; exit 2
fi
fail=0
for engine in tk2 tk1; do
  for s in $SUITES; do
    if [ "$engine" = "tk1" ]; then export TK1=1; else unset TK1; fi
    echo "=== $engine $s"
    Scripts/iostest.sh "$s" || fail=1
  done
done
exit $fail
