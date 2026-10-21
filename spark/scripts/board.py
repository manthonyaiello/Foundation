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
  scripts/board-rows.txt       the rows: function -> spec entity, impl entity,
                               and the row's kind (#67)
  obj/ffi/ffi-results.txt      the FFI log written by scripts/check-ffi.sh
                               (M0.3); "not run" while it does not exist
  scripts/proof-slow.txt       the units proved on demand: their recorded
                               proofs, checked against their fingerprints
                               (README "Slow proofs")
  saw/results.txt              the record of the last default SAW run
  saw/results-long.txt         (scripts/check-saw.sh, local only) and of
                               the last SAW_LONG=1 run: what SAW proved,
                               at which commit, and the hashes of the
                               sources and Cryptol it read, which say
                               whether the record is still this tree's

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
  scripts/board.py --rows F --ffi-log F --saw F --saw-long F --root DIR
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

#: Row kinds (board-rows.txt's fourth field; README "The board"). The
#: first two have an implementation entity; the last two have none, by
#: design, and are complete when what covers them is.
KINDS = ["impl", "impl = spec", "spec-only", "subsumed-by"]

#: The SAW records, relative to the crate (scripts/check-saw.sh).
SAW_RESULTS = "saw/results.txt"
SAW_RESULTS_LONG = "saw/results-long.txt"

#: What SAW reads besides the hashed sources and Cryptol: the scripts and
#: check-saw.sh. A change to one since the recorded commit makes the record
#: stale too. Relative to the crate; the results files themselves excluded.
SAW_SCRIPTS = ["saw", "scripts/check-saw.sh", "scripts/toolchain-pins.env"]


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


def slow_units(root):
    """{unit: its proof-slow.txt record}, with whether its fingerprint is current.

    A slow unit is proved on demand (scripts/prove-slow.sh), not by the
    default gate, so the board reports its recorded proof, not a .spark file
    (README "Slow proofs"). "current" is None when the fingerprint cannot be
    computed here (no gnatprove for its version lines).
    """
    sys.dont_write_bytecode = True  # no __pycache__ in scripts/
    import slow_proofs  # scripts/slow_proofs.py, beside this file
    try:
        entries = slow_proofs.read_manifest(slow_proofs.manifest_path(root))
    except slow_proofs.ManifestError as e:
        print("board.py: %s" % e, file=sys.stderr)
        return {}
    try:
        tools = slow_proofs.tool_versions(root)
    except slow_proofs.ManifestError:
        tools = None
    out = {}
    for rel, e in entries:
        unit = os.path.splitext(os.path.basename(rel))[0]
        current = None
        if tools is not None:
            try:
                cur, _ = slow_proofs.compute_inputs(root, rel, tools=tools)
                current = slow_proofs.fingerprint(cur) == e["fingerprint"]
            except slow_proofs.ManifestError:
                current = False
        out[unit] = {"file": rel, "commit": e["commit"], "date": e["date"],
                     "level": e["level"], "checks": e["checks"], "current": current,
                     "name": unit.replace("-", ".").lower()}
    return out


def slow_unit_of(slow, name):
    """The slow unit that declares entity NAME (by its qualified name), or None."""
    n = name.lower()
    for unit, s in slow.items():
        if n == s["name"] or n.startswith(s["name"] + "."):
            return unit
    return None


def slow_cell(slow, unit, name):
    """A row's cell for an entity of a slow unit: its recorded proof."""
    s = slow[unit]
    return {"entity": name, "found": True, "unit": unit, "slow": s,
            "level": s["level"], "analyzed": True, "checks": None,
            "unit_checks": None, "unit_holes": None, "unit_output": "slow"}


