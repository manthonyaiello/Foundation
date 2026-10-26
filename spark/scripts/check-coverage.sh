#!/usr/bin/env bash
#
# check-coverage.sh -- GNATcoverage of the executable SPARK under the
# Cryptol-driven FFI properties: statement, decision and MC/DC
# (gnatcov's stmt+mcdc, which includes decision)
# coverage of the units in coverage/units.txt (the executable
# implementations and the non-ghost FFI export units), from every property
# of cryptol/properties.txt.
#
# 1. Installs gnatcov's runtime (gnatcov setup) in obj/cov/rts, once per
#    gnatcov version.
# 2. Instruments the FFI library's coverage build (foundation_spark_ffi.gpr
#    with FOUNDATION_SPARK_FFI_BUILD=coverage: its own object and library
#    directories under obj/cov/, plus the trace dump unit in coverage/) with
#    `gnatcov instrument --dump-trigger=manual`, and builds it. The proof
#    project, its switches and the FFI check's own build are not touched.
# 3. Runs scripts/check-ffi.sh against the instrumented library (FFI_LIB),
#    which checks every property as it always does. Cryptol has no Ada main
#    for gnatcov to put a dump in; the library's coverage unit registers the
#    dump with atexit when Cryptol loads it, so each `cryptol -b` (one per
#    property) writes its own source trace into obj/cov/traces/ when it
#    exits. A run that wrote no trace fails this script.
# 4. Consolidates the traces with `gnatcov coverage` into obj/cov/report/:
#    report.txt (the violations, unit by unit), xcov/ (the annotated
#    sources: one .xcov per source, each line marked + covered, - not,
#    ! partly, . no code), xml/ (the same, for tools) and summary.txt (the
#    per-unit table, and each violation with its explanation from
#    coverage/explained.txt, from scripts/coverage-summary.py).
#
# Usage (from anywhere; needs the Alire workspace, i.e. `alr -n build` once):
#   scripts/check-coverage.sh                 every property
#   scripts/check-coverage.sh PROPERTY ...    only these (a partial report)
#
# Env:
#   GNATCOV     the gnatcov binary (default: gnatcov). Its version must be
#               GNATCOV_VERSION of scripts/toolchain-pins.env.
#   CRYPTOL, FFI_JOBS, ALR: as for check-ffi.sh.
#
# Exit status: 0 when every property passed, every run wrote a trace and
# every violation (statement, decision or MC/DC obligation not covered) is
# explained in coverage/explained.txt; 1 when one of those fails; 2 on a
# usage or setup error. A partial run (PROPERTY ...) leaves violations that
# the whole run would cover, so read its verdict accordingly.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ALR="${ALR:-alr}"
GNATCOV="${GNATCOV:-gnatcov}"
JOBS="${FFI_JOBS:-$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN)}"

COV="obj/cov"
RTS="$COV/rts"
TRACES="$COV/traces"
REPORT="$COV/report"
UNITS="coverage/units.txt"
EXPLAINED="coverage/explained.txt"
LEVEL="stmt+mcdc"
X=(-XFOUNDATION_SPARK_FFI_BUILD=coverage -XGNATCOV_RTS_LIBRARY_TYPE=static-pic)

case "$(uname -s)" in
  Darwin) EXT=dylib ;;
  *)      EXT=so ;;
esac
LIB="$COV/lib/libfoundation_spark_ffi.$EXT"

die() { echo "check-coverage.sh: $*" >&2; exit 2; }

command -v "$GNATCOV" >/dev/null 2>&1 || die "gnatcov not found (set GNATCOV)"
GNATCOV="$(command -v "$GNATCOV")"
want_version="$(sed -nE 's/^GNATCOV_VERSION=(.*)$/\1/p' scripts/toolchain-pins.env)"
have_version="$("$GNATCOV" --version | head -n 1)"
# "GNATcoverage FSF 26.2" for the crate gnatcov=26.2.1: compare the release.
case "$want_version" in
  "${have_version##* }"|"${have_version##* }".*) ;;
  *) die "gnatcov is \"$have_version\", the pin is GNATCOV_VERSION=$want_version" ;;
