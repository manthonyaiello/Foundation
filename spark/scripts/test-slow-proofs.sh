#!/usr/bin/env bash
#
# test-slow-proofs.sh -- test the slow-proof manifest and the gate's skip
# (README "Slow proofs"), with no prover and no toolchain.
#
# It works on a scratch copy of the crate (src/, scripts/, the GPR) in its own
# git repository, marks one real unit slow, and checks that
#   * the manifest check passes on a current entry and fails when the unit is
#     marked but not listed, listed but not marked or not existing, or its
#     fingerprint was edited by hand;
#   * the check names the input that changed: a file in the unit's closure,
#     the GPR's proof switches, alire.toml, a tool version;
#   * `refresh` keeps a recorded proof when the only change is a new input
#     unchanged since the recorded commit (alire.toml joining the
#     fingerprint, #67), and refuses otherwise;
#   * check-proof.sh, gating a synthetic gnatprove.out (CHECK_PROOF_OUT),
#     exempts the listed unit, and ONLY it, from the "tracked unit absent"
#     and "entity skipped" rules: an unlisted unit still fails both.
#
# CI runs it in the trust job. Exit 0 when every case behaves.
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SLOW_UNIT="${SLOW_TEST_UNIT:-foundation_spark-aes-spec-sbox}"     # marked slow
OTHER_UNIT="${OTHER_TEST_UNIT:-foundation_spark-aes-spec-types}"  # in its closure, not slow

T="$(mktemp -d "${TMPDIR:-/tmp}/slow-proofs-test.XXXXXX")"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/crate"
cp -R "$ROOT/src" "$ROOT/scripts" "$ROOT/foundation_spark.gpr" "$ROOT/alire.toml" "$T/crate/"
C="$T/crate"
# Start from no slow unit: the tree's own markers (and manifest) go.
grep -rlE '^[[:space:]]*--[[:space:]]+Slow proof:' "$C/src" 2>/dev/null | while IFS= read -r f; do
  grep -vE '^[[:space:]]*--[[:space:]]+Slow proof:' "$f" > "$f.unmarked"
  mv "$f.unmarked" "$f"
done
git -C "$C" init -q
git -C "$C" add -A src
: > "$C/scripts/proof-slow.txt"

cat > "$T/versions" <<'EOF'
FSF 16.1.0
Why3 for gnatprove version 1.8.2+git
/x/bin/alt-ergo: Alt-Ergo version 2.6.1
/x/bin/cvc5: This is cvc5 version 1.3.2
/x/bin/z3: Z3 version 4.15.4 - 64 bit
EOF
export SLOW_PROOFS_TOOL_VERSIONS="$T/versions"

SLOW_FILE="$(git -C "$C" ls-files -- src | grep -E "/${SLOW_UNIT}\.ad[sb]\$" | head -n 1)"
OTHER_FILE="$(git -C "$C" ls-files -- src | grep -E "/${OTHER_UNIT}\.ad[sb]\$" | head -n 1)"
[ -n "$SLOW_FILE" ] && [ -n "$OTHER_FILE" ] || { echo "!! test units not found" >&2; exit 2; }

FAILS=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; FAILS=$((FAILS + 1)); }

# expect NAME STATUS PATTERN -- CMD...: CMD exits STATUS and its output
# matches PATTERN (an extended regex; empty for none).
expect() {
  local name="$1" want="$2" pat="$3"; shift 4
  local out got
  out="$("$@" 2>&1)"; got=$?
  if [ "$got" -ne "$want" ]; then
    fail "$name (exit $got, wanted $want)"; printf '%s\n' "$out" | sed 's/^/       /'
  elif [ -n "$pat" ] && ! printf '%s\n' "$out" | grep -qE "$pat"; then
    fail "$name (no /$pat/ in output)"; printf '%s\n' "$out" | sed 's/^/       /'
  else
    pass "$name"
  fi
}

SP=(python3 "$C/scripts/slow_proofs.py")

expect "empty manifest: check passes" 0 "" -- "${SP[@]}" check

