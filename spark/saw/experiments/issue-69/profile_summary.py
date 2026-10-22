"""Summarize a crucible profile (enable_crucible_profiling's report_data.js).

Usage: python3 -I profile_summary.py DIR/report_data.js

Prints the symbolic simulation's span (first ENTER to last EXIT, ms) for
each llvm_verify profiled, and per function the inclusive time of its
outermost activations. Times in the file are milliseconds since the
epoch. The solver's time is not in it (crucible profiles the simulator).
"""
import json
import re
import sys
from collections import defaultdict

text = open(sys.argv[1]).read()
text = re.sub(r"^data\.receiveData\(", "", text.strip())
text = re.sub(r"\);?$", "", text)
data = json.loads(text)
for block in data:
    if block.get("type") != "callgraph":
        continue
    events = block["events"]
    if not events:
        continue
    t0 = events[0]["metrics"]["time"]
    t1 = events[-1]["metrics"]["time"]
    print(f"callgraph: {len(events)} events, span {t1 - t0:.1f} ms")
    stack = []
    incl = defaultdict(float)
    count = defaultdict(int)
    for e in events:
        f = e["function"]
        t = e["metrics"]["time"]
        if e["type"] == "ENTER":
            stack.append((f, t))
        elif e["type"] == "EXIT":
            # pop to the matching ENTER
            for i in range(len(stack) - 1, -1, -1):
                if stack[i][0] == f:
                    g, ts = stack.pop(i)
                    if all(s[0] != f for s in stack):
                        incl[f] += t - ts
                        count[f] += 1
                    break
    for f, v in sorted(incl.items(), key=lambda kv: -kv[1])[:25]:
        print(f"  {f:60s} {count[f]:5d} {v:10.1f} ms")
