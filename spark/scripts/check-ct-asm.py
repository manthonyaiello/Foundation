#!/usr/bin/env python3
"""check-ct-asm.py -- the constant-time rule, checked on the object code
(issue #50; README "Constant time").

Reads `objdump -d -r` output of the release-built AES, SHA-256 and HMAC
objects (scripts/check-ct.sh makes it) and, function by function, finds the
two instruction shapes through which a secret reaches timing:

* a conditional branch (aarch64 b.<cond>, cbz, cbnz, tbz, tbnz; x86_64 any
  j<cc>), and an indirect branch (br/blr, jmp/call through a register);
* a load or store whose address has an index register (aarch64
  [xN, xM ...] / [xN, wM ...]; x86_64 (base,index,scale)), the shape of a
  table lookup.

The rule. In the functions of STRAIGHT (below), whose every input may be
secret and which have no public loop or length, both counts must be zero.
The functions of LOOPS may branch, and index memory, only on public values:
loop counters, the key size K and lengths; the script lists their sites for
review and counts them, but it cannot tell a public condition from a secret
one, so it does not fail on them. A function the script does not find (it
was inlined everywhere) is reported, not failed.

Usage: check-ct-asm.py DISASSEMBLY...    (exit 1 on a violation)
"""

import re
import sys

PREFIXES = (
    "foundation_spark__aes__impl__",
    "foundation_spark__sha2__",
    "foundation_spark__hmac__",
)

# Functions that see secret data and have no public loop bound or length:
# no conditional branch and no indexed memory access, at all.
STRAIGHT = {
    "foundation_spark__aes__impl__x_times",
    "foundation_spark__aes__impl__sbox_lanes",
    "foundation_spark__aes__impl__inv_sbox_lanes",
    "foundation_spark__aes__impl__sub_byte",
    "foundation_spark__aes__impl__inv_sub_byte",
    "foundation_spark__aes__impl__sub_word",
    "foundation_spark__aes__impl__rot_word",
    "foundation_spark__aes__impl__xor_word",
    "foundation_spark__aes__impl__sub_bytes",
    "foundation_spark__aes__impl__inv_sub_bytes",
    "foundation_spark__aes__impl__shift_rows",
    "foundation_spark__aes__impl__inv_shift_rows",
    "foundation_spark__aes__impl__mix_column",
    "foundation_spark__aes__impl__inv_mix_column",
    "foundation_spark__aes__impl__inv_mix_byte",
    "foundation_spark__aes__impl__mix_columns",
    "foundation_spark__aes__impl__inv_mix_columns",
    "foundation_spark__aes__impl__add_round_key",
    "foundation_spark__aes__impl__round",
    "foundation_spark__aes__impl__inv_round",
    "foundation_spark__aes__impl__inv_round_prime",
}

# Functions with public loops (rounds, bits, words, blocks) or lengths.
LOOPS = {
    "foundation_spark__aes__impl__dot",
    "foundation_spark__aes__impl__rcon",
    "foundation_spark__aes__impl__expand_key",
    "foundation_spark__aes__impl__encrypt_block",
    "foundation_spark__aes__impl__decrypt_block",
    "foundation_spark__aes__impl__decrypt_block_prime",
    "foundation_spark__sha2__sha256_stream__compress",
    "foundation_spark__sha2__sha256_stream__load_block",
    "foundation_spark__sha2__sha256_stream__to_digest",
    "foundation_spark__sha2__sha256_stream__init",
    "foundation_spark__sha2__sha256_stream__update",
    "foundation_spark__sha2__sha256_stream__final",
    "foundation_spark__sha2__sha256_stream__hash",
    "foundation_spark__sha2__sha256_stream__hash_chunked",
    "foundation_spark__hmac__sha256_impl__init_key",
    "foundation_spark__hmac__sha256_impl__xor_pad",
    "foundation_spark__hmac__sha256_impl__hmac_sha256",
    "foundation_spark__hmac__sha256_impl__init",
    "foundation_spark__hmac__sha256_impl__update",
    "foundation_spark__hmac__sha256_impl__final",
}


def module(func):
    """The unit prefix of a symbol, up to its last "__"."""
    return func.rsplit("__", 1)[0]