def parse_kind(field, impl_name):
    """A row's kind from board-rows.txt's fourth field ("" for the default).

    Returns {"kind", "covers", "error"}: COVERS is the entities a
    spec-only row names, or the function a subsumed-by row names.
    """
    s = " ".join(field.split())
    kind = next((k for k in sorted(KINDS, key=len, reverse=True)
                 if s == k or s.startswith(k + " ")), None) if s else "impl"
    if kind is None:
        return {"kind": s, "covers": None, "error": "unknown kind `%s`" % s}
    arg = s[len(kind):].strip() if s else ""
    rec = {"kind": kind, "covers": None, "error": None}
    has_impl = impl_name not in ("", "-")
    if kind in ("impl", "impl = spec"):
        if arg:
            rec["error"] = "kind `%s` takes no argument" % kind
        elif not has_impl:
            rec["error"] = "kind `%s` needs an impl entity" % kind
    elif has_impl:
        rec["error"] = "kind `%s` has no impl entity (`-`)" % kind
    elif not arg:
        rec["error"] = "kind `%s` needs %s" % (
            kind, "the entities that cover it" if kind == "spec-only" else "a function")
    else:
        rec["covers"] = arg.split() if kind == "spec-only" else arg
    return rec


def sha256_file(path):
    """The full sha256 hex digest of a file, or None if it does not exist."""
    import hashlib
    try:
        with open(path, "rb") as f:
            return hashlib.sha256(f.read()).hexdigest()
    except OSError:
        return None


def saw_name_parts(name):
    """A SAW result's subprogram name as lower-case parts.

    The implementation's results name it with dots (sha256_stream.hash), the
    spec layer's with the symbol's double underscores (cipher__subbytes).
    """
    return [p for p in re.split(r"__|\.", name.lower()) if p]


def read_saw(root, rel):
    """Read a SAW record (saw/results.txt) into a dictionary, or None if absent.

    Each "proved" line is one result, or N when it says "(N proofs"; a
    "spec layer:" line is of the spec layer, any other of the
    implementation; "(lax arithmetic module)" marks a lax-arithmetic result.
    The "source" and "cryptol" lines' hashes are compared with the files as
    they are now, and the SAW scripts with the recorded commit's (git), to
    say whether the record is still this tree's.
    """
    path = os.path.join(root, rel)
    if not os.path.exists(path):
        return None
    rec = {"file": rel, "commit": "", "date": "", "options": "", "results": [],
           "inputs": 0, "changed": [], "scripts_checked": False}
    top = git(root, "rev-parse", "--show-toplevel") or os.path.dirname(root)
    with open(path, encoding="utf-8") as f:
        for line in f:
            s = line.rstrip("\n")
            key, _, val = s.partition(" ")
            val = val.strip()
            if key in ("commit", "date", "options") and not rec[key]:
                rec[key] = val
            elif key == "proved":
                layer = "impl"
                if val.startswith("spec layer:"):
                    layer, val = "spec", val[len("spec layer:"):].strip()
                n = re.search(r"\((\d+) proofs", val)
                rec["results"].append({
                    "layer": layer,
                    "name": val.split()[0] if val else "",
                    "lax": "(lax arithmetic module)" in val.split(" = ", 1)[0],
                    "count": int(n.group(1)) if n else 1,
                })
            elif key in ("source", "cryptol", "spec.adc"):
                m = re.match(r"^([0-9a-f]{64}) (\S+)", val)
                if not m:
                    continue  # the version line "cryptol Cryptol 3.6.0 ..."
                digest, f_rel = m.group(1), m.group(2).rstrip(":")
                base = top if key == "cryptol" else root
                rec["inputs"] += 1
                if sha256_file(os.path.join(base, f_rel)) != digest:
                    rec["changed"].append(f_rel)
    # The scripts are not hashed in the record: compare them with the
    # recorded commit's, when this checkout has it.
    if rec["commit"] and git(root, "cat-file", "-t", rec["commit"]) == "commit":
        rec["scripts_checked"] = True
        out = git(root, "diff", "--name-only", rec["commit"], "--", *SAW_SCRIPTS,
                  ":!saw/results.txt", ":!saw/results-long.txt")
        prefix = git(root, "rev-parse", "--show-prefix")
        for p in out.splitlines():
            p = p[len(prefix):] if prefix and p.startswith(prefix) else p
            if p not in rec["changed"]:
                rec["changed"].append(p)
    rec["stale"] = bool(rec["changed"])
    return rec


