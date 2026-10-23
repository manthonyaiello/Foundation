#!/usr/bin/env bash
#
# perf-aes.sh -- binary size and performance of the SPARK AES against NSA's
# Rust AES (issue #51, README "Performance"), on whatever machine it runs on:
# Linux or macOS, x86_64 or arm64.
#
# 1. Builds the SPARK harness perf/perf.gpr (perf_bench, timing through
#    Perf_AES's non-inlined wrappers) in five variants, all with
#    Assertion_Policy (Ignore) (perf/perf.adc: no contract, assertion or
#    ghost code), -gnatn, -ffunction-sections -fdata-sections, -flto at
#    compile and link time, and dead-section removal at link time:
#      spark-O2          -O2 -gnatp   the constant-time S-box (src/)
#      spark-O3          -O3 -gnatp   the same
#      spark-O3-checks   -O3          the same, run-time checks kept
#      spark-table-O2    -O2 -gnatp   the table S-box: src/ at PERF_TABLE_REV
#      spark-table-O3    -O3 -gnatp   the same
# 2. Builds the Rust harness perf/rust (NSA's Cipher and KeyExpansion
#    crates behind non-inlined wrappers) with cargo, three ways:
#      rust-O2           profile perf-o2: opt-level 2, lto "fat", 1 codegen unit
#      rust-O3           profile perf-o3: opt-level 3, lto "fat", 1 codegen unit
#      rust-release      plain --release: opt-level 3, no LTO, 16 codegen units
# 3. Unless PERF_SKIP_BENCH=1, runs every executable once, one after the
#    other (the FIPS-197 Appendix C known answers, then the timings), and
#    records the machine's load before and after.
# 4. Prints the known-answer check, the size table and the time table
#    (scripts/perf-report.py), and writes them to obj/perf/perf-report.md.
#
# Usage (from spark/, with the crate's toolchain and cargo on PATH):
#   source "$HOME/.cargo/env"
#   alr -n exec -- scripts/perf-aes.sh
# Env:
#   GPRBUILD         gprbuild (default: gprbuild)
#   CARGO            cargo (default: cargo)
#   PERF_TABLE_REV   the commit whose src/ has the table S-box (default
#                    b967ebb, the last before #84); "none" skips those builds
#   PERF_QUICK       1 for a smoke test (few, small batches): not a measurement
#   PERF_SKIP_BENCH  1 to build and measure sizes only
#
# Exit status: 1 if a build fails or a known answer is wrong, 0 otherwise.
# Timings are reported, never enforced: CI does not run this script.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GPRBUILD="${GPRBUILD:-gprbuild}"
CARGO="${CARGO:-cargo}"
TABLE_REV="${PERF_TABLE_REV:-b967ebb}"
OUT="obj/perf"
REPORT="$OUT/perf-report.md"
JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"

case "$(uname -s)" in
  Darwin) OS=darwin ;;
  Linux)  OS=linux ;;
  *) echo "perf-aes.sh: unsupported system $(uname -s)" >&2; exit 2 ;;
esac

mkdir -p "$OUT"
: > "$OUT/manifest.txt"
RUN_ARG=""
if [ "${PERF_QUICK:-0}" = 1 ]; then RUN_ARG=quick; fi

load() {
  uptime | sed 's/.*load average[s]*: *//'
}

scheduler() {
  if command -v spark-scheduler >/dev/null 2>&1; then
    spark-scheduler status 2>/dev/null | grep -E '^(pool|flight)' | tr -s ' ' | paste -sd ';' -
  else
    echo "no spark-scheduler"
  fi
}

cpu() {
  if [ "$OS" = darwin ]; then
    sysctl -n machdep.cpu.brand_string
  else
    grep -m1 -E '^(model name|Model)' /proc/cpuinfo | sed 's/.*: //' || uname -m
  fi
}

