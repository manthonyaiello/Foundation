#!/usr/bin/env python3
"""Per-layer effort tables for ANALYSIS.md, from agents.csv and commands.csv.

Usage: summarize.py [--per-transcript] [EFFORT_DIR]   (default: this file's directory)

Each transcript (machine, session, who) is assigned one layer in LAYERS
below. For each layer it prints the transcripts' summed wall-clock, tool
calls and output tokens, and the time they spent waiting on tools: per
transcript, the union of the intervals of its commands in each tool
category (so a background run and the poll that waits on it count once),
summed over the layer's transcripts.

A `poll-wait` row (an `until ...; do sleep` loop on a background job's
output) is attributed to the tool category of the same transcript's
latest background command started before it; when that command has no
tool category, or there is none, it stays `poll-wait`. That attribution
is a heuristic.

`silent` is the time in gaps of over 30 minutes in which none of the
transcript's commands was running: a tick idle after its report, or
resumed later by a message; for an orchestrator, mostly waiting on its
ticks or on Tony. `rest` = wall-clock - silent - waiting on tools: the
agent's own work (reading, writing, short commands).

With --per-transcript, prints one row per transcript instead.
"""
import csv, os, sys
from collections import defaultdict
from datetime import datetime, timedelta

#: (machine, who) -> layer. `who` is the orchestrator's session id prefix
#: for an orchestrator, else the agent id prefix.
LAYERS = {
    # foundation, 0f5e52b6 (2026-10-18/19): E0-E3, M5.1
    ("foundation", "agent-ac360d3b"): "spec",      # M1.1 AES spec (#8)
    ("foundation", "agent-a7264b6a"): "spec",      # M1.2 KeyExpansion (#9)
    ("foundation", "agent-a3440681"): "spec",      # M1.3 Cipher/InvCipher/Main (#10)
    ("foundation", "agent-a5db082b"): "spec",      # M2.1 SHA-2 spec (#14)
    ("foundation", "agent-abf62d1e"): "spec",      # M2.2 pad/parse/hash (#15)
    ("foundation", "agent-a83e9070"): "spec",      # M3.1 HMAC spec (#19)
    ("foundation", "agent-ad2bca77"): "spec-properties",  # M1.5 AES Cryptol properties (#12)
    ("foundation", "agent-a3102908"): "impl",      # M1.4 AES implementation (#11)
    ("foundation", "agent-a079d1ec"): "impl",      # M2.3 SHA-256 byte refinement (#16)
    ("foundation", "agent-a9a36781"): "impl",      # M2.4 SHA-256 streaming (#17)
    ("foundation", "agent-a25a7963"): "impl",      # M3.2 HMAC impl (#20)
    ("foundation", "agent-a49aa7d3"): "impl",      # remaining board rows: executable counterparts
    ("foundation", "agent-ad1bee8e"): "ffi",       # M0.3 FFI harness (#4)
    ("foundation", "agent-aec083e4"): "ffi",       # FFI onto the AES spec
    ("foundation", "agent-a20f3c9a"): "ffi",       # FFI for SHA-256 and HMAC
    ("foundation", "agent-a1885e7d"): "ffi",       # AES impl FFI export (#11)
    ("foundation", "agent-a4bd897a"): "reobtain-spark",  # x86_64 proof margins (#54)
    ("foundation", "agent-ad7b5bc3"): "infra",     # CI (#3)
    ("foundation", "agent-abeb7273"): "infra",     # Cryptol from source (#2)
    ("foundation", "agent-a51e7923"): "infra",     # levels and board (#5)
    ("foundation", "agent-a51fff23"): "infra",     # restack spec PRs
    ("foundation", "agent-a6a6cdfb"): "infra",     # restack SHA/HMAC onto FFI
    ("foundation", "agent-a0002a4a"): "infra",     # on-demand slow proofs + restack
    ("foundation", "agent-a53e6730"): "infra",     # x86_64 bootstrap (#6)
    ("foundation", "agent-a2d2e245"): "other",     # M5.1 coverage (#49)
    # foundation, 0022b46d (2026-10-20/21): review follow-ups
    ("foundation", "agent-a812b736"): "reobtain-spark",  # #72 remove SPARKlib
    ("foundation", "agent-af9201bd"): "reobtain-spark",  # #68 narrow Bit_Index
    ("foundation", "agent-a65a31dc"): "reobtain-spark",  # #74 spike, generic AES spec
    ("foundation", "agent-aa4c1a67"): "reobtain-spark",  # #80 full AES generic
    ("foundation", "agent-ab0acb6a"): "reobtain-spark",  # #75 prelude + SHA-2/HMAC
    ("foundation", "agent-ab79f9a4"): "reobtain-spark",  # #75 AES migration
    ("foundation", "agent-adc5fb7f"): "reobtain-spark",  # #70 cheap part: move SBox_Entries
    ("foundation", "agent-a0ce48f4"): "reobtain-spark",  # #70 cheaper SBoxCorrect
    ("foundation", "agent-a1200683"): "infra",     # #67 board kinds, docs
    ("foundation", "agent-a4bd4fed"): "other",     # #50 constant-time AES
    ("foundation", "agent-a3bd5bae"): "other",     # crosswalk snapshot (docs)
    ("foundation", "agent-a6ac2127"): "other",     # old-vs-new page (docs)
    # iod, 0f6e209a (2026-10-19/20): E4
    ("iod", "agent-a7e6b907"): "saw-impl",         # M4.1 spike (#22)
    ("iod", "agent-a06ea36f"): "saw-impl",         # M4.2 AES (#23)
    ("iod", "agent-ac0466c2"): "saw-impl",         # M4.3 SHA-256/HMAC (#24)
    ("iod", "agent-ab3f8564"): "saw-spec",         # M4.4 spec layer (#59)
    ("iod", "agent-a418d907"): "saw-spec",         # #59 gaps
    ("iod", "agent-aef69b74"): "other",            # unnamed helper
    # iod, bfed13a5 (2026-10-21/22): SAW after the spec changes
    ("iod", "agent-aaaef209"): "reobtain-saw",     # tick A, SAW impl repair
    ("iod", "agent-a175171e"): "reobtain-saw",     # tick B, SAW spec-layer repair
    ("iod", "agent-ae15b4fa"): "saw-spec",         # tick C, SAW Parse (#67): a new spec-layer proof
    ("iod", "agent-abfcdb36"): "reobtain-saw",     # tick E, record staleness fix (#95): a new record
    ("iod", "agent-aa4121a9"): "other",            # tick D, #69 cost analysis
    ("iod", "agent-a8a83d08"): "other",            # #50 x86_64 constant time
}
ORDER = ["spec", "spec-properties", "impl", "ffi", "saw-impl", "saw-spec",
         "reobtain-spark", "reobtain-saw", "infra", "other",
         "orchestration, foundation", "orchestration, iod", "review"]