A64_BRANCH = re.compile(r"^(b\.[a-z]+|cbn?z|tbn?z)$")
A64_INDIRECT = re.compile(r"^(br|blr)$")
A64_INDEXED = re.compile(r"\[\s*x\d+|sp\s*,\s*[xw]\d+")
A64_MEM = re.compile(r"^(ld|st)")
X86_BRANCH = re.compile(r"^j(?!mp)[a-z]+$")
X86_INDEXED = re.compile(r"\(%?[a-z0-9]*,%[a-z0-9]+(,\d)?\)")

FUNC = re.compile(r"^[0-9a-f]+ <([^>]+)>:$")
INSN = re.compile(r"^\s+([0-9a-f]+):\s+(\S+)\s*(.*)$")


def scan(lines, arch):
    """Yield (function, offset, kind, text) for each site."""
    func = None
    for line in lines:
        m = FUNC.match(line)
        if m:
            func = m.group(1)
            continue
        m = INSN.match(line)
        if not m or func is None:
            continue
        off, op, args = m.group(1), m.group(2), m.group(3)
        text = (op + " " + args).strip()
        if arch == "aarch64":
            if A64_BRANCH.match(op):
                yield func, off, "branch", text
            elif A64_INDIRECT.match(op):
                yield func, off, "indirect", text
            elif A64_MEM.match(op):
                # [xN, xM] or [xN, wM, uxtw]: an index register.
                mm = re.search(r"\[([^\]]*)\]", args)
                if mm:
                    parts = [p.strip() for p in mm.group(1).split(",")]
                    if len(parts) >= 2 and re.match(r"^[xw]\d+$", parts[1]):
                        yield func, off, "indexed", text
        else:
            if X86_BRANCH.match(op):
                yield func, off, "branch", text
            elif op in ("jmp", "call", "jmpq", "callq") and "*" in args:
                yield func, off, "indirect", text
            elif X86_INDEXED.search(args) and not op.startswith("lea") \
                    and not op.startswith("nop"):
                yield func, off, "indexed", text


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    seen = set()
    sites = {}
    for path in sys.argv[1:]:
        with open(path) as f:
            lines = f.read().splitlines()
        arch = "x86_64" if any("x86-64" in ln for ln in lines[:5]) \
            else "aarch64"
        for ln in lines:
            m = FUNC.match(ln)
            if m:
                seen.add(m.group(1))
        for func, off, kind, text in scan(lines, arch):
            sites.setdefault(func, []).append((off, kind, text))

    bad = 0
    scanned = {module(f) for f in seen}
    print("Straight-line functions (rule: no branch, no indexed access):")
    for func in sorted(STRAIGHT):
        if module(func) not in scanned:
            continue
        if func not in seen:
            print(f"  {func}: not in the object code (inlined)")
            continue
        s = sites.get(func, [])
        verdict = "ok" if not s else "VIOLATION"
        print(f"  {func}: {len(s)} site(s) {verdict}")
        for off, kind, text in s:
            print(f"      {off}: {kind:8} {text}")
        bad += len(s)
    print("Loop functions (sites listed for review, on public values only):")
    for func in sorted(LOOPS):
        if module(func) not in scanned:
            continue
        if func not in seen:
            print(f"  {func}: not in the object code (inlined)")
            continue
        s = sites.get(func, [])
        kinds = {}
        for _, kind, _ in s:
            kinds[kind] = kinds.get(kind, 0) + 1
        print(f"  {func}: " + (", ".join(f"{v} {k}" for k, v in
                                        sorted(kinds.items())) or "none"))
        for off, kind, text in s:
            print(f"      {off}: {kind:8} {text}")
    others = sorted(f for f in seen
                    if f.startswith(PREFIXES) and f not in STRAIGHT | LOOPS)
    print("Other functions in the objects (not classified):")
    for func in others:
        s = sites.get(func, [])
        kinds = {}
        for _, kind, _ in s:
            kinds[kind] = kinds.get(kind, 0) + 1
        print(f"  {func}: " + (", ".join(f"{v} {k}" for k, v in
                                        sorted(kinds.items())) or "none"))
    print(f"check-ct-asm: {bad} violation(s) in straight-line functions")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
