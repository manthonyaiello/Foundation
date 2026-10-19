# The campaign plan: SPARK AES, SHA-256 and HMAC against the Cryptol

**Provenance.** Rewritten 2026-10-19. `main` is `ac09517` (the merge of PR
#52). The board below was counted on it by `spark/scripts/board.py`, after a
whole-crate `check-proof.sh` (through the scheduler, on `foundation`) and a
full `check-ffi.sh`. Open: PR #46 (#6, the x86_64 bootstrap), and the
`x86-proof-margins` work it waits on. Everything else is merged.

**A fresh session starts at "Next".**

## What the campaign is

Foundation (NSA's Cryptol specifications, forked) has Cryptol specs and SAW
proofs, and Rust behind a few fixed-size primitives. The campaign adds SPARK
implementations of AES, SHA-256 and HMAC-SHA-256, proved **platinum**: every
check proved, against a SPARK spec layer, with no assumptions.

* **The spec layer** mirrors the Cryptol at minimal semantic distance:
  Cryptol's types (ghost Boolean arrays for arbitrary bit sequences), its
  iteration structure (recursive ghost folds and functions), its names and its
  parameterization (generics). Representation changes are separate layers.
* **The implementation layer** is executable SPARK, proved equal to the spec
  layer by gnatprove.
* **The FFI check** tests spec = Cryptol: the SPARK is exported through C and
  called from Cryptol by `foreign`, and equivalence properties run with
  `:exhaust` or `:check`. Testing, not proof.
* **SAW (E4)** is to prove implementation = Cryptol directly at fixed sizes,
  on GNAT-LLVM bitcode.

## The board

Counted on `main` at `ac09517`:

* **37 of 40 functions complete** (spec exists and is FFI-checked,
  implementation proved, no holes).
* **53 units, 3506 checks in the default gate: 3506 proved**, 0 justified,
  0 unproved. Plus one slow unit proved on demand:
  `foundation_spark-aes-spec-properties-sbox_entries`, 2482/2482, proved at
  `46c5799`, fingerprint current.
* **Holes:** 0 assumes, 0 justifications, 0 `SPARK_Mode Off`, 0 warning
  suppressions, 0 check suppressions. 21 foreign bindings (the FFI export
  units, each justified in `spark/scripts/trust-surface.txt`).
* **FFI:** 118 properties, all passing (50+ AES, SHA-256, HMAC; see
  `spark/cryptol/properties.txt`). CI FFI job about 10–14 min on x86_64.
* **SAW:** not run (E4).

The three incomplete rows, honestly so:

| row | why |
|---|---|
| `AES::SBox::affine` | ghost-only by design (#12); the implementation reads the S-box table |
| `GF2::inverse (AES)` | same |
| `SHA2::Preprocessing::pad` | no executable counterpart: `Final` writes only the last one or two padded blocks, proved through `Hash` |

`Ch`, `Maj`, Σ, σ are "impl = spec" rows: the spec functions are non-ghost
`Unsigned_32` functions that `Compress` calls at run time.

## The issues

| epic | sub-issues | state |
|---|---|---|
| **#1** E0 infrastructure | #2 Cryptol/SAW · #3 CI · #4 FFI harness · #5 levels, board · #6 x86_64 bootstrap | #3 #4 #5 closed; #2 open (SAW half); #6 open (PR #46) |
| **#7** E1 AES | #8 #9 #10 #11 #12 | all closed |
| **#13** E2 SHA-256 | #14 #15 #16 #17 | all closed |
| **#18** E3 HMAC-SHA-256 | #19 #20 | all closed |
| **#21** E4 SAW | #22 M4.1 spike · #23 M4.2 AES · #24 M4.3 SHA-256 and HMAC | open, paused for GNAT-LLVM |
| **#48** E5 assurance beyond the proofs | #49 M5.1 coverage · #50 M5.2 constant time · #51 M5.3 binaries and performance | open, new |

## Next

1. **Fix the x86_64 proof margins, then merge PR #46 (#6).** #46's bootstrap
   jobs install everything (toolchain, Cryptol, SAW 1.6; a bare image needs
   only `ca-certificates curl git libc6-dev python3`), pass FFI, prove the
   repo's `GF28.saw`/`SBox.saw` with SAW, and match the slow unit's
   fingerprint on x86_64. But three level-2 checks time out on the x86_64
   runner under the 10 s CI allowance, though they prove on arm64 and with
   60 s on x86_64: `AES.Spec.Properties.GF28MultiplicationCorrect`,
   `HMAC.SHA256_Impl.Lemma_Hash_Ext`, `HMAC.SHA256_Impl.Lemma_HMAC`. The
   `x86-proof-margins` tick restructures those proofs (or raises the two
   files to `Level_3` if it must), re-runs the slow proof (properties.ads is
   one of its inputs), and restacks #46 on top.
2. **Run `spark-prove-slow.yml` once** on the final `main` (Tony's decision:
   only after everything is merged). It validates the on-demand workflow; it
   should reproduce sbox_entries' recorded fingerprint and 2482/2482.
3. **Move to the x86_64 IOD** (Tony, 2026-10-19): run the bootstrap from
   `spark/README.md` ("Bootstrapping the x86_64 instance"), confirm the gates.
   The slow unit's fingerprint already matched on the x86_64 CI runner.
4. **M4.1 (#22)** on the IOD: GNAT-LLVM + SAW 1.6, one AES leaf
   (`Sub_Bytes` or `X_Times`) proved by `llvm_verify` against the Cryptol.
   **Blocked on GNAT-LLVM** for x86_64 Linux: a GNAT Pro LLVM build, or a
   source build of `AdaCore/gnat-llvm` (Tony to say which). Template: the
   repository's `algorithms/AES/rust/*/theorems/saw.py` (`mir_verify`,
   leaf lemmas, uninterpreted compositions).
5. **M4.2 (#23)** AES at k = 128/192/256, then **M4.3 (#24)** SHA-256
   `Compress` and HMAC at fixed message sizes.
6. **E5** when E4 waits on something: **M5.1 (#49)** coverage first (Tony: do
   it if the queue runs dry), then **M5.2 (#50)** constant time (the AES
   table S-box leaks), then **M5.3 (#51)** binaries and performance (on the
   IOD for x86_64 numbers).

Small items, any time:
* **The slow-proof follow-ups** (Open for Tony, below), as one small PR.
* **Scheduler inside `prove.sh`**: use `spark-scheduler` when on PATH, direct
  otherwise (CI, IOD), so the long wrapper command goes away.
* **One bit-sequence type**: `AES.Spec.Main.Bits` (index `0 .. 2**127-1`) and
  `SHA2.Bits` (`0 .. 2**126`) duplicate each other. Unify into a common unit.
  Touches sbox_entries' inputs? Check with `slow_proofs.py inputs` first.
* **`board-rows.txt` row kinds**, if Tony agrees (below).
* **`#52`'s FFI job was 14m26s against `main`'s 9m55s** with only ~5 s of
  new properties: find out why.
* **A cheaper SBoxCorrect proof**: about 7.5 min of its 26 is gnat2why reading
  the 7,700-line generated unit.

Not yet, and not filed:
* A T-table AES (only if speed matters; M5.3 will say).
* `FinalBits` for SHA-256 (trailing partial byte): cheap, since the padding
  lemma already covers every bit length.
* SHA-224/384/512 instances of the E2 generic.
* HMAC with truncated output (λ < 256).

## Machines

* **`foundation`**: an aarch64 Linux container on niss, 11 CPUs, long-lived.
  Main checkout `/work/Foundation`. alr 2.1.1, gnatprove FSF 16.1.0,
  gprbuild 26.0.1 on PATH; Cryptol 3.6.0 built from source with FFI
  (`~/.local/bin/cryptol`; headers in `~/.local/sysroot`). **No system C
  toolchain**: GNAT's gcc is the only one. No SAW, no GNAT-LLVM (neither
  exists for aarch64 Linux). `/tmp` is a ramfs. `spark-scheduler` pool of 10.
* **The x86_64 IOD**: dies 24 hours after it starts. Bootstrap with
  `spark/scripts/bootstrap-x86_64.sh` (PR #46). No scheduler: gnatprove with
  `PROVE_JOBS=$(nproc)`. **Push after every commit.** Cryptol and SAW are
  the x86_64 releases. Needs root or passwordless sudo only if the image lacks
  the apt prerequisites the script names.

## How the ticks run

* The `campaign` skill's procedure holds, with `agent-brief.md`.
* **Parallel ticks** are fine; each proves through the scheduler on
  `foundation`. Parallel ticks are siblings; restack into one line before
  merging.
* **The orchestrator merges** verified PRs, bottom up, merge commits,
  retargeting each to `main` first.
* **CI is the floor**: trust surface, GNATdoc, proof (arm64), FFI (x86_64).
  PR proof job timeout 30 min. Green CI is necessary, not sufficient.

## Decisions taken — do not re-ask

* **Crate.** One Alire crate at `spark/` (`foundation_spark`). gnat_native
  16.1.0, SPARKlib 16.1.0, gnatprove FSF 16.1.0. Pins live in
  `spark/scripts/toolchain-pins.env` (with PR #46).
* **Faithfulness.** The spec layer stays semantically close to the Cryptol.
  Representation changes go in separately proved layers. Renamings forced by
  Ada or gnatdoc are recorded in the source comment that cites the `.cry`.
* **FFI.** Our Cryptol modules live in `spark/cryptol/` and declare body-less
  `spark_<Name>` foreigns. The NSA `.cry` files and libraries are never
  modified. `check-ffi.sh` requires each of our modules to load its library
  and fails if any NSA module loads one. Ghost spec functions are exported
  through a ghost shim plus a non-ghost export unit that Imports the
  `___ghost_`-prefixed link name; executables are exported directly and
  built without `-gnata`. Always name type parameters in properties.
* **FFI testing is targeted** (Tony): boundary cases, KATs, bulk random
  samples on the executables proved equal to the spec (so faithfulness is
  checked transitively), a few direct tests per ghost spec export. A long run
  at large N is deferred to times Tony chooses.
* **AES key sizes.** Unconstrained arrays with an explicit `K` and
  `Is_Key_Words`/`Is_Round_Keys` preconditions. Held through M1.4; no generic.
* **SHA-2 generality.** A generic mirroring `SHA2::Main`, instantiated for
  SHA-256 only. Library-level instances need `pragma SPARK_Mode (On)`.
* **Bit sequences.** Ghost Boolean arrays, 128-bit index, length < 2**64.
* **Streaming.** GNAT 16 rejects ghost record components, so streaming
  contexts carry their message through ghost lemmas (`Lemma_Update`,
  `Lemma_Final`) called after each operation.
* **Machines.** As above. No scheduler on the IOD. The scheduler's grant goes
  to gnatprove through `{tokens}`.
* **Levels.** Committed per file in the GPR through `Level_2/3/4` switch
  lists, never literal `--level`/`--timeout`. CI adds a wall-clock allowance
  (`FOUNDATION_SPARK_PROOF_ALLOWANCE=ci`).
* **Slow proofs** (Tony): units in `spark/scripts/proof-slow.txt` are proved
  on demand (`prove-slow.sh`, `spark-prove-slow.yml`), not by the default
  gate, which instead checks a fingerprint of their inputs and fails STALE on
  any change.
* **CI.** Arm64 runners for the gates, x86_64 for FFI. The proof cache is
  saved only by `main`; the cold refresh is scheduled.
* **Merging** (Tony, 2026-10-18): the orchestrator merges.
* **E4 waits for GNAT-LLVM**, on the x86_64 IOD.
* **Plan location.** This file. There is one `PLAN.md`; its history is git's.

## Open for Tony

* **GNAT-LLVM for x86_64 Linux** (blocks #22): a Pro build, or try building
  `AdaCore/gnat-llvm` from source on the IOD?
* **Slow-proof follow-ups** (from PR #44), with my recommendations:
  1. the gate's `-u` run passes `-A=generic-not-analyzed` (a command-line
     warning tag the trust gate does not see): accept;
  2. the fingerprint closure includes bodies, not only specs: keep
     (conservative);
  3. fingerprint `alire.toml` (it pins SPARKlib): add it;
  4. timeouts 30 min (PR proof) and 60 min (refresh): keep.
* **Board row kinds**: a fourth field in `board-rows.txt`: `impl` (default),
  `spec-only` (with a reason; out of the denominator, counted separately),
  `subsumed-by <row>` (`pad` → `hash`)? And should `affine` and
  `GF2::inverse` get FFI properties?
* **"impl = spec" rows** (`Ch`, `Maj`, Σ, σ): acceptable as complete?
* **AES bytes as `Unsigned_8`** with a Cryptol-order bit accessor, rather
  than ghost Boolean arrays, for fixed 8-bit words: acceptable?

## Live ambushes

* **The auto-mode permission classifier** blocks wrapper commands it has no
  allow rule for (`spark-scheduler run ... -- env ...`), and then grows
  suspicious of nearby commands. `.claude/settings.local.json` on `foundation`
  (untracked, Tony's) allows `spark-scheduler run/status`,
  `[spark/]scripts/prove.sh`, `[spark/]scripts/check-*.sh`,
  `python3 [spark/]scripts/board.py`. Start commands with those prefixes.
  The classifier refuses to let the orchestrator edit settings itself.
* **A fresh worktree has no Alire workspace**: `alr -n build` in its
  `spark/` before any proof, or gnatprove fails at once on sparklib's lib
  dir.
* **A hand re-run replays cached proofs** (about 2 s); `prove.sh` refuses
  `-f`. CI's run is the cold one.
* **gnatdoc 26 crashes** on: `declare` expressions; a line break right after
  `for X in A .. B =>` in an aggregate; an iterated aggregate nested in
  another expression; package renamings; `is` alone on its line before an
  iterated aggregate; a private-part expression function whose quantified
  expression breaks after `=>`. It rejects `@formal` on generic-subprogram
  formals. gnatdoc is not on PATH on `foundation` (a copy lives in a
  session scratchpad; the CI action installs it).
* **gnat1 16.1 (aarch64) crashes** (`Storage_Error`) on an iterated aggregate
  over a 64- or 128-bit index range written `[for N in T range A .. B => …]`;
  use `[for N in Subtype'Range => …]`.
* **The provers do not treat Ada array `=` as equality.** Extensionality and
  congruence lemmas (`*_Ext` in SHA-2, `*_Eq` in AES) are routinely needed.
* **x86_64 provers are slower on some goals than arm64**: three checks that
  prove in under 10 s on arm64 need up to 60 s on the x86_64 runner. A green
  arm64 gate does not imply a green x86_64 gate; the bootstrap job runs the
  x86_64 gate.
* **Executing ghost recursions is exponential** (`KeyExpansion.W`, SHA-2's
  `W`): never put a large-N FFI property on a ghost spec export.
* **Cryptol `[l /^ 8][8]`** does not determine `l`: pass `` `{l} ``.
* **zsh**: a word starting with `=` is a command lookup; `$var` with spaces
  is not word-split (use `${(f)...}` arrays); `for` loops over a string
  of names need splitting.
* **`gh pr create` on a fork** defaults to the upstream. Always
  `--repo manthonyaiello/Foundation`.
* **Subagent reports call `foundation` "hex"** out of habit: the numbers are
  from `foundation`.
