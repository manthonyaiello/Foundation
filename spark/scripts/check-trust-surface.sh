#!/usr/bin/env bash
#
# check-trust-surface.sh -- gate the crate's trust surface against a manifest.
#
# Adapted from memcp's scripts/check-trust-surface.sh (manthonyaiello/memcp).
#
# The trust surface is everything a proof of this crate does not cover: code
# outside SPARK, assumptions the prover takes on faith, justified checks,
# suppressed warnings and checks, and the foreign boundary. trust-surface.txt
# (beside this script) lists every such site with a justification; this script
# derives the same set from the sources and fails on any difference.
#
# This crate is meant to be platinum: every check proved against the spec layer,
# with no assumptions. So the manifest should only ever hold the FFI export
# shims. Anything else is a hole, and a hole is reported as one in the
# change that adds it, even when the manifest line makes this gate pass.
#
# Scope: git-tracked Ada sources under spark/src/, recursively (src/common,
# src/aes, src/sha2, ...). Paths are relative to spark/.
#
# Kinds:
#   spark-mode-off    SPARK_Mode => Off, pragma SPARK_Mode (Off)          entity
#   assume            pragma Assume                                        entity
#   justification     Annotate (GNATprove, False_Positive | Intentional
#                     | Skip_Proof | Skip_Flow_And_Proof), pragma or aspect entity
#   warning-off       pragma Warnings (.. Off ..), Warnings => Off,
#                     pragma Unreferenced | Unmodified | Unused             entity
#   check-suppressed  pragma Suppress                                      entity
#   foreign-binding   Import / Export / Interface / Convention => C        file
#
# Differences from memcp's script, all deliberate:
#   * Matching is case-insensitive (Ada is), comments are stripped first, and a
#     construct may span lines: a pragma's arguments routinely wrap.
#   * SPARK_Mode (Off) in pragma form counts, not only the aspect.
#   * Skip_Proof and Skip_Flow_And_Proof count as justifications: they are
#     holes of the same kind.
#   * Export counts as a foreign binding: the FFI shims export SPARK to C.
#   * No native-source kind: the crate has no hand-written C or Rust.
#
# Known limits. A string literal containing "--" is cut at that point, as if it
# were a comment. Compiler switches that suppress checks or warnings (-gnatp,
# -gnatws) live in the GPR and the Alire config, not in src/; CODEOWNERS routes
# those files to review instead.
#
# Usage:
#   scripts/check-trust-surface.sh          # gate (exit 1 on any difference)
#   scripts/check-trust-surface.sh --list   # print the derived set, manifest-shaped
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MANIFEST="scripts/trust-surface.txt"

LIST=0
case "${1:-}" in
  --list) LIST=1 ;;
  "") ;;
  *) echo "!! unknown argument: $1" >&2; exit 2 ;;
esac

# --- the file universe --------------------------------------------------------

# git-tracked only, so build output and the Alire workspace cannot enter the
# surface by appearing on disk.
ada_sources() {
  git ls-files -- src | grep -E '^src/.+\.(ads|adb)$' || true
}

# --- deriving the surface -----------------------------------------------------

# Emit "kind:line" for every site in file $1. The file is lower-cased, its
# comments stripped, and joined into one string, so that a regex can match a
# construct that spans lines; the line is that of the match's first character.
scan_file() {
  awk '
    {
      s = tolower($0)
      sub(/--.*$/, "", s)
      text = text s "\n"
    }
    function scan(kind, re,    rest, offset, pre, n) {
      rest = text
      offset = 0
      while (match(rest, re)) {
        pre = substr(text, 1, offset + RSTART)
        n = gsub(/\n/, "\n", pre)
        print kind ":" (n + 1)
        offset += RSTART + RLENGTH - 1
        rest = substr(rest, RSTART + RLENGTH)
      }
    }
    END {
      ws = "[ \t\n]"
      id = "[a-z0-9_]"
      scan("spark-mode-off", "spark_mode" ws "*(=>" ws "*off|[(]" ws "*off" ws "*[)])")
      scan("assume",         "pragma" ws "+assume" ws "*[(]")
      scan("justification",  "annotate" ws "*(=>" ws "*)?[(]" ws "*gnatprove" ws "*," ws "*(false_positive|intentional|skip_proof|skip_flow_and_proof)")
      scan("warning-off",    "pragma" ws "+warnings" ws "*[(]([^;]*,)?" ws "*off" ws "*[,)]")
      scan("warning-off",    "warnings" ws "*=>" ws "*off")
      scan("warning-off",    "pragma" ws "+(unreferenced|unmodified|unused)" ws "*[(]")
      scan("check-suppressed", "pragma" ws "+suppress" ws "*[(]")
    }
  ' "$1"
}

# True when file $1 binds across the language boundary.
is_foreign() {
  awk '
    {
      s = tolower($0)
      sub(/--.*$/, "", s)
      text = text " " s
    }
    END {
      ws = "[ \t]"
      if (text ~ ("pragma" ws "+(import|export|interface)" ws "*[(]") \
          || text ~ ("[^a-z0-9_.](import|export)" ws "*(=>|,|;)") \
          || text ~ ("convention" ws "*=>" ws "*c([^a-z0-9_]|$)"))
        found = 1
    }
    END { exit (found ? 0 : 1) }
  ' "$1"
}

