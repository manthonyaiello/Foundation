---
name: campaign
description: Run the Foundation SPARK campaign named in .claude/campaign/PLAN.md (AES, SHA-256 and HMAC-SHA-256 proved against the Cryptol, epics E0–E4): pick the next item from the plan, work it as a tick (a coding agent in its own worktree), open a stacked PR, verify the proof, FFI and CI results it claims, and keep going until told to stop. Use when the user says "/campaign", "continue the campaign", "next tick", or asks what the campaign should do next.
---

# The campaign

You are the **orchestrator** of the Foundation SPARK campaign. **Its issues,
its order and its decisions are in `.claude/campaign/PLAN.md`.** Where the plan
states a campaign-specific rule, it takes precedence over this file. You choose
the work, launch it, verify what comes back, and keep the board honest.

A tick is **one coding agent in its own worktree**, reading `agent-brief.md`
beside this file. It writes the SPARK, the FFI properties and the proof, and it
opens the PR. You do not write the code.

**Tony merges. The campaign never merges.**

## Continuing

On "continue the campaign" / "/campaign", in this order:

1. **Read the plan: `.claude/campaign/PLAN.md`.** It is the single planning
   document: the board, the queue, the decisions taken, and what is open for
   Tony. It is rewritten at every stop, so it should read cold.
2. **Read the real board**, never the plan's copy of it. Once M0.4 exists,
   that is `spark/scripts/board.py` run on the stack head (or `main` if nothing
   is open), plus the trust manifest. Before then, it is the gnatprove output
   and `check-ffi.sh` output of the last PR, read from its CI run.
3. **Check what `main` is and what is open.** `git fetch origin --prune`,
   `git log --oneline -1 origin/main`,
   `gh pr list -R manthonyaiello/Foundation`, `git worktree list`. A plan that
   says "N PRs open" may describe a world Tony has since merged.
4. **Check the machine.** `spark-scheduler status`. Other sessions
   (spark-houdini, spark-corpus, spark-iglm, spark-mc) prove through the same
   pool. That does not stop a tick, but it goes in the tick's wall-clock note,
   and a proving tick does not start while another of *this* campaign's
   proving runs is live. For an x86_64 tick, ask Tony when the instance's 24
   hours started, and do not launch a tick that cannot finish and push inside
   them.
5. **Check the next item's premise before building on it.** These issues were
   filed together before any of them was built. **Read them with
   `--comments`**, and read the PR that landed the item below: the interface
   as built is the contract, not the interface as filed.
6. **Pick, say why, and go.** Take the front of the plan's queue. Announce the
   tick and launch it. Do not ask which item unless the plan's order is
   genuinely ambiguous or the premise failed.

Then keep going: verify the PR, save memcp, pick the next item, launch the next
tick. **Work until Tony asks for a stopping point.** Do not stop after one tick
to ask whether to continue.

## A code tick

One agent, one worktree, one PR. **One proving tick at a time on hex.** Prover
capacity is pooled through `spark-scheduler`, so two runs would not corrupt
each other outright. But GNATprove's `--level` is a wall-clock timeout, so a
loaded machine can turn a slow proof into an unproved check, and two ticks'
results on one board cannot be attributed to one change. A tick on the x86_64
instance (M0.5, E4) may run alongside a hex tick.

Launch the coding agent (`general-purpose`, no model override) with a prompt
that says:
* the issue number and the BASE branch with its sha;
* the branch and worktree names (`issue-<n>-<slug>`, under `.claude/worktrees/`);
* the board as you counted it on the BASE;
* a scratchpad path;
* which machine (hex, or the x86_64 instance and when it dies);
* anything the plan says about this item.

Tell it to read `.claude/skills/campaign/agent-brief.md` first.

**Stacking.** The first tick targets `main`. Each later tick branches from
the tick below it and targets that branch, so its delta is attributable to it
alone. Say the BASE and its sha in the PR. Independent epics may stack
separately (an E4 tick on the x86_64 machine need not sit on top of an E2
tick), and the plan says when they do.

**When an agent stalls** (dropped network, watchdog), do not restart it.
Inspect the worktree yourself (`git log`, `git status --porcelain`, whether the
branch is pushed), then resume it with SendMessage, pasting the state you
verified. Tell it to commit in small working increments, so the next stall
costs nothing. On the x86_64 instance, a stall near hour 24 means the
instance may be gone: what is pushed is all there is.

## What to run, and what not to re-run

A whole-crate proof is cheap now and will not stay cheap. Scope local runs to
what the change can have moved, and let CI run the whole gate.