printf '\n--  Slow proof: proved on demand (scripts/proof-slow.txt).\n' >> "$C/$SLOW_FILE"
expect "marked but not listed: fails" 2 "unit $SLOW_UNIT carries the .* no entry for it" -- "${SP[@]}" check

expect "record the entry" 0 "recorded" -- "${SP[@]}" record "$SLOW_FILE" \
  --commit 0123456789abcdef0123456789abcdef01234567 --date 2026-01-01 \
  --checks 7/7 --reason "test"
expect "current entry: check passes and prints the skip" 0 \
  "slow unit skipped: $SLOW_FILE .*proved at 0123456789" -- "${SP[@]}" check
expect "the closure reaches a withed unit" 0 "$OTHER_FILE" -- "${SP[@]}" inputs "$SLOW_FILE" -v

cp "$C/scripts/proof-slow.txt" "$T/manifest.good"

# --- the change detector ------------------------------------------------------------

cp "$C/$OTHER_FILE" "$T/other.bak"
printf '\n--  a comment\n' >> "$C/$OTHER_FILE"
expect "a withed unit changed: stale, named" 1 "$OTHER_FILE \(changed\)" -- "${SP[@]}" check
cp "$T/other.bak" "$C/$OTHER_FILE"

cp "$C/foundation_spark.gpr" "$T/gpr.bak"
sed -i.sed 's/use Level_2 & ("--counterexamples=on");/use Level_3 \& ("--counterexamples=on");/' "$C/foundation_spark.gpr"
expect "the default proof switches changed: stale, named" 1 'gpr: Proof_Switches \("Ada"\) \(changed\)' -- "${SP[@]}" check
cp "$T/gpr.bak" "$C/foundation_spark.gpr"

cp "$C/alire.toml" "$T/alire.bak"
printf '\n# a comment\n' >> "$C/alire.toml"
expect "alire.toml changed: stale, named" 1 "alire.toml \(changed\)" -- "${SP[@]}" check
cp "$T/alire.bak" "$C/alire.toml"

cp "$T/versions" "$T/versions.bak"
sed -i.sed 's/4.15.4/4.15.5/' "$T/versions"
expect "a prover version changed: stale, named" 1 "tool: z3 \(changed\)" -- "${SP[@]}" check
cp "$T/versions.bak" "$T/versions"

expect "restored: check passes" 0 "" -- "${SP[@]}" check

sed -i.sed -E 's/^(  fingerprint +sha256:)./\10/' "$C/scripts/proof-slow.txt"
expect "fingerprint edited by hand: fails" 2 "not the hash of its recorded inputs" -- "${SP[@]}" check
cp "$T/manifest.good" "$C/scripts/proof-slow.txt"

sed -i.sed "s#^unit .*#unit src/no-such-unit.adb#" "$C/scripts/proof-slow.txt"
expect "a listed unit that does not exist: fails" 2 "not a tracked file" -- "${SP[@]}" check
cp "$T/manifest.good" "$C/scripts/proof-slow.txt"

cp "$C/$SLOW_FILE" "$T/slow.bak"
grep -v 'Slow proof:' "$T/slow.bak" > "$C/$SLOW_FILE"
expect "listed but not marked: fails" 2 "but no file of unit $SLOW_UNIT carries" -- "${SP[@]}" check
cp "$T/slow.bak" "$C/$SLOW_FILE"

# --- refresh: an input-only change ------------------------------------------------

# refresh compares a new input with its content at the recorded commit, so
# the entry needs a real one.
git -C "$C" add -A src alire.toml
git -C "$C" -c user.name=test -c user.email=test@invalid -c commit.gpgsign=false \
  commit -qm "the tree proved"
PROVED="$(git -C "$C" rev-parse HEAD)"
expect "record at a real commit" 0 "recorded" -- "${SP[@]}" record "$SLOW_FILE" \
  --commit "$PROVED" --date 2026-01-01 --checks 7/7

# drop_input NAME: make the entry one recorded before NAME was an input.
drop_input() {
  python3 -c '
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1] + "/scripts")
import slow_proofs as sp
root, rel, name = sys.argv[1:4]
path = sp.manifest_path(root)
e = dict(sp.read_manifest(path))[rel]
del e["inputs"][name]
e["fingerprint"] = sp.fingerprint(e["inputs"])
sp.write_entry(path, rel, e)
' "$C" "$SLOW_FILE" "$1"
}

