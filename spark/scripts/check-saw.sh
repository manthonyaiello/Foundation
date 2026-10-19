#!/usr/bin/env bash
#
# check-saw.sh -- SAW's llvm_verify of the SPARK AES, SHA-256 and
# HMAC-SHA-256 implementations, and of the AES spec layer, against NSA's
# Cryptol, on GNAT-LLVM bitcode of the crate's own sources (E4, #21; M4.1
# #22, M4.2 #23, M4.3 #24, M4.4 #59). README "SAW".
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
# What it does, for each module of MODULES below (aes, sha256):
#   1. compiles each of the module's units with $GNAT_LLVM_DIR/bin/llvm-gcc
#      to saw/obj/<unit>.bc (SWITCHES below), and links them with
#      $LLVM_LINK_DIR/bin/llvm-link into one module, saw/obj/<module>.bc
#      (M4.2, #23): SAW takes an override only from the module being
#      verified;
#   2. checks the bitcode, each unit's and the linked module: no symbol of a
#      ghost entity (the spec layer, the lemmas, ghost functions of the
#      implementation units) is defined or referenced;
#   3. refuses any llvm_unsafe_assume_spec in saw/ (every override must be
#      a proof), then runs saw/<module>_impl.saw, every llvm_verify of
#      which must succeed;
# then, for each module of SPEC_MODULES (aes_spec), the spec layer (M4.4):
#   1. compiles its units the same way plus -fno-inline and the
#      configuration pragmas of saw/spec.adc (ghost code on, every other
#      assertion kind off) to saw/obj/spec/<unit>.bc, and links them into
#      saw/obj/spec/<module>.bc;
#   2. checks the opposite of the implementation's step 2: the bitcode
#      defines the spec layer's ghost symbols;
#   3. runs saw/<module>.saw, every llvm_verify of which must succeed;
# and then:
#   4. runs each saw/negative/*.saw, every one of which must FAIL with a
#      counterexample (the negative controls);
#   5. writes saw/results.txt (unless --print).
#
# Every saw run is in its own systemd scope capped at SAW_MEMORY_MAX (10G,
# no swap) when systemd-run --user works, so that a proof that blows up is
# killed alone instead of taking the machine down (#24: one did, at
# 15.7 GB). A run killed by the cap is a failure, reported as such. Without
# systemd-run the runs are not capped, and the script says so.
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
#   SAW_MEMORY_MAX optional: the memory cap of each saw run (default 10G).
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
[ -n "${LLVM_LINK_DIR:-}" ] || die "LLVM_LINK_DIR is unset. This check links each module's units'
   bitcode with llvm-link, which GNAT Pro does not ship: set LLVM_LINK_DIR to
   the directory holding bin/llvm-link of LLVM's own release (the x86_64
   bootstrap's gnat-llvm phase installs it, README \"SAW\")."
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

# The memory cap of each saw run: its own systemd scope when the user
# manager answers (an OOM then kills that scope alone), else no cap.
SAW_MEMORY_MAX="${SAW_MEMORY_MAX:-10G}"
CAP=()
if command -v systemd-run >/dev/null 2>&1 \
   && systemd-run --user --scope -q -p MemoryMax=1G true >/dev/null 2>&1; then
  CAP=(systemd-run --user --scope -q -p "MemoryMax=$SAW_MEMORY_MAX" -p MemorySwapMax=0)
  CAP_NOTE="each saw run in its own systemd scope, MemoryMax=$SAW_MEMORY_MAX, MemorySwapMax=0"
else
  CAP_NOTE="none: systemd-run --user is not available, saw runs uncapped"
  echo ">> NOTE: systemd-run --user is not available: the saw runs are NOT memory-capped" >&2
fi

# --- what is compiled, and how ----------------------------------------------------

# The modules SAW loads, each the units listed (files under spark/src)
# linked by llvm-link into saw/obj/<module>.bc, and the script of proofs
# run on it, saw/<module>_impl.saw.
MODULES=(aes sha256)

# aes: AES.Impl, and the non-ghost AES.Spec.Types whose expression
# functions (Nk, Nr, Split, Join) AES.Impl calls, and which -O0 leaves as
# calls to external symbols.
UNITS_aes=(aes/foundation_spark-aes-impl.adb aes/foundation_spark-aes-spec-types.ads)

