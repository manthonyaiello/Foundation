# The campaign plan: SPARK AES, SHA-256 and HMAC against the Cryptol

**Provenance.** Rewritten 2026-10-22 (evening) on **hex**, at `main` =
`f7a2366` (the merge of PR #111). **The campaign now runs on hex**, Tony's
arm64 Mac; the `foundation` container is retired ("Machines"). This session
merged PRs #108 (#100), #109 (#107) and #111 (part of #75), and refiled the
remaining work around **a technical blog post** (#102).
**Board, counted on hex at `f7a2366`:** 4264/4264 proved; SAW **STALE**
(PR #111 changed five of its inputs; the next IOD session re-records).
**Open PRs:** none besides this plan's.
**Open issues:** #102 blog post and its prerequisites #103 #104 #51 #113;
the IOD batch #99 #110 and #75 (item 3, the re-record, four AES
statements); #106 effort analysis; E5's epic #48. #105 and #67 closed
(Tony's decisions, "Decisions").
**E0–E4 are closed**; E5: #49 and #50 closed, #51 open.
**Measurements:** `.claude/campaign/measurements/2026-10-19-iod.md` (the E4
day) and `2026-10-22-saw-cost.md` (#69). The AES spec crosswalks are in
`.claude/campaign/walkthroughs/` (links in its README).

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
* **SAW (E4)** proves implementation = Cryptol directly at fixed sizes, on
  bitcode from GNAT Pro 27's LLVM back end (#22–#24), and spec layer =
  Cryptol the same way (#59). E4 is done. Local only: nobody without GNAT Pro
  can reproduce it, so CI never runs it and `spark/saw/results.txt` records
  its provenance.

## The board

Counted on hex at `main` = `f7a2366` (`check-proof.sh` through the
scheduler, `FOUNDATION_SPARK_PROOF_ALLOWANCE=ci`, 225 s warm; CI's arm64
gate green on PR #111's head):

* **40 of 40 functions complete** in CI, 3 of them by design (`board.py`'s
  row kinds, #67/PR #81): `AES::SBox::affine` and `GF2::inverse (AES)` are
  `spec-only`, covered by `SBoxCorrect` and `SBox_Entries.Lemma_SBox_Entry`;
  `SHA2::Preprocessing::pad` is `subsumed-by` `hash`. `Ch`, `Maj`, Σ, σ are
  `impl = spec` rows. (On hex `board.py` says 0 of 40: it has no FFI log,
  since hex has no Cryptol.)
* **72 units, 4264 checks in the default gate: 4264 proved**, 0 justified,
  0 unproved (4231 before PR #111: `Lemma_Prefix_Extends` and the prelude
  instances). Plus one slow unit proved on demand:
  `foundation_spark-aes-spec-sbox-sbox_entries`, **2565/2565** at level 4,
  proved at `283afe5`, fingerprint current (#111 changed none of its
  inputs). About 28 min cold in CI; 493 s on `foundation` at `-j6`.
* **Holes:** 0 assumes, 0 justifications, 0 `SPARK_Mode Off`, 0 warning
  suppressions, 0 check suppressions. **23 foreign bindings** (the FFI
  export units, each justified in `spark/scripts/trust-surface.txt`).
* **FFI:** 147 properties, all passing in CI on PR #111's head
  (`spark/cryptol/properties.txt`). CI FFI job about 11–16 min.
* **Coverage (#49, PR #55):** under the FFI properties, 300/303 statements,
  13/14 decisions, 14/17 MC/DC, every gap explained
  (`spark/coverage/explained.txt`). Measured before the constant-time
  S-box; the CI Coverage job is green on every PR since, so the gaps are
  still all explained, but the numbers need re-running (#104).
* **Constant time (#50, closed):** AES's S-box is a bitsliced
  Boyar–Peralta circuit, proved equal to the tables. On aarch64 and x86_64
  the object-code check finds 0 violations; dudect max |t| ≤ 2.3; x86_64
  Valgrind `ct_grind` 0 errors. Cost at `-O3`: encrypt 1.64×, decrypt
  1.42–1.54×, `Expand_Key` 1.9–2.9×. **Left out of the blog post** (Tony).
* **SAW: STALE.** Last records: `results.txt` at `5bf56ac`, **2890 proved**
  (implementation 90, 24 lax; spec layer 2800: AES 1137, SHA-256 + HMAC
  1663), 20 negative controls fail, 3543 s; `results-long.txt` at
  `babab6f`, 3672 proved, 7819 s. PR #111 changed `sha2.ads`,
  `sha2-main.ads`, `hmac.ads`, `hmac-sha256_impl.adb` and
  `aes-spec-cipher.ads`; the re-record's changes are listed on #99.
  GNAT Pro 27 LLVM 21.1.8, SAW 1.6.

## The issues

| epic | sub-issues | state |
|---|---|---|
| **#1** E0 infrastructure | #2 #3 #4 #5 #6 | all closed |
| **#7** E1 AES | #8 #9 #10 #11 #12 | all closed |
| **#13** E2 SHA-256 | #14 #15 #16 #17 | all closed |
| **#18** E3 HMAC-SHA-256 | #19 #20 | all closed |
| **#21** E4 SAW | #22 #23 #24 #59 | all closed |
| **#48** E5 assurance beyond the proofs | #49 coverage · #50 constant time · #51 binaries and performance (AES only) | #49 #50 closed; #51 open |
| review of 2026-10-20 | #67 … #80 | all closed but #75 (item 3, four AES statements) |
| IOD session 2026-10-21/22 | #95 #99 #100 | #95 #100 closed; #99 open (IOD) |
| **#102** blog post (2026-10-22) | #103 docs · #104 mutation testing · #105 fork history · #51 · #75 · #99 · #113 FFI on macOS | #105 closed (accepted); the rest open |
| hex move (2026-10-22) | #107 scripts on macOS · #110 `check-saw.sh` on macOS | #107 closed; #110 open (IOD) |
| other | #106 effort analysis | open |

## Next

**The goal is the blog post (#102).** Tony writes it by hand; Claude
supplies bullets, data, code snippets and the figure's content, on request,
and never drafts it. A `/campaign` run never takes #102 as a writing task.

**The order** (A → B: A first):

```
#113 FFI on macOS ──► #104a mutants: FFI + gnatprove (hex) ─┐
#51a  AES perf, aarch64 (hex; Rust via `use rust`) ─────────┤
                          IOD session ◄─────────────────────┘
                            #99 unfold linear recursions
                            #110 check-saw.sh portable
                            #75 item 3, prelude SAW proofs
                            check-saw: relative runtime path, generic comment (#105)
                            SAW re-record, default + long, once
                            #104 SAW column · #51b AES perf, x86_64
                          ──► #103 docs ──► #102 data ──► tag, clean FSF repro ──► publish
#106 effort analysis: Tony, in the `foundation` container (2026-10-23), from a brief
```

**On hex now:** #113 (the FFI library as a `.dylib`: macOS gprbuild has no
encapsulated libraries), then #104's FFI and gnatprove columns; #51's
aarch64 half. Cryptol 3.6.0 (macOS ARM64, with solvers, FFI enabled) is
installed on hex (2026-10-22); Rust is `use rust`.

**The IOD session** (Tony builds one; it dies 24 h after start, so **upload
the session to memcp before then**): everything under "IOD session" above,
in one line of PRs, one re-record.

**Then #103** (the README rewrite and in-repo walkthroughs), which needs the
final numbers, then data for #102 as Tony asks.

Not in the post (Tony, 2026-10-22): constant time; offering the work to NSA
(undecided; possibly after GNAT-LLVM is in the community release).

Not yet, and not filed:
* A T-table AES (only if speed matters; #51 will say).
* `FinalBits` for SHA-256; SHA-224/384/512 instances; truncated HMAC.
* The four AES statements still inline (`pmod`, GF2 `pmult` [9], `pdiv`,
  `Types.Split`/`Join`): each sits in `SBox_Entries`' closure (PR #111
  says what each would need).

## Machines

* **hex** (since 2026-10-22): Tony's arm64 Mac, macOS, 10 CPUs, BSD
  userland, bash 3.2. Main checkout under `~/Local/repos/`.
  alr 2.1.1 at `~/Local/Software/alr/bin/alr`, gnatprove FSF 16.1.0 in
  `~/.alire/bin`, gnat_native 16.1.0 and gprbuild 26.0.1 as alr's default
  toolchain; **none on PATH**: give a tick
  `PATH=$HOME/Local/Software/alr/bin:$HOME/.alire/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin`
  (written out in full: the scheduler's child does not expand `~`).
  `spark-scheduler` pool of 8, key prefix `hex|`. **Prove with
  `FOUNDATION_SPARK_PROOF_ALLOWANCE=ci`**: at the local default (5 s at
  level 2) three `aes-lemmas` checks time out under load. Cryptol 3.6.0 (FFI, with solvers) in
  `~/Local/Software/cryptol-3.6.0-macos-15-ARM64-with-solvers/bin`, not
  on PATH; `check-ffi.sh` needs #113 first. Rust through `use rust`
  (`source $HOME/.cargo/env`, 1.95.0). No gnatcov, Valgrind or SAW. Whole-crate
  gate: about 550 s cold at `-j8`. hex is also Tony's desktop: never
  idle, so benchmarks go last or elsewhere.
* **`foundation`** (retired 2026-10-22): the aarch64 Linux container on
  niss where E0–E3 and the reviews ran. Its session transcripts are needed
  for #106.
* **The x86_64 IOD**: dies 24 hours after it starts. **8 CPUs, 15.7 GB RAM,
  no swap.** Bootstrap with `spark/scripts/bootstrap-x86_64.sh`: since #100
  it uses each tool already present at its pin and fetches the rest. The IOD
  comes with GNAT Pro 27 (GNAT Pro, SPARK Pro and the LLVM back end); point
  `GNAT_LLVM_DIR` and `LLVM_LINK_DIR` at it in the tools' `env.sh`. **The
  concrete paths are not in this repository** (it is public): they are in
  memcp (session of 2026-10-21/22). A default SAW record takes about 60 min,
  the long one about 130 min, on one core. **Push after every commit, and
  upload the session to memcp before the instance dies** (one was reaped
  with its session on it).
* **niss** (M5 Pro, 64 GB): the fallback if a SAW proof ever needs more
  memory than the IOD has. SAW ships for macOS arm64, so that would mean
  bitcode on the IOD and SAW on a Mac. Not needed so far.

## How the ticks run

* The `campaign` skill's procedure holds, with `agent-brief.md`.
* **Parallel ticks** are fine; each proves through the scheduler on
  hex. Parallel ticks are siblings; restack into one line before
  merging.
* **The orchestrator merges** verified PRs, bottom up, merge commits,
  retargeting each to `main` first.
* **CI is the floor**: trust surface, GNATdoc, proof (arm64), FFI (x86_64).
  PR proof job timeout 30 min. Green CI is necessary, not sufficient.

## Decisions taken — do not re-ask

* **Crate.** One Alire crate at `spark/` (`foundation_spark`). gnat_native
  16.1.0 (it matches gnatprove), gnatprove FSF 16.1.0, no crate
  dependencies (SPARKlib was never used and was removed, #72). Pins live in
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
* **AES key sizes: a generic over the key size** (Tony, 2026-10-20, on the
  spike #74; done by #80, PR #82). The `{k}` functions are the generic
  `Spec.AES_K` with formal `K : Key_Size`: `KeyExpansion` with its `W`,
  `Cipher`, `InvCipher`, `InvCipher'`, Main's `Encrypt`/`Decrypt` and
  `Split_Key`. `Spec.AES128/192/256` are its instances, as
  ``AES128 = AES`{128}`` is in Cryptol.
  * **What stays non-generic.** `Round`, the S-boxes, GF(2^8) and their
    lemmas are proved once.
  * **The instances' subtypes** constrain the unconstrained `Key_Words` and
    `Round_Keys`, so the generic functions take Cryptol's arguments with no
    precondition. The implementation stays flexible in `K`.
  * **The bridge** is `Spec.Dispatch`: one ghost dispatcher per `{k}`
    function, whose postcondition restates the Cryptol body with an
    explicit K and is proved per instance. Only the dispatchers case on
    K.
  * **`Key_Size` is a `Static_Predicate` (`128 | 192 | 256`)**, not
    Types.cry's clauses: Pure instances need a static K.
    `Dispatch.Lemma_Key_Size` proves the list equal to the clauses. `Nk`
    and `Nr` are Ada 2022 `Static` functions.
  * **The properties that take K** stay K-explicit over the dispatchers.
    Inside the generic, each would be proved three times for one theorem.
  * **Numbers.** The spike measured the gate at 530 s on `main` and 537 s
    with the generic (cold, `-j4`, idle pool), with checks 3554 → 3674.
    Proof time did not triple.
  * **History.** An earlier review the same day had declined the generic,
    weighing it as if the whole spec and implementation had to be generic.
* **The Cryptol prelude in SPARK** (#75; PRs #83, #85). Cryptol's built-ins
  the spec layers use are stated once, as ghost generics in
  `spark/src/cryptol/`, each citing its line in Cryptol 3.6's `Cryptol.cry`
  or the reference manual. Each is FFI-checked against Cryptol's own
  built-in.
  * **`foldl`** is a Cryptol primitive with no body, so `Folds` recurses
    from the last element, as the prelude's example and the
    implementation's loops do. The head-first equation is a theorem, stated
    only where needed.
  * **A spec body uses the prelude, unless an instance form costs a
    proof.** Then the statement stays inline, word for word the prelude's,
    with the reason in its comment. Four remain, all AES, all in
    `SBox_Entries`' closure (PR #111 isolated and fixed the other four:
    an extra definition layer, a guarded postcondition; see the README).
* **SAW waits for one IOD session** (Tony, 2026-10-20): spec and
  implementation changes land on hex (formerly `foundation`) first, each PR editing its
  SAW contracts and saying they are unverified. One IOD session then
  confirms them all. (Done for #68–#85 on 2026-10-21/22.)
* **SHA-2 generality.** A generic mirroring `SHA2::Main`, instantiated for
  SHA-256 only. Library-level instances need `pragma SPARK_Mode (On)`.
* **Bit sequences.** Ghost Boolean arrays, length < 2**64. SHA-2's index is
  128-bit because Cryptol's domain needs it: messages up to 2**64 − 1 bits,
  padded past Ada's 64-bit range. AES's index is `range 0 .. 256`, what AES
  needs: a 256-bit key's indices and its length (#68; Tony, 2026-10-20:
  wide types are not a way to avoid proving absence of overflow). The two
  types differ on purpose; no shared bit-sequence type. Ghost only, so no
  run-time cost either way.
* **Fixed-width words** (Tony, 2026-10-20): AES bytes are `Unsigned_8` with a
  Cryptol-order bit accessor (`Bit_Of`), not Boolean arrays; Boolean arrays
  are for arbitrary-length sequences only.
* **The x86_64 bootstrap CI job does not prove** (Tony, 2026-10-22): the
  gnatprove gate is arm64 only. Six AES checks time out on x86_64 (on `main`
  since #84/#85; the bootstrap workflow runs only when the bootstrap or the
  pins change, so nobody saw them): `aes-lemmas.adb` 74:16, 93:16, 115:16
  (fold lemmas), `aes-lemmas.ads` 70:08 (`Lemma_Pmult_Fold`),
  `aes-impl.ads` 126:17, 132:17 (`Sub_Bytes`, `Inv_Sub_Bytes`). The job runs
  the bootstrap with `--no-proof` (build and FFI still run).
* **Nothing internal in the repository** (Tony, 2026-10-22; it is public):
  no internal host names, install paths, package names or how GNAT Pro was
  installed, in files, commit messages or PR and issue text. Machine-specific
  setup goes to memcp. The bootstrap uses a tool when it is present and
  matches the pin, and fetches it otherwise (#100).
* **Unfold SAW's linear recursions** (Tony, 2026-10-22): worth doing, as
  follow-on work (#99), not in the session that found it.
* **Re-proved Cryptol properties are optional** (Tony, 2026-10-20). The
  spec layer is proved equal to the Cryptol (SAW), so the Cryptol's
  properties already hold of it. Re-proving them in SPARK is, in general, a
  bad idea: it adds proof cost without adding a theorem. Every writeup of
  this work says so. They stay for now, all of them, `SBoxCorrect` (the
  26-minute `sbox_entries`) included, because SAW does not run in CI. Until
  it does, they are the continuously checked cross-check that the SPARK spec
  is right. The two not stated (`SBoxPolynomialIsIrreducible`,
  `inverseCorrect`, #73 item 3) need not be added for this reason. Revisit
  when SAW runs in CI.
* **Spec and implementation need not be one-to-one** (Tony, 2026-10-20):
  `affine` and `GF2::inverse` (covered through `SBoxCorrect` and
  `Sub_Byte`'s postcondition), `pad` (through `hash`), and the "impl = spec"
  rows `Ch`, `Maj`, Σ, σ are complete, as designed. The board says so by row
  kind (#67). No FFI properties for `affine` and `inverse`.
* **SAW's scope** (Tony, 2026-10-20): implementation subprograms that nothing
  calls (`InvCipher'`, `Dot`) stay out of SAW; SHA-256 and HMAC pieces that
  SAW executes inside `Hash` and HMAC stay proved in place. Both are
  documented with their reasons, alongside where gnatprove's argument is
  stronger (#67). Fixed sizes match NSA's own Rust proofs (AES at k = 128,
  192, 256); NSA has no SHA-256 or HMAC implementation proof.
* **Slow-proof follow-ups from PR #44** (Tony, 2026-10-20): the `-u` run's
  `-A=generic-not-analyzed` is accepted; the fingerprint closure keeps
  bodies; `alire.toml` joins the fingerprint (#67); timeouts stay 30 min
  (PR proof) and 60 min (refresh).
* **The proof toolchain is FSF 16.1 only** (Tony, 2026-10-20): Pro 27's
  proof results are not repaired. The `spark-scheduler` stays outside this
  repository.
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
* **E4 toolchain** (Tony, 2026-10-19): the crate does not move; FSF 16.1
  stays the gate and CI's toolchain. GNAT Pro 27's LLVM back end is used only
  to make bitcode for SAW, and only on a machine with GNAT Pro.
* **E4 lives in the repository, out of CI** (Tony): `spark/saw/`, run only by
  `spark/scripts/check-saw.sh` (needs `GNAT_LLVM_DIR` and `LLVM_LINK_DIR`),
  never wired into a workflow. Every result is recorded in
  `spark/saw/results.txt` by the script, on a clean tree, with the commit,
  tool versions and the sha256 of every bitcode and source file.
* **SAW links, never assumes.** Units are linked with LLVM 21.1.8's own
  `llvm-link` (pinned in `toolchain-pins.env`; GNAT Pro ships none), so
  overrides are proved, not assumed: zero `llvm_unsafe_assume_spec`, and the
  script refuses one, and also `admit`, `assume_unsat` and `assume_valid`
  (#95), everywhere under `saw/` except `saw/experiments/`, which no record
  loads and which is not a SAW input for `board.py`. A lax-arithmetic module is allowed only where
  null-range poison forces it, and each such result is marked.
* **Lax-arithmetic SAW results are accepted** (Tony, 2026-10-19): in them SAW
  proves the functional equality and gnatprove proves absence of overflow.
  Tony: this is good for highlighting the value of SPARK. Keep them marked
  and counted separately.
* **The spec layer keeps Cryptol's meaning, not its evaluation strategy.**
  Recursive definitions stay recursive ghost functions (e.g.
  `KeyExpansion.W`); sharing is the implementation's job, and SAW gets it by
  per-index overrides (#59 discussion, 2026-10-19). #69 measured that the
  linear recursions are 10–30× cheaper for SAW unfolded: #99 changes that
  (decision above).
* **The blog post** (Tony, 2026-10-22, #102): Tony writes it; Claude
  provides bullets, data, snippets and the figure's content only. It has a
  "what we used, and what the results rest on" section. Performance is AES
  only (no reference SHA-256/HMAC). Constant time and upstreaming stay out.
  A tag and a clean-machine FSF reproduction come after the post is written.
* **The fork's history is accepted** (Tony, 2026-10-22, #105): no rewrite;
  the two places at the tip are fixed in the next SAW re-record.
* **#67 item 11 is done enough** (Tony, 2026-10-22): the README and
  `Properties` carry the note; the generated `sbox_entries.ads` gets it
  only if a later change touches the generator.
* **#106 is Tony's**, in the `foundation` container, from a brief this
  session writes at its end.
* **Coverage is not the argument against FFI-only testing**: it is near
  100%. Mutation testing (#104) is.
* **Plan location.** This file. There is one `PLAN.md`; its history is git's.

## Open for Tony

* **crucible-llvm and wide GEP indices**: optional (draft in PR #65).
* **The constant-time S-box's cost** (#50): aarch64 encrypt 1.64×, decrypt
  1.42×, `Expand_Key` 2.9×; x86_64 1.64×, 1.54×, 1.9–2.1× (PR #90). Accept
  it, or ask for a cheaper constant-time option. A T-table AES leaks.
* **Two GNAT 16.1 bugs to report upstream** (reproducers in PR #82's body):
  `Program_Error` at `sem_type.adb:825` on a `Static` function called in an
  instance's expression function; under `-gnata`, "R is undefined" for an
  iterated aggregate inside a quantified postcondition. Also, for GNAT Pro
  27: it does not carry a generic's `Pure` to its library-level instances
  (#89 worked around it with `with Pure`).
* **`SBox_Entries` and the default gate.** 28m24s cold in CI against a
  30 min job timeout. Levers measured, not applied: one inverse lemma per
  byte (about 20%); Z3 alone (a `--prover` level-policy change).
* **The IOD's global `~/.claude/CLAUDE.md`** is a mempalace leftover; Tony
  said to ignore it (use memcp). Delete it on the next image if wanted.
* **memcp's SessionStart hook** injected no surface on the IOD, and `hex`'s
  SessionEnd uploads are failing (3 of 19 sessions): `doctor`, or redeploy
  the hooks.

## Live ambushes

* **The auto-mode permission classifier** blocks wrapper commands it has no
  allow rule for (`spark-scheduler run ... -- env ...`), and then grows
  suspicious of nearby commands. `.claude/settings.local.json`
  (untracked, Tony's) allowed, on `foundation`; hex has none, and so far
  has not needed one. The rules were: `spark-scheduler run/status`,
  `[spark/]scripts/prove.sh`, `[spark/]scripts/check-*.sh`,
  `python3 [spark/]scripts/board.py`. Start commands with those prefixes.
  The classifier refuses to let the orchestrator edit settings itself.
* **A fresh worktree has no Alire workspace**: `alr -n build` in its
  `spark/` before any proof, or gnatprove fails at once with "imported
  project file config/foundation_spark_config.gpr not found" (`alr -n
  exec` does not generate it; re-checked after #72). On hex, see
  "Machines" for the PATH a tick needs.
* **Moving a spec body behind a prelude instance can time out an
  implementation lemma**, even with the same formula (#83, #85). PR #111
  explained four: one more definition between a term and its arithmetic
  (CVC5 3831 → 52939 steps), and a precondition-guarded `'Last`
  postcondition in context. Diagnose by diffing the saved VCs
  (`--debug-save-vcs`) with and without the instance. Restating GF2
  can also blow up `SBox_Entries`: GF2's `pmult` via the prelude ran past
  77 min for 9 of its 32 subprograms.
* **gnatprove warns on a `Subprogram_Variant` of a function that no longer
  recurses**, and the gate fails on warnings (#85 removed eight).
* **GNAT 16.1 and generics** (#82): a `Static` function called in an
  instance's expression function crashes the compiler; read a constant
  instead. A Pure library-level instance needs a static actual, so its
  subtype needs a `Static_Predicate`.
* **A hand re-run replays cached proofs** (seconds); `prove.sh` refuses
  `-f` (its freshness guard forces per unit). CI's run is the cold one.
* **hex is macOS**: scripts must run under BSD awk/sed and bash 3.2 (#107
  fixed the proof and FFI scripts; `check-saw.sh` is #110). XProtect and
  Tony's own work load the machine: load averages near 20 are normal
  during a `-j8` proof.
* **gnatdoc 26 crashes** on: `declare` expressions; a line break right after
  `for X in A .. B =>` in an aggregate; an iterated aggregate nested in
  another expression; package renamings; `is` alone on its line before an
  iterated aggregate; a private-part expression function whose quantified
  expression breaks after `=>`. It rejects `@formal` on generic-subprogram
  formals.
* **gnat1 16.1 (aarch64 Linux) crashes** (`Storage_Error`) on an iterated aggregate
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
* **An OOM kills the whole tmux window.** Each window is a systemd scope with
  `OOMPolicy=stop`: one OOM-killed process (an rme proof of eight 32-bit
  additions, 2026-10-19) took the orchestrator and its tick with it. Run
  every saw/cryptol/z3 by hand under
  `systemd-run --user --scope -q -p MemoryMax=10G -p MemorySwapMax=0`;
  `check-saw.sh` does so itself.
* **SAW 1.6 on GNAT-LLVM bitcode** (README "SAW" has the detail):
  no `-g` (metadata parse fails); `-O0` only (SROA poison at `-O1`+);
  overrides only within one LLVM module (hence llvm-link); rme hangs on 32-bit
  division and blows up on 32-bit adders (use z3 / `w4_unint_z3`); an input
  with no symbolic part needs nothing uninterpreted; null ranges create
  poison in a discarded `select` operand, which SAW rejects (lax module, fixed
  at `llvm_load_module`); `SHA256.cry`/`Hash.cry` do not load (PBKDF's
  `parmap`), so `spark/saw/SHA256Main.cry` instantiates `Main`; negative
  controls outside the proof's uninterpreted vocabulary can run for minutes.
* **`gh pr checks` skips the bootstrap workflow** unless the bootstrap script
  or pins change; when they do, it adds 35–50 min per job, and (since
  #84/#85) it runs with `--no-proof` (decision above); since #100 each job runs the
  script twice, to check that a second run fetches nothing.
* **On the IOD, source the tools' `env.sh` in every shell.**
  Without it GNAT Pro 27's `gnatprove`, `gcc` and `gprbuild` are first on
  PATH: builds use Pro 27, and `board.py` reports `SBox_Entries` falsely
  STALE (its fingerprint includes the tool versions). Build through
  `alr -n exec --`.
* **saw by hand needs `CRYPTOLPATH=<repo root>`** (`check-saw.sh` exports
  it); without it every script fails to load its Cryptol.
* **Anything new under `spark/saw/` used to stale both SAW records** (#94);
  since #96 only `saw/experiments/` is exempt. Run `board.py` before merging
  a PR that touches `saw/`, `check-saw.sh` or the pins.
* **Per-unit bitcode hashes in `results.txt` change with the worktree path**
  (it is embedded); the linked modules' hashes do not. Not a result change.
* **A background Bash with an explicit `timeout` kills the job at expiry**;
  never set one on a SAW record. Never `pkill` a solver during a recorded
  run.
* **Two capped SAW runs can still OOM the machine**: `MemoryMax` is per
  scope, so two 10 G scopes exceed 15.7 GB. One saw at a time; if two must
  run, 6 G each (2026-10-20, a tick's helper ran a second one).
* **`pgrep -f PATTERN` in a wait loop matches the loop itself** (the pattern
  is in its own command line), so `until ! pgrep -f X; do sleep 5; done`
  never ends: seven such loops from the M4.3 tick ran for 5+ hours. And
  `pkill -f PATTERN` can kill the shell that runs it. Wait on a PID, a file,
  or `pgrep -x`.
* **SAW drops the stack bytes an override's postcondition does not state.**
  A lemma used as an override must state everything its caller reads
  afterwards (HMAC_init at k = 65 failed until its `Hash` lemmas kept the
  bytes below the message, PR #65).
* **SAW 1.6 rejects a GEP index wider than 64 bits** (GNAT-LLVM emits `i128`
  when a constrained array with a 128-bit index type is indexed directly).
  #68 removed the one case (AES's `Join_Block`) and the `gep64` rewrite;
  SHA-2's index is still 128-bit, so do not reach for a wide index again.
  `check-saw.sh` refuses a linked spec module with an `i128` GEP index.
* **zsh**: a word starting with `=` is a command lookup; `$var` with spaces
  is not word-split (use `${(f)...}` arrays); `for` loops over a string
  of names need splitting.
* **`gh pr create` on a fork** defaults to the upstream. Always
  `--repo manthonyaiello/Foundation`.
