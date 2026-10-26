#!/usr/bin/env bash
#
# test-bootstrap-detect.sh -- tests bootstrap-x86_64.sh's "present and
# matching the pin" detection, anywhere bash 3.2 or later runs.
#
# bootstrap-x86_64.sh itself runs only on x86_64 Linux, and its real test is
# the bootstrap workflow, which runs it on machines with nothing installed and
# then again with everything present. This tests the part that decides
# between the two: it sources the script's "tool detection" functions alone,
# and runs them against stub tools (shell scripts that print what each real
# tool's --version prints) on a made-up PATH, at the versions
# toolchain-pins.env pins and at others.
#
# Usage: scripts/test-bootstrap-detect.sh   (exit 0 when every case passes)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/bootstrap-x86_64.sh"
# shellcheck source=/dev/null  # KEY=VALUE pins
. "$HERE/toolchain-pins.env"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The detection functions, and nothing else of the script.
sed -n '/^# --- tool detection/,/^# --- end of tool detection/p' "$SCRIPT" > "$WORK/detect.sh"
grep -q '^find_tool()' "$WORK/detect.sh" || { echo "no tool detection block in $SCRIPT" >&2; exit 1; }
# The functions append to TOOL_STATES, which the script declares.
TOOL_STATES=()
# PATH holds the stubs' directories and SYS, the few system commands the
# functions and this test use, so no real tool (a z3, say) interferes.
SYS="$WORK/sys"
mkdir -p "$SYS"
for c in sed awk dirname basename mkdir chmod grep rm; do
  ln -s "$(command -v "$c")" "$SYS/$c"
done
PATH="$SYS"
# shellcheck source=/dev/null
. "$WORK/detect.sh"

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); echo "ok    $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL  $*"; }
# expect NAME WANT GOT
expect() { if [ "$2" = "$3" ]; then ok "$1"; else fail "$1: want '$2', got '$3'"; fi; }

# stub DIR NAME EXIT LINE... : DIR/NAME prints the lines and exits EXIT.
stub() {
  local dir="$1" name="$2" status="$3" line
  shift 3
  mkdir -p "$dir"
  {
    echo '#!/bin/sh'
    for line in "$@"; do printf "printf '%%s\\\\n' '%s'\n" "$line"; done
    echo "exit $status"
  } > "$dir/$name"
  chmod +x "$dir/$name"
}

# --- tool_version: each tool's --version, as the real one prints it ------------

S="$WORK/pinned/bin"
stub "$S" alr 0 "alr $ALR_VERSION"
stub "$S" gnatprove 0 "FSF $GNATPROVE_VERSION" "Why3 for gnatprove version 1.8.2+git"
stub "$S" gnatdoc 1 "GNATdoc $GNATDOC_VERSION (20260415)"
stub "$S" cryptol 0 "Cryptol $CRYPTOL_VERSION" "Git commit 0000000" "    branch release-$CRYPTOL_VERSION" "FFI enabled"
stub "$S" z3 0 "Z3 version 4.8.14 - 64 bit"
stub "$S" saw 0 "$SAW_VERSION (0000000 release-$SAW_VERSION)"
stub "$S" llvm-link 0 "LLVM (http://llvm.org/):" "  LLVM version $LLVM_LINK_VERSION" "  Optimized build."

expect "tool_version alr"       "$ALR_VERSION"       "$(tool_version alr "$S/alr")"
expect "tool_version gnatprove" "$GNATPROVE_VERSION" "$(tool_version gnatprove "$S/gnatprove")"
expect "tool_version gnatdoc (exits 1)" "$GNATDOC_VERSION" "$(tool_version gnatdoc "$S/gnatdoc")"
expect "tool_version cryptol"   "$CRYPTOL_VERSION"   "$(tool_version cryptol "$S/cryptol")"
expect "tool_version saw"       "$SAW_VERSION"       "$(tool_version saw "$S/saw")"
expect "tool_version llvm-link" "$LLVM_LINK_VERSION" "$(tool_version llvm-link "$S/llvm-link")"
stub "$WORK/v/bin" saw 0 "version $SAW_VERSION (0000000)"
expect "tool_version saw, 'version' first" "$SAW_VERSION" "$(tool_version saw "$WORK/v/bin/saw")"
stub "$WORK/odd/bin" alr 0 "something else"
expect "tool_version of an unrecognised output is empty" "" "$(tool_version alr "$WORK/odd/bin/alr")"

# --- tool_matches / find_tool ------------------------------------------------------