# sha256: SHA2.SHA256_Stream (Compress, Hash), the SHA-256 instance of the
# generic SHA2.Main (Ch, Maj, "+"), SHA2.Functions (the SIGMA and sigma
# functions, and the Notation instances' ROTR and SHR), which
# SHA256_Stream calls; and HMAC.SHA256_Impl, which calls SHA256_Stream.
UNITS_sha256=(
  sha2/foundation_spark-sha2-sha256_stream.adb
  sha2/foundation_spark-sha2-sha256.ads
  sha2/foundation_spark-sha2-functions.ads
  hmac/foundation_spark-hmac-sha256_impl.adb
)

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

# The spec layer's modules (M4.4, #59), each the units listed linked into
# saw/obj/spec/<module>.bc, and the script of proofs run on it,
# saw/<module>.saw.
SPEC_MODULES=(aes_spec)

# aes_spec: the AES spec layer's units whose functions the script proves
# (all ghost but AES.Spec.Types). AES.Spec.Main is not among them: its
# functions return their bit sequences on the secondary stack (README
# "SAW").
UNITS_aes_spec=(
  aes/foundation_spark-aes-spec-types.ads
  aes/foundation_spark-aes-spec-gf28.ads
  aes/foundation_spark-aes-spec-gf2.ads
  aes/foundation_spark-aes-spec-sbox.ads
  aes/foundation_spark-aes-spec-cipher.ads
  aes/foundation_spark-aes-spec-keyexpansion.ads
)

# The spec layer's switches: the implementation's, plus
# -fno-inline: GNAT-LLVM marks every expression function alwaysinline, and
#   the spec layer is expression functions: inlined, a recursive fold's
#   call to its round function, or KeyExpansion's W's to SubWord, is no
#   call, and no lemma can be its override. -fno-inline keeps each a call
#   (noinline) and changes nothing else.
# -gnatec=saw/spec.adc: Assertion_Policy Ghost => Check and everything
#   else Ignore: the ghost code is compiled, and no contract or assertion.
SPEC_OBJ_DIR="$OBJ_DIR/spec"
SPEC_ADC="$SAW_DIR/spec.adc"
SPEC_SWITCHES=("${SWITCHES[@]}" -fno-inline "-gnatec=$SPEC_ADC")

# Linked into every spec module: the spec functions that return an
# unconstrained array do so on the secondary stack, so the module carries
# GNAT Pro's own System.Secondary_Stack and System.Soft_Links, compiled
# from the runtime's sources as the runtime is (-gnatg), and the harness
# adapter saw/saw_soft_links.ads (README "SAW", "The secondary stack").
RTS_SRC="$(dirname "$(find "$GNAT_LLVM_DIR/lib/gnat-llvm" -path '*/rts-native/adainclude/s-secsta.adb' -print -quit)")"
[ -f "$RTS_SRC/s-secsta.adb" ] || die "no rts-native/adainclude/s-secsta.adb under $GNAT_LLVM_DIR/lib/gnat-llvm"
RTS_UNITS=(s-secsta.adb s-soflin.adb)
RTS_SWITCHES=(-c -gnatg -gnatp -O0 -emit-llvm)
HARNESS_UNITS=(saw_soft_links.ads)

