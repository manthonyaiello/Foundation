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
  entry and its declaration carries `Import`.
