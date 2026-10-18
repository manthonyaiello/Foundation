#!/usr/bin/env bash
#
# check-docs.sh -- GNATdoc generation and the documentation gate.
#
# Adapted from memcp's scripts/check-docs.sh (manthonyaiello/memcp).
#
# `gnatdoc --warnings` reports every undocumented entity and then exits 0: it
# is a report, not a check. This script reads the report and sets the exit
# status, and checks that the run produced its index.html (a run can exit 0,
# warn about nothing, and generate nothing).
#
# STYLE: --style=gnat. A doc comment sits BELOW the declaration it describes
# (a package's or generic's header block sits above it), and @param, @return
# and @enum are mandatory. There is no GPR attribute for the style, so this
# script is its record. --generate=private, so private parts are documented
# too.
#
# This gate cannot see PLACEMENT: a block on the wrong side of a declaration is
# credited to the declaration above it. scripts/check-doc-placement.sh checks
# that, and CI runs both.
#
# gnatdoc is a tool, not a crate dependency, and is pinned: the set of warnings
# IS the gate, so a silent version bump must not change what CI accepts.
# 26.0.0 is the generation that pairs with gnat_native 16.1.0.
#
# Usage (from anywhere; needs an Alire workspace, i.e. `alr -n build` once):
#   scripts/check-docs.sh            generate, report, FAIL on any finding
#   scripts/check-docs.sh --no-gate  generate and report only
#
# Output: docs/api/ (HTML) and docs/gnatdoc-run.txt (the log), under spark/.
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
readonly ROOT_DIR="$PWD"
readonly OUT_DIR="$ROOT_DIR/docs/api"
readonly LOG="$ROOT_DIR/docs/gnatdoc-run.txt"

GATE=1
case "${1-}" in
  --no-gate) GATE=0 ;;
  "") ;;
  *) echo "usage: $0 [--no-gate]" >&2; exit 2 ;;
esac

readonly GNATDOC_PIN="gnatdoc_bin=26.0.0"
if ! command -v gnatdoc >/dev/null 2>&1; then
  cat >&2 <<EOF
error: gnatdoc is not on PATH. Install the pinned version:

    alr -n install $GNATDOC_PIN
    export PATH="\$HOME/.alire/bin:\$PATH"
EOF
  exit 2
fi

# Entities we do not author. gnatdoc walks the whole closure, SPARKlib
# included; warning lines carry only a base name, so the filter is by unit:
#   spark.ads, spark-*   SPARKlib
#   *_config.ads         Alire-generated, gitignored crate config
# Our own units all start with foundation_spark, so `spark[-.]` anchored at the
# start of the name cannot catch one. Warnings on .gpr files are NOT filtered:
# a project problem should fail the gate rather than hide.
readonly NOT_OURS='^(spark[-.])|_config\.ads:'

mkdir -p "$OUT_DIR"
: > "$LOG"

# The raw output goes to the log only: gnatdoc reports on SPARKlib too, which
# is thousands of lines that are not ours. What is ours is printed below.
echo "== foundation_spark.gpr" >> "$LOG"
echo ">> gnatdoc --style=gnat --generate=private --warnings -P foundation_spark.gpr (log: spark/docs/gnatdoc-run.txt)"
set +e
alr -n exec -- gnatdoc --style=gnat --generate=private --warnings \
  -P foundation_spark.gpr -O "$OUT_DIR" >> "$LOG" 2>&1
GD_STATUS=$?
set -e

if [ "$GD_STATUS" -ne 0 ]; then
  echo "error: gnatdoc exited $GD_STATUS. The end of its log:" >&2
  tail -n 30 "$LOG" >&2
  exit 1
fi

if [ ! -f "$OUT_DIR/index.html" ]; then
  echo "error: gnatdoc produced no docs/api/index.html" >&2
  exit 1
fi

# `internal error` is gnatdoc giving up on a declaration: neither documented nor
# reported. It is listed separately below so it cannot score as clean.
ours="$(grep -E ':[0-9]+:[0-9]+: (warning|error|internal error):' "$LOG" \
        | grep -vE "$NOT_OURS" | sort -u || true)"
crashes="$(printf '%s\n' "$ours" | grep -E ': internal error:' | sed '/^$/d' || true)"
findings="$(printf '%s\n' "$ours" | grep -vE ': internal error:' | sed '/^$/d' || true)"

# Output that is neither a diagnostic nor framing, so that a new output shape
# cannot hide behind patterns written for the old one. 26.0.0 prints a bare AST
# node for a package renaming, e.g.
#   <PackageRenamingDecl ["EHT"] spark-containers-formal-unbounded_hashed_maps.ads:1059:4-1059:45>
# (SPARKlib has four). Such a line names its file mid-line, so the same
# not-ours filter is applied to the file it names.
readonly NOT_OURS_NAMED='(^|[^A-Za-z0-9_])spark[-.][A-Za-z0-9_.-]*\.ad[sb]:|_config\.ads:'
unaccounted="$(grep -vE '^(==|[A-Za-z0-9_.-]+:[0-9]+:[0-9]+:|Note:|Success:|error:|warning:)' "$LOG" \
               | grep -vE "$NOT_OURS_NAMED" | sed '/^$/d' | sort -u || true)"

if [ -n "$crashes" ]; then
  echo
  echo "GNATdoc: declaration(s) that CRASHED the tool and are absent from docs/api/:"
  printf '%s\n' "$crashes"
fi

if [ -n "$unaccounted" ]; then
  echo
  echo "GNATdoc: output matching no known diagnostic shape:"
  printf '%s\n' "$unaccounted"
fi

# Crashes and unaccounted lines fail the gate too. memcp reports them without
# gating, because its tree had some it could not fix; this crate starts clean,
# and a declaration that reaches neither the docs nor the report is
# undocumented in fact.
problems="$(printf '%s\n%s\n%s\n' "$findings" "$crashes" "$unaccounted" | sed '/^$/d' || true)"

if [ -z "$problems" ]; then
  echo
  echo "GNATdoc: no undocumented entities in our sources. HTML in spark/docs/api/."
  exit 0
fi

total="$(printf '%s\n' "$problems" | wc -l | tr -d ' ')"
echo
echo "GNATdoc: $total finding(s) in our sources:"
printf '%s\n' "$problems"

if [ -n "${GITHUB_STEP_SUMMARY-}" ]; then
  {
    echo "### GNATdoc: $total finding(s)"
    echo
    echo '```'
    printf '%s\n' "$problems"
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
fi

[ "$GATE" -eq 0 ] || exit 1
