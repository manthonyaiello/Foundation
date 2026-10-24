#!/usr/bin/env python3
"""mutation.py -- mutation testing of the executable SPARK (#104).

Each mutant of mutation/mutants.txt is a one-line change to an
implementation unit. For each one, this script records what catches it:

  * the FFI column: the mutant's FFI properties (scripts/check-ffi.sh, run
    against a library built from the mutated tree), and, for a survivor of
    those, every property (--full);
  * the proof column: gnatprove on the mutant's units (scripts/prove.sh -u),
    at their committed levels. A failed proof is classified by what the
    provers said: a check with a counterexample, a check without one, a
    check whose every prover attempt ran out of time or steps (a timeout is
    not a refutation), or a flow-analysis error.

Mutants are applied in a scratch copy of the checkout (the TREE), one at a
time, and the pristine file is restored after each, so the checkout this
script lives in is never modified. Results go to TREE/results/.

Usage (from anywhere; the checkout needs `alr -n build` once):

  mutation.py check                      every mutant applies to the sources
  mutation.py list                       the mutants, one per line
  mutation.py setup TREE                 copy the checkout to TREE, build it
  mutation.py saw TREE ID ... [--baseline]
                                         the SAW column (GNAT Pro LLVM, SAW)
  mutation.py ffi TREE [ID ...] [--full] [--baseline]
  mutation.py prove TREE [ID ...] [--baseline]
  mutation.py report TREE                the results table, as Markdown
  mutation.py reclassify TREE            classify the saved proof logs again
  mutation.py diagnose TREE ID ... -- GNATPROVE_ARGS
                                         gnatprove again, directly, with
                                         more time (diagnostic only)
  mutation.py witness TREE ID MODULE EXPR TESTS
                                         one Cryptol :check of EXPR (from
                                         cryptol/MODULE) against the mutant

With no ID, ffi and prove take every mutant without a result yet (--redo:
every mutant). A mutant's properties run one at a time and stop at the
first that fails (its killer); a survivor has passed them all. --baseline runs the column on the unmutated tree: the union
of the mutants' properties, or of their units; it must pass.

Env:
  FFI_JOBS, CRYPTOL, ALR   as for check-ffi.sh (CRYPTOL must report "FFI
                           enabled"); FFI_JOBS also builds the library.
  PROVE_JOBS               gnatprove -j (default: 1). Under the scheduler,
                           SPARK_SCHEDULER_TOKENS is used instead.
  MUTATION_PROVE_WRAP      a command prefix for each proof, word-split, in
                           which {tokens} is passed through, for example
                           "spark-scheduler run --up-to 8 --key hex|mutation
                           --strategy prove --variant spark --level 2 --".
                           The child is then `env PROVE_JOBS={tokens}
                           scripts/prove.sh -u ...`.
  MUTATION_TIMEOUT         seconds before one column's run of one mutant is
                           killed and recorded as a hang (default 3600).
"""

import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import time

SPARK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(SPARK)
DATA = os.path.join(SPARK, "mutation", "mutants.txt")
EXT = "dylib" if sys.platform == "darwin" else "so"


def die(msg):
    sys.stderr.write("mutation.py: %s\n" % msg)
    sys.exit(2)


# --------------------------------------------------------------- the data


class Mutant(object):
    def __init__(self, fields, lineno):
        (self.id, self.file, line, self.old, self.new, ffi, prove,
         self.what) = fields
        self.line = int(line)
        self.ffi = ffi.split()
        self.prove = prove.split()
        self.lineno = lineno


def load():
    """The mutants (in order) and the groups of mutants.txt."""
    groups = {}
    mutants = []
    with open(DATA) as f:
        for n, raw in enumerate(f, 1):
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            m = re.match(r"^group\s+(\S+)\s*=\s*(.*)$", line)
            if m:
                groups[m.group(1)] = m.group(2).split()
                continue
            fields = [x.strip() for x in line.split(" | ")]
            if len(fields) != 8:
                die("%s:%d: %d fields, not 8" % (DATA, n, len(fields)))
            mutants.append(Mutant(fields, n))
    ids = [m.id for m in mutants]
    if len(set(ids)) != len(ids):
        die("duplicate mutant ids")
    return mutants, groups


def expand(names, groups, seen=()):
    out = []
    for x in names:
        if x in groups:
            if x in seen:
                die("group %s includes itself" % x)
            out += expand(groups[x], groups, seen + (x,))
        else:
            out.append(x)
    # Unique, in order.
    res = []
    for x in out:
        if x not in res:
            res.append(x)
    return res


