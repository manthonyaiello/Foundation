# SPARK implementations

An Alire crate (`foundation_spark`) holding SPARK implementations of
Foundation algorithms, proved against the Cryptol specifications in
`../algorithms`.

## Layout

- `src/common/` – types shared across algorithms (bit sequences, words)
- `src/aes/`, `src/sha2/` – per algorithm: a top spec layer that stays
  semantically close to the Cryptol, plus refinement layers proved
  against it
- `src/ffi/` – the FFI export shims, see "The FFI harness"
- `cryptol/` – our Cryptol: the modules that call the SPARK exports by
  `foreign` and state the properties, and `properties.txt`
- `saw/` – SAW scripts proving the implementation's bitcode against the
  Cryptol directly (E4), and `results.txt`, their record; local only, see
  "SAW"

## Toolchain

Uses gnat_native 16.1.0 and SPARKlib 16.1.0 (for
`SPARK.Higher_Order.Fold` and `SPARK.Big_Integers`). gnatprove 16.1.0
must be on `PATH`; it was installed with `alr install gnatprove` into
`~/.alire/bin`.

```console
$ alr -n build
$ PROVE_JOBS=3 scripts/prove.sh                 # the whole crate
$ PROVE_JOBS=3 scripts/prove.sh -u foundation_spark-aes-spec-gf28.ads
$ scripts/board.py                               # the board, as markdown
$ FFI_JOBS=3 scripts/check-ffi.sh                # every FFI property
$ FFI_JOBS=3 scripts/check-coverage.sh           # gnatcov under the FFI properties
```

## Proving

`scripts/prove.sh` is the one way to call gnatprove, for local runs and for
CI's proof gate alike. It runs, from `spark/`:

```console
alr -n exec -- gnatprove -P foundation_spark.gpr -j$PROVE_JOBS [-u FILE ...] [ARGS after --] $GNATPROVE_EXTRA
```

`PROVE_JOBS` defaults to `nproc`; set it on a shared machine. A bare
`gnatprove` does not find SPARKlib's project, hence `alr -n exec`. The log
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

There is no prover pool on the campaign's machine. A scheduler could wrap the
gnatprove call in `prove.sh` later; it would have to pass its grant to
gnatprove as `-j`, because gnatprove has no other way to learn it.

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

## The board

`scripts/board.py` (Python 3, standard library only) counts the PLAN's board
from what is on disk: the `.spark` files of the last `prove.sh` run
(`obj/*/gnatprove/`), each unit's level from the GPR, the trust manifest, the
rows file and the FFI log. `scripts/board.py` prints markdown;
`--json` prints JSON, and `--json-out FILE` writes it beside the markdown. It
reports and does not gate.

It prints one row per function (spec, FFI-checked, impl proved, SAW, holes,
complete) and one per tracked unit (level, entities analyzed, checks proved,
unproved, and the manifest's assumes, justifications, `SPARK_Mode Off`,
warning and check suppressions and foreign bindings, and whether the unit's
`.spark` is `fresh`, `stale` or `missing`). A row is complete, as the PLAN
says, when the spec exists and is FFI-checked and its implementation is proved
with zero unproved checks, assumptions and justifications. SAW is "not run"
until E4.

**Rows.** A function's spec and implementation live in different units, so
`scripts/board-rows.txt` maps each row to both:

```text
# function | spec entity | impl entity
AES::GF28::xTimes | Foundation_Spark.AES.Spec.GF28.xTimes | -
```

