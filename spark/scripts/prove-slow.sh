#!/usr/bin/env bash
#
# prove-slow.sh -- prove the slow units on demand, and record their proofs.
#
# The default gate (check-proof.sh) skips the units listed in
# scripts/proof-slow.txt and checks only that their recorded proofs are still
# current (README "Slow proofs"). This script is how they are proved: each
# unit through scripts/prove.sh -u (so at its committed level, the GPR's,
# with prove.sh's freshness guard and --warnings=error), then
#   * on success (gnatprove exit 0, its .spark fresh, every check proved, no
#     entity skipped), it rewrites the unit's manifest entry: the commit
#     proved (HEAD), the date, the level, the checks, the fingerprint and the
#     inputs (scripts/slow_proofs.py record);
#   * on failure, it leaves the entry unchanged and exits 1.
#
# The tree must be clean (outside proof-slow.txt): the entry records HEAD as
# the commit proved, and a dirty tree is not HEAD.
#
# Usage:
#   scripts/prove-slow.sh                     # every listed unit
#   scripts/prove-slow.sh FILE...             # these (files under spark/)
#   scripts/prove-slow.sh --reason TEXT FILE  # a unit not listed yet
#   scripts/prove-slow.sh --print [FILE...]   # print the entries, write none
#                                             # (the CI workflow, which cannot
#                                             # push)
#
# Env: as scripts/prove.sh (PROVE_JOBS, GNATPROVE_EXTRA, ALR,
# FOUNDATION_SPARK_PROOF_ALLOWANCE). On the campaign machine, run it through
# spark-scheduler, with PROVE_JOBS set to the grant.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PRINT=()
REASON=()
FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --print) PRINT=(--print); shift ;;
    --reason) [ $# -ge 2 ] || { echo "!! --reason needs a text" >&2; exit 2; }
              REASON=(--reason "$2"); shift 2 ;;
    -*) echo "!! unknown argument: $1" >&2; exit 2 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

if [ "${#FILES[@]}" -eq 0 ]; then
  while IFS= read -r f; do
    [ -n "$f" ] && FILES+=("$f")
  done <<< "$(python3 scripts/slow_proofs.py units --files)"
fi
if [ "${#FILES[@]}" -eq 0 ]; then
  echo ">> no slow unit listed in scripts/proof-slow.txt; nothing to prove."
  exit 0
fi

if [ "${#PRINT[@]}" -eq 0 ] \
   && [ -n "$(git status --porcelain -- . ':!scripts/proof-slow.txt' ':!obj' ':!lib' ':!alire' ':!config' ':!docs')" ]; then
  echo "!! the tree is dirty: commit first. The entry records HEAD as the commit proved." >&2
  git status --short -- . ':!scripts/proof-slow.txt' ':!obj' ':!lib' ':!alire' ':!config' ':!docs' >&2
  exit 2
fi

HEAD_SHA="$(git rev-parse HEAD)"
FAILED=""
for f in "${FILES[@]}"; do
  unit="$(basename "$f")"; unit="${unit%.*}"
  level="$(python3 scripts/slow_proofs.py level "$f")"
  UARGS=()
  while IFS= read -r src; do
    [ -n "$src" ] && UARGS+=(-u "$src")
  done <<< "$(git ls-files -- src | grep -E "/${unit}\.ad[sb]\$" || true)"
  if [ "${#UARGS[@]}" -eq 0 ]; then
    echo "!! $f: no tracked file of unit $unit under src/" >&2
    FAILED="$FAILED $f"; continue
  fi

  echo ">> prove-slow: $f (unit $unit, committed level $level) at ${HEAD_SHA:0:7}"
  log="obj/prove-slow-${unit}.log"
  set +e
  PROVE_LOG="$log" scripts/prove.sh "${UARGS[@]}" -- --warnings=error
  status=$?
  set -e

  if [ "$status" -ne 0 ]; then
    echo "!! $f: prove.sh exit $status; its entry is unchanged (log: $log)" >&2
    FAILED="$FAILED $f"; continue
  fi
  set +e
  checks="$(python3 scripts/slow_proofs.py checks "$f")"
  cstatus=$?
  set -e
  if [ "$cstatus" -ne 0 ]; then
    echo "!! $f: not every check proved ($checks); its entry is unchanged" >&2
    FAILED="$FAILED $f"; continue
  fi
  echo ">> $f: $checks checks proved at level $level"
  python3 scripts/slow_proofs.py record "$f" --commit "$HEAD_SHA" \
    --date "$(date -u +%Y-%m-%d)" --checks "$checks" \
    "${REASON[@]+"${REASON[@]}"}" "${PRINT[@]+"${PRINT[@]}"}"
done

if [ -n "$FAILED" ]; then
  echo "!! SLOW PROOF FAILED:$FAILED" >&2
  exit 1
fi
echo ">> SLOW PROOFS OK"
