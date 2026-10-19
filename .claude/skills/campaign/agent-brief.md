# Brief for a campaign coding agent

You are working one GitHub issue in the Foundation fork (NSA's Cryptol
specifications, plus our SPARK crate in `spark/` that is proved against them)
as one **code tick** of the campaign in `.claude/campaign/PLAN.md`. **Read
the plan, especially "Decisions taken", and its entry for your item.** Where
it differs from this brief, the plan wins.

Your orchestrator gave you:
* the issue number, the BASE branch and its sha;
* your branch and worktree names;
* the board as counted on the BASE;
* a scratchpad path;
* the machine: `foundation` (the long-lived aarch64 container), or the
  x86_64 IOD instance and when it dies (see "Machines" in the plan).

Read `gh issue view <N> -R manthonyaiello/Foundation --comments`, the
comments and not just the body, and the parent epic. These issues were filed
together before any was built. Where the PR that landed the item below you
settled something differently from the issue text, **the PR is the
contract**. Read it before building on it.

The repository's working conventions are in `.claude/skills/issue/SKILL.md`.
Read it. It covers what finishes an issue, what "close to the Cryptol"
means, building in a worktree, the toolchain path, the FFI's silent-fallback
trap, and proving through the pool.

House style is visible in `git log` and in the NSA specs' own comments:
* cite the `.cry` file (and the FIPS/RFC section the Cryptol cites) for every
  spec-layer declaration;
* measured numbers, never projected ones: checks proved, tests run;
* name what is proved and what is not;
* say what was skipped and why;
* no wall-clock estimates for future work in durable docs.

## Where and how

* The main checkout is `/work/Foundation` on `foundation`, or the bootstrap's
  clone on the IOD. **Never commit on `main`, never merge (the orchestrator
  merges), never touch another agent's worktree.**
* **Never modify the NSA side**: `algorithms/`, `shared/`, `packaging/`,
  `.ci/`, `.devcontainer/`, NSA's `.github/workflows/*`. Our files are
  `spark/`, `.claude/`, and our own `.github/` files (`spark-*.yml`, our
  actions, `CODEOWNERS`, the PR template).
* Create the worktree with
  `git -C <main checkout> worktree add .claude/worktrees/<name> -b <branch> origin/<BASE>`,
  and work only inside it.
* **Bash: one plain command per call.** No `&&`, `;`, loops, or heredocs into
  scripts. The auto-mode classifier blocks them unpredictably. Use
  Read/Grep/Edit/Write for files. Commit with `git commit -F <file>` after
  writing the message with Write. Use `git -C` or `env -C <worktree>` rather
  than `cd`. zsh treats a word starting with `=` as a command lookup, so
  quote any such word.
* **Commit in small working increments.** The network drops, and a stall
  should lose only uncommitted work. **On the x86_64 instance, push after
  every commit**: it dies 24 hours after it starts.
* Scratch goes in your scratchpad path, under `issue-<N>/`.

## Setting up the worktree

The Alire workspace is gitignored, so a fresh worktree has none. From the
worktree's `spark/`:

```
alr -n build
```

Always `alr -n`. Confirm `gnatprove --version` is FSF 16.1.0. On `foundation`
the toolchain is already on PATH. On the IOD, source the `env.sh` the
bootstrap script (`spark/scripts/bootstrap-x86_64.sh`) writes.

## Writing the SPARK

* **The spec layer mirrors the Cryptol** at minimal semantic distance: the
  same types (ghost Boolean arrays where the Cryptol has bits), the same
  iteration structure (`foldl` as a recursive ghost fold, recursive
  definitions as recursive ghost functions with a `Subprogram_Variant`), the
  same names, the same parameterization (a generic where the Cryptol module is
  parameterized). Representation changes are never in the spec layer.
* **The implementation layer** is ordinary executable SPARK, with
  postconditions stating equality with the spec layer.
* **No holes.** No `pragma Assume`, no `pragma Annotate (GNATprove, ...)`, no
  `SPARK_Mode => Off`, no warning suppression, in spec or implementation units.
  If you cannot avoid one, stop, add it to the trust manifest with its
  reason, report it as a hole, and leave the issue open. Never add to
  `proof-xfail.txt`.
* **Lemmas** are ghost procedures with contracts. Prefer a lemma with a
  clear statement to a long chain of `pragma Assert`s in a loop.

## Proving

