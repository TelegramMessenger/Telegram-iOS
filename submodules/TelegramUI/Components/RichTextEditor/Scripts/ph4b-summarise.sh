#!/bin/bash
# Aggregates the `PH4B-ROW` lines produced by `ph4b-isolation-sweep.sh` into a per-arm table.
#
# It reports VARIANCE, not just a rate, because PH4's finding about the legacy arm was that it was
# BIMODAL (0 or 375 red px, never an intermediate value) rather than noisy — and a mean would have
# hidden exactly that. So the distinct `correctedRed` values are listed with their counts.
#
# It also checks the two things that would invalidate the sweep rather than merely change its
# answer: every row must come from a DISTINCT pid (one arm per process), and every row must be
# valid (`present=1`, i.e. the arm did paint a marker before the correction, and `calibRed>3`,
# i.e. the instrument saw a known red underline in that same process).
#
#   ./Scripts/ph4b-summarise.sh Host/build/ph4b-rows.txt
set -uo pipefail
LOG="${1:-Host/build/ph4b-rows.txt}"
[ -f "$LOG" ] || { echo "no such log: $LOG" >&2; exit 1; }

python3 - "$LOG" <<'PY'
import sys, collections, statistics
rows = []
for line in open(sys.argv[1]):
    if not line.startswith('PH4B-ROW '): continue
    d = {}
    for tok in line.strip().split()[1:]:
        if '=' in tok:
            k, v = tok.split('=', 1); d[k] = v
    rows.append(d)

void = [r for r in rows if r.get('pid') == 'NONE' or 'VOID' in r]
good = [r for r in rows if r not in void]
pids = [r['pid'] for r in good]
dupe = [p for p, c in collections.Counter(pids).items() if c > 1]

print(f"rows: {len(rows)}   usable: {len(good)}   void/failed invocations: {len(void)}")
print(f"ISOLATION CHECK — distinct pids: {len(set(pids))}/{len(pids)}"
      + ("  OK" if not dupe else f"  ** REUSED PIDS: {dupe} — ISOLATION BROKEN **"))
armcount = {r.get('arms') for r in good}
print(f"ISOLATION CHECK — arms driven per process: {sorted(armcount)}"
      + ("  OK" if armcount <= {'1'} else "  ** MORE THAN ONE ARM IN A PROCESS **"))
print()

for arm in ('stock', 'inputDec', 'legacy'):
    a = [r for r in good if r.get('arm') == arm]
    if not a:
        continue
    n = len(a)
    cleared = sum(1 for r in a if r.get('cleared') == '1')
    present = sum(1 for r in a if r.get('present') == '1')
    corrected = [int(r['correctedRed']) for r in a]
    misspelled = [int(r['misspelledRed']) for r in a]
    forced = [int(r['forcedRed']) for r in a]
    calib = [int(r['calibRed']) for r in a]
    dist = collections.Counter(corrected)
    sd = statistics.pstdev(corrected) if n > 1 else 0.0
    print(f"--- {arm}  (n={n}) ---")
    print(f"  cleared:            {cleared}/{n}")
    print(f"  marker present:     {present}/{n}   (a run with present=0 is VOID, not a clear)")
    print(f"  correctedRed:       distinct values {dict(sorted(dist.items()))}   sd={sd:.1f}")
    print(f"  misspelledRed:      min={min(misspelled)} max={max(misspelled)} "
          f"distinct={len(set(misspelled))}")
    print(f"  forcedRed == correctedRed in {sum(1 for r in a if r['forcedRed']==r['correctedRed'])}/{n} runs")
    print(f"  CONTROL calibRed:   min={min(calib)} max={max(calib)}  (must be > 3 every run)")
    slow = [float(r['correctedSeconds']) for r in a]
    conv = sum(1 for r in a if r.get('correctedConverged') == '1')
    print(f"  corrected settle:   converged {conv}/{n}, seconds min={min(slow):.2f} max={max(slow):.2f}")
    print()
PY