def saw_totals(rec):
    """Count a SAW record's results: in all, per layer, and the lax ones."""
    t = {"proved": 0, "lax": 0, "impl": 0, "impl_lax": 0, "spec": 0, "spec_lax": 0}
    for r in rec["results"]:
        t["proved"] += r["count"]
        t[r["layer"]] += r["count"]
        if r["lax"]:
            t["lax"] += r["count"]
            t[r["layer"] + "_lax"] += r["count"]
    return t


def saw_cell(rec, layer, entity):
    """The results of LAYER ("spec" or "impl") whose subprogram is ENTITY.

    A result matches when its name's parts are the last parts of the
    entity's qualified name (sha256_stream.hash is ...SHA2.SHA256_Stream.Hash).
    An AES.Spec.Dispatch entity (#80) is never proved by SAW itself: it
    selects an instance of AES_K by K, and gnatprove proves it is each
    instance's function. Its results are the instances' (AES128, AES192,
    AES256) of the same name, one per key size.
    """
    if rec is None or entity in (None, "", "-"):
        return None
    want = entity.lower().split(".")
    wants = [want]
    if len(want) >= 2 and want[-2] == "dispatch":
        wants = [want[:-2] + [k, want[-1]] for k in ("aes128", "aes192", "aes256")]
    c = {"proved": 0, "lax": 0}
    for r in rec["results"]:
        parts = saw_name_parts(r["name"])
        if r["layer"] == layer and parts and any(w[-len(parts):] == parts for w in wants):
            c["proved"] += r["count"]
            c["lax"] += r["count"] if r["lax"] else 0
    return c


