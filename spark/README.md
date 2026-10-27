# SPARK implementations of AES, SHA-256 and HMAC-SHA-256

This directory is an Alire crate, `foundation_spark`. It holds SPARK
implementations of three algorithms from the NSA's Cryptol specifications 
in [`../algorithms`](../algorithms):

* **AES** (FIPS 197): key expansion, encryption and decryption, at 128,
  192 and 256-bit keys;
* **SHA-256** (FIPS 180-4): one-shot and streaming;
* **HMAC-SHA-256** (FIPS 198-1): one-shot and incremental.

Each is proved, with SPARK's prover `gnatprove`, equal to a SPARK
transcription of the NSA's Cryptol. That transcription is checked against 
the Cryptol itself by testing through Cryptol's foreign function interface
and by proof with SAW.

## How the pieces fit

```text
  NSA's Cryptol (algorithms/AES, SHA2, HMAC)
        |                          ^
        | the FFI check            | SAW, at fixed sizes:
        | (testing, in CI)         | spec layer = Cryptol
        v                          |
  Spec layer: ghost SPARK, declaration by declaration the Cryptol
        ^
        | gnatprove, for all inputs (in CI)
        |
  Implementation layer: executable SPARK      --- SAW, at fixed sizes:
  (postconditions: "the result is the spec's")    implementation = Cryptol
```

* The **spec layer** mirrors the Cryptol as closely as SPARK allows: the
  same names, the same types (Boolean arrays where Cryptol has bits), the
  same recursion and folds. It is ghost code: it is proved, and it runs
  only in the test build, never in the library a client links. The Cryptol built-ins it is
  written in (`foldl`, `@`, `join`, `split`, ...) are stated once, in
  [`src/cryptol/`](src/cryptol) ([doc/cryptol-prelude.md](doc/cryptol-prelude.md)).
* The **implementation layer** is ordinary SPARK, written to run. Each
  subprogram's postcondition says its result is the spec layer's. Lemma
  units and representation layers (bytes against bits, streaming against
  one-shot) sit between the two.
* **gnatprove** proves the implementation equal to the spec layer for every
  input, and proves the absence of run-time errors (overflow, out-of-range
  indexing, and so on) everywhere.
* The **FFI check** calls the spec layer and the executables from Cryptol
  and compares them with NSA's Cryptol, exhaustively where the input space
  is small and on random and known-answer inputs otherwise.
* **SAW** proves the compiled LLVM bitcode of both layers equal to NSA's
  Cryptol, with no SPARK spec in between, at fixed key sizes and message
  lengths.

The walkthroughs show the chain on real code, Cryptol and SPARK side by
side:

* [AES](doc/walkthroughs/aes.md)
* [SHA-256](doc/walkthroughs/sha-256.md)
* [HMAC-SHA-256](doc/walkthroughs/hmac-sha-256.md)

## What is proved

* **Every check gnatprove generates is proved**: 4085 of 4085 in the CI
  gate's 72 units (gnatprove analyzes 71 of them), and 2565 of 2565 in one
  slow unit proved on demand (`SBox_Entries`, the S-box table against its
  algebraic definition). The gate's count is for `main` at `383bce7`
  (`scripts/board.py` recounts it from a proof run); the slow unit's is
  its entry in
  [`scripts/proof-slow.txt`](scripts/proof-slow.txt).
* **Nothing is assumed.** There is no `pragma Assume`, no justified check,
  no `SPARK_Mode => Off`, and no warning or check suppression. The only
  code gnatprove does not see is the 23 foreign-binding units that export
  the spec to Cryptol for testing, each listed with its reason in
  [`scripts/trust-surface.txt`](scripts/trust-surface.txt). CI enforces
  this ([doc/proving.md](doc/proving.md), "Gates").
* **The implementation equals the spec layer for every input**, including
  every message length below 2^61 bytes (for HMAC, every text shorter than its
  `Max_Text`) and every way of splitting a message into chunks for the
  streaming SHA-256 and HMAC interfaces.
* **SAW**: 1895 results in its default run, 87 of the implementation
  layer and 1808 of the spec layer, with 20 negative controls that fail
  as they must (`saw/results.txt`, at `ae3eb2c`, as `scripts/board.py`
  counts it); 2142 with `SAW_LONG=1`, 87 and 2055
  (`saw/results-long.txt`, at `8279ca5`). Both commits differ from
  `383bce7` only by records (the slow proof's and the default run's). AES at
  k = 128, 192 and 256; SHA-256's compression function for every input;
  hashing and HMAC at fixed lengths chosen at the padding boundaries.
  Details and what SAW leaves out: [doc/saw.md](doc/saw.md).

What is **not** proved:

* that the spec layer equals the Cryptol for every input at every size.
  That rests on the FFI check (testing) and on SAW (proof at fixed sizes:
  all of AES, but SHA-256 and HMAC only at the lengths SAW was run at);
