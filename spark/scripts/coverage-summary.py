#!/usr/bin/env python3
"""coverage-summary.py -- the per-unit coverage table of check-coverage.sh (#49).

Reads the per-source XML that `gnatcov coverage --annotate=xml` writes (one
<source> per file, whose first <scope_metric> is the whole unit) and prints,
for each unit of interest (spec and body together), the statement, decision
and MC/DC obligations covered out of those relevant, then the totals.

Usage: coverage-summary.py XML_DIR
"""

import os
import sys
import xml.etree.ElementTree as ET

KINDS = ("Stmt", "Decision", "MCDC")


def file_stats(path):
    """(unit name, {kind: (covered, total)}) for one source's XML, or None."""
    root = ET.parse(path).getroot()
    if root.tag != "source":
        return None
    scope = root.find("scope_metric")
    if scope is None:
        return None
    stats = {}
    for ob in scope.findall("obligation_stats"):
        m = {e.get("kind"): int(e.get("count")) for e in ob.findall("metric")}
        stats[ob.get("kind")] = (m.get("fully_covered", 0),
                                 m.get("total_obligations_of_relevance", 0))
    return scope.get("scope_name"), stats


def cell(covered, total):
    """"covered/total (pct%)", or "-" when there is nothing to cover."""
    if total == 0:
        return "-"
    return "%d/%d (%d%%)" % (covered, total, 100 * covered // total)


def main(argv):
    if len(argv) != 2 or not os.path.isdir(argv[1]):
        sys.exit("usage: coverage-summary.py XML_DIR")
    units = {}
    for name in sorted(os.listdir(argv[1])):
        if not name.endswith((".ads.xml", ".adb.xml")):
            continue
        got = file_stats(os.path.join(argv[1], name))
        if got is None:
            continue
        unit, stats = got
        acc = units.setdefault(unit, {k: [0, 0] for k in KINDS})
        for k in KINDS:
            c, t = stats.get(k, (0, 0))
            acc[k][0] += c
            acc[k][1] += t
    if not units:
        sys.exit("coverage-summary.py: no source XML in %s" % argv[1])
    width = max(len(u) for u in units)
    head = "%-*s  %-16s  %-16s  %-16s" % (width, "unit", "statement", "decision", "MC/DC")
    print(head)
    print("-" * len(head))
    total = {k: [0, 0] for k in KINDS}
    for unit in sorted(units):
        row = units[unit]
        print("%-*s  %-16s  %-16s  %-16s" % (
            width, unit, *(cell(*row[k]) for k in KINDS)))
        for k in KINDS:
            total[k][0] += row[k][0]
            total[k][1] += row[k][1]
    print("-" * len(head))
    print("%-*s  %-16s  %-16s  %-16s" % (
        width, "total", *(cell(*total[k]) for k in KINDS)))


if __name__ == "__main__":
    main(sys.argv)