def build(args):
    """Assemble the whole board as one JSON-ready dictionary."""
    root = args.root
    units = tracked_units(root)
    slow = slow_units(root)
    # A slow unit's .spark, if one is on disk, is not the default gate's: its
    # recorded proof is reported instead.
    spark = {u: v for u, v in read_spark(root).items() if u not in slow}
    manifest = [(f[0], f[1]) for _, f in table_lines(os.path.join(root, args.manifest))
                if len(f) >= 2]
    urows = unit_rows(root, units, spark, manifest)
    for u in urows:
        if u["unit"] in slow:
            u.update(output="slow", slow=slow[u["unit"]])
    by_name = {u["unit"]: u for u in urows}
    ffi = read_ffi(os.path.join(root, args.ffi_log))
    saw = read_saw(root, args.saw)
    saw_long = read_saw(root, args.saw_long)
    head = git(root, "rev-parse", "HEAD")

    def cell_of(name):
        su = slow_unit_of(slow, name) if name not in ("", "-") else None
        return slow_cell(slow, su, name) if su else entity_cell(spark, by_name, name)

    def proved(cell):
        if cell.get("slow"):
            return cell["slow"]["current"] is True
        return bool(cell.get("found") and cell.get("analyzed")
                    and cell["checks"]["unproved"] == 0
                    and cell["unit_checks"]["unproved"] == 0)

    rows = []
    for n, f in table_lines(os.path.join(root, args.rows)):
        if len(f) not in (3, 4):
            print("board.py: %s:%d: expected 3 or 4 fields, skipped" % (args.rows, n),
                  file=sys.stderr)
            continue
        kind = parse_kind(f[3] if len(f) == 4 else "", f[2])
        if kind["kind"] == "impl = spec" and f[1] != f[2]:
            kind["error"] = "kind `impl = spec` but the impl entity is not the spec entity"
        if kind["error"]:
            print("board.py: %s:%d: %s" % (args.rows, n, kind["error"]), file=sys.stderr)
        spec, impl = cell_of(f[1]), cell_of(f[2])
        props = None if ffi is None else ffi.get(f[0], [])
        ffi_ok = bool(props) and all(p["passed"] == p["run"] > 0 for p in props)
        if kind["kind"] == "spec-only" and kind["covers"]:
            covers = [cell_of(e) for e in kind["covers"]]
            holes = holes_of([spec] + covers)
            # Covered by proofs, not by an implementation of its own: the
            # spec's unit is proved, and so is each entity that covers it.
            # No FFI property is needed (PLAN: "Spec and implementation need
            # not be one-to-one"); one that exists must pass.
            impl_proved = all(proved(c) for c in covers)
            ffi_cond = ffi_ok or (props is not None and not props)
            spec_ok = bool(spec.get("found") and spec.get("analyzed")
                           and (spec["unit_checks"] or {}).get("unproved", 0) == 0)
        elif kind["kind"] == "subsumed-by" and kind["covers"]:
            covers = []
            holes = holes_of([spec])
            impl_proved = None  # settled below, from the row it names
            ffi_cond = ffi_ok
            spec_ok = bool(spec.get("found"))
        else:
            covers = None
            holes = holes_of([spec, impl])
            impl_proved = proved(impl)
            ffi_cond = ffi_ok
            spec_ok = bool(spec.get("found"))
        rows.append({
            "function": f[0],
            "kind": kind["kind"],
            "kind_error": kind["error"],
            "covered_by": kind["covers"],
            "covers": covers,
            "spec": spec,
            "impl": impl,
            "ffi": props,
            "ffi_checked": ffi_ok,
            "impl_proved": impl_proved,
            "saw": None if saw is None else {
                "spec": saw_cell(saw, "spec", f[1]),
                "impl": saw_cell(saw, "impl", f[2]),
                "stale": saw["stale"],
            },
            "holes": holes,
            # PLAN: complete = spec exists and FFI-checked, impl proved with
            # zero unproved, assumptions and justifications. A spec-only or
            # subsumed-by row is complete when what covers it is (#67).
            "complete": bool(not kind["error"] and spec_ok and ffi_cond and impl_proved
                             and holes["assume"] == 0 and holes["justification"] == 0
                             and holes["unproved"] == 0),
            "by_design": kind["kind"] in ("spec-only", "subsumed-by"),
        })
    # A subsumed-by row is complete when the row it names is.
    by_function = {r["function"]: r for r in rows}
    for r in rows:
        if r["kind"] == "subsumed-by" and not r["kind_error"]:
            target = by_function.get(r["covered_by"])
            if target is None or target["kind"] == "subsumed-by":
                r["kind_error"] = "subsumed-by names `%s`, which is not an impl row" % r["covered_by"]
                print("board.py: %s: %s" % (args.rows, r["kind_error"]), file=sys.stderr)
            r["impl_proved"] = bool(target and not r["kind_error"] and target["complete"])
            r["complete"] = bool(not r["kind_error"] and r["spec"].get("found")
                                 and r["ffi_checked"] and r["impl_proved"]
                                 and r["holes"]["assume"] == 0
                                 and r["holes"]["justification"] == 0
                                 and r["holes"]["unproved"] == 0)

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
        "saw": [dict({k: v for k, v in s.items() if k != "results"}, totals=saw_totals(s))
                for s in (saw, saw_long) if s is not None],
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


def fmt_slow(s):
    """A slow unit's recorded proof, or STALE when its fingerprint changed."""
    at = "proved at %s (on demand)" % s["commit"][:7]
    if s["current"] is False:
        return "**STALE** (slow: %s; its inputs changed since)" % at
    if s["current"] is None:
        return "slow: %s; fingerprint not checked (no gnatprove)" % at
    return "slow: %s" % at