The function is the Cryptol declaration, qualified by module. The entities are
named as gnatprove names them in the `.spark` files (for a generic, the
proved instance's entity). The file is the board's denominator: a tick that
adds a spec-layer function adds its row, and the tick that implements it fills
in the impl entity.

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

## The FFI harness

The FFI check is the machine check that the spec layer says what the Cryptol
says: the SPARK spec functions are exported through C, called from Cryptol by
`foreign`, and compared with the NSA functions they mirror, with `:exhaust`
or `:check`. It is testing, not proof.

```console
$ FFI_JOBS=3 scripts/check-ffi.sh             # build, run every property
$ scripts/check-ffi.sh prop_Dot               # only these properties
```

It needs Cryptol 3.6 built with FFI support (`cryptol --version` says "FFI
enabled") on `PATH`, or named by `CRYPTOL`, with z3 on `PATH` (Cryptol's type
checker needs it), and bash 4. It sets
`CRYPTOLPATH` to the repository root and `cryptol/`, so a property module
imports `algorithms::AES::GF28` by its NSA name.

**The pieces.**

- `foundation_spark_ffi.gpr` builds the crate's sources with `-gnata`
  (assertions and ghost code enabled: the spec layer is ghost and has to
  execute) as `obj/ffi/lib/libfoundation_spark_ffi.so`, a shared,
  encapsulated (libgnat linked in), auto-initializing (no `adainit` from
  Cryptol) standalone library, linked with `--no-undefined`. Its
  `Library_Interface` lists each shim and export unit.
- `src/ffi/`: per Cryptol module, a ghost shim unit and an export unit
  (below). Each file is a `foreign-binding` entry in
  `scripts/trust-surface.txt`.
- `cryptol/<path>/<File>.cry`: a module (`SPARK::AES::GF28`) that declares
  the exports as `foreign spark_<Name>` **without a Cryptol body** and states
  the properties (`spark_xTimes b == xTimes b`). Cryptol loads a module's
  foreign implementations from `<File>.so` beside it; `check-ffi.sh` links
  the library there (gitignored).
- `cryptol/properties.txt`: module, property, function, mode, test count.
- `scripts/check-ffi.sh`: builds, links, runs each property in its own
  `cryptol -b`, writes `obj/ffi/ffi-results.txt` (format under "The board"),
  and keeps each run's script and output in `obj/ffi/run/`.

**Exporting a ghost function.** The spec layer is ghost, and Ada lets only
ghost code call it, so the shim that calls it must be ghost. But GNAT 16.1
links every ghost entity compiled with ghost code enabled under `___ghost_`
followed by its external name, and `Link_Name` does not avoid it: a ghost
`Export` with `External_Name => "spark_xTimes"` is the symbol
`___ghost_spark_xTimes` (checked with `nm`). So each module has two units:

- the **ghost shim** (`Foundation_Spark.FFI.AES_GF28`): ghost functions,
  `Convention => C`, `External_Name => "spark_<Name>"`, whose postcondition
  is the spec function, proved;
- the **export** (`Foundation_Spark.FFI.AES_GF28_Exports`): ordinary
  functions with the same `External_Name`, which is what Cryptol looks up.
  Each calls its shim through an `Import` of
  `Ghost_Link_Prefix & "spark_<Name>"` (`Foundation_Spark.FFI`), with
  `Global => null`.

This keeps the harness in Ada: no `objcopy` pass, no C, and Cryptol sees the
plain names. It depends on GNAT's prefix, which is undocumented; if a later
GNAT changes it, the `--no-undefined` link fails rather than the first call.
The alternatives were renaming the symbol with `objcopy --redefine-sym` (a
pass over gprbuild's objects, outside the GPR), a C wrapper (native source
in a crate that has none), and declaring `foreign ___ghost_spark_xTimes` in
the Cryptol (GNAT's detail in every property module).

In the proof build (`foundation_spark.gpr`) ghost code is ignored: the shims
are proved, and the static library carries the export units with their
imports unresolved. Only the FFI library links them.

**What a pass requires.** Cryptol 3.6 can report a run that never called
SPARK without failing it, so `check-ffi.sh` passes a property only when:

- `cryptol` exits 0, with no `ERROR`, counterexample or `[error]`;
- the property's module printed `Loading dynamic library <File>.so`.
  **A body-less `foreign` whose library is missing does not fail the
  load.** Seen with Cryptol 3.6.0: the module loads with
  `[warning] Could not load all foreign implementations for module
  SPARK::AES::GF28 ... Fallback cryptol implementations will be used if
  available`; each call is then an evaluation error (`No foreign
  implementation is loaded`), `:exhaust` reports `ERROR`, and `cryptol -b`
  exits 1. The body-less declaration still matters: with a body, the
  missing library would make the property compare the Cryptol with itself,
  and pass;
- no module outside `cryptol/` loaded a dynamic library. NSA's `foreign`
  declarations with Cryptol bodies (`AES::Cipher`, `AES::KeyExpansion`,
  `Keccak::StepMappings`) fall back to those bodies on Linux, because the
  repository's `.so` files are symlinks into the unbuilt `rust/*/target/`
  and dangle. That is what the properties want: SPARK against the Cryptol.
  If someone builds the Rust, the comparison would silently become SPARK
  against Rust, so `check-ffi.sh` fails instead;
- Cryptol reports `Passed N tests.` with N the planned count, and `Q.E.D.`
  for `:exhaust`.

`:set evalForeign=always` would make a missing library a load error, but it
applies to every module loaded, NSA's included, which would then require the
Rust.

**Passing bit sequences.** Cryptol's C calling convention passes `[K]` only
for a constant `K <= 64` (as `uint8_t` .. `uint64_t`), and sequences of such
words (`[n][8]` as `uint8_t *`, with each size variable passed first as
`size_t`). An arbitrary-length `[l]` is rejected ("Type unsupported for
FFI"), and so is a fixed `[100]`. So a function over `[l]` (SHA-2's `hash`,
#15) is checked through a byte-packing wrapper on the Cryptol side, for
example `foreign spark_hash : {l} (fin l) => [l /^ 8][8] -> [32][8]`, which
is the C `void spark_hash (size_t l, uint8_t *in, uint8_t *out)`. Cryptol's
other convention, `foreign abstract`, does accept `{l} (fin l) => [l]`: the
callee receives `l`, then the bits as little-endian 64-bit digits through
the `CryValExporter` callbacks of `cry_ffi.h` (a C stub summing the bits
agreed with Cryptol on `[8]`, `[16]`, `[200]` and `[1000]`). Using it from
Ada means binding those callback records, which is more trust surface than
the wrapper.

**The AES spec layer** (`SPARK/AES/{GF28,SBox,Cipher,KeyExpansion,Main}.cry`)
follows the recipe per Cryptol module: a ghost shim unit
(`FFI.AES_<Module>`), an export unit (`FFI.AES_<Module>_Exports`), both in
`Library_Interface` and both `foreign-binding` entries, and one
`properties.txt` line per property. `FFI.AES_Types` holds the C shapes they
share.

- **Blocks and words.** `Block` (`[16][8]`) and `AESWord` (`[4][8]`) are
  passed as pointers to their bytes, and a result of either type is written
  through the pointer Cryptol passes after the arguments, so each shim is a
  procedure with an `out` parameter: `foreign spark_SubBytes : Block ->
  Block` is `procedure SubBytes (Bs : Block; Output : out Block)`.
- **Key sizes.** Cryptol passes a numeric type parameter as a leading
  `size_t`, so `foreign spark_Cipher : {k} (Key k) => [Nr k + 1]Block ->
  Block -> Block` is one export, `Cipher (K, W, Input, Output)`, called as
  ``spark_Cipher`{128}``, ``{192}`` and ``{256}``. The length of
  `[Nr k + 1]Block` (and `[Nk k]AESWord`, `[k / 8][8]`) depends on `k`, so
  the parameter is typed at the largest size (`AES_Types.All_Round_Keys`,
  15 blocks) and the shim reads only the first `Nr k + 1`
  (`Round_Keys_Of`), which is the unconstrained `Round_Keys` that the
  spec's `Is_Round_Keys (K, W)` precondition asks for. `KeyExpansion`
  writes its `[Nr k + 1]Block` result the same way, into the first
  `Nr k + 1` blocks only (`in out`, and its proved postcondition says the
  rest is untouched). The shims' `Pre => Is_Key_Size (K)` is checked at run
  time in the `-gnata` library, and Cryptol checks `Key k` at the call.
- **Bit sequences.** `Main.cry`'s `Encrypt` and `Decrypt` take `[k]` and
  `[128]`, which the C convention cannot pass. The Cryptol side packs them
  with the Cryptol's own `split` and `join`:
  ``join (spark_Encrypt`{k} (split key) (split in))``, with
  `foreign spark_Encrypt : {k} (Key k) => [k / 8][8] -> [16][8] -> [16][8]`.
  The shim joins the bytes into the spec's ghost bit sequences (`Join_Key`,
  and the spec's `Join_Block`) and splits the result (`Split_Block`), so the
  check covers those conversions with the spec function.
- **Known answers.** `Tests.cry`'s vectors go through the SPARK functions.
  `prop_CipherExample` and `prop_AES<n>Example` restate the vectors (copied
  from `Tests.cry`) over the `spark_` functions. `prop_Example<n>KeyExpansion`
  checks that the SPARK `KeyExpansion` equals the Cryptol one on `Tests.cry`'s
  key and conjoins `Tests.cry`'s own `Example<n>KeyExpansion`, so the long
  expected schedules are not copied. Each is a closed `Bit`, run with
  `:exhaust` (1 test).
- **The executable AES** (`AES.Impl`, #11) is not ghost: its exports
  (`FFI.AES_Impl`: `spark_Expand_Key`, `spark_Encrypt_Block`,
  `spark_Decrypt_Block`, `spark_Decrypt_Block_Prime`) call `Expand_Key`
  and the block ciphers directly, with no ghost shim, in the C shapes of
  `AES_Types`, and `foundation_spark_ffi.gpr` builds them without
  `-gnata`, as for SHA-256 below. `KeyExpansion.cry` and `Cipher.cry`
  declare them and check them against `KeyExpansion` and `Cipher`,
  `InvCipher` and `InvCipher'` at k = 128, 192 and 256; `Main.cry` composes
  `Expand_Key` with `Encrypt_Block` or `Decrypt_Block` as `Main.cry`'s
  `AES` composes `KeyExpansion` with `Cipher` (`implEncrypt`,
  `implDecrypt`) and checks that against `AES`{k}.Encrypt` and `Decrypt`.
  The known answers go through them too: FIPS-197 Appendix A
  (`prop_Expand_Key_FIPS`), Appendix B (`prop_Block_CipherExample`),
  `Tests.cry`'s `AES<n>Example` (`prop_Impl_AESExamples`), and Appendix C.1
  to C.3 (`prop_Impl_FIPS197_C`, and `prop_FIPS197_C` through the spec),
  which `Tests.cry` does not have: copied from the standard, and checked
  against `Main.cry`'s `AES` in the same property.
- **Targeted, not volume.** Executed, the ghost `KeyExpansion` is
  exponential in its `W` recursion: a ghost `KeyExpansion`, `Encrypt` or
  `Decrypt` property took 96–109 s per 1,000 tests at k = 128 in CI on
  `1a2e0af` (28–54 s at k = 192 and 256), and the 27 such properties
  1,095 s of the FFI job's 27 minutes. So the
  random samples (1,000 per property, per key size) are drawn on the
  executables, which are proved equal to the spec (`Expand_Key =
  KeyExpansion`, `Encrypt_Block = Cipher`, `Decrypt_Block = InvCipher`,
  `Decrypt_Block_Prime = InvCipher'`), and so check the spec's faithfulness
  through the proofs. The ghost spec's whole-cipher, `KeyExpansion` and
  `Encrypt`/`Decrypt` properties run 5 tests each, at each key size, which
  runs each export path, and the known answers above go through the spec
  too. The byte-level properties (`•`, `xTimes`, `SBox`, `InvSBox`,
  `Rcon` exhaustively, the round transformations at 10,000) are unchanged.
  A long run at large N is deferred: N is per property in
  `properties.txt`.

**SHA-256** (`SPARK/SHA2/{Functions,Preprocessing,SHA256}.cry`) follows the
same recipe: ghost shim and export units `FFI.SHA2_<Module>` and
`FFI.SHA2_<Module>_Exports`, with the C shapes in `FFI.SHA2_Types`.

- **Messages of any length.** A message is `[l]`, which the C convention
  cannot pass, and its length is a type. The foreign functions take bytes,
  with the length first: ``foreign spark_hash : {l} (fin l, 64 >= width l)
  => [l /^ 8][8] -> [32][8]`` is `void spark_hash (size_t l, uint8_t *m,
  uint8_t *out)`. The property passes `split (M # zero)`, the message padded
  to whole bytes with zero bits, and the shim takes the first `l` bits back
  (`SHA2_Types.Join_Bits`), so the bit-level spec is checked at bit lengths
  that are not whole bytes too. The byte-level functions take `[n][8]` and
  are compared with `SHA256::hash (join M)`. A buffer whose length depends
  on the type is typed at a fixed maximum (`Byte_Buffer`, 2^24 bytes;
  `Block_Buffer`; `Cut_Buffer`, 64 cut points) and only the caller's prefix
  is read or written.
- **Pass the length explicitly.** `[l /^ 8][8]` does not determine `l`:
  ``spark_hash (split M)`` on a 24-bit `M` type-checks with `l = 17`, and
  hashes the first 17 bits. Every call names `l` (``spark_hash`{l}``).
- **Targeted, not volume.** A length is a type, so a property names the
  lengths it covers. They are the padding boundaries, 0, 1, 55, 56, 63,
  64, 65, 119, 120, 127 and 128 bytes (55 bytes is the longest message
  whose padding fits one block, 119 two), bit lengths around them that are
  not whole bytes, the FIPS 180-4 examples, and a fixed list of longer
  lengths drawn at random once. `:check` draws the contents. The executable
  functions, which are proved equal to the spec (`Compress = Step`, and
  `Hash` and `Hash_Chunked = Hash_Bytes`, and so `= SHA256.Hash` on the
  bits by `Lemma_Hash_Bytes`), carry the samples of about 100. The ghost
  spec functions are checked directly at a handful of tests, so that their
  own export path runs too, and through the proofs at the rest. A long run
  at large N is deferred; N is per property in `properties.txt`, so raising
  it is a one-field change. (`parse` is checked at every N = 0 .. 8 blocks
  by a recursion on the type, `parseUpTo`: ``parseUpTo`{n}`` checks `n` and
  calls ``parseUpTo`{max 1 n - 1}``. Cryptol 3.6 accepts this polymorphic
  recursion.)
- **Cost.** Measured on aarch64 with `:time`, a call of the ghost spec's
  `Hash` costs about 2 ms per block (1.8 ms for one block, 10.6 ms for
  five), far less than the call count of `W`'s four-way recursion
  suggests (why was not investigated). Cryptol's own `SHA256::hash` costs about 6 ms per block
  (30 ms for five), so the reference side, not the spec, sets the time of
  a hash property. The executable `SHA256_Stream.Hash` takes about 20 us
  for five blocks.
- **`step` and the constants.** `algorithms::SHA2::SHA256` instantiates
  `Main` privately and exports only `hash` (and `HMAC`, `PBKDF2`). The
  module instantiates `Main` again with `SHA256.cry`'s parameters, copied,
  and compares the SPARK `step` with that. `K_256` and `H0_256` are
  constants, so their foreign functions take `()`.
- **The executable SHA-256** (`SHA256_Stream`) is not ghost: its exports
  (`FFI.SHA2_SHA256_Stream`) call `Hash` and `Hash_Chunked` (Init, Update on
  each chunk, Final) directly, with no ghost shim. A chunking is `[c][64]`,
  the ends of the chunks, which the property draws at random and makes valid
  (mod `n + 1`, then `sort`). `foundation_spark_ffi.gpr` builds these units
  without `-gnata`, as a client builds them: executed, their contracts and
  invariants would run the ghost spec in every `Update` (`Models` folds
  `Step` over the whole message so far): one test of every length 0..300
  bytes did not finish in ten minutes. No unit built with `-gnata` refers to their
  ghost entities, so the link still resolves. `check-ffi.sh` builds with
  `gprbuild -s`, so that a change of switches recompiles.
- **Known answers.** The FIPS 180-4 examples (`""`, `"abc"`, the 448- and
  896-bit messages) go through each SPARK function, against the published
  digests, and through `SHA256::hash`.

**HMAC-SHA-256** (`SPARK/HMAC/SHA256.cry`) checks the spec's
`HMAC.SHA256.HMAC` (at lambda = 256) and `HMAC_init` through the ghost shim
and export units `FFI.HMAC_SHA256` and `_Exports`, and the executable
`HMAC.SHA256_Impl` (`HMAC_SHA256`, `Init_Key`, and `Init`/`Update`*/`Final`
on a random chunking) through `FFI.HMAC_SHA256_Impl`, which, like
`FFI.SHA2_SHA256_Stream`, has no ghost shim and is built without `-gnata`.
All are compared with `algorithms::SHA2::SHA256::HMAC`, that is
`packaging/Hash.cry`'s `HMAC` at `SHA256.cry`'s parameters.

- **`HMAC_init` is private** in `algorithms/HMAC/Main.cry`, so no module can
  call it. The module restates it (`hmacInit`), copied from `Main.cry` at
  B = 64, L = 32 and `Hk = SHA256::hash`, and compares the SPARK
  `HMAC_init` and `Init_Key` with that copy. Every `HMAC` property also runs
  them against NSA's own `HMAC_init`, inside `SHA256::HMAC`.
- **Targeted lengths**: keys of 63, 64 and 65 bytes (`HMAC_init`'s three
  cases) under texts at SHA-256's padding boundaries; keys at the
  boundaries under a 20-byte text; for the spec, texts that are not whole
  bytes; a fixed list of longer keys and texts for the executable; and RFC
  4231's cases 1-7 (case 5 truncated to 128 bits), through each SPARK
  function and through `SHA256::HMAC` itself. The repository's own HMAC
  tests exercise only SHA-3, so that is the first check of `SHA256::HMAC`
  against RFC 4231.

**CI** runs `check-ffi.sh` in its own job (`FFI (Cryptol, linux x86_64)`,
`.github/workflows/spark-ci.yml`) on `ubuntu-24.04`, x86_64: Cryptol has no
arm64 Linux release. It installs the `cryptol-3.6.0-ubuntu-24.04-X64-with-solvers`
release, checked against its sha256 (the release without solvers does not
start: Cryptol's type checker needs z3), and the same Alire toolchain.

## Coverage

`scripts/check-coverage.sh` (#49) measures how much of the executable code
the FFI properties run: GNATcoverage's statement, decision and MC/DC
obligations (`--level=stmt+mcdc`) of the units in `coverage/units.txt` (the
executables `AES.Impl`, `AES.Impl.Main`, `SHA2.SHA256_Stream`,
`HMAC.SHA256_Impl`, `SHA2.Functions`, and the non-ghost FFI export units),
under every property of `cryptol/properties.txt`. The ghost spec is out of
scope: it is not code that ships.

```console
$ FFI_JOBS=3 scripts/check-coverage.sh          # every property
$ GNATCOV=/path/to/gnatcov scripts/check-coverage.sh prop_Impl_Dot
```

It needs gnatcov `GNATCOV_VERSION` (`scripts/toolchain-pins.env`; the
Alire crate, `alr -n install gnatcov=26.2.1`, has aarch64 and x86_64 Linux
builds) and what `check-ffi.sh` needs. It

1. installs gnatcov's runtime in `obj/cov/rts` (`gnatcov setup`, once per
   version);
2. instruments and builds the coverage build of the FFI library:
   `foundation_spark_ffi.gpr` with `FOUNDATION_SPARK_FFI_BUILD=coverage`,
   which has its own object and library directories (`obj/cov/`) and one more
   unit, `coverage/foundation_spark_coverage`. gnatprove never reads this
   project, and the FFI check's build is untouched;
3. runs `check-ffi.sh` against that library (`FFI_LIB`, `FFI_OUT`), which
   judges every property as usual;
4. consolidates the traces into `obj/cov/report/`: `summary.txt` (the
   per-unit table and every violation with its explanation), `report.txt`
   (gnatcov's report), `xcov/` (annotated sources) and `xml/`.

**Dumping a trace from Cryptol's process.** gnatcov's `atexit` and
`main-end` triggers are inserted into Ada mains, and Cryptol, which loads the
library by `foreign`, has none. So the instrumentation uses
`--dump-trigger=manual`: `Foundation_Spark_Coverage.Dump` holds
`pragma Annotate (Xcov, Dump_Buffers)`, which gnatcov replaces with the dump,
and the unit's elaboration registers `Dump` with the C library's `atexit`.
The library elaborates itself when Cryptol loads it, so every `cryptol -b`
(one per property) writes its own trace into `obj/cov/traces/` when it exits
(`GNATCOV_TRACE_FILE`). The script fails unless there is one trace per run.

**Explained, or closed.** Every violation must match an entry of
`coverage/explained.txt` (the file, the trimmed text of the line, the
reason), or the script fails. An entry is for code the properties cannot
reach by construction, such as an expression function called only from
contracts, which the FFI build does not execute. A gap in the targeted
tests is closed with a property instead (`prop_Impl_Dot` closed
`AES.Impl.Dot`, which the ciphers never call).

**CI** runs it in `.github/workflows/spark-coverage.yml`, its own workflow,
so it never lengthens the FFI gate: on `ubuntu-24.04` (x86_64), on a PR or a
push to `main` that touches the sources, the properties or the coverage
tooling, and by hand (`workflow_dispatch`). The report is the artifact
`spark-coverage`, and the table goes in the job summary.

## Gates

CI (`.github/workflows/spark-ci.yml`) runs three gates, in this order, and
the FFI job after the docs gate ("The FFI harness"). Each
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

## Cryptol

The FFI checks (`spark/cryptol/`, M0.3 onward) need Cryptol 3.6.0 built
with FFI support (`cryptol --version` prints `FFI enabled`). SAW is
installed only on the x86_64 instance, by its bootstrap ("Bootstrapping
the x86_64 instance").

### `CRYPTOLPATH`

The NSA modules are named from the repository root
(`algorithms::AES::Main`, `shared::...`), so `CRYPTOLPATH` must hold the
repository root. `spark/cryptol` will be added to it when M0.3 lands.

```console
$ export CRYPTOLPATH=/path/to/Foundation
$ cryptol -b script.icry
```

### aarch64 Linux (the `foundation` container)

Cryptol 3.6.0 ships no aarch64 Linux binary. The release has macOS
ARM64/x86_64 and x86_64 Linux/Windows builds only. No packaged route was
credible:
* Ubuntu 24.04's `cryptol` package is 3.0.0.
* The Docker Hub `galoisinc/cryptol` images are amd64 only, and the
  container has no docker, podman or nix.

So it was built from the `3.6.0` tag, with GHC 9.8.4 and cabal 3.14.1.0
(the versions upstream's CI uses for its release builds), against the
release's own freeze file `cabal.GHC-9.8.4.config`. That file sets
`cryptol +ffi` and `libffi +ghc-bundled-libffi`. Nothing needed sudo.

The container has no system C toolchain (no `/usr/bin/gcc`, `cc`, `ld` or
`ar`), so GHC and cabal used the gcc 16.1.0 and binutils from Alire's
`gnat_native` toolchain. It also has no `-dev` packages, so the headers,
the link-time `.so` symlinks and `pkgconf` came from Ubuntu's `.deb`s,
unpacked without installing them. The resulting `cryptol` links only
against system libraries (`libm`, `libtinfo`, `libz`, `libgmp`, `libc`).

```console
# Headers and pkgconf from Ubuntu debs, unpacked into ~/.local/sysroot.
$ mkdir -p ~/build/apt/state/lists/partial ~/build/apt/cache/archives/partial ~/build/debs
$ apt-get -o Dir::State=$HOME/build/apt/state -o Dir::Cache=$HOME/build/apt/cache \
    -o Debug::NoLocking=1 -o APT::Sandbox::User=$(whoami) update
$ cd ~/build/debs
$ apt-get -o Dir::State=$HOME/build/apt/state -o Dir::Cache=$HOME/build/apt/cache \
    download libffi-dev libgmp-dev zlib1g-dev libncurses-dev \
    pkgconf pkgconf-bin libpkgconf3 z3 libz3-4
$ for d in ~/build/debs/*.deb; do dpkg-deb -x $d ~/.local/sysroot; done
# Then: point each dangling lib*.so symlink in
# ~/.local/sysroot/usr/lib/aarch64-linux-gnu at the runtime library in
# /usr/lib/aarch64-linux-gnu, and rewrite the prefix/libdir/includedir
# of the .pc files there to ~/.local/sysroot. ~/.local/bin/pkg-config
# and ~/.local/bin/z3 are two-line wrappers that set LD_LIBRARY_PATH (and,
# for pkg-config, PKG_CONFIG_LIBDIR) to the sysroot before exec'ing it.

# GHC 9.8.4 and cabal 3.14.1.0 through ghcup, in ~/.ghcup.
$ mkdir -p ~/.ghcup/bin
$ curl -sSfL -o ~/.ghcup/bin/ghcup https://downloads.haskell.org/~ghcup/aarch64-linux-ghcup
$ chmod +x ~/.ghcup/bin/ghcup
$ S=$HOME/.local/sysroot
$ export PATH=$HOME/.ghcup/bin:$HOME/.local/bin:$HOME/.local/share/alire/toolchains/gnat_native_16.1.0_8e297497/bin:$PATH
$ export LIBRARY_PATH=$S/usr/lib/aarch64-linux-gnu
$ export C_INCLUDE_PATH=$S/usr/include/aarch64-linux-gnu:$S/usr/include
$ CC=gcc ghcup install ghc 9.8.4 --set
$ ghcup install cabal 3.14.1.0 --set

# Cryptol 3.6.0, installed as ~/.local/bin/cryptol.
$ git clone --depth 1 --branch 3.6.0 --recurse-submodules --shallow-submodules \
    https://github.com/GaloisInc/cryptol.git ~/build/cryptol-3.6.0
$ cd ~/build/cryptol-3.6.0
$ cp cabal.GHC-9.8.4.config cabal.project.freeze
$ cabal update
$ cabal build -j4 exe:cryptol
$ install -m755 "$(cabal list-bin exe:cryptol)" ~/.local/bin/cryptol
```

The first `cabal build` stopped after compiling the `cryptol` library.
cabal's `act-as-setup configure` for the `cryptol-repl-internal`
sublibrary never reaped a `pkgconf` child that had already exited, and
hung there. Killing it and rerunning the same command finished the build
in 15 s from the store. Before the hang, the build had run for about 11
minutes at `-j4`, on a container shared with two other jobs.

```console
$ cryptol --version
Cryptol 3.6.0
Git commit 61dd17b0c45ddf8c5c1e952afd5e789c4dc4ec4b
    branch HEAD
FFI enabled
```

An SMT solver is optional, since `:check` and `:exhaust` do not use one.
Ubuntu's z3 4.8.12 is unpacked in the sysroot behind the `~/.local/bin/z3`
wrapper.

On Linux, Cryptol looks for a module's foreign implementations in
`<Module>.so` beside the `.cry` file (`<Module>.dylib` on macOS).

### CI

CI (M0.3) uses the `cryptol-3.6.0-ubuntu-24.04-X64-with-solvers` release
tarball on an x86_64 runner: the release without solvers refuses to start
without z3. No arm64 Linux release exists.

## Bootstrapping the x86_64 instance

The x86_64 instance (E4: SAW, later GNAT-LLVM) starts bare and **dies
24 hours after it starts**. One command takes it from a bare Ubuntu 24.04
to a green `check-ffi.sh`:

```console
$ curl -fsSL https://raw.githubusercontent.com/manthonyaiello/Foundation/main/spark/scripts/bootstrap-x86_64.sh | bash
```

Then, in each new shell, `. ~/foundation-tools/env.sh` (the script also
prints the `export PATH=...` line). The rules while it lives:

- **Push after every commit.** Nothing unpushed survives the instance.
- **It dies 24 h after start**, whatever is running. Start long proofs
  early, and push their results as they land.
- gnatprove runs with `-j$(nproc)` (`PROVE_JOBS` defaults to `nproc`):
  there is no scheduler there and no other user.

`scripts/bootstrap-x86_64.sh` (M0.5, #6) is idempotent: each phase skips
what is in place, so rerun it after anything goes wrong. Its phases, each
timed at the end of the run:

| phase | what |
|---|---|
| `prereqs` | curl, git, python3, CA certificates, `libc6-dev`; missing ones are apt-installed |
| `clone` | clones the fork to `~/Foundation`, or fetches it and fast-forwards a clean checkout |
| `alire` | alr 2.1.1, `alr toolchain --select` gnat_native 16.1.0 and gprbuild 26.0.1, `alr install` gnatprove 16.1.0 and gnatdoc_bin 26.0.0 |
| `cryptol` | Cryptol 3.6.0, `ubuntu-24.04-X64-with-solvers` release |
| `saw` | SAW 1.6, `ubuntu-24.04-X64-with-solvers` release |
| `gnat-llvm` | checks the GNAT Pro LLVM install that `GNAT_LLVM_DIR` names (nothing of it is downloaded), installs `llvm-link` from LLVM's own 21.1.8 release (2 GB tarball, sha256 checked, `bin/llvm-link` alone extracted), and writes `GNAT_LLVM_DIR` and `LLVM_LINK_DIR` to `env.sh`; skipped, with a note, when `GNAT_LLVM_DIR` is unset ("SAW") |
| `build` | `alr -n build` |
| `proof` | `scripts/check-proof.sh`, slow units skipped as in CI ("Slow proofs"), under CI's allowance (`FOUNDATION_SPARK_PROOF_ALLOWANCE=ci` unless set); retried once on failure, and then reported as "ok on retry" |
| `ffi` | `scripts/check-ffi.sh` |

Every version and release sha256 comes from `scripts/toolchain-pins.env`,
which CI's `setup-alire-spark` action reads too, so the instance and CI
cannot drift apart. Tools go to `~/foundation-tools` (`FOUNDATION_TOOLS`),
Alire's state to `~/.alire` and `~/.local/share/alire` as in CI. The
header of the script lists its other variables (`FOUNDATION_REPO`,
`FOUNDATION_REF`, `FOUNDATION_SPARK_PROOF_ALLOWANCE`, ...).

**Root** is needed only by `prereqs`, and only for packages the image
lacks. As root or with passwordless sudo the script installs them;
otherwise it stops and prints the one `sudo apt-get install` line to run.
Cryptol's and SAW's shared libraries are checked with `ldd` after
unpacking, the same way.

**SAW's signature.** The release's `.sig` is signed by key
`07FC90D0C93F5F3B56354E1DCBF4BB4143DB4A3A`, which neither
keys.openpgp.org nor keyserver.ubuntu.com serves, so the pin is the
asset's sha256. Given the key (`SAW_SIGNING_KEY_FILE=key.asc`), the script
verifies the `.sig` too.

The script is tested by `.github/workflows/spark-bootstrap-x86_64.yml`
(on a PR that touches it, or dispatched): on a bare `ubuntu-24.04` runner
with no setup action, and in a plain `ubuntu:24.04` container as root,
which is what measures the packages it must install.

## Slow proofs

A unit whose proof is too slow for the default gate is **proved on demand,
not by the gate, and the gate detects when anything it depends on changes**,
so it is known when to prove it again. The first was #12's generated
`SBox_Entries` (SBox.cry's `SBoxCorrect` by case enumeration): about 26 min
cold on the campaign machine and 1 h 40 min cold in CI.

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
unit src/aes/foundation_spark-aes-spec-properties-sbox_entries.adb
  reason      ...
  commit      <the commit proved>
  date        <its date, UTC>
  level       4
  checks      <proved>/<total>
  fingerprint sha256:<over the input lines>
  input       <sha256, 16 hex> <input name>
  ...
```

**The inputs** are computed by `scripts/slow_proofs.py`, not listed by hand:

- the spec and body of every unit in the unit's closure under `src/`: the
  unit, its parents, every unit its context clauses `with` (limited and
  private ones too), their parents, and so on, through the spec and the body
  of each. A body is included because it can change what gnatprove assumes
  of its unit (generated `Global` contracts, a generic's instance), so the
  closure errs towards staleness. Units outside `src/` (the runtime,
  SPARKlib) are listed in the verbose output but not hashed. The toolchain
  versions are inputs; SPARKlib's version is pinned by `alire.toml`, which
  is not;
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

Each input is hashed (sha256, its first 16 hex digits), and the fingerprint
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

The board shows a row whose spec (or impl) entity is in a slow unit as
`slow: proved at <sha> (on demand)`, or **STALE** when the fingerprint no
longer matches, and lists the slow units' recorded checks apart from the
totals.

## SAW

E4 (#21) proves the **implementation** layer equal to NSA's Cryptol
directly, with SAW's `llvm_verify` on LLVM bitcode of the crate's own
sources, independently of the SPARK spec layer and of gnatprove. M4.1 (#22)
proved three leaves of `Foundation_Spark.AES.Impl`; M4.2 (#23) proves the
key schedule and both ciphers at each key size, against
`algorithms/AES/KeyExpansion.cry` and `Cipher.cry`, imported unmodified:

| Ada (`AES.Impl`) | Cryptol | k | overrides | tactic |
|---|---|---|---|---|
| `Expand_Key` | `KeyExpansion.cry`: ``KeyExpansion`{k}`` | 128, 192, 256 | `Nk`, `Nr`, `Sub_Byte` | z3, `SBox` uninterpreted |
| `Encrypt_Block` | `Cipher.cry`: ``Cipher`{k}`` | 128, 192, 256 | `Nr`, `Round`, `Sub_Bytes`, `Shift_Rows`, `Add_Round_Key` | z3, `Round`, `SubBytes`, `ShiftRows`, `AddRoundKey` uninterpreted |
| `Decrypt_Block` | `Cipher.cry`: ``InvCipher`{k}`` | 128, 192, 256 | `Nr`, `Inv_Round`, `Inv_Sub_Bytes`, `Inv_Shift_Rows`, `Add_Round_Key` | z3, `InvRound`, `InvSubBytes`, `InvShiftRows`, `AddRoundKey` uninterpreted |

Each of the nine takes under a second. They rest on these leaves, each
proved first and then passed as an override to its callers:

| Ada | Cryptol | overrides | tactic |
|---|---|---|---|
| `AES.Spec.Types.Nk`, `.Nr` | `Types.cry`: `Nk k = k / 32`, `Nr k = Nk k + 6`, for `k` in 128, 192, 256 | | z3 (rme does not finish on the 32-bit division) |
| `AES.Spec.Types.Split`, `.Join` | Cryptol's `split : Block -> [4]AESWord`, `join` | | rme |
| `X_Times` | `GF28.cry`: `xTimes` | | rme |
| `Sub_Byte`, `Inv_Sub_Byte` | `SBox.cry`: `\b -> SBox @ b`, `\b -> InvSBox @ b` | | rme |
| `Sub_Bytes`, `Inv_Sub_Bytes` | `Cipher.cry`: `SubBytes`, `InvSubBytes` | `Sub_Byte`, `Inv_Sub_Byte` | rme |
| `Shift_Rows`, `Inv_Shift_Rows` | `Cipher.cry`: `ShiftRows`, `InvShiftRows` | | rme |
| `Add_Round_Key` | `Cipher.cry`: `AddRoundKey` | | rme |
| `Mix_Column` | `Cipher.cry`: `MixColumnsStep` | `X_Times` | rme |
| `Inv_Mix_Byte` (body-local) | `Cipher.cry`: `\a b c d -> InvMixColumnsStep [a, b, c, d] @ 0` | `X_Times` | rme |
| `Inv_Mix_Column` | `Cipher.cry`: `InvMixColumnsStep` | `Inv_Mix_Byte` | rme |
| `Mix_Columns`, `Inv_Mix_Columns` | `Cipher.cry`: `MixColumns`, `InvMixColumns` | the column step, `Split`, `Join` | rme |
| `Round` | `Cipher.cry`: `Round` | `Sub_Bytes`, `Shift_Rows`, `Mix_Columns`, `Add_Round_Key` | rme |
| `Inv_Round` | `Cipher.cry`: `InvRound` | `Inv_Shift_Rows`, `Inv_Sub_Bytes`, `Add_Round_Key`, `Inv_Mix_Columns` | rme |

There is **no `llvm_unsafe_assume_spec`**: every override is a proof in
the same module, and `check-saw.sh` refuses to run if a script under
`saw/` contains one. Not proved by SAW: `Dot` (no cipher calls it), and
`Decrypt_Block_Prime` with `Inv_Round_Prime` (``InvCipher'``, which the
issue does not ask for). `Sub_Word`, `Rot_Word`, `Xor_Word` and `Rcon` are
expression functions that llvm-gcc inlines into `Expand_Key` even at
`-O0`, so they are proved as part of it.

```console
$ GNAT_LLVM_DIR=.../gnatpro-llvm-ada/install LLVM_LINK_DIR=.../llvm-21.1.8 scripts/check-saw.sh
$ scripts/check-saw.sh --print      # run, print the record, write nothing
```

**Local only, never CI** (Tony, 2026-10-19). The bitcode comes from
**GNAT Pro 27's LLVM back end** (`$GNAT_LLVM_DIR/bin/llvm-gcc`), which CI
does not have and nobody without GNAT Pro can install. It is used for
nothing else: the crate's toolchain, its gates and CI stay FSF GNAT 16.1.
`check-saw.sh` fails at once, saying so, when `GNAT_LLVM_DIR` is unset. On
the x86_64 instance the bootstrap's `gnat-llvm` phase checks
`GNAT_LLVM_DIR` and writes it to `env.sh` when it is set; nothing of GNAT
Pro is downloaded.

**`llvm-link`, pinned.** SAW verifies one LLVM module at a time and takes
an override only from that module, and `AES.Impl` calls `AES.Spec.Types`
(see "The bitcode ABI"). GNAT Pro ships no `llvm-link`, so `check-saw.sh`
links the two units' bitcode with **LLVM's own 21.1.8 release**, the LLVM
of GNAT Pro 27's llvm-gcc: `LLVM_LINK_VERSION`, `_TAG`, `_TARBALL` and
`_SHA256` in `scripts/toolchain-pins.env` (the sha256 is the digest
GitHub lists for `LLVM-21.1.8-Linux-X64.tar.xz`). `LLVM_LINK_DIR` must
name a directory with that `bin/llvm-link`; the script fails, saying
which, when it is unset, missing, of another version, or when GNAT-LLVM's
LLVM (`llvm-nm --version`) is not the same version. The bootstrap's
`gnat-llvm` phase installs it when `GNAT_LLVM_DIR` is set: it fetches
the 2 GB tarball, checks its sha256, extracts `bin/llvm-link` alone (it
is statically linked against LLVM) to `~/foundation-tools/llvm-21.1.8`,
and writes `LLVM_LINK_DIR` to `env.sh`.

**The record.** Since no one else can rerun it, every run that passes
writes `saw/results.txt`: the commit (the tree must be clean), the date,
the host, the versions of llvm-gcc, LLVM, llvm-link (with the tarball's
sha256), SAW, Cryptol and z3, the compiler switches, the sha256 of each
unit's bitcode and of the linked module, of every crate source the
compiler read for them (the ALIs' dependencies) and of every NSA Cryptol
file imported, each result with its tactic and SAW's time for it, each
negative control's counterexample, and the wall-clock. Commit it with the
change it checks. CI's gates do not read `saw/`: the trust and docs gates
scan `src/`, and the bitcode (`saw/obj/`) is not tracked.

**What it runs.**

1. `llvm-gcc -c -gnat2022 -gnatp -gnatVn -O0 -emit-llvm` on
   `src/aes/foundation_spark-aes-impl.adb` and
   `src/aes/foundation_spark-aes-spec-types.ads`, every directory of
   `src/` on the search path, into `saw/obj/`. No run-time or validity
   checks (gnatprove proves them absent). No `-gnata`, so contracts,
   assertions and ghost code are ignored and none reaches the bitcode.
   The units need no SPARKlib.
2. `llvm-link` of the two into `saw/obj/aes.bc`, the one module the
   scripts load. `llvm-nm` checks each unit's bitcode and the linked
   module: no symbol of a ghost unit (`AES.Spec.Cipher`, `GF28`, `SBox`,
   `KeyExpansion`, `Lemmas`, ...) is defined or referenced.
3. `saw aes_impl.saw` (from `saw/`, with `CRYPTOLPATH` the repository's
   root): every proof must pass.
4. `saw negative/*.saw`: each negative control must **fail** with a
   counterexample:
   - `X_Times` against the shift without the reduction: `b = 128`;
   - `Sub_Bytes` against `InvSubBytes`;
   - `Expand_Key` at 128 against `KeyExpansion` of the key words reversed;
   - `Encrypt_Block` at 256 against `Cipher` of the round keys reversed;
   - `Decrypt_Block` at 128 against `InvCipher` of the round keys
     reversed.

   The last three run `aes_impl.saw` first and use its overrides and
   tactics, so they show that neither the overrides nor the uninterpreted
   functions make the top-level proofs vacuous. (`Encrypt_Block` against
   ``InvCipher`{128}`` fails too, but z3 took 245 s to find the
   counterexample, with `Round` uninterpreted on one side and `InvRound`
   interpreted on the other; it is not among the controls.)

The scripts follow `algorithms/AES/rust/Cipher/theorems/saw.py`: a
contract per shape of subprogram, leaves first, each verified leaf passed
as an override to its callers, `rme` for the leaves, and z3 with the
overridden compositions uninterpreted for the ciphers (the template's
`z3(["Round", "SubBytes", "ShiftRows"])`, plus `AddRoundKey`; the
template uses ``InvCipher'`` and cvc5 for decryption, the crate's
`Decrypt_Block` is ``InvCipher`` itself and z3 proves it). They are
SAWScript,
not the Python client: SAWScript runs with the `saw` of the release
tarball alone, while the client needs `saw-remote-api` and an unpinned
`saw-client` from PyPI; the NSA's own `algorithms/*/theorems/*.saw` are
SAWScript too.

**Three constraints of SAW 1.6 on GNAT-LLVM 27 bitcode**, measured:

- **No `-g`.** SAW rejects the debug metadata (`METADATA_BLOCK` "not yet
  implemented").
- **`-O0`.** At `-O1` and above, LLVM's SROA builds GNAT's array returns
  with `insertvalue [16 x i8] poison, ...`, and crucible panics
  ("Attempting to evaluate poison value"). `X_Times` and `Sub_Byte`
  (scalars) verify at `-O2 -gnatn`; `Sub_Bytes` (an array) does not.
- **One module per proof.** An override must come from the module being
  verified (`llvm_verify` says "different LLVM module" otherwise), and the
  GNAT Pro install has no `llvm-link`: hence the pinned `llvm-link` above,
  and one linked module.
- And `llvm-gcc` refuses `-o x.bc` ("incorrect object file extension"): the
  bitcode takes the source's name.

### The bitcode ABI

What `llvm-gcc -O0` makes of `AES.Impl`, which M4.2 (#23) builds on:

- **Symbols** are GNAT's external names, unchanged: the expanded name in
  lower case, `.` as `__`: `Foundation_Spark.AES.Impl.X_Times` is
  `foundation_spark__aes__impl__x_times`. No `Export` or `Convention => C`
  is needed (or wanted: the proof is of the crate's own code). A
  subprogram local to the body (`Inv_Mix_Byte`) is `internal` but
  verifiable by the same name. Overloading would add a `__<n>` suffix;
  `AES.Impl` has none.
- **Scalars**: `Byte` is `i8`, `Natural` (the key size `K`) is `i32`.
- **Constrained arrays by value**: `AESWord` is `[4 x i8]`, `Block` is
  `[16 x i8]`, `Columns` is `[4 x [4 x i8]]`, passed and returned as LLVM
  aggregates, not pointers.
- **`in out` of a constrained array** is copy-in copy-out: `procedure
  Sub_Bytes (State : in out Block)` is
  `define [16 x i8] @..._sub_bytes([16 x i8] %state)`, the new state
  returned. `Round (State : in out Block; Key : Block)` is
  `[16 x i8] ([16 x i8] %state, [16 x i8] %key)`. A contract for such a procedure is
  a function's: `llvm_execute_func [state]; llvm_return {{ F state }}`.
- **Unconstrained arrays** (`Key_Words`, `Round_Keys`) are fat pointers,
  `{ ptr, ptr }`: the data, and a bounds record `{ i32, i32 }` (`First`,
  `Last`), named `%foundation_spark__aes__spec__types__round_keys_BOUNDS`.
  `Encrypt_Block (K, W, State)` is
  `[16 x i8] (i32 %k, { ptr, ptr } %w, [16 x i8] %state)`; its contract
  (`cipher_contract`) allocates the `Nr + 1` blocks and the bounds
  `{0, Nr}` read-only, which is `Is_Round_Keys (K, W)`, and passes
  `llvm_struct_value [data, bounds]`. `Expand_Key (K, Key, W : out
  Round_Keys)` is `void (i32 %k, { ptr, ptr } %key, { ptr, ptr } %w)`: it
  writes through `W`'s data pointer, so its contract
  (`expand_key_contract`) allocates `Key`'s `Nk` words read-only with
  bounds `{0, Nk - 1}` and `W`'s `Nr + 1` blocks writable with bounds
  `{0, Nr}` (the precondition), and states the result with
  `llvm_points_to` on `W`'s data. After `llvm-link` the two units' fat
  pointer and bounds types are merged into one (`..._key_words_FP`,
  `..._round_keys_BOUNDS`).
- **Layout against the Cryptol.** Element `i` of an Ada array is element
  `i` of the Cryptol sequence, and a `Byte` is the `[8]` whose head is its
  most significant bit, so no reordering is needed anywhere:
  `Key (I) (J)` is `key @ i @ j` of KeyExpansion's `[Nk k]AESWord`;
  `W (R) (I)` is `KeyExpansion key @ r @ i`, which is byte `i mod 4` of
  word `4 r + i / 4` of the schedule (`split (split (join (join w)))`),
  exactly how `Expand_Key` fills `W (R)` from its words; and a `Block`'s
  byte `I` is `Block`'s element `i`, column `I / 4`, row `I mod 4`, as
  `split`/`join` in `MixColumns` take it.
- **Constant tables** (`S_Box`, `Inv_S_Box`) are constant globals; at
  `-O0` the body reads a private copy (`@foundation_spark-aes-impl.for.ref`).
  SAW initializes constant globals itself: no `llvm_alloc_global` needed.
- **Calls into `AES.Spec.Types`** (`Nk`, `Nr`, `Split`, `Join`: non-ghost
  expression functions, from `Expand_Key`, `Encrypt_Block`, `Decrypt_*`,
  `Mix_Columns`, `Inv_Mix_Columns`) are external declarations in
  `AES.Impl`'s bitcode at `-O0`: that unit compiles to a module of its
  own. `-O2 -gnatn` would inline them, but `-O2` is ruled out above.
  M4.1 left the choice between linking and `llvm_unsafe_assume_spec`;
  M4.2 links (`llvm-link`, above), so `Nk`, `Nr`, `Split` and `Join` are
  proved in the linked module and are overrides like any other.
- **Expression functions of `AES.Impl` itself** (`Sub_Word`, `Rot_Word`,
  `Xor_Word`, `Rcon`) are inlined into their callers by llvm-gcc even at
  `-O0` (the inlined blocks are named `..._xor_word.exit` and so on).
  `Expand_Key` calls none of them: it calls `Sub_Byte`, `Nk` and `Nr`.