def properties():
    """The property names of cryptol/properties.txt, in order."""
    props = []
    with open(os.path.join(SPARK, "cryptol", "properties.txt")) as f:
        for line in f:
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            props.append(line.split("|")[1].strip())
    return props


def mutate_text(m, text):
    """The source text with m applied, or a reason it does not apply."""
    lines = text.split("\n")
    if m.line < 1 or m.line > len(lines):
        return None, "line %d is past the end" % m.line
    src = lines[m.line - 1]
    count = src.count(m.old)
    if count != 1:
        return None, "'%s' occurs %d times on line %d: %s" % (
            m.old, count, m.line, src.strip())
    lines[m.line - 1] = src.replace(m.old, m.new)
    return "\n".join(lines), None


# --------------------------------------------------------------- the tree


def tree_paths(tree):
    tree = os.path.abspath(tree)
    return (tree, os.path.join(tree, "repo", "spark"),
            os.path.join(tree, "pristine"), os.path.join(tree, "results"))


def write_fresh(path, text):
    """Write text to path with a new mtime, so that gprbuild and gnatprove
    see the change (a restored file must not look older than its objects)."""
    with open(path, "w") as f:
        f.write(text)
    now = time.time()
    os.utime(path, (now, now))


def restore_all(tree):
    _, spark, pristine, _ = tree_paths(tree)
    for root, _, files in os.walk(pristine):
        for name in files:
            p = os.path.join(root, name)
            rel = os.path.relpath(p, pristine)
            dst = os.path.join(spark, rel)
            with open(p) as f:
                orig = f.read()
            with open(dst) as f:
                cur = f.read()
            if cur != orig:
                write_fresh(dst, orig)


class Applied(object):
    """Context manager: m applied in the tree, the pristine file restored
    on exit."""

    def __init__(self, tree, m):
        self.tree, self.m = tree, m

    def __enter__(self):
        _, spark, pristine, _ = tree_paths(self.tree)
        src = os.path.join(spark, self.m.file)
        keep = os.path.join(pristine, self.m.file)
        if not os.path.exists(keep):
            os.makedirs(os.path.dirname(keep), exist_ok=True)
            shutil.copyfile(src, keep)
        with open(keep) as f:
            text = f.read()
        new, why = mutate_text(self.m, text)
        if new is None:
            die("%s: %s" % (self.m.id, why))
        write_fresh(src, new)
        return self

    def __exit__(self, *exc):
        restore_all(self.tree)
        return False


class Unmutated(object):
    """Context manager: the tree as it is (the control of a witness)."""

    def __init__(self, tree):
        self.tree = tree

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def run(cmd, cwd, log, env=None, timeout=None):
    """Run cmd with output to log; (exit status, seconds). A run past
    timeout is killed with its process group and returns status None."""
    t0 = time.time()
    with open(log, "w") as out:
        out.write(">> %s\n" % " ".join(shlex.quote(c) for c in cmd))
        out.flush()
        p = subprocess.Popen(cmd, cwd=cwd, stdout=out, stderr=subprocess.STDOUT,
                             env=env, start_new_session=True)
        try:
            status = p.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid, signal.SIGKILL)
            p.wait()
            status = None
    return status, int(time.time() - t0)


def timeout():
    return int(os.environ.get("MUTATION_TIMEOUT", "3600"))


# --------------------------------------------------------------- results


def result_path(tree, column, mid):
    d = os.path.join(tree_paths(tree)[3], column)
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, mid + ".json")


def save(tree, column, mid, res):
    with open(result_path(tree, column, mid), "w") as f:
        json.dump(res, f, indent=1, sort_keys=True)
        f.write("\n")


def loaded(tree, column, mid):
    p = result_path(tree, column, mid)
    if not os.path.exists(p):
        return None
    with open(p) as f:
        return json.load(f)


# --------------------------------------------------------------- commands


def cmd_check(_args):
    mutants, groups = load()
    props = set(properties())
    bad = 0
    for m in mutants:
        path = os.path.join(SPARK, m.file)
        if not os.path.exists(path):
            print("%s: no file %s" % (m.id, m.file))
            bad += 1
            continue
        with open(path) as f:
            _, why = mutate_text(m, f.read())
        if why:
            print("%s: %s" % (m.id, why))
            bad += 1
        for p in expand(m.ffi, groups):
            if p not in props:
                print("%s: no property %s" % (m.id, p))
                bad += 1
        for u in expand(m.prove, groups):
            if not any(os.path.exists(os.path.join(SPARK, "src", d, u))
                       for d in os.listdir(os.path.join(SPARK, "src"))):
                print("%s: no unit %s" % (m.id, u))
                bad += 1
    print("%d mutants, %d problems" % (len(mutants), bad))
    return 1 if bad else 0


