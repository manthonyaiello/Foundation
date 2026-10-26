#!/usr/bin/env bash
#
# run.sh -- the unfold-vs-chain measurements: the spec layer's linear recursions proved
# unfolded against the per-index lemma chains they replaced. Each
# experiment is a SAW script here, e_<name>.saw, run against the bitcode
# check-saw.sh builds (saw/obj/), in a scratch copy of saw/'s scripts.
# saw/experiments/ is outside the record (README "SAW"; the
# spec-layer-cost experiments' run.sh, which this follows, says how).
#
#   run.sh EXPERIMENT [OUT_DIR]
#
#   EXPERIMENT  e_<EXPERIMENT>.saw;
#   OUT_DIR     default /tmp/saw-unfold-vs-chain/<EXPERIMENT>.
#
# Needs saw/obj built by `scripts/check-saw.sh --print`, and the env
# check-saw.sh needs (saw and z3 on PATH). The saw run is capped at
# SAW_MEMORY_MAX (default 10G, no swap) in its own systemd scope, and
# timed with /usr/bin/time -v (wall-clock, peak RSS): OUT_DIR/time.txt.
# OUT_DIR/summary.txt has each "== <label>" with the "Time:" lines SAW
# printed under it.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAW_DIR="$(cd "$HERE/../.." && pwd)"
SPARK_DIR="$(cd "$SAW_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SPARK_DIR/.." && pwd)"

EXP="${1:?usage: run.sh EXPERIMENT [OUT_DIR]}"
OUT="${2:-/tmp/saw-unfold-vs-chain/$EXP}"

[ -f "$HERE/e_$EXP.saw" ] || { echo "no $HERE/e_$EXP.saw" >&2; exit 2; }
[ -f "$SAW_DIR/obj/spec/sha256_spec.bc" ] || { echo "no saw/obj/spec: run scripts/check-saw.sh --print first" >&2; exit 2; }

rm -rf "$OUT"
mkdir -p "$OUT/s/work"
# The scripts import NSA's Cryptol as ../../algorithms/...: the copy sits
# two levels below OUT, where the repository's algorithms/ and shared/
# are linked.
ln -s "$ROOT_DIR/algorithms" "$OUT/algorithms"
ln -s "$ROOT_DIR/shared" "$OUT/shared"
ln -s "s/work" "$OUT/work"
cp "$SAW_DIR"/*.saw "$SAW_DIR"/*.cry "$OUT/work/"
cp "$HERE/e_$EXP.saw" "$OUT/work/"
ln -s "$SAW_DIR/obj" "$OUT/work/obj"

export CRYPTOLPATH="$ROOT_DIR"
cd "$OUT/work"
status=0
systemd-run --user --scope -q -p "MemoryMax=${SAW_MEMORY_MAX:-10G}" -p MemorySwapMax=0 \
  /usr/bin/time -v -o "$OUT/time.txt" saw "e_$EXP.saw" > "$OUT/saw.log" 2>&1 || status=$?
awk '/^== / { label = substr($0, 4); print "== " label } /^Time: / { printf "   %s\n", $2 } /^RESULT/ { print "   " $0 } /^Proof failed|[Ee]rror|failed/ { print "   " $0 }' "$OUT/saw.log" > "$OUT/summary.txt"
grep -E 'Elapsed|Maximum resident' "$OUT/time.txt" >> "$OUT/summary.txt" || true
echo "exit $status" >> "$OUT/summary.txt"
cat "$OUT/summary.txt"
exit "$status"
