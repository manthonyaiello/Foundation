# The campaign plan: SPARK AES, SHA-256 and HMAC against the Cryptol

**Provenance.** Started 2026-10-16, before any issue was built. `main` is
`a24edbf` (the crate scaffolding). Nothing is open. The issues are
filed on `manthonyaiello/Foundation` as five epics with GitHub
sub-issues, #1–#24 (table below). Milestone ids (M1.4) are in the issue
titles and are how the issues refer to each other.

**A fresh session starts at "Next".**

## What the campaign is

Foundation (NSA's Cryptol specifications, forked) has Cryptol specs and
SAW proofs, and Rust behind a few fixed-size primitives. This campaign
adds SPARK implementations of AES, SHA-256 and HMAC-SHA-256, proved
**platinum**: every check proved, against a SPARK spec layer, with no
assumptions.

Two layers per algorithm, and two kinds of check:

* **The spec layer** mirrors the Cryptol at minimal *semantic* distance:
  Cryptol's types (bit sequences where the Cryptol has bits), its
  iteration structure (`foldl` as a recursive ghost fold, `W@t` as a
  recursive ghost function) and its parameterization. Representation
  changes (bits to bytes, streaming) are not here.
* **The implementation layer** is executable, and is proved equal to the
  spec layer by gnatprove. Refinement layers in between (SHA-256's byte
  level) are proved the same way.
* **gnatprove** proves implementation = spec for all inputs.
* **The FFI check** shows spec = Cryptol: the SPARK functions are
  exported through C and called from Cryptol by `foreign`, and
  equivalence properties are run with `:exhaust` or `:check`. It is
  testing, not proof, and it is the only check of the spec layer's
  faithfulness. SAW (E4) later proves implementation = Cryptol directly at
  fixed sizes.

## The issues

| epic | sub-issues |
|---|---|
| **#1** E0 infrastructure | #2 M0.1 Cryptol/SAW on hex · #3 M0.2 CI · #4 M0.3 FFI harness · #5 M0.4 levels, pool, board · #6 M0.5 x86_64 bootstrap |
| **#7** E1 AES | #8 M1.1 types, GF(2^8), S-boxes, transformations · #9 M1.2 KeyExpansion · #10 M1.3 Cipher, InvCipher, Main · #11 M1.4 implementation · #12 M1.5 (stretch) the Cryptol properties |
| **#13** E2 SHA-256 | #14 M2.1 primitives and `step` · #15 M2.2 pad, parse, hash over bits · #16 M2.3 byte-level refinement · #17 M2.4 streaming implementation |
| **#18** E3 HMAC-SHA-256 | #19 M3.1 spec · #20 M3.2 implementation |
| **#21** E4 SAW | #22 M4.1 GNAT-LLVM/SAW spike · #23 M4.2 AES · #24 M4.3 SHA-256 and HMAC |

## The board

Counted by `spark/scripts/board.py` once M0.4 exists. Until then: no
SPARK units, no FFI checks. CI: none yet (M0.2).

| function | spec | FFI-checked | impl proved | SAW |
|---|---|---|---|---|
| (none yet) | | | | |

A function's row is complete when the spec exists and is FFI-checked,
its implementation is proved with zero unproved checks, assumptions and
justifications, and (E4) SAW proves it at each fixed size. Always report
the assumption and justification counts, even when they are zero.

## Next

1. **M0.2 (#3)** CI on the memcp model: the trust-surface gate, the proof gate
   and the cached prove workflow, green on the scaffold. First, because
   every later PR is reviewed against it. It needs no Cryptol.
2. **M0.1 (#2)** Cryptol and SAW on hex. Needs Tony only if an install needs a
   password.
3. **M0.3 (#4)** the FFI harness, with `xTimes` and `•` across, and its CI job.
4. **M0.4 (#5)** levels, the pool, and the board.
5. **M1.1 (#8) → M1.2 (#9) → M1.3 (#10) → M1.4 (#11)**, in order. AES calibrates every later
   estimate and tests the unconstrained-array decision.
6. **M2.1 (#14) → M2.2 (#15) → M2.3 (#16) → M2.4 (#17)**, then **M3.1 (#19) → M3.2 (#20)**.
7. **M1.5 (#12)** (stretch) when a tick needs a break from E2, or after E3.

Off the main line:
* **M0.5 (#6)** (the x86_64 bootstrap) and then **M4.1 (#22)** (the GNAT-LLVM/SAW
  spike), when Tony brings up the 8-CPU instance. They depend on nothing
  but M0.3. **M4.2 (#23)** follows M1.4, and **M4.3 (#24)** follows M2.4 and M3.2.

Not yet, and not filed:
* A T-table AES, proved equal to the spec. Only if the byte-wise
  implementation's speed matters to someone.
* `FinalBits` for SHA-256 (RFC 6234's trailing partial byte). Cheap once
  M2.3 states the padding lemma for general bit lengths.
* SHA-224/384/512 instances of the E2 generic.
* Keccak/SHA-3, KW/KWP. ECDSA is out of scope (bignum arithmetic).

## How the ticks run

* The `campaign` skill's procedure holds, with `agent-brief.md`.
* **Stacking.** The first tick targets `main`. Each later tick targets
  the tick below it, unless Tony has merged the stack. Check the PRs
  first.
* **Two machines.** Proofs and FFI checks run on hex, through
  `spark-scheduler`. GNAT-LLVM and SAW-on-SPARK run on the ephemeral
  x86_64 instance, which dies 24 hours after it starts: on it, **push
  after every commit**, and gnatprove calls `-j8` directly (the tick
  is the machine's only user).
* **CI is the floor** once M0.2 lands: a tick's PR is not reported done
  until its checks are green on the PR's head (`gh pr checks`). Green CI
  is necessary, not sufficient: the issue's own numbers still go in the
  PR.
* **Controls.** A tick that changes a shared unit (`Foundation_Spark`
  root, the common types, the FFI shims or the scripts) re-runs the
  board and `check-ffi.sh` for every unit already on it. A unit that
  lost a proved check, or a property that stopped passing, is a
  regression.

## Decisions taken — do not re-ask

* **Crate.** One Alire crate at `spark/` (`foundation_spark`), not one per
  algorithm. gnat_native 16.1.0, SPARKlib 16.1.0, gnatprove FSF 16.1.0.
* **Faithfulness.** The spec layer stays semantically close to the
  Cryptol. Representation changes go in separately proved layers.
* **FFI.** Our Cryptol modules live in `spark/cryptol/` and declare
  `spark_<Name>` foreign functions. The NSA `.cry` files and their Rust
  `.dylib`s are never modified or replaced.
* **AES key sizes.** Unconstrained arrays with `Key k` as a precondition.
  Fallback, if that proves rough: a generic per key size. M1.4
  records which.
* **SHA-2 generality.** A generic mirroring `SHA2::Main`'s parameters,
  instantiated for SHA-256 only.
* **Bit sequences.** Ghost Boolean arrays, 128-bit integer index,
  `Length < 2**64`. Zero runtime cost; the FFI build runs them with
  ghost code enabled.
* **Byte-only implementation.** SHA-256 and HMAC hash whole bytes. The
  padding lemma covers general bit lengths.
* **Pool.** gnatprove goes through `spark-scheduler` on hex. M0.4 settles
  the grant policy.
* **CI.** On the memcp model, in workflow files of our own: a trust-surface
  manifest with a justification per site, a proof gate with an (empty)
  xfail list, a file-based proof cache that PRs restore and only `main`
  saves, a daily cold reprove, and memcp's GNATdoc gate (every entity
  documented, every doc block on the right declaration). Placed first in
  the queue.
* **Upstream workflows** are disabled on the fork (`gh workflow disable`,
  files untouched) once Actions are enabled. Only our `spark-*` workflows
  run.
* **Plan location.** This file, committed. There is one `PLAN.md`, and its
  history is git's.
* **Epics.** One parent issue per epic (E0–E4), with GitHub sub-issues.

## Open for Tony

* Enable Actions on the fork (Actions tab) when M0.2's PR is ready. That
  is UI-only, and the tick disables NSA's workflows right after.
* Bring up the 8-CPU x86_64 instance when M0.5 is next. Say when its
  24 hours start.
* GNAT-LLVM source for x86_64 (M4.1): a GNAT Pro LLVM build, or a
  source build?

## Live ambushes

* `alr` (`~/Local/Software/alr/bin`) and `gnatprove` (`~/.alire/bin`)
  are not on PATH. Prepend both.
* `alr init` without `-n` hangs on a prompt. Use `alr -n` always.
* zsh treats a word starting with `=` as a command lookup: `echo =====`
  fails. Quote separators.
* `spark-scheduler run` does not tell its child how many tokens it got.
  `--up-to N -- gnatprove -jN` can oversubscribe.
* Cryptol finds a `foreign` library by the module file's name, next to
  the file. For a `foreign` with a Cryptol body, a library named wrong
  is not loaded, Cryptol evaluates the Cryptol definition instead, and
  the check compares the Cryptol with itself. Our modules declare
  `foreign` without a body so that a missing library is a load error.
  This is believed, not yet seen: M0.3 confirms it for Cryptol 3.6.
* `gh pr create` on a fork defaults to the upstream
  (`NationalSecurityAgency/Foundation`). Always pass
  `--repo manthonyaiello/Foundation`.
