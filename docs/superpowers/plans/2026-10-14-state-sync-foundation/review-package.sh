#!/bin/bash
# Usage: bash docs/superpowers/plans/2026-10-14-state-sync-foundation/review-package.sh OUTDIR NAME BASE [HEAD]
#
# Writes OUTDIR/review-NAME-BASE..HEAD.diff: the commit list, the stat and the full diff (10 lines of context) of
# BASE..HEAD, for a reviewer to read in one file. Prints the path and its size. HEAD defaults to the current commit.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
OUTDIR=$1; NAME=$2; BASE=$3
HEAD_REV=${4:-$(git rev-parse --short HEAD)}
mkdir -p "$OUTDIR"
OUT="$OUTDIR/review-${NAME}-${BASE}..${HEAD_REV}.diff"
{
  echo "# Review package: ${BASE}..${HEAD_REV} (${NAME})"
  echo
  echo "## Commits"
  git log --oneline "${BASE}..${HEAD_REV}"
  echo
  echo "## Files changed"
  git diff --stat "${BASE}..${HEAD_REV}" -- . ':(exclude)docs/superpowers/reports'
  echo
  echo "## Diff"
  git diff -U10 "${BASE}..${HEAD_REV}" -- . ':(exclude)docs/superpowers/reports'
} > "$OUT"
echo "$OUT $(wc -c < "$OUT")"
