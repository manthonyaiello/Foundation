# Proving

How the crate is proved with gnatprove (FSF 16.1.0): the one script that
calls it, the committed proof levels, the board that counts the results,
the slow units proved on demand, and the CI gates. Where the spec layer
and the implementation are deliberately not one-to-one, and the Cryptol's
own properties re-proved in SPARK, are here too. Back to the
[README](../README.md).

## Running gnatprove

`scripts/prove.sh` is the one way to call gnatprove, for local runs and for
CI's proof gate alike. It runs, from `spark/`:

```console
alr -n exec -- gnatprove -P foundation_spark.gpr -j$PROVE_JOBS [-u FILE ...] [ARGS after --] $GNATPROVE_EXTRA
```

`PROVE_JOBS` defaults to `nproc` (`getconf _NPROCESSORS_ONLN` where there is
no `nproc`, as on macOS); set it on a shared machine. `alr -n exec`
runs gnatprove in the crate's Alire environment (the toolchain Alire
selected, on `PATH`). The project `with`s
`config/foundation_spark_config.gpr`, which Alire generates from
`alire.toml` (it is gitignored) on `alr -n build`, not on `alr -n exec`: in
a fresh checkout or worktree, build once first, or gnatprove stops at once
with "imported project file ... not found". The log
(`obj/prove.log`, or `PROVE_LOG`) starts with the command line, `-j`
included, the commit, and the allowance. The script

- refuses `--level`, `--timeout`, `--steps`, `--memlimit`, `--prover` and
  `-j` in its arguments and in `GNATPROVE_EXTRA`, and a literal `--level` or
  `--timeout` in a `Proof_Switches` of the GPR: levels are the GPR's (below);
- deletes `gnatprove.out` and the `.spark` file of every unit in scope before
  the run, and fails (exit 3) unless the run wrote both anew. A run that
  stops early therefore cannot be summarised, by itself or by `board.py`,
  from an earlier run's `obj/`. Units out of scope keep their `.spark`, so
  `board.py` marks a unit `stale` when a source file is newer than it.

A job scheduler can wrap the call to `prove.sh`; it must pass its grant to
gnatprove as `PROVE_JOBS` (so `-j`), because gnatprove has no other way to
learn it.

## Levels

Each unit's proof level is committed in `foundation_spark.gpr`, package
`Prove`: the crate default is `Level_2`, and a unit raised above it has its
own entry, `for Proof_Switches ("<file>") use Level_3;`, with the reason in
the commit. The `Level_N` lists are the only way a level is written, and the
same entries serve local runs and CI.

**A command-line `--timeout` overrides a per-file level's timeout**, and so
shortens a raised unit's allowance. Measured with gnatprove 16.1.0 on a
scratch unit, reading the limits gnatprove hands to gnatwhy3 (`-d` keeps them
in `obj/*/gnatprove/*.tmp`):

| switches | the unit's prover timeout |
|---|---|
| `--level=2` (default) | 5 s (memlimit 1000) |
| per-file `--level=3` | 20 s (memlimit 2000) |
| per-file `--level=4` | 60 s (memlimit 2000) |
| per-file `--level=4`, command-line `--timeout=10` | **10 s** |
| per-file `--level=3 --timeout=45`, command-line `--timeout=10` | **10 s** |
| per-file `--level=4`, `"Ada"` default `--level=2 --timeout=10` | **10 s** |
| per-file `--level=4 --timeout=60`, `"Ada"` default `--timeout=10` | 60 s |

So an explicit `--timeout` beats the level, the command line beats the GPR,
and the `"Ada"` default's switches reach every file that has its own entry.
#3's CI passed `--timeout=10` on the command line: harmless at level 2 (it
lengthens 5 s to 10 s), but it would have proved a level-3 or level-4 unit
with 10 s.