O="$WORK/other/bin"
stub "$O" alr 0 "alr 2.0.0"
stub "$O" gnatprove 0 "FSF 15.1.0"
stub "$O" llvm-link 0 "LLVM (http://llvm.org/):" "  LLVM version 18.1.3"
stub "$O" saw 0 "1.5 (0000000 release-1.5)"

for t in alr gnatprove gnatdoc cryptol saw llvm-link; do
  pin=""
  case "$t" in
    alr) pin="$ALR_VERSION" ;; gnatprove) pin="$GNATPROVE_VERSION" ;;
    gnatdoc) pin="$GNATDOC_VERSION" ;; cryptol) pin="$CRYPTOL_VERSION" ;;
    saw) pin="$SAW_VERSION" ;; llvm-link) pin="$LLVM_LINK_VERSION" ;;
  esac
  if tool_matches "$t" "$S/$t" "$pin" > /dev/null; then ok "$t at the pin matches"; else fail "$t at the pin does not match"; fi
done
for t in alr gnatprove saw llvm-link; do
  if tool_matches "$t" "$O/$t" "999" > /dev/null; then fail "$t at another version matches"; else ok "$t at another version does not match"; fi
done
if tool_matches alr "$WORK/nowhere/alr" "$ALR_VERSION" > /dev/null; then fail "a missing executable matches"; else ok "a missing executable does not match"; fi

# The first matching candidate wins; empty and mismatched ones are skipped.
out="$(find_tool alr "$ALR_VERSION" "" "$O/alr" "$S/alr"; echo "rc=$? FOUND=$FOUND")"
expect "find_tool skips empty and mismatched candidates" "rc=0 FOUND=$S/alr" "${out##*$'\n'}"
case "$out" in *"$O/alr: 2.0.0, not the pinned $ALR_VERSION"*) ok "find_tool says why a candidate is passed over" ;;
  *) fail "find_tool did not say why $O/alr was passed over: $out" ;; esac
out="$(find_tool alr "$ALR_VERSION" "$S/alr" "$O/alr"; echo "rc=$? FOUND=$FOUND")"
expect "find_tool takes the first match" "rc=0 FOUND=$S/alr" "${out##*$'\n'}"
out="$(find_tool alr "$ALR_VERSION" "" "$O/alr" "$WORK/nowhere/alr" > /dev/null; echo "rc=$? FOUND=$FOUND")"
expect "find_tool with no match fails, FOUND empty" "rc=1 FOUND=" "$out"

# The way the script calls it: PATH's, then an earlier run's directory.
PATH="$O:$SYS"
out="$(find_tool alr "$ALR_VERSION" "$(on_path alr)" "$S/alr" > /dev/null; echo "$FOUND")"
expect "PATH's alr at another version: the earlier run's is used" "$S/alr" "$out"
PATH="$S:$SYS"
out="$(find_tool alr "$ALR_VERSION" "$(on_path alr)" "$WORK/nowhere/alr" > /dev/null; echo "$FOUND")"
expect "PATH's alr at the pin is used" "$S/alr" "$out"
PATH="$SYS"

# --- cryptol: FFI support and z3 ---------------------------------------------------

C="$WORK/cryptol-noffi/bin"
stub "$C" cryptol 0 "Cryptol $CRYPTOL_VERSION" "Git commit 0000000"
stub "$C" z3 0 "Z3 version 4.8.14 - 64 bit"
if tool_matches cryptol "$C/cryptol" "$CRYPTOL_VERSION" > /dev/null; then fail "cryptol without FFI matches"; else ok "cryptol without FFI does not match"; fi

C="$WORK/cryptol-noz3/bin"
stub "$C" cryptol 0 "Cryptol $CRYPTOL_VERSION" "FFI enabled"
if tool_matches cryptol "$C/cryptol" "$CRYPTOL_VERSION" > /dev/null; then fail "cryptol with no z3 matches"; else ok "cryptol with no z3 beside it or on PATH does not match"; fi
Z="$WORK/z3/bin"
stub "$Z" z3 0 "Z3 version 4.8.14 - 64 bit"
PATH="$Z:$SYS"
if tool_matches cryptol "$C/cryptol" "$CRYPTOL_VERSION" > /dev/null; then ok "cryptol with z3 on PATH matches"; else fail "cryptol with z3 on PATH does not match"; fi
PATH="$SYS"

# --- llvm-link -----------------------------------------------------------------------

