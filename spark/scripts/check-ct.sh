#!/usr/bin/env bash
#
# check-ct.sh -- the constant-time checks of issue #50 (README "Constant
# time"), on whatever machine it runs on (aarch64 or x86_64):
#
# 1. builds ct/ct.gpr: AES, SHA-256 and HMAC from src/, at Alire's release
#    optimization level (-O3 -gnatn, default runtime checks), with the
#    throughput benchmark ct_bench and the timing test ct_dudect;
# 2. disassembles the release objects of AES.Impl, SHA256_Stream,
#    SHA256_Bytes and HMAC.SHA256_Impl (objdump -d -r) into obj/ct/asm/ and
#    runs scripts/check-ct-asm.py on them: it FAILS if a straight-line
#    function (one that sees secrets and has no public loop) has a
#    conditional or indirect branch or an indexed memory access, and lists
#    the sites of the loop functions for review;
# 3. if valgrind is on PATH, runs ct_grind under Memcheck (the secrets
#    marked undefined, ctgrind-style): it FAILS on any Memcheck error, and
#    on a control run (a deliberate table lookup) that reports none;
# 4. unless CT_SKIP_TIMING=1, runs ct_bench, and ct_dudect on every target
#    (CT_SAMPLES measurements each, default 1000000), writing all output to
#    obj/ct/ct-report.txt. dudect's verdicts are reported, not enforced:
#    timing statistics on a shared machine are evidence, not a gate.
#
# Usage: scripts/check-ct.sh
# Env:
#   OBJDUMP         objdump for the target (default: objdump; on foundation,
#                   GNAT's own, in the gnat_native toolchain's bin/)
#   GPRBUILD        gprbuild (default: gprbuild)
#   CT_SAMPLES      dudect measurements per target (default 1000000)
#   CT_SKIP_TIMING  1 to stop after the object-code check
#
# Exit status: 1 if the object-code rule or ct_grind fails, 0 otherwise.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OBJDUMP="${OBJDUMP:-objdump}"
GPRBUILD="${GPRBUILD:-gprbuild}"
SAMPLES="${CT_SAMPLES:-1000000}"
OUT="obj/ct"
ASM="$OUT/asm"
REPORT="$OUT/ct-report.txt"

ARCH="$(uname -m)"
case "$ARCH" in
  aarch64|arm64) ARCH=aarch64 ;;
  x86_64|amd64)  ARCH=x86_64 ;;
  *) echo "check-ct.sh: no Valgrind client requests for $ARCH" >&2; exit 2 ;;
esac
"$GPRBUILD" -P ct/ct.gpr -q -XCT_ARCH="$ARCH" -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"

mkdir -p "$ASM"
units=(foundation_spark-aes-impl foundation_spark-sha2-sha256_stream
       foundation_spark-sha2-sha256_bytes foundation_spark-hmac-sha256_impl)
for u in "${units[@]}"; do
  "$OBJDUMP" -d -r --no-show-raw-insn "$OUT/$u.o" > "$ASM/$u.s"
done

{
  echo "# check-ct.sh on $(uname -m), $(date -u +%Y-%m-%dT%H:%M:%SZ), commit $(git rev-parse --short HEAD)$(git diff --quiet HEAD -- . || echo ' (dirty)')"
  echo "## Object code"
} > "$REPORT"
status=0
python3 -I scripts/check-ct-asm.py "$ASM"/*.s | tee -a "$REPORT" || status=1

echo "## Secret taint (ct_grind under Valgrind's Memcheck)" | tee -a "$REPORT"
if command -v valgrind >/dev/null 2>&1; then
  # The run proper must report no error; the control (one table lookup by
  # a secret byte, in ct_grind.adb) must report at least one, or the
  # marking is not working and the clean run means nothing.
  if valgrind -q --error-exitcode=1 "$OUT/ct_grind" >> "$REPORT" 2>&1; then
    echo "ct_grind: 0 Memcheck errors on the secrets" | tee -a "$REPORT"
  else
    echo "ct_grind: Memcheck errors on the secrets: FAIL" | tee -a "$REPORT"
    status=1
  fi
  if valgrind -q --error-exitcode=1 "$OUT/ct_grind" control >> "$REPORT" 2>&1; then
    echo "ct_grind control: no error, the marking does not work: FAIL" | tee -a "$REPORT"
    status=1
  else
    echo "ct_grind control: Memcheck reports the table lookup, as it must" | tee -a "$REPORT"
  fi
else
  echo "valgrind not found: ct_grind skipped" | tee -a "$REPORT"
fi

if [ "${CT_SKIP_TIMING:-0}" != 1 ]; then
  echo "## Throughput (ct_bench)" | tee -a "$REPORT"
  "$OUT/ct_bench" | tee -a "$REPORT"
  echo "## Timing (ct_dudect, $SAMPLES samples per target)" | tee -a "$REPORT"
  for t in aes128_encrypt aes128_decrypt aes128_key sha256 hmac_key; do
    "$OUT/ct_dudect" "$t" "$SAMPLES" | tee -a "$REPORT"
  done
fi

echo ">> wrote $REPORT"
exit "$status"
