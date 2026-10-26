#!/usr/bin/env bash
#
# prove.sh -- the one way this crate calls gnatprove.
#
# Local ticks and CI's proof gate (check-proof.sh) both prove through this
# script, so the two cannot drift apart: same project, same committed levels,
# same freshness guard. Run from anywhere; it works in spark/.
#
# Levels are the GPR's, never this script's. Each unit proves at the level
# committed in foundation_spark.gpr's Prove package (Level_2 by default, a
# per-file Proof_Switches for a raised unit). So this script refuses any
# switch that would override a committed level or its limits: --level,
# --timeout, --steps, --memlimit, --prover, -j (see README "Levels" for why a
# command-line --timeout is the dangerous one).
#
# Freshness. A gnatprove run that stops early can leave gnatprove.out and the
# per-unit .spark files of an earlier run in obj/, and a summary read from them
# looks like this run's. So, before the run, this script deletes gnatprove.out
# and the .spark file of every unit in scope (all of them for a whole-crate
# run, the -u units otherwise), which makes gnatprove re-analyze those units
# (proof attempts still replay from its session files). After the run it
# requires a gnatprove.out newer than the run's start and a fresh .spark for
# every unit in scope.
#
# Usage:
#   scripts/prove.sh                          # the whole crate
#   scripts/prove.sh -u FILE [-u FILE ...]    # only these units (file names,
#                                             # as gnatprove's -u takes them)
#   scripts/prove.sh [...] -- ARGS...         # extra gnatprove arguments
#                                             # (check-proof.sh passes
#                                             # --warnings=error here)
#
# Env:
#   PROVE_JOBS       gnatprove -j (default: nproc). On a shared machine, set it.
#   PROVE_LOG        where the run's log goes (default: obj/prove.log). The log
#                    starts with the gnatprove command line, -j included.
#   GNATPROVE_EXTRA  more gnatprove arguments, word-split (CI passes its
#                    --memcached-server here). Checked like ARGS.
#   ALR              the alr binary (default: alr).
#   FOUNDATION_SPARK_PROOF_ALLOWANCE
#                    read by the GPR, not here: "none" (default) or "ci". See
#                    foundation_spark.gpr and README "Levels".
#
# Exit status: gnatprove's, or 2 for a usage error, or 3 when gnatprove exited 0
# but its output is missing or stale.
#
# A scheduler could wrap the gnatprove call below later (for example
# `spark-scheduler run --up-to N -- ...`). If one is added, it must pass its
# grant to the child (as -j), because gnatprove cannot learn it otherwise and
# PROVE_JOBS would oversubscribe the grant.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ALR="${ALR:-alr}"
JOBS="${PROVE_JOBS:-$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN)}"
LOG="${PROVE_LOG:-obj/prove.log}"
GPR="foundation_spark.gpr"

UNITS=()
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -u) [ $# -ge 2 ] || { echo "!! -u needs a file name" >&2; exit 2; }
        UNITS+=("$(basename "$2")"); shift 2 ;;
    --) shift; ARGS+=("$@"); break ;;
    *) echo "!! unknown argument: $1 (gnatprove arguments go after --)" >&2; exit 2 ;;
  esac
done

case "$JOBS" in
  ''|*[!0-9]*) echo "!! PROVE_JOBS must be a number, not '$JOBS'" >&2; exit 2 ;;
esac

# shellcheck disable=SC2206  # GNATPROVE_EXTRA is word-split on purpose
EXTRA=(${GNATPROVE_EXTRA:-})

# --- the committed levels are the only levels ---------------------------------

for a in "${ARGS[@]+"${ARGS[@]}"}" "${EXTRA[@]+"${EXTRA[@]}"}"; do
  case "$a" in
    --level*|--timeout*|--steps*|--memlimit*|--prover*|-j*|-u|-f)
      echo "!! prove.sh does not pass '$a': levels, limits and provers are the" >&2
      echo "   GPR's (Prove package), jobs are PROVE_JOBS, units are -u, and a" >&2
      echo "   forced run is what the freshness guard already does per unit." >&2
      exit 2 ;;
  esac
done