def fmt_entity(cell, head):
    """The spec or impl cell of a function row."""
    if cell.get("slow"):
        return fmt_slow(cell["slow"])
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


def fmt_kind(r):
    """The kind cell of a function row."""
    if r["kind_error"]:
        return "**%s** (%s)" % (r["kind"], r["kind_error"])
    if r["kind"] == "subsumed-by":
        return "subsumed by `%s`" % r["covered_by"]
    return r["kind"]


def fmt_impl(r, head):
    """The impl-proved cell: the impl entity, or what covers a row without one."""
    if r["kind"] == "spec-only" and r["covers"]:
        return "none by design; covered by " + ", ".join(
            "`%s` %s" % (c["entity"].rsplit(".", 1)[-1], fmt_entity(c, head))
            for c in r["covers"])
    if r["kind"] == "subsumed-by" and not r["kind_error"]:
        return "none by design; proved within `%s`'s (%s)" % (
            r["covered_by"], "complete" if r["impl_proved"] else "**not complete**")
    return fmt_entity(r["impl"], head)


def fmt_saw_count(c):
    """One layer's SAW results for a row: the count, and how many are lax."""
    if c is None:
        return None
    if not c["proved"]:
        return "-"
    return "%d%s" % (c["proved"], " (%d lax)" % c["lax"] if c["lax"] else "")


def fmt_saw(r):
    """The SAW cell of a function row: spec-layer and implementation results."""
    s = r["saw"]
    if s is None:
        return "not run"
    parts = ["spec %s" % fmt_saw_count(s["spec"])]
    impl = fmt_saw_count(s["impl"])
    if impl is not None:
        parts.append("impl %s" % impl)
    return ", ".join(parts) + (" (stale)" if s["stale"] else "")