REVIEW = {"9388b3d5", "3cff259e"}  # sessions with Tony, no ticks
TOOLS = ["gnatprove", "ffi", "saw", "ci-wait", "build+ct", "poll-wait"]


def tool(cat):
    if cat.startswith("saw-"):
        return "saw"
    if cat in ("build", "constant-time"):
        return "build+ct"
    return cat if cat in TOOLS else None


def layer(machine, session, who):
    if who == "orchestrator":
        return "review" if session in REVIEW else "orchestration, " + machine
    return LAYERS.get((machine, who), "unassigned")


def union(iv):
    tot, end = timedelta(), None
    for a, b in sorted(iv):
        if end is None or a > end:
            tot += b - a; end = b
        elif b > end:
            tot += b - end; end = b
    return tot.total_seconds()


SILENT = 1800  # seconds


def silent(a, rows):
    """Gaps over SILENT seconds, between the transcript's start and end, in
    which none of its commands was running (a background command with no
    recorded duration counts as an instant)."""
    busy = [(datetime.fromisoformat(a["start"]),) * 2, (datetime.fromisoformat(a["end"]),) * 2]
    for r in rows:
        t0 = datetime.fromisoformat(r["start"])
        busy.append((t0, t0 + timedelta(seconds=float(r["seconds"] or 0))))
    tot, end = 0.0, None
    for x, y in sorted(busy):
        if end is not None and (x - end).total_seconds() > SILENT:
            tot += (x - end).total_seconds()
        end = y if end is None or y > end else end
    return tot


def main():
    args = sys.argv[1:]
    per = "--per-transcript" in args
    args = [a for a in args if a != "--per-transcript"]
    d = args[0] if args else os.path.dirname(os.path.abspath(__file__))
    agents = list(csv.DictReader(open(os.path.join(d, "agents.csv"))))
    cmds = defaultdict(list)
    for r in csv.DictReader(open(os.path.join(d, "commands.csv"))):
        cmds[(r["machine"], r["session"], r["who"])].append(r)
    L = defaultdict(lambda: defaultdict(float))
    for a in agents:
        key = (a["machine"], a["session"], a["who"])
        g = L[(key[0], key[1], key[2], a["description"]) if per else layer(*key)]
        g["layer"] = layer(*key)
        g["n"] += 1
        for f in ("wall_seconds", "tool_calls", "output_tokens"):
            g[f] += float(a[f])
        iv, last_bg = defaultdict(list), None
        for r in sorted(cmds[key], key=lambda r: r["start"]):
            t = tool(r["category"])
            if r["background"] == "True" and t != "poll-wait":
                last_bg = t  # None for a background job of no tool category
            if t is None or not r["seconds"]:
                continue
            if t == "poll-wait" and last_bg:
                t = last_bg
            t0 = datetime.fromisoformat(r["start"])
            iv[t].append((t0, t0 + timedelta(seconds=float(r["seconds"]))))
        for t, x in iv.items():
            g[t] += union(x)
        g["tools"] += union([i for x in iv.values() for i in x])
        g["silent"] += silent(a, cmds[key])
    h = lambda s: "%.2f" % (s / 3600)
    cols = ["wall-clock h", "silent h", "tool calls", "output tokens", "waiting on tools h"] \
        + [t + " h" for t in TOOLS] + ["rest h"]
    vals = lambda g: [h(g["wall_seconds"]), h(g["silent"]), "%d" % g["tool_calls"], "%d" % g["output_tokens"],
                      h(g["tools"])] + [h(g[t]) for t in TOOLS] \
        + [h(g["wall_seconds"] - g["silent"] - g["tools"])]
    rank = lambda name: ORDER.index(name) if name in ORDER else len(ORDER)
    if per:
        head = ["machine", "session", "who", "description", "layer"]
        keys = sorted(L, key=lambda k: (rank(L[k]["layer"]), k))
        cells = lambda k: list(k[:3]) + [k[3] or "(none)", L[k]["layer"]]
    else:
        head = ["layer", "transcripts"]
        keys = sorted(L, key=lambda k: (rank(k), k))
        cells = lambda k: [k, "%d" % L[k]["n"]]
    print("| " + " | ".join(head + cols) + " |")
    print("|" + "---|" * (len(head) + len(cols)))
    for k in keys:
        print("| " + " | ".join(cells(k) + vals(L[k])) + " |")


main()