drop_input alire.toml
expect "an entry from before alire.toml was an input: stale, refresh offered" 1 \
  "slow_proofs.py refresh $SLOW_FILE" -- "${SP[@]}" check
expect "refresh: the new input is unchanged since the commit: refreshed" 0 \
  "refreshed .* new inputs, unchanged since: alire.toml" -- "${SP[@]}" refresh "$SLOW_FILE"
expect "refreshed: check passes, the proof's commit kept" 0 "proved at $PROVED" -- "${SP[@]}" check

drop_input alire.toml
printf '\n# a comment\n' >> "$C/alire.toml"
expect "refresh: the new input changed since the commit: refused" 1 \
  "alire.toml \(new, and changed since the recorded commit" -- "${SP[@]}" refresh "$SLOW_FILE"
cp "$T/alire.bak" "$C/alire.toml"

printf '\n--  a comment\n' >> "$C/$OTHER_FILE"
expect "refresh: a recorded input changed: refused" 1 "$OTHER_FILE \(changed\)" -- \
  "${SP[@]}" refresh "$SLOW_FILE"
cp "$T/other.bak" "$C/$OTHER_FILE"

drop_input "tool: z3"
expect "refresh: a new input that is not a file: refused" 1 "tool: z3 \(new, and not a file" -- \
  "${SP[@]}" refresh "$SLOW_FILE"
cp "$T/manifest.good" "$C/scripts/proof-slow.txt"

# --- the gate's exemptions (check-proof.sh on a synthetic gnatprove.out) -----------

units() { git -C "$C" ls-files -- src | sed -E 's#^.*/##; s/\.ad[sb]$//' | sort -u; }
gp_out() {  # gp_out OUT [UNIT-to-omit] [UNIT-with-a-skipped-entity]
  local u
  : > "$1"
  while IFS= read -r u; do
    [ "$u" = "${2:-}" ] && continue
    echo "in unit $u, 1 subprograms and packages out of 1 analyzed" >> "$1"
    if [ "$u" = "${3:-}" ]; then
      echo "  Foundation_Spark.Test_Entity at $u.ads:1 skipped; SPARK_Mode => Off" >> "$1"
    fi
  done <<< "$(units)"
  echo "Total            1 .            .            .            .            ." >> "$1"
}

gp_out "$T/out.slow-absent" "$SLOW_UNIT"
expect "gate: the listed slow unit absent from the report: passes" 0 "PROOF OK" -- \
  env CHECK_PROOF_OUT="$T/out.slow-absent" "$C/scripts/check-proof.sh"

gp_out "$T/out.other-absent" "$OTHER_UNIT"
expect "gate: an unlisted unit absent from the report: fails" 1 \
  "\(unit $OTHER_UNIT\)" -- \
  env CHECK_PROOF_OUT="$T/out.other-absent" "$C/scripts/check-proof.sh"

gp_out "$T/out.slow-skipped" "" "$SLOW_UNIT"
expect "gate: an entity of the listed slow unit skipped: passes" 0 "PROOF OK" -- \
  env CHECK_PROOF_OUT="$T/out.slow-skipped" "$C/scripts/check-proof.sh"

gp_out "$T/out.other-skipped" "" "$OTHER_UNIT"
expect "gate: an entity of an unlisted unit skipped: fails" 1 \
  "did not analyze" -- \
  env CHECK_PROOF_OUT="$T/out.other-skipped" "$C/scripts/check-proof.sh"

: > "$C/scripts/proof-slow.txt"
grep -v 'Slow proof:' "$T/slow.bak" > "$C/$SLOW_FILE"
expect "gate: with nothing listed, the same unit absent fails" 1 "PROOF INCOMPLETE" -- \
  env CHECK_PROOF_OUT="$T/out.slow-absent" "$C/scripts/check-proof.sh"

echo
if [ "$FAILS" -ne 0 ]; then
  echo "!! $FAILS case(s) failed"
  exit 1
fi
echo ">> slow-proof tests OK"