CI's allowance is now `FOUNDATION_SPARK_PROOF_ALLOWANCE=ci` (set in
`.github/workflows/spark-prove.yml`). Under it, each `Level_N` list carries an
explicit timeout of max (the level's own, 10 s): 10 s at level 2, 20 s at
level 3, 60 s at level 4. A raised level is never shortened. Locally (the
default, `none`) a level is just the level.

**The local default is marginal on a loaded machine.** Level 2's 5 s leaves
little room: on 2026-10-22, on an arm64 Mac under load, the three
`AddRoundKey` assertions in `foundation_spark-aes-lemmas.adb` (lines 74, 93
and 115) timed out at 5 s, and proved under
`FOUNDATION_SPARK_PROOF_ALLOWANCE=ci`, the gate's 10 s. To reproduce the gate
locally, set it.

## The board

`scripts/board.py` (Python 3, standard library only) counts the board
from what is on disk: the `.spark` files of the last `prove.sh` run
(`obj/*/gnatprove/`), each unit's level from the GPR, the trust manifest, the
rows file and the FFI log. `scripts/board.py` prints markdown;
`--json` prints JSON, and `--json-out FILE` writes it beside the markdown. It
reports and does not gate.

It prints one row per function (kind, spec, FFI-checked, impl proved, SAW,
holes, complete) and one per tracked unit (level, entities analyzed, checks
proved, unproved, and the manifest's assumes, justifications, `SPARK_Mode
Off`, warning and check suppressions and foreign bindings, and whether the
unit's `.spark` is `fresh`, `stale` or `missing`). A row is complete, as the
plan says, when the spec exists and is FFI-checked and its implementation is
proved with zero unproved checks, assumptions and justifications, or, for a
row with no implementation by design, when what covers it is (its kind,
below).

**Rows.** A function's spec and implementation live in different units, so
`scripts/board-rows.txt` maps each row to both, and optionally gives the
row's kind:

```text
# function | spec entity | impl entity [| kind]
AES::GF28::xTimes | Foundation_Spark.AES.Spec.GF28.xTimes | Foundation_Spark.AES.Impl.X_Times
```

The function is the Cryptol declaration, qualified by module. The entities are
named as gnatprove names them in the `.spark` files (for a generic, the
proved instance's entity). The file is the board's denominator: a tick that
adds a spec-layer function adds its row, and the tick that implements it fills
in the impl entity.

**Row kinds** (#67). The fourth field says how the row is complete; a row
without one is `impl`:

| kind | impl entity | complete when |
|---|---|---|
| `impl` | the implementation | the spec is FFI-checked, and the impl entity and its unit are proved |
| `impl = spec` | the spec entity itself | as `impl`: the spec function is executable, and is the implementation |
| `spec-only E ...` | `-` | the spec's unit is proved, and so is each entity `E` (the proofs that tie the spec to the implementation, a slow unit's by its current recorded proof); an FFI property is not needed, and one that exists must pass |
| `subsumed-by F` | `-` | the spec is FFI-checked, and row `F` is complete: `F`'s proof is the proof of this row's spec |

The board prints a `spec-only` or `subsumed-by` row that is complete as
"yes, by design", and counts them in its summary. The next section says
which rows these are, and why.

**SAW.** The SAW column reads `saw/results.txt`, the record of the last
default `check-saw.sh` run (local only, GNAT Pro; [saw.md](saw.md)): per row,
the results whose subprogram is the row's spec entity (`spec`) and its impl
entity (`impl`), with how many of them are in the lax-arithmetic module, or
`-` for none. A result matches an entity when its name's parts are the last
parts of the entity's qualified name (`sha256_stream.hash` is
`Foundation_Spark.SHA2.SHA256_Stream.Hash`, `cipher__subbytes` is
`Foundation_Spark.AES.Spec.Cipher.SubBytes`). Under the table it summarizes
`results.txt` and `results-long.txt`: the commit and date they were
recorded at, the results in all, of the implementation and of the spec
layer, the lax ones of each, and how many rows have a result of their own.
A row without one is not unproved by SAW: SAW executes it inside a
result of its caller, or leaves it out, for the reasons in [saw.md](saw.md).

A SAW record is **stale** when what SAW read has changed since: a `source`,
`cryptol` or `spec.adc` file whose sha256 is no longer the one recorded, or
a SAW script (`saw/` but for the records and `saw/experiments/`, which no
recorded run loads; `scripts/check-saw.sh`; `scripts/toolchain-pins.env`)
that differs from the recorded commit's (when this checkout has that
commit). The board then says **STALE**, names the changed inputs, and marks
every row's SAW cell "(stale)": the results are not this tree's until
`check-saw.sh` is run again. The board cannot re-run SAW (no GNAT Pro in
CI); it reports the record honestly.

**FFI log.** `scripts/check-ffi.sh` (M0.3) writes `obj/ffi/ffi-results.txt`,
one line per property, `|`-separated, `#` for comments:

```text
# property | function | mode | run | passed | commit
prop_xTimes | AES::GF28::xTimes | exhaust | 256 | 256 | 68d0872
```

`mode` is `exhaust` or `check` (Cryptol's `:exhaust` or `:check`), `run` the
number of tests run, `passed` the number that passed, and `commit` the
commit the SPARK side was built from (`git rev-parse --short HEAD`). The
`function` matches the row. A function is FFI-checked when it has at least
one property and every one passed all of its tests. The board shows "not
run" while the file does not exist, and a property's commit when it is not
the board's. A property that fails is logged with `passed` 0: Cryptol stops
at the first counterexample and does not say how many tests passed before it.

## Where spec and implementation are not one-to-one

The spec layer mirrors the Cryptol declaration by declaration; the
implementation is shaped for execution. Mostly there is one implementation
entity per spec function, proved equal to it. In the places below there is
not, **by design** (a campaign decision of 2026-10-20). Each is covered by
a proved function, so none is a hole or a missing proof. The board shows each by its row kind.

| row | kind | covered by | why this is the design |
|---|---|---|---|
| `AES::SBox::affine`, `GF2::inverse (AES)` | `spec-only` | `Impl.Sub_Byte`'s postcondition is `Spec.SBox.SBox (B)`, the table (row `AES::SBox::SBox`, `prop_SBox` `:exhaust` 256). `Spec.Properties.SBoxCorrect` proves `Affine (B) = SBox (B)` for every byte, from the slow unit `Spec.SBox.SBox_Entries` (`Lemma_SBox_Entry`, 2501 checks). `Affine` is built on `Inverse`, so the one proof ties the table to both | The implementation reads the S-box table, as FIPS 197 presents it and as practical AES does; `SBox.cry` defines the table and states `SBoxCorrect` relating it to `affine`, and the spec mirrors both. No FFI property for the two (a campaign decision of 2026-10-20): the proof chain does not need one, and the table they equal is FFI-checked. SAW proves both at the spec layer for every byte |
| `SHA2::Preprocessing::pad (SHA-256)` | `subsumed-by SHA2::Main::hash (SHA-256)` | `SHA256_Stream.Hash`'s postcondition is the spec's `Hash`, which is defined through `Pad` (as `hash` is through `pad` in `Main.cry`). `Final` writes only the padded message's last one or two blocks (`Tail_Pad`), and `Lemma_Final` proves them those of `Pad (M)` | A streaming hash never builds the padded message: it would cost a copy of the whole message. `Pad` itself is FFI-checked (`prop_pad`, `:check` 100) and SAW-proved at the spec layer at twelve lengths |
| `SHA2::Functions::Ch`, `Maj`, `SIGMA_256_0/1`, `sigma_256_0/1` | `impl = spec` | the spec functions themselves, proved free of run-time errors and FFI-checked | `Functions.cry`'s functions are on `[32]`, which the spec states on `Unsigned_32` with no change of representation, so the spec functions are executable and are what `Compress` calls at run time. A second implementation, or a wrapper, would add a name, not a proof |
| `SHA2::Main::hash (SHA-256, bytes)` | `impl` | `SHA256_Stream.Hash`, proved equal to `SHA256_Bytes.Hash_Bytes` and to the spec's `Hash` on the message's bits | `Hash_Bytes` is not a Cryptol declaration: it is SPARK's representation layer, `Hash` on the bits of a byte array, proved equal to it by gnatprove (`Lemma_Hash_Bytes`). It is the row through which the byte-level FFI properties (`prop_Hash_Bytes`, `prop_Stream_*`) reach `hash` |

Three of these are counted complete "by design" on the board (`affine`,
`inverse`, `pad`); the `impl = spec` and `Hash_Bytes` rows are complete in
the ordinary way. The parts of the implementation that do have a spec
counterpart but that SAW does not prove on their own are in [saw.md, "What SAW proves on its own, in place, or not at all"](saw.md#what-saw-proves-on-its-own-in-place-or-not-at-all).

## The Cryptol's own properties, re-proved

`AES.Spec.Properties` states and proves, of the SPARK spec layer, 13 of the
15 properties that `algorithms/AES` states about itself
(`GF28MultiplicationCorrect`, `SBoxCorrect`, `SBoxInverts`, the `*Inverts`
of `Cipher.cry`, `InvCipherEquivalence`, `EncryptInverts`, and the others
its header lists). **They are optional, and they are kept for now** (a campaign
decision of 2026-10-20; #67):

- **Optional.** SAW proves the spec layer equal to NSA's Cryptol at k =
  128, 192 and 256, which is all of AES, so the Cryptol's properties
  already hold of the SPARK spec. (Since #80 the `{k}` functions are the
  instances `AES128`, `AES192`, `AES256` of the generic `AES_K`, one per
  key size, each proved by SAW.) `Properties` states the four properties that take a key size
  (`InvCipherEquivalence`, `CipherInverts`, `CipherInverts'`,
  `EncryptInverts`) once, over the dispatchers of `Spec.Dispatch`, not
  three times in the generic. In general, re-proving a higher-level
  spec's properties after moving to SPARK adds proof cost without adding a
  theorem. `SBoxCorrect` is the extreme case: 1122 s of gnatprove on an
  aarch64 Linux container for the slow unit `SBox_Entries` (1 h 40 min cold in
  CI) for a closed property that Cryptol evaluates in under a second, about
  a table that is textually identical in both specs.
- **Kept for now, because SAW is not in CI.** The transfer rests on a local
  SAW run (GNAT Pro 27, recorded in `saw/results.txt`), and any change to
  the spec suspends it until SAW is run again (the board says so:
  **STALE**). The properties are re-proved on every PR, so until SAW runs in
  CI they are the continuously checked cross-check that the SPARK spec is
  right.
- **Two are not stated:** `SBoxPolynomialIsIrreducible` and
  `inverseCorrect` (#73 item 3). For the reason above, that is acceptable.
- **What the transfer assumes.** SAW proves the spec layer's bitcode equal
  to the Cryptol, while gnatprove reasons about the Ada source. Carrying a
  property from the Cryptol to the source assumes GNAT-LLVM compiled the
  ghost spec faithfully.

## Slow proofs

A unit whose proof is too slow for the default gate is **proved on demand,
not by the gate, and the gate detects when anything it depends on changes**,
so it is known when to prove it again. The first was #12's generated
`SBox_Entries` (SBox.cry's `SBoxCorrect` by case enumeration): about 26 min
cold on an aarch64 Linux container and 1 h 40 min cold in CI.

**Marking a unit slow.** One of its files carries the comment

```ada
--  Slow proof: proved on demand (scripts/proof-slow.txt).
```

(a generated unit gets it from its generator), and `scripts/proof-slow.txt`
has its entry. The gate fails when a marked unit has no entry, or an entry
names a unit that is not marked or does not exist.

**The entry** is written by `scripts/prove-slow.sh` after a successful
proof, never by hand except its `reason`:

```text
unit src/aes/foundation_spark-aes-spec-sbox-sbox_entries.adb
  reason      ...
  commit      <the commit proved>
  date        <its date, UTC>
  level       4
  checks      <proved>/<total>
  fingerprint sha256:<over the input lines>
  input       <first 16 digits of the sha256> <input name>
  ...
```

**The inputs** are computed by `scripts/slow_proofs.py`, not listed by hand:

- the spec and body of every unit in the unit's closure under `src/`: the
  unit, its parents, every unit its context clauses `with` (limited and
  private ones too), their parents, and so on, through the spec and the body
  of each. A body is included because it can change what gnatprove assumes
  of its unit (generated `Global` contracts, a generic's instance), so the
  closure errs towards staleness. Units outside `src/` (the runtime) are
  listed in the verbose output but not hashed;
- `alire.toml`, the crate's manifest: it pins the crate's dependencies and
  its build switches (`ada_version`), which gnatprove reads too (#67, a
  follow-up of PR #44);
- the GPR's proof switches for those files: the `Prove` package's level
  definitions, `Proof_Switches ("Ada")`, and each input file's own
  `Proof_Switches`;
- the generator, for a generated unit (its file says `Generated by
  scripts/<script>`);
- the gnatprove, why3 and prover versions (`gnatprove --version`, install
  paths stripped, as in CI's cache key).

The closure is found by parsing context clauses rather than from the
compiler's `.ali` dependency lines because the gate must answer before
anything is compiled, on a checkout with no `obj/`. `slow_proofs.py inputs
FILE --ali` cross-checks the parse against the `.ali` files of a build.

Each input is hashed (sha256, its first 16 hexadecimal digits), and the fingerprint
is the sha256 of the `<digest> <name>` lines sorted by name. The entry keeps
the lines, so a stale entry names the inputs that changed.

```console
$ scripts/slow_proofs.py inputs FILE -v     # the fingerprint and its inputs
$ scripts/slow_proofs.py check -v           # what the gate checks, verbosely
```

**The default gate** (`check-proof.sh`, so CI's prove job and the daily cold
refresh) proves every tracked file but the slow units' (`prove.sh -u` each),
with `-A=generic-not-analyzed`: naming a generic unit by `-u` draws that
warning, which says only that the generic is analyzed through its instances,
as a whole-crate run does without saying so. The slow units' `.spark` files
are deleted first, because gnatprove's summary counts every `.spark` on disk.
It prints each skipped unit with its recorded commit, and exempts only the listed
units from the "tracked unit absent" and "entity skipped" rules. It fails
when a listed unit's inputs changed since its proof, naming them and saying
how to re-run, after proving the rest. `scripts/test-slow-proofs.sh` checks
this, including that an unlisted unit still fails both rules. The prove job
is bounded at 30 minutes, the cold refresh at 60.

**Proving on demand.**

```console
$ PROVE_JOBS=6 scripts/prove-slow.sh                 # every listed unit
$ PROVE_JOBS=6 scripts/prove-slow.sh --reason TEXT FILE   # a new one
```

It proves each unit through `prove.sh -u`, at its committed level, and on
success (every check proved, no entity skipped) rewrites its entry with HEAD
as the commit. On failure it leaves the entry unchanged. It refuses a dirty
tree, since the entry records HEAD. In CI, the `SPARK prove slow units`
workflow (`spark-prove-slow.yml`, `workflow_dispatch`, up to 180 minutes) runs
`prove-slow.sh --print`: it uploads gnatprove's output and prints the entries
in its summary. It cannot push, so the entries are committed by hand.

**When the fingerprint gains an input.** Adding an input to what
`slow_proofs.py` hashes (as `alire.toml` was, #67) makes every entry stale
although nothing its proof read has changed. `scripts/slow_proofs.py refresh
FILE` rewrites the entry's inputs and fingerprint and keeps its commit, date,
level and checks, but only when every difference is a new input that is a
file whose content is the same as at the entry's recorded commit (`git
show`). A changed or removed input, a new input that is not a file, or a new
file that differs from the recorded commit's is refused, and the unit is
proved again. The gate's STALE message offers `refresh` when every change is
a new input.

The board shows a row whose spec (or impl) entity is in a slow unit as
`slow: proved at <sha> (on demand)`, or **STALE** when the fingerprint no
longer matches, and lists the slow units' recorded checks apart from the
totals.

## Gates

CI (`.github/workflows/spark-ci.yml`) runs three gates, in this order, and
the FFI job after the docs gate ([ffi.md](ffi.md)). Each
is a script here that runs the same way locally:

- `scripts/check-trust-surface.sh`: every site in `src/` that gnatprove does
  not prove (`SPARK_Mode => Off`, `pragma Assume`, a GNATprove justification,
  a warning or check suppression, a foreign binding) is listed with a reason
  in `scripts/trust-surface.txt`. The crate is meant to be platinum, so only
  the FFI export shims belong there.
- `scripts/check-doc-placement.sh` and `scripts/check-docs.sh`: every entity
  is documented (`gnatdoc --style=gnat`, with `gnatdoc_bin=26.0.0`), and
  every doc block sits below the declaration it describes.
- `scripts/test-slow-proofs.sh` (in the trust job): the slow-proof manifest's
  change detector, and the proof gate's exemption of listed slow units (and
  only them), on a scratch copy with no prover. See "Slow proofs".
- `scripts/check-proof.sh`: gnatprove, through `scripts/prove.sh`, at each
  unit's committed level (the GPR's `Prove` package) with `--warnings=error`.
  Any unproved check fails, unless `scripts/proof-xfail.txt` allows it, and
  that file is empty. So does a tracked unit missing from the report, an
  entity of a tracked unit that gnatprove skipped (a generic instance
  without `pragma SPARK_Mode (On)` is skipped whole, and gnatprove still says
  "Success"), unless the trust manifest lists a `spark-mode-off` site in that
  unit, and a tracked unit with no entity analyzed. An imported subprogram
  (an FFI export unit's `Import` of its ghost shim) has no body and is
  reported skipped; it is allowed when its file is a `foreign-binding`
  entry and its declaration carries `Import`. The slow units are skipped,
  and their recorded proofs checked current ("Slow proofs").
