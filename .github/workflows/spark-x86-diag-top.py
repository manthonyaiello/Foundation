# TEMPORARY (spark-x86-diag.yml). Pairs each gnatprove "info: ... proved
# (...)" line with the "--> file:line:col" after it, and prints the checks
# at the given locations, then the N slowest.
import re
import sys

lines = open(sys.argv[1], errors="replace").read().splitlines()
n = int(sys.argv[2])
want = sys.argv[3:]
rows = []
for i, l in enumerate(lines):
    m = re.search(r"info: (.*?) proved \((.*)\)", l)
    if not m:
        continue
    loc = ""
    for j in range(i + 1, min(i + 4, len(lines))):
        if "--> " in lines[j]:
            loc = lines[j].split("--> ")[1].strip()
            break
    times = [float(t) for t in re.findall(r"max ([0-9.]+) seconds", m.group(2))]
    steps = [int(s) for s in re.findall(r"and ([0-9]+) steps?", m.group(2))]
    rows.append((max(times or [0]), max(steps or [0]), loc, m.group(1), m.group(2)))
for r in rows:
    if any(w in r[2] for w in want) and r[3] in ("postcondition", "assertion"):
        print(f"  {r[2]}  {r[3]}  ({r[4]})")
print("-- slowest:")
for r in sorted(rows, reverse=True)[:n]:
    print(f"  {r[0]:5.1f}s {r[1]:7d} steps  {r[2]}  {r[3]}  ({r[4]})")