# A per-file Proof_Switches must use one of the GPR's Level_N lists. A literal
# "--level=N" there would, under FOUNDATION_SPARK_PROOF_ALLOWANCE=ci, inherit
# the default's --timeout=10 and so prove a raised unit with less time than its
# level gives (README "Levels").
#
# The GPR is read statement by statement (split at ";"), with comments
# stripped: a "--" at the start of a line or after a blank. A quoted switch
# ("--level=2") keeps its "--", because a quote precedes it.
LITERAL="$(
  awk 'BEGIN { RS = ";" }
       { s = "\n" $0
         gsub(/\n[ \t]*--[^\n]*/, "\n", s)
         gsub(/[ \t]--[^\n]*/, "", s) }
       s ~ /for[ \t\n]+Proof_Switches[ \t\n]*\(/ && s ~ /"--(level|timeout|steps)/ {
         gsub(/[ \t\n]+/, " ", s); print s }' "$GPR"
)"
if [ -n "$LITERAL" ]; then
  echo "!! $GPR: a Proof_Switches gives a literal --level/--timeout/--steps:" >&2
  printf '%s\n' "$LITERAL" | sort -u | sed 's/^/     /' >&2
  echo "   Use the Prove package's Level_N lists (README \"Levels\")." >&2
  exit 2
fi

# --- freshness: no output of an earlier run survives into this one -----------

# Units in scope, by the base name gnatprove uses for the .spark file.
SCOPE=()
if [ "${#UNITS[@]}" -gt 0 ]; then
  for f in "${UNITS[@]}"; do SCOPE+=("${f%.*}"); done
else
  while IFS= read -r f; do
    [ -n "$f" ] && SCOPE+=("$(basename "${f%.*}")")
  done <<< "$(git ls-files -- src | grep -E '^src/.+\.(ads|adb)$' || true)"
fi
SORTED=()
while IFS= read -r u; do
  [ -n "$u" ] && SORTED+=("$u")
done < <(printf '%s\n' "${SCOPE[@]+"${SCOPE[@]}"}" | sort -u)
SCOPE=("${SORTED[@]+"${SORTED[@]}"}")

mkdir -p "$(dirname "$LOG")"
START="$(mktemp "${TMPDIR:-/tmp}/prove-start.XXXXXX")"
trap 'rm -f "$START"' EXIT

find obj -path '*/gnatprove/gnatprove.out' -delete 2>/dev/null || true
if [ "${#UNITS[@]}" -gt 0 ]; then
  for u in "${SCOPE[@]}"; do
    find obj -path "*/gnatprove/${u}.spark" -delete 2>/dev/null || true
  done
else
  find obj -path '*/gnatprove/*.spark' -delete 2>/dev/null || true
fi
# The guard compares against this file's mtime; make it strictly older than
# anything gnatprove writes next.
sleep 1

# --- the run --------------------------------------------------------------------

CMD=("$ALR" -n exec -- gnatprove -P "$GPR" "-j$JOBS")
for u in "${UNITS[@]+"${UNITS[@]}"}"; do CMD+=(-u "$u"); done
CMD+=("${ARGS[@]+"${ARGS[@]}"}" "${EXTRA[@]+"${EXTRA[@]}"}")

{
  echo ">> prove.sh $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(hostname) ($(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo '?') CPUs)"
  echo ">> commit $(git rev-parse --short HEAD 2>/dev/null || echo '?')$(git diff --quiet HEAD -- . 2>/dev/null || echo ' (dirty)')"
  echo ">> FOUNDATION_SPARK_PROOF_ALLOWANCE=${FOUNDATION_SPARK_PROOF_ALLOWANCE:-none}"
  echo ">> ${CMD[*]}"
} | tee "$LOG"

T0="$(date +%s)"
set +e
"${CMD[@]}" 2>&1 | tee -a "$LOG"
STATUS=${PIPESTATUS[0]}
set -e
echo ">> gnatprove exit $STATUS after $(( $(date +%s) - T0 ))s" | tee -a "$LOG"

# --- the guard ------------------------------------------------------------------

STALE=""
OUT="$(find obj -path '*/gnatprove/gnatprove.out' -newer "$START" 2>/dev/null | head -n 1)"
[ -n "$OUT" ] || STALE="${STALE}gnatprove.out (none written by this run)"$'\n'
for u in "${SCOPE[@]}"; do
  if [ -z "$(find obj -path "*/gnatprove/${u}.spark" -newer "$START" 2>/dev/null | head -n 1)" ]; then
    STALE="${STALE}${u}.spark"$'\n'
  fi
done

if [ -n "$STALE" ]; then
  {
    echo "!! STALE OR MISSING OUTPUT -- this run did not write:"
    printf '%s' "$STALE" | sed 's/^/     /'
    echo "   Nothing in obj/ may be quoted as this run's result."
  } | tee -a "$LOG" >&2
  [ "$STATUS" -ne 0 ] && exit "$STATUS"
  exit 3
fi

exit "$STATUS"
