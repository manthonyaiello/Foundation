#!/usr/bin/env python3
"""perf-report.py -- the size and benchmark tables.

Called by scripts/perf-aes.sh with the perf output directory. It reads
<dir>/manifest.txt, one build per line:

    name|side|binary|bench-output

where side is "spark" or "rust", and prints Markdown to stdout:

* the known-answer check (FIPS-197 Appendix C) of every build: any mismatch
  is an error (exit 1);
* the size table: per build, the text and data of the AES library code, the
  wrappers, and the whole executable's text for scale; then each AES
  function's text, per build;
* the benchmark table: per key size and operation, each build's median ns
  per call, with the interquartile range, and the SPARK/Rust ratios.

Sizes come from the symbol table of the linked executable:
* On Linux, `nm -S` gives each symbol's size.
* On macOS (Mach-O has no symbol sizes), the linker map that perf.gpr and
  perf-aes.sh ask ld64 for (-map) gives each atom's size.
Anonymous constants (Rust's l_anon.*, GCC's literal pools) belong to no
crate by name and are not counted in either side's AES data.

"AES library code" is, for SPARK, every symbol of the crate
(foundation_spark__*), and for Rust, every symbol of NSA's Cipher and
KeyExpansion crates. The wrappers are perf_aes__* and aes_perf::{expand_key,
encrypt, decrypt}. Everything else (the harness, the GNAT runtime, Rust's
std, core and alloc) is left out of the AES columns.
"""

import os
import re
import subprocess
import sys

KAT = {
    ("aes128", "encrypt"): "69c4e0d86a7b0430d8cdb78070b4c55a",
    ("aes192", "encrypt"): "dda97ca4864cdfe06eaf70a0ec0d7191",
    ("aes256", "encrypt"): "8ea2b7ca516745bfeafc49904b496089",
}
PLAIN = "00112233445566778899aabbccddeeff"
SIZES = ["aes128", "aes192", "aes256"]
OPS = ["expand_key", "encrypt", "decrypt", "decrypt_prime"]


def run(cmd):
    """Run a command and return its standard output."""
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def rust_path(sym):
    """Demangle a legacy Rust symbol (_ZN...E) to its path, without the hash."""
    s = sym.lstrip("_")
    if not s.startswith("ZN"):
        return None
    i, parts = 2, []
    while i < len(s) and s[i] != "E":
        m = re.match(r"\d+", s[i:])
        if not m:
            return None
        n = int(m.group(0))
        i += len(m.group(0))
        parts.append(s[i:i + n])
        i += n
    if parts and re.fullmatch(r"h[0-9a-f]{16}", parts[-1]):
        parts = parts[:-1]
    return "::".join(parts)


def classify(side, sym):
    """Where a symbol belongs: ("lib", name), ("wrap", name), or None."""
    name = sym[1:] if sys.platform == "darwin" and sym.startswith("_") else sym
    if side == "spark":
        if name.startswith("foundation_spark__"):
            return "lib", name[len("foundation_spark__"):].replace("__", ".")
        if name.startswith("perf_aes__"):
            return "wrap", "Perf_AES." + name[len("perf_aes__"):]
        return None
    path = rust_path(name) or ""
    if path.startswith("Cipher::") or path.startswith("KeyExpansion::"):
        return "lib", path
    if path in ("aes_perf::expand_key", "aes_perf::encrypt", "aes_perf::decrypt"):
        return "wrap", path
    return None


def symbols_linux(binary):
    """(name, size, is_text) of every sized symbol, and the .text size."""
    out = []
    for line in run(["nm", "-S", "--defined-only", binary]).splitlines():
        f = line.split()
        if len(f) == 4:
            out.append((f[3], int(f[1], 16), f[2] in "tT"))
    text = 0
    for line in run(["size", "-A", binary]).splitlines():
        f = line.split()
        if len(f) >= 2 and f[0] == ".text":
            text = int(f[1])
    return out, text


def symbols_darwin(binary):
    """(name, size, is_text) of every symbol, and the __text size, from the
    linker map <binary>.map (ld64 -map): Mach-O symbol tables carry no
    sizes, and the map gives every atom's exact size, anonymous constants
    included. The __text size is checked against `size -m`."""
    text_lo = text_hi = None
    out, part = [], None
    for line in open(binary + ".map", errors="replace"):
        if line.startswith("# Sections:"):
            part = "sections"
        elif line.startswith("# Symbols:"):
            part = "symbols"
        elif line.startswith("# Dead Stripped Symbols:"):
            part = None
        elif line.startswith("#"):
            continue
        elif part == "sections":
            f = line.split()
            if len(f) == 4 and f[2:] == ["__TEXT", "__text"]:
                text_lo = int(f[0], 16)
                text_hi = text_lo + int(f[1], 16)
        elif part == "symbols":
            m = re.match(r"0x([0-9A-Fa-f]+)\s+0x([0-9A-Fa-f]+)\s+\[\s*\d+\]\s+(\S+)",
                         line)
            if m:
                addr, size = int(m.group(1), 16), int(m.group(2), 16)
                out.append((m.group(3), size, text_lo <= addr < text_hi))
    text = 0
    for line in run(["size", "-m", "-l", binary]).splitlines():
        m = re.match(r"\s+Section __text: (\d+)", line)
        if m:
            text = int(m.group(1))
            break
    if text != text_hi - text_lo:
        sys.exit(f"perf-report.py: {binary}.map does not match {binary}")
    return out, text


