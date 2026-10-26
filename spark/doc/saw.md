# SAW

SAW proofs that the LLVM bitcode of the implementation layer, and of the
ghost spec layer, equals NSA's Cryptol, at fixed sizes. They need GNAT
Pro's LLVM back end, so they run locally, not in CI; the record of the
last run is `saw/results.txt`. How to run them is in
[reproducing.md](reproducing.md#the-saw-path-gnat-pro). Back to the
[README](../README.md).

## SAW

SAW proves the **implementation** layer equal to NSA's Cryptol
directly, with SAW's `llvm_verify` on LLVM bitcode of the crate's own
sources, independently of the SPARK spec layer and of gnatprove: three
leaves of `Foundation_Spark.AES.Impl`; the key schedule and both ciphers
at each key size, against `algorithms/AES/KeyExpansion.cry` and
`Cipher.cry`; SHA-256's compression function for all inputs, and the
one-shot SHA-256 and HMAC-SHA-256 at fixed lengths, against
`algorithms/SHA2/Main.cry` and `algorithms/HMAC/Main.cry`. SAW also
proves the **spec layer** equal to the same Cryptol, so that spec =
Cryptol, which the FFI check tests, is also a proof at these sizes
(below, "The spec layer"). The NSA Cryptol is imported unmodified.

**SAW proves each size separately; gnatprove covers every size.**
`Compress` is proved for every hash value and block, but `Hash` and
`HMAC_SHA256` take arrays, and SAW executes them at one length at a time:
each row below is one length. gnatprove proves the same
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
with `Inv_Round_Prime` (``InvCipher'``).
`Sub_Word`, `Rot_Word`, `Xor_Word` and `Rcon` are expression functions
that llvm-gcc marks `alwaysinline` and inlines into `Expand_Key` even at
`-O0`, so they are proved as part of it. Why, and what proves them
instead: "What SAW proves on its own, in place, or not
at all", below.

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
  reached a 4 GB cap in under 7 s; uncapped, it took the x86_64 instance's 15.7 GB
  and was killed by the kernel. Hence the memory cap below.
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
`Hash`), `Hash_Chunked`, and the incremental HMAC interface on its own
(executed within `HMAC_SHA256`). Precisely which results execute each,
and what proves them for every input: "What SAW proves on its own, in
place, or not at all", below.

### The spec layer

SAW proves the ghost spec layer equal to the NSA Cryptol, with
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
- **Recursions: unfolded where that is cheaper, a lemma per index where
  not**. A recursive ghost function whose variant is a size is
  either proved once, at the size its caller uses, with SAW unfolding the
  recursion (the overrides are those of the calls each level makes), or
  one index at a time, each lemma with the lemmas at the smaller indices
  it calls as overrides. For the linear ones unfolding measured 10 to 30
  times cheaper (`Rounds.Foldl` 2.4 s unfolded against 23.2 s for its 65
  lemmas, `To_Bits` 1.4 s against 43.8 s), and each linear recursion was
  then measured both ways (`saw/experiments/issue-99/`,
  `results-2026-10-23.txt` there). **Unfolded:** SHA-2's `Rounds.Foldl`
  (`Foldl_Step3`, 2.4 s against 25.9 s), `Literal` (`To_Bits`, 1.5 s
  against 48.0 s, at each of its stack states), `Blocks.Foldl_Take`
  (`Foldl_Step`, 0.13 s against 0.46 s at 2 blocks), and GF(2^8)'s
  `Products` (0.06 s against 0.88 s) and `Pmod_Fold` (0.19 s against
  1.65 s). **Per index**, because unfolded the goal is dearer: the
  recursions with more than one call, `KeyExpansion`'s `W` (I - 1 and
  I - Nk: unfolded it grows 1.38 times per index, some 35 minutes for
  `KeyExpansion` against 16 s for its 44 lemmas at k = 128; 44, 52 and 60
  lemmas at k = 128, 192, 256) and SHA-2's `W` (four calls; 64 lemmas,
  about what one unfolded `W` at 63 costs); and three linear ones where
  the solver's goal grows faster than the lemmas: `Word_Of` (a symbolic
  index at every level: 230 s unfolded at Count = 8 against 179.5 s for
  all 33 lemmas), the cipher folds (z3 with the round uninterpreted:
  `Round`'s 24.3 s unfolded at M = 13 against 14.2 s for its 14 lemmas,
  and 8.2 s against 7.2 s even at M = 9), and GF(2)'s `Pmod_Fold` and
  `Pdiv_Fold` (rme: 34.1 s each unfolded against 12.5 s for both
  chains). GF2's `Inner` (pgcd's `inner`) recurses on a value, the degree of
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
| `Cipher.Round_Folds.Foldl_Take`, `.InvRound_Folds.`, `.InvRound_Prime_Folds.` (the recursion of `Foldl_Round` and the others) | ``foldl Round z (take`{N} xs)`` and the others | N = 0 .. M at M = 9, 11, 13 round keys (not unfolded: measured dearer); `Round`'s with the slice's bounds a read-only constant (`Cipher` passes `W (1 .. Nr - 1)`), the inverse rounds' writable (the reversed keys, on the secondary stack) | N - 1, the round | z3, the round uninterpreted |
| `AES128.Cipher`, `AES192.`, `AES256.` | ``Cipher`{k}`` | 128, 192, 256 (one instance each) | the fold, `SubBytes`, `ShiftRows`, `AddRoundKey` | z3, the four uninterpreted |
| `Cipher.Reverse_Keys` | `reverse` | 9, 11, 13 round keys | | z3 |
| `AES<k>.InvCipher`, `.InvCipher_Prime` | ``InvCipher`{k}``, ``InvCipher'`{k}`` | 128, 192, 256 | the fold, the steps (`Reverse_Keys` executed) | z3, the round and steps uninterpreted |
| `KeyExpansion.RotWord`, `.SubWord`, `"xor"` | `RotWord`, `SubWord`, `^` | | | rme |
| `AES<k>.W` | `w @ i` = `(groupBy`{4} (join (KeyExpansion`{k} key))) @ i` | each I at each k: 44, 52, 60 | the lemmas below I (SAW applies those at I - 1 and I - Nk), the leaves | z3, `SubWord` uninterpreted |
| `AES<k>.KeyExpansion` | ``KeyExpansion`{k}`` | 128, 192, 256 | the W lemmas, `Join` | z3, `SubWord` uninterpreted |
| `Main.Bit_Of`, `.Byte_At`, `.Split_Block`; `AES<k>.Split_Key` | `Main.cry`'s `split`s: `b @ j`, ``take`{8} (bs << from)``, `split in`, `split (split key)` | `Byte_At` at 128, 192, 256 bits; `Split_Key` at each k (its result by value at every k) | none (`Split_Block` and `Split_Key` call the prelude's `Byte_Bits.Split_At`, executed) | z3 |
| `Main.Join_Block` | `Main.cry`'s `join : Block -> [128]` | any `High_Water_Mark` found (it marks the secondary stack, calls the prelude's `Byte_Bits.Join`, executed, copies its 128 bits out and releases the mark) | | z3 |
| **`AES<k>.Encrypt`, `.Decrypt`** | **`Main.cry`: ``AES`{k}.Encrypt``, ``.Decrypt``, which are `AES128.Encrypt` and the others** | 128, 192, 256 | `Split_Key`, `KeyExpansion`, `Split_Block`, `Cipher` or `InvCipher`, `Join_Block` | z3, `Cipher`, `InvCipher`, `KeyExpansion` uninterpreted |

The `{k}` functions are the generic `AES.Spec.AES_K`'s, proved on its
instances `AES128`, `AES192` and `AES256`, with no `K` argument.
Their contracts were first written on a machine with no GNAT-LLVM or SAW;
the SAW session of 2026-10-21 on an x86_64 Linux instance (`saw/results.txt`) ran them and
corrected them against the bitcode GNAT-LLVM 27 emits: the key words go
by value at k = 128 and by reference at 192 and 256, as assumed;
`KeyExpansion` returns through a pointer the caller passes first, as
assumed; `Split_Key` returns its words **by value at every k** (not
through one at 192 and 256); and `Encrypt` and `Decrypt` reach the
secondary stack through `Join_Block`, which marks and releases it.
The dispatchers of `AES.Spec.Dispatch` are not proved by SAW:
each is a `case` on `K` over the instances, and gnatprove proves that its
postcondition, the Cryptol body, holds of every instance.

`Rcon` is read by the W lemmas, and the `SBox` and `InvSBox` tables by
`SubBytes` and `InvSubBytes` (every entry, for a symbolic block).

SHA-256 and HMAC-SHA-256 (`sha256_spec.saw`, with `sha256_spec_step.saw`,
`sha256_spec_pad.saw`, `sha256_spec_hash.saw`, `sha256_spec_hmac.saw`;
shared parts in `sha256_spec_common.saw`; the HMAC units are linked into
`sha256_spec.bc`). Message lengths are the
implementation's: 0, 1, 55, 56, 63, 64, 65, 100, 119, 120, 128 and 200
bytes; HMAC's (key, text) lengths the implementation's too. The SHA-2
and HMAC spec bodies call the Cryptol prelude's instances, and the
scripts name the instances' recursions (the rows that name a
recursion). The wrappers (`To_Bits`, `Zero`, HMAC's `Repeat` and
`Zero`) pass their callee's secondary-stack result through without a
copy (GNAT-LLVM 27, read from the IR on 2026-10-21), so no stack base
moved.

| Ada (`SHA2.SHA256.` unless named) | Cryptol | sizes, lemmas | overrides | tactic |
|---|---|---|---|---|
| `SHA2.Functions.SIGMA_256_0/1`, `Small_Sigma_256_0/1`; `Logical.Ch`, `.Maj` | `Functions.cry` | | | rme |
| `W` | `Ws m @ t` (`SHA256Step.cry`: `step`'s `W@t`) | T = 0 .. 63 | the lemmas below T (SAW applies those at T - 2, T - 7, T - 15, T - 16), the sigmas | z3, the four sigmas uninterpreted |
| `T1`, `T2`, `Step3` | `SHA256Step.cry`: `step3`'s `T1`, `T2`, and `step3` | each T: 64, 1, 64 | `W` at T, the sigmas, `Ch`, `Maj`; `T1` at T, `T2` | z3, sigmas uninterpreted |
| `Rounds.Foldl` (`Foldl_Step3`'s recursion), then `Foldl_Step3` at 64 | `foldl (step3 m) h [0 ..< N]` | N = 64, unfolded | `Step3` at each round; `Rounds.Foldl` at 64 | z3, sigmas uninterpreted |
| `"+"`, `Step` | `+` on `[8][32]`; **`Main.cry`: `step`** | | `Foldl_Step3` at 64, `"+"` | z3, sigmas uninterpreted |
| `Small_K` | `hash`'s `type k = (l + 1 + 2 * w) %^ m` | each length | | z3 |
| `Zero` | `zero : [k]` | each k (7 values) | | z3 |
| `SHA2.Sequences_Of_Bits.Literal` (`SHA2.To_Bits`'s recursion) | ``drop`{128 - W} v``, `pad`'s ``(`l : [64])`` | W = 64, unfolded, for each k | | z3 |
| **`Pad`** | `Preprocessing.cry`: ``pad`{512, 32, l, k}`` | all twelve lengths | `Small_K`, `Zero`, `To_Bits` at 64 | z3 |
| `Word_Sequences.Value` (`Word_Of`'s recursion) | ``zext (take`{Count} (p << first))`` (a word of `parse`) | Count = 0 .. 32, P of 512 and 1024 bits | Count - 1 | yices |
| **`Parse`** | `Preprocessing.cry`: ``parse`{32, N}`` | N = 1, 2 blocks; with `SAW_LONG=1` also 3, 4 | `Word_Of` at 32 for 512 N bits (`Parse_Block`, `Split_At` executed) | z3 |
| `Blocks.Foldl_Take` (`Foldl_Step`'s recursion) | ``foldl step h (take`{N} ms)`` | N = 1 of 1 block, 2 of 2 (with `SAW_LONG=1` also 3 of 3, 4 of 4), unfolded | `Step` | z3, `step` uninterpreted |
| **`Hash`** | `Main.cry`: ``hash`{l}`` | 0, 1, 55, 56, 63, 64, 65, 100, 119 bytes; with `SAW_LONG=1` also 120, 128, 200 | `Pad`, `Word_Of` at 32, `Foldl_Step` (`Parse`, `Parse_Block`, `Join`, `Bit` executed) | z3, `step` uninterpreted |
| `Hash` (for HMAC), with its `Pad`, `Zero`, `To_Bits` | as above | at each base of the secondary stack where HMAC calls it (below) | as above | as above |
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
each hash's lemma, with `Pad`, `Zero` and `To_Bits` under it
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

**The prelude's instances on their own** (`saw/aes_spec_prelude.saw`
and `saw/sha256_spec_prelude.saw`, each
included last by its module's script). The proofs above execute the
Cryptol prelude's instances ([cryptol-prelude.md](cryptol-prelude.md)), or take their
recursions' lemmas as overrides. These prove each instance a spec layer
calls by itself, at the sizes it is called at, against the Cryptol
built-in it states:

| instance (generic) | Cryptol built-in | sizes | overrides | tactic |
|---|---|---|---|---|
| GF28's `Byte_Bits`, `Product_Bits`, GF2's `Poly_Bits`, `Main.Byte_Bits.Word_Bits` (`Words`): `Bit`, `Head` | `x @ j`, `head x` | `[8]` in a byte, `[15]` and `[9]` in a `Poly`, `[8]` | | z3, rme |
| `GF28.Products.Pmult` (`Polynomial_Products`) | `pmult` | `[8] x [8] -> [15]` | `Products` at 8 | rme |
| `Cipher.Table_Indexing.Bulk_Index`, `Cipher.Block_Indexing.Bulk_Index` (`Bulk_Indexing`) | `xs @@ is` | `[256][8] @@ [16][8]`, any table; `[16][8] @@` 16 indices below 16, any permutation | | z3 |
| `Cipher.Round_Folds.Foldl`, `.InvRound_Folds.`, `.InvRound_Prime_Folds.` (`Folds`) | `foldl f z xs` | M = 9, 11, 13 round keys | `Foldl_Take` at M | z3, the round uninterpreted |
| `Cipher.Key_Sequences.Reverse_Of` (`Sequences`) | `reverse` | 9, 11, 13 round keys | | z3 |
| `Main.Byte_Bits.Join`, `.Split_At` (`Join_Split`) | `join`, `split` | 16 bytes; 128, 192, 256 bits | | z3 |
| `SHA2.Lengths.Ceil_Div`, `.Ceil_Mod` (`Numeric`) | `` `(a /^ b) ``, `` `(a %^ b) `` (type operators, so constants) | A = l + 65, B = 512, at the 14 lengths l `Hash` and HMAC's hashes are proved at | | z3 |
| `SHA2.Sequences_Of_Bits.Zero`, `.Literal` (`Bit_Sequences`) | `zero : [n]`; the `[64]` literal of `v`, ``drop`{64} v`` | the 9 counts `Pad` and `HMAC_init` use; W = 64, unfolded | | z3 |
| SHA-256's `Word_Sequences.Word_Bits.Bit`, `HMAC.Byte_Words.Word_Bits.Bit` (`Words`) | `x @ j` | `[32]`, `[8]` | | z3 |
| SHA-256's `Word_Sequences.Join`, `.Split_At`; `HMAC.Byte_Words.Join` (`Join_Split`) | `join`, `split` | `[8][32]`; 512 and 1024 bits (with `SAW_LONG=1` also 1536, 2048), `Split_At` at each word index, as `Parse_Block` calls it (one `RESULTS` line per length; with the index symbolic the proof reached the 10G cap); keys of 0, 32, 64, 65, 100 bytes | `Value` at 32 for `Split_At` | z3 |
| `HMAC.Byte_Sequences.Repeat` (`Sequences`) | `repeat` | `[64][8]` | | z3 |

The recursions `Folds.Foldl_Take`, `Enumeration_Folds.Foldl` and
`Polynomial_Products.Products` are proved in the tables above, against
`foldl` and `pmult`. `Join_Split.Value`, the conversion from bits to a
word, is not a Cryptol built-in: it is proved per bit count for SHA-256
(`Word_Of`, above) and executed within `Split_At`'s proofs for AES.

**Measured** (`results.txt`, the default run at `82b10e6` on an x86_64
Linux instance, 2026-10-23): 1808 proofs of the spec
layer, 1141 of AES (768 of them the exhaustive `Pgcd`, `Inverse` and
`Affine`, recorded as three `RESULTS 256` lines; 108 the cipher folds'
lemmas, `Foldl_Take` at N = 0 .. M for M = 9, 11, 13 and each of the three
rounds; 27 the prelude's instances on their own) and 667 of SHA-256 and
HMAC (419 of them in the lax-arithmetic load; 95 the prelude's
instances, 48 of them `Split_At` index by index), with 12 negative
controls of the spec layer failing as they must. `aes_spec.saw` takes
648 s (226 s of it the prelude's `@@` on a symbolic table),
`sha256_spec.saw` 1385 s (most of it `Word_Of`), the whole
`check-saw.sh` 2749 s. Before the linear recursions were unfolded
(`5bf56ac`): 2800 proofs of the spec layer (AES 1137, SHA-256 and HMAC
1663, most of the difference the 975 `To_Bits` lemmas, now 15 unfolded
proofs), 3543 s; the same scripts at `6023e8a`, re-run on 2026-10-23,
3686 s. Before the Cryptol prelude and the `AES_K` instances (at
`d874133`): 2742; peak memory then 3.8 GB. `SAW_LONG=1`
(`results-long.txt`, at `82b10e6`): 2055 proofs of the spec layer (666
lax), `sha256_spec.saw` 4899 s, the whole 6257 s; before the unfolding
(at `babab6f`) 3582, 7819 s (before the prelude, at `c31472e`: 3522,
7784 s, peak 7.2 GB; below, "Running it").

**Why the spec layer costs about 76 times the implementation** (experiments
in `saw/experiments/issue-69/`): 31 times as many results, each 2.6 times
as long. Of the spec layer's time, 44% is lemmas proved again at another
secondary-stack base (an override matches only the stack state its
contract names, and SAW cannot name a symbolic one), 33% lemmas per
index of a recursion (`Word_Of` alone 23%, most of it the solver relating
one Boolean byte per bit to Cryptol's shift), 7% the exhaustive per-byte
proofs, and 2% the lemmas re-proved in the lax-arithmetic load. Measured
there too: unfolding the linear recursions (`Rounds.Foldl`, `To_Bits`)
is 10 to 30 times cheaper than their lemmas, and a constrained result, an
aggregate for a literal, and packed bits each remove a factor; and what
this says about checking a C-to-SPARK translation.

**Not proved by SAW**, and why:

- `SHA2.SHA256.Hash` at 120, 128 and 200 bytes (3 and 4 padded blocks)
  only with `SAW_LONG=1`: each `Word_Of` lemma, `First` symbolic, takes
  longer the longer the padded message (yices; z3 half again as long), and
  the 66 lemmas for 1536 and 2048 bits would make every run that much
  longer. `Pad` is proved at those lengths in every run.
- `SHA2.SHA256_Bytes` (`Hash_Bytes` and its helpers): not the spec layer,
  but a ghost representation change (bytes for bits) proved equal to it by
  gnatprove (`Lemma_Hash_Bytes`); not attempted, and not needed (below,
  "What SAW proves on its own, in place, or not at all").
- HMAC at (key, text) = (0, 0), (32, 32), (64, 3) and (100, 32) bytes
  only with `SAW_LONG=1`: each call of a hash is at a secondary-stack base
  of its own, and each base costs `Hash`'s lemma and those under it
  (`Pad`, `Zero`, `To_Bits`) again; the default run proves one length per case of
  `HMAC_init`. HMAC at other lengths, or λ < 256: not attempted.
- On their own: `Parse_Block`, `Join` and `Bit` (executed within
  `Hash`, and `Parse_Block` within `Parse`'s own results), GF2's `Inner`,
  `Inner_Step`, `Inner_Next`, `Sub_Mult`, `Term`, `Lead`, `Reduce` and
  `Bit` (within `Pgcd` and the folds; `Inner` and the rest are pgcd's
  locals, with no Cryptol name), `SBox.Reversed_Bit` and `Affine_Bit`,
  `KeyExpansion.Words`, and the `Is_*` predicates (contract helpers).
- The dispatchers of `AES.Spec.Dispatch`, which select an instance
  of `AES_K` by `K`: not in the Cryptol, and each is the instance's
  function at each `K`, which gnatprove proves of its postcondition.
- `Pgcd` and `Inverse` are proved at the modulus `SBoxPolynomial` only,
  the one `SBox.cry` and the spec's `Affine` pass.

#### The secondary stack

A spec function that returns an unconstrained array (`Reverse_Keys`,
`Pad`, `Zero`, `To_Bits`, `Parse`, `Join`,
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
are proved for every byte. So are `Main`'s
`prop_Encrypt*`/`prop_Decrypt*` (every key and block at each key
size), and HMAC's spec properties (`prop_HMAC_*`, `prop_HMAC_init`) at
the (key, text) lengths proved, which overlap theirs only in part. So is
`prop_parse` at N = 1 and 2 blocks (3 and 4 with
`SAW_LONG=1`) of its N = 0 .. 8. Not backed: `prop_Hash_Bytes`.

### What SAW proves on its own, in place, or not at all

SAW's results are of particular subprograms at particular sizes. This
section says, for every subprogram that has no SAW result of its own, which
results execute its code (rather than replace a call to it with an
override), at which sizes, and why it has no result of its own (a campaign
decision of 2026-10-20). Each is proved by gnatprove for all
inputs and FFI-checked. The board's SAW column counts only results of a
row's own entities; this is what stands behind its `-`. A row whose spec
entity is a dispatcher of `AES.Spec.Dispatch` counts the results
of the instances `AES128`, `AES192` and `AES256` of the same name, one
per key size: the dispatcher is each instance's function at its `K`
(gnatprove), and SAW proves the instances.

**Why fixed sizes: what NSA's own proofs do.**

- **AES: the same as NSA's.** NSA's only implementation proofs in this
  repository are of Rust: `algorithms/AES/rust/Cipher/theorems/saw.py`
  proves `Cipher::cipher` against ``Cipher`{k}`` and `Cipher::inv_cipher`
  against ``InvCipher'`{k}``, and `KeyExpansion/theorems/saw.py` the key
  expansion against ``KeyExpansion`{k}``, each at k = 128, 192 and 256, one
  proof per key size. Ours are at the same three sizes (against
  ``InvCipher`{k}`` for `Decrypt_Block`). The only other implementation
  proof is `algorithms/Keccak/rust`'s, of the fixed-size permutation
  `Keccak_p`. The repository has no C.
- **SHA-256 and HMAC: NSA has no implementation proof to compare against.**
  There is no Rust or C for them. `algorithms/SHA2/theorems` proves
  properties of the Cryptol alone: `Preprocessing.saw` proves `padTest512`
  and `padTest1024`, `pad` on the single input "abc". The fixed lengths
  therefore come from SAW itself: it executes the code symbolically, so loop
  bounds and buffer sizes must be concrete, one proof per length. The
  lengths are chosen at the padding's boundaries (0; 55, the longest message
  whose padding fits one block; 56, the shortest that needs two; 63, 64 and
  65 around a whole block; 119 and 120, the same boundary in the second
  block; 128; 200, four blocks; 1 and 100 besides), and HMAC's keys at each
  case of `HMAC_init` (shorter than the block, the block, longer): "SHA-256
  and HMAC-SHA-256" above, and `saw/sha256_impl.saw`'s comments.
- **What SPARK adds**: gnatprove proves the same subprograms for every
  length (below).

**Implementation subprograms that nothing calls: left out.** Both are proved
by gnatprove for all inputs and FFI-checked:

- `AES.Impl.Decrypt_Block_Prime` and `Inv_Round_Prime`: FIPS 197's
  equivalent inverse cipher (``InvCipher'``). `Impl.Main.Decrypt` uses
  `Decrypt_Block`, and no other subprogram calls these; the
  implementation's SAW proofs cover only `KeyExpansion`, `Cipher` and
  `InvCipher`. SAW does prove the spec
  layer's `InvCipher_Prime` (of the instances `AES<k>`) and `Cipher.InvRound_Prime`
  against ``InvCipher'`` and `InvRound'`.
- `AES.Impl.Dot`: general GF(2^8) multiplication. The ciphers use `X_Times`
  (`foundation_spark-aes-impl.ads`), so only the FFI export calls `Dot`.
  SAW proves the spec layer's `GF28.Dot` against `(•)`.

**Implementation subprograms that SAW checks in place, not on their own**
(`saw/sha256_impl.saw`, `saw/aes_impl.saw`):

| subprogram | executed within | at | why not on its own |
|---|---|---|---|
| `SHA256_Stream.Init`, `Update`, `Final`, `Load_Block`, `To_Digest` | every `SHA256_Stream.Hash` result (`Hash` is `Init`, one `Update`, `Final`; `Compress` is the only override) | 12 message lengths: 0, 1, 55, 56, 63, 64, 65, 100, 119, 120, 128, 200 bytes (every run) | `Update` and `Final` would need a contract over the streaming context (buffer, count, chaining state) and its invariant, and SAW would still prove them only at fixed fill levels and data lengths; `Load_Block` and `To_Digest` take arrays and offsets that differ from call to call, so one contract would not serve as their override |
| the same, and `Init_Key`, `Xor_Pad`, and HMAC's incremental `Init`, `Update`, `Final` | every `HMAC_SHA256` result (`HMAC_SHA256` is `Init`, one `Update`, `Final`; `Compress` is the override, and at keys of 65 and 100 bytes so is `SHA256_Stream.Hash` at that length, for `Init_Key`'s call) | 7 (key, text) pairs: (0, 0), (32, 3), (32, 32), (64, 3), (64, 32), (65, 3), (100, 32) bytes (every run) | the incremental interface is the same function as the one-shot `HMAC_SHA256`, which SAW proves; on its own it needs a contract over two streaming contexts, as above |
| `SHA256_Stream.Hash_Chunked` | none | | its claim is the digest for every way of splitting the message into chunks; SAW can only check particular splits |
| `AES.Impl.Sub_Word`, `Rot_Word`, `Xor_Word`, `Rcon` | `Expand_Key`'s results (llvm-gcc inlines them, even at `-O0`) | k = 128, 192, 256 | `alwaysinline` expression functions: `Expand_Key` makes no call to them, so no proof of them could be its override |
| `AES.Impl.Main.Encrypt`, `Decrypt` | none | | a byte-level composition of `Expand_Key` with `Encrypt_Block` or `Decrypt_Block`, each SAW-proved at k = 128, 192, 256. The FFI checks them against `Main.cry`'s `Encrypt` and `Decrypt` |

**Spec-layer subprograms that SAW executes, not proves on their own**
(`saw/sha256_spec_hash.saw`, `sha256_spec_hmac.saw`, `aes_spec_gf.saw`):

| subprogram | executed within | at |
|---|---|---|
| `SHA2.SHA256.Parse_Block`, `Join`, `Bit` (and `Parse`, which has results of its own too) | every spec `Hash` result (`Pad`, `Word_Of` and `Foldl_Step` are overrides; these, which do not recurse, are executed); `Parse_Block` also within each `Parse` result | 0, 1, 55, 56, 63, 64, 65, 100, 119 bytes; also 120, 128, 200 with `SAW_LONG=1`; and each `Hash` lemma at the secondary-stack bases where HMAC calls it |
| `Ceil_Div`, `Ceil_Mod` | `Small_K` | each length |
| `HMAC.Join`, `Repeat`, `Zero`, `Byte_Bit`; the instance's `Opad`, `Ipad` | the `HMAC_init` and `HMAC` results | (32, 3), (64, 32), (65, 3); all seven pairs with `SAW_LONG=1` |
| GF2's `Inner`, `Inner_Step`, `Inner_Next`, `Sub_Mult`, `Term`, `Lead`, `Reduce`, `Bit` | `Pgcd` and the folds | every byte (pgcd's locals; no Cryptol name) |
| `SBox.Reversed_Bit`, `Affine_Bit` | `Affine` | every byte |
| `KeyExpansion.Words`, the `Is_*` predicates | contracts only | |

`Parse` has results of its own: ``parse`{32, N}`` at
N = 1 and 2 blocks (3 and 4 with `SAW_LONG=1`), the padded lengths
`Hash` is proved at, with `Word_Of`'s lemma at 32 as the override. `Hash`
still executes it rather than take those results as overrides: there its
message is `Pad`'s result on the secondary stack, above `Pad`'s
temporaries, not an argument of its own, and a `Parse` lemma would be
needed at that stack base for each length.

**Why there is no SAW proof of `hash` over bytes.**
`SHA256_Bytes.Hash_Bytes` is not a Cryptol declaration: it is the spec's
`Hash` on the bits of a byte array, proved equal to it by gnatprove
(`Lemma_Hash_Bytes`). The end-to-end claim a SAW proof of it would carry,
`SHA256_Stream.Hash` on bytes = Cryptol `hash`, is already a SAW result of
the implementation layer, at 12 lengths. A SAW proof of `Hash_Bytes` would
sit between two things already joined.

**Where the SPARK argument is stronger.** Not to criticize SAW, but to show
what SPARK adds:

- **Every length, not fixed lengths.** gnatprove proves `Hash`, `HMAC`,
  `Pad` and `Parse` for every message and key length (below 2 ** 61 bytes;
  HMAC's text below `Max_Text`). SAW proves the implementation's `Hash` at
  12 lengths and `HMAC_SHA256` at 7 (key, text) pairs; the spec layer's
  `Hash` at 9 lengths and `HMAC` at 3 pairs in the default run (12 and 7
  with `SAW_LONG=1`).
- **Every chunking and every call sequence.** `Hash_Chunked`, and the
  streaming and incremental interfaces through `Lemma_Update` and
  `Lemma_Final`, are proved for all inputs, which SAW cannot state.
- **Absence of run-time errors in the lax-arithmetic results.** In the
  default run, 24 implementation-layer results (the 4 top-level ones:
  `Hash` at 0, 64 and 128 bytes and `HMAC_SHA256` at (0, 0); and the 19
  leaves and `Compress` re-proved in that module as their overrides) and
  1396 spec-layer results (2178 under `SAW_LONG=1`) are proved in the
  module loaded with lax arithmetic. There, absence of overflow rests on
  gnatprove (AoRTE), not on SAW.
- **The subprograms SAW leaves out** (above): gnatprove covers them.
- **What SAW adds, to keep this fair.** It checks the bitcode GNAT-LLVM
  actually emits against NSA's own Cryptol, with no SPARK spec layer in
  between. For the implementation layer, that removes the spec layer from
  the trusted base.

### Running it

There is **no `llvm_unsafe_assume_spec`**: every override is a proof in
the same module, and `check-saw.sh` refuses to run if a script under
`saw/` contains one. Nor is there an **`admit`** (or its older names
`assume_unsat` and `assume_valid`), the tactic that closes a goal without
a solver: `check-saw.sh` refuses the word anywhere in those scripts,
comments included. The one exception is `saw/experiments/`: scratch
measurements that no recorded run loads, outside the record, which
may use `admit` on purpose (to time symbolic execution alone). `board.py`
does not count a change there as a change to SAW's inputs either.

```console
$ GNAT_LLVM_DIR=<dir> LLVM_LINK_DIR=<dir> scripts/check-saw.sh   # GNAT Pro's LLVM back end (bin/llvm-gcc); llvm-link 21.1.8
$ scripts/check-saw.sh --print      # run, print the record, write nothing
$ SAW_LONG=1 scripts/check-saw.sh   # also the long proofs; writes saw/results-long.txt
$ SAW_LAYERS=impl scripts/check-saw.sh --print   # one layer only (impl or spec)
```

`SAW_LAYERS=impl` compiles and proves the implementation modules alone,
with the negative controls not named `spec_*`; `SAW_LAYERS=spec` the spec
layer alone, with the `spec_*` controls. A one-layer run is never a
record: the script requires `--print` with it, and prints its
`layers` line.

**What the default run proves, and `SAW_LONG`.** The default run (2749 s
on an x86_64 Linux instance, `results.txt`) proves everything above but `Hash`
at 120, 128 and 200 bytes and HMAC at (key, text) = (0, 0), (32, 32),
(64, 3) and (100, 32) bytes; `SAW_LONG=1` (6257 s) adds those (`Word_Of`'s
lemmas for 1536 and 2048 bits, `Foldl_Step` at 3 and 4 blocks, the
prelude's `Split_At` at those lengths, and four more HMAC lengths
with their hashes' lemmas at their stack bases) and records the run in
`saw/results-long.txt`. Each record's `options` line says which it was.

**Local only, never CI** (a campaign decision of 2026-10-19). The bitcode comes from
**GNAT Pro 27's LLVM back end** (`$GNAT_LLVM_DIR/bin/llvm-gcc`), which CI
does not have and nobody without GNAT Pro can install. It is used for
nothing else: the crate's toolchain, its gates and CI stay FSF GNAT 16.1.
`check-saw.sh` fails at once, saying so, when `GNAT_LLVM_DIR` is unset. On
an x86_64 Linux instance the bootstrap's `gnat-llvm` phase checks
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
version. The bootstrap's `gnat-llvm` phase, when `GNAT_LLVM_DIR` is
set, uses an `llvm-link` 21.1.8 that is present (in `LLVM_LINK_DIR`, or
on `PATH` in a `bin/` directory), and otherwise fetches the 2 GB tarball,
checks its sha256, and extracts `bin/llvm-link` alone (it is statically
linked against LLVM) to `llvm-21.1.8` under the bootstrap's tools
directory (`FOUNDATION_TOOLS`). Either way it
writes `LLVM_LINK_DIR` to `env.sh`.

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
   bitcode.
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
3. The spec layer: for each spec module, `aes_spec` and
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
     complemented); `spec_sha256_parse_reversed` (`Parse` at 1 block, on
     `Word_Of`'s lemmas, against `parse` of the bits reversed).
     (The leaf control was first `ShiftRows` against
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

What `llvm-gcc -O0` makes of `AES.Impl`, which the AES proofs build on:

- **Symbols** are GNAT's external names, unchanged: the expanded name in
  lower case, `.` as `__`: `Foundation_Spark.AES.Impl.X_Times` is
  `foundation_spark__aes__impl__x_times`. No `Export` or `Convention => C`
  is needed (or wanted: the proof is of the crate's own code). A
  subprogram local to the body (`Inv_Mix_Byte`) is `internal` but
  verifiable by the same name. Overloading would add a `__<n>` suffix;
  `AES.Impl` has none.
- **Scalars**: `Byte` is `i8`, `Key_Size` (the key size `K`, a subtype of `Natural`) is `i32`.
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
  pointer and bounds types are merged into one each, named after the
  first the linker met: the bounds `..._spec__types__round_keys_BOUNDS`,
  which the contracts name, and the fat pointer, named after another
  unconstrained array type of the two units, which they do not.
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
  The proofs link them (`llvm-link`, above) rather than assume them
  with `llvm_unsafe_assume_spec`, so `Nk`, `Nr`, `Split` and `Join` are
  proved in the linked module and are overrides like any other.
- **Expression functions of `AES.Impl` itself** (`Sub_Word`, `Rot_Word`,
  `Xor_Word`, `Rcon`) are `alwaysinline` and inlined into their callers
  by llvm-gcc even at `-O0` (the inlined blocks are named
  `..._xor_word.exit` and so on). `Expand_Key` calls none of them: it
  calls `Sub_Byte`, `Nk` and `Nr`.

What `llvm-gcc -O0` makes of the SHA-256 and HMAC units:

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

What the spec layer's build (`-fno-inline`, ghost code on)
adds:

- **Ghost symbols are GNAT's external names, unchanged.** GNAT-LLVM 27
  links ghost entities under their plain names:
  `Foundation_Spark.AES.Spec.GF28.Dot` is
  `foundation_spark__aes__spec__gf28__dot`, and even a ghost `Export` with
  `External_Name => "spark_xTimes"` is `spark_xTimes` (checked with
  `llvm-nm` on the FFI shim `Foundation_Spark.FFI.AES_GF28`). FSF GNAT
  16.1, which builds the FFI library, links them under `___ghost_`
  followed by the name ([ffi.md](ffi.md)); the SAW scripts name the
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
  is a 128-bit integer type (its domain needs it); AES's is
  `range 0 .. 256` (`Object_Size` 16). Unconstrained, they are fat
  pointers `{ ptr, ptr }` whose bounds record is two of the index type
  (`..._bits_BOUNDS`): SHA-2's `{ i128, i128 }`, AES's `{ i16, i16 }`, so
  AES's `Byte_At (Bs, From)` is `i8 ({ ptr, ptr } %bs, i16 %from)` (read
  from GNAT-LLVM 27's IR, 2026-10-21: `%..._main__bits_BOUNDS = type
  { i16, i16 }`). The contracts take
  n bytes under the precondition that each is 0 or 1 (an Ada Boolean's
  validity) and read them as Cryptol bits (`[ b == 1 | b <- bs ]`).
  `Block_Bits` (`Bits (0 .. 127)`, constrained) is passed by reference and
  returned through a hidden first pointer. **SAW 1.6 cannot translate a
  `getelementptr` with an index wider than 64 bits** (crucible-llvm's
  `calcGEP_array`, at 2026-10-16, takes an index of exactly the pointer's
  width or narrower, and no GNAT switch avoids the wide one). GNAT-LLVM
  emits one where a constrained array of a 128-bit index type is indexed
  directly; indexing through a fat pointer goes through an `i64` offset
  and is fine. AES's `Bit_Index` is narrow (`range 0 .. 256`, above), so
  AES has no such index; `check-saw.sh` refuses a linked spec module with
  an `i128` GEP index, by name, before SAW would (it disassembles with
  `llvm-link -S`; on a 128-bit-indexed constrained array its pattern
  finds the two `getelementptr ..., i128 %n`). Read from GNAT-LLVM 27's
  IR on 2026-10-21, the linked AES spec module has no `i128` GEP index:
  163 are `i64` (every index through a fat pointer, sign-extended), 374
  `i32` (record fields), and 5 `i16` (a byte, zero-extended, indexing a
  256-entry S-box table). `Join_Block` indexes nothing itself:
  it calls the prelude's `Byte_Bits.Join`, which returns on the secondary
  stack, and copies the 128 bits out (`memcpy`).
- **Unconstrained results** are on the secondary stack: `SS_Allocate`'s
  block holds the bounds record, then the data (`Reverse_Keys`'
  `Round_Keys`: `{ i32, i32 }` at 0, the blocks at 8; a `SHA2.Bits`:
  `{ i128, i128 }` at 0, the bits at 32), and the function returns the fat
  pointer `{ data, bounds }`. Sizes are rounded up to 16 bytes. An empty
  `Bits` aggregate (`To_Bits (V, 0)`) is the bounds `{0, -1}` alone. A
  function that calls others which allocate (`InvCipher`) marks the stack
  and releases it on exit, through a finalizer called on every path (and
  an `invoke` of each call, which SAW translates). The
  `KeyExpansion` and `Split_Key` of the instances of `AES_K` return
  their constrained subtypes, by value
  (16 bytes or less) or through a hidden first pointer, which the
  contracts assume and the next SAW session confirms.
- **Slices' bounds** (`W (1 .. Nr (K) - 1)`, and each fold's rest) are
  built in a stack temporary of the caller, writable and 1-byte aligned
  (`alloca ..., align 1`): the fold lemmas' bounds are allocated so, and a
  slice's data pointer points into its array (an interior pointer, which
  an override's allocation matches).
