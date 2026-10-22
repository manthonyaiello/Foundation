# Effort data: obtaining the proofs vs. checking them

Raw data for comparing the time it takes to **obtain** the SPARK and SAW
proofs (agent work, until the proofs are green) with the time it takes to
**check** them (running the tools on a green tree). Collected 2026-10-22;
no analysis yet.

## What is here

| file | what |
|---|---|
| `agents.csv` | One row per transcript: the orchestrator session and each tick (subagent) it launched. Start, end, wall-clock, tool calls, output tokens, and the tick's description. |
| `commands.csv` | One row per shell command run by any of them: start, duration, foreground or background, a category, and the command with local paths, host names and toolchain package names replaced by `<path>`, `<host>`, `<pkg>`. |
| `extract_effort.py` | The extractor that wrote both (run on Claude Code session transcripts; see its docstring). Absolute paths, cloud host names and emails are scrubbed by the script; further words (internal package and host names) are passed in `EFFORT_SCRUB_WORDS`, so they appear nowhere in the repository. |

No message text is kept, only timestamps, counts and scrubbed commands.

**Sessions covered** (both on the x86_64 IOD; `session` is the first 8 hex
digits of the session id):

* `0f6e209a`, 2026-10-19/20: **E4, obtaining the SAW proofs** from scratch.
  Ticks M4.1 (#22, spike), M4.2 (#23, AES), M4.3 (#24, SHA-256/HMAC), M4.4
  (#59, spec layer) and the #59 gaps tick; one unnamed helper.
* `bfed13a5`, 2026-10-21/22: **re-obtaining SAW after spec changes** (#68,
  #75's SAW half, #67 `Parse`), the #69 cost analysis, the #95 record fix,
  and #50's x86_64 constant-time half (not SAW).

**Not covered:** the SPARK (gnatprove) work, E0–E3 and later. Those sessions
ran on `foundation`; their transcripts are under `~/.claude/projects/` there,
and memcp holds their summaries and turns. Run `extract_effort.py` on them
to extend these files.

## Categories (`commands.csv`)

Assigned by the first matching pattern in `extract_effort.py`: `saw-record`
(`check-saw.sh` writing a record), `saw-check-print` (`check-saw.sh --print`),
`saw-hand` (saw run directly), `saw-experiment` (#69's harness), `gnatprove`,
`ffi`, `constant-time`, `build`, `ci-wait` (waiting on CI), `github`, `git`,
`board`, `other`. The patterns are coarse: read the command column before
trusting a category.

**Durations:** foreground commands, from the tool call to its result.
Background commands, from the call to the completion notification; empty
when no notification was matched. A tick's wall-clock includes the time it
waited on its own SAW records, so obtain-time = wall-clock minus those
`saw-record` rows (roughly).

## Check times recorded elsewhere

The tools' own records, all in the repository:

* **SAW**, `spark/saw/results.txt` and `results-long.txt`: per result and
  per script.
  * Default record at `5bf56ac`: 4 + 31 + 395 + 2352 s = **3543 s**: AES
    impl, SHA-256/HMAC impl, AES spec, SHA-256/HMAC spec. One core, x86_64,
    an idle machine.
  * Long record at `babab6f`: **7819 s**.
  * Earlier records are in their git history (e.g. `d874133`: 3838 s).
* **SAW cost by cause**: `../measurements/2026-10-22-saw-cost.md` (#69),
  with peak memory per script.
* **gnatprove**:
  * the default gate on `foundation` (arm64), cold at `-j4`, about 530 s
    (`PLAN.md`, the #74 spike);
  * the slow unit `SBox_Entries`, cold in CI: 28m24s;
  * CI's prove jobs: `gh run list -R manthonyaiello/Foundation --workflow
    "SPARK CI"` and the job timings. Mostly cached runs; the scheduled
    cache refresh is the cold one.
* **The E4 day's measurements**: `../measurements/2026-10-19-iod.md`.

A fresh, controlled "check" run was not made: the SAW default record of
`5bf56ac` (tick E, an idle machine) is the latest one. gnatprove on x86_64
is not comparable, since six checks time out there.