# LLVM_LINK_DIR's first, then PATH's (in a bin/ directory only).
G="$WORK/given"
stub "$G/bin" llvm-link 0 "LLVM (http://llvm.org/):" "  LLVM version $LLVM_LINK_VERSION"
PATH="$S:$SYS"
out="$(find_tool llvm-link "$LLVM_LINK_VERSION" "$G/bin/llvm-link" "$(llvm_link_on_path)" > /dev/null; echo "$FOUND")"
expect "LLVM_LINK_DIR's llvm-link comes before PATH's" "$G/bin/llvm-link" "$out"
expect "LLVM_LINK_DIR derived from it" "$G" "${out%/bin/llvm-link}"
out="$(find_tool llvm-link "$LLVM_LINK_VERSION" "" "$(llvm_link_on_path)" > /dev/null; echo "$FOUND")"
expect "with no LLVM_LINK_DIR, PATH's llvm-link at the pin" "$S/llvm-link" "$out"
out="$(find_tool llvm-link "$LLVM_LINK_VERSION" "$O/llvm-link" "$(llvm_link_on_path)" > /dev/null; echo "$FOUND")"
expect "LLVM_LINK_DIR's at another version: PATH's" "$S/llvm-link" "$out"
NB="$WORK/notbin"
stub "$NB" llvm-link 0 "LLVM (http://llvm.org/):" "  LLVM version $LLVM_LINK_VERSION"
PATH="$NB:$SYS"
expect "PATH's llvm-link outside a bin/ directory is not used" "" "$(llvm_link_on_path)"
PATH="$SYS"
expect "no llvm-link on PATH" "" "$(llvm_link_on_path)"

# --- toolchain_selected (`alr toolchain`'s listing) ---------------------------------

listing="CRATE        VERSION STATUS    NOTES
gprbuild     25.0.1  Available
gprbuild     $GPRBUILD_VERSION  Default
gnat_native  15.2.4  Available
gnat_native  $GNAT_NATIVE_VERSION  Default"
if toolchain_selected "$listing" gnat_native "$GNAT_NATIVE_VERSION"; then ok "gnat_native selected"; else fail "gnat_native not seen as selected"; fi
if toolchain_selected "$listing" gprbuild "$GPRBUILD_VERSION"; then ok "gprbuild selected"; else fail "gprbuild not seen as selected"; fi
if toolchain_selected "$listing" gnat_native 15.2.4; then fail "an Available gnat_native seen as selected"; else ok "an Available toolchain is not selected"; fi
if toolchain_selected "" gnat_native "$GNAT_NATIVE_VERSION"; then fail "an empty listing has a selection"; else ok "an empty listing selects nothing"; fi

# --- add_path / use_tool ---------------------------------------------------------------

BASE_PATH="$SYS"
TOOL_PATH=""
PATH="$BASE_PATH"
add_path "$WORK/a"
add_path "$WORK/b"
add_path "$WORK/a"
expect "add_path keeps order and adds once" "$WORK/a:$WORK/b" "$TOOL_PATH"
expect "add_path puts TOOL_PATH ahead of the base PATH" "$WORK/a:$WORK/b:$SYS" "$PATH"

BASE_PATH="$S:$SYS"
TOOL_PATH=""
PATH="$BASE_PATH"
use_tool "$S/saw"
expect "use_tool adds nothing for a tool PATH already finds" "" "$TOOL_PATH"
use_tool "$G/bin/llvm-link"
expect "use_tool adds the directory of one PATH does not find" "$G/bin" "$TOOL_PATH"

# --- tool_present / tool_fetched ---------------------------------------------------------

TOOL_STATES=()
out="$(tool_present cryptol "$CRYPTOL_VERSION" "$S/cryptol")"
expect "tool_present says so" ">> cryptol $CRYPTOL_VERSION: present and matching the pin ($S/cryptol)" "$out"
out="$(tool_fetched saw "$SAW_VERSION" "$WORK/saw/bin/saw")"
expect "tool_fetched says so" ">> saw $SAW_VERSION: fetched ($WORK/saw/bin/saw)" "$out"
tool_present cryptol "$CRYPTOL_VERSION" "$S/cryptol" > /dev/null
tool_fetched saw "$SAW_VERSION" "$WORK/saw/bin/saw" > /dev/null
expect "TOOL_STATES records both" 2 "${#TOOL_STATES[@]}"
case "${TOOL_STATES[0]}" in "cryptol "*"$CRYPTOL_VERSION"*"present and matching the pin") ok "TOOL_STATES row for a present tool" ;;
  *) fail "TOOL_STATES row: ${TOOL_STATES[0]}" ;; esac

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