def cmd_list(_args):
    mutants, groups = load()
    for m in mutants:
        print("%s  %s:%d  %s  [%d properties; %s]" % (
            m.id, m.file, m.line, m.what, len(expand(m.ffi, groups)),
            " ".join(expand(m.prove, groups))))
    return 0


def cmd_setup(args):
    if len(args) != 1:
        die("setup TREE")
    tree, spark, _, _ = tree_paths(args[0])
    if os.path.exists(os.path.join(tree, "repo")):
        die("%s exists" % os.path.join(tree, "repo"))
    os.makedirs(tree, exist_ok=True)
    ignore = shutil.ignore_patterns(".git", "obj", "lib", "alire", "config",
                                    "*.so", "*.dylib")

    def ign(d, names):
        skip = set(ignore(d, names))
        # NSA's .so/.dylib links beside their .cry files are kept (dangling
        # symlinks into unbuilt Rust, as in the checkout); only our own
        # build output is skipped.
        if not os.path.abspath(d).startswith(SPARK):
            skip = set(n for n in skip if not n.endswith((".so", ".dylib")))
        return skip

    shutil.copytree(REPO, os.path.join(tree, "repo"), symlinks=True,
                    ignore=ign)
    alr = os.environ.get("ALR", "alr")
    status, secs = run([alr, "-n", "build"], spark,
                       os.path.join(tree, "setup.log"))
    if status != 0:
        die("alr -n build failed in %s (setup.log)" % spark)
    print("setup: %s (alr -n build, %d s)" % (spark, secs))
    return 0


def select(args, mutants):
    ids = [a for a in args if not a.startswith("--")]
    if not ids:
        return mutants
    by = dict((m.id, m) for m in mutants)
    for i in ids:
        if i not in by:
            die("no mutant %s" % i)
    return [by[i] for i in ids]


def build_ffi(spark, log):
    jobs = os.environ.get("FFI_JOBS", str(os.cpu_count() or 1))
    alr = os.environ.get("ALR", "alr")
    return run([alr, "-n", "exec", "--", "gprbuild", "-p", "-q", "-s",
                "-j" + jobs, "-P", "foundation_spark_ffi.gpr"], spark, log)


def ffi_once(tree, props, logbase, stop_early=True):
    """Build the library from the tree as it is and run props (all when
    props is None). A dict: outcome, failed properties, times."""
    _, spark, _, _ = tree_paths(tree)
    status, bsecs = build_ffi(spark, logbase + ".build.log")
    if status != 0:
        return {"outcome": "nocompile", "build_s": bsecs}
    env = dict(os.environ)
    env["FFI_LIB"] = "obj/ffi/lib/libfoundation_spark_ffi.%s" % EXT
    if props is None or not stop_early:
        cmd = ["scripts/check-ffi.sh"] + (props or [])
        status, secs = run(cmd, spark, logbase + ".log", env=env,
                           timeout=timeout())
        with open(logbase + ".log") as f:
            out = f.read()
    else:
        # One property per check-ffi.sh run (each is its own cryptol run
        # anyway), stopping at the first that fails: a killed mutant needs
        # one killer, and only a survivor needs them all.
        out, secs, status = "", 0, 0
        for p in props:
            st, s = run(["scripts/check-ffi.sh", p], spark,
                        logbase + ".one.log", env=env, timeout=timeout())
            secs += s
            with open(logbase + ".one.log") as f:
                out += f.read()
            if st != 0:
                status = st
                break
        with open(logbase + ".log", "w") as f:
            f.write(out)
    failed = re.findall(r"^\s+FAIL\s+(\S+):", out, re.M)
    passed = re.findall(r"^\s+PASS\s+(\S+):", out, re.M)
    res = {"build_s": bsecs, "run_s": secs, "failed": failed,
           "passed": len(passed)}
    if status is None:
        res["outcome"] = "hang"
    elif status == 0 and not failed:
        res["outcome"] = "survived"
    elif status == 1 and failed:
        res["outcome"] = "killed"
        # The first lines of each failure's reason, from the log.
        why = {}
        for p in failed:
            m = re.search(r"^\s+FAIL\s+%s:.*\n((?:\s{9}.*\n){0,3})"
                          % re.escape(p), out, re.M)
            why[p] = [x.strip() for x in (m.group(1) if m else "").splitlines()]
        res["why"] = why
    else:
        res["outcome"] = "error"
        res["status"] = status
    return res


