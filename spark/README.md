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
  Cryptol directly (E4), `SHA256Main.cry` (SHA-2's `Main` at SHA-256, for
  them), and `results.txt`, their record; local only, see "SAW"

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
`algorithms/AES/KeyExpansion.cry` and `Cipher.cry`; M4.3 (#24) proves
SHA-256's compression function for all inputs, and the one-shot SHA-256
and HMAC-SHA-256 at fixed lengths, against `algorithms/SHA2/Main.cry` and
`algorithms/HMAC/Main.cry`. M4.4 (#59) proves the **spec layer** equal to
the same Cryptol, so that spec = Cryptol, which the FFI check tests, is
also a proof at these sizes (below, "The spec layer"). The NSA Cryptol is
imported unmodified.

**SAW proves each size separately; gnatprove covers every size.**
`Compress` is proved for every hash value and block, but `Hash` and
`HMAC_SHA256` take arrays, and SAW executes them at one length at a time:
each row below is one length. gnatprove (E2, E3) proves the same
subprograms for every length below 2 ** 61 bytes, against the SPARK spec
layer, which the FFI check tests against the same Cryptol.

### AES

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

Not proved by SAW: `Dot` (no cipher calls it), and `Decrypt_Block_Prime`
with `Inv_Round_Prime` (``InvCipher'``, which the issue does not ask for).
`Sub_Word`, `Rot_Word`, `Xor_Word` and `Rcon` are expression functions
that llvm-gcc inlines into `Expand_Key` even at `-O0`, so they are proved
as part of it.

### SHA-256 and HMAC-SHA-256

The Cryptol: `step` and `hash` of `algorithms/SHA2/Main.cry` at SHA-256's
parameters, and `HMAC` of `algorithms/HMAC/Main.cry`. Two things stand
between the scripts and `SHA256.cry` itself, so `saw/SHA256Main.cry`
instantiates `Main` with **SHA256.cry's own parameters, copied** (as
`cryptol/SPARK/SHA2/SHA256.cry`'s `Main256` does for the FFI check):

- `SHA256.cry` instantiates `Main` privately (`import algorithms::SHA2::Main
  as SHA256 where ...`), so its `step` cannot be named from outside;
- **SAW 1.6 cannot load `SHA256.cry`** at all, by `import` or by
  `cryptol_load`: it is `packaging::Hash` instantiated, `Hash.cry` imports
  `algorithms/PBKDF/Main.cry`, and SAW's translation of that module to
  SAWCore fails ("Argument type not subtype of expected type", at a
  `parmap` over `kLen /^ hLen` blocks).

For the same reason `Hash.cry`'s `HMAC` (Hash.cry:71) is stated as
`Hash.cry` states it: ``HMAC`{λ = 256, B = 64, k, n, L = 32} hash hash
hash`` of `HMAC/Main.cry`, with `SHA256Main`'s `hash` as `Hk`, `Hn` and
`HL`.

| Ada | Cryptol | sizes (bytes) | overrides | tactic |
|---|---|---|---|---|
| `SHA2.SHA256_Stream.Compress` | `Main.cry`: `step` | all `H`, `M` | `SIGMA_256_0/1`, `Small_Sigma_256_0/1`, `Ch`, `Maj`, `"+"` | z3, `SIGMA_256_0/1`, `sigma_256_0/1` uninterpreted |
| `SHA2.SHA256_Stream.Hash` | `\msg -> split (hash (join msg))` | 0, 1, 55, 56, 63, 64, 65, 100, 119, 120, 128, 200 | `Compress` | z3, `step` and the four sigmas uninterpreted (at 0: none, below) |
| `HMAC.SHA256_Impl.HMAC_SHA256` | `\key text -> split (HMAC`{256, 64, k, 8 * n, 32} hash hash hash key (join text))` | (key, text): (0, 0), (32, 3), (32, 32), (64, 3), (64, 32), (65, 3), (100, 32) | `Compress`; at keys 65 and 100, `Hash` at that length | z3, `step` and the four sigmas uninterpreted (at (0, 0): none) |

The lengths reach each case of the padding (55, the longest message whose
padding fits one block; 56, the shortest that needs two; 64 and 128, whole
blocks; 119 and 120, the boundary in the second block; 200, four blocks)
and each case of `HMAC_init` (a key shorter than the block, the block, and
longer: hashed first). `Compress` takes about 3 s; `Hash` 0.2 to
1.2 s, and `HMAC_SHA256` 0.6 to 1.6 s, except at 0 bytes (2.6 s) and at
(0, 0) (10 s), where the whole digest is evaluated on constants;
`results.txt` has each one's time. Their
leaves:

| Ada | Cryptol | overrides | tactic |
|---|---|---|---|
| `SHA2.Functions.By_<n>.ROTR`, `.SHR` (12 instances of `Notation`) | `Notation.cry`: ``ROTR`{n, 32}``, ``SHR`{n, 32}`` | | rme |
| `SHA2.Functions.SIGMA_256_0/1`, `Small_Sigma_256_0/1` | `Functions.cry`: `SIGMA_256_0/1`, `sigma_256_0/1` | their three `ROTR`/`SHR` | rme |
| `SHA2.SHA256.Ch`, `.Maj` (the instance's `Logical`) | `Functions.cry`: `Ch`, `Maj` at `[32]` | | rme |
| `SHA2.SHA256."+"` | `+` on `[8][32]` | | z3 |

- **`Compress` is one function at `-O0`.** Its message-schedule loop and
  its 64-round loop are inline; there is no round or schedule subprogram
  in the bitcode (the spec layer's `W`, `T1`, `T2` and `Step3`, which
  would be, are ghost). So the 64 rounds are executed symbolically in one
  proof, with every call they make overridden and the sigmas
  uninterpreted: about 3 s and 0.2 GB of memory.
- **`"+"` by z3, not rme**: rme's normal form of eight 32-bit additions
  reached a 4 GB cap in under 7 s; uncapped, it took the IOD's 15.7 GB
  and was killed by the kernel (#24). Hence the memory cap below.
- **`Ch` and `Maj` stay interpreted** at the top: `Functions.cry`'s take a
  tuple, and SAW 1.6's what4 back end cannot make an uninterpreted
  function of one ("Cannot create uninterpreted higher-order function").
  They are three bitwise operations.
- **With no symbolic input** (`Hash` at 0 bytes, `HMAC_SHA256` at (0, 0))
  SAW evaluates the overrides' `step` on constants, so the
  implementation's side is the digest itself; the Cryptol side must then
  be evaluated too, so nothing is uninterpreted there. (With `step`
  uninterpreted the goal is "uninterpreted term = constant", not valid; z3
  ran 10 minutes on it before it was stopped.)
- **Lax arithmetic for null slices.** The proofs where the code makes a
  null range (an empty `Data` or `Key`, and `Final`'s copy of 0 buffered
  bytes when the length is a multiple of 64: `Hash` at 0, 64 and 128,
  `HMAC_SHA256` at (0, 0)) are of a second load of the module with SAW's
  lax arithmetic; see "The bitcode ABI". Their overrides (the leaves and
  `Compress`) are re-proved in that module, and their results are marked
  "lax arithmetic module" in `results.txt`.

Not proved by SAW: `Load_Block` and `To_Digest` on their own (they are
executed within `Hash`'s proofs: they take arrays and offsets that differ
from call to call, so one contract would not serve as their override), `Init`, `Update` and `Final` on their own (likewise, through
`Hash`), `Hash_Chunked`, and the incremental HMAC interface.

### The spec layer

M4.4 (#59) proves the ghost spec layer equal to the NSA Cryptol, with
`llvm_verify` as above, on bitcode built apart from the implementation's:

- **The build** (`saw/obj/spec/`, one module per algorithm,
  `aes_spec.bc` and `sha256_spec.bc`): the implementation's switches, plus
  `-gnatec=saw/spec.adc`, whose `pragma Assertion_Policy (Ignore)` then
  `pragma Assertion_Policy (Ghost => Check)` compile the ghost code and no
  contract or assertion (GNAT rejects the one-pragma form `(Ghost =>
  Check, others => Ignore)`: `others` is not an assertion kind), and
  **`-fno-inline`**: GNAT-LLVM marks every expression function
  `alwaysinline`, and the spec layer is expression functions, so without
  it a fold's call to its round function, or `W`'s to `SubWord`, is
  inlined and no lemma can be its override. `-fno-inline` makes each a
  call (`noinline`) and changes nothing else. The implementation's builds
  keep the check that no ghost symbol appears; the spec modules must
  define them instead.
- **Recursions are never unfolded.** A recursive ghost function whose
  variant is a size is proved one index at a time, each lemma with the
  lemmas at the smaller indices it calls as overrides: the GF(2^8) and
  GF(2) folds per bit count, the cipher folds per number of round keys,
  `KeyExpansion`'s `W` per index (44, 52 and 60 lemmas at k = 128, 192,
  256), SHA-2's `W` per index (64) and `Foldl_Step3` per round count (65),
  `To_Bits` per width, `Word_Of` per bit count, `Foldl_Step` per block
  count. GF2's `Inner` (pgcd's `inner`) recurses on a value, the degree of
  `r'`, not on a size, and with a symbolic byte SAW's evaluation of the
  Cryptol's `inner` does not terminate: `Pgcd`, `Inverse` and `Affine` are
  proved on each of the 256 bytes, one `llvm_verify` per byte, which
  together are the proof for every byte.
- **SHA-2's `step` locals.** Main.cry's `W`, `step3`, `T1` and `T2` are
  local to `step` and cannot be named. `saw/SHA256Step.cry` (ours) copies
  them, at SHA-256, out of `step`, text for text with the block as an
  explicit argument; the spec's `W`, `T1`, `T2`, `Step3` and `Foldl_Step3`
  are proved against the copy, and the spec's `Step` against NSA's `step`
  itself (through `saw/SHA256Main.cry`), with `Foldl_Step3`'s lemma as the
  override: that proof ties the copy to Main.cry.

AES (`aes_spec.saw`, with `aes_spec_gf.saw`, `aes_spec_cipher.saw`,
`aes_spec_keyexpansion.saw`, `aes_spec_main.saw`; contracts in
`aes_spec_common.saw`):

| Ada (`AES.Spec.`) | Cryptol | sizes, lemmas | overrides | tactic |
|---|---|---|---|---|
| `GF28.xTimes`, `.Head`, `.Bit`, `.Product_Bit` | `GF28.cry`: `xTimes`; `head`, `@` | | | rme, z3 |
| `GF28.Pmult_Fold` | `zext (pmult b (take`{N} c))` | N = 0 .. 8 | N - 1 | rme |
| `GF28.Pmult`, `.Reduce`, `.Pmod` | `pmult`, `pmod` at GF28.cry's types | | the folds at 8, 15 | rme |
| `GF28.Pmod_Fold` | `pmod (take`{N} x) y` | N = 0 .. 15 | N - 1, `Reduce`, `Product_Bit` | rme |
| `GF28.Dot` | `GF28.cry`: `(•)` | | `Pmult`, `Pmod` | rme |
| `GF2.Pmult`, `.Pdeg`, `.Pdiv` | `GF2.cry`: `(^*)`, `pdeg`, `(^/)` at `[9]` | | `Pdiv_Fold` at 9 | rme, z3 |
| `GF2.Pmod_Fold`, `.Pdiv_Fold` | `pmod`, `pdiv` of `take`{N} x` | N = 0 .. 9 | N - 1 | rme |
| `GF2.Pgcd`, `.Inverse` | `GF2.cry`: `pgcd`{7, 8} a SBoxPolynomial`, `inverse a SBoxPolynomial` | each of the 256 bytes | `Pdiv`; `Pgcd` at that byte | rme |
| `SBox.Affine` | `SBox.cry`: `affine` | each of the 256 bytes | `Inverse` at that byte | rme |
| `Types.Nk`, `.Nr`, `.Split`, `.Join` | as for the implementation | | | z3, rme |
| `Cipher.SubBytes` to `.InvMixColumns`, `.AddRoundKey` | `Cipher.cry`, each | | `Dot`; the column step, `Split`, `Join` | rme |
| `Cipher.Round`, `.InvRound`, `.InvRound_Prime` | `Round`, `InvRound`, `InvRound'` | | their four steps | rme; z3 for `InvRound'` |
| `Cipher.Foldl_Round`, `.Foldl_InvRound`, `.Foldl_InvRound_Prime` | `foldl Round z xs` and the others | M = 0 .. 13 round keys | M - 1, the round | z3, the round uninterpreted |
| `Cipher.Cipher` | ``Cipher`{k}`` | 128, 192, 256 | `Nr`, the fold, `SubBytes`, `ShiftRows`, `AddRoundKey` | z3, the four uninterpreted |
| `Cipher.Reverse_Keys` | `reverse` | 9, 11, 13 round keys | | z3 |
| `Cipher.InvCipher`, `.InvCipher_Prime` | ``InvCipher`{k}``, ``InvCipher'`{k}`` | 128, 192, 256 | `Nr`, the fold, the steps (`Reverse_Keys` executed) | z3, the round and steps uninterpreted |
| `KeyExpansion.RotWord`, `.SubWord`, `"xor"` | `RotWord`, `SubWord`, `^` | | | rme |
| `KeyExpansion.W` | `w @ i` = `(groupBy`{4} (join (KeyExpansion`{k} key))) @ i` | each I at each k: 44, 52, 60 | the lemmas below I (SAW applies those at I - 1 and I - Nk), the leaves | z3, `SubWord` uninterpreted |
| `KeyExpansion.KeyExpansion` | ``KeyExpansion`{k}`` | 128, 192, 256 | the W lemmas, `Nr`, `Join` | z3, `SubWord` uninterpreted |
| `Main.Bit_Of`, `.Byte_At`, `.Split_Block`, `.Split_Key` | `Main.cry`'s `split`s: `b @ j`, ``take`{8} (bs << from)``, `split in`, `split (split key)` | `Byte_At` at 128, 192, 256 bits; `Split_Key` at each k | `Byte_At` | z3 |
| `Main.Join_Block` | `Main.cry`'s `join : Block -> [128]` | | `Bit_Of` | z3 (no GEP rewrite since #68; unverified until the next SAW run) |
| `KeyExpansion.KeyExpansion`, `Cipher.InvCipher` (as `Main` calls them) | as above | 128, 192, 256, their argument on the secondary stack (Split_Key's key words; KeyExpansion's round keys) | as above | as above |
| **`Main.Encrypt`, `.Decrypt`** | **`Main.cry`: ``AES`{k}.Encrypt``, ``.Decrypt``** | 128, 192, 256 | `Split_Key`, `KeyExpansion`, `Split_Block`, `Cipher` or `InvCipher`, `Join_Block` | z3, `Cipher`, `InvCipher`, `KeyExpansion` uninterpreted |
| `Main.AES128.Encrypt`, `.Decrypt`, and `AES192`'s, `AES256`'s | `Main.cry`: `AES128.Encrypt` and the others | | `Encrypt` or `Decrypt` at k | as above |

`Rcon` is read by the W lemmas, and the `SBox` and `InvSBox` tables by
`SubBytes` and `InvSubBytes` (every entry, for a symbolic block).

SHA-256 and HMAC-SHA-256 (`sha256_spec.saw`, with `sha256_spec_step.saw`,
`sha256_spec_pad.saw`, `sha256_spec_hash.saw`, `sha256_spec_hmac.saw`;
shared parts in `sha256_spec_common.saw`; the HMAC units are linked into
`sha256_spec.bc`). Message lengths are M4.3's: 0, 1, 55, 56, 63, 64, 65,
100, 119, 120, 128 and 200 bytes; HMAC's (key, text) lengths M4.3's too.

| Ada (`SHA2.SHA256.` unless named) | Cryptol | sizes, lemmas | overrides | tactic |
|---|---|---|---|---|
| `SHA2.Functions.SIGMA_256_0/1`, `Small_Sigma_256_0/1`; `Logical.Ch`, `.Maj` | `Functions.cry` | | | rme |
| `W` | `Ws m @ t` (`SHA256Step.cry`: `step`'s `W@t`) | T = 0 .. 63 | the lemmas below T (SAW applies those at T - 2, T - 7, T - 15, T - 16), the sigmas | z3, the four sigmas uninterpreted |
| `T1`, `T2`, `Step3` | `SHA256Step.cry`: `step3`'s `T1`, `T2`, and `step3` | each T: 64, 1, 64 | `W` at T, the sigmas, `Ch`, `Maj`; `T1` at T, `T2` | z3, sigmas uninterpreted |
| `Foldl_Step3` | `foldl (step3 m) h [0 ..< N]` | N = 0 .. 64 | N - 1, `Step3` at N - 1 | z3, sigmas uninterpreted |
| `"+"`, `Step` | `+` on `[8][32]`; **`Main.cry`: `step`** | | `Foldl_Step3` at 64, `"+"` | z3, sigmas uninterpreted |
| `Small_K` | `hash`'s `type k = (l + 1 + 2 * w) %^ m` | each length | | z3 |
| `Zero` | `zero : [k]` | each k (7 values) | | z3 |
| `SHA2.To_Bits` | ``drop`{128 - W} v``, `pad`'s ``(`l : [64])`` | W = 0 .. 64, for each k | W - 1 | z3 |
| **`Pad`** | `Preprocessing.cry`: ``pad`{512, 32, l, k}`` | all twelve lengths | `Small_K`, `Zero`, `To_Bits` at 64 | z3 |
| `Word_Of` | ``zext (take`{Count} (p << first))`` (a word of `parse`) | Count = 0 .. 32, P of 512 and 1024 bits | Count - 1 | yices |
| `Foldl_Step` | ``foldl step h (take`{N} ms)`` | N = 0 .. 1 of 1 block, 0 .. 2 of 2 | N - 1, `Step` | z3, `step` uninterpreted |
| **`Hash`** | `Main.cry`: ``hash`{l}`` | 0, 1, 55, 56, 63, 64, 65, 100, 119 bytes; with `SAW_LONG=1` also 120, 128, 200 | `Pad`, `Word_Of` at 32, `Foldl_Step` (`Parse`, `Parse_Block`, `Join`, `Bit` executed) | z3, `step` uninterpreted |
| `Hash` (for HMAC), with its `Pad`, `Zero`, `To_Bits` chain | as above | at each base of the secondary stack where HMAC calls it (below) | as above | as above |
| `HMAC.SHA256.HMAC_init` | `saw/HMACInit.cry` (ours: a copy of `HMAC/Main.cry`'s private `HMAC_init`): ``HMAC_init`{64, k, 32} hash`` | each key length HMAC is proved at, at the two stack bases HMAC calls it at | for k > 64, `Hash` at 8k bits, its message on the secondary stack | z3 (k > 64: `step` uninterpreted) |
| **`HMAC.SHA256.HMAC`** | **`HMAC/Main.cry`: ``HMAC`{256, 64, k, n, 32} hash hash hash``** (Hash.cry's `HMAC` at SHA-256) | (key, text) = (32, 3), (64, 32), (65, 3) bytes (one per case of `HMAC_init`); with `SAW_LONG=1` also (0, 0), (32, 32), (64, 3), (100, 32); λ = 256 | `HMAC_init` twice, `Hash` (Hn at 512 + n bits, HL at 768) | z3, `step` uninterpreted (at (0, 0): none; with `step` uninterpreted z3 reports a spurious counterexample there, as for `Hash` at 0) |

`Pad` (`pad` has no executable counterpart: `Final` writes only the last
blocks) and `Hash` are proved in a load of the module with lax arithmetic
(see "The bitcode ABI": `To_Bits (V, 1)` concatenates the null range
`To_Bits (V / 2, 0)`, and `Pad` on an empty message makes one), with
`Small_K`, `Zero`, `To_Bits`, `Word_Of`, `Foldl_Step` and the compression
function's lemmas proved again in that load; `results.txt` marks each of
those results "lax arithmetic module". HMAC is proved in the same load
(its hashes' lemmas are there, and `Join` of an empty key computes a
null range's length).

**HMAC and the secondary stack.** `HMAC (K, Text, Lambda)` calls, in
order, `HMAC_init`, `Opad` (`Repeat`, `Join`), `HMAC_init`, `Ipad`, `Hn`
and `HL`, each leaving its result on the secondary stack (the `xor`s and
`&`s are on the primary stack), and allocates its result last; a long key's
`HMAC_init` calls `Join (K)`, `Hk` on that result, and `Zero`. An override
applies only where the stack's `Top` is the one its contract states, so
each hash's lemma, with `Pad`, `Zero` and the `To_Bits` chain under it
(`Word_Of` and `Foldl_Step` take no stack), is proved at the base where
that call happens (`results.txt`: "the secondary stack at N bytes"), and
`HMAC_init`'s at its two. A lemma's message is in one of three places
(`msg_frame` in `sha256_spec_pad.saw`): a read-only argument (the `Hash`
proofs above), a writable temporary (`Hn`'s and `HL`'s concatenations), or
on the secondary stack below the base (`Hk`'s, `Join (K)`'s result),
stated unchanged. A lemma keeps (states unchanged) what its caller reads
after the call: `Zero`'s result across `To_Bits`, the message on the stack
across both, and the first `HMAC_init`'s result and `Opad`'s across the
second `HMAC_init`. Nothing else below a hash's base is read after it
returns. `HMAC_init` is private in `Main.cry`; `saw/HMACInit.cry` copies
it text for text, the spec's `HMAC_init` is proved against the copy, and
`HMAC` against `Main.cry`'s own `HMAC` with `HMAC_init`'s lemmas as the
overrides, which ties the copy to `Main.cry` (as `Step` ties
`SHA256Step.cry`).

**Measured** (`results.txt`, the default run at `d874133` on the x86_64
IOD): 2742 proofs of the spec layer, 1083 of AES (768 of them the
exhaustive `Pgcd`, `Inverse` and `Affine`, recorded as three `RESULTS 256`
lines) and 1659 of SHA-256 and HMAC (1393 of them in the lax-arithmetic
load), with 11 negative controls of the spec layer failing as they must.
`aes_spec.saw` takes 567 s, `sha256_spec.saw` 2362 s (most of it the
`To_Bits` chains, 15 of them, and `Word_Of`), the whole `check-saw.sh`
3785 s; peak memory 3.8 GB. `SAW_LONG=1` (`results-long.txt`, at
`c31472e`): 3522 proofs of the spec layer, `sha256_spec.saw` 6363 s, the
whole 7784 s, peak 7.2 GB (below, "Running it").

**Not proved by SAW**, and why:

- `SHA2.SHA256.Hash` at 120, 128 and 200 bytes (3 and 4 padded blocks)
  only with `SAW_LONG=1`: each `Word_Of` lemma, `First` symbolic, takes
  longer the longer the padded message (yices; z3 half again as long), and
  the 66 lemmas for 1536 and 2048 bits would make every run that much
  longer. `Pad` is proved at those lengths in every run.
- `SHA2.SHA256_Bytes` (`Hash_Bytes` and its helpers): not the spec layer,
  but a ghost representation change (bytes for bits) proved equal to it by
  gnatprove (`Lemma_Hash_Bytes`); not attempted.
- HMAC at (key, text) = (0, 0), (32, 32), (64, 3) and (100, 32) bytes
  only with `SAW_LONG=1`: each call of a hash is at a secondary-stack base
  of its own, and each base costs `Pad`'s `To_Bits` chain again (65
  lemmas, about 70 s); the default run proves one length per case of
  `HMAC_init`. HMAC at other lengths, or λ < 256: not attempted.
- On their own: `Parse`, `Parse_Block`, `Join` and `Bit` (executed within
  `Hash`), `Ceil_Div` and `Ceil_Mod` (within `Small_K`), GF2's `Inner`,
  `Inner_Step`, `Inner_Next`, `Sub_Mult`, `Term`, `Lead`, `Reduce` and
  `Bit` (within `Pgcd` and the folds; `Inner` and the rest are pgcd's
  locals, with no Cryptol name), `SBox.Reversed_Bit` and `Affine_Bit`,
  `KeyExpansion.Words`, and the `Is_*` predicates (contract helpers).
- `Pgcd` and `Inverse` are proved at the modulus `SBoxPolynomial` only,
  the one `SBox.cry` and the spec's `Affine` pass.

#### The secondary stack

A spec function that returns an unconstrained array (`KeyExpansion`,
`Reverse_Keys`, `Split_Key`, `Pad`, `Zero`, `To_Bits`, `Parse`, `Join`,
`Hash`) allocates its result on the secondary stack, with
`System.Secondary_Stack.SS_Allocate`. That is executed, not assumed:
`check-saw.sh` compiles GNAT Pro's own `s-secsta.adb` and `s-soflin.adb`
from the runtime's sources (`-gnatg -gnatp -O0`, their sha256 in
`results.txt`) and links them into each spec module. A contract of such a
function starts from the state the runtime's `SS_Init` leaves the
environment task's stack in (`saw/secondary_stack.saw`): one static chunk
of 64 KiB, `Top` at its first byte (or after the bytes a caller has
already allocated), and `NT_TSD.Sec_Stack_Ptr` pointing to it; and it
states where the result is on the stack, and the stack's `Top` after the
call. Two things stand between SAW and the runtime as it is:

- GNAT calls a soft link with a static-chain ("nest") argument that the
  default target, `Get_Sec_Stack_NT`, does not take; native code ignores
  it, but SAW refuses a call whose arguments do not match the callee's
  ("Failed to load function handle"). The contracts set the soft link to
  `saw/saw_soft_links.ads`'s `Get_Sec_Stack`, harness code that takes the
  argument and returns `Get_Sec_Stack_NT`'s result. This adapter is the
  one piece of the spec proofs that is not the crate's or the runtime's
  own code.
- When SAW applies an override, it invalidates every writable allocation
  and global of its precondition that its postcondition does not describe.
  So a lemma used as an override (`Zero`, `To_Bits`, `Pad`) restates the
  soft link, `NT_TSD`'s pointer and the stack's headers, and what its
  caller allocated before the call (`keep`), and every array a spec
  contract takes by reference is writable and stated unchanged (a
  read-only allocation in an override does not match a writable one, and
  the callers pass temporaries and arrays on the secondary stack).

#### The FFI properties now backed by a proof

The FFI check stays: it is the reproducible one. These spec-layer
properties, tested with `:check` (random inputs), are now also SAW-proved
at the spec layer, for every input at the sizes stated: `prop_SubBytes`,
`prop_InvSubBytes`, `prop_ShiftRows`, `prop_InvShiftRows`,
`prop_MixColumnsStep`, `prop_MixColumns`, `prop_InvMixColumnsStep`,
`prop_InvMixColumns`, `prop_AddRoundKey`, `prop_Round`, `prop_InvRound`,
`prop_InvRound'`, `prop_RotWord`, `prop_SubWord`, `prop_Ch`, `prop_Maj`,
`prop_SIGMA_256_0`, `prop_SIGMA_256_1`, `prop_sigma_256_0`,
`prop_sigma_256_1`, `prop_step` (every input); `prop_Cipher*`,
`prop_InvCipher*`, `prop_InvCipher'*` and `prop_KeyExpansion*` (every key
and block, at the property's key size); `prop_pad` (at the twelve
lengths) and `prop_hash`, `prop_hash_bits` (at nine). `SBox.affine` and
`GF2::inverse`, which have no FFI property and no executable counterpart,
are proved for every byte. Since #59's second PR, `Main`'s
`prop_Encrypt*`/`prop_Decrypt*` too (every key and block at each key
size), and HMAC's spec properties (`prop_HMAC_*`, `prop_HMAC_init`) at
the (key, text) lengths proved, which overlap theirs only in part. Not
backed: `prop_parse` (executed within `Hash` only) and `prop_Hash_Bytes`.

### Running it

There is **no `llvm_unsafe_assume_spec`**: every override is a proof in
the same module, and `check-saw.sh` refuses to run if a script under
`saw/` contains one.

```console
$ GNAT_LLVM_DIR=.../gnatpro-llvm-ada/install LLVM_LINK_DIR=.../llvm-21.1.8 scripts/check-saw.sh
$ scripts/check-saw.sh --print      # run, print the record, write nothing
$ SAW_LONG=1 scripts/check-saw.sh   # also the long proofs; writes saw/results-long.txt
```

**What the default run proves, and `SAW_LONG`.** The default run (about
an hour on the x86_64 IOD) proves everything above but `Hash` at 120, 128
and 200 bytes and HMAC at (key, text) = (0, 0), (32, 32), (64, 3) and
(100, 32) bytes; `SAW_LONG=1` adds those (`Word_Of`'s lemmas for 1536 and
2048 bits, `Foldl_Step` at 3 and 4 blocks, and four more HMAC lengths
with their hashes' lemmas at their stack bases) and records the run in
`saw/results-long.txt`. Each record's `options` line says which it was.

**Local only, never CI** (Tony, 2026-10-19). The bitcode comes from
**GNAT Pro 27's LLVM back end** (`$GNAT_LLVM_DIR/bin/llvm-gcc`), which CI
does not have and nobody without GNAT Pro can install. It is used for
nothing else: the crate's toolchain, its gates and CI stay FSF GNAT 16.1.
`check-saw.sh` fails at once, saying so, when `GNAT_LLVM_DIR` is unset. On
the x86_64 instance the bootstrap's `gnat-llvm` phase checks
`GNAT_LLVM_DIR` and writes it to `env.sh` when it is set; nothing of GNAT
Pro is downloaded.

**A memory cap on every `saw` run.** Each runs in its own systemd scope,
`systemd-run --user --scope -p MemoryMax=10G -p MemorySwapMax=0`
(`SAW_MEMORY_MAX` overrides the 10G), so that a proof whose terms blow up
is killed alone, not the machine and everything on it. A run killed by
the cap is reported as a failure ("KILLED by the memory cap"), never as a
hang or a pass, and a negative control killed by it does not count as
failing. Where `systemd-run --user` does not work, the runs are uncapped
and the script says so; the record names the cap it ran under.

**`llvm-link`, pinned.** SAW verifies one LLVM module at a time and takes
an override only from that module, and `AES.Impl` calls `AES.Spec.Types`,
`SHA256_Stream` the SHA-256 instance and `Functions`, `HMAC.SHA256_Impl`
`SHA256_Stream` (see "The bitcode ABI"). GNAT Pro ships no `llvm-link`, so
`check-saw.sh` links each module's units' bitcode with **LLVM's own 21.1.8
release**, the LLVM of GNAT Pro 27's llvm-gcc: `LLVM_LINK_VERSION`,
`_TAG`, `_TARBALL` and `_SHA256` in `scripts/toolchain-pins.env` (the
sha256 is the digest GitHub lists for `LLVM-21.1.8-Linux-X64.tar.xz`).
`LLVM_LINK_DIR` must name a directory with that `bin/llvm-link`; the
script fails, saying which, when it is unset, missing, of another
version, or when GNAT-LLVM's LLVM (`llvm-nm --version`) is not the same
version. The bootstrap's `gnat-llvm` phase installs it when
`GNAT_LLVM_DIR` is set: it fetches the 2 GB tarball, checks its sha256,
extracts `bin/llvm-link` alone (it is statically linked against LLVM) to
`~/foundation-tools/llvm-21.1.8`, and writes `LLVM_LINK_DIR` to `env.sh`.

**The record.** Since no one else can rerun it, every run that passes
writes `saw/results.txt`: the commit (the tree must be clean), the date,
the host, the versions of llvm-gcc, LLVM, llvm-link (with the tarball's
sha256), SAW, Cryptol and z3, the memory cap, the compiler switches, the
sha256 of each unit's bitcode and of each linked module, of every crate
source the compiler read for them (the ALIs' dependencies), of every NSA
Cryptol file imported and of `saw/SHA256Main.cry`, each result with its
tactic and SAW's time for it, each negative control's counterexample and
time, and the wall-clock. Commit it with the change it checks. CI's gates
do not read `saw/`: the trust and docs gates scan `src/`, and the bitcode
(`saw/obj/`) is not tracked.

**What it runs.**

1. For each module, `aes` and `sha256`, `llvm-gcc -c -gnat2022 -gnatp
   -gnatVn -O0 -emit-llvm` on its units, every directory of `src/` on the
   search path, into `saw/obj/`: for `aes`,
   `src/aes/foundation_spark-aes-impl.adb` and
   `src/aes/foundation_spark-aes-spec-types.ads`; for `sha256`,
   `src/sha2/foundation_spark-sha2-sha256_stream.adb`,
   `src/sha2/foundation_spark-sha2-sha256.ads` (the SHA-256 instance of
   the generic `Main`), `src/sha2/foundation_spark-sha2-functions.ads` and
   `src/hmac/foundation_spark-hmac-sha256_impl.adb`. No run-time or
   validity checks (gnatprove proves them absent). No `-gnata`, so
   contracts, assertions and ghost code are ignored and none reaches the
   bitcode. The units need no SPARKlib.
2. `llvm-link` of each module's units into `saw/obj/aes.bc` and
   `saw/obj/sha256.bc`. `llvm-nm` checks each unit's bitcode and each
   linked module: no symbol of a ghost entity is defined or referenced —
   the AES spec units and lemmas; `SHA2.SHA256_Blocks`, `HMAC.Main` and
   `HMAC.SHA256`; the ghost functions of the units that also hold
   executable code (the spec layer's `W`, `Step`, `Hash` and the rest of
   the SHA-256 instance, `SHA256_Bytes`' and `SHA256_Stream`'s ghost
   functions, `HMAC.SHA256_Impl`'s); and every `Lemma_`. The check is not
   vacuous: with `-gnata` it lists over a hundred such symbols in the
   SHA-256 and HMAC units.
3. The spec layer (M4.4): for each spec module, `aes_spec` and
   `sha256_spec`, the same `llvm-gcc` with `-fno-inline` and
   `-gnatec=saw/spec.adc` on its units into `saw/obj/spec/`: for
   `aes_spec`, `src/aes/foundation_spark-aes-spec-{types,gf28,gf2,sbox,
   cipher,keyexpansion,main}.ads`; for `sha256_spec`,
   `src/sha2/foundation_spark-sha2.ads`, `-sha2-functions.ads`,
   `-sha2-preprocessing.ads` and `-sha2-sha256.ads`. The runtime's
   `s-secsta.adb` and `s-soflin.adb` (`-gnatg -gnatp -O0 -emit-llvm`) and
   `saw/saw_soft_links.ads` are compiled once and linked into each.
   `llvm-nm` checks that each spec module defines ghost symbols.
4. `saw aes_impl.saw`, `saw sha256_impl.saw`, `saw aes_spec.saw` and
   `saw sha256_spec.saw` (from `saw/`, with `CRYPTOLPATH` the repository's
   root), each capped: every proof must pass. A `RESULTS <n> proved` line
   (the exhaustive `Pgcd`, `Inverse` and `Affine`) counts n proofs.
5. `saw negative/*.saw`, each capped: each negative control must **fail**
   with a counterexample:
   - `X_Times` against the shift without the reduction: `b = 128`;
   - `Sub_Bytes` against `InvSubBytes`;
   - `Expand_Key` at 128 against `KeyExpansion` of the key words reversed;
   - `Encrypt_Block` at 256 against `Cipher` of the round keys reversed;
   - `Decrypt_Block` at 128 against `InvCipher` of the round keys
     reversed;
   - `Compress` against `step` with the feed-forward adding `H`'s words
     reversed (`step h m - h + reverse h`);
   - `Hash` at 56 bytes against `hash` of the message's bytes reversed;
   - `HMAC_SHA256` at a 100-byte key and a 3-byte text against `HMAC` of
     the key reversed;
   - and of the spec layer, one per kind of proof, each with the
     overrides and tactic of the proof it mirrors:
     `spec_xtimes_without_reduction` (a leaf, rme: `b = 128`);
     `spec_dot_wrong_modulus` (`Dot` on the fold lemmas, against `pmod`
     by `x^^8 + x^^4 + x^^3 + x^^2 + 1`); `spec_affine_wrong_byte` (an
     exhaustive proof: `Affine` at `0x53` against `affine 0x52`, a goal
     with no variable, so its counterexample is empty);
     `spec_w_reversed_key` (`KeyExpansion.W` at k = 128, I = 4, on the
     lemmas at 0 .. 3, against the key words reversed);
     `spec_foldl_round_reversed` (`Foldl_Round` at 9 round keys against
     `foldl Round z (reverse xs)`); `spec_cipher_reversed_round_keys`
     (`Cipher` at 256); `spec_sha256_w_reversed_block` (SHA-2's `W` at 16
     against the block reversed); `spec_sha256_step_reversed_feed_forward`
     (`Step`, as the `Compress` control); `spec_sha256_pad_complemented`
     (`Pad` at 1 byte, in the lax load, against `pad` of the message
     complemented). (The leaf control was first `ShiftRows` against
     `InvShiftRows`: rme's normal form of that false 128-bit equality took
     the 10 GB cap.)

   The implementation's controls but the first two run their module's
   script first, and the spec layer's the lemma files they need, and use
   their overrides and tactics, in the same uninterpreted vocabulary, so
   they show that neither the overrides nor the uninterpreted functions
   make the proofs vacuous. (`Encrypt_Block` against
   ``InvCipher`{128}`` fails too, but z3 took 245 s to find the
   counterexample, with `Round` uninterpreted on one side and `InvRound`
   interpreted on the other; it is not among the controls. Nor are three
   stronger controls of `Compress` that no solver refuted in time: `step`
   of the block reversed (z3 stopped after 11 min at 2.8 GB; yices and
   bitwuzla, 400 s), of the block with word 15 flipped (z3, 400 s), and
   with its result words rotated (z3, 150 s). Telling two different
   64-round terms apart means bit-blasting both, with the uninterpreted
   sigmas' applications Ackermannized; the correct spec is the same term
   as the implementation's and is proved in 3 s.)

The scripts follow `algorithms/AES/rust/Cipher/theorems/saw.py`: a
contract per shape of subprogram, leaves first, each verified leaf passed
as an override to its callers, `rme` for the bitwise leaves, and z3 with
the overridden compositions uninterpreted above them (for AES the
template's `z3(["Round", "SubBytes", "ShiftRows"])`, plus `AddRoundKey`;
the template uses ``InvCipher'`` and cvc5 for decryption, the crate's
`Decrypt_Block` is ``InvCipher`` itself and z3 proves it). They are
SAWScript, not the Python client: SAWScript runs with the `saw` of the
release tarball alone, while the client needs `saw-remote-api` and an
unpinned `saw-client` from PyPI; the NSA's own
`algorithms/*/theorems/*.saw` are SAWScript too.

**Constraints of SAW 1.6 on GNAT-LLVM 27 bitcode**, measured:

- **No `-g`.** SAW rejects the debug metadata (`METADATA_BLOCK` "not yet
  implemented").
- **`-O0`.** At `-O1` and above, LLVM's SROA builds GNAT's array returns
  with `insertvalue [16 x i8] poison, ...`, and crucible panics
  ("Attempting to evaluate poison value"). `X_Times` and `Sub_Byte`
  (scalars) verify at `-O2 -gnatn`; `Sub_Bytes` (an array) does not.
- **One module per proof.** An override must come from the module being
  verified (`llvm_verify` says "different LLVM module" otherwise), and the
  GNAT Pro install has no `llvm-link`: hence the pinned `llvm-link` above,
  and one linked module per algorithm.
- **Lax arithmetic is fixed at load time.** `enable_lax_arithmetic`
  changes nothing for a module already loaded: SAW applies it when it
  translates the module, at `llvm_load_module`. Hence the second load of
  `sha256.bc` for the proofs that need it.
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

What `llvm-gcc -O0` makes of the SHA-256 and HMAC units (M4.3, #24):

- **`Hash_Value` and `Block` are passed by reference**, unlike AES's
  16-byte `Block`: `procedure Compress (H : in out Hash_Value; M : Block)`
  is `void (ptr %h, ptr %m)`, `H` a writable pointer to `[8 x i32]`, `M` a
  read-only pointer to `[16 x i32]`; the contract
  (`compress_contract`) allocates both and states the result with
  `llvm_points_to` on `H`. `"+" (Left, Right : Hash_Value)` takes two
  read-only pointers and returns `[8 x i32]` by value. A function
  returning a `Block` (`Load_Block`) takes a hidden first pointer to the
  result (`ptr %_return`). The 32-byte `Digest` is returned by value,
  `[32 x i8]`. `Unsigned_32` is `i32`; Ch and Maj take three `i32`.
- **`Byte_Array`** (`SHA256_Bytes`, index `Byte_Index`, `0 .. 2 ** 62`) is
  a fat pointer `{ ptr, ptr }`, its bounds record `{ i64, i64 }`
  (`..._sha256_bytes__byte_array_BOUNDS`). `Hash (M)` is
  `[32 x i8] ({ ptr, ptr } %m)`, `HMAC_SHA256 (Key, Text)` the same with
  two. The contracts (`byte_array_arg`) allocate the `n` bytes read-only
  with bounds `{0, n - 1}` (`{0, -1}` for `n = 0`, a null range). After
  `llvm-link`, every `{ ptr, ptr }` fat-pointer type of the four units is
  merged into one, named after the first the linker met
  (`..._sha256_stream__chunk_ends_FP`): the name says nothing about the
  array.
- **Layout against the Cryptol.** Byte `I` of a `Byte_Array` is element
  `i` of Cryptol's `[n][8]`, its most significant bit first, so the
  message's bits are `join msg`, as `hash` and `HMAC` take them; the
  `Digest`'s bytes are `split` of the `[256]`. Word `J` of a `Block` or a
  `Hash_Value` is element `j` of `[16][32]` or `[8][32]`.
- **Records** (`SHA256_Stream.Context`, packed `<{ [8 x i32], [64 x i8],
  i64 }>`; `HMAC.SHA256_Impl.Context`) are passed by reference; the
  one-shot `Hash` and `HMAC_SHA256` keep them on their own stack, so no
  contract allocates one.
- **Constant tables** (`K_256`, and the initial context with `H0_256`) are
  private constant copies in `SHA256_Stream`'s bitcode
  (`@foundation_spark-sha2-sha256_stream.for.ref`): `Compress` reads no
  other unit's data.
- **Ranges' lengths.** GNAT-LLVM computes the length of `Lo .. Hi` as
  `select (Lo > Hi, 0, (Hi - Lo) +nuw 1)`. For a null range with
  `Hi = Lo - 1`, the `add nuw` wraps and makes a poison value in the
  operand the `select` discards. LLVM allows that (a `select` is poison
  only if the operand it chooses is), but crucible fails the proof where
  the poison is created ("Poison value created: Unsigned addition caused
  wrapping even though the `nuw` flag was set"), with any bounds, `{0, -1}`
  or `{1, 0}`. The crate makes such a range for an empty argument and in
  `Final`'s `Last (0 .. R - 1) := C.Buf (0 .. R - 1)` when `R = 0`. The
  proofs that reach one load the module a second time with SAW's
  `enable_lax_arithmetic` (above), under which overflow is not an
  obligation; absence of overflow is gnatprove's to prove, and it does.

What the spec layer's build (`-fno-inline`, ghost code on, M4.4, #59)
adds:

- **Ghost symbols are GNAT's external names, unchanged.** GNAT-LLVM 27
  links ghost entities under their plain names:
  `Foundation_Spark.AES.Spec.GF28.Dot` is
  `foundation_spark__aes__spec__gf28__dot`, and even a ghost `Export` with
  `External_Name => "spark_xTimes"` is `spark_xTimes` (checked with
  `llvm-nm` on the FFI shim `Foundation_Spark.FFI.AES_GF28`). FSF GNAT
  16.1, which builds the FFI library, links them under `___ghost_`
  followed by the name ("The FFI harness"); the SAW scripts name the
  plain symbols. A generic instance's functions take the instance's name:
  `foundation_spark__sha2__sha256__w`, `..._sha256__logical__ch`; `"+"` is
  `..._Oadd`, `"xor"` `..._Oxor`.
- **Every subprogram is a call.** GNAT-LLVM marks expression functions
  `alwaysinline` (the attribute set `alwaysinline memory(read)`), and LLVM
  inlines those even at `-O0`; with `-fno-inline` they are `noinline`.
- **`Boolean` is `i8`**, 0 or 1, as an argument, a result and an array
  element.
- **Bit sequences** (`AES.Spec.Main.Bits`, `SHA2.Bits`) are arrays of
  `i8`, one per bit, 0 or 1, the Cryptol's first bit first. SHA-2's index
  is a 128-bit integer type (its domain needs it); AES's, since #68, is
  `range 0 .. 256` (`Object_Size` 16). Unconstrained, they are fat
  pointers `{ ptr, ptr }` whose bounds record is two of the index type
  (`..._bits_BOUNDS`): SHA-2's `{ i128, i128 }`, AES's `{ i16, i16 }`, so
  AES's `Byte_At (Bs, From)` is `i8 ({ ptr, ptr } %bs, i16 %from)` (the
  AES widths are unverified until the next GNAT-LLVM session: they are
  `Bit_Index`'s `Object_Size`, not read from the IR). The contracts take
  n bytes under the precondition that each is 0 or 1 (an Ada Boolean's
  validity) and read them as Cryptol bits (`[ b == 1 | b <- bs ]`).
  `Block_Bits` (`Bits (0 .. 127)`, constrained) is passed by reference and
  returned through a hidden first pointer. **SAW 1.6 cannot translate a
  `getelementptr` with an index wider than 64 bits** (crucible-llvm's
  `calcGEP_array`, at 2026-10-16, takes an index of exactly the pointer's
  width or narrower, and no GNAT switch avoids the wide one). GNAT-LLVM
  emits one where a constrained array of a 128-bit index type is indexed
  directly; indexing through a fat pointer goes through an `i64` offset
  and is fine. Until #68 there was one, in AES's `Join_Block` (its
  aggregate over `Block_Bits'Range`), and `check-saw.sh` rewrote it to a
  `trunc` to `i64` (`gep64`, with `opt` and `llvm-extract`). #68 narrowed
  AES's `Bit_Index` instead, which removes the index, the rewrite and the
  two tools; `check-saw.sh` still refuses a linked spec module with an
  `i128` GEP index, by name, before SAW would.
- **Unconstrained results** are on the secondary stack: `SS_Allocate`'s
  block holds the bounds record, then the data (`KeyExpansion`'s
  `Round_Keys`: `{ i32, i32 }` at 0, the blocks at 8; a `SHA2.Bits`:
  `{ i128, i128 }` at 0, the bits at 32), and the function returns the fat
  pointer `{ data, bounds }`. Sizes are rounded up to 16 bytes. An empty
  `Bits` aggregate (`To_Bits (V, 0)`) is the bounds `{0, -1}` alone. A
  function that calls others which allocate (`InvCipher`, `Main`'s) marks
  the stack and releases it on exit, through a finalizer called on every
  path (and an `invoke` of each call, which SAW translates).
- **Slices' bounds** (`W (1 .. Nr (K) - 1)`, and each fold's rest) are
  built in a stack temporary of the caller, writable and 1-byte aligned
  (`alloca ..., align 1`): the fold lemmas' bounds are allocated so, and a
  slice's data pointer points into its array (an interior pointer, which
  an override's allocation matches).
