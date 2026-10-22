# The campaign plan: SPARK AES, SHA-256 and HMAC against the Cryptol

**Provenance.** Rewritten 2026-10-22 on the x86_64 IOD,
at `main` = `95a57c4` (the merge of PR #96), after the IOD session of
2026-10-21/22. That session merged PRs #89, #92, #93, #94 and #96 (closing
#68, #69 and #95). **SAW is current again**: `board.py` on `95a57c4` (with
the tools' `env.sh` sourced) says "SAW: recorded", both records
current. The gnatprove gate was confirmed by CI on each PR's head (no PR of
the session changed a proof result; one changed `spark/src`: #89's
`with Pure` on the three AES instances, re-proved).
**Open PRs:** #90 (`Closes #50`; green except the bootstrap jobs, which
fail on six x86_64 proof timeouts already on `main`; unblocked by the
bootstrap `--no-proof` PR, decision below), #97 (this plan), #98 (effort
data), and the bootstrap `--no-proof` / scrub PR.
**Open issues:** #50 (PR #90), #51, #99, #100, #67 (item 11's header in the generated
`sbox_entries.ads` only), #75 (five statements left inline; the prelude's
own SAW proofs, item 3, not written), and E5's epic #48.
**E0–E4 are closed**; E5 is under way (#49 closed, #50 waiting on #90).
**Measurements:** `.claude/campaign/measurements/2026-10-19-iod.md` (the E4
day) and `2026-10-22-saw-cost.md` (#69). The AES spec crosswalks (`.claude/campaign/walkthroughs/`) are the
"before" of 2026-10-20 and the "after #75" of 2026-10-21 (both published),
plus an old-vs-new SPARK page (published, PR #88); the links are in the
walkthroughs README. The "after #80" copy is superseded and unpublished.

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

Counted on `main` = `95a57c4` (gnatprove from CI on the session's PR heads,
unchanged since `1140824`; SAW recorded at `5bf56ac` and `babab6f`):

* **40 of 40 functions complete**, 3 of them by design (`board.py`'s row
  kinds, #67/PR #81): `AES::SBox::affine` and `GF2::inverse (AES)` are
  `spec-only`, covered by `SBoxCorrect` and `SBox_Entries.Lemma_SBox_Entry`;
  `SHA2::Preprocessing::pad` is `subsumed-by` `hash`. `Ch`, `Maj`, Σ, σ are
  `impl = spec` rows.
* **72 units, 4231 checks in the default gate: 4231 proved**, 0 justified,
  0 unproved. Plus one slow unit proved on demand:
  `foundation_spark-aes-spec-sbox-sbox_entries` (moved out from under
  `Properties` by PR #79; closure `Types`, `SBox`, `GF2`, `GF28` and the
  prelude), **2565/2565** at level 4, proved at `283afe5`, fingerprint
  current. PR #86 (#70) split each row lemma, so pgcd's steps no longer
  carry the 256-entry `SBox` table. That took the proof from 1148 s to 493 s
  on `foundation` (`-j6`, idle pool), and the cold CI run from 1h40m47s to
  28m24s. The cost was never gnat2why, which takes 3 s: it was gnatwhy3's
  per-goal transformations, 3404 s of CPU before and 1015 s after. `alire.toml` is now in every slow fingerprint, and
  `slow_proofs.py refresh FILE` records an input-only change without
  re-proving, when the new input is unchanged since the proof.
* **Holes:** 0 assumes, 0 justifications, 0 `SPARK_Mode Off`, 0 warning
  suppressions, 0 check suppressions. **23 foreign bindings** (the FFI
  export units, each justified in `spark/scripts/trust-surface.txt`; #83
  added the prelude's shim and exports).
* **FFI:** 147 properties, all passing (`spark/cryptol/properties.txt`):
  the 119 of 2026-10-19, 22 for the Cryptol prelude against Cryptol's
  built-ins (#83), and 6 for the constant-time S-box leaves, three at
  `:exhaust` 256 (#84). CI FFI job about 11–15 min.
* **Constant time (#50, PR #84):** AES's S-box is a bitsliced Boyar–Peralta
  circuit, proved equal to the tables. `scripts/check-ct.sh`:
  * the object-code check finds 0 violations on aarch64 (re-run by the
    orchestrator);
  * dudect max |t| is at most 2.1 on aarch64 (17.6 before);
  * cost on aarch64 at `-O3`: AES-128 encrypt 1.64×, decrypt 1.42×,
    `Expand_Key` 2.9×.

  **x86_64 (PR #90, not merged):** object-code check 0 violations; Valgrind
  `ct_grind` 0 errors, its control failing; dudect max |t| ≤ 2.3 (1M–2M
  samples). The table S-box (`b967ebb`) is flagged by all three: 86
  object-code violations, 1855 Memcheck errors (incl. `sub_byte`), |t| > 4.5
  in 10 of 15 runs. Cost at `-O3`: encrypt 1.64×, decrypt 1.54×,
  `Expand_Key` 1.9–2.1×. Valgrind on aarch64 is not done (`foundation` has
  none), as #84 allowed.
* **SAW: current.** `results.txt` (recorded at `5bf56ac`): **2890 proved**,
  implementation 90 (24 lax) and spec layer 2800 (AES 1137, 768 of them
  exhaustive; SHA-256 + HMAC 1663, 1396 lax); 20 negative controls fail with
  a counterexample; 3543 s. `results-long.txt` (`SAW_LONG=1`, at `babab6f`):
  3672 proved (spec 3582, 2178 lax), 7819 s. Rows with a SAW result of their
  own: spec 36 of 40, impl 28 of 37 (`board.py` counts the AES `Dispatch`
  rows through their instances since #92). `AES.Impl.Main.Encrypt`/`Decrypt`
  have none (#67 documents why). GNAT Pro 27 LLVM 21.1.8, SAW 1.6.

## The issues

| epic | sub-issues | state |
|---|---|---|
| **#1** E0 infrastructure | #2 #3 #4 #5 #6 | all closed |
| **#7** E1 AES | #8 #9 #10 #11 #12 | all closed |
| **#13** E2 SHA-256 | #14 #15 #16 #17 | all closed |
| **#18** E3 HMAC-SHA-256 | #19 #20 | all closed |
| **#21** E4 SAW | #22 #23 #24 #59 | all closed |
| **#48** E5 assurance beyond the proofs | #49 M5.1 coverage · #50 M5.2 constant time · #51 M5.3 binaries and performance | #49 closed; #50 waits on PR #90; #51 open |
| review of 2026-10-20 | #67 board kinds, SAW scope, docs · #68 AES `Bit_Index` · #69 SAW spec-layer cost · #70 cheaper SBoxCorrect · #72 SPARKlib · #73 AES spec feedback · #74 generic spike · #75 Cryptol prelude · #80 generic AES | #68 #69 #70 #72 #73 #74 #80 closed; #67 item 11 header left; #75 inline statements + prelude SAW left |
| IOD session 2026-10-21/22 | #95 SAW record inputs (`saw/experiments/`, `admit`) | closed (PR #96) |

## Next

Done on 2026-10-21/22 on the x86_64 IOD, all SAW, in
one line of PRs:
* **#68** (PR #89, closed): the impl layer re-proved, 90 (87 + the
  constant-time S-box's `sbox_lanes`, `inv_sbox_lanes`, `sub_word`); 8 impl
  negative controls fail. GNAT Pro 27 rejected the Pure `Dispatch` withing
  the instances: `with Pure` on `AES128/192/256` (FSF 16.1 accepts both;
  re-proved 195/195). Read from the IR: `bits_BOUNDS` is `{i16, i16}`; no
  `i128` GEP in the AES spec module. `check-saw.sh` gained
  `SAW_LAYERS=all|impl|spec` (one layer only with `--print`).
* **#75's SAW half** (PR #92): the spec layer re-proved (#80, #83, #85's
  edits). Departures from the plan's assumptions: `Split_Key` returns by
  value at every k; fold slice bounds are a read-only constant global in
  `Cipher` but writable in the inverse folds (`foldl_take_contract`'s `ro`
  flag); `Join_Block` needs the secondary-stack setup, with a high-water
  mark bounded by the chunk (signed compare); the AES spec count rose 54
  (108 `Foldl_Take` lemmas where the per-M ones were 42). #83 needed no
  edits.
* **#67 item 3** (PR #93): SAW proves `Parse` on its own,
  = ``parse`{32, N}`` at N = 1, 2 (and 3, 4 long), with a negative control.
  `Hash` still executes `Parse` (its input sits at a `Pad`-dependent stack
  base).
* **#69** (PR #94, closed): why SAW costs 76× more on the spec layer. Write-up
  `.claude/campaign/measurements/2026-10-22-saw-cost.md`; experiments in
  `spark/saw/experiments/issue-69/`. Shares of spec proof time: secondary
  stack 44% (a lemma per stack base: SAW 1.6 places values only at constant
  offsets); recursion lemmas 33% (needed for the exponential recursions;
  **linear ones are 10–30× cheaper unfolded**); one byte per bit 23%
  (packed bits remove 94–97% of it); exhaustive per-byte proofs 7%; null
  ranges / lax module 2%. Lesson for C-to-SPARK equivalence: cost follows
  structural distance, not size.
* **#95** (PR #96, closed): `saw/experiments/` is not a SAW input for
  `board.py`; `check-saw.sh` refuses `admit`/`assume_unsat`/`assume_valid`
  outside `saw/experiments/`. Both records re-run, identical results.
* **#50's IOD half** (PR #90, **open**): see the board. `check-ct-asm.py`
  skips x86 prefix words (`data16`, `notrack`, `bnd`, ...) and counts
  `loop*` as branches; Valgrind joins the bootstrap prereqs.

**Order from here:**

1. **Merge the bootstrap `--no-proof` / scrub PR** once its bootstrap jobs
   are green, then rebase and merge **#90** (closes #50).
2. **#51** (M5.3 binaries and performance): aarch64 on `foundation`, x86_64
   on the next IOD (needs a Rust toolchain and an idle machine; not started).
3. **#100** (bootstrap uses present tools): any machine; its CI is the
   bootstrap workflow.
4. **#99** (unfold SAW's linear recursions): the next IOD; a re-record
   follows.
5. **#67 item 11**: the "re-proved properties are optional" header in the
   generated `sbox_entries.ads` means changing `gen-sbox-entries.py` and
   re-proving the slow unit (about 30 min cold): a `foundation` job.
6. **#75's remainder**: the five inline statements (each measured; cause not
   isolated) and the prelude's own SAW proofs (item 3), the latter on an IOD.
7. **Obtain vs. check analysis** (Tony, another session): data in
   `.claude/campaign/effort/` (PR #98); extend it with the `foundation`
   sessions' transcripts.

Small items: none open. Settled on 2026-10-20 (Tony):
* **Dropped:** Pro-27 proof repair (the crate stays on FSF 16.1; Pro 27's 4
  failures and 3 timeouts, listed in the measurements file, are known and
  accepted); x86_64 proof margins (the gate proves on arm64); the
  scheduler inside `prove.sh` (the scheduler is an internal tool, not part of
  this repository); the FFI job's 14 min on #52 (runner noise: identical
  code runs in about 8–10 or 14–15 min, the property step alone doubling,
  e.g. PR #65 at 7m35s, 14m34s, 9m27s; do not chase it again).
* **Already done:** the bootstrap workflow's path filter (it triggers only on
  the bootstrap script, the pins and the workflow).
* **Into issues:** `board.py`'s SAW column, board row kinds and SAW's
  unproved pieces → #67; one bit-sequence type → dropped by #68 (AES and
  SHA-2 keep different index types on purpose); why SAW of the spec layer is harder
  → #69; a cheaper SBoxCorrect → #70; gnatcov in the bootstrap → #51.

Not yet, and not filed:
* A T-table AES (only if speed matters; M5.3 will say).
* `FinalBits` for SHA-256 (trailing partial byte): cheap, since the padding
  lemma already covers every bit length.
* SHA-224/384/512 instances of the E2 generic.
* HMAC with truncated output (λ < 256).

## Machines

* **`foundation`**: an aarch64 Linux container on niss, 11 CPUs, long-lived.
  Main checkout `/work/Foundation`. alr 2.1.1, gnatprove FSF 16.1.0,
  gprbuild 26.0.1, on an interactive shell's PATH only. **A tick's or the
  orchestrator's shell has none of them**: pass
  `env PATH=/home/tony/Software/alr/bin:~/.local/share/alire/toolchains/gnat_native_16.1.0_*/bin:~/.local/share/alire/toolchains/gprbuild_*/bin:~/.local/share/alire/releases/gnatprove_16.1.0_*/bin:$PATH`.
  GNAT's own `objdump` is in the gnat_native bin; there is no system
  `objdump`, `gdb` or Valgrind. Cryptol 3.6.0 built from source with FFI
  (`~/.local/bin/cryptol`; headers in `~/.local/sysroot`). **No system C
  toolchain**: GNAT's gcc is the only one. No SAW, no GNAT-LLVM (neither
  exists for aarch64 Linux). `/tmp` is a ramfs. `spark-scheduler` pool of 10.
* **The x86_64 IOD**: dies 24 hours after it starts. **8 CPUs, 15.7 GB RAM,
  no swap; the request has no memory option** (Tony checked). Bootstrap with
  `spark/scripts/bootstrap-x86_64.sh` (PR #46) on a bare image; it fetches
  the pinned llvm-link and, when `GNAT_LLVM_DIR` names a GNAT Pro LLVM
  install, records it. No scheduler: gnatprove with `PROVE_JOBS=$(nproc)`.
  **Push after every commit.** Needs root or passwordless sudo only if the
  image lacks the apt prerequisites the script names.
  The IOD comes with a GNAT Pro 27 install (GNAT Pro, SPARK Pro and GNAT
  Pro's LLVM back end). On 2026-10-21 it was set up by
  `FOUNDATION_TOOLS=<tools dir> bootstrap-x86_64.sh --no-checks` (65 s;
  passwordless sudo), **without** `GNAT_LLVM_DIR`, then two lines added to
  the tools directory's `env.sh` by hand: `GNAT_LLVM_DIR` (GNAT Pro's LLVM
  back end, holding `bin/llvm-gcc`) and `LLVM_LINK_DIR`. The GNAT Pro 27
  install provides a matching `llvm-link` (21.1.8), so the LLVM tarball is
  not needed. **The concrete paths are not in this repository** (it is
  public): they are in memcp (session of 2026-10-21/22). Valgrind 3.22 by
  apt (in the bootstrap since PR #90). A default SAW record takes about
  60 min, the long one about 130 min, on one core.
* **niss** (the host of `foundation`, M5 Pro, 64 GB): the fallback if a SAW
  proof ever needs more than the IOD's memory. SAW ships for macOS arm64 (not
  aarch64 Linux), so that would mean compiling and linking on the IOD and
  verifying on niss's macOS host. Not needed so far: every SAW proof runs in
  under 1 GB once composed.

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
    with the reason in its comment. Five such statements remain (listed in
    "Next").
* **SAW waits for one IOD session** (Tony, 2026-10-20): spec and
  implementation changes land on `foundation` first, each PR editing its
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
* **Plan location.** This file. There is one `PLAN.md`; its history is git's.

## Open for Tony

* **Rewrite the fork's history** (Tony, 2026-10-22, from another session).
  The fork is public, and its history (and two SAW-input files that cannot
  change without a SAW re-record: `spark/scripts/check-saw.sh`'s comment
  example and the results files' `runtime` line) still holds internal host
  names, install paths and toolchain package names. Forward commits (PR #97,
  PR #98, the bootstrap/scrub PR) and edited PR bodies removed the rest. The
  list of patterns is in memcp (session of 2026-10-21/22). Tony does the
  `git filter-repo` and force-push.
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
* **A tick changed global Alire state** on `foundation` (2026-10-20). Check
  `~/.config/alire`.
* **The IOD's global `~/.claude/CLAUDE.md`** is a mempalace leftover; Tony
  said to ignore it (use memcp). Delete it on the next image if wanted.
* **memcp's SessionStart hook** injected no surface on the IOD, and `hex`'s
  SessionEnd uploads are failing (3 of 19 sessions): `doctor`, or redeploy
  the hooks.

## Live ambushes

* **The auto-mode permission classifier** blocks wrapper commands it has no
  allow rule for (`spark-scheduler run ... -- env ...`), and then grows
  suspicious of nearby commands. `.claude/settings.local.json` on `foundation`
  (untracked, Tony's) allows `spark-scheduler run/status`,
  `[spark/]scripts/prove.sh`, `[spark/]scripts/check-*.sh`,
  `python3 [spark/]scripts/board.py`. Start commands with those prefixes.
  The classifier refuses to let the orchestrator edit settings itself.
* **A fresh worktree has no Alire workspace**: `alr -n build` in its
  `spark/` before any proof, or gnatprove fails at once with "imported
  project file config/foundation_spark_config.gpr not found" (`alr -n
  exec` does not generate it; re-checked after #72). On `foundation`, `alr`
  is `~/Software/alr/bin/alr` and the toolchain comes from
  `~/Software/null_crate`'s `alr printenv`; neither is on a tick's `PATH`
  by default.
* **Moving a spec body behind a prelude instance can time out an
  implementation lemma**, even with the same formula (#83, #85). Five cases
  are known and none is explained. Bisect primitive by primitive against
  the implementation lemmas: it takes about 1–2 min per unit. Restating GF2
  can also blow up `SBox_Entries`: GF2's `pmult` via the prelude ran past
  77 min for 9 of its 32 subprograms.
* **gnatprove warns on a `Subprogram_Variant` of a function that no longer
  recurses**, and the gate fails on warnings (#85 removed eight).
* **GNAT 16.1 and generics** (#82): a `Static` function called in an
  instance's expression function crashes the compiler; read a constant
  instead. A Pure library-level instance needs a static actual, so its
  subtype needs a `Static_Predicate`.
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
  #84/#85) it fails on six x86_64 timeouts ("Open for Tony").
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
* **Subagent reports call `foundation` "hex"** out of habit: the numbers are
  from `foundation`.