def cmd_ffi(args):
    if not args:
        die("ffi TREE [ID ...] [--full] [--baseline] [--redo]")
    tree = args[0]
    rest = args[1:]
    full = "--full" in rest
    mutants, groups = load()
    logs = os.path.join(tree_paths(tree)[3], "ffi")
    os.makedirs(logs, exist_ok=True)
    restore_all(tree)
    if "--baseline" in rest:
        props = None if full else expand(
            [p for m in mutants for p in m.ffi], groups)
        res = ffi_once(tree, props, os.path.join(logs, "baseline"),
                       stop_early=False)
        res["properties"] = "all" if full else len(props)
        save(tree, "ffi", "baseline" + ("-full" if full else ""), res)
        print("baseline: %s (%s properties, %s passed)" % (
            res["outcome"], res["properties"], res.get("passed")))
        return 0 if res["outcome"] == "survived" else 1
    column = "ffi-full" if full else "ffi"
    for m in select(rest, mutants):
        if loaded(tree, column, m.id) and "--redo" not in rest and \
                not [a for a in rest if not a.startswith("--")]:
            continue
        if full:
            t = loaded(tree, "ffi", m.id)
            if not t or t["outcome"] != "survived":
                continue
        props = None if full else expand(m.ffi, groups)
        with Applied(tree, m):
            res = ffi_once(tree, props,
                           os.path.join(logs, m.id + ("-full" if full else "")))
        res["properties"] = "all" if full else len(props)
        save(tree, column, m.id, res)
        print("%s %s: %s%s (%s properties, %s s)" % (
            column, m.id, res["outcome"],
            (" by " + " ".join(res["failed"])) if res.get("failed") else "",
            res["properties"], res.get("run_s", res.get("build_s"))))
        sys.stdout.flush()
    return 0


# gnatprove 16's messages. A check or flow message is a header line
# " medium: postcondition might fail" (severity high, medium or low; error
# and warning likewise), then "--> file:line:col", the source excerpt, and
# notes starting with "+": "+ e.g. when B = 128 ..." for a counterexample,
# "+ provers reached time limit ..." for a timeout. A compiler error is the
# classic "file:line:col: error: text".
HEAD = re.compile(r"^ ?(high|medium|low|error|warning|info|"
                  r"check|style): (.*)$")
LOC = re.compile(r"^\s*--> (\S+\.ad[sb]):(\d+):(\d+)")
CLASSIC = re.compile(r"^(\S+\.ad[sb]):(\d+):(\d+): (error|warning|"
                     r"high|medium|low): (.*)$")
FLOW = re.compile(r"might not be initialized|is not initialized|"
                  r"might be used uninitialized|not set before|"
                  r"unused assignment|is not modified|has no effect|"
                  r"might not be written|is not used|statement has no effect")
LIMIT = re.compile(r"reached (time|step|steps|resource|memory) limit|"
                   r"time limit|timeout|resource limit|step limit")


def parse_messages(log_text):
    """Every message of gnatprove's output: dicts of severity, location,
    text and notes."""
    msgs = []
    cur = None
    for line in log_text.splitlines():
        m = CLASSIC.match(line)
        if m:
            cur = {"severity": m.group(4), "text": m.group(5),
                   "at": "%s:%s:%s" % m.group(1, 2, 3), "notes": []}
            msgs.append(cur)
            continue
        m = HEAD.match(line)
        if m:
            cur = {"severity": m.group(1), "text": m.group(2), "at": "?",
                   "notes": []}
            msgs.append(cur)
            continue
        if cur is None:
            continue
        m = LOC.match(line)
        if m and cur["at"] == "?":
            cur["at"] = "%s:%s:%s" % m.group(1, 2, 3)
            continue
        st = line.strip()
        if st.startswith("+ "):
            cur["notes"].append(st[2:])
        elif st.startswith(("Summary logged", ">> ", "Phase ")):
            cur = None
    return [x for x in msgs if x["severity"] not in ("info",)]