* that the compiler is correct. gnatprove reasons about the Ada source;
  SAW about the bitcode one compiler (GNAT Pro's LLVM back end) emits;
* timing. The AES here is not constant time: its S-box is a table lookup
  indexed by key and state bytes. A constant-time AES (a bitsliced S-box,
  proved equal to the same spec) is on the `constant-time` branch.

## What is tested

* **The FFI check**: 141 properties
  ([`cryptol/properties.txt`](cryptol/properties.txt)), run in CI on
  every change. They compare the SPARK functions with NSA's Cryptol, with
  Cryptol's `:exhaust` (every input, for bytes and other small domains)
  or `:check` (random inputs), plus the known-answer vectors of FIPS 197,
  FIPS 180-4 and RFC 4231. [doc/ffi.md](doc/ffi.md).
* **Coverage** of the executable code under those properties, statement,
  decision and MC/DC; a gap is closed with a property or explained in
  [`coverage/explained.txt`](coverage/explained.txt). Measured in CI:
  334/334 statements, 13/13 decisions and 14/14 MC/DC, with no gap.
  [doc/coverage.md](doc/coverage.md).
* **Mutation testing**: 84 one-line faults in the executable code. The FFI
  properties catch 68. Of the other 16, 10 do not change behaviour, and 6
  are real bugs in the streaming SHA-256 that only show on messages longer
  than the properties try, or on an array that does not start at index 0.
  gnatprove fails to prove all six (by timeout, not by counterexample).
  [doc/coverage.md](doc/coverage.md), "Mutation testing".
* **Performance** against NSA's Rust reference AES.
  [doc/performance.md](doc/performance.md).

## Layout

| path | what |
|---|---|
| [`src/aes/`](src/aes), [`src/sha2/`](src/sha2), [`src/hmac/`](src/hmac) | per algorithm: the spec layer (`*-spec-*`, and SHA-2's and HMAC's generics), the implementation (`*-impl*`, `*-sha256_stream`, `*-sha256_impl`) and their lemmas |
| [`src/cryptol/`](src/cryptol) | Cryptol's built-ins in SPARK, as ghost generics |
| [`src/ffi/`](src/ffi) | the units that export the SPARK functions to Cryptol |
| [`cryptol/`](cryptol) | our Cryptol: the property modules that call the SPARK exports, and `properties.txt` |
| [`saw/`](saw) | the SAW scripts, and `results.txt`, the record of the last run |
| [`coverage/`](coverage), [`mutation/`](mutation) | coverage and mutation-testing inputs |
| [`perf/`](perf) | the performance harness |
| [`scripts/`](scripts) | proof, FFI, coverage, SAW, gates, bootstrap; `toolchain-pins.env` pins every tool |
| [`doc/`](doc) | the detailed documents below |

## Reproducing

From the repository root:

```console
$ alr -n toolchain --select gnat_native=16.1.0 gprbuild=26.0.1
$ alr -n install gnatprove=16.1.0
$ export PATH="$HOME/.alire/bin:$PATH"
$ cd spark
$ alr -n build
$ FOUNDATION_SPARK_PROOF_ALLOWANCE=ci scripts/check-proof.sh   # the CI proof gate
$ scripts/check-ffi.sh                                         # needs Cryptol 3.6.0 with FFI
```

`alr` 2.1.1 comes from [Alire's release
page](https://github.com/alire-project/alire/releases/tag/v2.1.1), and
Cryptol 3.6.0 from [Galois's](https://github.com/GaloisInc/cryptol/releases/tag/3.6.0)
(take a build "with solvers").

Everything but SAW needs only free tools (the FSF path). SAW needs GNAT
Pro 27's LLVM back end. Both paths, step by step:
[doc/reproducing.md](doc/reproducing.md).

## Documents

| document | what it covers |
|---|---|
| [doc/reproducing.md](doc/reproducing.md) | the FSF path and the SAW (GNAT Pro) path, step by step |
| [doc/proving.md](doc/proving.md) | running gnatprove, proof levels, the board, slow proofs, the CI gates, where spec and implementation differ by design |
| [doc/cryptol-prelude.md](doc/cryptol-prelude.md) | Cryptol's built-ins in SPARK, and the choices made in stating them |
| [doc/ffi.md](doc/ffi.md) | the FFI check: how SPARK is called from Cryptol, what a pass requires, what each algorithm's properties cover |
| [doc/coverage.md](doc/coverage.md) | coverage under the FFI properties, and mutation testing |
| [doc/performance.md](doc/performance.md) | size and speed against NSA's Rust AES |
| [doc/saw.md](doc/saw.md) | the SAW proofs: what is proved at which sizes, what is not, how to run them, the bitcode details |
| [doc/bootstrap.md](doc/bootstrap.md) | installing Cryptol (and building it from source), and bootstrapping an x86_64 Linux machine |
| [doc/walkthroughs/](doc/walkthroughs) | AES, SHA-256 and HMAC-SHA-256: Cryptol and SPARK side by side |
