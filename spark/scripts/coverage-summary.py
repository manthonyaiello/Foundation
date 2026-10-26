#!/usr/bin/env python3
"""coverage-summary.py -- the per-unit coverage table of check-coverage.sh.

Reads the per-source XML that `gnatcov coverage --annotate=xml` writes (one
<source> per file, whose first <scope_metric> is the whole unit) and prints,
for each unit of interest (spec and body together), the statement, decision
and MC/DC obligations covered out of those relevant, then the totals.

With --report and --explained, it then lists every violation of gnatcov's
report (report.txt) with the entry of coverage/explained.txt that explains
it, or as UNEXPLAINED, and exits 1 when one is unexplained. An entry is
"file | line text | reason": it matches a violation in that file whose
source line, trimmed, is that text.

Usage: coverage-summary.py XML_DIR [--report REPORT --explained EXPLAINED]
"""

import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET

VIOLATION = re.compile(r"^(\S+\.ad[sb]):(\d+):(\d+): (.*)$")

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


def source_paths(xml_dir):
    """{basename: full path} of the sources the XML report covers."""
    paths = {}
    for name in os.listdir(xml_dir):
        if name.endswith((".ads.xml", ".adb.xml")):
            root = ET.parse(os.path.join(xml_dir, name)).getroot()
            if root.tag == "source" and root.get("file"):
                paths[os.path.basename(root.get("file"))] = root.get("file")
    return paths


def read_explained(path):
    """{(file, line text): reason} from explained.txt."""
    entries = {}
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = [p.strip() for p in line.split(" | ")]
            if len(parts) != 3 or not all(parts):
                sys.exit("%s:%d: expected \"file | line text | reason\"" % (path, n))
            entries[(parts[0], parts[1])] = parts[2]
    return entries


def violations(xml_dir, report, explained):
    """Print each violation with its explanation; return the unexplained count."""
    paths = source_paths(xml_dir)
    entries = read_explained(explained)
    lines_of = {}
    found = []
    with open(report, encoding="utf-8") as f:
        for line in f:
            m = VIOLATION.match(line.rstrip("\n"))
            if m:
                found.append(m.groups())
    unexplained = 0
    used = set()
    print()
    print("violations: %d" % len(found))
    for base, ln, col, what in found:
        if base not in lines_of:
            with open(paths[base], encoding="utf-8") as f:
                lines_of[base] = f.read().splitlines()
        text = lines_of[base][int(ln) - 1].strip()
        reason = entries.get((base, text))
        if reason is None:
            unexplained += 1
            print("  UNEXPLAINED %s:%s:%s: %s" % (base, ln, col, what))
            print("              %s" % text)
        else:
            used.add((base, text))
            print("  explained   %s:%s:%s: %s" % (base, ln, col, what))
            print("              %s" % reason)
    for key in sorted(set(entries) - used):
        print("  (stale entry, matched nothing: %s | %s)" % key)
    print("unexplained: %d" % unexplained)
    return unexplained


def main(argv):
    ap = argparse.ArgumentParser(description="The per-unit coverage table.")
    ap.add_argument("xml_dir")
    ap.add_argument("--report")
    ap.add_argument("--explained")
    args = ap.parse_args(argv[1:])
    if not os.path.isdir(args.xml_dir):
        sys.exit("coverage-summary.py: no directory %s" % args.xml_dir)
    if bool(args.report) != bool(args.explained):
        sys.exit("coverage-summary.py: --report and --explained go together")
    units = {}
    for name in sorted(os.listdir(args.xml_dir)):
        if not name.endswith((".ads.xml", ".adb.xml")):
            continue
        got = file_stats(os.path.join(args.xml_dir, name))
        if got is None:
            continue
        unit, stats = got
        acc = units.setdefault(unit, {k: [0, 0] for k in KINDS})
        for k in KINDS:
            c, t = stats.get(k, (0, 0))
            acc[k][0] += c
            acc[k][1] += t
    if not units:
        sys.exit("coverage-summary.py: no source XML in %s" % args.xml_dir)
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
    if args.report and violations(args.xml_dir, args.report, args.explained):
        sys.exit(1)


if __name__ == "__main__":
    main(sys.argv)