def classify(log_text):
    """The proof column's outcome, and each message with its kind: cex
    (a counterexample), timeout (the provers reached a time or step limit,
    no counterexample), nocex (unproved, neither), flow (flow analysis),
    error (the compiler), warning."""
    msgs = []
    for x in parse_messages(log_text):
        notes = " ".join(x["notes"])
        if x["severity"] == "error":
            kind = "error"
        elif x["severity"] in ("warning", "style"):
            kind = "warning"
        elif FLOW.search(x["text"]) and "might fail" not in x["text"]:
            kind = "flow"
        elif re.search(r"\be\.g\. when\b|counterexample", notes):
            kind = "cex"
        elif LIMIT.search(notes) or LIMIT.search(x["text"]):
            kind = "timeout"
        else:
            kind = "nocex"
        msgs.append({"at": x["at"], "severity": x["severity"], "kind": kind,
                     "text": (x["text"] + (" | " + notes if notes else ""))[:500]})
    kinds = set(x["kind"] for x in msgs)
    if not msgs:
        outcome = "proved"
    elif "error" in kinds and not kinds & {"cex", "nocex", "timeout", "flow"}:
        outcome = "nocompile"
    elif "cex" in kinds:
        outcome = "refuted"
    elif "nocex" in kinds:
        outcome = "unproved"
    elif "flow" in kinds:
        outcome = "flow"
    elif "timeout" in kinds:
        outcome = "timeout"
    else:
        outcome = "warning"
    return outcome, msgs


def prove_once(tree, units, logbase):
    _, spark, _, _ = tree_paths(tree)
    log = logbase + ".log"
    wrap = os.environ.get("MUTATION_PROVE_WRAP")
    child = ["scripts/prove.sh"]
    for u in units:
        child += ["-u", u]
    env = dict(os.environ)
    env["PROVE_LOG"] = log + ".prove"
    if wrap:
        cmd = shlex.split(wrap) + ["env", "PROVE_JOBS={tokens}"] + child
    else:
        env["PROVE_JOBS"] = os.environ.get(
            "SPARK_SCHEDULER_TOKENS", os.environ.get("PROVE_JOBS", "1"))
        cmd = child
    status, secs = run(cmd, spark, log, env=env, timeout=timeout())
    with open(log) as f:
        text = f.read()
    res = {"run_s": secs, "status": status, "units": units}
    if status is None:
        res["outcome"] = "hang"
        return res
    if status == 3 or "STALE OR MISSING OUTPUT" in text:
        # prove.sh's freshness guard: a unit was not analyzed (a compile
        # error stops gnatprove before it writes the .spark files).
        if re.search(r"^\S+\.ad[sb]:\d+:\d+: error:", text, re.M) or \
                "compilation" in text.lower():
            res["outcome"] = "nocompile"
        else:
            res["outcome"] = "stale"
        res["messages"] = classify(text)[1][:20]
        return res
    outcome, msgs = classify(text)
    if status != 0 and outcome == "proved":
        outcome = "error"
    res["outcome"] = outcome
    res["messages"] = msgs
    return res


def cmd_prove(args):
    if not args:
        die("prove TREE [ID ...] [--baseline] [--redo]")
    tree = args[0]
    rest = args[1:]
    mutants, groups = load()
    logs = os.path.join(tree_paths(tree)[3], "prove")
    os.makedirs(logs, exist_ok=True)
    restore_all(tree)
    if "--baseline" in rest:
        units = expand([u for m in mutants for u in m.prove], groups)
        res = prove_once(tree, units, os.path.join(logs, "baseline"))
        save(tree, "prove", "baseline", res)
        print("baseline: %s (%d units, %d s)" % (res["outcome"], len(units),
                                                 res["run_s"]))
        return 0 if res["outcome"] == "proved" else 1
    explicit = [a for a in rest if not a.startswith("--")]
    for m in select(rest, mutants):
        if loaded(tree, "prove", m.id) and "--redo" not in rest \
                and not explicit:
            continue
        units = expand(m.prove, groups)
        with Applied(tree, m):
            res = prove_once(tree, units, os.path.join(logs, m.id))
        save(tree, "prove", m.id, res)
        kinds = {}
        for x in res.get("messages", []):
            if isinstance(x, dict):
                kinds[x["kind"]] = kinds.get(x["kind"], 0) + 1
        print("prove %s: %s %s (%d s)" % (
            m.id, res["outcome"],
            " ".join("%s=%d" % kv for kv in sorted(kinds.items())),
            res["run_s"]))
        sys.stdout.flush()
    return 0


