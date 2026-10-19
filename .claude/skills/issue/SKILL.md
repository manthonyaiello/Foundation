---
name: issue
description: Work a Foundation (SPARK-against-Cryptol) GitHub issue end to end in an isolated worktree. Fetches the issue, creates a worktree under .claude/worktrees, does the work, proves it with gnatprove through spark-scheduler, checks it against the Cryptol through the FFI, opens a PR, and saves a summary to memcp. Use when the user says "/issue <number>" or asks to work on a specific issue by number.
---

# Work a GitHub issue

Fetch issue #$1 from `manthonyaiello/Foundation`, set up a worktree in
`.claude/worktrees` for it, move to the worktree, do the work, open a PR with
the results, and save a summary to memcp. If you have questions, ask them as
needed, but try to get as much done with reasonable assumptions as possible.

## What this repository is

A fork of NSA's Foundation: Cryptol specifications (`algorithms/`,
`shared/`), SAW proofs, and Rust behind a few fixed-size primitives. Ours is
`spark/`, an Alire crate of SPARK implementations proved platinum against a
SPARK spec layer that mirrors the Cryptol. The plan, the decisions and their
reasons are in `.claude/campaign/PLAN.md`. Read its "Decisions taken" before
designing anything.

**Never modify the NSA side**: the `.cry` files, the SAW scripts, the Rust,
the `.dylib`/`.so` files beside the specs, the CI. Our Cryptol lives in
`spark/cryptol/`. If an NSA spec looks wrong, say so in the PR and in an issue.
Do not fix it here.

## What finishes an issue

An issue is not done when the code compiles. It is done when it has a
**proof result and an FFI result**, both stated as numbers in the PR:

1. **gnatprove**: every check in the issue's units is proved, at the unit's
   committed level (the GPR's `Prove` package), through the scheduler. Quote
   the `board.py` rows: proved / unproved / justified / assumed.
2. **No new holes.** No `pragma Assume`, no `pragma Annotate (GNATprove, ...)`
   justification, no `SPARK_Mode => Off`, no warning suppression, in a spec or
   implementation unit, unless the issue explicitly allows it. The trust gate
   (`spark/scripts/check-trust-surface.sh`, M0.2) enforces this against
   `spark/scripts/trust-surface.txt`. Adding a manifest line satisfies the gate
   and not this rule. The only expected entries are the FFI export shims. A
   hole you could not avoid is reported as a hole, with its reason, and the
   issue stays open.
3. **FFI**: every new spec-layer function has an equivalence property in
   `spark/cryptol/` against the NSA Cryptol function it mirrors, run by
   `spark/scripts/check-ffi.sh`. Quote, per property, `:exhaust` or
   `:check` and the number of tests run. Use `:exhaust` when the domain is
   ≤ 2^16, and say why when you did not.
4. **Known answers**: wherever `Tests.cry`, a FIPS appendix or an RFC gives
   vectors, they go through the SPARK functions too.

5. **Documented.** Every new declaration carries a GNATdoc comment (the docs
   gate, M0.2, fails on an undocumented entity or a doc block on the wrong
   declaration). A spec-layer comment names the `.cry` declaration it mirrors.
6. **CI green** on the PR's head (`gh pr checks <n> -R manthonyaiello/Foundation`).
   It is necessary, not sufficient: CI's proof runs on a slower runner than
   `foundation`, so a proof that passes locally and times out in CI is a failure to fix (raise
   the unit's level, or simplify the proof), not to explain away.

The issue body's "Done when" adds to this list, never subtracts. Until M0.2–M0.4
land, what they automate is done by hand, and the PR says how.

## The spec layer: what "close to the Cryptol" means

Minimal *semantic* distance, not just syntactic. Where the Cryptol has a bit
sequence, the spec has a (ghost) Boolean array. Where it has `foldl`, the spec
has a recursive ghost fold. Where it has `W@t` defined by recursion, the spec
has a recursive ghost function with a `Subprogram_Variant`. Where it is a
parameterized module, the spec is a generic. Name things as the Cryptol does
(`SubBytes`, `step3`, `SIGMA_256_0`) and cite the `.cry` file and line in a
comment. A reader should be able to check the spec against the Cryptol by eye.
The FFI check is the machine check of that same claim.

Representation changes (bits to bytes, streaming, in-place state) never go in
the spec layer. They are their own layer, with their own proof.

## Four things that go wrong in a worktree

**Name the repository to `gh`.** Pass `-R manthonyaiello/Foundation` to every
`gh` command. The upstream is `NationalSecurityAgency/Foundation`: **never
open a PR or issue there.** `gh pr create` defaults to the upstream of a fork.
Pass `--repo manthonyaiello/Foundation --base <BASE>` explicitly.

**Build inside the worktree.** `spark/obj/`, `spark/lib/`, `spark/alire/` and
`spark/config/` are gitignored, so a fresh worktree has no Alire workspace. Run
`alr -n build` from the worktree's `spark/` (always `-n`: without it, alr may
wait on a prompt forever).

**The toolchain.** On `foundation`, alr, gnatprove and Cryptol are on PATH
(`~/.local/bin/cryptol` was built from source). On the x86_64 IOD, source the
`env.sh` that `spark/scripts/bootstrap-x86_64.sh` writes. Confirm with
`gnatprove --version` (FSF 16.1.0).

**Cryptol must load our library, not fall back.** Cryptol finds a `foreign`
function's library by the module file's name, beside the file. In Cryptol 3.6
a body-less `foreign` whose library is missing still *loads* (with a warning),
and only its calls fail; NSA's foreign-with-body modules silently run their
Cryptol body. `check-ffi.sh` therefore requires the "Loading dynamic library"
line for each of our modules and fails if any NSA module loads a library.
Never give a `spark_*` foreign a body, and always name a property's type
parameters (`` `{k} ``, `` `{l} ``) explicitly: `[l /^ 8][8]` does not fix `l`.

## Proving

* **Through the scheduler, on `foundation`.**
  `spark-scheduler run --up-to 6 --key 'foundation|<unit or crate>' --strategy prove --variant spark --level <n> -- env -C <worktree>/spark PROVE_JOBS={tokens} scripts/prove.sh [-u <file>]`
  (or `scripts/check-proof.sh` for the gate). The scheduler substitutes the
  grant for `{tokens}`. Start the command with `spark-scheduler`: the
  permission allow rules match that prefix. `spark-scheduler status` shows
  who else is proving; that goes in the PR's wall-clock note.
* **On the x86_64 IOD**, the tick is the only user: `PROVE_JOBS=$(nproc)
  scripts/check-proof.sh` directly, and **every commit is pushed at once**:
  the machine dies 24 hours after it starts, and nothing unpushed survives.
* **Slow units** in `spark/scripts/proof-slow.txt` are proved on demand
  (`scripts/prove-slow.sh`); the gate checks their input fingerprint.
* **Levels.** Each unit proves at its committed level. Do not lower one to go
  faster, and do not quote a result at another level as if it were the result.
  Raising a unit's level is allowed. It goes in the GPR in the same PR, with
  the reason.
* **A run that proved nothing looks like a run that passed.** Check the board's
  unit count against the units you expect before quoting it.

## Finishing

Report plainly: what is proved, what is not, every hole, every FFI property
and its test count, and what was skipped and why. A null or partial result is
reported as one. If the issue's premise turns out wrong (a decision in
`PLAN.md` that does not survive contact, such as unconstrained arrays for
AES), say so in the PR, leave the issue open with what was learned, and flag
it for Tony.