# The ghost entities: none of their symbols may appear in the
# implementation's bitcode (the spec layer's must define them).
#  - AES: the spec layer's units and the lemmas (all ghost);
#  - SHA-256 and HMAC: the ghost units SHA2.SHA256_Blocks, HMAC.Main and
#    its instance HMAC.SHA256; the ghost functions of the units that also
#    hold executable code (the SHA2 root, the SHA-256 instance of Main,
#    SHA256_Bytes, SHA256_Stream, the HMAC root, HMAC.SHA256_Impl); and
#    every lemma (`__lemma_`), wherever it is declared.
GHOST_RE_AES='foundation_spark__aes__(spec__(cipher|gf2|gf28|keyexpansion|main|properties|sbox)|lemmas|main_lemmas)(__|_E$|$)'
GHOST_RE_SHA='foundation_spark__(sha2__sha256_blocks|hmac__main|hmac__sha256)(__|_E$|$)'
GHOST_RE_SHA+='|foundation_spark__sha2__(ceil_div|ceil_mod|to_bits)$'
GHOST_RE_SHA+='|foundation_spark__sha2__sha256__(w|t1|t2|step3|foldl_step3|step|small_k|n|zero|pad|word_of|parse_block|parse|foldl_step|bit|join|hash)$'
GHOST_RE_SHA+='|foundation_spark__sha2__sha256_bytes__(byte_bit|bits_of|blocks|length_byte|padded_byte|pad_bytes|word_at|block_at|parse_bytes|word_byte|digest_bytes|hash_bytes)$'
GHOST_RE_SHA+='|foundation_spark__sha2__sha256_stream__(models|absorbed|finished|joined|tail_blocks|tail_pad|empty)$'
GHOST_RE_SHA+='|foundation_spark__hmac__(byte_bit|join|repeat|zero)$'
GHOST_RE_SHA+='|foundation_spark__hmac__sha256_impl__(to_bytes|models|absorbed|finished|inner_prefix|inner_message|outer_message)$'
GHOST_RE_SHA+='|__lemma_'
GHOST_RE="$GHOST_RE_AES|$GHOST_RE_SHA"

# The NSA Cryptol that the scripts import, directly or through its imports.
CRYPTOL_FILES=(
  algorithms/AES/Types.cry
  algorithms/AES/GF28.cry
  algorithms/AES/SBox.cry
  algorithms/AES/Cipher.cry
  algorithms/AES/KeyExpansion.cry
  shared/algebra/Polynomial/GF2.cry
  shared/common/utils/Prime.cry
  algorithms/SHA2/Main.cry
  algorithms/SHA2/Notation.cry
  algorithms/SHA2/Functions.cry
  algorithms/SHA2/Preprocessing.cry
  algorithms/HMAC/Main.cry
)
# Our own Cryptol in saw/: instantiations of NSA's, recorded by sha256.
OUR_CRYPTOL=(spark/saw/SHA256Main.cry)

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

# --- 1. compile, and 2. no ghost code in the bitcode -----------------------------------

INCLUDES=()
while IFS= read -r d; do INCLUDES+=("-I$d"); done < <(find "$SPARK_DIR/src" -type d | sort)

no_ghost() {  # no_ghost BC: die if BC defines or references a ghost entity's symbol
  local bc="$1" syms ghost
  syms="$("$LLVM_NM" "$bc")"
  ghost="$(printf '%s\n' "$syms" | awk '{print $NF}' | grep -E "$GHOST_RE" || true)"
  [ -z "$ghost" ] || die "ghost symbols in $(basename "$bc"):
$ghost"
  echo ">> $(basename "$bc"): $(printf '%s\n' "$syms" | grep -c ' [TtDdRrBb] ') symbols defined, none of a ghost entity; undefined: $(printf '%s\n' "$syms" | awk '$1 == "U" {print $2}' | tr '\n' ' ')"
}

has_ghost() {  # has_ghost BC: die unless BC defines ghost entities' symbols
  local bc="$1" syms ghost
  syms="$("$LLVM_NM" "$bc")"
  ghost="$(printf '%s\n' "$syms" | awk '$(NF-1) ~ /^[TtDdRrBb]$/ {print $NF}' | grep -cE "$GHOST_RE" || true)"
  [ "$ghost" -gt 0 ] || die "no ghost symbol defined in $(basename "$bc"): is ghost code compiled?"
  echo ">> $(basename "$bc"): $(printf '%s\n' "$syms" | grep -c ' [TtDdRrBb] ') symbols defined, $ghost of them ghost; undefined: $(printf '%s\n' "$syms" | awk '$1 == "U" {print $2}' | tr '\n' ' ')"
}

