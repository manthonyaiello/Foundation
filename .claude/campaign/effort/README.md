# Effort data: obtaining the proofs vs. checking them

Raw data for comparing the time it takes to **obtain** the SPARK and SAW
proofs (agent work, until the proofs are green) with the time it takes to
**check** them (running the tools on a green tree). Collected 2026-10-22
(IOD) and 2026-10-23 (`foundation`). The analysis is `ANALYSIS.md` (#106).

## What is here

| file | what |
|---|---|
| `ANALYSIS.md` | Effort per layer, obtain vs. check, and what the data cannot show (#106). |
| `summarize.py` | Writes `ANALYSIS.md`'s tables from the two CSVs: assigns each transcript a layer and sums its wall-clock, tool calls, tokens and tool waits (see its docstring). |
| `agents.csv` | One row per transcript: the orchestrator session and each tick (subagent) it launched. Start, end, wall-clock, tool calls, output tokens, and the tick's description. |
| `commands.csv` | One row per shell command run by any of them: start, duration, foreground or background, a category, and the command with local paths, host names and toolchain package names replaced by `<path>`, `<host>`, `<pkg>`. |
| `extract_effort.py` | The extractor that wrote both (run on Claude Code session transcripts; see its docstring). Absolute paths, cloud host names and emails are scrubbed by the script; further words (internal package and host names) are passed in `EFFORT_SCRUB_WORDS`, so they appear nowhere in the repository. |

Both CSVs start with a `machine` column: `iod` (the x86_64 IOD) or
`foundation` (the aarch64 container). No message text is kept, only
timestamps, counts and scrubbed commands.

**Sessions covered** (`session` is the first 8 hex digits of the session
id). On the x86_64 IOD (`machine` = `iod`):

* `0f6e209a`, 2026-10-19/20: **E4, obtaining the SAW proofs** from scratch.
  Ticks M4.1 (#22, spike), M4.2 (#23, AES), M4.3 (#24, SHA-256/HMAC), M4.4
  (#59, spec layer) and the #59 gaps tick; one unnamed helper.
* `bfed13a5`, 2026-10-21/22: **re-obtaining SAW after spec changes** (#68,
  #75's SAW half, #67 `Parse`), the #69 cost analysis, the #95 record fix,
  and #50's x86_64 constant-time half (not SAW).

On `foundation` (`machine` = `foundation`), added 2026-10-23 (#106):

* `0f5e52b6`, 2026-10-18/19: **E0–E3 and M5.1**: CI, the FFI harness,
  the board, the AES, SHA-256 and HMAC spec layers, implementations and
  FFI properties, slow proofs, the x86_64 bootstrap and proof margins,
  coverage. 25 ticks.
* `9388b3d5`, `3cff259e`, 2026-10-20: **reviews with Tony** (no ticks).
* `0022b46d`, 2026-10-20/21: the review's follow-ups: #72, #68, the #74
  spike, #80 (generic AES spec), #75 (the Cryptol prelude, two ticks),
  #70 (two), #67, #50's constant-time S-box, two doc helpers.

**Not covered:** the planning session of 2026-10-16 (`46b31592`, no
transcript), the one of 2026-10-15 on hex, a 4-minute shell-setup fix on
`foundation` (`88925fce`, not campaign work), and the hex sessions from
2026-10-22 on.

**How the `foundation` rows were made:** `extract_effort.py` on the five
transcripts, with the same scrubbing, then merged: a final scrub of the
`EFFORT_SCRUB_WORDS` list without word boundaries (one IOD row had kept a
host name inside a regular expression); on `foundation`, the commands that
matched a SAW pattern (no SAW ran there: heredocs and greps) re-labelled
`other`, and six runs of a CI wait script `ci-wait`; on the IOD, the
`other` rows that are polls re-labelled `poll-wait`, as the extractor now
does.

## Categories (`commands.csv`)

Assigned by the first matching pattern in `extract_effort.py`: `saw-record`
(`check-saw.sh` writing a record), `saw-check-print` (`check-saw.sh --print`),
`saw-hand` (saw run directly), `saw-experiment` (#69's harness), `gnatprove`,
`ffi`, `constant-time`, `build`, `ci-wait` (waiting on CI), `github`, `git`,
`board`, `poll-wait` (an `until ...; do sleep` loop on a background job's
output), `other`. The patterns are coarse: read the command column before
trusting a category.

**Durations:** foreground commands, from the tool call to its result.
Background commands, from the call to the completion notification; empty
when no notification was matched. The extractor of 2026-10-22 matched
only notifications in a user message, not those queued as attachments
while the agent was busy: 45 of the IOD's 77 background commands have no
duration. Fixed for the `foundation` rows (3 of 194 lack one); the IOD
transcripts were not re-extracted. A tick's wall-clock includes the time it
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
