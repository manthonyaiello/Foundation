#!/usr/bin/env bash
#
# check-proof.sh -- run gnatprove over the crate and gate the result.
#
# Adapted from memcp's scripts/check-proof.sh (manthonyaiello/memcp).
#
# Each unit proves at its COMMITTED level: the Prove package of
# foundation_spark.gpr (Proof_Switches ("Ada") for the default, and
# Proof_Switches ("<file>") for a unit raised above it). This script passes no
# --level of its own, so the GPR stays the single record of the levels.
#
# The gate fails when
#   * any check is unproved and matches no pattern in proof-xfail.txt (which
#     starts empty and should stay so: the crate is meant to be platinum);
#   * gnatprove exits non-zero for any other reason: the run is
#     --warnings=error, so a warning is an error, and the only way to leave
#     one standing is a suppression that check-trust-surface.sh then requires
#     to be listed and justified;
#   * a tracked unit under src/ is missing from gnatprove's report. A run that
#     proved nothing looks like a run that passed, so the gate checks that
#     every unit it expected was analyzed.
#
# Usage:
#   scripts/check-proof.sh          # prove, then gate (exit 1 on regression)
#   scripts/check-proof.sh --list   # prove, then list the unproved checks
#
# Env:
#   ALR              the alr binary (default: alr)
#   GNATPROVE_EXTRA  extra flags appended to the gnatprove call, word-split.
#                    Empty by default, so a local run is exactly the committed
#                    level. CI passes its wall-clock allowance (--timeout) and
#                    its cache (--memcached-server=file:...) here; see
#                    .github/workflows/spark-prove.yml.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ALR="${ALR:-alr}"
XFAIL="scripts/proof-xfail.txt"
EXTRA="${GNATPROVE_EXTRA:-}"

LIST=0
case "${1:-}" in
  --list) LIST=1 ;;
  "") ;;
  *) echo "!! unknown argument: $1" >&2; exit 2 ;;
esac

# A stale summary from an earlier run must not be read as this run's.
find obj -path '*/gnatprove/gnatprove.out' -delete 2>/dev/null || true

RUNLOG="$(mktemp "${TMPDIR:-/tmp}/gnatprove-run.XXXXXX")"
trap 'rm -f "$RUNLOG"' EXIT

echo ">> $ALR -n exec -- gnatprove -P foundation_spark.gpr -j0 --warnings=error $EXTRA"
set +e
# shellcheck disable=SC2086  # EXTRA is word-split on purpose
"$ALR" -n exec -- gnatprove -P foundation_spark.gpr -j0 --warnings=error $EXTRA 2>&1 | tee "$RUNLOG"
GP_STATUS=${PIPESTATUS[0]}
set -e

OUT="$(find obj -path '*/gnatprove/gnatprove.out' 2>/dev/null | head -n 1)"
[ -n "$OUT" ] && [ -f "$OUT" ] || { echo "!! gnatprove wrote no gnatprove.out (exit $GP_STATUS)" >&2; exit 2; }

# --- what was proved ----------------------------------------------------------

# Identity (entity @ location) of every entity with an unproved check: the
# detailed report prints these as "... and not proved, N checks out of M proved".
ACTUAL_FAILS="$(
  { grep -F ' and not proved' "$OUT" || true; } \
  | sed -E 's/^[[:space:]]+//; s/ flow analyzed.*$//' \
  | sort -u
)"

TOTAL_ROW="$(grep -E '^Total[[:space:]]' "$OUT" || true)"
ANALYZED="$(grep -E '^Analyzed [0-9]+ units?' "$OUT" || true)"

if [ "$LIST" -eq 1 ]; then
  if [ -z "$ACTUAL_FAILS" ]; then
    echo ">> no unproved checks."
  else
    echo ">> unproved checks:"
    printf '%s\n' "$ACTUAL_FAILS" | sed 's/^/     /'
  fi
  exit 0
fi

[ -f "$XFAIL" ] || { echo "!! missing allowlist $XFAIL" >&2; exit 2; }

summary() {
  [ -n "${GITHUB_STEP_SUMMARY-}" ] || return 0
  {
    echo "### Proof: $1"
    echo
    echo '```'
    echo "${ANALYZED:-no 'Analyzed' line}"
    echo "                              Total      Flow   Provers   Justified   Unproved"
    echo "${TOTAL_ROW:-no Total row}"
    [ -n "${2-}" ] && printf '\n%s\n' "$2"
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
}

# --- gate: every expected unit was analyzed -----------------------------------

# gnatprove names a unit by its file's base name ("in unit foundation_spark-aes,").
MISSING=""
while IFS= read -r src; do
  [ -z "$src" ] && continue
  unit="$(basename "$src")"
  unit="${unit%.*}"
  if ! grep -qE "^in unit ${unit}," "$OUT"; then
    MISSING="${MISSING}${src} (unit ${unit})"$'\n'
  fi
done <<< "$(git ls-files -- src | grep -E '^src/.+\.(ads|adb)$' || true)"

if [ -n "$MISSING" ]; then
  echo "" >&2
  echo "!! PROOF INCOMPLETE -- tracked units absent from $OUT:" >&2
  printf '%s' "$MISSING" | sed 's/^/     /' >&2
  summary "units not analyzed" "$MISSING"
  exit 1
fi

# --- gate: every unproved check is allowed ------------------------------------

PATTERNS="$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$XFAIL" || true)"

allowed() {
  local fail="$1" p
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$fail" in *"$p"*) return 0 ;; esac
  done <<< "$PATTERNS"
  return 1
}

regressions=""
allowed_n=0
while IFS= read -r fail; do
  [ -z "$fail" ] && continue
  if allowed "$fail"; then
    allowed_n=$((allowed_n + 1))
  else
    regressions="${regressions}${fail}"$'\n'
  fi
done <<< "$ACTUAL_FAILS"

if [ -n "$regressions" ]; then
  echo "" >&2
  echo "!! PROOF REGRESSION -- unproved check(s) not covered by $XFAIL:" >&2
  printf '%s' "$regressions" | sed 's/^/     /' >&2
  echo "" >&2
  # gnatprove 16 prints " high: <message>" and then "--> <file>:<line>:<col>".
  { grep -E -A1 '^[[:space:]]*(low|medium|high):' "$RUNLOG" || true; } | sed 's/^/     /' >&2
  echo "" >&2
  echo "   Prove it, or raise the unit's level in foundation_spark.gpr (with the" >&2
  echo "   reason in the commit). $XFAIL is not the fix." >&2
  summary "unproved checks" "$regressions"
  exit 1
fi

# --- gate: nothing else made gnatprove fail -----------------------------------

if [ "$GP_STATUS" -ne 0 ]; then
  echo "" >&2
  echo "!! GNATPROVE FAILED -- exit $GP_STATUS with no unproved check outside $XFAIL." >&2
  echo "   Under --warnings=error a warning is an error. What it reported:" >&2
  echo "" >&2
  { grep -E -A1 '^[[:space:]]*(warning|error):|: (warning|error):' "$RUNLOG" || true; } | sed 's/^/     /' >&2
  summary "gnatprove exit $GP_STATUS"
  exit 1
fi

echo ""
echo "$ANALYZED"
echo "$TOTAL_ROW"
if [ "$allowed_n" -eq 0 ]; then
  echo ">> PROOF OK -- no unproved checks."
  summary "OK, no unproved checks"
else
  echo ">> PROOF OK -- ${allowed_n} unproved check(s), all allowed by $XFAIL."
  summary "OK, ${allowed_n} allowed by proof-xfail.txt"
fi
exit 0
