#!/usr/bin/env bash
#
# run.sh -- the controlled experiments of #69 (why SAW costs so much more
# on the spec layer than on the implementation). Write-up:
# .claude/campaign/measurements/2026-10-22-saw-cost.md.
#
# Each experiment is a SAW script in this directory, e_<name>.saw, run
# against the bitcode check-saw.sh builds (saw/obj/), in a scratch copy
# of saw/'s scripts, so that one thing can be changed at a time without
# touching a recorded script (saw/results.txt stays current):
#
# saw/experiments/ is outside the record: no recorded run loads it,
# board.py does not count it among SAW's inputs, and check-saw.sh's
# assumed-spec guard skips it, so these scripts may use `admit` (here, to
# time symbolic execution without a solver). A recorded script may not.
#
#   run.sh [-v VARIANT] [-p] EXPERIMENT [OUT_DIR]
#
#   -v VARIANT  apply variants/<VARIANT>.sed to the scratch copy of the
#               recorded scripts (e.g. a smaller secondary-stack chunk);
#   -p          also build the probe units probes/*.ads into
#               OUT_DIR/obj/probes.bc (with the secondary stack linked in),
#               for the experiments that compare two ways of writing a
#               function;
#   EXPERIMENT  e_<EXPERIMENT>.saw;
#   OUT_DIR     default /tmp/saw-spec-layer-cost/<EXPERIMENT>[-VARIANT].
#
# Needs: saw/obj built by `scripts/check-saw.sh --print` (any SAW_LAYERS
# that includes spec), the env check-saw.sh needs (GNAT_LLVM_DIR,
# LLVM_LINK_DIR, saw and z3 on PATH). Every saw run is capped at
# SAW_MEMORY_MAX (default 6G) in its own systemd scope, and timed with
# /usr/bin/time -v (wall-clock, peak RSS): OUT_DIR/time.txt. SAW's own
# per-proof times are in OUT_DIR/saw.log ("Time:" lines), each after an
# "== <label>" line the script prints.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAW_DIR="$(cd "$HERE/../.." && pwd)"
SPARK_DIR="$(cd "$SAW_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SPARK_DIR/.." && pwd)"

VARIANT=""
PROBES=0
while [ $# -gt 0 ]; do
  case "$1" in
    -v) VARIANT="$2"; shift 2 ;;
    -p) PROBES=1; shift ;;
    *) break ;;
  esac
done
EXP="${1:?usage: run.sh [-v VARIANT] [-p] EXPERIMENT [OUT_DIR]}"
OUT="${2:-/tmp/saw-spec-layer-cost/$EXP${VARIANT:+-$VARIANT}}"

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
# The recorded scripts and our Cryptol, copied; the bitcode, linked.
cp "$SAW_DIR"/*.saw "$SAW_DIR"/*.cry "$OUT/work/"
cp "$HERE"/e_*.saw "$OUT/work/"
ln -s "$SAW_DIR/obj" "$OUT/work/obj"
if [ -n "$VARIANT" ]; then
  for f in "$OUT"/work/*.saw; do sed -i -f "$HERE/variants/$VARIANT.sed" "$f"; done
  # What the variant changed, for the record.
  (cd "$OUT/work" && for f in *.saw; do diff -u "$SAW_DIR/$f" "$f" 2>/dev/null || true; done) > "$OUT/variant.diff"
fi

if [ "$PROBES" -eq 1 ]; then
  mkdir -p "$OUT/obj"
  INCLUDES=()
  while IFS= read -r d; do INCLUDES+=("-I$d"); done < <(find "$SPARK_DIR/src" -type d | sort)
  probe_bc=()
  for u in "$HERE"/probes/*.ads; do
    (cd "$OUT/obj" && "$GNAT_LLVM_DIR/bin/llvm-gcc" -c -gnat2022 -gnatp -gnatVn -O0 -emit-llvm -fno-inline \
       "-gnatec=$SAW_DIR/spec.adc" "${INCLUDES[@]}" "-I$HERE/probes" "$u")
    probe_bc+=("$OUT/obj/$(basename "${u%.ads}").bc")
  done
  "$LLVM_LINK_DIR/bin/llvm-link" "${probe_bc[@]}" "$SAW_DIR/obj/spec/s-secsta.bc" "$SAW_DIR/obj/spec/s-soflin.bc" \
    "$SAW_DIR/obj/spec/saw_soft_links.bc" -o "$OUT/obj/probes.bc"
  ln -s "$OUT/obj" "$OUT/work/probes_obj"
fi

export CRYPTOLPATH="$ROOT_DIR"
cd "$OUT/work"
status=0
systemd-run --user --scope -q -p "MemoryMax=${SAW_MEMORY_MAX:-6G}" -p MemorySwapMax=0 \
  /usr/bin/time -v -o "$OUT/time.txt" saw "e_$EXP.saw" > "$OUT/saw.log" 2>&1 || status=$?
# The labels and SAW's times, in order; then wall-clock and peak RSS.
awk '/^== / { label = substr($0, 4) } /^Time: / { printf "%-70s %s\n", label, $2 } /^RESULT|^Proof failed|error|Error|failed/ { print "   " $0 }' "$OUT/saw.log" > "$OUT/summary.txt"
grep -E 'Elapsed|Maximum resident' "$OUT/time.txt" >> "$OUT/summary.txt" || true
echo "exit $status" >> "$OUT/summary.txt"
cat "$OUT/summary.txt"
exit "$status"