def sizes(side, binary):
    """Per-function AES sizes and the totals of one build."""
    syms, text = (symbols_darwin if sys.platform == "darwin"
                  else symbols_linux)(binary)
    funcs = {}
    tot = {"lib_text": 0, "lib_data": 0, "wrap_text": 0, "bin_text": text}
    for name, size, is_text in syms:
        c = classify(side, name)
        if c is None:
            continue
        kind, label = c
        if is_text:
            funcs[label] = funcs.get(label, 0) + size
            tot[kind + "_text"] += size
        elif kind == "lib":
            tot["lib_data"] += size
            funcs[label + " (data)"] = size
    return funcs, tot


def bench(path):
    """KAT lines and bench lines of one run."""
    kat, res = {}, {}
    if not os.path.exists(path):
        return kat, res
    for line in open(path):
        f = line.split()
        if f and f[0] == "kat":
            kat[(f[1], f[2])] = f[3]
        elif f and f[0] == "bench":
            res[(f[1], f[2])] = [float(x) for x in f[3:8]]
    return kat, res


def ratios(runs):
    """SPARK median / Rust median, each SPARK build against the Rust build at
    its optimization level (rust-O2 or rust-O3). NSA's inv_cipher undoes the
    rounds of cipher in reverse order, as Decrypt_Block_Prime does, so Rust's
    decrypt is set against both SPARK decryptions."""
    rust = {name: res for name, side, res in runs if side == "rust"}
    pairs = []
    for name, side, res in runs:
        lvl = re.search(r"O[23]", name)
        if side == "spark" and lvl and "rust-" + lvl.group(0) in rust:
            pairs.append((name, res, rust["rust-" + lvl.group(0)]))
    if not pairs:
        return
    print("\n## SPARK / Rust (median over median, same optimization level)\n")
    print("| op | " + " | ".join(f"{p[0]} / rust-{re.search(r'O[23]', p[0]).group(0)}"
                                 for p in pairs) + " |")
    print("|---|" + "---:|" * len(pairs))
    for k in SIZES:
        for op in OPS:
            r_op = "decrypt" if op == "decrypt_prime" else op
            cells = []
            for _n, s, r in pairs:
                if (k, op) in s and (k, r_op) in r:
                    cells.append(f"{s[(k, op)][0] / r[(k, r_op)][0]:.2f}")
                else:
                    cells.append("")
            print(f"| {k} {op} | " + " | ".join(cells) + " |")


def main():
    out = sys.argv[1]
    builds = []
    for line in open(os.path.join(out, "manifest.txt")):
        if line.strip():
            name, side, binary, res = line.strip().split("|")
            builds.append((name, side, binary, res))

    status = 0
    print("## Known answers (FIPS-197 Appendix C.1-C.3)\n")
    for name, side, _, res in builds:
        kat, _r = bench(res)
        if not kat:
            print(f"* {name}: not run")
            continue
        bad = [k for k in kat
               if kat[k] != (KAT.get(k) if k[1] == "encrypt" else PLAIN)]
        missing = [k for k in KAT if k not in kat]
        if bad or missing:
            status = 1
            print(f"* {name}: **FAIL** {bad + missing}")
        else:
            print(f"* {name}: {len(kat)}/{len(kat)} match")

    print("\n## Size (bytes, linked executable)\n")
    print("| build | AES text | AES data | wrappers | AES total | "
          "executable text |")
    print("|---|---:|---:|---:|---:|---:|")
    per = {}
    for name, side, binary, _ in builds:
        funcs, t = sizes(side, binary)
        per[name] = funcs
        print(f"| {name} | {t['lib_text']} | {t['lib_data']} | "
              f"{t['wrap_text']} | "
              f"{t['lib_text'] + t['lib_data'] + t['wrap_text']} | "
              f"{t['bin_text']} |")

    print("\n### Per function (text bytes; data marked)\n")
    for name, _side, _b, _r in builds:
        funcs = per[name]
        items = sorted(funcs.items(), key=lambda kv: (-kv[1], kv[0]))
        print(f"* **{name}**: " + ", ".join(f"`{k}` {v}" for k, v in items))

    print("\n## Time (ns per call: median, [p25, p75])\n")
    runs = [(name, side, bench(res)[1]) for name, side, _, res in builds]
    runs = [r for r in runs if r[2]]
    if runs:
        print("| op | " + " | ".join(r[0] for r in runs) + " |")
        print("|---|" + "---:|" * len(runs))
        for k in SIZES:
            for op in OPS:
                cells = []
                for _n, _s, res in runs:
                    v = res.get((k, op))
                    cells.append(f"{v[0]:.1f} [{v[2]:.1f}, {v[3]:.1f}]"
                                 if v else "")
                if any(cells):
                    print(f"| {k} {op} | " + " | ".join(cells) + " |")
        print("\nmin / max per op and build: in each build's .bench.txt "
              "(fields: median min p25 p75 max).")
        ratios(runs)
    sys.exit(status)


if __name__ == "__main__":
    main()
