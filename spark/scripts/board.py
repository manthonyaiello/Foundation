#!/usr/bin/env python3
"""board.py -- count the campaign's board from what is on disk (issue #5).

The PLAN's board says, per function, how far along it is: does the spec
exist, is it checked against the Cryptol (FFI), is its implementation proved,
and (E4) does SAW prove it. This script counts that board instead of
remembering it. It reads, relative to spark/:

  obj/*/gnatprove/*.spark      gnatprove's per-unit results, as written by the
                               last scripts/prove.sh run (one per unit)
  foundation_spark.gpr         each unit's committed level (package Prove)
  scripts/trust-surface.txt    the trust manifest: every site gnatprove does
                               not prove (the trust gate keeps it exact)
  scripts/board-rows.txt       the rows: function -> spec entity, impl entity
  obj/ffi/ffi-results.txt      the FFI log written by scripts/check-ffi.sh
                               (M0.3); "not run" while it does not exist

and prints the board as markdown (default) or JSON. Python 3 standard library
only. The formats of board-rows.txt and the FFI log are in spark/README.md
("The board").

It reports; it does not gate. The gates are check-trust-surface.sh and
check-proof.sh. A unit whose .spark is missing, or older than one of its
source files, is marked so: its numbers are not this tree's.

Usage:
  scripts/board.py                    # markdown on stdout
  scripts/board.py --json             # JSON on stdout
  scripts/board.py --json-out F       # markdown on stdout, JSON into F
  scripts/board.py --rows F --ffi-log F --root DIR
"""

import argparse
import datetime
import glob
import json
import os
import re
import subprocess
import sys

#: Manifest kinds, in the order the board prints them (check-trust-surface.sh).
HOLE_KINDS = [
    "assume",
    "justification",
    "spark-mode-off",
    "warning-off",
    "check-suppressed",
    "foreign-binding",
]

#: Column titles for the hole kinds.
HOLE_TITLES = {
    "assume": "assumes",
    "justification": "justifications",
    "spark-mode-off": "SPARK_Mode Off",
    "warning-off": "warning suppressions",
    "check-suppressed": "check suppressions",
    "foreign-binding": "foreign bindings",
}

#: gnatprove severities that mean "this check is not proved".
UNPROVED_SEVERITIES = {"low", "medium", "high", "error"}