def cmd_diagnose(args):
    """Prove mutants again with gnatprove called directly (not through
    prove.sh, which refuses level and timeout switches), with the extra
    arguments after --, to see whether more prover time turns a timeout
    into a counterexample. Diagnostic only: the proof column is prove's,
    at the committed levels. Results in TREE/results/diagnose/."""
    if "--" not in args or len(args) < 3:
        die("diagnose TREE ID ... -- GNATPROVE_ARGS ...")
    k = args.index("--")
    tree, ids, extra = args[0], args[1:k], args[k + 1:]
    mutants, groups = load()
    _, spark, _, results = tree_paths(tree)
    logs = os.path.join(results, "diagnose")
    os.makedirs(logs, exist_ok=True)
    restore_all(tree)
    jobs = os.environ.get("SPARK_SCHEDULER_TOKENS",
                          os.environ.get("PROVE_JOBS", "1"))
    alr = os.environ.get("ALR", "alr")
    for m in select(ids, mutants):
        units = expand(m.prove, groups)
        cmd = [alr, "-n", "exec", "--", "gnatprove", "-P",
               "foundation_spark.gpr", "-j" + jobs, "-f"]
        for u in units:
            cmd += ["-u", u]
        cmd += extra
        log = os.path.join(logs, m.id + ".log")
        with Applied(tree, m):
            status, secs = run(cmd, spark, log, timeout=timeout())
        with open(log) as f:
            outcome, msgs = classify(f.read())
        res = {"outcome": outcome, "messages": msgs, "run_s": secs,
               "status": status, "args": extra}
        save(tree, "diagnose", m.id, res)
        print("diagnose %s: %s (%d s)" % (m.id, outcome, secs))
        for x in msgs:
            print("   %s %s %s" % (x["kind"], x["at"], x["text"][:300]))
        sys.stdout.flush()
    return 0


def cmd_witness(args):
    """Run one Cryptol :check against the library built with a mutant (or
    with none, ID "none", the control)
    applied, typically at an input the properties never try (a longer
    message): a concrete witness that an FFI survivor is a real bug.
    MODULE is under cryptol/; EXPR is a Cryptol expression of a function
    to Bit that may use the module's definitions."""
    if len(args) != 5:
        die("witness TREE ID MODULE EXPR TESTS")
    tree, mid, module, expr, tests = args
    mutants, _ = load()
    m = None if mid == "none" else select([mid], mutants)[0]
    _, spark, _, results = tree_paths(tree)
    repo = os.path.dirname(spark)
    logs = os.path.join(results, "witness")
    os.makedirs(logs, exist_ok=True)
    restore_all(tree)
    icry = os.path.join(logs, mid + ".icry")
    with open(icry, "w") as f:
        f.write(":set tests=%s\n:load %s\n:check %s\n"
                % (tests, os.path.join(spark, "cryptol", module), expr))
    # check-ffi.sh's ad hoc signed copy on macOS (made by any earlier run
    # in this tree), else CRYPTOL.
    cryptol = os.path.join(spark, "obj", "ffi", "cryptol-adhoc", "cryptol")
    if not os.path.exists(cryptol):
        cryptol = os.environ.get("CRYPTOL", "cryptol")
    env = dict(os.environ)
    env["CRYPTOLPATH"] = "%s:%s" % (repo, os.path.join(spark, "cryptol"))
    with (Applied(tree, m) if m else Unmutated(tree)):
        st, _ = build_ffi(spark, os.path.join(logs, mid + ".build.log"))
        if st != 0:
            die("%s does not build" % mid)
        st, secs = run([cryptol, "-b", icry], repo,
                       os.path.join(logs, mid + ".log"), env=env,
                       timeout=timeout())
    with open(os.path.join(logs, mid + ".log")) as f:
        out = f.read()
    verdict = ("counterexample" if "Counterexample" in out or
               re.search(r"^\s*= False", out, re.M) else
               "passed" if re.search(r"Passed \d+ tests", out) else "error")
    print("witness %s: %s (%s s; log %s)" % (mid, verdict, secs,
                                           os.path.join(logs, mid + ".log")))
    return 0 if verdict == "counterexample" else 1


def saw_git(tree):
    """check-saw.sh reads the commit (git rev-parse HEAD) and checks NSA's
    Cryptol against it (git diff HEAD), but setup copies no .git: give the
    tree's repo a git of its own, one commit of the pristine copy, so that
    a mutant is an uncommitted change (check-saw.sh --print says "with
    uncommitted changes: not a record")."""
    repo = os.path.dirname(tree_paths(tree)[1])
    if os.path.exists(os.path.join(repo, ".git")):
        return
    git = ["git", "-c", "user.name=mutation.py",
           "-c", "user.email=mutation@localhost", "-c", "commit.gpgsign=false"]
    log = os.path.join(tree_paths(tree)[0], "git.log")
    for cmd in (["init", "-q"], ["add", "-A"],
                ["commit", "-q", "-m", "pristine copy (mutation.py saw)"]):
        status, _ = run(git + cmd, repo, log)
        if status != 0:
            die("git %s failed in %s (%s)" % (cmd[0], repo, log))