# Name of the innermost declaration still open at line $2 of file $1. Empty when
# none is, which the caller reports rather than hides.
#
# Scope-aware rather than nearest-above, as in memcp: declarations push, and
# `end <Name>;` pops back to (and including) the entry of that name, so a
# suppression in a body's statement part names the body, not the last local
# subprogram. A subprogram declaration with no body of its own (a spec, an
# expression function) is never popped until its enclosing unit ends, so a site
# after one in the same declarative part is attributed to it. The name is a
# key for the manifest, and it is deterministic, which is what the key needs.
enclosing_entity() {
  awk -v target="$2" '
    NR > target { exit }
    {
      line = $0
      sub(/--.*$/, "", line)
      low = tolower(line)
      if (match(low, /^[ \t]*(procedure|function|package[ \t]+body|package)[ \t]+[a-z]/)) {
        rest = low
        sub(/^[ \t]*(procedure|function|package[ \t]+body|package)[ \t]+/, "", rest)
        name = substr(line, length(line) - length(rest) + 1)
        sub(/[^A-Za-z0-9_.].*$/, "", name)
        if (name != "") { depth++; stack[depth] = name }
      } else if (match(low, /^[ \t]*end[ \t]+[a-z]/)) {
        ends = low
        sub(/^[ \t]*end[ \t]+/, "", ends)
        sub(/[^a-z0-9_.].*$/, "", ends)
        found = 0
        for (i = depth; i >= 1; i--) if (tolower(stack[i]) == ends) { found = i; break }
        if (found) depth = found - 1
      }
    }
    END { if (depth >= 1) print stack[depth] }
  ' "$1"
}

derive() {
  local file kind line entity
  ada_sources | while IFS= read -r file; do
    scan_file "$file" | while IFS=: read -r kind line; do
      entity="$(enclosing_entity "$file" "$line")"
      if [ -z "$entity" ]; then
        echo "!! cannot name the entity at $file:$line ($kind) -- the gate needs one" >&2
        exit 2
      fi
      printf '%s|%s|%s\n' "$kind" "$file" "$entity"
    done
    if is_foreign "$file"; then
      printf '%s|%s|-\n' foreign-binding "$file"
    fi
  done
}

DERIVED="$(derive | sort -u)"

# --- --list: print the derived set in manifest form ---------------------------

if [ "$LIST" -eq 1 ]; then
  printf '%s\n' "$DERIVED" | while IFS='|' read -r kind path entity; do
    [ -z "$kind" ] && continue
    printf '%-16s | %-40s | %-24s | \n' "$kind" "$path" "$entity"
  done
  exit 0
fi

[ -f "$MANIFEST" ] || { echo "!! missing manifest $MANIFEST" >&2; exit 2; }

# --- reading the manifest -----------------------------------------------------

# Non-comment, non-blank lines, whitespace squeezed out of the key fields so the
# manifest can stay column-aligned for a human reader.
MANIFEST_KEYS="$(
  { grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$MANIFEST" || true; } \
  | awk -F'|' '{ for (i = 1; i <= 3; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i) }
                 print $1 "|" $2 "|" $3 }' \
  | sort -u
)"

# Entries whose justification field is empty or missing.
UNJUSTIFIED="$(
  { grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$MANIFEST" || true; } \
  | awk -F'|' '{ j = (NF >= 4 ? $4 : ""); gsub(/^[ \t]+|[ \t]+$/, "", j)
                 if (j == "") { for (i = 1; i <= 3; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i)
                                print $1 "|" $2 "|" $3 } }'
)"

# --- gate ---------------------------------------------------------------------

ADDED="$(comm -23 <(printf '%s\n' "$DERIVED") <(printf '%s\n' "$MANIFEST_KEYS") | sed '/^$/d' || true)"
STALE="$(comm -13 <(printf '%s\n' "$DERIVED") <(printf '%s\n' "$MANIFEST_KEYS") | sed '/^$/d' || true)"

fail=0

if [ -n "$ADDED" ]; then
  fail=1
  cat >&2 <<EOF

!! TRUST SURFACE GREW -- these sites are not in spark/$MANIFEST:

$(printf '%s\n' "$ADDED" | sed 's/^/     /')

   Each is something gnatprove does not prove. This crate is meant to be
   platinum, and the only expected entries are the FFI export shims.

   If the site is unavoidable: add a line to spark/$MANIFEST naming it and
   saying, in one sentence, why no SPARK formulation works, and report it in
   the PR as a hole. If it is not, the fix is in the code.
EOF
fi

if [ -n "$STALE" ]; then
  fail=1
  cat >&2 <<EOF

!! STALE MANIFEST ENTRIES -- listed in spark/$MANIFEST, absent from the tree:

$(printf '%s\n' "$STALE" | sed 's/^/     /')

   The trust surface shrank. Delete these lines.
EOF
fi

if [ -n "$UNJUSTIFIED" ]; then
  fail=1
  cat >&2 <<EOF

!! UNJUSTIFIED ENTRIES -- no text in the fourth field of spark/$MANIFEST:

$(printf '%s\n' "$UNJUSTIFIED" | sed 's/^/     /')

   An entry without a justification is an exception nobody has argued for.
EOF
fi

if [ "$fail" -ne 0 ]; then
  if [ -n "${GITHUB_STEP_SUMMARY-}" ]; then
    {
      echo "### Trust surface: drift from spark/$MANIFEST"
      echo
      echo '```'
      [ -n "$ADDED" ] && printf 'not in manifest:\n%s\n' "$ADDED"
      [ -n "$STALE" ] && printf 'stale:\n%s\n' "$STALE"
      [ -n "$UNJUSTIFIED" ] && printf 'unjustified:\n%s\n' "$UNJUSTIFIED"
      echo '```'
    } >> "$GITHUB_STEP_SUMMARY"
  fi
  exit 1
fi

n_sources="$(ada_sources | grep -c . || true)"
n_sites="$(printf '%s\n' "$DERIVED" | grep -c . || true)"
echo ">> TRUST SURFACE OK -- ${n_sites} site(s) over ${n_sources} tracked source(s), all in spark/$MANIFEST."
