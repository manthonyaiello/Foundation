# The campaign plan: SPARK AES, SHA-256 and HMAC against the Cryptol

**Provenance.** Rewritten 2026-10-19 (evening, UTC); updated 2026-10-20
(08:15 UTC) at `9d750d8` (the merge of PR #65), on the x86_64 IOD just before
Tony shut it down; updated again 2026-10-20 on `foundation` after Tony's
review of E4's loose ends and the small items (no code changed; issues
#67–#70 filed), and again after his side-by-side review of the AES spec
layer against the Cryptol (no code changed; #72–#74 filed). The gnatprove board was re-counted on 2026-10-19 on
`ec57e9e` on the IOD with FSF 16.1 (`check-proof.sh`, `-j8`, CI allowance:
3554/3554, 786 s); PRs #57–#66 since changed no `spark/src`, `spark/cryptol`
or FFI script. The SAW numbers are `spark/saw/results.txt` (default run) and
`results-long.txt` (`SAW_LONG=1`) at `9d750d8`; the orchestrator re-ran the
default at the head of each PR. **Open:** #67–#70, #72–#74 (below) and
E5's #50, #51.
**E0–E4 are closed** (epic #21 closed 2026-10-20); E5 remains.
**The day's measurements** are in `.claude/campaign/measurements/2026-10-19-iod.md`.

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

Counted on `main` (gnatprove at `ec57e9e`, unchanged since; SAW at `9d750d8`):

* **37 of 40 functions complete** (spec exists and is FFI-checked,
  implementation proved, no holes).
* **53 units, 3554 checks in the default gate: 3554 proved**, 0 justified,
  0 unproved. Plus one slow unit proved on demand:
  `foundation_spark-aes-spec-properties-sbox_entries`, 2482/2482, proved at
  `46c5799`, fingerprint current.
* **Holes:** 0 assumes, 0 justifications, 0 `SPARK_Mode Off`, 0 warning
  suppressions, 0 check suppressions. 21 foreign bindings (the FFI export
  units, each justified in `spark/scripts/trust-surface.txt`).
* **FFI:** 119 properties, all passing (50+ AES, SHA-256, HMAC; see
  `spark/cryptol/properties.txt`). CI FFI job about 10–14 min on x86_64.
* **SAW (implementation layer, local, GNAT Pro 27 LLVM bitcode, -O0):**
  87 proved, 8 negative controls fail as they must, 0 assumed specs
  (`check-saw.sh` refuses `llvm_unsafe_assume_spec`). AES: 19 leaves plus
  `Expand_Key`, `Encrypt_Block`, `Decrypt_Block` at k = 128/192/256 against
  ``KeyExpansion`{k}``, ``Cipher`{k}``, ``InvCipher`{k}``. SHA-256: 19 leaves,
  `Compress` = `step` for all inputs, `Hash` at 0, 1, 55, 56, 63, 64, 65, 100,
  119, 120, 128, 200 bytes; HMAC at (key, text) = (0,0), (32,3), (32,32),
  (64,3), (64,32), (65,3), (100,32). **4 of them (Hash at 0/64/128, HMAC
  (0,0)) are in a lax-arithmetic module** (null-range poison, below): there,
  absence of overflow rests on gnatprove, not SAW (accepted, below).
* **SAW (spec layer, #59, PRs #63 and #65):** default run **2742 proved**
  (AES 1083, SHA-256 + HMAC 1659), **1393 of them lax**; `SAW_LONG=1` **3522**
  (2173 lax). 0 assumed specs. AES: GF(2)/GF(2^8), **`Affine` and
  `GF2::inverse` for every byte** (the two rows below that have no
  implementation), the round functions, `KeyExpansion.W` per index
  (44/52/60 lemmas, never unfolded), KeyExpansion, Cipher, InvCipher,
  InvCipher', and Main's **`Encrypt`/`Decrypt`/`AES128/192/256`** (through
  the `gep64` rewrite of `Join_Block`, which #68 retires). SHA-256: `W` per index,
  `Step` = NSA's `step`, **`Pad` at the 12 M4.3 lengths**, `Hash` at 9
  lengths (3 more under `SAW_LONG`: 120, 128, 200 bytes). **HMAC** = NSA's
  `HMAC` at one (key, text) per key case by default ((32,3), (64,32),
  (65,3)), all seven M4.3 pairs under `SAW_LONG`. Spec-layer rows
  SAW-proved: **38 of 40** (not: `parse` on its own, which #67 adds; `hash`
  over bytes, a SPARK-side representation layer, which #67 documents).
* **SAW in all, default run:** 2829 proved, 19 negative controls fail, 3838 s
  (orchestrator's re-run at `86e7e2d`; tick's record 3785 s), peak 3.84 GB.
  `SAW_LONG=1`: 3609 proved, 7784 s, peak 7.23 GB. `board.py`'s SAW column
  still prints "not run" (#67).

The three rows the board counts incomplete, though complete by design (Tony,
2026-10-20; #67 gives them row kinds so the board says so):

| row | why |
|---|---|
| `AES::SBox::affine` | ghost-only by design (#12); the implementation reads the S-box table, which `SBoxCorrect` proves equal to `affine` for every byte |
| `GF2::inverse (AES)` | same |
| `SHA2::Preprocessing::pad` | no executable counterpart: `Final` writes only the last one or two padded blocks, proved through `Hash` |

`Ch`, `Maj`, Σ, σ are "impl = spec" rows: the spec functions are non-ghost
`Unsigned_32` functions that `Compress` calls at run time.

## The issues

| epic | sub-issues | state |
|---|---|---|
| **#1** E0 infrastructure | #2 Cryptol/SAW · #3 CI · #4 FFI harness · #5 levels, board · #6 x86_64 bootstrap | all closed |
| **#7** E1 AES | #8 #9 #10 #11 #12 | all closed |
| **#13** E2 SHA-256 | #14 #15 #16 #17 | all closed |
| **#18** E3 HMAC-SHA-256 | #19 #20 | all closed |
| **#21** E4 SAW | #22 M4.1 spike · #23 M4.2 AES · #24 M4.3 SHA-256 and HMAC · #59 M4.4 spec layer | all closed (PRs #57, #58, #60, #63, #65) |
| **#48** E5 assurance beyond the proofs | #49 M5.1 coverage · #50 M5.2 constant time · #51 M5.3 binaries and performance | #49 closed (PR #55); #50, #51 open |

## Next

Done on 2026-10-19, on the x86_64 IOD with Tony's GNAT Pro 27.0 install:
* **Tool sanity** (Tony asked): FSF 16.1 gate 3554/3554 (786 s, `-j8`).
  SPARK Pro 27 gnatprove on the same tree: `sbox_entries` 2482/2482 (2836 s,
  level 4, max VC 20 s), but the default gate **3641/3645** with the CI
  allowance: 4 Pro-27 regressions, listed under "Small items". The crate stays
  on FSF 16.1 (Tony), so these are not gate failures.
* **#22 M4.1** (PR #57): GNAT-LLVM 27 (LLVM 21.1.8) bitcode loads in SAW 1.6
  (without `-g`); `X_Times`, `Sub_Byte`, `Sub_Bytes` proved; the bitcode ABI
  written down (README "The bitcode ABI").
* **#23 M4.2** (PR #58): AES at k = 128/192/256, no assumptions, by linking
  the units with a pinned `llvm-link` 21.1.8 (LLVM's own release).
* **#24 M4.3** (PR #60): SHA-256 `Compress` for all inputs, `Hash` and HMAC
  at fixed sizes; `check-saw.sh` caps every SAW run at 10 GB.
* **#59 M4.4** (PR #63, `Part of #59`): the spec layer, 2162 results (board
  above). Spec bitcode: `saw/spec.adc` (`Assertion_Policy (Ignore)` then
  `(Ghost => Check)`; GNAT rejects the `others =>` form), `-gnatp`,
  `-fno-inline` (GNAT-LLVM marks expression functions `alwaysinline`).
  GNAT's runtime (`s-secsta`, `s-soflin`) is compiled and executed for the
  secondary stack; `saw/saw_soft_links.ads` is a one-line trusted harness
  adapter (static chain). `saw/SHA256Step.cry` copies `step`'s local
  definitions, tied to NSA's `step` by the `Step` proof.
* **#59 closed** (PR #65, 2026-10-20): the HMAC spec layer (`saw/HMACInit.cry`
  copies Main.cry's private `HMAC_init` word for word; HMAC's proof against
  NSA's public `HMAC` ties it), AES Main through `gep64`, `Hash` at 3–4
  blocks under `SAW_LONG=1` (writes `saw/results-long.txt`). The default
  `check-saw.sh` takes about 64 min; `SAW_LONG=1` about 130 min. The
  bootstrap extracts `opt` and `llvm-extract` too (for `gep64`).
* The raw logs of 2026-10-19/20 are untracked in the main checkout of the IOD
  (`.claude/campaign/runs/2026-10-19-iod/`), retrieved by Tony at shutdown;
  every number that matters is in the measurements file.

1. **#67** (no GNAT Pro needed except item 3): board row kinds
   (`spec-only`, `subsumed-by`, `impl = spec`; the board goes to 40/40),
   the statements of where spec and implementation are not one-to-one and
   why that is intended, SAW's standalone `Parse`, the documentation of what
   SAW proves in place or leaves out and why, fixed sizes as NSA's own
   practice, where SPARK's proof is stronger, `board.py`'s SAW column, and
   `alire.toml` in the slow-proof fingerprint. Tony may batch more into it.
2. **#68**: narrow AES's `Bit_Index` to what AES needs and retire `gep64`
   (SAW re-run needs GNAT Pro).
3. **E5**: **M5.2 (#50)** constant time (the AES table S-box leaks), then
   **M5.3 (#51)** binaries and performance (x86_64 numbers need an IOD; it
   adds gnatcov to the x86_64 bootstrap when it needs it). Neither needs
   GNAT Pro.
4. **#69**: why SAW costs about 100 times more on the spec layer; **#70**: a
   cheaper `SBoxCorrect` proof.
5. **#72**: remove the unused SPARKlib dependency. **#73**: Tony's AES
   spec-layer review feedback, an umbrella he adds to: `Key k` as a
   `Key_Size` subtype with a predicate (decided); one `foldl` generic and the
   two unstated `SBox.cry` properties (open for Tony).
6. **#74**: spike a generic AES spec over the key size, bridged to the
   flexible implementation by ghost dispatchers; a draft PR with
   measurements decides "AES key sizes" (below).

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
  unproved pieces → #67; one bit-sequence type → #68 (AES and SHA-2 now
  keep different index types on purpose); why SAW of the spec layer is harder
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
  gprbuild 26.0.1 on PATH; Cryptol 3.6.0 built from source with FFI
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
  On 2026-10-19 the instance (`ip-10-10-101-245`) had Tony's GNAT Pro 27.0
  under `/it/Software/27.0/x86_64-linux/` (`gnatall`, `spark2014`,
  `gnatpro-llvm-ada`, ...; the first two on PATH) and was set up **by hand,
  not by the bootstrap**: alr 2.1.1 with Pro 27 as its default toolchain; the
  FSF gate toolchain in separate Alire settings
  (`/it/foundation-tools/alr-fsf`, wrapper `/it/foundation-tools/bin/alr`);
  Cryptol, SAW and llvm-link under `/it/foundation-tools`; everything a tick
  needs in `/it/foundation-tools/env.sh`.
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
* **AES key sizes.** **Under reconsideration (Tony, 2026-10-20), pending
  the spike #74.** Now: unconstrained arrays with an explicit `K` and
  `Is_Key_Words`/`Is_Round_Keys` preconditions, held through M1.4, no
  generic. This is the spec layer's largest deviation from the Cryptol, whose
  `{k}` functions `AES128 = AES`{128}` instantiates.
  * *First review, earlier the same day:* kept. A generic mirrors `{k}` more
    closely (lengths in the subtypes, no `Is_*` preconditions, Cryptol's
    arities, `AES128` an instance), but proof time triples and the
    implementation would either triple its executable footprint or need
    bridging proofs to three generic specs.
  * *Why reopened:* that weighed the wrong alternatives. Only the `{k}`
    functions need be generic (`KeyExpansion`, `Cipher`, `InvCipher`,
    `InvCipher'`, `Encrypt`/`Decrypt`). `Round`, the S-boxes, GF(2^8) and
    their lemmas stay non-generic and are proved once. The instances'
    subtypes constrain the existing unconstrained types, so the
    implementation stays flexible in `K` with no conversions. The bridge is
    one ghost dispatcher per `{k}` function (`case K is when 128 =>
    AES128.Cipher (W, S) …`), named by the implementation's postconditions.
    Tripling is confined to the `k`-dependent parts. The unknown is the
    lemmas the three-way split needs.
  * *Decide on:* #74's proof times, lemma churn and reading of the generic
    `Cipher` beside `Cipher.cry`. `Key k` becomes a `Key_Size` predicate
    subtype either way (#73), the formal's subtype under the generic.
* **SHA-2 generality.** A generic mirroring `SHA2::Main`, instantiated for
  SHA-256 only. Library-level instances need `pragma SPARK_Mode (On)`.
* **Bit sequences.** Ghost Boolean arrays, length < 2**64. SHA-2's index is
  128-bit because Cryptol's domain needs it: messages up to 2**64 − 1 bits,
  padded past Ada's 64-bit range. AES's index is to be narrowed to what AES
  needs (#68; Tony, 2026-10-20: wide types are not a way to avoid proving
  absence of overflow). Ghost only, so no run-time cost either way.
* **Fixed-width words** (Tony, 2026-10-20): AES bytes are `Unsigned_8` with a
  Cryptol-order bit accessor (`Bit_Of`), not Boolean arrays; Boolean arrays
  are for arbitrary-length sequences only.
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
  script refuses one. A lax-arithmetic module is allowed only where
  null-range poison forces it, and each such result is marked.
* **Lax-arithmetic SAW results are accepted** (Tony, 2026-10-19): in them SAW
  proves the functional equality and gnatprove proves absence of overflow.
  Tony: this is good for highlighting the value of SPARK. Keep them marked
  and counted separately.
* **The spec layer keeps Cryptol's meaning, not its evaluation strategy.**
  Recursive definitions stay recursive ghost functions (e.g.
  `KeyExpansion.W`); sharing is the implementation's job, and SAW gets it by
  per-index overrides (#59 discussion, 2026-10-19).
* **Plan location.** This file. There is one `PLAN.md`; its history is git's.

## Open for Tony

* **`llvm-link` from GNAT Pro** (2026-10-20): Tony is asking internally
  whether GNAT-LLVM can ship `llvm-link` (GNAT Pro 27 ships none). Until
  then the bootstrap keeps fetching LLVM 21.1.8's release tarball (2 GB,
  sha256 pinned). After #68, only `llvm-link` is needed from it.
* **crucible-llvm and wide GEP indices**: Tony is deciding whether to raise
  `calcGEP_array`'s 64-bit limit with Galois. The draft in PR #65 predates
  the finding that a precise request should include LangRef's `trunc nsw` /
  `trunc nuw` rules for `nusw`/`nuw` GEPs. #68 removes our need either way.

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
  or pins change; when they do, it adds 35–50 min per job.
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
  when a constrained array with a 128-bit index type is indexed directly);
  `check-saw.sh`'s `gep64` handles the one case, and dies on a new one.
* **zsh**: a word starting with `=` is a command lookup; `$var` with spaces
  is not word-split (use `${(f)...}` arrays); `for` loops over a string
  of names need splitting.
* **`gh pr create` on a fork** defaults to the upstream. Always
  `--repo manthonyaiello/Foundation`.
* **Subagent reports call `foundation` "hex"** out of habit: the numbers are
  from `foundation`.
