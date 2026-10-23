# Effort analysis: obtaining each layer vs. checking it (#106)

What each layer of the result cost to **obtain** (agent work until its
proofs were green), set beside what it costs to **check** on a green tree.
The data is `agents.csv` and `commands.csv` (README), which cover the
SPARK sessions on `foundation` (aarch64) and the SAW sessions on the
x86_64 IOD. The tables come from `summarize.py`. Every number is measured;
the caveats are listed at the end.

## Sessions

| machine | session | dates (UTC) | what (memcp summary) | in the data |
|---|---|---|---|---|
| foundation | `46b31592` | 2026-10-16 | campaign planned, epics and issues #1–#24 filed, PR #25 | **no transcript** |
| foundation | `0f5e52b6` | 2026-10-18 13:23 → 10-19 19:50 | E0–E3 + M5.1: CI, FFI harness, board, AES/SHA-256/HMAC spec + impl + FFI, slow proofs, x86_64 bootstrap and margins, coverage; 25 ticks | yes |
| iod | `0f6e209a` | 2026-10-19 14:32 → 10-20 08:11 | E4: SAW of the implementations (M4.1–M4.3) and of the spec layer (M4.4, #59 gaps) | yes (PR #98) |
| foundation | `9388b3d5` | 2026-10-20 14:06 → 15:39 | review with Tony, no code: #67–#70 filed | yes (review) |
| foundation | `3cff259e` | 2026-10-20 15:40 → 20:18 | Tony's AES spec crosswalk review, plan reordered (PR #71), no code | yes (review) |
| foundation | `0022b46d` | 2026-10-20 20:18 → 10-21 15:16 | #72, #68, #74 spike, #80 generic AES, #75 prelude (two ticks), #70 (two), #67, #50 constant-time S-box; 12 ticks | yes |
| iod | `bfed13a5` | 2026-10-21 14:16 → 10-22 12:23 | SAW re-obtained after those changes (ticks A, B, E), #67 `Parse` (C), #69 cost analysis (D), #50 on x86_64 | yes (PR #98) |

A further foundation transcript, `88925fce` (2026-10-18, 4 minutes: a fix
to the machine's shell setup, not campaign work), is left out. The
planning session of 2026-10-15 on hex, and the hex sessions from
2026-10-22 on (#51, #113 and later), are not covered.

## Effort per layer

Each tick (a subagent with its own worktree) is assigned the layer it
worked on (`LAYERS` in `summarize.py`, with the tick's issue):

* **spec**: the SPARK spec layer written from the Cryptol (M1.1–M1.3,
  M2.1–M2.2, M3.1);
* **spec-properties**: the AES Cryptol properties proved on the spec
  layer (M1.5, #12), whose `SBoxCorrect` is the slow unit;
* **impl**: the implementation and its gnatprove proof against the spec
  (M1.4, M2.3, M2.4, M3.2, and the board-rows tick that added the
  executable counterparts);
* **ffi**: the FFI properties (M0.3 harness, AES spec, SHA-256/HMAC, AES
  impl export);
* **saw-impl**: the SAW proofs of the implementations (M4.1 spike, M4.2,
  M4.3);
* **saw-spec**: the SAW proofs of the spec layer (M4.4, #59 gaps, and
  tick C, `Parse`, a spec-layer proof added later);
* **spec-change**: the changes after the 2026-10-20 review, each made
  and re-proved by gnatprove (#72, #68, #74, #80, #75 ×2, #70 ×2). Each
  tick designed and wrote its change as well as re-proving it, and the
  data cannot split the two. The ticks also edited the SAW contracts their
  change touched (unverified until the IOD session), so part of SAW's
  upkeep is in this layer;
* **saw-follow**: SAW brought back in line after those changes (ticks A,
  B; E, the record re-written). It made no change of its own;
* **infra**: CI, Cryptol build, levels and board, restacks, slow-proof
  machinery, bootstrap, #67's board kinds;
* **other**: coverage, constant time (#50, both machines), the #69
  analysis, the x86_64 proof-margin investigation (#54, later dropped),
  docs pages, two unnamed helpers;
* **orchestration**: the orchestrator sessions (choosing ticks, briefing
  them, verifying each tick's claims, merging), per machine;
* **review**: the two sessions with Tony.

Columns: **wall-clock**, from the transcript's first event to its last,
summed over the layer's transcripts (ticks ran in parallel, so these are
agent-hours, not elapsed time). **Silent**: gaps of over 30 minutes in
which none of the transcript's commands was running (a tick idle after
its report or resumed later; an orchestrator waiting on ticks or on
Tony). **Waiting on tools**: per transcript, the union of the time its
commands of a tool category ran, foreground or background, so a
background run and the poll that waits on it count once; the per-tool
columns are the same union per tool (they can overlap each other, so
they need not add up to the total). **Rest** = wall-clock − silent −
waiting on tools: the agent's own work (reading, writing, thinking,
short commands). Tokens are the assistant's output tokens only.

| layer | transcripts | wall-clock h | silent h | tool calls | output tokens | waiting on tools h | gnatprove h | ffi h | saw h | ci-wait h | build+ct h | poll-wait h | rest h |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| spec | 6 | 1.32 | 0.00 | 538 | 72552 | 0.42 | 0.10 | 0.00 | 0.00 | 0.31 | 0.01 | 0.00 | 0.90 |
| spec-properties | 1 | 3.08 | 0.00 | 162 | 26066 | 2.80 | 1.09 | 0.00 | 0.00 | 1.71 | 0.01 | 0.00 | 0.28 |
| impl | 5 | 3.87 | 0.00 | 601 | 92354 | 2.53 | 1.16 | 0.41 | 0.00 | 1.07 | 0.03 | 0.00 | 1.34 |
| ffi | 4 | 4.63 | 0.00 | 611 | 56182 | 3.71 | 0.36 | 1.70 | 0.00 | 2.10 | 0.01 | 0.18 | 0.92 |
| saw-impl | 3 | 8.89 | 4.71 | 474 | 90022 | 3.25 | 0.00 | 0.00 | 0.67 | 2.26 | 0.00 | 0.31 | 0.94 |
| saw-spec | 3 | 14.22 | 0.00 | 777 | 151553 | 12.08 | 0.00 | 0.00 | 11.25 | 0.83 | 0.00 | 0.00 | 2.14 |
| spec-change | 8 | 12.26 | 0.00 | 1699 | 248396 | 10.60 | 6.78 | 0.69 | 0.00 | 3.33 | 0.01 | 0.00 | 1.66 |
| saw-follow | 3 | 8.19 | 0.00 | 359 | 21729 | 7.54 | 0.00 | 0.00 | 6.80 | 0.74 | 0.00 | 0.00 | 0.65 |
| infra | 8 | 8.98 | 0.00 | 1229 | 190928 | 7.47 | 1.85 | 0.62 | 0.00 | 5.01 | 0.00 | 0.00 | 1.51 |
| other | 8 | 8.94 | 1.50 | 1074 | 114921 | 5.38 | 1.10 | 0.09 | 1.06 | 3.28 | 0.11 | 0.00 | 2.06 |
| orchestration, foundation | 2 | 49.41 | 40.13 | 400 | 830921 | 2.35 | 0.13 | 0.10 | 0.00 | 2.13 | 0.00 | 0.00 | 6.93 |
| orchestration, iod | 2 | 39.77 | 31.86 | 310 | 661478 | 3.77 | 1.05 | 0.00 | 2.47 | 0.20 | 0.05 | 0.00 | 4.14 |
| review | 2 | 6.19 | 3.71 | 145 | 353596 | 0.02 | 0.00 | 0.00 | 0.00 | 0.01 | 0.00 | 0.00 | 2.45 |

**What it says.**

* **Writing the SPARK spec layer was the cheapest layer**: six ticks,
  1.32 agent-hours, 0.90 h of it the agent's own work. It was written
  from the Cryptol with little tool time (0.10 h gnatprove).
* **Everything after the spec was mostly waiting on tools.** The
  implementation and its proof spent 2.53 of 3.87 h waiting (gnatprove
  1.16 h, CI 1.07 h); the FFI properties 3.71 of 4.63 h; the SAW spec
  layer 12.08 of 14.22 h, 11.25 h of it SAW; the spec changes 10.60 of
  12.26 h (gnatprove 6.78 h, CI 3.33 h); the SAW follow-up 7.54 of 8.19 h
  (SAW 6.80 h).
* **SAW cost more to obtain than SPARK's spec and implementation
  together**: 23.1 agent-hours for saw-impl + saw-spec (18.4 h less the
  silent gaps), against 8.27 h for spec + spec-properties + impl. The
  SAW spec layer alone is 14.22 h; the implementations' 8.89 h (4.18 h
  without M4.3's idle tail) include M4.1, the spike that set up the
  whole SAW pipeline (GNAT-LLVM bitcode, the secondary stack, the
  record).
* **The two "after a change" layers are not comparable, and say nothing
  about which tool costs more to maintain.** spec-change (12.26 h) is the
  cost of *making* the review's changes (the generic AES spec, the Cryptol
  prelude, a narrower index type, a cheaper `SBoxCorrect`) and re-proving
  them; saw-follow (8.19 h) is only the cost of bringing SAW back in line
  afterwards, and some of that is inside spec-change (the SAW contract
  edits) and some is missing (the IOD's undercounted background waits,
  below). What is comparable is the machine time: 6.78 h of gnatprove
  against 6.80 h of SAW. One structural difference: a SAW record is all or
  nothing, so any change to one of its inputs costs a full record (about
  an hour, two for the long one), where gnatprove's gate re-proves only
  what changed.

## Obtain vs. check

Check costs on a green tree, from the tools' own records:

* **gnatprove, the default gate** (the whole crate: spec, properties
  other than the slow unit, implementation): about 530 s cold on
  `foundation` at `-j4` (`PLAN.md`, the #74 spike: 530 s on `main`, 537 s
  with the generic); about 550 s on hex at `-j8`, as reported from the
  2026-10-23 hex session (no committed record).
* **gnatprove, the slow unit** `SBox_Entries` (`SBoxCorrect`): 493 s on
  `foundation` (`-j6`, idle pool) and 28m24s cold in CI, since PR #86
  (before it: 1148 s and 1h40m47s).
* **FFI** (spec vs. Cryptol by testing, 147 properties): the CI job runs
  about 8–16 min (`PLAN.md`: 7m35s to 14m34s for identical code, runner
  noise).
* **SAW**, `spark/saw/results.txt` (`5bf56ac`, one core, x86_64): 3543 s
  in all, of which `aes_impl.saw` 4 s, `sha256_impl.saw` 31 s,
  `aes_spec.saw` 395 s, `sha256_spec.saw` 2352 s; the remaining 761 s
  are the bitcode build and the 20 negative controls. Long record
  (`results-long.txt`, `babab6f`): 7819 s, `sha256_spec.saw` 6614 s.

| layer | obtain: agent-hours (less silent) | of which its checker ran | check on a green tree | obtain ÷ check, wall-clock | checker time ÷ one check |
|---|---|---|---|---|---|
| SPARK spec | 1.32 h | gnatprove 0.10 h | in the gate (530 s, whole crate) and the FFI job | — (shared check) | — |
| SPARK spec-properties (#12) | 3.08 h | gnatprove 1.09 h | slow unit: 493 s local, 28m24s cold CI | 22× (vs. 493 s) | 8 |
| SPARK impl + proof | 3.87 h | gnatprove 1.16 h | the gate: 530 s | 26× | 8 |
| SPARK spec + impl, together | 5.19 h | gnatprove 1.26 h | the gate: 530 s | 35× | 9 |
| FFI properties | 4.63 h | FFI 1.70 h | FFI job: about 8–16 min | 17–35× | 6–13 |
| SAW impl | 8.89 h (4.18 h) | SAW 0.67 h (undercounted, below) | 35 s (4 + 31) | 430× (less silent) | ≥ 69 |
| SAW spec layer | 14.22 h | SAW 11.25 h | 2747 s (395 + 2352); long 7009 s | 19× | 15 |
| spec changes, made and re-proved (SPARK) | 12.26 h | gnatprove 6.78 h | gate + slow unit: 530 + 493 s | 43× | 24 |
| SAW re-proof after those changes | 8.19 h | SAW 6.80 h | the record: 3543 s | 8× | 7 |

"Checker time ÷ one check" is the time the layer's own checker ran
during obtaining, in units of one check of that layer on a green tree.
It is not a count of runs: the runs during obtaining were partial
(`-u` one unit, `SAW_LAYERS=impl`, one script), repeated, and on a
foundation pool shared with parallel ticks.

**What it says.**

* **Checking is cheap beside obtaining on every layer**: 8× to 43×
  wall-clock, except the SAW implementation proofs (430×), whose check is
  35 s while their obtaining included building the SAW pipeline.
* **The two tools check in very different times for the same
  algorithms.** gnatprove checks the whole crate in about 9 minutes
  (plus 8 for the slow unit); SAW takes 35 s for the implementations and
  46 minutes for the spec layer (2 h long). The FFI checks the spec
  against the Cryptol by testing in 8–16 min.
* **SAW's obtain cost follows its check cost.** The SAW spec layer's
  obtaining was 79% SAW time (11.25 of 14.22 h), about 15 checks' worth;
  the SAW follow-up was 83% SAW time. A layer whose check takes 46
  minutes is expensive to iterate on, whatever the agent's own effort
  (2.14 h of rest).
* **gnatprove during the spec changes was the most tool time of any
  layer** (6.78 h: about 46 gates' worth, 24 of gate plus slow unit),
  because the review's changes (#80, #75) restructured the spec layer and
  each tick re-proved its closure, several ticks at once on one pool.

### SAW's cost by cause (#69)

From `../measurements/2026-10-22-saw-cost.md`. The spec layer has 2800
results and 2648 s of summed proof time, against the implementation's
90 results and 32.6 s (31× the results, 2.6× the time per result). The
spec layer's time, by cause (`causes.py`, each result in the first group
that matches):

| cause | results | time | share |
|---|---|---|---|
| a lemma proved again per secondary-stack base (SAW cannot state a symbolic one) | 937 | 1175 s | 44.4% |
| a lemma per index of a recursion | 702 | 868 s | 32.8% |
| one result per function and size | 126 | 382 s | 14.4% |
| a proof per byte value (`pgcd`, `Inverse`, `Affine`) | 768 | 175 s | 6.6% |
| the compression function's lemmas again in the lax load | 267 | 48 s | 1.8% |

The same Cryptol function costs 15× to 1055× more in time on the spec
layer than on the implementation (`step` 15×, `hash` 166×, the S-box
1055×); where the two are written alike (`SubBytes`, `MixColumns`, the
sigmas) they cost the same. The #69 analysis itself cost a tick of
1.99 h (in **other**).

## What the data cannot show

* **Only one route was taken**: Cryptol → SPARK spec layer → SPARK
  implementation proved against it by gnatprove, with the FFI testing
  the spec against the Cryptol and SAW proving both layers against the
  Cryptol alongside. There is no measurement of any alternative: SAW
  directly against a hand-written implementation without the SPARK
  proof, an implementation proved without a spec layer, a spec layer
  written in another style. Nothing here says what those would have
  cost.
* **What it supports** is the cost of each step on this route (the
  tables above), and #69's finding: SAW's cost follows the **structural
  distance** between the code and the Cryptol, not the size of the code.
  The implementation, a loop over fixed-size words, is one proof per
  function; the spec layer (unconstrained results on the secondary stack,
  unshared recursion, a byte per bit) multiplies the proofs, by up to
  1055× for one function. #69's probes measured each cause on its own;
  a spec layer rewritten along them was not measured.
* **No controlled repetition.** Each layer was obtained once, by one
  agent, in one order: the spec layer's low cost may owe to its being
  written first and close to the Cryptol, and SAW's to its coming after
  everything was proved. Several ticks ran at once on `foundation`'s
  proof pool, so gnatprove waits include contention.
* **Tony's time is not measured.** The review sessions (6.19 h wall,
  3.71 h of it silent) and the orchestrators' silent gaps include his
  decisions, but nothing separates them.

## Caveats on the data

* **Categories are coarse** (README, `extract_effort.py`'s `CATS`): the
  first matching regular expression on the command. `gnatprove` takes
  any command naming it (also greps of its output); `ffi` takes any
  command naming `cryptol`; `ci-wait` takes `gh pr view` as well as
  watches. On `foundation` no SAW ran; the 43 commands that matched a
  SAW pattern there (heredocs, greps) were re-labelled `other` at merge,
  and six runs of a CI wait script (`waitrun.sh`, which matched
  `run.sh`) `ci-wait`. The `run.sh` pattern is now anchored.
* **Polls.** An agent often started a run in the background and polled
  its output (`until ...; do sleep`, each poll capped at 10 minutes by
  the tool). These are `poll-wait`; `summarize.py` gives each the tool
  of the transcript's latest background command, a heuristic.
* **Background durations on the IOD are undercounted.** The extractor
  matched a background command's completion only in a user message; a
  completion queued as an attachment while the agent was busy was
  missed. Fixed for this extraction (the `foundation` rows: 3 of 194
  background commands lack a duration), but the IOD rows (PR #98) were
  not re-extracted: their transcripts are not on `foundation`. 45 of the 77 IOD
  background commands lack a duration (saw-impl 13, saw-spec 11,
  saw-follow 13, other 7, orchestration 1), so the IOD layers' tool
  waits are low and their **rest** high by an unknown amount.
* **Wall-clock spans the transcript**, first event to last. Agent hours
  of parallel ticks overlap; the orchestrators' spans are the sessions'
  calendar time (E0–E3: 30.5 h; E4: 17.7 h).
* **Output tokens** are the assistant's only (no input or cache tokens).

## Per transcript

| machine | session | who | description | layer | wall-clock h | silent h | tool calls | output tokens | waiting on tools h | gnatprove h | ffi h | saw h | ci-wait h | build+ct h | poll-wait h | rest h |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| foundation | 0f5e52b6 | agent-a3440681 | Tick: M1.3 Cipher/InvCipher/Main (#10) | spec | 0.19 | 0.00 | 109 | 10076 | 0.07 | 0.02 | 0.00 | 0.00 | 0.05 | 0.00 | 0.00 | 0.12 |
| foundation | 0f5e52b6 | agent-a5db082b | Tick: M2.1 SHA-2 spec (#14) | spec | 0.28 | 0.00 | 83 | 19364 | 0.06 | 0.01 | 0.00 | 0.00 | 0.04 | 0.00 | 0.00 | 0.22 |
| foundation | 0f5e52b6 | agent-a7264b6a | Tick: M1.2 KeyExpansion (#9) | spec | 0.15 | 0.00 | 93 | 4479 | 0.05 | 0.01 | 0.00 | 0.00 | 0.04 | 0.00 | 0.00 | 0.10 |
| foundation | 0f5e52b6 | agent-a83e9070 | Tick: M3.1 HMAC spec (#19) | spec | 0.29 | 0.00 | 125 | 11723 | 0.13 | 0.03 | 0.00 | 0.00 | 0.09 | 0.00 | 0.00 | 0.16 |
| foundation | 0f5e52b6 | agent-abf62d1e | Tick: M2.2 SHA-2 pad/parse/hash (#15) | spec | 0.23 | 0.00 | 62 | 11044 | 0.07 | 0.02 | 0.00 | 0.00 | 0.04 | 0.00 | 0.00 | 0.16 |
| foundation | 0f5e52b6 | agent-ac360d3b | Tick: M1.1 AES spec (#8) | spec | 0.18 | 0.00 | 66 | 15866 | 0.04 | 0.00 | 0.00 | 0.00 | 0.03 | 0.00 | 0.00 | 0.14 |
| foundation | 0f5e52b6 | agent-ad2bca77 | Tick: M1.5 AES Cryptol properties (#12) | spec-properties | 3.08 | 0.00 | 162 | 26066 | 2.80 | 1.09 | 0.00 | 0.00 | 1.71 | 0.01 | 0.00 | 0.28 |
| foundation | 0f5e52b6 | agent-a079d1ec | Tick: M2.3 SHA-256 byte refinement (#16) | impl | 0.46 | 0.00 | 81 | 14751 | 0.23 | 0.14 | 0.00 | 0.00 | 0.09 | 0.00 | 0.00 | 0.23 |
| foundation | 0f5e52b6 | agent-a25a7963 | Tick: M3.2 HMAC impl (#20) | impl | 0.84 | 0.00 | 157 | 29638 | 0.59 | 0.39 | 0.00 | 0.00 | 0.19 | 0.00 | 0.00 | 0.25 |
| foundation | 0f5e52b6 | agent-a3102908 | Tick: M1.4 AES implementation (#11) | impl | 0.58 | 0.00 | 113 | 11113 | 0.35 | 0.23 | 0.00 | 0.00 | 0.11 | 0.01 | 0.00 | 0.23 |
| foundation | 0f5e52b6 | agent-a49aa7d3 | Tick: complete remaining board rows | impl | 1.31 | 0.00 | 136 | 18598 | 1.21 | 0.26 | 0.41 | 0.00 | 0.67 | 0.00 | 0.00 | 0.10 |
| foundation | 0f5e52b6 | agent-a9a36781 | Tick: M2.4 SHA-256 streaming impl (#17) | impl | 0.68 | 0.00 | 114 | 18254 | 0.15 | 0.14 | 0.00 | 0.00 | 0.00 | 0.01 | 0.00 | 0.52 |
| foundation | 0f5e52b6 | agent-a1885e7d | Tick: AES impl FFI export (#11) | ffi | 0.73 | 0.00 | 109 | 6603 | 0.54 | 0.10 | 0.29 | 0.00 | 0.14 | 0.00 | 0.18 | 0.19 |
| foundation | 0f5e52b6 | agent-a20f3c9a | Tick: FFI for SHA-256 and HMAC | ffi | 2.41 | 0.00 | 219 | 5754 | 2.09 | 0.20 | 1.15 | 0.00 | 1.19 | 0.01 | 0.00 | 0.32 |
| foundation | 0f5e52b6 | agent-ad1bee8e | Tick: M0.3 FFI harness (#4) | ffi | 0.35 | 0.00 | 128 | 12507 | 0.15 | 0.01 | 0.01 | 0.00 | 0.14 | 0.00 | 0.00 | 0.20 |
| foundation | 0f5e52b6 | agent-aec083e4 | Tick: FFI onto real AES spec (#4, #8–#10) | ffi | 1.14 | 0.00 | 155 | 31318 | 0.93 | 0.05 | 0.26 | 0.00 | 0.62 | 0.00 | 0.00 | 0.21 |
| iod | 0f6e209a | agent-a06ea36f | M4.2 SAW AES tick (#23) | saw-impl | 1.33 | 0.00 | 162 | 35924 | 1.09 | 0.00 | 0.00 | 0.10 | 0.99 | 0.00 | 0.00 | 0.23 |
| iod | 0f6e209a | agent-a7e6b907 | M4.1 SAW spike tick (#22) | saw-impl | 1.22 | 0.00 | 126 | 11426 | 1.02 | 0.00 | 0.00 | 0.01 | 1.01 | 0.00 | 0.00 | 0.20 |
| iod | 0f6e209a | agent-ac0466c2 | M4.3 SAW SHA/HMAC tick (#24) | saw-impl | 6.34 | 4.71 | 186 | 42672 | 1.13 | 0.00 | 0.00 | 0.56 | 0.26 | 0.00 | 0.31 | 0.50 |
| iod | 0f6e209a | agent-a418d907 | #59 gaps SAW tick | saw-spec | 7.22 | 0.00 | 256 | 38068 | 6.35 | 0.00 | 0.00 | 5.52 | 0.83 | 0.00 | 0.00 | 0.87 |
| iod | 0f6e209a | agent-ab3f8564 | M4.4 SAW spec-layer tick (#59) | saw-spec | 3.31 | 0.00 | 387 | 103531 | 2.44 | 0.00 | 0.00 | 2.44 | 0.00 | 0.00 | 0.00 | 0.86 |
| iod | bfed13a5 | agent-ae15b4fa | Tick C: SAW Parse (#67) | saw-spec | 3.70 | 0.00 | 134 | 9954 | 3.29 | 0.00 | 0.00 | 3.29 | 0.00 | 0.00 | 0.00 | 0.41 |
| foundation | 0022b46d | agent-a0ce48f4 | Tick #70 cheaper SBoxCorrect | spec-change | 1.17 | 0.00 | 130 | 6955 | 1.06 | 0.69 | 0.00 | 0.00 | 0.37 | 0.00 | 0.00 | 0.10 |
| foundation | 0022b46d | agent-a65a31dc | Spike #74 generic AES spec | spec-change | 1.97 | 0.00 | 240 | 33507 | 1.70 | 1.17 | 0.00 | 0.00 | 0.52 | 0.01 | 0.00 | 0.26 |
| foundation | 0022b46d | agent-a812b736 | Tick #72 remove SPARKlib | spec-change | 1.15 | 0.00 | 126 | 9790 | 1.10 | 0.23 | 0.00 | 0.00 | 0.86 | 0.00 | 0.00 | 0.05 |
| foundation | 0022b46d | agent-aa4c1a67 | Tick #80 full AES generic | spec-change | 1.40 | 0.00 | 329 | 44894 | 1.22 | 0.85 | 0.00 | 0.00 | 0.39 | 0.00 | 0.00 | 0.17 |
| foundation | 0022b46d | agent-ab0acb6a | Tick #75 prelude + SHA-2/HMAC | spec-change | 1.91 | 0.00 | 346 | 95904 | 1.57 | 1.07 | 0.45 | 0.00 | 0.22 | 0.00 | 0.00 | 0.34 |
| foundation | 0022b46d | agent-ab79f9a4 | Tick #75 AES migration | spec-change | 2.40 | 0.00 | 267 | 38397 | 2.11 | 1.64 | 0.24 | 0.00 | 0.25 | 0.00 | 0.00 | 0.29 |
| foundation | 0022b46d | agent-adc5fb7f | Tick #70 cheap part: move sbox_entries | spec-change | 0.66 | 0.00 | 107 | 8254 | 0.33 | 0.33 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.33 |
| foundation | 0022b46d | agent-af9201bd | Tick #68 narrow Bit_Index | spec-change | 1.61 | 0.00 | 154 | 10695 | 1.50 | 0.79 | 0.00 | 0.00 | 0.71 | 0.00 | 0.00 | 0.11 |
| iod | bfed13a5 | agent-a175171e | Tick B: SAW spec-layer repair | saw-follow | 4.59 | 0.00 | 162 | 10082 | 4.17 | 0.00 | 0.00 | 3.60 | 0.57 | 0.00 | 0.00 | 0.42 |
| iod | bfed13a5 | agent-aaaef209 | Tick A: SAW impl repair | saw-follow | 0.17 | 0.00 | 115 | 7615 | 0.05 | 0.00 | 0.00 | 0.04 | 0.00 | 0.00 | 0.00 | 0.13 |
| iod | bfed13a5 | agent-abfcdb36 | Tick E: SAW record staleness fix | saw-follow | 3.43 | 0.00 | 82 | 4032 | 3.33 | 0.00 | 0.00 | 3.16 | 0.17 | 0.00 | 0.00 | 0.11 |
| foundation | 0022b46d | agent-a1200683 | Tick #67 board kinds, docs | infra | 0.80 | 0.00 | 154 | 39608 | 0.66 | 0.39 | 0.00 | 0.00 | 0.27 | 0.00 | 0.00 | 0.13 |
| foundation | 0f5e52b6 | agent-a0002a4a | Tick: on-demand slow proofs + restack #36/#41 | infra | 2.57 | 0.00 | 291 | 54689 | 2.29 | 1.29 | 0.00 | 0.00 | 1.00 | 0.00 | 0.00 | 0.27 |
| foundation | 0f5e52b6 | agent-a51e7923 | Tick: M0.4 levels and board (#5) | infra | 0.28 | 0.00 | 111 | 18498 | 0.06 | 0.03 | 0.00 | 0.00 | 0.04 | 0.00 | 0.00 | 0.22 |
| foundation | 0f5e52b6 | agent-a51fff23 | Tick: restack the spec PRs | infra | 0.41 | 0.00 | 176 | 9089 | 0.06 | 0.02 | 0.00 | 0.00 | 0.03 | 0.00 | 0.00 | 0.35 |
| foundation | 0f5e52b6 | agent-a53e6730 | Tick: x86_64 bootstrap script (#6) | infra | 3.47 | 0.00 | 163 | 32672 | 3.25 | 0.00 | 0.00 | 0.00 | 3.25 | 0.00 | 0.00 | 0.22 |
| foundation | 0f5e52b6 | agent-a6a6cdfb | Tick: restack SHA/HMAC chain onto FFI | infra | 0.49 | 0.00 | 94 | 2990 | 0.44 | 0.11 | 0.13 | 0.00 | 0.21 | 0.00 | 0.00 | 0.04 |
| foundation | 0f5e52b6 | agent-abeb7273 | Tick: Cryptol from source (#2) | infra | 0.56 | 0.00 | 69 | 4771 | 0.49 | 0.00 | 0.49 | 0.00 | 0.00 | 0.00 | 0.00 | 0.08 |
| foundation | 0f5e52b6 | agent-ad7b5bc3 | Tick 1: issue #3 CI | infra | 0.40 | 0.00 | 171 | 28611 | 0.21 | 0.00 | 0.00 | 0.00 | 0.21 | 0.00 | 0.00 | 0.19 |
| foundation | 0022b46d | agent-a3bd5bae | (none) | other | 0.06 | 0.00 | 39 | 755 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.06 |
| foundation | 0022b46d | agent-a4bd4fed | Tick #50 constant-time AES | other | 1.01 | 0.00 | 281 | 50270 | 0.75 | 0.39 | 0.00 | 0.00 | 0.49 | 0.03 | 0.00 | 0.26 |
| foundation | 0022b46d | agent-a6ac2127 | Write AES spec old-vs-new page | other | 0.15 | 0.00 | 46 | 983 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.14 |
| foundation | 0f5e52b6 | agent-a2d2e245 | Tick: M5.1 GNATcoverage (#49) | other | 1.27 | 0.00 | 137 | 15130 | 0.97 | 0.12 | 0.09 | 0.00 | 0.76 | 0.00 | 0.00 | 0.31 |
| foundation | 0f5e52b6 | agent-a4bd897a | Tick: x86_64 proof margins | other | 2.37 | 0.00 | 163 | 11417 | 2.23 | 0.53 | 0.00 | 0.00 | 1.79 | 0.00 | 0.00 | 0.14 |
| iod | 0f6e209a | agent-aef69b74 | (none) | other | 0.34 | 0.00 | 79 | 1912 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.34 |
| iod | bfed13a5 | agent-a8a83d08 | Tick: #50 x86_64 CT | other | 1.75 | 1.50 | 96 | 7398 | 0.14 | 0.06 | 0.00 | 0.00 | 0.00 | 0.08 | 0.00 | 0.12 |
| iod | bfed13a5 | agent-aa4121a9 | Tick D: SAW cost analysis (#69) | other | 1.99 | 0.00 | 233 | 27056 | 1.29 | 0.00 | 0.00 | 1.05 | 0.24 | 0.00 | 0.00 | 0.69 |
| foundation | 0022b46d | orchestrator | orchestrator session | orchestration, foundation | 18.96 | 16.45 | 117 | 186366 | 0.02 | 0.00 | 0.00 | 0.00 | 0.02 | 0.00 | 0.00 | 2.49 |
| foundation | 0f5e52b6 | orchestrator | orchestrator session | orchestration, foundation | 30.45 | 23.68 | 283 | 644555 | 2.33 | 0.13 | 0.09 | 0.00 | 2.11 | 0.00 | 0.00 | 4.44 |
| iod | 0f6e209a | orchestrator | orchestrator session | orchestration, iod | 17.66 | 11.46 | 205 | 459144 | 3.20 | 1.04 | 0.00 | 2.08 | 0.03 | 0.04 | 0.00 | 3.00 |
| iod | bfed13a5 | orchestrator | orchestrator session | orchestration, iod | 22.11 | 20.40 | 105 | 202334 | 0.57 | 0.00 | 0.00 | 0.39 | 0.17 | 0.01 | 0.00 | 1.14 |
| foundation | 3cff259e | orchestrator | orchestrator session | review | 4.63 | 3.71 | 80 | 239847 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.91 |
| foundation | 9388b3d5 | orchestrator | orchestrator session | review | 1.56 | 0.00 | 65 | 113749 | 0.02 | 0.00 | 0.00 | 0.00 | 0.01 | 0.00 | 0.00 | 1.54 |
