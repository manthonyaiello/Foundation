# The FFI check against the Cryptol

How the SPARK functions are called from Cryptol through its `foreign`
interface and compared with NSA's Cryptol, by exhaustive or random
testing. Installing Cryptol is in [bootstrap.md](bootstrap.md). Back to
the [README](../README.md).

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
checker needs it), and python3 (macOS's bash 3.2 is enough). It sets
`CRYPTOLPATH` to the repository root and `cryptol/`, so a property module
imports `algorithms::AES::GF28` by its NSA name.

**On macOS** (#113) the check runs as on Linux, with `.dylib` for `.so`,
and two differences, neither of which touches the Linux build:

- gprbuild 26.0.1 does not enable encapsulated libraries for aarch64
  Darwin (it does for x86_64 Darwin), so `foundation_spark_ffi.gpr` sets
  `Library_Encapsulated_Supported` itself when Alire's host is `macos`. The
  library is still encapsulated (`libgnat_pic.a` and a static libgcc linked
  in) and depends on `libSystem` only. Apple's `ld` fails a dylib link on
  an undefined name by default, so it gets no `--no-undefined`.
- Galois signs the macOS release of Cryptol with the hardened runtime, which
  refuses to `dlopen` a library not signed by Galois ("different Team
  IDs"). `check-ffi.sh` detects that signature and runs an ad hoc signed
  copy of the binary (`obj/ffi/cryptol-adhoc/cryptol`), made once and
  remade when the original changes.

The coverage build (`check-coverage.sh`) has not been run on macOS; CI runs
it on Linux.

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
  `cryptol -b`, writes `obj/ffi/ffi-results.txt` (format in [proving.md, "The board"](proving.md#the-board)),
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