def saw_once(tree, logbase, layers):
    """check-saw.sh --print on the tree as it is. A dict: outcome (proved,
    failed: an llvm_verify failed, with a counterexample or not; killed: the
    memory cap; error: anything else), the script and subprogram that
    failed, and the per-script times."""
    _, spark, _, _ = tree_paths(tree)
    env = dict(os.environ)
    env["SAW_LAYERS"] = layers
    log = logbase + ".log"
    status, secs = run(["scripts/check-saw.sh", "--print"], spark, log,
                       env=env, timeout=timeout())
    # check-saw.sh clears saw/obj/ each run: keep this run's saw logs.
    keep = logbase + ".logs"
    if os.path.exists(keep):
        shutil.rmtree(keep)
    src = os.path.join(spark, "saw", "obj", "logs")
    if os.path.isdir(src):
        shutil.copytree(src, keep)
    with open(log) as f:
        out = f.read()
    res = {"status": status, "run_s": secs, "layers": layers}
    m = re.search(r"^>> SAW: (\d+) proved", out, re.M)
    res["proved"] = int(m.group(1)) if m else None
    res["times"] = re.findall(r"(\d+ s for \S+\.saw)", out)
    script = re.search(r"saw (\S+\.saw) (FAILED|was KILLED)", out)
    neg = re.search(r"NEGATIVE CONTROL PROVED: (\S+)", out)
    if status is None:
        res["outcome"] = "hang"
    elif status == 0:
        res["outcome"] = "proved"
    elif script:
        res["script"] = script.group(1)
        res["outcome"] = "killed" if script.group(2) != "FAILED" else "failed"
        slog = os.path.join(keep, script.group(1)[:-4] + ".log")
        text = ""
        if os.path.exists(slog):
            with open(slog) as f:
                text = f.read()
        # The subprogram being verified when the proof failed.
        verifying = re.findall(r"^Verifying (\S+?) *\.\.\.$", text, re.M)
        res["subprogram"] = verifying[-1] if verifying else None
        res["cex"] = "-Counterexample-" in text
        err = [x for x in text.splitlines()
               if re.search(r"Proof failed|error|Error|failed", x)]
        res["errors"] = [x.strip()[:300] for x in err[:10]]
    elif neg:
        res["outcome"] = "error"
        res["script"] = neg.group(1)
        res["errors"] = ["negative control proved"]
    else:
        res["outcome"] = "error"
        res["errors"] = [x[:300] for x in out.splitlines() if
                         x.startswith("!!")][:10]
    return res


def cmd_saw(args):
    """The SAW column (on a machine with GNAT Pro's LLVM back end and SAW,
    the x86_64 instance): per mutant, scripts/check-saw.sh --print in the
    tree with the mutant applied, SAW_LAYERS=impl (all for SHA2.Functions,
    which the spec layer shares). A mutant SAW catches makes an llvm_verify
    fail (check-saw.sh stops at the first script that fails); a negative
    control that stops failing is reported as an error. --baseline: the
    unmutated tree, SAW_LAYERS=impl (it must prove). Needs GNAT_LLVM_DIR
    and LLVM_LINK_DIR, as check-saw.sh does. Results in TREE/results/saw/,
    with each run's saw logs in <ID>.logs/."""
    if len(args) < 2:
        die("saw TREE ID ... | saw TREE --baseline")
    tree, rest = args[0], args[1:]
    mutants, _ = load()
    logs = os.path.join(tree_paths(tree)[3], "saw")
    os.makedirs(logs, exist_ok=True)
    restore_all(tree)
    saw_git(tree)
    if "--baseline" in rest:
        res = saw_once(tree, os.path.join(logs, "baseline"), "impl")
        save(tree, "saw", "baseline", res)
        print("saw baseline: %s, %s proved (%d s)" % (
            res["outcome"], res.get("proved"), res["run_s"]))
        return 0 if res["outcome"] == "proved" else 1
    for m in select(rest, mutants):
        layers = os.environ.get("SAW_LAYERS",
                                "all" if m.id.startswith("F") else "impl")
        with Applied(tree, m):
            res = saw_once(tree, os.path.join(logs, m.id), layers)
        save(tree, "saw", m.id, res)
        print("saw %s: %s%s (%d s)" % (
            m.id, res["outcome"],
            (" at %s %s%s" % (res.get("script"), res.get("subprogram"),
                              ", counterexample" if res.get("cex") else ""))
            if res.get("script") else "", res["run_s"]))
        sys.stdout.flush()
    return 0