rm -rf "$OBJ_DIR"
mkdir -p "$OBJ_DIR" "$SPEC_OBJ_DIR"
BITCODE=()
ALL_ALIS=()
for mod in "${MODULES[@]}"; do
  declare -n units="UNITS_$mod"
  mod_bc=()
  for u in "${units[@]}"; do
    echo ">> llvm-gcc ${SWITCHES[*]} src/$u"
    (cd "$OBJ_DIR" && "$LLVM_GCC" "${SWITCHES[@]}" "${INCLUDES[@]}" "$SPARK_DIR/src/$u")
    bc="$OBJ_DIR/$(basename "${u%.*}").bc"
    [ -f "$bc" ] || die "llvm-gcc wrote no $bc"
    no_ghost "$bc"
    mod_bc+=("$bc")
    ALL_ALIS+=("${bc%.bc}.ali")
  done
  unset -n units
  echo ">> llvm-link ${mod_bc[*]##*/} -o $mod.bc"
  "$LLVM_LINK" "${mod_bc[@]}" -o "$OBJ_DIR/$mod.bc"
  no_ghost "$OBJ_DIR/$mod.bc"
  BITCODE+=("${mod_bc[@]}" "$OBJ_DIR/$mod.bc")
done

# The secondary stack, compiled once and linked into each spec module.
SS_BC=()
for u in "${RTS_UNITS[@]}"; do
  echo ">> llvm-gcc ${RTS_SWITCHES[*]} <runtime>/adainclude/$u"
  (cd "$SPEC_OBJ_DIR" && "$LLVM_GCC" "${RTS_SWITCHES[@]}" "$RTS_SRC/$u")
  bc="$SPEC_OBJ_DIR/${u%.*}.bc"
  [ -f "$bc" ] || die "llvm-gcc wrote no $bc"
  SS_BC+=("$bc")
  ALL_ALIS+=("${bc%.bc}.ali")
done
for u in "${HARNESS_UNITS[@]}"; do
  echo ">> llvm-gcc ${SPEC_SWITCHES[*]} saw/$u"
  (cd "$SPEC_OBJ_DIR" && "$LLVM_GCC" "${SPEC_SWITCHES[@]}" -gnatwI "$SAW_DIR/$u")
  bc="$SPEC_OBJ_DIR/${u%.*}.bc"
  [ -f "$bc" ] || die "llvm-gcc wrote no $bc"
  SS_BC+=("$bc")
  ALL_ALIS+=("${bc%.bc}.ali")
done
BITCODE+=("${SS_BC[@]}")

# The spec layer: ghost code compiled, so its symbols are expected.
for mod in "${SPEC_MODULES[@]}"; do
  declare -n units="UNITS_$mod"
  mod_bc=()
  for u in "${units[@]}"; do
    echo ">> llvm-gcc ${SPEC_SWITCHES[*]} src/$u"
    (cd "$SPEC_OBJ_DIR" && "$LLVM_GCC" "${SPEC_SWITCHES[@]}" "${INCLUDES[@]}" "$SPARK_DIR/src/$u")
    bc="$SPEC_OBJ_DIR/$(basename "${u%.*}").bc"
    [ -f "$bc" ] || die "llvm-gcc wrote no $bc"
    mod_bc+=("$bc")
    ALL_ALIS+=("${bc%.bc}.ali")
  done
  unset -n units
  echo ">> llvm-link ${mod_bc[*]##*/} ${SS_BC[*]##*/} -o spec/$mod.bc"
  "$LLVM_LINK" "${mod_bc[@]}" "${SS_BC[@]}" -o "$SPEC_OBJ_DIR/$mod.bc"
  has_ghost "$SPEC_OBJ_DIR/$mod.bc"
  BITCODE+=("${mod_bc[@]}" "$SPEC_OBJ_DIR/$mod.bc")
done

# --- 3. the proofs ---------------------------------------------------------------------

# No assumption: every override must be a proof (README "SAW").
assumed="$(grep -rn --include='*.saw' -E 'llvm_unsafe_assume_spec|_unsafe_assume' "$SAW_DIR" || true)"
[ -z "$assumed" ] || die "an assumed spec in saw/: every override must be proved:
$assumed"

export CRYPTOLPATH="$ROOT_DIR"
LOG_DIR="$OBJ_DIR/logs"
mkdir -p "$LOG_DIR"

KILLED_BY_CAP=137  # 128 + SIGKILL: what a scope killed by its MemoryMax returns

