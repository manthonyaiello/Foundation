"""Spec-layer cost: the spec layer's SAW results grouped by what makes them, from a
check-saw.sh record (saw/results.txt).

Usage: python3 -I causes.py saw/results.txt

Each spec-layer result (and each exhaustive RESULTS line's 256) goes to
exactly one group, the first that matches:

  stack-base   a result proved again only because the secondary stack's
               base differs (To_Bits chains after the first, and every
               result "at the secondary stack at N bytes");
  lax-copy     a result of the lax-arithmetic load that the strict load
               also proves (the compression function's lemmas, loaded
               twice because Pad/Hash need lax arithmetic);
  per-value    the exhaustive Pgcd/Inverse/Affine (recursion on a value);
  per-index    a lemma at one index or count of a recursion (W, T1, Step3,
               the folds, To_Bits' first chain, Word_Of, Foldl_Take);
  top          the rest: one result per function and size.

It prints, per group, the results and SAW's summed time, and the same per
function within the group, and the implementation layer's totals.
"""
import re
import sys
from collections import defaultdict

PER_INDEX = re.compile(
    r"(^|__)(w|t1|step3|rounds__foldl|foldl_take|pmult_fold|pmod_fold|pdiv_fold|"
    r"products__products|literal|word_sequences__value)$")
STEP_FAMILY = re.compile(
    r"^(functions__(small_)?sigma_256_[01]|sha256__logical__(ch|maj)|sha256__(w|t1|t2|step3|"
    r"rounds__foldl|foldl_step3|Oadd|step))$")

groups = defaultdict(lambda: defaultdict(lambda: [0, 0.0]))
impl = [0, 0.0]
seen_chain_base = None
for line in open(sys.argv[1]):
    if not line.startswith("proved"):
        continue
    t = 0.0
    m = re.search(r", ([0-9.]+) s( with the lines below)?$", line.rstrip())
    if m:
        t = float(m.group(1))
    n = 1
    m = re.search(r"\((\d+) proofs, one per value\)", line)
    if m:
        n = int(m.group(1))
    if not line.startswith("proved      spec layer: "):
        impl[0] += n
        impl[1] += t
        continue
    sym = line[len("proved      spec layer: "):].split(" ", 1)[0]
    lax = "(lax arithmetic module)" in line
    mb = re.search(r"the secondary stack at (\d+) bytes", line)
    if sym == "sequences_of_bits__literal":
        # The first chain (65 lemmas, W = 0 .. 64) is the recursion's
        # cost; every later one is the same chain at another stack base
        # or with other bytes kept below it.
        seen_chain_base = (seen_chain_base or 0) + 1
        g = "per-index" if seen_chain_base <= 65 else "stack-base"
    elif mb:
        g = "stack-base"
    elif lax and STEP_FAMILY.match(sym):
        g = "lax-copy"
    elif n > 1:
        g = "per-value"
    elif PER_INDEX.search(sym):
        g = "per-index"
    else:
        g = "top"
    groups[g][sym][0] += n
    groups[g][sym][1] += t

tot_n = sum(v[0] for g in groups.values() for v in g.values())
tot_t = sum(v[1] for g in groups.values() for v in g.values())
print(f"implementation: {impl[0]} results, {impl[1]:.1f} s summed")
print(f"spec layer: {tot_n} results, {tot_t:.1f} s summed")
for g in ("per-index", "stack-base", "lax-copy", "per-value", "top"):
    gn = sum(v[0] for v in groups[g].values())
    gt = sum(v[1] for v in groups[g].values())
    print(f"\n{g}: {gn} results ({100 * gn / tot_n:.1f}%), {gt:.1f} s ({100 * gt / tot_t:.1f}%)")
    for sym, (c, s) in sorted(groups[g].items(), key=lambda kv: -kv[1][1]):
        print(f"   {sym:45s} {c:5d} {s:9.2f} s")