# The table S-box: src/ as it was at TABLE_REV, extracted outside the tree.
TABLE_SRC=""
if [ "$TABLE_REV" != none ]; then
  rm -rf "$OUT/src-table"
  mkdir -p "$OUT/src-table"
  # The pathspec is relative to the current directory: run from the top.
  git -C "$(git rev-parse --show-toplevel)" archive "$TABLE_REV:spark" src \
    | tar -x -C "$OUT/src-table"
  TABLE_SRC="$ROOT/$OUT/src-table/src"
fi

spark_build() { # name opt checks src
  echo ">> building $1" >&2
  "$GPRBUILD" -P perf/perf.gpr -q -j"$JOBS" \
    -XPERF_OS="$OS" -XPERF_OPT="$2" -XPERF_CHECKS="$3" -XPERF_LTO=on \
    -XPERF_SRC="$4" -XPERF_NAME="$1"
  echo "$1|spark|$OUT/$1/perf_bench|$OUT/$1.bench.txt" >> "$OUT/manifest.txt"
}

rust_build() { # name profile
  echo ">> building $1" >&2
  # cargo rustc: the extra arguments reach the final crate's link only. On
  # macOS they ask for the linker map that perf-report.py reads for symbol
  # sizes (as perf.gpr does for SPARK); they change no code generation.
  local link=()
  if [ "$OS" = darwin ]; then
    link=(-- -C "link-arg=-Wl,-map,$ROOT/$OUT/rust/$2/aes_perf.map")
  fi
  "$CARGO" rustc --quiet --locked --manifest-path perf/rust/Cargo.toml \
    --target-dir "$OUT/rust" --profile "$2" --bin aes_perf "${link[@]+"${link[@]}"}"
  echo "$1|rust|$OUT/rust/$2/aes_perf|$OUT/$1.bench.txt" >> "$OUT/manifest.txt"
}

spark_build spark-O2 O2 off "$ROOT/src"
spark_build spark-O3 O3 off "$ROOT/src"
spark_build spark-O3-checks O3 on "$ROOT/src"
if [ -n "$TABLE_SRC" ]; then
  spark_build spark-table-O2 O2 off "$TABLE_SRC"
  spark_build spark-table-O3 O3 off "$TABLE_SRC"
fi
rust_build rust-O2 perf-o2
rust_build rust-O3 perf-o3
rust_build rust-release release

{
  echo "# perf-aes.sh on $(uname -s) $(uname -m), $(date -u +%Y-%m-%dT%H:%M:%SZ), commit $(git rev-parse --short HEAD)$(git diff --quiet HEAD -- . || echo ' (dirty)')"
  echo
  echo "* CPU: $(cpu), $JOBS logical CPUs"
  echo "* GNAT: $(gcc --version | head -1); gprbuild: $("$GPRBUILD" --version | head -1)"
  echo "* Rust: $(rustc --version), host $(rustc -vV | sed -n 's/^host: //p')"
  echo "* table S-box sources: ${TABLE_REV}"
  if [ -n "$RUN_ARG" ]; then
    echo "* **PERF_QUICK=1: a smoke test, not a measurement**"
  fi
} > "$REPORT"

if [ "${PERF_SKIP_BENCH:-0}" != 1 ]; then
  echo "* load before (1, 5, 15 min): $(load); scheduler: $(scheduler)" >> "$REPORT"
  while IFS='|' read -r name _side binary result; do
    echo ">> running $name" >&2
    # shellcheck disable=SC2086  # RUN_ARG is empty or one word
    "$binary" $RUN_ARG > "$result"
  done < "$OUT/manifest.txt"
  echo "* load after (1, 5, 15 min): $(load); scheduler: $(scheduler)" >> "$REPORT"
else
  rm -f "$OUT"/*.bench.txt
fi
echo >> "$REPORT"

status=0
python3 -I scripts/perf-report.py "$OUT" >> "$REPORT" || status=1
cat "$REPORT"
echo ">> wrote $REPORT" >&2
exit "$status"