run_saw() {  # run_saw FILE LOG: saw FILE from saw/, capped, its output in LOG; returns saw's status
  local status=0
  (cd "$SAW_DIR" && "${CAP[@]}" saw "$1") > "$2" 2>&1 || status=$?
  if [ "$status" -eq "$KILLED_BY_CAP" ] && [ "${#CAP[@]}" -gt 0 ]; then
    echo "!! KILLED (SIGKILL): saw $1 reached the memory cap ($SAW_MEMORY_MAX)" >> "$2"
  fi
  return "$status"
}

PROVED=()
T_PROOFS=()
N_PROVED=0
N_SPEC=0
SCRIPTS=()
for mod in "${MODULES[@]}"; do SCRIPTS+=("${mod}_impl"); done
for mod in "${SPEC_MODULES[@]}"; do SCRIPTS+=("$mod"); done
for name in "${SCRIPTS[@]}"; do
  script="$name.saw"
  log="$LOG_DIR/$name.log"
  echo ">> saw $script"
  t="$(date +%s)"
  status=0
  run_saw "$script" "$log" || status=$?
  if [ "$status" -ne 0 ]; then
    grep -v 'override\|^Matching\|^Branching\|^  variant' "$log" | tail -40 >&2
    [ "$status" -ne "$KILLED_BY_CAP" ] || die "saw $script was KILLED by the memory cap ($SAW_MEMORY_MAX): a failure (log: $log)"
    die "saw $script FAILED (log: $log)"
  fi
  T_PROOFS+=("$(( $(date +%s) - t )) s for $script")
  # Each RESULT line, with the time SAW's `time` printed just before it for
  # that llvm_verify (the common files' verify_symbol). A RESULTS line
  # ("RESULTS <n> proved ...", the spec scripts' print_results) stands for
  # n proofs of one subprogram, one per value of its argument; the time
  # before the first of a run of them is the whole run's.
  case "$name" in
    *_impl) prefix="" ;;
    *) prefix="spec layer: " ;;
  esac
  mod_proved=()
  while IFS= read -r line; do mod_proved+=("$line"); done < <(awk -v prefix="$prefix" '
    /^Time: / { t = $2; sub(/s$/, "", t) }
    /^RESULT proved / { sub(/^RESULT proved /, ""); printf "1 %s%s, %.2f s\n", prefix, $0, t; t = "" }
    /^RESULTS [0-9]+ proved / {
      n = $2; sub(/^RESULTS [0-9]+ proved /, "")
      if (t != "") printf "%d %s%s (%d proofs, one per value), %.2f s with the lines below\n", n, prefix, $0, n, t
      else printf "%d %s%s (%d proofs, one per value), timed with the line above\n", n, prefix, $0, n
      t = ""
    }
  ' "$log")
  [ "${#mod_proved[@]}" -gt 0 ] || die "saw $script proved nothing (log: $log)"
  n_lines=0
  for p in "${mod_proved[@]}"; do n_lines=$(( n_lines + ${p%% *} )); done
  n_succeeded="$(grep -c '^Proof succeeded!' "$log" || true)"
  [ "$n_succeeded" -eq "$n_lines" ] \
    || die "$script: $n_succeeded proofs succeeded but the RESULT lines count $n_lines"
  N_PROVED=$(( N_PROVED + n_lines ))
  [ -z "$prefix" ] || N_SPEC=$(( N_SPEC + n_lines ))
  for p in "${mod_proved[@]}"; do echo "   proved ${p#* }"; PROVED+=("${p#* }"); done
done

# --- 4. the negative controls ---------------------------------------------------------------

NEGATIVE=()
for f in "$SAW_DIR"/negative/*.saw; do
  name="negative/$(basename "$f")"
  log="$LOG_DIR/$(basename "$f" .saw).log"
  echo ">> saw $name (must fail)"
  status=0
  run_saw "$name" "$log" || status=$?
  [ "$status" -ne 0 ] || die "NEGATIVE CONTROL PROVED: $name must fail (log: $log)"
  [ "$status" -ne "$KILLED_BY_CAP" ] \
    || die "$name was KILLED by the memory cap ($SAW_MEMORY_MAX), not refuted (log: $log)"
  grep -q '^Proof failed\.' "$log" && grep -q -- '-Counterexample-' "$log" \
    || { tail -20 "$log" >&2; die "$name failed without a counterexample (log: $log)"; }
  target="$(sed -n 's/^Verifying \(.*\)\.\.\.$/\1/p' "$log" | tail -1)"
  cex="$(sed -n '/-Counterexample-/,/^---*$/p' "$log" | sed '1d;$d' | sed 's/^ *//' | tr '\n' ' ' | sed 's/ $//')"
  t_neg="$(awk '/^Time: / { t = $2 } END { sub(/s$/, "", t); if (t != "") printf "%.2f s", t }' "$log")"
  NEGATIVE+=("$name: $target fails${t_neg:+ in $t_neg}, counterexample $cex")
  echo "   failed as it must: $target, counterexample $cex"
done
[ "${#NEGATIVE[@]}" -gt 0 ] || die "no negative control in saw/negative/"

T_TOTAL=$(( $(date +%s) - T0 ))

# --- 5. the record --------------------------------------------------------------------------

sha() { sha256sum "$1" | cut -d' ' -f1; }

record() {
  echo "# saw/results.txt -- written by scripts/check-saw.sh; do not edit."
  echo "#"
  echo "# SAW llvm_verify of the SPARK AES, SHA-256 and HMAC-SHA-256"
  echo "# implementations' bitcode, and of the AES spec layer's (lines"
  echo "# \"proved spec layer: ...\"), against NSA's Cryptol. Local only (GNAT"
  echo "# Pro LLVM), never run by CI: this record is the provenance of the"
  echo "# result. README \"SAW\"."
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
  echo "memory cap  $CAP_NOTE"
  echo "switches    ${SWITCHES[*]}"
  echo "spec layer  ${SPEC_SWITCHES[*]/#-gnatec=$SAW_DIR\//-gnatec=saw/}"
  echo "spec.adc    $(sha "$SPEC_ADC") saw/spec.adc: $(grep '^pragma' "$SPEC_ADC" | tr '\n' ' ' | sed 's/ $//')"
  for bc in "${BITCODE[@]}"; do
    echo "bitcode     $(sha "$bc") ${bc#"$OBJ_DIR"/}"
  done
  # The sources the front end read for the units (their ALIs' D lines),
  # each once: ours by sha256; the GNAT Pro runtime's by name and the ALI's
  # checksum.
  for ali in "${ALL_ALIS[@]}"; do
    grep '^D ' "$ali"
  done | awk '!seen[$2]++' | while read -r _ file _ cksum _; do
    src="$(find "$SPARK_DIR/src" "$SAW_DIR" -maxdepth 3 -name "$file" -print -quit)"
    if [ -n "$src" ]; then
      echo "source      $(sha "$src") ${src#"$SPARK_DIR"/}"
    else
      echo "runtime     $cksum $file"
    fi
  done
  # The runtime units compiled into the spec modules, by sha256.
  for u in "${RTS_UNITS[@]}"; do
    echo "runtime src $(sha "$RTS_SRC/$u") ${RTS_SRC#"$GNAT_LLVM_DIR"/}/$u (compiled: ${RTS_SWITCHES[*]})"
  done
  for f in "${CRYPTOL_FILES[@]}"; do
    echo "cryptol     $(sha "$ROOT_DIR/$f") $f"
  done
  for f in "${OUR_CRYPTOL[@]}"; do
    echo "cryptol     $(sha "$ROOT_DIR/$f") $f (ours: an instantiation)"
  done
  for p in "${PROVED[@]}"; do
    echo "proved      $p"
  done
  for n in "${NEGATIVE[@]}"; do
    echo "negative    $n"
  done
  local IFS=';'
  echo "wall-clock  ${T_PROOFS[*]}; ${T_TOTAL} s in all" | sed 's/;/; /g'
}

if [ "$PRINT" -eq 1 ]; then
  record
else
  record > "$RESULTS"
  echo ">> wrote ${RESULTS#"$ROOT_DIR"/}"
fi
echo ">> SAW: $N_PROVED proved ($N_SPEC of the spec layer, in ${#PROVED[@]} lines), ${#NEGATIVE[@]} negative controls failed as they must (${T_TOTAL} s)"