def fmt_saw_record(s):
    """A sentence on one SAW record: where it was run, what it proved, and
    whether it is still this tree's."""
    t = s["totals"]
    out = ("`%s` (%s), recorded at %s on %s: %d proved, %d of the implementation "
           "(%d lax) and %d of the spec layer (%d lax)"
           % (s["file"], s["options"].split(":")[0] or "options not recorded",
              s["commit"][:7] or "?", s["date"][:10] or "?", t["proved"], t["impl"],
              t["impl_lax"], t["spec"], t["spec_lax"]))
    if s["stale"]:
        shown = ", ".join("`%s`" % c for c in s["changed"][:6])
        more = len(s["changed"]) - 6
        out += ("; **STALE**: %d of SAW's inputs changed since (%s%s), so these results "
                "are not this tree's until `check-saw.sh` is run again (GNAT Pro)"
                % (len(s["changed"]), shown, ", and %d more" % more if more > 0 else ""))
    else:
        out += "; current: none of its %d hashed inputs changed" % s["inputs"]
        if s["scripts_checked"]:
            out += ", nor the SAW scripts since %s" % s["commit"][:7]
        else:
            out += " (the SAW scripts not checked: %s is not in this checkout)" % s["commit"][:7]
    return out


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
           "Counted by `spark/scripts/board.py` at %s. FFI log: %s. SAW: %s."
           % (b["generated"], "`%s`" % b["ffi_log"] if b["ffi_log"] else "not run",
              ("**STALE** record (below)" if any(s["stale"] for s in b["saw"])
               else "recorded (below)") if b["saw"] else "not run"),
           ""]
    if b["rows"]:
        out += ["| function | kind | spec | FFI-checked | impl proved | SAW | holes | complete |",
                "|---|---|---|---|---|---|---|---|"]
        for r in b["rows"]:
            ffi = fmt_ffi(r["ffi"], head)
            if r["kind"] == "spec-only" and r["ffi"] == []:
                ffi = "not required"
            out.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % (
                r["function"], fmt_kind(r), fmt_entity(r["spec"], head), ffi,
                fmt_impl(r, head), fmt_saw(r), fmt_holes(r["holes"]),
                ("yes, by design" if r["by_design"] else "yes") if r["complete"] else "no"))
        done = [r for r in b["rows"] if r["complete"]]
        design = [r["function"] for r in done if r["by_design"]]
        out += ["", "%d of %d functions complete%s. *kind*: `impl`, an implementation "
                "entity proved equal to the spec; `impl = spec`, the spec function is "
                "executable and is the implementation; `spec-only`, no implementation "
                "by design, complete when the proofs it names are; `subsumed by`, no "
                "implementation by design, complete when the row it names is (README "
                "\"Where spec and implementation are not one-to-one\"). *spec*, *impl "
                "proved*: the unit's committed level, then the entity's own checks "
                "proved/total (its unit's are below). *SAW*: the default run's results "
                "whose subprogram is the row's spec entity (spec) or impl entity "
                "(impl), and how many are in the lax-arithmetic module; `-` for none. "
                "*holes*: unproved checks and trust-manifest entries in the spec and "
                "impl units (and, for `spec-only`, the units of the proofs it names)."
                % (len(done), len(b["rows"]),
                   " (%d by design: %s)" % (len(design), ", ".join("`%s`" % d for d in design))
                   if design else ""), ""]
        if b["saw"]:
            out += ["SAW (local only, GNAT Pro; `scripts/check-saw.sh`):", ""]
            out += ["- " + fmt_saw_record(s) + "." for s in b["saw"]]
            if any(r["saw"] for r in b["rows"]):
                spec_rows = sum(1 for r in b["rows"] if r["saw"]["spec"]["proved"])
                with_impl = [r for r in b["rows"] if r["saw"]["impl"] is not None]
                impl_rows = sum(1 for r in with_impl if r["saw"]["impl"]["proved"])
                out += ["- The default run has a result of its own for the spec entity "
                        "of %d of %d rows, and for the impl entity of %d of the %d rows "
                        "that have one. README \"SAW\" says what the others are proved "
                        "within, and why." % (spec_rows, len(b["rows"]), impl_rows,
                                              len(with_impl))]
            out += [""]
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
        s = u.get("slow")
        out.append("| " + " | ".join(
            ["`%s`" % u["unit"], str(u["level"]), ents,
             "%s (recorded)" % s["checks"] if s else fmt_checks(c),
             "-" if c is None else str(c["unproved"])]
            + [str(u["holes"][k]) for k in HOLE_KINDS]
            + [fmt_slow(s) if s else u["output"]]) + " |")
    t = b["totals"]
    out += ["", "Totals: %d units, %d checks: %d proved, %d justified, %d unproved. "
            "Holes: %s." % (t["units"], t["checks"], t["proved"], t["justified"],
                            t["unproved"],
                            ", ".join("%d %s" % (t[k], HOLE_TITLES[k]) for k in HOLE_KINDS))]
    slow = [u for u in b["units"] if u.get("slow")]
    if slow:
        out += ["", "Slow units (proved on demand by `scripts/prove-slow.sh`, not by the "
                "default gate; not in the totals above): " + "; ".join(
                    "`%s` %s checks, %s" % (u["unit"], u["slow"]["checks"], fmt_slow(u["slow"]))
                    for u in slow) + "."]
    return "\n".join(out) + "\n"


def main():
    """Parse the arguments, build the board, print it."""
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=here, help="the crate (default: spark/)")
    ap.add_argument("--rows", default="scripts/board-rows.txt")
    ap.add_argument("--manifest", default="scripts/trust-surface.txt")
    ap.add_argument("--ffi-log", default="obj/ffi/ffi-results.txt")
    ap.add_argument("--saw", default=SAW_RESULTS, help="the default SAW run's record")
    ap.add_argument("--saw-long", default=SAW_RESULTS_LONG, help="the SAW_LONG=1 run's record")
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
