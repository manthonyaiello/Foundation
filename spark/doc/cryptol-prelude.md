# The Cryptol prelude in SPARK

The Cryptol built-ins the spec layers are written in (`foldl`, `@`,
`join`, `split`, `pmult`, ...), stated once in SPARK as ghost generics.
Back to the [README](../README.md).

## The Cryptol prelude

`src/cryptol/` (`Foundation_Spark.Cryptol`, #75) states, once and under
their Cryptol names, the Cryptol built-ins the spec layers are written in.
A spec unit instantiates a generic at its own types and calls the instance
where the Cryptol calls the built-in, so a reviewer checks each
translation from Cryptol to SPARK here, once, and the spec bodies are left
with the algorithm. Every unit is ghost, `Pure` and generic over the index,
element and array types it works on: AES's narrow bit index and SHA-2's
128-bit one both instantiate it, and AES's bytes stay `Unsigned_8`.

| generic | Cryptol | stated from |
|---|---|---|
| `Folds` (`Foldl`, `Foldl_Take`) | `foldl f z xs`, ``foldl f z (take`{N} xs)`` | Cryptol.cry:1146 (a primitive) and its example `((0 + 1) + 2) + 3` |
| `Enumeration_Folds` | `foldl f z [From ..< To]`, f closing over a value | the same, and RefMan BasicTypes.rst:169 |
| `Words` (`Bit`, `Head`) | `x @ j`, `head x` on a word `[w]` | Cryptol.cry:900 (a primitive), :796 (bit order), :855 (head's body) |
| `Join_Split` (`Join`, `Split_At`, `Value`) | `join`, `split` between `[n][w]` and `[n * w]` | Cryptol.cry:815 and :822 (primitives, documented as inverses) |
| `Bit_Sequences` (`Zero`, `Literal`) | `zero : [n]`, `` `v : [n] `` | Cryptol.cry:304 (a primitive), RefMan BasicSyntax.rst:349 |
| `Sequences` (`Reverse_Of`, `Repeat`) | `reverse`, `repeat` | Cryptol.cry:828 (a primitive), :1215 (repeat's body) |
| `Bulk_Indexing` (`Bulk_Index`) | `xs @@ is` | Cryptol.cry:906 (its body) |
| `Numeric` (`Ceil_Div`, `Ceil_Mod`) | the type operators `/^`, `%^` | Cryptol.cry:135 and :141 (primitives) |
| `Polynomial_Products` (`Pmult`) | `pmult` | Cryptol.cry:1005 (a primitive); RefMan BasicSyntax.rst:352 (a word as a polynomial) |
| `Polynomial_Remainders` (`Pmod`) | `pmod` | Cryptol.cry:1015 (a primitive) |
| `Polynomial_Quotients` (`Pdiv`) | `pdiv` | Cryptol.cry:1010 (a primitive) |

Line numbers are those of Cryptol 3.6.0's `lib/Cryptol.cry`. Most of these
are primitives, with a type and a comment but no Cryptol body, so they are
stated from their documented meaning. Three choices a reviewer should
know:

- **Folds recurse from the last element.** Cryptol does not define
  `foldl` by equations; its documented example, `foldl (+) 0 [1,2,3] =
  ((0 + 1) + 2) + 3`, applies the function last to the last element, and
  that is the recursion here: ``foldl f z (take`{N} xs) = f (foldl f z
  (take`{N - 1} xs)) (xs @ (N - 1))``. It is also the shape of the
  implementation's loops, whose invariant after N steps is the fold of the
  first N, so the step is the definition. A version recursing from the
  head, with this equation as a postcondition, did not prove at level 2,
  and where it was assumed, SHA-2's lemmas lost proofs: a postcondition
  gives array `=`, where a definition gives the provers' logical equality.
- **Closures are explicit.** A Cryptol fold's function may mention local
  values (SHA-2's `step3` mentions the block). Ada's generic formal
  functions are not closures, so `Enumeration_Folds` passes the value as
  the function's first argument.
- **Words are numbers.** In Cryptol a word is its bits; here a fixed-width
  word is a modular number (the campaign's fixed-width-word decision), so
  `Words.Bit` reads bit `j` as the bit of weight `2 ** (w - 1 - j)`, and
  `Join_Split.Value` is the conversion from bits to a word that Cryptol
  needs no name for. The polynomial generics read a word as a polynomial
  the same way, bit of weight `2 ** i` the coefficient of `x ^^ i`.

**Who uses it.** SHA-2 (`foldl` twice, `@`, `join`, `split`, `zero`, the
literal of `pad`, `/^` and `%^`) and HMAC (`repeat`, `zero`, `@` and
`join` on bytes), with nothing of either left inline. The last four
statements moved in #75's remainder, once the cause of the lost proofs
was measured from the provers' own goals (`--debug-save-vcs`):
- `/^` and `%^` (`SHA2.Lengths`, `Numeric`). They had been tried as
  wrappers, `SHA2.Ceil_Div` with the body `Lengths.Ceil_Div (A, B)`. The
  goal of `SHA256_Bytes.Lemma_Pad_Bytes_Bits`' assertion on the message's
  bytes then differs from the inline one in exactly one thing: one more
  definition between `k` and its arithmetic. That layer alone took CVC5
  from 3831 steps (2.5 s) to 52939 (98 s). With `Main` calling the
  instance directly, the goal is the inline one again (3831 steps), so
  there is no wrapper.
- `@` and `join` on bytes (`HMAC.Byte_Words`, `Join_Split` at `[8]`).
  `HMAC.SHA256_Impl.Lemma_Update`'s call of `SHA256_Stream.Lemma_Update`
  needs `Inner_Prefix (Key, M2)` to begin with `Inner_Prefix (Key, M)`.
  Its context holds `Init_Key`'s postcondition, and so `HMAC_init`'s
  `join`. Through the instance, that context has the generic `Join`'s
  postcondition (`'Last = K'Length * 8 - 1`, guarded by its
  precondition) where the inline `Join` had an unguarded `'Length = 8 *
  K'Length`. The level-2 provers did not prove that conjunct in 60 s.
  With `HMAC.Join` a renaming of the instance's, so with no wrapper, it
  still failed at the gate's 10 s, and also with the generic's
  precondition removed, or with its postcondition stated as a `'Length`.
  With both changes it proved (Z3, 4023 steps; inline, 4191). The prelude is left as it is:
  `SHA256_Impl.Lemma_Prefix_Extends` states the prefix reasoning apart
  from `Init_Key`, where it proves at once.

The FFI shim calls these instances (`SHA2.Lengths`, `HMAC.Byte_Words`).

AES since #75's second half: `foldl` (`Spec.Cipher`'s three round folds,
`Folds`; GF28MultiplicationCorrect's fold over a byte's bits,
`Enumeration_Folds`), `@@` (SubBytes, ShiftRows and their inverses,
`Bulk_Indexing`), `join` and `split` between bytes and bits (`Spec.Main`'s
`Join_Block`, `Split_Block`, `Byte_At`, `Bit_Of`, and `AES_K.Split_Key`,
`Join_Split` at `[8]`), `@` and `head` on words (GF28's `Bit`, `Head`,
`Product_Bit`, GF2's `Bit`, `Words`), `pmult` (GF28 at `[8] x [8]`,
`Polynomial_Products`), and `reverse` (`Cipher.Reverse_Keys`,
`Sequences` over round keys). `reverse` had stayed written out because
#85 measured `AES.Impl.Decrypt_Block_Prime`'s assertion `RK (J) = W (Nr
(K) - J)` timing out at level 2 through the instance. That does not
reproduce: through the instance the assertion proves with Z3 in 396
steps (0.15 s), on this tree and on #85's own before its rebase (its
spec with `AES.Impl` as it was before #84), and the gate proves. Four
stay written out, each for a measured reason (not re-measured in #75's
remainder):
- `pmod` (GF28's `Pmod_Fold`, `Pmod`): GF28 returns the remainder as a
  `Byte`, and its bound below `2 ** 8` is an induction no expression
  function can call; GF28's `Pmod` also takes any `Poly` dividend;
- `pmult` at `[9] x [9]` (GF2's `Pmult`, a closed form): GF2 proves with
  the prelude's, but the slow `SBox_Entries`, which evaluates it on
  constants, ran past 77 minutes at -j6 with 9 of its 32 subprograms
  done, against about 26 minutes for the whole unit;
- `pdiv` (GF2's `Pdiv`): with the prelude's, `Inner_Step`'s postcondition
  does not prove at level 4 (it rests on `Pdiv_Fold`'s, which reduces by
  the divisor's leading term, not by the prelude's `Top`);
- `split`/`join` between a block and its columns (`Types.Split`, `Join`):
  not in the prelude (which is between words and bits), and `Types` is
  not ghost, so it cannot call the prelude.

The prelude's folds recurse from the last element and AES's recursed
from the first, so the lemmas that unfolded them induct from the last
step now; `AES.Lemmas.Lemma_Foldl_*_Take_Eq` state that a fold's first N
steps depend only on the first N elements, which a fold over a slice
needs.

**How it is checked.** gnatprove proves each instance where it is
instantiated. `spark/cryptol/SPARK/Prelude.cry` checks each generic
against Cryptol's built-in through the FFI (`FFI.Prelude`), through the
spec layers' own instances where there are some: 22 properties, `:exhaust`
where the domain allows. A fold takes a function, which C cannot pass, so
the shims fold fixed ones whose result depends on the order of the
elements. The spec-layer SAW proofs go through its instances (their
lemmas name the instances' recursions), and since #75's item 3 SAW also
proves each instance the spec layers call on its own, at the sizes they
call it at, against the Cryptol built-in it states (`saw/aes_spec_prelude.saw`,
`saw/sha256_spec_prelude.saw`; [saw.md, "The spec layer"](saw.md#the-spec-layer)).
