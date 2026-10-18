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
#     every unit it expected was analyzed;
#   * a tracked unit has an entity gnatprove skipped ("skipped; SPARK_Mode =>
#     Off"), unless trust-surface.txt lists a spark-mode-off site in that
#     unit's files, or a tracked unit had no entity analyzed at all. A
#     library-level generic instance without pragma SPARK_Mode (On) is skipped
#     whole, with no SPARK_Mode text for the trust gate to find, and gnatprove
#     still reports success (#5).
#
# Usage:
#   scripts/check-proof.sh          # prove, then gate (exit 1 on regression)
#   scripts/check-proof.sh --list   # prove, then list the unproved checks
#
# Env:
#   ALR, PROVE_JOBS, GNATPROVE_EXTRA
#                    passed to scripts/prove.sh, which runs gnatprove (see
#                    there). GNATPROVE_EXTRA is empty by default, so a local
#                    run is exactly the committed level; CI passes its cache
#                    (--memcached-server=file:...) there. prove.sh refuses a
#                    --level or --timeout in it: CI's wall-clock allowance is
#                    FOUNDATION_SPARK_PROOF_ALLOWANCE=ci, which the GPR turns
#                    into a per-level floor (README "Levels").
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

XFAIL="scripts/proof-xfail.txt"

LIST=0
case "${1:-}" in
  --list) LIST=1 ;;
  "") ;;
  *) echo "!! unknown argument: $1" >&2; exit 2 ;;
esac

RUNLOG="$(mktemp "${TMPDIR:-/tmp}/gnatprove-run.XXXXXX")"
trap 'rm -f "$RUNLOG"' EXIT

# prove.sh clears it too, but only once its own checks pass: a refused run
# must not leave the last run's summary for this gate to read.
find obj -path '*/gnatprove/gnatprove.out' -delete 2>/dev/null || true

# The run itself is scripts/prove.sh's: the same command line as a local run,
# its -j from PROVE_JOBS, GNATPROVE_EXTRA checked there (no --level or
# --timeout may override a committed level), and its freshness guard (no
# gnatprove.out or .spark of an earlier run survives into this one; exit 3 if
# this run did not write them).
set +e
PROVE_LOG="$RUNLOG" scripts/prove.sh -- --warnings=error
GP_STATUS=$?
set -e

if [ "$GP_STATUS" -eq 3 ]; then
  echo "!! PROOF OUTPUT STALE -- prove.sh found gnatprove's output missing or older than the run" >&2
  exit 1
fi

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

# --- gate: no entity of a tracked unit was skipped ------------------------------

# A unit can appear in the report and still have nothing proved: gnatprove
# prints "in unit U, 0 subprograms and packages out of 9 analyzed" and lists
# each entity as "skipped; SPARK_Mode => Off". That is how a library-level
# generic instance without pragma SPARK_Mode (On) looks, and the run still
# says "Success". A skipped entity is allowed only in a unit whose files have
# a spark-mode-off entry in trust-surface.txt (an FFI shim's body, say). A
# tracked unit with no entity analyzed fails regardless.
TRACKED_UNITS="$(git ls-files -- src | grep -E '^src/.+\.(ads|adb)$' \
  | sed -E 's#^.*/##; s/\.(ads|adb)$//' | sort -u || true)"