def git(root, *args):
    """Run git in ROOT and return its stdout stripped, or "" on failure."""
    try:
        return subprocess.run(
            ["git", "-C", root, *args],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def table_lines(path):
    """Yield the fields of each non-comment, non-blank line of a |-table."""
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            yield n, [x.strip() for x in s.split("|")]


def tracked_units(root):
    """Map each unit under src/ (file base name) to its tracked source files."""
    out = git(root, "ls-files", "--", "src")
    files = [p for p in out.splitlines() if re.search(r"\.(ads|adb)$", p)]
    if not files:  # not a git checkout: fall back to the tree
        for d, _, names in os.walk(os.path.join(root, "src")):
            files += [os.path.relpath(os.path.join(d, n), root)
                      for n in names if re.search(r"\.(ads|adb)$", n)]
    units = {}
    for p in sorted(files):
        units.setdefault(os.path.splitext(os.path.basename(p))[0], []).append(p)
    return units


def gpr_levels(root):
    """Return (default level, {file name: level}) from the GPR's Prove package.

    A Proof_Switches entry names one of the package's Level_N lists
    (scripts/prove.sh refuses a literal --level), so the level is the N.
    """
    with open(os.path.join(root, "foundation_spark.gpr"), encoding="utf-8") as f:
        text = "\n".join(re.sub(r"(^|\s)--.*$", "", ln) for ln in f.read().splitlines())
    default, per_file = None, {}
    for m in re.finditer(r'for\s+Proof_Switches\s*\(\s*"([^"]+)"\s*\)\s*use\s+([^;]*);',
                         text, re.IGNORECASE):
        lv = re.search(r"Level_(\d)", m.group(2))
        if not lv:
            continue
        if m.group(1).lower() == "ada":
            default = int(lv.group(1))
        else:
            per_file[m.group(1).lower()] = int(lv.group(1))
    return default, per_file


def read_spark(root):
    """Load every obj/*/gnatprove/*.spark, the newest per unit."""
    found = {}
    for p in glob.glob(os.path.join(root, "obj", "*", "gnatprove", "*.spark")):
        unit = os.path.splitext(os.path.basename(p))[0]
        if unit not in found or os.path.getmtime(p) > os.path.getmtime(found[unit]):
            found[unit] = p
    data = {}
    for unit, p in found.items():
        with open(p, encoding="utf-8") as f:
            data[unit] = (p, json.load(f))
    return data


def count_checks(entries, entity_ids=None):
    """Count proved / justified / unproved checks among .spark entries.

    Only entries of ENTITY_IDS when given. Warnings are not checks.
    """
    c = {"proved": 0, "flow": 0, "provers": 0, "justified": 0, "unproved": 0}
    for kind, e in entries:
        if entity_ids is not None and e.get("entity") not in entity_ids:
            continue
        sev = e.get("severity")
        if "suppressed" in e:
            c["justified"] += 1
        elif sev == "info":
            c["proved"] += 1
            c["flow" if kind == "flow" else "provers"] += 1
        elif sev in UNPROVED_SEVERITIES:
            c["unproved"] += 1
    c["total"] = c["proved"] + c["justified"] + c["unproved"]
    return c


def spark_entries(doc):
    """The (kind, entry) pairs of a .spark document's flow and proof results."""
    return [("flow", e) for e in doc.get("flow", [])] + \
           [("proof", e) for e in doc.get("proof", [])]


def unit_rows(root, units, spark, manifest):
    """Build one record per tracked unit."""
    default, per_file = gpr_levels(root)
    out = []
    for unit, files in sorted(units.items()):
        names = [os.path.basename(p).lower() for p in files]
        levels = [per_file[n] for n in names if n in per_file]
        rec = {
            "unit": unit,
            "files": files,
            "level": max(levels) if levels else default,
            "holes": {k: 0 for k in HOLE_KINDS},
        }
        for kind, path in manifest:
            if path in files:
                rec["holes"][kind] = rec["holes"].get(kind, 0) + 1
        if unit not in spark:
            rec.update(output="missing", entities=None, checks=None, pragma_assume=None)
            out.append(rec)
            continue
        path, doc = spark[unit]
        newest_src = max(os.path.getmtime(os.path.join(root, p)) for p in files)
        status = doc.get("spark", {})
        rec.update(
            output="stale" if newest_src > os.path.getmtime(path) else "fresh",
            entities={
                "total": len(status),
                "analyzed": sum(1 for v in status.values() if v != "no"),
                "skipped": sorted(doc["entities"][k]["name"]
                                  for k, v in status.items() if v == "no"
                                  and k in doc.get("entities", {})),
            },
            checks=count_checks(spark_entries(doc)),
            pragma_assume=len(doc.get("pragma_assume", [])),
        )
        out.append(rec)
    return out


def find_entity(spark, name):
    """Locate entity NAME (case-insensitive) in the .spark files.

    Returns (unit, entity-id set, analyzed?) or None.
    """
    want = name.lower()
    for unit, (_, doc) in sorted(spark.items()):
        # A .spark file's "entities" also names entities its unit only
        # refers to (a shim's callee in another unit). The unit that
        # declares an entity is the one whose "spark" map has a status for
        # it, so only those ids count (#4).
        status = doc.get("spark", {})
        ids = {int(k) for k, v in doc.get("entities", {}).items()
               if v.get("name", "").lower() == want
               and (k in status or k.strip() in status)}
        if ids:
            analyzed = all(status.get(" %d" % i, status.get(str(i))) != "no" for i in ids)
            return unit, ids, analyzed
    return None


def read_ffi(path):
    """Read the FFI log into {function: [property records]}, or None if absent."""
    if not os.path.exists(path):
        return None
    out = {}
    for n, f in table_lines(path):
        if len(f) != 6 or f[2] not in ("exhaust", "check") \
                or not f[3].isdigit() or not f[4].isdigit():
            print("board.py: %s:%d: malformed FFI log line, skipped" % (path, n),
                  file=sys.stderr)
            continue
        out.setdefault(f[1], []).append({
            "property": f[0], "function": f[1], "mode": f[2],
            "run": int(f[3]), "passed": int(f[4]), "commit": f[5],
        })
    return out


def entity_cell(spark, units_by_name, name):
    """Describe one row entity (spec or impl): where it is, and its checks."""
    if name in ("", "-"):
        return {"entity": None, "found": False}
    hit = find_entity(spark, name)
    if hit is None:
        return {"entity": name, "found": False}
    unit, ids, analyzed = hit
    _, doc = spark[unit]
    u = units_by_name.get(unit, {})
    return {
        "entity": name,
        "found": True,
        "unit": unit,
        "level": u.get("level"),
        "analyzed": analyzed,
        "checks": count_checks(spark_entries(doc), ids),
        "unit_checks": u.get("checks"),
        "unit_holes": u.get("holes"),
        "unit_output": u.get("output"),
    }


def holes_of(cells):
    """Sum unproved checks and manifest holes over the units of CELLS."""
    seen, h = set(), {"unproved": 0, **{k: 0 for k in HOLE_KINDS}}
    for c in cells:
        if not c.get("found") or c["unit"] in seen:
            continue
        seen.add(c["unit"])
        h["unproved"] += (c["unit_checks"] or {}).get("unproved", 0)
        for k in HOLE_KINDS:
            h[k] += (c["unit_holes"] or {}).get(k, 0)
    return h


def build(args):
    """Assemble the whole board as one JSON-ready dictionary."""
    root = args.root
    units = tracked_units(root)
    spark = read_spark(root)
    manifest = [(f[0], f[1]) for _, f in table_lines(os.path.join(root, args.manifest))
                if len(f) >= 2]
    urows = unit_rows(root, units, spark, manifest)
    by_name = {u["unit"]: u for u in urows}
    ffi = read_ffi(os.path.join(root, args.ffi_log))
    head = git(root, "rev-parse", "HEAD")

    rows = []
    for _, f in table_lines(os.path.join(root, args.rows)):
        if len(f) != 3:
            continue
        spec = entity_cell(spark, by_name, f[1])
        impl = entity_cell(spark, by_name, f[2])
        props = None if ffi is None else ffi.get(f[0], [])
        holes = holes_of([spec, impl])
        impl_proved = bool(impl.get("found") and impl.get("analyzed")
                           and impl["checks"]["unproved"] == 0
                           and impl["unit_checks"]["unproved"] == 0)
        ffi_ok = bool(props) and all(p["passed"] == p["run"] > 0 for p in props)
        rows.append({
            "function": f[0],
            "spec": spec,
            "impl": impl,
            "ffi": props,
            "ffi_checked": ffi_ok,
            "impl_proved": impl_proved,
            "saw": None,
            "holes": holes,
            # PLAN: complete = spec exists and FFI-checked, impl proved with
            # zero unproved, assumptions and justifications, and (E4) SAW.
            "complete": bool(spec.get("found") and ffi_ok and impl_proved
                             and holes["assume"] == 0 and holes["justification"] == 0
                             and holes["unproved"] == 0),
        })

    totals = {"units": len(urows), "checks": 0, "proved": 0, "justified": 0,
              "unproved": 0, **{k: 0 for k in HOLE_KINDS}}
    for u in urows:
        for k in ("proved", "justified", "unproved"):
            totals[k] += (u["checks"] or {}).get(k, 0)
        totals["checks"] += (u["checks"] or {}).get("total", 0)
        for k in HOLE_KINDS:
            totals[k] += u["holes"][k]

    return {
        "commit": head,
        "dirty": bool(git(root, "status", "--porcelain", "--", ".")),
        "generated": datetime.datetime.now(datetime.timezone.utc)
                     .strftime("%Y-%m-%dT%H:%M:%SZ"),
        "ffi_log": args.ffi_log if ffi is not None else None,
        "units": urows,
        "rows": rows,
        "totals": totals,
    }


def fmt_checks(c):
    """'proved/total' plus the justified and unproved counts when non-zero."""
    if c is None:
        return "-"
    s = "%d/%d" % (c["proved"], c["total"])
    if c["justified"]:
        s += ", %d justified" % c["justified"]
    if c["unproved"]:
        s += ", **%d unproved**" % c["unproved"]
    return s


def fmt_entity(cell, head):
    """The spec or impl cell of a function row."""
    if cell["entity"] is None:
        return "not yet"
    if not cell["found"]:
        return "no (`%s` not in any .spark)" % cell["entity"].rsplit(".", 1)[-1]
    if not cell["analyzed"]:
        return "**skipped** (%s)" % cell["unit"]
    s = "L%s, %s" % (cell["level"], fmt_checks(cell["checks"]))
    if cell["unit_output"] != "fresh":
        s += " (%s)" % cell["unit_output"]
    return s


def fmt_ffi(props, head):
    """The FFI-checked cell of a function row."""
    if props is None:
        return "not run"
    if not props:
        return "no property"
    parts = []
    for p in props:
        s = ":%s %d/%d" % (p["mode"], p["passed"], p["run"])
        if p["passed"] != p["run"]:
            s = "**FAIL** " + s
        if head and not head.startswith(p["commit"]) and not p["commit"].startswith(head[:7]):
            s += " @%s" % p["commit"][:7]
        parts.append(s)
    return "; ".join(parts)


def fmt_holes(h):
    """Every non-zero hole count of a row, or 0."""
    parts = ["%d %s" % (v, "unproved" if k == "unproved" else HOLE_TITLES[k])
             for k, v in h.items() if v]
    return ", ".join(parts) if parts else "0"


def markdown(b):
    """Render the board as markdown."""
    head = b["commit"]
    out = ["## Board at %s%s" % (head[:7] or "?", " (dirty)" if b["dirty"] else ""),
           "",
           "Counted by `spark/scripts/board.py` at %s. FFI log: %s. SAW: not run (E4)."
           % (b["generated"], "`%s`" % b["ffi_log"] if b["ffi_log"] else "not run"),
           ""]
    if b["rows"]:
        out += ["| function | spec | FFI-checked | impl proved | SAW | holes | complete |",
                "|---|---|---|---|---|---|---|"]
        for r in b["rows"]:
            out.append("| %s | %s | %s | %s | %s | %s | %s |" % (
                r["function"], fmt_entity(r["spec"], head), fmt_ffi(r["ffi"], head),
                fmt_entity(r["impl"], head), "not run", fmt_holes(r["holes"]),
                "yes" if r["complete"] else "no"))
        done = sum(1 for r in b["rows"] if r["complete"])
        out += ["", "%d of %d functions complete. *spec*, *impl proved*: the unit's "
                "committed level, then the entity's own checks proved/total (its "
                "unit's are below). *holes*: unproved checks and trust-manifest "
                "entries in the spec and impl units." % (done, len(b["rows"])), ""]
    else:
        out += ["No functions on the board yet (`scripts/board-rows.txt` is empty).", ""]

    cols = ["unit", "level", "entities", "checks proved", "unproved"] + \
           [HOLE_TITLES[k] for k in HOLE_KINDS] + ["output"]
    out += ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    for u in b["units"]:
        e = u["entities"]
        ents = "-" if e is None else "%d/%d" % (e["analyzed"], e["total"])
        if e and e["skipped"]:
            ents += " (**%d skipped**)" % len(e["skipped"])
        c = u["checks"]
        out.append("| " + " | ".join(
            ["`%s`" % u["unit"], str(u["level"]), ents, fmt_checks(c),
             "-" if c is None else str(c["unproved"])]
            + [str(u["holes"][k]) for k in HOLE_KINDS] + [u["output"]]) + " |")
    t = b["totals"]
    out += ["", "Totals: %d units, %d checks: %d proved, %d justified, %d unproved. "
            "Holes: %s." % (t["units"], t["checks"], t["proved"], t["justified"],
                            t["unproved"],
                            ", ".join("%d %s" % (t[k], HOLE_TITLES[k]) for k in HOLE_KINDS))]
    return "\n".join(out) + "\n"


def main():
    """Parse the arguments, build the board, print it."""
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=here, help="the crate (default: spark/)")
    ap.add_argument("--rows", default="scripts/board-rows.txt")
    ap.add_argument("--manifest", default="scripts/trust-surface.txt")
    ap.add_argument("--ffi-log", default="obj/ffi/ffi-results.txt")
    ap.add_argument("--json", action="store_true", help="print JSON, not markdown")
    ap.add_argument("--json-out", metavar="FILE", help="also write the JSON to FILE")
    args = ap.parse_args()

    board = build(args)
    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as f:
            json.dump(board, f, indent=2)
            f.write("\n")
    if args.json:
        json.dump(board, sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        sys.stdout.write(markdown(board))


if __name__ == "__main__":
    main()
