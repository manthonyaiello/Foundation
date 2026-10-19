#!/usr/bin/env bash
#
# check-saw.sh -- SAW's llvm_verify of the SPARK AES implementation against
# NSA's Cryptol, on GNAT-LLVM bitcode of the crate's own sources (E4, #21;
# M4.1, #22). README "SAW".
#
# LOCAL ONLY: never wired into a CI workflow. It needs GNAT Pro's LLVM back
# end (llvm-gcc), which CI does not have and which nobody without GNAT Pro
# can install. The crate's gate toolchain stays FSF GNAT 16.1; GNAT Pro is
# used here only to make bitcode for SAW. Because no one else can rerun it,
# every run records its provenance in saw/results.txt: the commit, the date,
# the tool versions, the compiler switches, the sha256 of each bitcode file,
# of each source compiled into it and of each Cryptol file imported, every
# result, the negative controls' counterexamples, and the wall-clock.
#
# What it does:
#   1. compiles each unit of UNITS below with $GNAT_LLVM_DIR/bin/llvm-gcc
#      to saw/obj/<unit>.bc (SWITCHES below), and links them with
#      $LLVM_LINK_DIR/bin/llvm-link into one module, saw/obj/aes.bc (M4.2,
#      #23): SAW takes an override only from the module being verified, and
#      AES.Impl calls AES.Spec.Types;
#   2. checks the bitcode, each unit's and the linked module: no symbol of a
#      ghost unit (the spec layer and the lemmas) is defined or referenced;
#   3. runs saw/aes_impl.saw, every llvm_verify of which must succeed;
#   4. runs each saw/negative/*.saw, every one of which must FAIL with a
#      counterexample (the negative controls);
#   5. writes saw/results.txt (unless --print).
#
# Usage:
#   scripts/check-saw.sh           run, and record saw/results.txt
#   scripts/check-saw.sh --print   run, and print the record instead
#
# Recording needs a clean tree (outside saw/results.txt): the record names
# HEAD as the commit checked, and a dirty tree is not HEAD.
#
# Env:
#   GNAT_LLVM_DIR  REQUIRED: the GNAT Pro LLVM install, with bin/llvm-gcc and
#                  bin/llvm-nm (e.g. .../gnatpro-llvm-ada/install).
#   LLVM_LINK_DIR  REQUIRED: a directory with bin/llvm-link of the LLVM
#                  release pinned in toolchain-pins.env (LLVM_LINK_VERSION),
#                  which must also be the LLVM of GNAT_LLVM_DIR's llvm-gcc.
#                  GNAT Pro ships no llvm-link; the bootstrap's gnat-llvm
#                  phase installs LLVM's own release (README "SAW").
#   saw, cryptol and z3 must be on PATH (the x86_64 bootstrap's env.sh).
#
# Exit status: 0 when every proof passed and every negative control failed;
# 1 otherwise; 2 on a usage error.
#
set -euo pipefail

SPARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$SPARK_DIR/.." && pwd)"
SAW_DIR="$SPARK_DIR/saw"
OBJ_DIR="$SAW_DIR/obj"
RESULTS="$SAW_DIR/results.txt"

die() { printf '!! %s\n' "$*" >&2; exit 1; }

PRINT=0
case "${1:-}" in
  "") ;;
  --print) PRINT=1 ;;
  -h|--help) sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d'; exit 0 ;;
  *) echo "check-saw.sh: unknown argument: $1" >&2; exit 2 ;;
esac

# --- the toolchain -------------------------------------------------------------