OFF_UNITS="$(
  { grep -vE '^[[:space:]]*#|^[[:space:]]*$' scripts/trust-surface.txt 2>/dev/null || true; } \
  | awk -F'|' '{ k = $1; gsub(/[ \t]/, "", k); p = $2; gsub(/[ \t]/, "", p)
                 if (k == "spark-mode-off") { sub(/^.*\//, "", p); sub(/\.ad[sb]$/, "", p); print p } }' \
  | sort -u
)"
SKIPPED="$(
  awk -v tracked="$TRACKED_UNITS" -v off="$OFF_UNITS" '
    BEGIN { n = split(tracked, t, "\n"); for (i = 1; i <= n; i++) T[t[i]] = 1
            n = split(off, o, "\n");     for (i = 1; i <= n; i++) O[o[i]] = 1 }
    /^in unit / {
      unit = $3; sub(/,$/, "", unit)
      # "0 out of 0" is a generic unit: it is analyzed through its instances.
      if ((unit in T) && match($0, /, [0-9]+ subprograms and packages out of [0-9]+/)) {
        counts = substr($0, RSTART + 2, RLENGTH - 2)
        split(counts, c, " ")
        if (c[1] + 0 == 0 && c[7] + 0 > 0) print unit ": no entity analyzed"
      }
      next
    }
    /^  [^ ]/ && / skipped/ && (unit in T) && !(unit in O) {
      s = $0; sub(/^  /, "", s); print unit ": " s
    }' "$OUT"
)"

# An imported subprogram (an FFI export unit's Import of its ghost shim, #4)
# has no body to analyze, and gnatprove lists it as "skipped; body is
# SPARK_Mode => Off". It is allowed when its unit is a foreign-binding entry
# in trust-surface.txt and its declaration, from the reported line to the
# semicolon that ends it, carries Import. A real SPARK_Mode => Off in such a unit is
# still caught: the trust gate requires its own spark-mode-off entry, and
# its entities are not Imports.
FOREIGN_FILES="$(
  { grep -vE '^[[:space:]]*#|^[[:space:]]*$' scripts/trust-surface.txt 2>/dev/null || true; } \
  | awk -F'|' '{ k = $1; gsub(/[ \t]/, "", k); p = $2; gsub(/[ \t]/, "", p)
                 if (k == "foreign-binding") print p }' \
  | sort -u
)"
is_foreign_import() {
  local line="$1" unit loc file n path
  case "$line" in *"skipped; body is SPARK_Mode => Off") ;; *) return 1 ;; esac
  unit="${line%%:*}"
  loc="$(printf '%s\n' "$line" | sed -nE 's/.* at ([^ :]+):([0-9]+) skipped.*/\1:\2/p')"
  file="${loc%%:*}"; n="${loc##*:}"
  [ -n "$file" ] && [ -n "$n" ] || return 1
  [ "${file%.ad[sb]}" = "$unit" ] || return 1
  path="$(printf '%s\n' "$FOREIGN_FILES" | grep -E "(^|/)${file//./\\.}\$" | head -n 1)"
  [ -n "$path" ] && [ -f "$path" ] || return 1
  # The declaration ends at the first semicolon outside parentheses (a
  # parameter list has its own).
  awk -v n="$n" 'NR >= n { s = tolower($0); sub(/--.*$/, "", s)
                          for (i = 1; i <= length(s); i++) {
                            ch = substr(s, i, 1)
                            if (ch == "(") d++
                            else if (ch == ")") d--
                            else if (ch == ";" && d == 0) { text = text " " substr(s, 1, i); done = 1; exit }
                          }
                          text = text " " s }
                 END { exit (done && text ~ /[^a-z0-9_]import[^a-z0-9_]/ ? 0 : 1) }' "$path"
}
if [ -n "$SKIPPED" ]; then
  KEPT=""
  while IFS= read -r l; do
    [ -z "$l" ] && continue
    is_foreign_import "$l" || KEPT="$KEPT$l"$'\n'
  done <<< "$SKIPPED"
  SKIPPED="$(printf '%s' "$KEPT" | sed '/^$/d')"
fi

if [ -n "$SKIPPED" ]; then
  echo "" >&2
  echo "!! PROOF INCOMPLETE -- entities of tracked units that gnatprove did not analyze:" >&2
  printf '%s\n' "$SKIPPED" | sed 's/^/     /' >&2
  echo "" >&2
  echo "   A generic instance needs its own pragma SPARK_Mode (On). A deliberate" >&2
  echo "   SPARK_Mode => Off is a hole: list it in scripts/trust-surface.txt." >&2
  summary "entities skipped" "$SKIPPED"
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
