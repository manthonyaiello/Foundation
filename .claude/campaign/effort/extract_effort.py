#!/usr/bin/env python3
"""Extract a sanitized timing ledger from Claude Code session transcripts.

Usage: extract_effort.py OUT_DIR SESSION_JSONL [SESSION_JSONL ...]

For each session (the orchestrator) and each of its subagents (the ticks),
writes:
  agents.csv    one row per transcript: start, end, wall-clock, tool calls,
                output tokens, the description the orchestrator gave it
  commands.csv  one row per Bash call: who ran it, when, how long (foreground:
                tool_use to tool_result; background: tool_use to its
                completion notification), a category, and the command with
                local paths, hostnames and toolchain package names scrubbed
No message text is kept. Set EFFORT_SCRUB_WORDS (comma-separated) to scrub
further words, e.g. internal package names.
"""
import csv, json, os, re, sys
from datetime import datetime

CATS = [  # first match wins
    ("saw-record", r"check-saw\.sh(?![^|;&]*--print)"),
    ("saw-check-print", r"check-saw\.sh"),
    ("saw-experiment", r"experiments/issue-69|(?<![\w-])run(-all)?\.sh\b"),
    ("saw-hand", r"(^|[\s/])saw\s"),
    ("gnatprove", r"prove(-slow)?\.sh|gnatprove|check-proof\.sh"),
    ("ffi", r"check-ffi\.sh|cryptol"),
    ("constant-time", r"check-ct|valgrind|ct_grind|dudect"),
    ("build", r"alr\b.*build|gprbuild|llvm-gcc|llvm-link"),
    ("ci-wait", r"gh (pr|run) (checks|watch|view)|--watch"),
    ("github", r"\bgh\b"),
    ("git", r"\bgit\b"),
    ("board", r"board\.py|slow_proofs\.py"),
    ("poll-wait", r"\b(until|while)\b.*\bsleep\b"),  # polling a background job's output
]
SCRUB = [
    (re.compile(r"(?:(?<![\w.])|(?<=-[A-Za-z]))/(?:[\w.+-]+/)+[\w.+-]*"), "<path>"),  # absolute paths
    (re.compile(r"\bip-\d+(?:-\d+)*"), "<host>"),                  # cloud host names
    (re.compile(r"[\w.+-]+@[\w-]+\.[\w.]+"), "<email>"),
]


#: Extra words to replace by <pkg> (toolchain package names, internal tool
#: names), comma-separated, from the environment: kept out of this file.
EXTRA = [w for w in os.environ.get("EFFORT_SCRUB_WORDS", "").split(",") if w]
if EXTRA:
    SCRUB.append((re.compile(r"\b(" + "|".join(map(re.escape, EXTRA)) + r")\b", re.I), "<pkg>"))


def scrub(cmd):
    for rx, rep in SCRUB:
        cmd = rx.sub(rep, cmd)
    cmd = " ".join(cmd.split())
    return cmd[:200]


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def category(cmd):
    for name, rx in CATS:
        if re.search(rx, cmd):
            return name
    return "other"


def walk(path):
    for line in open(path):
        try:
            yield json.loads(line)
        except ValueError:
            pass


def content_items(d):
    m = d.get("message")
    if isinstance(m, dict) and isinstance(m.get("content"), list):
        return m["content"]
    return []


def text_of(item):
    c = item.get("content")
    if isinstance(c, list):
        return " ".join(x.get("text", "") for x in c if isinstance(x, dict))
    return c if isinstance(c, str) else ""