[ -n "${GNAT_LLVM_DIR:-}" ] || die "GNAT_LLVM_DIR is unset. This check needs GNAT Pro's LLVM back end:
   set GNAT_LLVM_DIR to its install directory (the one holding bin/llvm-gcc).
   It is local only and not part of CI (README \"SAW\")."
LLVM_GCC="$GNAT_LLVM_DIR/bin/llvm-gcc"
LLVM_NM="$GNAT_LLVM_DIR/bin/llvm-nm"
[ -x "$LLVM_GCC" ] || die "GNAT_LLVM_DIR=$GNAT_LLVM_DIR has no bin/llvm-gcc"
[ -x "$LLVM_NM" ] || die "GNAT_LLVM_DIR=$GNAT_LLVM_DIR has no bin/llvm-nm"
[ -n "${LLVM_LINK_DIR:-}" ] || die "LLVM_LINK_DIR is unset. This check links two units' bitcode with
   llvm-link, which GNAT Pro does not ship: set LLVM_LINK_DIR to the directory
   holding bin/llvm-link of LLVM's own release (the x86_64 bootstrap's
   gnat-llvm phase installs it, README \"SAW\")."
LLVM_LINK="$LLVM_LINK_DIR/bin/llvm-link"
[ -x "$LLVM_LINK" ] || die "LLVM_LINK_DIR=$LLVM_LINK_DIR has no bin/llvm-link"
for t in saw cryptol z3; do
  command -v "$t" >/dev/null 2>&1 || die "$t is not on PATH (source the bootstrap's env.sh)"
done

# Captured, not piped into head: a tool can die of SIGPIPE under pipefail.
first_line() { local out; out="$("$@" 2>&1)" || true; printf '%s\n' "${out%%$'\n'*}"; }
V_LLVM_GCC="$(first_line "$LLVM_GCC" --version)"
V_LLVM="$("$LLVM_NM" --version 2>&1 | sed -n 's/^ *LLVM version //p')"
V_LLVM_LINK="$("$LLVM_LINK" --version 2>&1 | sed -n 's/^ *LLVM version //p')"
# The pinned release: llvm-link must be it, and it must be GNAT-LLVM's own
# LLVM, so that the linker reads and writes the bitcode llvm-gcc makes.
# shellcheck source=toolchain-pins.env
. "$SPARK_DIR/scripts/toolchain-pins.env"
[ "$V_LLVM_LINK" = "$LLVM_LINK_VERSION" ] \
  || die "$LLVM_LINK is LLVM ${V_LLVM_LINK:-?}, not the pinned $LLVM_LINK_VERSION (toolchain-pins.env)"
[ "$V_LLVM" = "$LLVM_LINK_VERSION" ] \
  || die "GNAT_LLVM_DIR's llvm-gcc is LLVM ${V_LLVM:-?}, but llvm-link is the pinned $LLVM_LINK_VERSION: they must match"
V_SAW="$(first_line saw --version)"
V_CRYPTOL="$(cryptol --version 2>&1 | tr '\n' ' ' | sed 's/  */ /g; s/ $//')"
V_Z3="$(first_line z3 --version)"

# --- what is compiled, and how ----------------------------------------------------

# The units compiled to bitcode, as files under spark/src: AES.Impl, and
# the non-ghost AES.Spec.Types whose expression functions (Nk, Nr, Split,
# Join) AES.Impl calls, and which -O0 leaves as calls to external symbols.
UNITS=(aes/foundation_spark-aes-impl.adb aes/foundation_spark-aes-spec-types.ads)

# The one module SAW loads: UNITS linked by llvm-link.
LINKED="aes.bc"

# -gnatp: no run-time checks in the bitcode (gnatprove proves them absent).
# -gnatVn: no validity checks. No -gnata: assertions, contracts and ghost
#   code are ignored (Assertion_Policy Ignore), so none reaches the bitcode;
#   step 2 checks that.
# -O0: SAW 1.6 (crucible) panics on the `insertvalue <ty> poison` that
#   LLVM's SROA emits at -O1 and above for GNAT's array returns.
# No -g: SAW 1.6 rejects the debug metadata (METADATA_BLOCK "not yet
#   implemented").
# The bitcode is <unit>.bc in the working directory: llvm-gcc refuses -o
#   with a .bc name ("incorrect object file extension").
SWITCHES=(-c -gnat2022 -gnatp -gnatVn -O0 -emit-llvm)

# The ghost units: none of their symbols may appear in the bitcode.
GHOST_RE='foundation_spark__aes__(spec__(cipher|gf2|gf28|keyexpansion|main|properties|sbox)|lemmas|main_lemmas)(__|_E$|$)'

# The NSA Cryptol that the scripts import, directly or through its imports.
CRYPTOL_FILES=(
  algorithms/AES/Types.cry
  algorithms/AES/GF28.cry
  algorithms/AES/SBox.cry
  algorithms/AES/Cipher.cry
  algorithms/AES/KeyExpansion.cry
  shared/algebra/Polynomial/GF2.cry
  shared/common/utils/Prime.cry
)

T0="$(date +%s)"
COMMIT="$(git -C "$ROOT_DIR" rev-parse HEAD)"
if [ "$PRINT" -eq 0 ] \
   && [ -n "$(git -C "$ROOT_DIR" status --porcelain -- spark algorithms shared ':!spark/saw/results.txt' ':!spark/saw/obj' ':!spark/obj' ':!spark/lib' ':!spark/alire' ':!spark/config' ':!spark/docs')" ]; then
  die "the tree has changes: commit them, or use --print (the record names HEAD as the commit checked)"
fi
DIRTY=""
[ -z "$(git -C "$ROOT_DIR" status --porcelain -- spark/src spark/saw algorithms shared ':!spark/saw/results.txt' ':!spark/saw/obj')" ] \
  || DIRTY=" (with uncommitted changes: not a record)"

# NSA's Cryptol is never modified here: it must be the commit's, even with
# --print.
for f in "${CRYPTOL_FILES[@]}"; do
  [ -f "$ROOT_DIR/$f" ] || die "missing $f"
  git -C "$ROOT_DIR" diff --quiet HEAD -- "$f" || die "$f differs from HEAD: NSA's Cryptol is never modified"
done

# --- 1. compile ----------------------------------------------------------------------

INCLUDES=()
while IFS= read -r d; do INCLUDES+=("-I$d"); done < <(find "$SPARK_DIR/src" -type d | sort)

rm -rf "$OBJ_DIR"
mkdir -p "$OBJ_DIR"
for u in "${UNITS[@]}"; do
  echo ">> llvm-gcc ${SWITCHES[*]} src/$u"
  (cd "$OBJ_DIR" && "$LLVM_GCC" "${SWITCHES[@]}" "${INCLUDES[@]}" "$SPARK_DIR/src/$u")
done

# --- 2. no ghost code in the bitcode ---------------------------------------------------

no_ghost() {  # no_ghost BC: die if BC defines or references a ghost unit's symbol
  local bc="$1" syms ghost
  syms="$("$LLVM_NM" "$bc")"
  ghost="$(printf '%s\n' "$syms" | awk '{print $NF}' | grep -E "$GHOST_RE" || true)"
  [ -z "$ghost" ] || die "ghost symbols in $(basename "$bc"):
$ghost"
  echo ">> $(basename "$bc"): $(printf '%s\n' "$syms" | grep -c ' [TtDdRrBb] ') symbols defined, none of a ghost unit; undefined: $(printf '%s\n' "$syms" | awk '$1 == "U" {print $2}' | tr '\n' ' ')"
}

BITCODE=()
for u in "${UNITS[@]}"; do
  bc="$OBJ_DIR/$(basename "${u%.*}").bc"
  [ -f "$bc" ] || die "llvm-gcc wrote no $bc"
  BITCODE+=("$bc")
  no_ghost "$bc"
done

echo ">> llvm-link ${BITCODE[*]##*/} -o $LINKED"
"$LLVM_LINK" "${BITCODE[@]}" -o "$OBJ_DIR/$LINKED"
no_ghost "$OBJ_DIR/$LINKED"
BITCODE+=("$OBJ_DIR/$LINKED")

# --- 3. the proofs ---------------------------------------------------------------------

export CRYPTOLPATH="$ROOT_DIR"
LOG_DIR="$OBJ_DIR/logs"
mkdir -p "$LOG_DIR"

run_saw() {  # run_saw FILE LOG: saw FILE from saw/, its output in LOG; returns saw's status
  local status=0
  (cd "$SAW_DIR" && saw "$1") > "$2" 2>&1 || status=$?
  return "$status"
}

PROVED=()
echo ">> saw aes_impl.saw"
t="$(date +%s)"
if ! run_saw aes_impl.saw "$LOG_DIR/aes_impl.log"; then
  grep -v 'override\|^Matching\|^Branching' "$LOG_DIR/aes_impl.log" | tail -40 >&2
  die "saw aes_impl.saw FAILED (log: $LOG_DIR/aes_impl.log)"
fi
T_PROOFS=$(( $(date +%s) - t ))
# Each RESULT line, with the time SAW's `time` printed just before it for
# that llvm_verify (aes_impl_common.saw's verify_symbol).
while IFS= read -r line; do PROVED+=("$line"); done < <(awk '
  /^Time: / { t = $2; sub(/s$/, "", t) }
  /^RESULT proved / { sub(/^RESULT proved /, ""); printf "%s, %.2f s\n", $0, t; t = "" }
' "$LOG_DIR/aes_impl.log")
[ "${#PROVED[@]}" -gt 0 ] || die "saw aes_impl.saw proved nothing (log: $LOG_DIR/aes_impl.log)"
n_succeeded="$(grep -c '^Proof succeeded!' "$LOG_DIR/aes_impl.log" || true)"
[ "$n_succeeded" -eq "${#PROVED[@]}" ] \
  || die "aes_impl.saw: $n_succeeded proofs succeeded but ${#PROVED[@]} RESULT lines"
for p in "${PROVED[@]}"; do echo "   proved $p"; done

# --- 4. the negative controls ---------------------------------------------------------------

NEGATIVE=()
for f in "$SAW_DIR"/negative/*.saw; do
  name="negative/$(basename "$f")"
  log="$LOG_DIR/$(basename "$f" .saw).log"
  echo ">> saw $name (must fail)"
  if run_saw "$name" "$log"; then
    die "NEGATIVE CONTROL PROVED: $name must fail (log: $log)"
  fi
  grep -q '^Proof failed\.' "$log" && grep -q -- '-Counterexample-' "$log" \
    || { tail -20 "$log" >&2; die "$name failed without a counterexample (log: $log)"; }
  target="$(sed -n 's/^Verifying \(.*\)\.\.\.$/\1/p' "$log" | tail -1)"
  cex="$(sed -n '/-Counterexample-/,/^---*$/p' "$log" | sed '1d;$d' | sed 's/^ *//' | tr '\n' ' ' | sed 's/ $//')"
  NEGATIVE+=("$name: $target fails, counterexample $cex")
  echo "   failed as it must: $target, counterexample $cex"
done
[ "${#NEGATIVE[@]}" -gt 0 ] || die "no negative control in saw/negative/"

T_TOTAL=$(( $(date +%s) - T0 ))

# --- 5. the record --------------------------------------------------------------------------

sha() { sha256sum "$1" | cut -d' ' -f1; }

record() {
  echo "# saw/results.txt -- written by scripts/check-saw.sh; do not edit."
  echo "#"
  echo "# SAW llvm_verify of the SPARK AES implementation's bitcode against NSA's"
  echo "# Cryptol. Local only (GNAT Pro LLVM), never run by CI: this record is the"
  echo "# provenance of the result. README \"SAW\"."
  echo
  echo "commit      $COMMIT$DIRTY"
  echo "date        $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "host        $(uname -m), $(nproc) CPUs"
  echo "llvm-gcc    $V_LLVM_GCC"
  echo "llvm        $V_LLVM"
  echo "llvm-link   $V_LLVM_LINK ($LLVM_LINK_TARBALL, sha256 $LLVM_LINK_SHA256)"
  echo "saw         $V_SAW"
  echo "cryptol     $V_CRYPTOL"
  echo "solvers     rme (SAW's built-in); z3 on PATH: $V_Z3 (each proof's below)"
  echo "switches    ${SWITCHES[*]}"
  for bc in "${BITCODE[@]}"; do
    echo "bitcode     $(sha "$bc") $(basename "$bc")"
  done
  # The sources the front end read for the units (their ALIs' D lines),
  # each once: ours by sha256; the GNAT Pro runtime's by name and the ALI's
  # checksum.
  for u in "${UNITS[@]}"; do
    grep '^D ' "$OBJ_DIR/$(basename "${u%.*}").ali"
  done | awk '!seen[$2]++' | while read -r _ file _ cksum _; do
    src="$(find "$SPARK_DIR/src" -name "$file" -print -quit)"
    if [ -n "$src" ]; then
      echo "source      $(sha "$src") ${src#"$SPARK_DIR"/}"
    else
      echo "runtime     $cksum $file"
    fi
  done
  for f in "${CRYPTOL_FILES[@]}"; do
    echo "cryptol     $(sha "$ROOT_DIR/$f") $f"
  done
  for p in "${PROVED[@]}"; do
    echo "proved      $p"
  done
  for n in "${NEGATIVE[@]}"; do
    echo "negative    $n"
  done
  echo "wall-clock  ${T_PROOFS} s for aes_impl.saw; ${T_TOTAL} s in all"
}

if [ "$PRINT" -eq 1 ]; then
  record
else
  record > "$RESULTS"
  echo ">> wrote ${RESULTS#"$ROOT_DIR"/}"
fi
echo ">> SAW: ${#PROVED[@]} proved, ${#NEGATIVE[@]} negative controls failed as they must (${T_TOTAL} s)"