esac
[ -f "$UNITS" ] || die "missing $UNITS"
[ -f "$EXPLAINED" ] || die "missing $EXPLAINED"

# The Alire environment (the toolchain on PATH, and GPR_PROJECT_PATH), plus
# the gnatcov runtime's project.
eval "$("$ALR" -n printenv)"
export GPR_PROJECT_PATH="$ROOT/$RTS/share/gpr:$GPR_PROJECT_PATH"

# --- 1. the runtime --------------------------------------------------------------

stamp="$RTS/gnatcov-version"
if [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$have_version" ]; then
  echo ">> installing the gnatcov runtime in spark/$RTS ($have_version)"
  rm -rf "$RTS"
  "$GNATCOV" setup -q --prefix="$RTS" > "$COV-setup.log" 2>&1 \
    || { cat "$COV-setup.log"; die "gnatcov setup failed"; }
  echo "$have_version" > "$stamp"
fi

# --- 2. the instrumented library ------------------------------------------------------

echo ">> instrumenting ($LEVEL, $(grep -c . "$UNITS") units of interest)"
"$GNATCOV" instrument -q -P foundation_spark_ffi.gpr "${X[@]}" \
  --level="$LEVEL" --dump-trigger=manual --units=@"$UNITS" -j0

echo ">> building the instrumented FFI library (-j$JOBS)"
gprbuild -p -q -s -j"$JOBS" -P foundation_spark_ffi.gpr "${X[@]}" \
  --src-subdirs=gnatcov-instr --implicit-with=gnatcov_rts
[ -f "$LIB" ] || die "the build did not produce $LIB"

# --- 3. the properties, each run writing a trace -----------------------------------

rm -rf "$TRACES" "$REPORT"
mkdir -p "$TRACES" "$REPORT"
export GNATCOV_TRACE_FILE="$ROOT/$TRACES/"

status=0
FFI_LIB="$LIB" FFI_OUT="$COV/ffi" GITHUB_STEP_SUMMARY='' \
  "$ROOT/scripts/check-ffi.sh" "$@" || status=$?
[ "$status" -le 1 ] || exit "$status"

runs="$(grep -vc '^#' "$COV/ffi/ffi-results.txt" || true)"
traces=("$TRACES"/*.srctrace)
[ -e "${traces[0]}" ] || traces=()
echo ">> $runs cryptol run(s), ${#traces[@]} trace(s)"
if [ "${#traces[@]}" -ne "$runs" ]; then
  echo "!! expected one trace per cryptol run" >&2
  status=1
fi
[ "${#traces[@]}" -gt 0 ] || die "no trace to report on"

# --- 4. the report ---------------------------------------------------------------------

echo ">> consolidating ${#traces[@]} traces"
for fmt in report xcov+ xml; do
  case "$fmt" in
    report) out=(-o "$REPORT/report.txt") ;;
    xcov+)  out=(--output-dir="$REPORT/xcov") ;;
    xml)    out=(--output-dir="$REPORT/xml") ;;
  esac
  "$GNATCOV" coverage -q -P foundation_spark_ffi.gpr "${X[@]}" \
    --level="$LEVEL" --units=@"$UNITS" --annotate="$fmt" "${out[@]}" \
    "${traces[@]}"
done

explained=0
python3 "$ROOT/scripts/coverage-summary.py" "$REPORT/xml" \
  --report "$REPORT/report.txt" --explained "$EXPLAINED" \
  > "$REPORT/summary.txt" || explained=$?
cat "$REPORT/summary.txt"
case "$explained" in
  0) ;;
  1) echo "!! a violation is not explained in spark/$EXPLAINED: close it with a property, or explain it" >&2
     status=1 ;;
  *) die "coverage-summary.py failed" ;;
esac

if [ -n "${GITHUB_STEP_SUMMARY-}" ]; then
  {
    echo "### Coverage under the FFI properties ($LEVEL)"
    echo
    echo '```'
    cat "$REPORT/summary.txt"
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$status" -ne 0 ]; then
  echo "!! COVERAGE RUN FAILED -- see above; report: spark/$REPORT"
  exit 1
fi
echo ">> coverage report: spark/$REPORT (summary.txt, report.txt, xcov/)"
