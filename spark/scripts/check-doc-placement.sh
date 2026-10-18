#!/usr/bin/env bash
#
# check-doc-placement.sh -- find doc comments attached to the wrong entity.
#
# Adapted from memcp's scripts/check-doc-placement.sh (manthonyaiello/memcp).
#
# Under gnatdoc --style=gnat, a comment block documents the declaration ABOVE
# it. A block placed before a declaration is therefore not merely dropped: it
# becomes the documentation (and the IDE hover text) of the preceding entity.
# check-docs.sh cannot see this, because gnatdoc's --warnings is per entity,
# not per declaration. This script reports those blocks.
#
# Exceptions:
#   * A block above `package` or `generic` IS read: that is a file header.
#   * A banner (`-- Title --` between rules of dashes) is not documentation.
#   * A block above `pragma` is not flagged: a pragma is not a declaration.
#
# Gotcha when editing the rules: opens() fires on any line ENDING in `is`,
# `declare`, `private` or `record`, comment or not. Prose in a doc block that
# ends a line with one of those words makes the next comment line look
# block-initial. Reword the prose.
#
# No toolchain needed: awk over `git ls-files`.
#
# Usage:
#   scripts/check-doc-placement.sh            report and FAIL on any finding
#   scripts/check-doc-placement.sh --no-gate  report only
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
readonly ROOT_DIR="$PWD"

GATE=1
case "${1-}" in
  --no-gate) GATE=0 ;;
  "")        ;;
  *)         echo "usage: $0 [--no-gate]" >&2; exit 2 ;;
esac
readonly GATE

# Tracked sources under src/, relative to spark/.
sources="$(git -C "$ROOT_DIR" ls-files -- src | grep -E '\.(ads|adb)$' || true)"

if [ -z "$sources" ]; then
  echo "error: no tracked Ada sources under spark/src -- wrong directory?" >&2
  exit 1
fi

findings="$(printf '%s\n' "$sources" | while IFS= read -r f; do
  awk -v F="$f" '
    function is_comment(s) { return s ~ /^[[:space:]]*--/ }
    function is_blank(s)   { return s ~ /^[[:space:]]*$/ }
    function is_rule(s)    { return s ~ /^[[:space:]]*-+[[:space:]]*$/ }

    # Lines that open a declarative region: a comment block right after one is
    # block-initial, as after a blank line.
    function opens(s) {
      return tolower(s) ~ /(^|[[:space:]])(is|declare|private|record)[[:space:]]*$/
    }

    # Declarations whose doc is read from BELOW. The second alternative is an
    # object or component declaration (`Length : constant Natural :=`).
    function is_decl(s) {
      s = tolower(s)
      return s ~ /^[[:space:]]*(type|subtype|function|procedure|task|protected|entry)[[:space:]]/ \
          || s ~ /^[[:space:]]*[a-z][a-z0-9_]*([[:space:]]*,[[:space:]]*[a-z][a-z0-9_]*)*[[:space:]]*:[[:space:]]/
    }

    { L[NR] = $0 }

    END {
      for (i = 1; i <= NR; i++) {
        if (!is_comment(L[i]))                                    continue
        if (!(i == 1 || is_blank(L[i-1]) || opens(L[i-1])))        continue

        for (j = i; j < NR && is_comment(L[j+1]); j++) { }

        if (is_rule(L[i]) && is_rule(L[j])) { i = j; continue }

        if (is_decl(L[j+1])) {
          decl = L[j+1]
          sub(/^[[:space:]]+/, "", decl)
          print F ":" i ": leading block of " (j-i+1) " line(s) documents the" \
                " PRECEDING entity under --style=gnat; move it below: " decl
        }
        i = j
      }
    }
  ' "$ROOT_DIR/$f"
done)"

if [ -z "$findings" ]; then
  echo "Doc placement: no misattributed comment blocks."
  exit 0
fi

total="$(printf '%s\n' "$findings" | wc -l | tr -d ' ')"

echo "Doc placement: $total misattributed comment block(s)."
echo
printf '%s\n' "$findings"
echo
echo "Each block is credited to the declaration above it. Move it below the"
echo "declaration it describes (packages and generics are the exception)."

if [ -n "${GITHUB_STEP_SUMMARY-}" ]; then
  {
    echo "### Doc placement: $total misattributed comment block(s)"
    echo
    echo '```'
    printf '%s\n' "$findings"
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
fi

[ "$GATE" -eq 0 ] || exit 1