* **On `foundation`, every prover call goes through the scheduler**, with
  `prove.sh` or `check-proof.sh` as the child and `{tokens}` as the job count:
  `spark-scheduler run --up-to 6 --key 'foundation|<unit or crate>' --strategy prove --variant spark --level <n> -- env -C <worktree>/spark PROVE_JOBS={tokens} scripts/prove.sh [-u <file>]`.
  **Start the command with `spark-scheduler`**, with no `cd` or `&&` in front:
  the permission allow rules match on that prefix. Quote the grant in the PR.
* **On the IOD** there is no scheduler: run `PROVE_JOBS=$(nproc)
  scripts/check-proof.sh` directly. The tick is the machine's only user.
* **Slow units** (`spark/scripts/proof-slow.txt`) are skipped by the gate and
  proved on demand with `scripts/prove-slow.sh`. If you change one of their
  inputs, the gate fails STALE: re-run `prove-slow.sh` and commit its
  manifest update.
* **Levels.** Prove at the unit's committed level. Never lower it to get a
  green run. Raising it is allowed, in the GPR, with the reason in the
  commit.
* **One proving run at a time.** Background a long run
  (`run_in_background: true`) and wait for its completion notification.
  **Never arm a shell loop to watch it.**
* **A run that proved nothing looks like a run that passed.** Before quoting
  a result, check that the units you expect appear in gnatprove's output.

## Checking against the Cryptol

* Every new spec-layer function gets a property in `spark/cryptol/` against
  the NSA function it mirrors, run by `spark/scripts/check-ffi.sh` (M0.3).
  `:exhaust` when the domain is at most 2^16. Otherwise `:check` with an N you
  state. Known-answer vectors (`Tests.cry`, FIPS appendices, RFCs) go through
  the SPARK functions too.
* **Show that the check checks SPARK.** Once per PR, break one property's
  SPARK side on purpose (or move the library aside) and show it fails. Then
  restore it.

## What a change must carry

1. **Proof numbers**: the board rows for your units (proved / unproved, and
   the trust-surface entries), at the committed level, from the head commit.
2. **FFI numbers**: per property, `:exhaust` or `:check`, and N.
3. **CI green** on the PR's head: the trust, docs and proof gates and the FFI
   job. Every new declaration has a GNATdoc comment, and a spec-layer comment
   names the `.cry` declaration it mirrors.
4. **Controls**: if you touched a shared unit (root package, common types,
   FFI shims, scripts), every unit already on the board, re-proved, and every
   FFI property, re-run. A lost proof is a regression and is reported as one.
5. **Commits**: a subject that states the finding, in the style of `git log`,
   with the issue number. A body explaining it. End with
   `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Opening the PR

Rebase first: `git fetch origin`, then `git rebase origin/<BASE>` if it moved,
and re-run what the rebase touched. Push your branch to `origin`.

**The PR goes on the fork.** `gh pr create` on a fork defaults to the
upstream, NSA's repository, which must never receive a PR from this campaign.
Always:

```
gh pr create --repo manthonyaiello/Foundation --base <BASE> --head <branch> --title <title> --body-file <file>
```

Write the body with Write first. Fix a bad create with `gh pr edit`, never a
second create.

The description carries:
* `Closes #N.` (or `Part of #N.`);
* the stack line: `Part of the SPARK campaign: targets <BASE> (PR #<k>) at <sha>.`;
* what landed, with the `.cry` files it mirrors;
* the board before → after, with the hole counts (zero stated as zero);
* the FFI properties and their test counts;
* what was proved where (`foundation` or the IOD), at what level, and the
  wall-clock;
* every skip, with its reason;
* what was left, and why;
* as its last line: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

Verify through the API **twice**:
`gh pr view <n> -R manthonyaiello/Foundation --json state,mergeable,mergeStateStatus,headRefOid,baseRefName`,
and `gh pr checks <n> -R manthonyaiello/Foundation` until no check is
pending.

**Do not merge. Do not push to any branch but your own. Do not call any memcp
tool**: the orchestrator saves session memory.

## Reporting back, under 800 words

Include:
* the PR number, branch, head sha, and the BASE with its sha;
* whether the premise held on the BASE;
* the board before → after, with the hole counts;
* the FFI properties and their test counts;
* CI's state on the head;
* where the interface as built departs from the issue as filed, and any plan
  decision that did not survive;
* what was proved, at what level, its wall-clock, and whether the machine was
  shared;
* every skip;
* issues you filed;
* anything the orchestrator must know before the next tick.

If an item balloons (roughly three hours with nothing provable), stop, keep
what works, commit it, and say so. **Finishing most of an issue well beats
finishing none of it.**