| what the tick changed | trust gate | proof (local, through the pool) | `check-ffi.sh` |
|---|---|---|---|
| docs, README, skills, the plan | no | **none** | **none** |
| CI workflows or gate scripts | yes | the scaffold, to show the gate still runs | if the FFI job changed |
| a new spec-layer unit | yes | that unit | its new properties, plus all existing ones (cheap) |
| a new implementation or refinement unit | yes | that unit and the spec units it is proved against | the impl exports, plus all existing ones |
| a shared unit (root package, common types, FFI shims) | yes | **every unit on the board** (a control run) | all |

CI runs the full proof gate on every PR regardless. **A skip is stated in the
PR with its reason.** A silent omission and a deliberate one must not look the
same in review.

## Reading the board

* **The unit of progress is the function, completed.** A row is complete when
  its spec exists and is FFI-checked, its implementation is proved with zero
  unproved checks, and its unit has no trust-surface entries beyond its FFI
  shims. Always report completed rows, and the denominator: the rows in the
  plan.
* **Always state the hole counts**: unproved checks, `assume`s,
  justifications, `SPARK_Mode => Off` regions, warning suppressions. A count of
  zero is stated as zero.
* **An FFI result is a test count, not a proof.** Say `:exhaust` or `:check`,
  and N. Never write "verified against the Cryptol" for a `:check`.
* **Level is part of the verdict.** A proof at a level other than the unit's
  committed one is not comparable, and must say so.

## Verifying what comes back

Do not relay an agent's report as fact. Check, at minimum:
* **The PR, through the API, twice**: `state`, `mergeable`, `mergeStateStatus`,
  `headRefOid`, `baseRefName`
  (`gh pr view <n> -R manthonyaiello/Foundation --json state,mergeable,mergeStateStatus,headRefOid,baseRefName`).
  **It is on the fork**, not on `NationalSecurityAgency/Foundation`.
* **CI is green on that head**: `gh pr checks <n> -R manthonyaiello/Foundation`.
  A pending check is not green. Wait for it.
* **The results match the head.** The proof and FFI numbers in the PR came
  from the head commit, not an earlier one. `git diff <results commit> <head> --
  spark/src spark/cryptol` is **empty**.
* **No hole slipped in.** `git diff <BASE> <head> -- spark/scripts/trust-surface.txt
  spark/scripts/proof-xfail.txt` is empty, or each added line is named and
  justified in the PR and is one the issue allows.
* **The FFI check checked SPARK.** One property, run by hand, against a
  deliberately wrong input or with the library moved aside, fails. (A
  property that compares the Cryptol with itself passes everything.)
* **One claim by hand.** Rerun the proof of one unit the tick claims (through
  the pool), and read its gnatprove output.
* **The spec reads like the Cryptol.** Open one spec function next to the
  `.cry` it mirrors. The faithfulness decision is a reading claim as much as a
  testing one.

Say plainly what you did **not** verify.

## After each tick

Save one memcp summary for the session (a tick's agent is forbidden to). Record:
* the PR, its state and its CI;
* the board before → after, with the hole counts;
* what was skipped and why;
* the prover's wall-clock, the level, and whether the machine was shared;
* what the next tick must know, especially wherever the interface as built
  differs from the issue as filed, or a decision in the plan did not survive
  (unconstrained arrays for AES is the one to watch).

Then re-rank the queue in `PLAN.md` if the tick priced something: M1.1–M1.4
calibrate the cost of everything after them.

## Stopping: rewrite the plan, every time

A campaign ends one of two ways: it reaches a natural point, or **Tony
interrupts it**. Both end the same way. Before the session closes, **rewrite
`.claude/campaign/PLAN.md`** so that the next session can start cold from it.
This is not optional, and it is not a summary of what happened (memcp is
that). The plan is the *next* session's starting state:
* **The board**, re-counted on the stack head, with the provenance header
  updated: the date, the commit it was counted on, what `main` is, and what is
  open and mergeable.
* **The queue**, re-ranked against that board, with the "not yet" entries and
  why they are deferred.
* **The decisions**, with what was settled appended. A decision a tick
  disproved is rewritten, not carried.

Also refresh **Open for Tony** and **Live ambushes**, and delete what is no
longer true.

If the interruption is abrupt, the minimum is the provenance header, the
board, and one line naming what was in flight.

Never start a numbered plan. There is one `PLAN.md`, and its history is git's.
Commit the rewrite on the stack head's branch, or on a branch of its own if
nothing is open.

## Decisions already taken

They live in `PLAN.md` under **Decisions taken — do not re-ask**. Do not keep
a second copy.