def cmd_reclassify(args):
    """Re-read every saved proof log and classify it again (after a change
    to the classifier; the logs are the record)."""
    if len(args) != 1:
        die("reclassify TREE")
    tree = args[0]
    for path in sorted(os.listdir(os.path.join(tree_paths(tree)[3], "prove"))):
        if not path.endswith(".json"):
            continue
        mid = path[:-5]
        res = loaded(tree, "prove", mid)
        log = os.path.join(tree_paths(tree)[3], "prove", mid + ".log")
        if not os.path.exists(log) or res.get("outcome") in ("hang", "stale"):
            continue
        with open(log) as f:
            text = f.read()
        outcome, msgs = classify(text)
        if res.get("status") not in (0, None) and outcome == "proved":
            outcome = "error"
        res["outcome"], res["messages"] = outcome, msgs
        save(tree, "prove", mid, res)
        print("%s: %s" % (mid, outcome))
    return 0


def cell_ffi(r, rf):
    if not r:
        return "not run"
    o = r["outcome"]
    if o == "killed":
        return "killed by %s" % " ".join(r["failed"])
    if o == "survived":
        if rf:
            if rf["outcome"] == "killed":
                return "survived %d; killed by %s" % (
                    r["properties"], " ".join(rf["failed"]))
            return "survived %d; %s all" % (r["properties"], rf["outcome"])
        return "survived %d" % r["properties"]
    return o


def cell_prove(r):
    if not r:
        return "not run"
    o = r["outcome"]
    kinds = {}
    for x in r.get("messages", []):
        if isinstance(x, dict) and x["kind"] not in ("warning",):
            kinds[x["kind"]] = kinds.get(x["kind"], 0) + 1
    if kinds:
        return "%s (%s)" % (o, ", ".join("%d %s" % (v, k)
                                         for k, v in sorted(kinds.items())))
    return o


def cell_saw(r):
    if not r:
        return ""
    if r.get("script"):
        return "%s at %s `%s`%s" % (
            r["outcome"], r["script"], r.get("subprogram"),
            " (counterexample)" if r.get("cex") else "")
    return r["outcome"]


def verdict(m, rf, rff, rp):
    """The mutant's category for the table."""
    if not rf or not rp:
        return "incomplete"
    if rf["outcome"] == "nocompile" or rp["outcome"] == "nocompile":
        return "does not compile"
    ffi_killed = rf["outcome"] in ("killed", "hang") or (
        rff is not None and rff["outcome"] in ("killed", "hang"))
    if ffi_killed:
        return "FFI"
    if rf["outcome"] != "survived" or (rff and rff["outcome"] != "survived"):
        return "FFI error"
    if rp["outcome"] in ("refuted", "unproved", "flow"):
        return "proof only"
    if rp["outcome"] == "timeout":
        return "proof only (timeout)"
    if rp["outcome"] == "proved":
        return "neither"
    return "proof: " + rp["outcome"]


def cmd_report(args):
    if len(args) != 1:
        die("report TREE")
    tree = args[0]
    mutants, _ = load()
    rows = []
    counts = {}
    for m in mutants:
        rf = loaded(tree, "ffi", m.id)
        rff = loaded(tree, "ffi-full", m.id)
        rp = loaded(tree, "prove", m.id)
        rs = loaded(tree, "saw", m.id)
        v = verdict(m, rf, rff, rp)
        counts[v] = counts.get(v, 0) + 1
        rows.append("| %s | `%s`:%d | %s | %s | %s | %s | %s |" % (
            m.id, os.path.basename(m.file), m.line, m.what,
            cell_ffi(rf, rff), cell_prove(rp),
            cell_saw(rs), v))
    print("| id | where | mutant | FFI | gnatprove | SAW | caught by |")
    print("|---|---|---|---|---|---|---|")
    for r in rows:
        print(r)
    print()
    for k in sorted(counts):
        print("* %s: %d" % (k, counts[k]))
    return 0


def main(argv):
    if not argv:
        sys.stderr.write(__doc__)
        return 2
    cmds = {"check": cmd_check, "list": cmd_list, "setup": cmd_setup,
            "ffi": cmd_ffi, "prove": cmd_prove, "report": cmd_report,
            "reclassify": cmd_reclassify, "diagnose": cmd_diagnose,
            "witness": cmd_witness, "saw": cmd_saw}
    if argv[0] not in cmds:
        die("unknown command %s" % argv[0])
    return cmds[argv[0]](argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