def analyse(path, who, session):
    uses, rows = {}, []
    bg = {}  # background task id -> row
    first = last = None
    tools = out_tokens = 0
    for d in walk(path):
        t = d.get("timestamp")
        if not t:
            continue
        t = ts(t)
        first = first or t
        last = t
        if d.get("type") == "assistant":
            u = (d.get("message") or {}).get("usage") or {}
            out_tokens += u.get("output_tokens", 0)
        for it in content_items(d):
            if it.get("type") == "tool_use":
                tools += 1
                if it.get("name") == "Bash":
                    inp = it.get("input") or {}
                    uses[it["id"]] = (t, inp.get("command", ""), bool(inp.get("run_in_background")))
            elif it.get("type") == "tool_result" and it.get("tool_use_id") in uses:
                t0, cmd, isbg = uses.pop(it["tool_use_id"])
                row = {"who": who, "session": session, "start": t0.isoformat(),
                       "seconds": round((t - t0).total_seconds(), 1),
                       "background": isbg, "category": category(cmd), "command": scrub(cmd)}
                body = text_of(it)
                m = re.search(r"background with ID: (\w+)", body)
                if isbg and m:
                    row["seconds"] = ""
                    bg[m.group(1)] = (t0, row)
                rows.append(row)
        # background completion notifications: in a user message, or queued
        # as an attachment while the agent was busy (completed, failed or
        # killed: the agent waited on it until then either way)
        raw = json.dumps(d.get("message", "")) if d.get("type") == "user" else ""
        a = d.get("attachment") if d.get("type") == "attachment" else None
        if isinstance(a, dict) and a.get("type") == "queued_command":
            raw = str(a.get("prompt", ""))
        for note in raw.split("<task-notification>")[1:]:
            m = re.search(r"<task-id>(\w+)</task-id>", note)
            tid = m.group(1) if m and "<status>" in note else None
            if tid in bg:
                t0, row = bg.pop(tid)
                row["seconds"] = round((t - t0).total_seconds(), 1)
    agent = {"who": who, "session": session,
             "start": first.isoformat() if first else "", "end": last.isoformat() if last else "",
             "wall_seconds": round((last - first).total_seconds()) if first else 0,
             "tool_calls": tools, "output_tokens": out_tokens}
    return agent, rows


def descriptions(session_path):
    """agentId -> the description the orchestrator gave the Agent call."""
    pending, out = {}, {}
    for d in walk(session_path):
        for it in content_items(d):
            if it.get("type") == "tool_use" and it.get("name") == "Agent":
                pending[it["id"]] = (it.get("input") or {}).get("description", "")
            elif it.get("type") == "tool_result" and it.get("tool_use_id") in pending:
                m = re.search(r"agentId: (\w+)", text_of(it))
                if m:
                    out[m.group(1)] = pending.pop(it["tool_use_id"])
    return out


def main():
    out_dir, sessions = sys.argv[1], sys.argv[2:]
    os.makedirs(out_dir, exist_ok=True)
    agents, cmds = [], []
    for sp in sessions:
        sid = os.path.basename(sp)[:-6][:8]
        a, r = analyse(sp, "orchestrator", sid)
        a["description"] = "orchestrator session"
        agents.append(a); cmds += r
        desc = descriptions(sp)
        sub = os.path.join(sp[:-6], "subagents")
        for f in sorted(os.listdir(sub)) if os.path.isdir(sub) else []:
            if f.endswith(".jsonl"):
                aid = f[len("agent-"):-6]
                a, r = analyse(os.path.join(sub, f), "agent-" + aid[:8], sid)
                a["description"] = desc.get(aid, "")
                agents.append(a); cmds += r
    with open(os.path.join(out_dir, "agents.csv"), "w", newline="") as fh:
        w = csv.DictWriter(fh, ["session", "who", "description", "start", "end",
                                "wall_seconds", "tool_calls", "output_tokens"])
        w.writeheader(); w.writerows(agents)
    with open(os.path.join(out_dir, "commands.csv"), "w", newline="") as fh:
        w = csv.DictWriter(fh, ["session", "who", "start", "seconds", "background",
                                "category", "command"])
        w.writeheader(); w.writerows(cmds)
    print(len(agents), "transcripts,", len(cmds), "Bash calls")


main()
