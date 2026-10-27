#!/usr/bin/env bash
#
# run-all.sh OUT_DIR -- every #69 experiment, one after the other (one saw
# at a time), each into OUT_DIR/<experiment>[-<variant>]/ (run.sh). The
# write-up's numbers are from one such run on an otherwise idle machine:
# spark/doc/saw.md, "Why the spec layer costs about 76 times the implementation".
#
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:?usage: run-all.sh OUT_DIR}"
mkdir -p "$OUT"
run() { echo ">> $* ($(date -u +%H:%M:%S))"; "$HERE/run.sh" "$@" > /dev/null 2>&1; echo "   exit $?"; }
run tobits_w0b "$OUT/tobits_w0b"
run tobits_chain "$OUT/tobits_chain"
run -v chunk8k tobits_chain "$OUT/tobits_chain-chunk8k"
run -v chunk1m tobits_chain "$OUT/tobits_chain-chunk1m"
run recursion_aes "$OUT/recursion_aes"
run recursion_wide "$OUT/recursion_wide"
run recursion_sha "$OUT/recursion_sha"
run hash "$OUT/hash"
run -p probes "$OUT/probes"
echo ">> done ($(date -u +%H:%M:%S))"
