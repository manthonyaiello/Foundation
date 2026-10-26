# AES: the SPARK spec layer beside NSA's Cryptol

This page walks through the SPARK proof of AES (FIPS 197) next to the
Cryptol it is proved against. Every excerpt is copied from the files at
commit `6210b99`, with its path and line range.

NSA's Cryptol for AES is in [`algorithms/AES/`](../../../algorithms/AES/),
unmodified. The SPARK is in [`spark/src/aes/`](../../src/aes/), in three
parts:

- **The spec layer** (`Foundation_Spark.AES.Spec.*`) is ghost SPARK that
  mirrors the Cryptol declaration by declaration: same names, same types,
  same structure of iteration. It exists for proof and testing only, and
  is compiled only when ghost code is enabled, as in the FFI build
  ([`foundation_spark-aes-spec.ads:5-7`](../../src/aes/foundation_spark-aes-spec.ads#L5-L7)).
- **The implementation layer** (`AES.Impl`, `AES.Impl.Main`) is ordinary
  executable SPARK: loops, in-place updates, a constant-time S-box. Each
  subprogram's postcondition says that its result equals the spec-layer
  function it implements.
- **Between them** are ghost units that are not in the Cryptol: the lemma
  units `AES.Lemmas` and `AES.Main_Lemmas`, and `AES.Spec.Dispatch`, which
  lets one implementation, with the key size as a run-time parameter,
  name the spec at each of the three key sizes.

How each link is checked:

```text
                 NSA's Cryptol: algorithms/AES/*.cry
                  ^                              ^
   FFI check      |                              |  SAW (llvm_verify),
   (testing:      |                              |  proof at k = 128,
   random or      |                              |  192 and 256
   exhaustive)    |                              |
     spec layer: AES.Spec.*  --------------------+  spec bitcode = Cryptol
          ^       |                              |
          |       +-- executables tested too     +- impl bitcode = Cryptol
          |
          |  gnatprove: impl = spec, all inputs, all key sizes
          |  (with AES.Lemmas, AES.Main_Lemmas, AES.Spec.Dispatch)
          |
     implementation layer: AES.Impl, AES.Impl.Main
```

- **gnatprove** proves the implementation equal to the spec layer, for
  every input and every key size.
- **The FFI check** exports the spec functions (and the executable ones)
  through C, calls them from Cryptol with `foreign`, and compares them
  with NSA's functions by `:exhaust` (every input) or `:check` (random
  inputs). It is testing, except where the domain is small enough to
  exhaust.
- **SAW** proves the LLVM bitcode of the implementation, and separately
  that of the spec layer, equal to NSA's Cryptol, at each key size. AES
  has only three key sizes, so for the functions SAW covers this is a
  proof for all inputs.

## Reading the notation

Cryptol:

- `[8]` is an 8-bit word; `[16][8]` is 16 bytes. Bit 0 of a word is its
  most significant bit.
- `xs @ i` reads element `i`, counting from 0; `xs @@ is` reads the
  elements at each index in `is`.
- `a # b` concatenates; as a pattern, `[w0] # ws # [wr]` splits a
  sequence into first, middle and last. `^` is exclusive or.
- `split` and `join` regroup a sequence (`[128]` to `[16][8]` and back).
  `reverse` reverses a sequence.
- `foldl f z xs` applies `f` to an accumulator and each element in turn,
  from the first.
- `{k} (Key k) => ...` is polymorphic in a type-level number `k` under a
  constraint; ``AES`{128}`` applies it at `k = 128`.
- `where` introduces local definitions.
- `<| x^^8 + x^^4 + x^^3 + x + 1 |>` is a polynomial over GF(2) written
  as a bit vector. `pmult` and `pmod` multiply and reduce such
  polynomials; they are Cryptol primitives, with no Cryptol body.

SPARK (Ada):

- `with Ghost` marks code that exists only for proof.
- An expression function `function F (X : T) return R is (expr)` is a
  function whose body is one expression, visible to the prover.
- `[for I in R => ...]` and `[A, B, C]` are array aggregates.
- `Pre` and `Post` are the precondition and postcondition; `F'Result` is
  the function's result in `Post`, and `X'Old` the value of `X` on entry.
- `Subprogram_Variant => (Decreases => N)` is a recursive function's
  termination argument: `N` decreases at every recursive call.
- A generic package is a template instantiated with `is new`, as in
  `package P is new G (K => 128)`.

## The spec layer, declaration by declaration

There is one spec child per Cryptol module, plus `GF2` for the
polynomial helpers that `SBox.cry` imports, and the generic `AES_K` for
every declaration with a `{k}`.

### Types (`Types.cry`)

<table>
<tr><th>Cryptol: <a href="../../../algorithms/AES/Types.cry#L12"><code>algorithms/AES/Types.cry:12</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-types.ads#L87-L88"><code>spark/src/aes/foundation_spark-aes-spec-types.ads:87-88</code></a></th></tr>
<tr><td>

```cryptol
type constraint Key k = (fin k, k % 64 == 0, k / 64 >= 2, k / 64 <= 4)
```

</td><td>

```ada
   subtype Key_Size is Natural
   with Static_Predicate => Key_Size in 128 | 192 | 256;
```

</td></tr>
</table>

The constraint becomes a subtype. It lists the three values instead of
the Cryptol's clauses because it must be a static predicate, which
cannot use `mod`, and only a static subtype gives the generic `AES_K`
static bounds
([`foundation_spark-aes-spec-types.ads:28-33`](../../src/aes/foundation_spark-aes-spec-types.ads#L28-L33)).
The ghost lemma `Dispatch.Lemma_Key_Size` proves the list equal to the
clauses
([`foundation_spark-aes-spec-dispatch.ads:38-42`](../../src/aes/foundation_spark-aes-spec-dispatch.ads#L38-L42)).

A Cryptol `[8]` is a `Byte` (`Interfaces.Unsigned_8`), and Cryptol's bit
0 is its most significant bit
([`foundation_spark-aes-spec-types.ads:48-50`](../../src/aes/foundation_spark-aes-spec-types.ads#L48-L50)).
Arrays are indexed from 0, as Cryptol's `@` is. The rest of `Types`:

| Cryptol (`algorithms/AES/Types.cry`) | SPARK (`foundation_spark-aes-spec-types.ads`) | note |
|---|---|---|
| `type Block = [16][8]`, [18](../../../algorithms/AES/Types.cry#L18) | `Block`, [59](../../src/aes/foundation_spark-aes-spec-types.ads#L59) | `array (0 .. 15) of Byte` |
| `type AESWord = [4][8]`, [25](../../../algorithms/AES/Types.cry#L25) | `AESWord`, [66](../../src/aes/foundation_spark-aes-spec-types.ads#L66) | `array (0 .. 3) of Byte` |
| `type Nk k = k / 32`, [32](../../../algorithms/AES/Types.cry#L32) | `Nk`, [98-100](../../src/aes/foundation_spark-aes-spec-types.ads#L98-L100) | a type function becomes a `Static` function |
| `type Nr k = Nk k + 6`, [39](../../../algorithms/AES/Types.cry#L39) | `Nr`, [108-110](../../src/aes/foundation_spark-aes-spec-types.ads#L108-L110) | as `Nk` |
| `[Nk k]AESWord`, `[Nr k + 1]Block` | `Key_Words`, `Round_Keys`, with `Is_Key_Words`, `Is_Round_Keys`, [125-147](../../src/aes/foundation_spark-aes-spec-types.ads#L125-L147) | unconstrained arrays for a run-time `k`; in `AES_K` they are constrained subtypes |
| `split`, `join` between `Block` and `[4]AESWord` | `Split`, `Join`, [74-82](../../src/aes/foundation_spark-aes-spec-types.ads#L74-L82) | |

`Types` is the only spec unit that is not ghost: the implementation uses
the same types.

### GF(2^8) (`GF28.cry`)

<table>
<tr><th>Cryptol: <a href="../../../algorithms/AES/GF28.cry#L12-L14"><code>algorithms/AES/GF28.cry:12-14</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-gf28.ads#L136-L141"><code>spark/src/aes/foundation_spark-aes-spec-gf28.ads:136-141</code></a></th></tr>
<tr><td>

```cryptol
(•) : [8] -> [8] -> [8]
(•) b c = pmod (pmult b c) m
  where m = <| x^^8 + x^^4 + x^^3 + x + 1 |>
```

</td><td>

```ada
   M : constant Poly := 16#11B#;
   --  GF28.cry, in (•): m = <| x^^8 + x^^4 + x^^3 + x + 1 |>, the AES
   --  polynomial [FIPS-PUB-197 Section 4.2].

   function Dot (B, C : Byte) return Byte
   is (Pmod (Pmult (B, C), M));
```

</td></tr>
</table>

Ada has no operator `•`, so it is `Dot`. `pmult` and `pmod` have no
Cryptol body, so the spec layer states them: `Pmult` is the prelude's
`Polynomial_Products` at `[8] x [8] -> [15]`, and `Pmod` is long
division, a recursive fold `Pmod_Fold` over the dividend's bits, most
significant first
([`foundation_spark-aes-spec-gf28.ads:77-131`](../../src/aes/foundation_spark-aes-spec-gf28.ads#L77-L131)).
`Pmod` is local to `GF28`, not the prelude's, because it returns a `Byte`
and takes any dividend; the unit's header gives the reasons
([`foundation_spark-aes-spec-gf28.ads:10-17`](../../src/aes/foundation_spark-aes-spec-gf28.ads#L10-L17)).

<table>
<tr><th>Cryptol: <a href="../../../algorithms/AES/GF28.cry#L21-L22"><code>algorithms/AES/GF28.cry:21-22</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-gf28.ads#L148-L149"><code>spark/src/aes/foundation_spark-aes-spec-gf28.ads:148-149</code></a></th></tr>
<tr><td>

```cryptol
xTimes : [8] -> [8]
xTimes b = b << 1 ^ (if head b then 0x1b else 0x00)
```

</td><td>

```ada
   function xTimes (B : Byte) return Byte
   is (Interfaces.Shift_Left (B, 1) xor (if Head (B) then 16#1b# else 16#00#));
```

</td></tr>
</table>

Token for token. `Head (B)` is the prelude's `head` on a `[8]`, the most
significant bit.

### GF(2) polynomials (`shared/algebra/Polynomial/GF2.cry`)

`SBox.cry` does not define the inverse in GF(2^8) itself. It imports it
from NSA's shared library:

<a href="../../../algorithms/AES/SBox.cry#L8"><code>algorithms/AES/SBox.cry:8</code></a>

```cryptol
import shared::algebra::Polynomial::GF2 (is_irreducible, inverse, (^*), (^%), (^^^))
```

`inverse` is in
[`shared/algebra/Polynomial/GF2.cry`](../../../shared/algebra/Polynomial/GF2.cry),
built on `pgcd`, the extended Euclidean algorithm. `AES.Spec.GF2` mirrors
the part of that module that `inverse` needs, at the types `SBox.cry`
uses: `a : [8]` and `p : [9]`, so `pgcd` works on `[9]` polynomials
([`foundation_spark-aes-spec-gf2.ads:1-5`](../../src/aes/foundation_spark-aes-spec-gf2.ads#L1-L5)).

<table>
<tr><th>Cryptol: <a href="../../../shared/algebra/Polynomial/GF2.cry#L135-L136"><code>shared/algebra/Polynomial/GF2.cry:135-136</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-gf2.ads#L260-L262"><code>spark/src/aes/foundation_spark-aes-spec-gf2.ads:260-262</code></a></th></tr>
<tr><td>

```cryptol
inverse : {u, v} (fin u, fin v) => [1 + u] -> [1 + v] -> [max u v]
inverse a p = tail (pgcd`{wb=v} a p @ 1)
```

</td><td>

```ada
   function Inverse (A : Byte; P : Poly) return Byte
   is (Byte (Pgcd (A, P) (1) and (2 ** 8 - 1)))
   with Pre => Is_Poly9 (P);
```

</td></tr>
</table>

The types are fixed at `u = 7`, `v = 8`. `tail` of the `[9]` Bezout
coefficient drops its top coefficient; the SPARK keeps the low eight
bits.

<table>
<tr><th>Cryptol: <a href="../../../shared/algebra/Polynomial/GF2.cry#L112-L117"><code>shared/algebra/Polynomial/GF2.cry:112-117</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-gf2.ads#L231-L236"><code>spark/src/aes/foundation_spark-aes-spec-gf2.ads:231-236</code></a></th></tr>
<tr><td>

```cryptol
    inner : State -> State
    inner [r, s, t, r', s', t'] =
        if r' == <| 0 |> then
          [r, s, t, r', s', t']
        else
          inner [r', s', t', r'', s'', t'']
```

</td><td>

```ada
   function Inner (S : Poly_State) return Poly_State
   is (if S (3) = 0 then S else Inner (Inner_Step (S)))
   with
     Pre                => Is_State (S),
     Post               => Is_State (Inner'Result),
     Subprogram_Variant => (Decreases => S (3));
```

</td></tr>
</table>

`inner` is local to `pgcd` in the Cryptol and top-level here. The state
`[r, s, t, r', s', t']` is an array indexed 0 to 5, so `r'` is `S (3)`.
The variant is `r'` itself: each step replaces it by a remainder of
smaller degree, as `Inner_Step`'s postcondition states
([`foundation_spark-aes-spec-gf2.ads:220-225`](../../src/aes/foundation_spark-aes-spec-gf2.ads#L220-L225)).
The rest of `GF2`, each at type `[9]`:

| Cryptol (`shared/algebra/Polynomial/GF2.cry`) | SPARK (`foundation_spark-aes-spec-gf2.ads`) | note |
|---|---|---|
| `pgcd`, [107](../../../shared/algebra/Polynomial/GF2.cry#L107) and [126-129](../../../shared/algebra/Polynomial/GF2.cry#L126-L129) | `Pgcd`, [246-252](../../src/aes/foundation_spark-aes-spec-gf2.ads#L246-L252) | the pattern `[g, u, v, _, b', a']` becomes indices 0, 1, 2, 5, 4 of `Inner`'s result |
| `(^*) = pmult`, [42-43](../../../shared/algebra/Polynomial/GF2.cry#L42-L43) | `Pmult`, [68-74](../../src/aes/foundation_spark-aes-spec-gf2.ads#L68-L74) | a primitive; stated as the sum of shifted copies of the second factor |
| `(^/) = pdiv`, [47-48](../../../shared/algebra/Polynomial/GF2.cry#L47-L48) | `Pdiv`, with `Pmod_Fold`, `Pdiv_Fold`, [132-176](../../src/aes/foundation_spark-aes-spec-gf2.ads#L132-L176) | a primitive; stated as long division over the dividend's bits |
| `pdeg`, [76-77](../../../shared/algebra/Polynomial/GF2.cry#L76-L77) | `Pdeg`, [81-92](../../src/aes/foundation_spark-aes-spec-gf2.ads#L81-L92) | the highest set bit, as a chain of comparisons |
| `type State = [6]Poly`, [110](../../../shared/algebra/Polynomial/GF2.cry#L110) | `Poly_State`, [196](../../src/aes/foundation_spark-aes-spec-gf2.ads#L196) | |
| `x ^. x' = drop (zext x ^ q ^* x')`, [121-122](../../../shared/algebra/Polynomial/GF2.cry#L121-L122) | `Sub_Mult`, [184-188](../../src/aes/foundation_spark-aes-spec-gf2.ads#L184-L188) | `drop` keeps the low nine coefficients |
| `q = r ^/ r'` and `zipWith (^.)`, [119-124](../../../shared/algebra/Polynomial/GF2.cry#L119-L124) | `Inner_Next`, `Inner_Step`, [206-225](../../src/aes/foundation_spark-aes-spec-gf2.ads#L206-L225) | |

Two choices depart from a literal use of the prelude, both explained in
the unit's header
([`foundation_spark-aes-spec-gf2.ads:15-26`](../../src/aes/foundation_spark-aes-spec-gf2.ads#L15-L26)):
`Pmult` is a closed form rather than the prelude's fold, because the fold
made the exhaustive S-box proof much slower; and `Pdiv` reduces by the
divisor's leading term, so that `Inner_Step`'s postcondition proves. SAW
checks both against Cryptol's `pmult` and `pdiv`.

### S-boxes (`SBox.cry`)

<table>
<tr><th>Cryptol: <a href="../../../algorithms/AES/SBox.cry#L44-L45"><code>algorithms/AES/SBox.cry:44-45</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-sbox.ads#L19-L21"><code>spark/src/aes/foundation_spark-aes-spec-sbox.ads:19-21</code></a></th></tr>
<tr><td>

```cryptol
SBox : [256][8]
SBox = [ 0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76
```

</td><td>

```ada
   SBox : constant Types.Byte_Table :=
     [16#63#, 16#7c#, 16#77#, 16#7b#, 16#f2#, 16#6b#, 16#6f#, 16#c5#,
      16#30#, 16#01#, 16#67#, 16#2b#, 16#fe#, 16#d7#, 16#ab#, 16#76#,
```

</td></tr>
</table>

The first 16 entries; the tables are the same entry for entry, and so is
`InvSBox`
([`SBox.cry:66-83`](../../../algorithms/AES/SBox.cry#L66-L83),
[`foundation_spark-aes-spec-sbox.ads:55-87`](../../src/aes/foundation_spark-aes-spec-sbox.ads#L55-L87)).
`Byte_Table` is indexed by `Byte`, so `SBox @ b` is `SBox (B)`.

<table>
<tr><th>Cryptol: <a href="../../../algorithms/AES/SBox.cry#L31-L36"><code>algorithms/AES/SBox.cry:31-36</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-sbox.ads#L104-L110"><code>spark/src/aes/foundation_spark-aes-spec-sbox.ads:104-110</code></a></th></tr>
<tr><td>

```cryptol
affine : [8] -> [8]
affine b = reverse b'
  where
    c    = reverse 0b01100011
    b_   = reverse (inverse b SBoxPolynomial)
    b'@i = b_@i ^ b_@((i+4) % 8) ^ b_@((i+5) % 8) ^ b_@((i+6) % 8) ^ b_@((i+7) % 8) ^ c@i
```

</td><td>

```ada
   function Affine_Bit (Inv : Types.Byte; I : GF28.Bit_Index) return Boolean
   is (Reversed_Bit (Inv, I)
       xor Reversed_Bit (Inv, (I + 4) mod 8)
       xor Reversed_Bit (Inv, (I + 5) mod 8)
       xor Reversed_Bit (Inv, (I + 6) mod 8)
       xor Reversed_Bit (Inv, (I + 7) mod 8)
       xor Reversed_Bit (16#63#, I));
```

</td></tr>
</table>

The Cryptol defines `b'` one bit at a time; `Affine_Bit` is that bit.
`Reversed_Bit (B, I)` is `(reverse b) @ i`, and `0b01100011` is
`16#63#`. `Affine`
([`foundation_spark-aes-spec-sbox.ads:118-134`](../../src/aes/foundation_spark-aes-spec-sbox.ads#L118-L134))
assembles the eight bits of `reverse b'`, with
`GF2.Inverse (B, SBoxPolynomial)` for `b_`. `SBoxPolynomial`
([`SBox.cry:11`](../../../algorithms/AES/SBox.cry#L11)) is the constant
`2#1_0001_1011#`
([`foundation_spark-aes-spec-sbox.ads:93`](../../src/aes/foundation_spark-aes-spec-sbox.ads#L93)).

### Key expansion (`KeyExpansion.cry`)

<table>
<tr><th>Cryptol: <a href="../../../algorithms/AES/KeyExpansion.cry#L16-L18"><code>algorithms/AES/KeyExpansion.cry:16-18</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-keyexpansion.ads#L27-L31"><code>spark/src/aes/foundation_spark-aes-spec-keyexpansion.ads:27-31</code></a></th></tr>
<tr><td>

```cryptol
Rcon : [11]AESWord
Rcon = [ undefined
       , [ 0x01, 0x00, 0x00, 0x00 ]
```

</td><td>

```ada
   subtype Rcon_Index is Natural range 1 .. 10;
   --  The indices of Rcon that KeyExpansion reads. KeyExpansion.cry's Rcon
   --  is a [11]AESWord whose element 0 is undefined. Here the table has no
   --  element 0, so a read of Rcon @ 0 is a failed index check that the
   --  proof rules out, where the Cryptol would raise undefined.
```

</td></tr>
</table>

A deviation, with its reason in the comment: the SPARK table has no
element 0. Elements 1 to 10 are the Cryptol's, entry for entry
([`foundation_spark-aes-spec-keyexpansion.ads:37-47`](../../src/aes/foundation_spark-aes-spec-keyexpansion.ads#L37-L47)).
`RotWord` and `SubWord`
([`KeyExpansion.cry:35-45`](../../../algorithms/AES/KeyExpansion.cry#L35-L45))
are aggregates over `A (0)` to `A (3)`
([`foundation_spark-aes-spec-keyexpansion.ads:52-61`](../../src/aes/foundation_spark-aes-spec-keyexpansion.ads#L52-L61)),
and Cryptol's `^` on words is an `"xor"` on `AESWord`
([`foundation_spark-aes-spec-keyexpansion.ads:19-20`](../../src/aes/foundation_spark-aes-spec-keyexpansion.ads#L19-L20)).

`KeyExpansion` has a `{k}`, so it is in the generic `AES_K`, whose formal
`K` is the Cryptol's `k`. Its local sequence `w` is defined in terms of
itself; in SPARK it is a recursive function `W`, one case per guard:

<table>
<tr><th>Cryptol: <a href="../../../algorithms/AES/KeyExpansion.cry#L51-L60"><code>algorithms/AES/KeyExpansion.cry:51-60</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-aes_k.ads#L59-L67"><code>spark/src/aes/foundation_spark-aes-spec-aes_k.ads:59-67</code></a></th></tr>
<tr><td>

```cryptol
foreign KeyExpansion : {k} (Key k) => [Nk k]AESWord -> [Nr k + 1]Block
KeyExpansion key = split (split (join (join w)))
  where
    Nk = `(Nk k)
    w  = [ if i < Nk                then key@i
            | i % Nk == 0           then w@(i - Nk) ^ SubWord (RotWord (w@(i - 1))) ^ Rcon@(i / Nk)
            | i % Nk == 4 /\ Nk > 6 then w@(i - Nk) ^ SubWord (w@(i - 1))
           else                          w@(i - Nk) ^ w@(i - 1)
         | i <- [ 0 ..< 4 * (Nr k + 1) ]
         ] : [4 * (Nr k + 1)]AESWord
```

</td><td>

```ada
   function W (Key : Key_Words; I : Word_Index) return AESWord
   is (if I < Nk then Key (I)
       elsif I mod Nk = 0
       then W (Key, I - Nk) xor SubWord (RotWord (W (Key, I - 1)))
            xor Rcon (I / Nk)
       elsif I mod Nk = 4 and then Nk > 6
       then W (Key, I - Nk) xor SubWord (W (Key, I - 1))
       else W (Key, I - Nk) xor W (Key, I - 1))
   with Subprogram_Variant => (Decreases => I);
```

</td></tr>
</table>

Case for case the same. The variant `I` records why the self-reference
is well founded: each case reads `w` at smaller indices only. The
regrouping `split (split (join (join w)))` is `AES_K.KeyExpansion`,
which builds round key `R` from words `4 * R` to `4 * R + 3`:

<a href="../../src/aes/foundation_spark-aes-spec-aes_k.ads#L80-L82"><code>spark/src/aes/foundation_spark-aes-spec-aes_k.ads:80-82</code></a>

```ada
   function KeyExpansion (Key : Key_Words) return Round_Keys
   is [for R in 0 .. Nr => Join ([for J in AESWord_Index =>
                                        W (Key, 4 * R + J)])];
```

NSA declares `KeyExpansion`, `Cipher` and `InvCipher` `foreign`, with a
Rust library behind them. That library is not built here, and the FFI
check fails if it is ever loaded, so every comparison is with the
Cryptol bodies
([`spark/cryptol/SPARK/AES/Cipher.cry:26-29`](../../cryptol/SPARK/AES/Cipher.cry#L26-L29)).

### Round transformations and ciphers (`Cipher.cry`)

<table>
<tr><th>Cryptol: <a href="../../../algorithms/AES/Cipher.cry#L127-L132"><code>algorithms/AES/Cipher.cry:127-132</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-cipher.ads#L84-L92"><code>spark/src/aes/foundation_spark-aes-spec-cipher.ads:84-92</code></a></th></tr>
<tr><td>

```cryptol
ShiftRows : Block -> Block
ShiftRows bs = bs @@ [  0,  5, 10, 15
                     ,  4,  9, 14,  3
                     ,  8, 13,  2,  7
                     , 12,  1,  6, 11
                     ]
```

</td><td>

```ada
   ShiftRows_Indices : constant Permutation :=
     [0, 5, 10, 15,
      4, 9, 14, 3,
      8, 13, 2, 7,
      12, 1, 6, 11];
   --  The index list of Cipher.cry's ShiftRows: bs @@ [0, 5, 10, 15, ...].

   function ShiftRows (Bs : Block) return Block
   is (Block_Indexing.Bulk_Index (Bs, ShiftRows_Indices));
```

</td></tr>
</table>

The literal index list becomes a named constant, and `@@` is the
prelude's `Bulk_Index` (see "The Cryptol prelude in SPARK").

<table>
<tr><th>Cryptol: <a href="../../../algorithms/AES/Cipher.cry#L157-L163"><code>algorithms/AES/Cipher.cry:157-163</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-cipher.ads#L114-L118"><code>spark/src/aes/foundation_spark-aes-spec-cipher.ads:114-118</code></a></th></tr>
<tr><td>

```cryptol
MixColumnsStep : AESWord -> AESWord
MixColumnsStep [s0, s1, s2, s3] =
    [ (0x02 • s0) ^ (0x03 • s1) ^ s2          ^ s3
    , s0          ^ (0x02 • s1) ^ (0x03 • s2) ^ s3
    , s0          ^ s1          ^ (0x02 • s2) ^ (0x03 • s3)
    , (0x03 • s0) ^ s1          ^ s2          ^ (0x02 • s3)
    ]
```

</td><td>

```ada
   function MixColumnsStep (S : AESWord) return AESWord
   is [Dot (16#02#, S (0)) xor Dot (16#03#, S (1)) xor S (2) xor S (3),
       S (0) xor Dot (16#02#, S (1)) xor Dot (16#03#, S (2)) xor S (3),
       S (0) xor S (1) xor Dot (16#02#, S (2)) xor Dot (16#03#, S (3)),
       Dot (16#03#, S (0)) xor S (1) xor S (2) xor Dot (16#02#, S (3))];
```

</td></tr>
</table>

The spec multiplies with `Dot`, the full GF(2^8) product, as the Cryptol
does with `•`. (The implementation uses `xTimes`; a lemma connects the
two, below.)

<table>
<tr><th>Cryptol: <a href="../../../algorithms/AES/Cipher.cry#L17-L18"><code>algorithms/AES/Cipher.cry:17-18</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-cipher.ads#L159-L160"><code>spark/src/aes/foundation_spark-aes-spec-cipher.ads:159-160</code></a></th></tr>
<tr><td>

```cryptol
Round : Block -> Block -> Block
Round xs ki = AddRoundKey (MixColumns (ShiftRows (SubBytes xs))) ki
```

</td><td>

```ada
   function Round (Xs : Block; Ki : Block) return Block
   is (AddRoundKey (MixColumns (ShiftRows (SubBytes (Xs))), Ki));
```

</td></tr>
</table>

<table>
<tr><th>Cryptol: <a href="../../../algorithms/AES/Cipher.cry#L24-L29"><code>algorithms/AES/Cipher.cry:24-29</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-aes_k.ads#L92-L96"><code>spark/src/aes/foundation_spark-aes-spec-aes_k.ads:92-96</code></a></th></tr>
<tr><td>

```cryptol
foreign Cipher : {k} (Key k) => [Nr k + 1]Block -> Block -> Block
Cipher ([w0] # ws # [wr]) in = state_final
  where
    state_initial    = AddRoundKey in w0
    state_rounds     = foldl Round state_initial ws
    state_final      = AddRoundKey (ShiftRows (SubBytes state_rounds)) wr
```

</td><td>

```ada
   function Cipher (W : Round_Keys; Input : Block) return Block
   is (AddRoundKey (ShiftRows (SubBytes
                      (Foldl_Round (AddRoundKey (Input, W (0)),
                                    W (1 .. Nr - 1)))),
                    W (Nr)));
```

</td></tr>
</table>

The pattern `[w0] # ws # [wr]` becomes `W (0)`, the slice
`W (1 .. Nr - 1)` and `W (Nr)`, and the three `where` bindings are
nested into one expression. `in` is an Ada reserved word, so the
argument is `Input`. `foldl Round` is `Foldl_Round`, an instance of the
prelude's `Folds`. In the generic, `Round_Keys` is the subtype
`Types.Round_Keys (0 .. Nr)`
([`foundation_spark-aes-spec-aes_k.ads:53`](../../src/aes/foundation_spark-aes-spec-aes_k.ads#L53)),
so the length is in the type, as in `[Nr k + 1]Block`.

The rest of `Cipher.cry` follows the same pattern:

| Cryptol (`algorithms/AES/Cipher.cry`) | SPARK | note |
|---|---|---|
| `SubBytes`, [104-105](../../../algorithms/AES/Cipher.cry#L104-L105) | `SubBytes`, [`spec-cipher.ads:71-72`](../../src/aes/foundation_spark-aes-spec-cipher.ads#L71-L72) | `SBox @@ bs` is `Bulk_Index (SBox.SBox, Bs)` |
| `InvSubBytes`, [111-112](../../../algorithms/AES/Cipher.cry#L111-L112) | `InvSubBytes`, [`spec-cipher.ads:77-78`](../../src/aes/foundation_spark-aes-spec-cipher.ads#L77-L78) | |
| `InvShiftRows`, [140-145](../../../algorithms/AES/Cipher.cry#L140-L145) | `InvShiftRows`, [`spec-cipher.ads:99-108`](../../src/aes/foundation_spark-aes-spec-cipher.ads#L99-L108) | index list as a constant |
| `MixColumns`, [169-170](../../../algorithms/AES/Cipher.cry#L169-L170) | `MixColumns`, [`spec-cipher.ads:124-125`](../../src/aes/foundation_spark-aes-spec-cipher.ads#L124-L125) | `map` is an aggregate over the four columns |
| `InvMixColumnsStep`, [175-181](../../../algorithms/AES/Cipher.cry#L175-L181) | `InvMixColumnsStep`, [`spec-cipher.ads:131-139`](../../src/aes/foundation_spark-aes-spec-cipher.ads#L131-L139) | |
| `InvMixColumns`, [187-188](../../../algorithms/AES/Cipher.cry#L187-L188) | `InvMixColumns`, [`spec-cipher.ads:145-146`](../../src/aes/foundation_spark-aes-spec-cipher.ads#L145-L146) | |
| `AddRoundKey`, [208-209](../../../algorithms/AES/Cipher.cry#L208-L209) | `AddRoundKey`, [`spec-cipher.ads:152-153`](../../src/aes/foundation_spark-aes-spec-cipher.ads#L152-L153) | `bs ^ w`, bytewise |
| `InvRound`, [35-36](../../../algorithms/AES/Cipher.cry#L35-L36) | `InvRound`, [`spec-cipher.ads:168-169`](../../src/aes/foundation_spark-aes-spec-cipher.ads#L168-L169) | |
| `InvRound'`, [42-43](../../../algorithms/AES/Cipher.cry#L42-L43) | `InvRound_Prime`, [`spec-cipher.ads:177-178`](../../src/aes/foundation_spark-aes-spec-cipher.ads#L177-L178) | Ada names cannot contain `'` |
| `foldl Round`, `foldl InvRound`, `foldl InvRound'` | `Foldl_Round`, `Foldl_InvRound`, `Foldl_InvRound_Prime`, [`spec-cipher.ads:186-228`](../../src/aes/foundation_spark-aes-spec-cipher.ads#L186-L228) | instances of the prelude's `Folds` |
| `reverse ws` | `Reverse_Keys`, [`spec-cipher.ads:240-241`](../../src/aes/foundation_spark-aes-spec-cipher.ads#L240-L241) | `reverse` is an Ada reserved word |
| `InvCipher`, [56-61](../../../algorithms/AES/Cipher.cry#L56-L61) | `AES_K.InvCipher`, [`spec-aes_k.ads:110-114`](../../src/aes/foundation_spark-aes-spec-aes_k.ads#L110-L114) | has a `{k}`: in the generic |
| `InvCipher'`, [69-74](../../../algorithms/AES/Cipher.cry#L69-L74) | `AES_K.InvCipher_Prime`, [`spec-aes_k.ads:127-132`](../../src/aes/foundation_spark-aes-spec-aes_k.ads#L127-L132) | has a `{k}`: in the generic |

### The top level (`Main.cry`)

<table>
<tr><th>Cryptol: <a href="../../../algorithms/AES/Main.cry#L18-L25"><code>algorithms/AES/Main.cry:18-25</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-aes_k.ads#L158-L160"><code>spark/src/aes/foundation_spark-aes-spec-aes_k.ads:158-160</code></a></th></tr>
<tr><td>

```cryptol
AES : {k} (Key k)
 => { Encrypt : ([k] -> [128] -> [128])
    , Decrypt : ([k] -> [128] -> [128])
    }
AES = {
    Encrypt key in = join (Cipher`{k}    (KeyExpansion`{k} (split (split key))) (split in))
  , Decrypt key in = join (InvCipher`{k} (KeyExpansion`{k} (split (split key))) (split in))
}
```

</td><td>

```ada
   function Encrypt (Key : Key_Bits; Input : Block_Bits) return Block_Bits
   is (Join_Block (Cipher (KeyExpansion (Split_Key (Key)),
                           Split_Block (Input))));
```

</td></tr>
</table>

The record ``AES`{k}`` is the generic package `AES_K`: its field
`Encrypt` is the function `AES_K.Encrypt`, and `Decrypt` is alongside
([`foundation_spark-aes-spec-aes_k.ads:169-171`](../../src/aes/foundation_spark-aes-spec-aes_k.ads#L169-L171)).
Main.cry works on bit vectors `[k]` and `[128]`, so `Spec.Main` has a
ghost bit-sequence type, `Bits`, an array of `Boolean` whose element 0 is
the Cryptol's first (most significant) bit
([`foundation_spark-aes-spec-main.ads:50-56`](../../src/aes/foundation_spark-aes-spec-main.ads#L50-L56)).
`split in` and `join` are `Split_Block` and `Join_Block`
([`foundation_spark-aes-spec-main.ads:108-116`](../../src/aes/foundation_spark-aes-spec-main.ads#L108-L116));
`split (split key)` is `Split_Key`, in the generic because it depends on
`k`
([`foundation_spark-aes-spec-aes_k.ads:148-150`](../../src/aes/foundation_spark-aes-spec-aes_k.ads#L148-L150)).

Main.cry's ``AES128 = AES`{128}``
([`Main.cry:38`](../../../algorithms/AES/Main.cry#L38)) is the instance
`package Foundation_Spark.AES.Spec.AES128 is new Foundation_Spark.AES.Spec.AES_K (K => 128)`
([`foundation_spark-aes-spec-aes128.ads:5-6`](../../src/aes/foundation_spark-aes-spec-aes128.ads#L5-L6)),
so Cryptol's `AES128.Encrypt` is SPARK's `AES128.Encrypt`. `AES192` and
`AES256` ([`Main.cry:43-48`](../../../algorithms/AES/Main.cry#L43-L48))
are the instances in `foundation_spark-aes-spec-aes192.ads` and
`foundation_spark-aes-spec-aes256.ads`.

### The Cryptol's own properties (`Spec.Properties`)

NSA's modules state properties about themselves. `AES.Spec.Properties`
states 13 of them over the spec layer, each as a ghost procedure whose
postcondition is the property's body, and gnatprove proves them:

<table>
<tr><th>Cryptol: <a href="../../../algorithms/AES/Cipher.cry#L88-L90"><code>algorithms/AES/Cipher.cry:88-90</code></a></th>
<th>SPARK: <a href="../../src/aes/foundation_spark-aes-spec-properties.ads#L187-L191"><code>spark/src/aes/foundation_spark-aes-spec-properties.ads:187-191</code></a></th></tr>
<tr><td>

```cryptol
CipherInverts : {k} (Key k) => [Nr k + 1]Block -> Block -> Bool
property CipherInverts ws state =
    InvCipher`{k} ws (Cipher`{k} ws state) == state
```

</td><td>

```ada
   procedure CipherInverts (K : Key_Size; Ws : Round_Keys; State : Block)
   with
     Pre  => Is_Round_Keys (K, Ws),
     Post =>
       Dispatch.InvCipher (K, Ws, Dispatch.Cipher (K, Ws, State)) = State;
```

</td></tr>
</table>

A property with a `{k}` takes `K` as a parameter and is stated over the
dispatchers (below), so one proof covers the three key sizes.

| Cryptol property | SPARK (`foundation_spark-aes-spec-properties.ads`) |
|---|---|
| `GF28MultiplicationCorrect`, [`GF28.cry:29-32`](../../../algorithms/AES/GF28.cry#L29-L32) | [93-96](../../src/aes/foundation_spark-aes-spec-properties.ads#L93-L96) |
| `SBoxCorrect`, [`SBox.cry:39`](../../../algorithms/AES/SBox.cry#L39) | [107-108](../../src/aes/foundation_spark-aes-spec-properties.ads#L107-L108) |
| `SBoxInverts`, [`SBox.cry:88-89`](../../../algorithms/AES/SBox.cry#L88-L89) | [112-113](../../src/aes/foundation_spark-aes-spec-properties.ads#L112-L113) |
| `SubBytesInverts`, [`Cipher.cry:118-119`](../../../algorithms/AES/Cipher.cry#L118-L119) | [121-122](../../src/aes/foundation_spark-aes-spec-properties.ads#L121-L122) |
| `ShiftRowsInverts`, [`Cipher.cry:151-152`](../../../algorithms/AES/Cipher.cry#L151-L152) | [127-128](../../src/aes/foundation_spark-aes-spec-properties.ads#L127-L128) |
| `MixColumnsStepInverts`, [`Cipher.cry:194-195`](../../../algorithms/AES/Cipher.cry#L194-L195) | [133-134](../../src/aes/foundation_spark-aes-spec-properties.ads#L133-L134) |
| `MixColumnsInverts`, [`Cipher.cry:201-202`](../../../algorithms/AES/Cipher.cry#L201-L202) | [139-140](../../src/aes/foundation_spark-aes-spec-properties.ads#L139-L140) |
| `AddRoundKeyInvolution`, [`Cipher.cry:214-215`](../../../algorithms/AES/Cipher.cry#L214-L215) | [145-146](../../src/aes/foundation_spark-aes-spec-properties.ads#L145-L146) |
| `RoundInverts`, [`Cipher.cry:49-50`](../../../algorithms/AES/Cipher.cry#L49-L50) | [152-153](../../src/aes/foundation_spark-aes-spec-properties.ads#L152-L153) |
| `InvCipherEquivalence`, [`Cipher.cry:80-82`](../../../algorithms/AES/Cipher.cry#L80-L82) | [159-165](../../src/aes/foundation_spark-aes-spec-properties.ads#L159-L165) |
| `CipherInverts'`, [`Cipher.cry:96-98`](../../../algorithms/AES/Cipher.cry#L96-L98) | `CipherInverts_Prime`, [173-179](../../src/aes/foundation_spark-aes-spec-properties.ads#L173-L179) |
| `CipherInverts`, [`Cipher.cry:88-90`](../../../algorithms/AES/Cipher.cry#L88-L90) | [187-191](../../src/aes/foundation_spark-aes-spec-properties.ads#L187-L191) |
| `EncryptInverts`, [`Main.cry:31-33`](../../../algorithms/AES/Main.cry#L31-L33) | [203-208](../../src/aes/foundation_spark-aes-spec-properties.ads#L203-L208) |

Two are not stated: `SBoxPolynomialIsIrreducible` and `inverseCorrect`
([`SBox.cry:14-28`](../../../algorithms/AES/SBox.cry#L14-L28)).
`SBoxCorrect`, the table equal to `affine` at every byte, is proved by
evaluation, byte by byte, in the generated unit `Spec.SBox.SBox_Entries`,
one of the crate's slow proofs
([`spark/doc/proving.md`](../proving.md#slow-proofs)). These re-proofs are a cross-check: SAW
already proves the spec layer equal to the Cryptol, from which the
properties follow
([`spark/doc/proving.md`, "The Cryptol's own properties, re-proved"](../proving.md#the-cryptols-own-properties-re-proved)).

## The Cryptol prelude in SPARK

Cryptol built-ins such as `foldl` and `@@` have no Ada counterpart. The
crate states each once, as a generic in
[`spark/src/cryptol/`](../../src/cryptol/), and the spec instantiates it
at AES's types. AES uses `Folds`, `Bulk_Indexing`, `Sequences` (for
`reverse`), `Words` (`@` and `head` on a word), `Join_Split` (`split`
and `join` between bytes and bits) and `Polynomial_Products` (`pmult` in
`GF28`).

`foldl` is a primitive with no Cryptol body. `Folds` states it by
recursion on the number of elements folded, from the last, because that
is how a loop runs a fold; `Foldl` is then `Foldl_Take` over the whole
sequence
([`foundation_spark-cryptol-folds.ads:53-55`](../../src/cryptol/foundation_spark-cryptol-folds.ads#L53-L55)):

<a href="../../src/cryptol/foundation_spark-cryptol-folds.ads#L39-L46"><code>spark/src/cryptol/foundation_spark-cryptol-folds.ads:39-46</code></a>

```ada
   function Foldl_Take (Z : Acc; Xs : Seq; N : Index'Base) return Acc is
     (if N <= 0 then Z
      else F (Foldl_Take (Z, Xs, N - 1), Xs (Xs'First + (N - 1))))
   with
     Pre                => N <= Xs'Length,
     Subprogram_Variant => (Decreases => N);
   --  Cryptol's `foldl f z (take`{N} xs)`: Z when N is 0, and otherwise F
   --  applied to the fold of the first N - 1 elements and element N - 1.
```

`Spec.Cipher` instantiates it with `Round` as `F`, and `Foldl_Round` is
`Round_Folds.Foldl`
([`foundation_spark-aes-spec-cipher.ads:210-211`](../../src/aes/foundation_spark-aes-spec-cipher.ads#L210-L211)):

<a href="../../src/aes/foundation_spark-aes-spec-cipher.ads#L186-L191"><code>spark/src/aes/foundation_spark-aes-spec-cipher.ads:186-191</code></a>

```ada
   package Round_Folds is new Cryptol.Folds
     (Acc     => Block,
      Index   => Round_Key_Index,
      Element => Block,
      Seq     => Round_Keys,
      F       => Round);
```

`@@` has a Cryptol body, `xs @@ is = [ xs @ i | i <- is ]`, which
`Bulk_Indexing` restates directly:

<a href="../../src/cryptol/foundation_spark-cryptol-bulk_indexing.ads#L30-L31"><code>spark/src/cryptol/foundation_spark-cryptol-bulk_indexing.ads:30-31</code></a>

```ada
   function Bulk_Index (Xs : Seq; Ixs : Indices) return Out_Seq is
     ([for J in Out_Index => Xs (Ixs (J))]);
```

`Spec.Cipher` instantiates it twice: to index an S-box by the 16 bytes
of a block (`SBox @@ bs`), and to index a block by a permutation
(`bs @@ [0, 5, 10, ...]`)
([`foundation_spark-aes-spec-cipher.ads:51-67`](../../src/aes/foundation_spark-aes-spec-cipher.ads#L51-L67)).

## The implementation layer and the proof chain

### Dispatch: one implementation, three key sizes

The spec's `{k}` functions are three instances of `AES_K`, but the
implementation is one body with the key size `K` as a run-time
parameter. `Spec.Dispatch` has one ghost function per `{k}` function,
which selects the instance by `K`. Its postcondition restates the
Cryptol body once, uniformly in `K`, so the implementation's proofs
never case on the key size:

<a href="../../src/aes/foundation_spark-aes-spec-dispatch.ads#L112-L124"><code>spark/src/aes/foundation_spark-aes-spec-dispatch.ads:112-124</code></a>

```ada
   function Cipher (K : Key_Size; W : Round_Keys; Input : Block) return Block
   is (case K is
         when 128 => AES128.Cipher (W, Input),
         when 192 => AES192.Cipher (W, Input),
         when 256 => AES256.Cipher (W, Input))
   with
     Pre  => Is_Round_Keys (K, W),
     Post =>
       Cipher'Result
       = AddRoundKey (ShiftRows (SubBytes
                        (Foldl_Round (AddRoundKey (Input, W (0)),
                                      W (1 .. Nr (K) - 1)))),
                      W (Nr (K)));
```

`Dispatch` is not in the Cryptol: Cryptol resolves `k` at the type
level, and Ada has no type-level numbers
([`foundation_spark-aes-spec-dispatch.ads:8-15`](../../src/aes/foundation_spark-aes-spec-dispatch.ads#L8-L15)).

### The executable subprograms and their contracts

Every subprogram of `AES.Impl` has a postcondition that names the spec.
`Expand_Key`'s is `W = Spec.Dispatch.KeyExpansion (K, Key)`
([`foundation_spark-aes-impl.ads:112-116`](../../src/aes/foundation_spark-aes-impl.ads#L112-L116)),
and `Encrypt_Block`'s:

<a href="../../src/aes/foundation_spark-aes-impl.ads#L195-L198"><code>spark/src/aes/foundation_spark-aes-impl.ads:195-198</code></a>

```ada
   procedure Encrypt_Block (K : Key_Size; W : Round_Keys; State : in out Block)
   with
     Pre  => Is_Round_Keys (K, W),
     Post => State = Spec.Dispatch.Cipher (K, W, State'Old);
```

`Decrypt_Block` and `Decrypt_Block_Prime` have the same shape, with
`Spec.Dispatch.InvCipher` and `InvCipher_Prime`
([`foundation_spark-aes-impl.ads:206-222`](../../src/aes/foundation_spark-aes-impl.ads#L206-L222)).
The pieces they call each equal one spec function. For example,
`X_Times` uses a mask instead of the spec's `if`, so that no branch
depends on the data:

<a href="../../src/aes/foundation_spark-aes-impl.ads#L38-L41"><code>spark/src/aes/foundation_spark-aes-impl.ads:38-41</code></a>

```ada
   function X_Times (B : Byte) return Byte
   is (Interfaces.Shift_Left (B, 1)
       xor (16#1b# and (0 - Interfaces.Shift_Right (B, 7))))
   with Post => X_Times'Result = Spec.GF28.xTimes (B);
```

The S-box is constant-time too. `Sub_Byte`'s postcondition is the spec's
table
([`foundation_spark-aes-impl.ads:58-59`](../../src/aes/foundation_spark-aes-impl.ads#L58-L59)),
but its body reads no table: it evaluates Boyar and Peralta's circuit on
eight bytes at once, one per 8-bit lane of a 64-bit word. The body-local
function that does this states, lane by lane, equality with the table:

<a href="../../src/aes/foundation_spark-aes-impl.adb#L264-L268"><code>spark/src/aes/foundation_spark-aes-impl.adb:264-268</code></a>

```ada
   function SBox_Lanes (X : Lanes) return Lanes
   with
     Post =>
       (for all J in Lane_Index =>
          Lane (SBox_Lanes'Result, J) = Spec.SBox.SBox (Lane (X, J)));
```

gnatprove proves it: the provers bit-blast the circuit against the table
([`spark/doc/constant-time.md`](../constant-time.md#constant-time)).
`Inv_SBox_Lanes` does the same for `InvSBox`.

`AES.Impl.Main` is the byte-level top. A key is `K / 8` bytes rather
than `[k]` bits, and the postcondition goes through Cryptol's `join`
(the ghost `Join_Key` and `Spec.Main.Join_Block`) to compare with the
spec's bit-level `Encrypt`:

<a href="../../src/aes/foundation_spark-aes-impl-main.ads#L80-L87"><code>spark/src/aes/foundation_spark-aes-impl-main.ads:80-87</code></a>

```ada
   function Encrypt (K : Key_Size; Key : Key_Bytes; Input : Block)
     return Block
   with
     Pre  => Is_Key_Bytes (K, Key),
     Post =>
       Spec.Main.Join_Block (Encrypt'Result)
       = Spec.Dispatch.Encrypt
           (K, Join_Key (Key), Spec.Main.Join_Block (Input));
```

### How gnatprove gets from the code to the spec

Each subprogram is proved against its own spec function, and its callers
use that postcondition, so the proof is built bottom-up. Lemmas fill
four kinds of gap.

**GF(2^8) by `xTimes`.** The spec's `MixColumnsStep` multiplies with
`Dot`, two recursive folds over bits; the implementation multiplies by
the small constants with `X_Times` alone. `Lemma_Dot` proves the two
equal for any constant below 16:

<a href="../../src/aes/foundation_spark-aes-lemmas.ads#L111-L114"><code>spark/src/aes/foundation_spark-aes-lemmas.ads:111-114</code></a>

```ada
   procedure Lemma_Dot (B, C : Byte)
   with
     Pre  => B < 16,
     Post => Spec.GF28.Dot (B, C) = By_xTimes (B, C);
```

**Loops against `foldl`.** `Encrypt_Block` runs the middle rounds in a
loop whose invariant is: the state after `R - 1` rounds is the spec's
fold over the first `R - 1` middle round keys. One more round extends the
fold by one key at the end:

<a href="../../src/aes/foundation_spark-aes-impl.adb#L680-L693"><code>spark/src/aes/foundation_spark-aes-impl.adb:680-693</code></a>

```ada
      Add_Round_Key (State, W (0));
      for R in 1 .. Nr (K) - 1 loop
         pragma Loop_Invariant
           (State = Spec.Cipher.Foldl_Round (S0, W (1 .. R - 1)));
         Lemmas.Lemma_Round_Eq
           (State, Spec.Cipher.Foldl_Round (S0, W (1 .. R - 1)), W (R));
         Lemmas.Lemma_Foldl_Round_Snoc (S0, W (1 .. R));
         Round (State, W (R));
      end loop;
      pragma Assert
        (State = Spec.Cipher.Foldl_Round (S0, W (1 .. Nr (K) - 1)));
      Sub_Bytes (State);
      Shift_Rows (State);
      Add_Round_Key (State, W (Nr (K)));
```

<a href="../../src/aes/foundation_spark-aes-lemmas.ads#L230-L235"><code>spark/src/aes/foundation_spark-aes-lemmas.ads:230-235</code></a>

```ada
   procedure Lemma_Foldl_Round_Snoc (Z : Block; Xs : Round_Keys)
   with
     Pre  => Xs'Length > 0,
     Post =>
       Foldl_Round (Z, Xs)
       = Round (Foldl_Round (Z, Xs (Xs'First .. Xs'Last - 1)), Xs (Xs'Last));
```

Because the prelude's fold recurses from the last element, this lemma is
nearly its definition. After the loop, the last three calls are the outer
layer of `Dispatch.Cipher`'s postcondition. The key schedule is proved
the same way, word by word, against `Dispatch.W` through
`Dispatch.Lemma_W`
([`foundation_spark-aes-impl.adb:385-421`](../../src/aes/foundation_spark-aes-impl.adb#L385-L421)).

**Equal arguments, equal results.** Ada's `=` on arrays compares
components; it is not the provers' built-in equality. So the provers do
not know that a spec function gives equal results on two equal arrays
until the function is unfolded. The `*_Eq` lemmas state it once per
function, for example `Lemma_Round_Eq` above
([`foundation_spark-aes-lemmas.ads:143-146`](../../src/aes/foundation_spark-aes-lemmas.ads#L143-L146)).

**Bytes to bits.** `AES.Main_Lemmas.Lemma_Split_Join_Key` proves that
Cryptol's `split (split key)` of the key's bits gives back the key's
bytes, four to a word
([`foundation_spark-aes-main_lemmas.ads:34-43`](../../src/aes/foundation_spark-aes-main_lemmas.ads#L34-L43)).
With it and the congruence lemmas `Lemma_KeyExpansion_Eq` and
`Lemma_Cipher_Eq`, the body of `Impl.Main.Encrypt`
([`foundation_spark-aes-impl-main.adb:36-60`](../../src/aes/foundation_spark-aes-impl-main.adb#L36-L60))
proves its postcondition: the result is Main.cry's ``AES`{k}.Encrypt``
of the key and the block, for every key size, key and block.

## How it is checked

### gnatprove: implementation = spec, for all inputs

gnatprove proves every postcondition above, for every input and every
`K` in `Key_Size`. There are no fixed-size limits in this link.

### The FFI check: spec and executables against NSA's Cryptol, by testing

The properties are in
[`spark/cryptol/SPARK/AES/`](../../cryptol/SPARK/AES/), one module per
NSA module. Each declares the SPARK exports as body-less `foreign`
functions and compares them with NSA's function. For the S-box:

<a href="../../cryptol/SPARK/AES/SBox.cry#L28-L29"><code>spark/cryptol/SPARK/AES/SBox.cry:28-29</code></a>

```cryptol
prop_SBox : [8] -> Bit
property prop_SBox b = spark_SBox b == SBox @ b
```

`spark_SBox` is the spec layer's table; `prop_Impl_SBox` checks the
executable bitsliced S-box the same way
([`SBox.cry:54-55`](../../cryptol/SPARK/AES/SBox.cry#L54-L55)). For the
executable cipher at each key size:

<a href="../../cryptol/SPARK/AES/Cipher.cry#L221-L222"><code>spark/cryptol/SPARK/AES/Cipher.cry:221-222</code></a>

```cryptol
prop_Encrypt_Block : {k} (Key k) => [Nr k + 1]Block -> Block -> Bit
prop_Encrypt_Block w in = spark_Encrypt_Block`{k} w in == Cipher`{k} w in
```

Known-answer vectors are checked too, for example `prop_CipherExample`
([`Cipher.cry:203-214`](../../cryptol/SPARK/AES/Cipher.cry#L203-L214)),
copied from NSA's `CipherExample`
([`algorithms/AES/Tests.cry:236`](../../../algorithms/AES/Tests.cry#L236)).

[`spark/cryptol/properties.txt`](../../cryptol/properties.txt) lists 88
AES properties
([lines 20-107](../../cryptol/properties.txt#L20-L107)): 23 in `exhaust`
mode and 65 in `check` mode.

- `exhaust` runs every input: `xTimes` (256), `(•)` (65536), both
  S-boxes (256 each) for the spec and for the executable, `Rcon` (256),
  and the known-answer vectors (1 test each). For these functions the
  check covers every input.
- `check` runs random inputs: 10000 for the round transformations; 1000
  for the executable `Expand_Key`, `Encrypt_Block`, `Decrypt_Block`,
  `Decrypt_Block_Prime` and `Impl.Main`'s `Encrypt` and `Decrypt` at each
  key size; 100 through the exported C byte interface (`prop_Exec_*`);
  and 5 for the spec layer's `KeyExpansion`, `Cipher`, `InvCipher`,
  `InvCipher'`, `Encrypt` and `Decrypt` at each key size. The
  executables carry most of the random testing, since they are proved
  equal to the spec.

### SAW: bitcode = NSA's Cryptol, at k = 128, 192 and 256

SAW proves LLVM bitcode compiled from the crate's sources equal to NSA's
unmodified Cryptol. The run is recorded in
[`spark/saw/results.txt`](../../saw/results.txt): commit `82b10e6`, on an
x86_64 Linux instance
([lines 9-11](../../saw/results.txt#L9-L11)), with the SHA-256 of every
source and Cryptol file it read. The AES files at `6210b99` have the
same hashes.

- **Implementation** ([`aes_impl.saw`](../../saw/aes_impl.saw)): 31
  results ([lines 132-162](../../saw/results.txt#L132-L162)). The leaves
  (`X_Times`, `SBox_Lanes`, `Sub_Bytes`, `Mix_Column`, `Round`, and the
  others) are proved for all inputs. `Expand_Key`, `Encrypt_Block` and
  `Decrypt_Block` are proved against ``KeyExpansion`{k}``,
  ``Cipher`{k}`` and ``InvCipher`{k}`` at each of `k = 128, 192, 256`,
  for all keys and blocks. Not proved by SAW: `Dot` (no cipher calls
  it), `Decrypt_Block_Prime` with `Inv_Round_Prime`, and `Impl.Main`'s
  `Encrypt` and `Decrypt`; the FFI tests them
  ([`spark/doc/saw.md`](../saw.md#what-saw-proves-on-its-own-in-place-or-not-at-all)).
- **Spec layer** ([`aes_spec.saw`](../../saw/aes_spec.saw), with
  `aes_spec_gf.saw`, `aes_spec_cipher.saw`, `aes_spec_keyexpansion.saw`
  and `aes_spec_main.saw`): 376 results
  ([lines 222-597](../../saw/results.txt#L222-L597)) covering the
  spec-layer declarations above, up to each instance's `Encrypt` and
  `Decrypt`. Recursive functions are proved one index at a time where
  that is cheaper (44, 52 and 60 lemmas for `W` at the three key sizes).
  `Pgcd`, `Inverse` and `Affine` are proved for each of the 256 bytes,
  one proof per byte, because SAW's evaluation of `pgcd`'s `inner` does
  not terminate on a symbolic byte
  ([lines 568-570](../../saw/results.txt#L568-L570)).
- **Negative controls:** 12 deliberately wrong AES contracts (reversed
  round keys, `xTimes` without reduction, the wrong modulus in `Dot`,
  and others) are each rejected with a counterexample
  ([lines 1220-1238](../../saw/results.txt#L1220-L1238)).
- **Time:** 4 s for `aes_impl.saw` and 648 s for `aes_spec.saw`
  ([line 1239](../../saw/results.txt#L1239)).
  [`results-long.txt`](../../saw/results-long.txt) adds only SHA-256 and
  HMAC proofs ([line 19](../../saw/results-long.txt#L19)), nothing for
  AES.

SAW runs locally, not in CI. It proves the bitcode GNAT-LLVM produced;
gnatprove reasons about the Ada source.

### What is proved, and what is only tested

- **Proved for all inputs and key sizes:** implementation = spec layer
  (gnatprove).
- **Proved for all keys and blocks at each of the three key sizes:**
  implementation bitcode = Cryptol, and spec-layer bitcode = Cryptol
  (SAW), with the exceptions listed above.
- **Tested on every input:** the byte-level functions in `exhaust` mode
  (FFI).
- **Tested on random inputs only:** everything in `check` mode (FFI),
  including the parts SAW does not prove.

## Where spec and implementation are not one-to-one

Mostly there is one executable subprogram per spec function, proved
equal to it. The exceptions for AES
([`spark/doc/proving.md`](../proving.md#where-spec-and-implementation-are-not-one-to-one)):

- **`affine` and `inverse` are spec-only.** The implementation's S-box is
  a circuit proved equal to the table `SBox`, not to `affine`. The table
  is tied to `affine` (and so to `inverse`) by the re-proved
  `SBoxCorrect`, and SAW proves `Affine`, `Inverse` and `Pgcd` equal to
  the Cryptol at every byte. There is no FFI property for `affine` or
  `inverse`; the table they equal is checked exhaustively.
- **`Dot` is in the implementation, but the ciphers do not call it.**
  They multiply with `X_Times`, connected to `Dot` by `Lemma_Dot`.
- **`Rot_Word`, `Xor_Word` and `Rcon`** are executable copies of spec
  functions, proved equal to them. SAW proves them only as part of
  `Expand_Key`, because the compiler inlines them.
- **The implementation stops at bytes.** Main.cry's `Encrypt` takes bit
  vectors; `Impl.Main.Encrypt` takes bytes, and its postcondition
  converts through Cryptol's `join`. This change of representation is in
  the contract, not in the spec layer.
- **`Spec.Dispatch` has no Cryptol counterpart.** It exists because the
  implementation has one body for all key sizes.
