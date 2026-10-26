# HMAC-SHA-256: from NSA's Cryptol to SPARK

This page walks through the SPARK HMAC-SHA-256 in `foundation_spark` and
shows how it is tied to NSA's Cryptol specification of HMAC
(FIPS 198-1, RFC 2104). It quotes the code as it is at commit `6210b99`.
Every excerpt is cited by file and line range, and the links go to the
same lines in this repository.

HMAC is built on a hash. This page covers HMAC itself and uses SHA-256
only through its interface. SHA-256 has its own walkthrough:
[sha-256.md](sha-256.md).

## The three layers

The SPARK code has three layers, and each link between them is checked in
a different way.

- **The spec layer** is ghost SPARK: code that exists only for proof and
  is never compiled into the library. It mirrors NSA's Cryptol declaration
  by declaration. `HMAC`, `HMAC_init`, `opad` and `ipad` have the same
  names, the same arguments and the same case structure as in
  `algorithms/HMAC/Main.cry`. A generic package, `HMAC.Main`, plays the
  part of the Cryptol function that takes the hash functions as arguments.
  Its instance `HMAC.SHA256` plays the part of `packaging/Hash.cry`'s
  `HMAC` at SHA-256's parameters.
- **The implementation layer** is ordinary, executable SPARK:
  `HMAC.SHA256_Impl`. It works on bytes, not bits, and it hashes through
  two streaming SHA-256 contexts. Its postconditions state that its
  results equal the spec layer's on the bits. Between the two sit the
  byte-to-bit view `SHA2.SHA256_Bytes.Bits_Of` and the streaming theorems
  of `SHA2.SHA256_Stream` (`Lemma_Update`, `Lemma_Final`), plus lemmas in
  the HMAC body itself.
- **The checks:**
  - **gnatprove** proves implementation = spec layer, for every key and
    text within the length bounds.
  - **The FFI check** runs the spec layer and the executables against NSA's
    Cryptol through Cryptol's `foreign` functions, by random testing at
    chosen lengths and on RFC 4231's known answers.
  - **SAW** proves the compiled code (LLVM bitcode) of the implementation,
    and of the spec layer, equal to NSA's Cryptol, at a few fixed key and
    text lengths.

```text
  NSA's Cryptol                              SPARK
  ------------                               -----
  algorithms/HMAC/Main.cry   <-- mirrors --  HMAC.Main (generic, ghost)
  packaging/Hash.cry: HMAC   <-- mirrors --  HMAC.SHA256 (instance, ghost)
        ^       ^                                  ^
        |       |                                  | gnatprove: equal on the
        |       |                                  | bits, all inputs
        |       |                            HMAC.SHA256_Impl (executable)
        |       |                                  |  built on
        |       |                            SHA2.SHA256_Stream (executable)
        |       |
        |       +-- FFI (random tests, RFC 4231) -- spec layer and executables
        +---------- SAW (fixed lengths) ----------- bitcode of both layers
```

The chain closes like this. gnatprove shows the executable code equals the
spec layer for all inputs. The spec layer is written to read like the
Cryptol, and the FFI tests and SAW proofs check that it, and the
executable code, compute what NSA's Cryptol computes. Those two checks
cover chosen lengths only. The step from the spec layer to the Cryptol is
therefore by close reading plus testing plus fixed-size proof, not a proof
for all lengths.

## Reading the notation

Cryptol:

- `[n]` is a sequence of `n` bits; `[k][8]` is `k` bytes. `[n]` is also
  the type of an `n`-bit number.
- `#` concatenates sequences; `^` is exclusive or; `take` keeps the first
  bits of a sequence.
- `join` turns `[k][8]` into `[k * 8]`, the bytes' bits in order, most
  significant bit first. `repeat`{B} x` is `B` copies of `x`. `zero` is
  all zero bits.
- `{ λ, B, k, n, L }` are type parameters: sizes known at type-checking
  time. The parenthesised list after them gives constraints on the sizes.
  ``f`{B = 64}`` supplies a type parameter explicitly.
- `| k == B => ...` is a guard: the first case whose condition holds is
  the result.
- `private` hides the following declarations from other modules.

SPARK (Ada):

- `with Ghost` marks code that exists for proof only.
- An expression function `function F (X : T) return R is (expr)` is a
  function whose body is one expression, visible to the prover.
- `Pre` and `Post` are the precondition and postcondition; `F'Result` is
  the function's result in `Post`.
- `A & B` concatenates arrays; `xor` on Boolean arrays is element-wise.
  `X (0 .. N - 1)` is a slice. `X'Length`, `X'First` are an array's length
  and first index.
- A generic package is a template instantiated with `is new`; `with
  function Hk ...` in its formal part is a function supplied at
  instantiation.
- `pragma Compile_Time_Error (Cond, Msg)` rejects compilation when `Cond`
  is true.

## The spec layer, declaration by declaration

The Cryptol is in `algorithms/HMAC/Main.cry`. The SPARK is in three files
under `spark/src/hmac/`: `foundation_spark-hmac.ads` (bytes and the
prelude functions at HMAC's types), `foundation_spark-hmac-main.ads` (the
generic `Main`) and `foundation_spark-hmac-sha256.ads` (its SHA-256
instance).

Bits are `SHA2.Bits`, an array of `Boolean` indexed from 0, the same type
the SPARK SHA-256 spec takes and returns. Bytes are `HMAC.Bytes`, an
array of `Unsigned_8` indexed from 0.

### `HMAC`'s parameters: type parameters and hash arguments

<table>
<tr><th>Cryptol: <a href="../../../algorithms/HMAC/Main.cry#L26-L39"><code>algorithms/HMAC/Main.cry:26-39</code></a></th>
<th>SPARK: <a href="../../src/hmac/foundation_spark-hmac-main.ads#L38-L59"><code>spark/src/hmac/foundation_spark-hmac-main.ads:38-59</code></a></th></tr>
<tr><td>

```cryptol
HMAC : 
    { λ, B, k, n, L}
    ( λ <= L * 8
    , fin B, 2 ^^ B >= 8 * B
    , fin k
    , fin n, n < 2 ^^ B - 8 * B
    , L <= B
    )
 => ([k * 8]       -> [L * 8])
 -> ([B * 8 + n]   -> [L * 8])
 -> ([(B + L) * 8] -> [L * 8])
 -> [k][8]
 -> [n]
 -> [λ]
```

</td><td>

```ada
generic
   B : Positive;
   L : Natural;
   Max_Length : SHA2.Bit_Index;
   with function Hk (M : SHA2.Bits) return SHA2.Bits
   with
     Ghost,
     Pre  => M'First = 0 and then M'Length < Max_Length,
     Post => Hk'Result'First = 0
             and then Hk'Result'Length = 8 * SHA2.Bit_Index (L);
   with function Hn (M : SHA2.Bits) return SHA2.Bits
   with
     Ghost,
     Pre  => M'First = 0 and then M'Length < Max_Length,
     Post => Hn'Result'First = 0
             and then Hn'Result'Length = 8 * SHA2.Bit_Index (L);
   with function HL (M : SHA2.Bits) return SHA2.Bits
   with
     Ghost,
     Pre  => M'First = 0 and then M'Length < Max_Length,
     Post => HL'Result'First = 0
             and then HL'Result'Length = 8 * SHA2.Bit_Index (L);
```

</td></tr>
</table>

The Cryptol `HMAC` takes three hash functions, `Hk`, `Hn` and `HL`, as
arguments, and the block size `B` and output size `L` (both in bytes) as
type parameters. Ada has no function arguments, so the SPARK makes them
the generic's formals, in the same order. The per-call sizes `k`, `n` and
`λ` stay per call: they are the lengths of the key, the text and the
result. Cryptol gives each hash its own input type (`[k * 8]`,
`[B * 8 + n]`, `[(B + L) * 8]`); the SPARK gives all three one bound on
input length, `Max_Length`, and moves the size requirements into the
preconditions of `HMAC` and `HMAC_init`
([foundation_spark-hmac-main.ads:10-16](../../src/hmac/foundation_spark-hmac-main.ads#L10-L16)
states this).

### The type constraints

<table>
<tr><th>Cryptol: <a href="../../../algorithms/HMAC/Main.cry#L28-L33"><code>algorithms/HMAC/Main.cry:28-33</code></a></th>
<th>SPARK: <a href="../../src/hmac/foundation_spark-hmac-main.ads#L66-L73"><code>spark/src/hmac/foundation_spark-hmac-main.ads:66-73</code></a></th></tr>
<tr><td>

```cryptol
    ( λ <= L * 8
    , fin B, 2 ^^ B >= 8 * B
    , fin k
    , fin n, n < 2 ^^ B - 8 * B
    , L <= B
    )
```

</td><td>

```ada
   pragma Compile_Time_Error
     (B < 6, "Main.cry requires 2 ^^ B >= 8 * B, that is B >= 6");
   pragma Compile_Time_Error (L > B, "Main.cry requires L <= B");

   function Text_Limit return SHA2.Bit_Index is
     (if B >= 126 then SHA2.Bit_Index'Last
      else 2 ** B - 8 * SHA2.Bit_Index (B))
   with Ghost;
```

</td></tr>
</table>

The constraints on `B` and `L` hold for a whole instance, so the SPARK
checks them when the generic is instantiated. The constraints on `λ` and
`n` depend on each call, so they become conjuncts of `HMAC`'s
precondition (below). `Text_Limit` is Cryptol's `2 ^^ B - 8 * B`. One
deviation: for `B` of 126 or more that number does not fit in
`SHA2.Bit_Index`, and `Bit_Index'Last` stands in for it. The comment at
[foundation_spark-hmac-main.ads:74-77](../../src/hmac/foundation_spark-hmac-main.ads#L74-L77)
gives the reason: a text that long could not be hashed anyway. At SHA-256,
`B = 64`, so this case does not arise.

### `opad` and `ipad`

<table>
<tr><th>Cryptol: <a href="../../../algorithms/HMAC/Main.cry#L46-L47"><code>algorithms/HMAC/Main.cry:46-47</code></a></th>
<th>SPARK: <a href="../../src/hmac/foundation_spark-hmac-main.ads#L80-L95"><code>spark/src/hmac/foundation_spark-hmac-main.ads:80-95</code></a></th></tr>
<tr><td>

```cryptol
    opad = join (repeat`{B} 0x5C)  // [FIPS-PUB-198-1 Section 2.3]
    ipad = join (repeat`{B} 0x36)  // [FIPS-PUB-198-1 Section 2.3]
```

</td><td>

```ada
   function Opad return SHA2.Bits is
     (Join (Repeat (Byte_Index (B), 16#5C#)))
   with
     Ghost,
     Post => Opad'Result'First = 0
             and then Opad'Result'Length = 8 * SHA2.Bit_Index (B);
   --  HMAC's local `opad = join (repeat`{B} 0x5C)` (Main.cry:46,
   --  [FIPS-PUB-198-1 Section 2.3]), the outer pad: B bytes 0x5C.
   --  @return The B * 8 bits of the outer pad.

   function Ipad return SHA2.Bits is
     (Join (Repeat (Byte_Index (B), 16#36#)))
   with
     Ghost,
     Post => Ipad'Result'First = 0
             and then Ipad'Result'Length = 8 * SHA2.Bit_Index (B);
```

</td></tr>
</table>

The same expression: `B` copies of the byte, joined into `B * 8` bits.
In Cryptol they are local definitions in `HMAC`'s `where` clause; in
SPARK they are functions of the package, since an Ada expression function
has no `where`. `16#5C#` is Ada's spelling of `0x5C`. `Join` and `Repeat`
are the Cryptol prelude's `join` and `repeat`, described in
[The Cryptol prelude in SPARK](#the-cryptol-prelude-in-spark).

### `HMAC_init`: the key preprocessing

<table>
<tr><th>Cryptol: <a href="../../../algorithms/HMAC/Main.cry#L56-L65"><code>algorithms/HMAC/Main.cry:56-65</code></a></th>
<th>SPARK: <a href="../../src/hmac/foundation_spark-hmac-main.ads#L100-L113"><code>spark/src/hmac/foundation_spark-hmac-main.ads:100-113</code></a></th></tr>
<tr><td>

```cryptol
  HMAC_init :
      { B, k, L }
      ( fin B, fin k, L <= B )
   => ([k * 8] -> [L * 8])
   -> [k][8]
   -> [B * 8]
  HMAC_init Hk K
    | k == B => join K
    | k >  B => Hk (join K) # (zero : [(B - L) * 8])
    | k <  B => join K      # (zero : [(B - k) * 8])
```

</td><td>

```ada
   function HMAC_init (K : Bytes) return SHA2.Bits is
     (if K'Length = Byte_Index (B) then Join (K)
      elsif K'Length > Byte_Index (B)
      then Hk (Join (K)) & Zero (8 * SHA2.Bit_Index (B - L))
      else Join (K)
           & Zero (8 * (SHA2.Bit_Index (B) - SHA2.Bit_Index (K'Length))))
   with
     Ghost,
     Pre  =>
       K'Length <= Byte_Index (B)
       or else 8 * SHA2.Bit_Index (K'Length) < Max_Length,
     Post =>
       HMAC_init'Result'First = 0
       and then HMAC_init'Result'Length = 8 * SHA2.Bit_Index (B);
```

</td></tr>
</table>

Steps 1 to 3 of FIPS 198-1: a key of exactly `B` bytes is used as it is;
a longer key is hashed and the digest padded with zeros to `B` bytes; a
shorter key is padded with zeros. The three guards become an
if-expression with the cases in the same order. `k` is `K'Length`, and
`Hk` is the generic formal rather than an argument. The precondition asks
that only a key that is hashed be short enough for the hash; that is what
Cryptol's type `[k * 8]` for `Hk` asks of the caller. The one deviation:
`HMAC_init` is `private` in `Main.cry` but public in SPARK, because the
implementation is proved against it
([foundation_spark-hmac-main.ads:114-117](../../src/hmac/foundation_spark-hmac-main.ads#L114-L117)).
The implementation's `Init_Key` has `HMAC_init` in its postcondition.

### `HMAC`

<table>
<tr><th>Cryptol: <a href="../../../algorithms/HMAC/Main.cry#L40-L47"><code>algorithms/HMAC/Main.cry:40-47</code></a></th>
<th>SPARK: <a href="../../src/hmac/foundation_spark-hmac-main.ads#L127-L144"><code>spark/src/hmac/foundation_spark-hmac-main.ads:127-144</code></a></th></tr>
<tr><td>

```cryptol
HMAC Hk Hn HL K text = 
    take (HL ((K0 ^ opad) # (Hn ((K0 ^ ipad) # text))))
  where
    K0   : [B * 8]                 // `K` after preprocessing to form
                                   // a `B`-byte key.
    K0   = HMAC_init Hk K
    opad = join (repeat`{B} 0x5C)  // [FIPS-PUB-198-1 Section 2.3]
    ipad = join (repeat`{B} 0x36)  // [FIPS-PUB-198-1 Section 2.3]
```

</td><td>

```ada
   function HMAC
     (K : Bytes; Text : SHA2.Bits; Lambda : SHA2.Bit_Index) return SHA2.Bits
   is
     (HL ((HMAC_init (K) xor Opad)
          & Hn ((HMAC_init (K) xor Ipad) & Text))
        (0 .. Lambda - 1))
   with
     Ghost,
     Pre  =>
       (K'Length <= Byte_Index (B)
        or else 8 * SHA2.Bit_Index (K'Length) < Max_Length)
       and then Text'First = 0
       and then Text'Length < Text_Limit
       and then 8 * SHA2.Bit_Index (B) + Text'Length < Max_Length
       and then 8 * (SHA2.Bit_Index (B) + SHA2.Bit_Index (L)) < Max_Length
       and then Lambda <= 8 * SHA2.Bit_Index (L),
     Post =>
       HMAC'Result'First = 0 and then HMAC'Result'Length = Lambda;
```

</td></tr>
</table>

The formula is the same: the outer hash of `K0 xor opad` followed by the
inner hash of `K0 xor ipad` followed by the text, cut to its first `λ`
bits. `^` is spelled `xor`, `#` is spelled `&`, and `take` is the slice
`(0 .. Lambda - 1)`. Cryptol's `λ` is a type parameter fixed by the
result type; SPARK passes it as the argument `Lambda`. The local `K0` is
written out as `HMAC_init (K)` at both places it is used. The
precondition is the Cryptol constraints `λ <= L * 8` and
`n < 2 ^^ B - 8 * B`, plus what the three hashes' input types ask of the
caller, each stated as a length below `Max_Length`
([foundation_spark-hmac-main.ads:152-159](../../src/hmac/foundation_spark-hmac-main.ads#L152-L159)).

### The SHA-256 instance

<table>
<tr><th>Cryptol: <a href="../../../packaging/Hash.cry#L71-L85"><code>packaging/Hash.cry:71-85</code></a></th>
<th>SPARK: <a href="../../src/hmac/foundation_spark-hmac-sha256.ads#L6-L12"><code>spark/src/hmac/foundation_spark-hmac-sha256.ads:6-12</code></a></th></tr>
<tr><td>

```cryptol
HMAC :
    { k, n }
    ( fin k, fin n, n < 2^^(BlockSize/8) - BlockSize
    , UpperLimit >= width (8 * k)
    , UpperLimit >= width (BlockSize - BlockSize % 8 + n)
    , UpperLimit >= width (BlockSize + DigestSize)
    )
 => [k][8]
 -> [n]
 -> [DigestSize]
HMAC = _HMAC::HMAC`{ B = BlockSize/8, L = DigestSize/8 } Hk Hn HL
  where
    Hk = hash
    Hn = hash
    HL = hash
```

</td><td>

```ada
package Foundation_Spark.HMAC.SHA256 is new Foundation_Spark.HMAC.Main
  (B          => 64,
   L          => 32,
   Max_Length => Foundation_Spark.SHA2.SHA256.Max_Length,
   Hk         => Foundation_Spark.SHA2.SHA256.Hash,
   Hn         => Foundation_Spark.SHA2.SHA256.Hash,
   HL         => Foundation_Spark.SHA2.SHA256.Hash);
```

</td></tr>
</table>

`packaging/Hash.cry` is a parameterised module.
[`algorithms/SHA2/SHA256.cry:5-9`](../../../algorithms/SHA2/SHA256.cry#L5-L9)
instantiates it with `_BlockSize = 512`, `_DigestSize = 256` and
`_UpperLimit = 64`, so its `HMAC` is `Main.cry`'s at `B = 64`, `L = 32`,
with SHA-256's `hash` for all three hash functions. The SPARK instance
uses the same values, and `SHA2.SHA256.Hash`, the SPARK spec of SHA-256's
`hash` (see [sha-256.md](sha-256.md)). Cryptol's `UpperLimit >= width x`
constraints say a message has fewer than `2 ^^ 64` bits; SPARK's
`Max_Length` is that bound. In Cryptol, `λ` is fixed at `DigestSize`
(256) by the result type `[DigestSize]`; in SPARK the instance keeps
`Lambda` as an argument, and every user of it passes 256.

## The Cryptol prelude in SPARK

`Main.cry` uses four prelude functions: `join`, `repeat`, `zero` and,
through `join`, `@` on bytes. `spark/src/cryptol/` states each one once,
as a generic. `foundation_spark-hmac.ads` instantiates them at HMAC's
types and wraps them as `Join`, `Repeat` and `Zero`.

`join` from bytes to bits:

<table>
<tr><th>Prelude generic: <a href="../../src/cryptol/foundation_spark-cryptol-join_split.ads#L44-L53"><code>spark/src/cryptol/foundation_spark-cryptol-join_split.ads:44-53</code></a></th>
<th>HMAC's instance: <a href="../../src/hmac/foundation_spark-hmac.ads#L42-L50"><code>spark/src/hmac/foundation_spark-hmac.ads:42-50</code></a></th></tr>
<tr><td>

```ada
   function Join (Xs : Words) return Bits is
     ([for I in 0 .. Bit_Index (Xs'Length) * Bit_Index (Width) - 1 =>
         Word_Bits.Bit
           (Xs (Xs'First + Word_Index (I / Bit_Index (Width))),
            Natural (I mod Bit_Index (Width)))])
   with
     Pre  => Xs'Length <= Bit_Index'Last / Bit_Index (Width),
     Post => Join'Result'First = Bit_Index'(0)
             and then Join'Result'Last
                      = Bit_Index (Xs'Length) * Bit_Index (Width) - 1;
```

</td><td>

```ada
   package Byte_Words is new Cryptol.Join_Split
     (Word        => Byte,
      Width       => 8,
      Shift_Right => Interfaces.Shift_Right,
      Word_Index  => Byte_Index,
      Words       => Bytes,
      Bit_Index   => SHA2.Bit_Index,
      Bits        => SHA2.Bits);
   --  The prelude's `@` and `join` between bytes [8] and bits.
```

</td></tr>
</table>

Bit `I` of the result is bit `I mod 8` of byte `I / 8`, most significant
bit first, as in Cryptol. `Word_Bits.Bit` is the prelude's `@` on a word.
[`foundation_spark-hmac.ads:68-73`](../../src/hmac/foundation_spark-hmac.ads#L68-L73)
wraps the instance as `HMAC.Join`, which is what `HMAC_init`, `Opad` and
`Ipad` call.

`repeat`:

<table>
<tr><th>Prelude generic: <a href="../../src/cryptol/foundation_spark-cryptol-sequences.ads#L33-L37"><code>spark/src/cryptol/foundation_spark-cryptol-sequences.ads:33-37</code></a></th>
<th>HMAC's instance and wrapper: <a href="../../src/hmac/foundation_spark-hmac.ads#L83-L87"><code>spark/src/hmac/foundation_spark-hmac.ads:83-87</code></a></th></tr>
<tr><td>

```ada
   function Repeat (Count : Index; X : Element) return Seq is
     ([for I in 0 .. Count - 1 => X])
   with
     Pre  => Count >= 0 and then Index'First <= 0,
     Post => Repeat'Result'First = 0 and then Repeat'Result'Length = Count;
```

</td><td>

```ada
   function Repeat (Count : Byte_Index; X : Byte) return Bytes is
     (Byte_Sequences.Repeat (Count, X))
   with
     Ghost,
     Post => Repeat'Result'First = 0 and then Repeat'Result'Length = Count;
```

</td></tr>
</table>

`Byte_Sequences` is the generic instantiated at bytes
([foundation_spark-hmac.ads:52-53](../../src/hmac/foundation_spark-hmac.ads#L52-L53)).
`zero` is the same pattern:
[`foundation_spark-cryptol-bit_sequences.ads:27-29`](../../src/cryptol/foundation_spark-cryptol-bit_sequences.ads#L27-L29)
states it, SHA-2 instantiates it as `SHA2.Sequences_Of_Bits`, and
[`foundation_spark-hmac.ads:95-99`](../../src/hmac/foundation_spark-hmac.ads#L95-L99)
wraps it as `HMAC.Zero`.

## The implementation and how gnatprove ties it to the spec

The executable code is `HMAC.SHA256_Impl`
([foundation_spark-hmac-sha256_impl.ads](../../src/hmac/foundation_spark-hmac-sha256_impl.ads),
[.adb](../../src/hmac/foundation_spark-hmac-sha256_impl.adb)). It differs
from the spec in representation, not in algorithm:

- it takes and returns bytes (`Byte_Array`), where the spec takes bits;
- it hashes with SHA-256's streaming implementation,
  `SHA2.SHA256_Stream`, so the text is fed to the inner hash in place and
  never copied into a concatenated message;
- it always returns the full 256-bit MAC (λ = 256).

`To_Bytes` re-indexes a byte array from 0 as the spec's `Bytes`, and
`SHA2.SHA256_Bytes.Bits_Of` gives the bits of a byte array, most
significant bit first. Both are ghost.

### The one-shot MAC and the key preprocessing

[`foundation_spark-hmac-sha256_impl.ads:76-84`](../../src/hmac/foundation_spark-hmac-sha256_impl.ads#L76-L84):

```ada
   function HMAC_SHA256 (Key : Byte_Array; Text : Byte_Array) return Digest
   with
     Pre  =>
       Key'Length < SHA2.SHA256_Bytes.Max_Bytes
       and then Text'Length < Max_Text,
     Post =>
       SHA2.SHA256_Bytes.Bits_Of (HMAC_SHA256'Result)
       = HMAC.SHA256.HMAC
           (To_Bytes (Key), SHA2.SHA256_Bytes.Bits_Of (Text), 256);
```

[`foundation_spark-hmac-sha256_impl.ads:63-67`](../../src/hmac/foundation_spark-hmac-sha256_impl.ads#L63-L67):

```ada
   function Init_Key (Key : Byte_Array) return Key_Block with
     Pre  => Key'Length < SHA2.SHA256_Bytes.Max_Bytes,
     Post =>
       SHA2.SHA256_Bytes.Bits_Of (Init_Key'Result)
       = HMAC.SHA256.HMAC_init (To_Bytes (Key));
```

The postconditions name the spec layer directly: the bits of the MAC are
the spec's `HMAC` at λ = 256, and the bits of the 64-byte block `K0` are
the spec's `HMAC_init`. `Max_Bytes` is `2 ** 61` bytes, SHA-256's
`2 ** 64` bits. `Max_Text` is `Max_Bytes - 64`, which is `Main.cry`'s
`n < 2 ^^ B - 8 * B` at `B = 64`, in bytes
([foundation_spark-hmac-sha256_impl.ads:44-48](../../src/hmac/foundation_spark-hmac-sha256_impl.ads#L44-L48)).

`HMAC_SHA256` is itself a short composition of the incremental interface,
[`foundation_spark-hmac-sha256_impl.adb:602-613`](../../src/hmac/foundation_spark-hmac-sha256_impl.adb#L602-L613):

```ada
   function HMAC_SHA256 (Key : Byte_Array; Text : Byte_Array) return Digest
   is
      C  : Context;
      C0 : Context with Ghost;
   begin
      Init (C, Key);
      C0 := C;
      Update (C, Text);
      Lemma_Update (C0, Text, C, Key, SHA2.SHA256_Stream.Empty, Text);
      Lemma_Final (C, Key, Text);
      return Final (C);
   end HMAC_SHA256;
```

`C0` and the two `Lemma_` calls are ghost: they guide the proof and are
not compiled.

### The incremental interface

A `Context` holds the inner SHA-256 context and `K0 xor opad`. It does not
hold the key or the text, so its meaning is stated by ghost predicates:
`Models (C, Key, M)` says `C` is HMAC under `Key` after the text `M`.
[`foundation_spark-hmac-sha256_impl.adb:52-56`](../../src/hmac/foundation_spark-hmac-sha256_impl.adb#L52-L56):

```ada
   function Models
     (C : Context; Key : Byte_Array; M : Byte_Array) return Boolean
   is (M'Length < Max_Text
       and then SHA2.SHA256_Stream.Models (C.Inner, Inner_Prefix (Key, M))
       and then C.O_Pad = Xor_Pad (Init_Key (Key), 16#5C#));
```

`Inner_Prefix (Key, M)` is `K0 xor ipad` followed by `M`, the message the
inner hash absorbs. `Init`, `Update` and `Final` are specified on
contexts,
[`foundation_spark-hmac-sha256_impl.ads:137-152`](../../src/hmac/foundation_spark-hmac-sha256_impl.ads#L137-L152):

```ada
   procedure Init (C : out Context; Key : Byte_Array) with
     Pre  => Key'Length < SHA2.SHA256_Bytes.Max_Bytes,
     Post =>
       Models (C, Key, SHA2.SHA256_Stream.Empty) and then Count (C) = 64;
   --  Starts HMAC-SHA-256 under Key: K0 (Init_Key), and an inner SHA-256
   --  context fed K0 xor ipad.
   --  @param C The context started.
   --  @param Key The key, of any length below 2 ** 61 bytes.

   procedure Update (C : in out Context; Data : Byte_Array) with
     Pre  =>
       Count (C) < SHA2.SHA256_Bytes.Max_Bytes
       and then Data'Length < SHA2.SHA256_Bytes.Max_Bytes - Count (C),
     Post =>
       Absorbed (C'Old, Data, C)
       and then Count (C) = Count (C'Old) + Data'Length;
```

and the two ghost lemmas carry the key and text to the spec. A caller
calls `Lemma_Update` after each `Update`, and `Lemma_Final` before
`Final`.
[`foundation_spark-hmac-sha256_impl.ads:174-197`](../../src/hmac/foundation_spark-hmac-sha256_impl.ads#L174-L197):

```ada
   procedure Lemma_Update
     (C0   : Context;
      Data : Byte_Array;
      C1   : Context;
      Key  : Byte_Array;
      M    : Byte_Array;
      M2   : Byte_Array)
   with
     Ghost,
     Pre  =>
       Key'Length < SHA2.SHA256_Bytes.Max_Bytes
       and then Data'Length < SHA2.SHA256_Bytes.Max_Bytes
       and then M2'Length < Max_Text
       and then Models (C0, Key, M)
       and then Absorbed (C0, Data, C1)
       and then M2'Length = M'Length + Data'Length
       and then
         (for all I in 0 .. SHA2.SHA256_Bytes.Byte_Index (M'Length) - 1 =>
            M2 (M2'First + I) = M (M'First + I))
       and then
         (for all I in 0 .. SHA2.SHA256_Bytes.Byte_Index (Data'Length) - 1 =>
            M2 (M2'First + SHA2.SHA256_Bytes.Byte_Index (M'Length) + I)
            = Data (Data'First + I)),
     Post => Models (C1, Key, M2);
```

[`foundation_spark-hmac-sha256_impl.ads:207-217`](../../src/hmac/foundation_spark-hmac-sha256_impl.ads#L207-L217):

```ada
   procedure Lemma_Final (C : Context; Key : Byte_Array; M : Byte_Array) with
     Ghost,
     Pre  =>
       Key'Length < SHA2.SHA256_Bytes.Max_Bytes and then Models (C, Key, M),
     Post =>
       M'Length < Max_Text
       and then Count (C) < SHA2.SHA256_Bytes.Max_Bytes
       and then
         SHA2.SHA256_Bytes.Bits_Of (Final (C))
         = HMAC.SHA256.HMAC
             (To_Bytes (Key), SHA2.SHA256_Bytes.Bits_Of (M), 256);
```

`Lemma_Update` says: if `C0` models the text `M`, and `C1` is `C0` after
`Data`, then `C1` models `M2`, which is `M` followed by `Data`.
`Lemma_Final` says: the MAC that `Final` returns from a context that
models `M` is, on the bits, the spec's `HMAC` of the key and `M`.

### What the HMAC proof rests on from SHA-256

Two results from SHA-256's own proof do most of the work (see
[sha-256.md](sha-256.md) for how they are proved). The streaming theorem,
[`foundation_spark-sha2-sha256_stream.ads:202-206`](../../src/sha2/foundation_spark-sha2-sha256_stream.ads#L202-L206):

```ada
   procedure Lemma_Final (C : Context; M : Byte_Array) with
     Ghost,
     Pre  => Models (C, M),
     Post => Count (C) < SHA256_Bytes.Max_Bytes
             and then Final (C) = SHA256_Bytes.Hash_Bytes (M);
```

with its companion `SHA256_Stream.Lemma_Update`
([lines 173-190](../../src/sha2/foundation_spark-sha2-sha256_stream.ads#L173-L190)),
which has the same shape as HMAC's `Lemma_Update`. And the byte-to-bit
refinement,
[`foundation_spark-sha2-sha256_bytes.ads:425-428`](../../src/sha2/foundation_spark-sha2-sha256_bytes.ads#L425-L428):

```ada
   procedure Lemma_Hash_Bytes (M : Byte_Array) with
     Ghost,
     Pre  => M'Length < Max_Bytes,
     Post => Bits_Of (Hash_Bytes (M)) = SHA256.Hash (Bits_Of (M));
```

### How the proof goes

gnatprove proves each subprogram against its contract. The argument runs
as follows.

1. **The key.** `Init_Key` copies a short key into a zeroed 64-byte block,
   or hashes a long key with `SHA256_Stream.Hash` and copies the 32-byte
   digest. Its body asserts, bit by bit, that the block's bits are
   `HMAC_init`'s: the key's bits, then zeros
   ([foundation_spark-hmac-sha256_impl.adb:543-596](../../src/hmac/foundation_spark-hmac-sha256_impl.adb#L543-L596)).
2. **The streams.** `Init` feeds `K0 xor ipad` to a fresh SHA-256 context
   and calls `SHA256_Stream.Lemma_Update`, so the context models
   `Inner_Prefix (Key, Empty)`. Each `Update` is followed by HMAC's
   `Lemma_Update`, which calls `Lemma_Prefix_Extends` (below) and then
   `SHA256_Stream.Lemma_Update` on the inner messages.
3. **The end.** `Lemma_Final` applies `SHA256_Stream.Lemma_Final` to the
   inner context, so the inner digest is `Hash_Bytes` of
   `K0 xor ipad` then the text. `Final` hashes `K0 xor opad` then that
   digest in a second context, with the same two stream lemmas.
4. **Bytes to bits.** The body lemma `Lemma_HMAC`
   ([foundation_spark-hmac-sha256_impl.adb:426-457](../../src/hmac/foundation_spark-hmac-sha256_impl.adb#L426-L457))
   turns both byte-level messages into the spec's bit-level ones:
   the bits of `K0 xor ipad` are the spec's `K0 ^ ipad`
   (`Lemma_Pad_Xor_Bits`), the bits of a block followed by bytes are the
   block's bits followed by theirs (`Lemma_Message_Bits`), and
   `Lemma_Hash_Bytes` turns each `Hash_Bytes` into the spec's
   `SHA256.Hash`. `Lemma_HMAC_Unfold` unfolds the spec's `HMAC` at
   λ = 256, where the slice is the whole outer digest.

Two kinds of helper lemma deserve a word. Ada's `=` on arrays is not the
provers' built-in equality, so a function applied to two arrays that are
`=` is not automatically `=`. `Lemma_Hash_Ext` proves that for
`SHA256.Hash`, by going through its padding, parsing and fold, and
`Lemma_Bits_Trans` chains `=` through function results
([foundation_spark-hmac-sha256_impl.adb:129-142](../../src/hmac/foundation_spark-hmac-sha256_impl.adb#L129-L142),
[364-374](../../src/hmac/foundation_spark-hmac-sha256_impl.adb#L364-L374)).
Several lemmas are also stated apart only so that the provers see one
step in a small context. `Lemma_Pad_Xor_Bits` ran out of time inside
`Lemma_HMAC` on x86_64
([adb:252-256](../../src/hmac/foundation_spark-hmac-sha256_impl.adb#L252-L256)).
`Lemma_Prefix_Extends` shows that putting `K0 xor ipad` in front of `M`
and of `M2` keeps `M2` "M then Data". Inside `Lemma_Update` it did not
prove in 60 s once `HMAC.Join` went through the prelude's generic; stated
apart, without `Init_Key` in context, it proves at once
([adb:692-702](../../src/hmac/foundation_spark-hmac-sha256_impl.adb#L692-L702)).

The result is a proof, for every key below `2 ** 61` bytes and every text
below `Max_Text` bytes, that `HMAC_SHA256`, and `Init`/`Update`/`Final`
used with the lemmas, compute the spec layer's `HMAC` at λ = 256 on the
bits. gnatprove does not compare anything with NSA's Cryptol; the next
section does.

## How it is checked against NSA's Cryptol

### The FFI check

[`spark/cryptol/SPARK/HMAC/SHA256.cry`](../../cryptol/SPARK/HMAC/SHA256.cry)
declares the SPARK functions, exported through C, as Cryptol `foreign`
functions, and compares them with `algorithms::SHA2::SHA256::HMAC`, which
is `packaging/Hash.cry`'s `HMAC` at SHA-256. It checks both layers: the
ghost spec `HMAC.SHA256.HMAC` (at λ = 256) and `HMAC_init`, reached
through ghost shims, and the executable `HMAC_SHA256`, `Init_Key` and
`Init`/`Update`/`Final` on a random chunking of the text.

A representative property,
[`SHA256.cry:119-123`](../../cryptol/SPARK/HMAC/SHA256.cry#L119-L123):

```cryptol
/** The SPARK HMAC.SHA256.HMAC is SHA256::HMAC on a k-byte key and an [n]. */
hmacAt :
  {k, n} (fin k, 61 >= width k, fin n, 64 >= width (512 + n)) =>
    [k][8] -> [n] -> Bit
hmacAt K text = sparkHMAC`{k, n} K text == SHA256::HMAC`{k, n} K text
```

`HMAC_init` is `private` in `Main.cry`, so no other module can call it.
The FFI module restates it as `hmacInit`, at `B = 64`, `L = 32` and
`Hk = SHA256::hash`, to check the SPARK `HMAC_init` and `Init_Key`
against it directly,
[`SHA256.cry:94-103`](../../cryptol/SPARK/HMAC/SHA256.cry#L94-L103):

```cryptol
/**
 * algorithms/HMAC/Main.cry's HMAC_init (private there), copied, at
 * B = 64, L = 32 and Hk = SHA256::hash: steps 1-3 of [FIPS-PUB-198-1
 * Section 4 Table 1].
 */
hmacInit : {k} (fin k, 64 >= width (8 * k)) => [k][8] -> [512]
hmacInit K
  | k == 64 => join K
  | k >  64 => SHA256::hash (join K) # (zero : [(64 - 32) * 8])
  | k <  64 => join K # (zero : [(64 - k) * 8])
```

The copy could in principle drift from NSA's. Every `HMAC` property also
exercises NSA's own `HMAC_init` inside `SHA256::HMAC`, which closes that
gap for the key lengths tested
([SHA256.cry:20-24](../../cryptol/SPARK/HMAC/SHA256.cry#L20-L24)).

Lengths are types in Cryptol, so each property lists the lengths it
covers, and `:check` draws random contents. Keys of 63, 64 and 65 bytes
select `HMAC_init`'s three cases. Texts of 0, 1, 55, 56, 63, 64, 65, 119,
120, 127 and 128 bytes sit at SHA-256's padding boundaries. Other
properties cover keys from 0 to 200 bytes under a 20-byte text, texts
that are not whole bytes (spec only), a fixed list of longer keys and
texts (executable only), and RFC 4231's test cases 1 to 7
([SHA256.cry:33-46](../../cryptol/SPARK/HMAC/SHA256.cry#L33-L46)). The
RFC 4231 property checks NSA's `SHA256::HMAC` itself as well as the
SPARK; the module notes that the repository's own HMAC tests exercise
only SHA-3
([SHA256.cry:16-18](../../cryptol/SPARK/HMAC/SHA256.cry#L16-L18)).

The modes and test counts, from
[`spark/cryptol/properties.txt:132-144`](../../cryptol/properties.txt#L132-L144)
(`check` is random testing with that many tests; `exhaust` with 1 test is
a property with no inputs, such as the known answers):

```text
SPARK/HMAC/SHA256.cry        | prop_HMAC_texts            | HMAC::Main::HMAC (SHA-256)           | check   | 3
SPARK/HMAC/SHA256.cry        | prop_HMAC_keys             | HMAC::Main::HMAC (SHA-256)           | check   | 5
SPARK/HMAC/SHA256.cry        | prop_HMAC_bits             | HMAC::Main::HMAC (SHA-256)           | check   | 5
SPARK/HMAC/SHA256.cry        | prop_HMAC_RFC4231          | HMAC::Main::HMAC (SHA-256)           | exhaust | 1
SPARK/HMAC/SHA256.cry        | prop_HMAC_init             | HMAC::Main::HMAC_init (SHA-256)      | check   | 5
SPARK/HMAC/SHA256.cry        | prop_HMAC_SHA256_texts     | HMAC::Main::HMAC (SHA-256)           | check   | 30
SPARK/HMAC/SHA256.cry        | prop_HMAC_SHA256_keys      | HMAC::Main::HMAC (SHA-256)           | check   | 30
SPARK/HMAC/SHA256.cry        | prop_HMAC_SHA256_long      | HMAC::Main::HMAC (SHA-256)           | check   | 3
SPARK/HMAC/SHA256.cry        | prop_HMAC_SHA256_RFC4231   | HMAC::Main::HMAC (SHA-256)           | exhaust | 1
SPARK/HMAC/SHA256.cry        | prop_HMAC_Chunked          | HMAC::Main::HMAC (SHA-256)           | check   | 30
SPARK/HMAC/SHA256.cry        | prop_HMAC_Chunked_long     | HMAC::Main::HMAC (SHA-256)           | check   | 3
SPARK/HMAC/SHA256.cry        | prop_HMAC_Chunked_RFC4231  | HMAC::Main::HMAC (SHA-256)           | check   | 100
SPARK/HMAC/SHA256.cry        | prop_Init_Key              | HMAC::Main::HMAC_init (SHA-256)      | check   | 100
```

Each test of a property such as `prop_HMAC_texts` covers every length
combination it lists (33 for that one), so a small count still means many
comparisons. As the module says, the executable functions "carry the
samples of about 100; the ghost spec is checked directly at a handful of
tests" ([SHA256.cry:43-46](../../cryptol/SPARK/HMAC/SHA256.cry#L43-L46)).

### SAW

SAW proves the compiled code equal to NSA's Cryptol by symbolic
execution. It needs concrete loop bounds and buffer sizes, so it proves
one key length and one text length at a time.

**The implementation.**
[`spark/saw/sha256_impl.saw:259-266`](../../saw/sha256_impl.saw#L259-L266)
proves `HMAC_SHA256` against `Main.cry`'s `HMAC` at `λ = 256`, `B = 64`,
`L = 32`, with SHA-256's `hash` for all three hash functions, the form
`packaging/Hash.cry` instantiates:

```text
hmac_0_0    <- verify_hmac_in sha256_impl_lax [compress_lax] 0 0 "0" "0" " (lax arithmetic module)"
                 [] "z3, nothing uninterpreted (no symbolic input)";
hmac_32_3   <- verify_hmac 32  3  "32"  "3"  [];
hmac_32_32  <- verify_hmac 32  32 "32"  "32" [];
hmac_64_3   <- verify_hmac 64  3  "64"  "3"  [];
hmac_64_32  <- verify_hmac 64  32 "64"  "32" [];
hmac_65_3   <- verify_hmac 65  3  "65"  "3"  [hash_65];
hmac_100_32 <- verify_hmac 100 32 "100" "32" [hash_100];
```

The (key, text) lengths in bytes are (0, 0), (32, 3), (32, 32), (64, 3),
(64, 32), (65, 3) and (100, 32): keys shorter than the block, equal to
it, and longer. SAW loads `HMAC` from `Main.cry` directly, because SAW 1.6
cannot load `packaging/Hash.cry`'s instance ([saw.md, "SHA-256 and
HMAC-SHA-256"](../saw.md#sha-256-and-hmac-sha-256)). All seven are proved in
[`spark/saw/results.txt:215-221`](../../saw/results.txt#L215-L221), from
0.57 s to 1.53 s each, and 9.96 s at (0, 0).

**The spec layer.**
[`spark/saw/sha256_spec_hmac.saw`](../../saw/sha256_spec_hmac.saw) proves
the bitcode of the ghost `HMAC.SHA256.HMAC` against `Main.cry`'s `HMAC`,
and `HMAC.SHA256.HMAC_init` against
[`spark/saw/HMACInit.cry`](../../saw/HMACInit.cry), a text-for-text copy
of the private `HMAC_init`. The copy is tied to NSA's: the proof of `HMAC`
against `Main.cry`'s own `HMAC` uses the `HMAC_init` results as its
overrides ([sha256_spec_hmac.saw:15-18](../../saw/sha256_spec_hmac.saw#L15-L18)).
[`spark/saw/sha256_spec.saw:159-169`](../../saw/sha256_spec.saw#L159-L169)
chooses the lengths: by default one per case of `HMAC_init`, and four
more with `SAW_LONG=1`, since each extra length re-proves the SHA-256
lemmas at new positions of the secondary stack
([sha256_spec.saw:151-157](../../saw/sha256_spec.saw#L151-L157)).

| (key, text) bytes | run | `HMAC.SHA256.HMAC` proved |
|---|---|---|
| (32, 3) | default | 15.41 s, [results.txt:1133](../../saw/results.txt#L1133) |
| (64, 32) | default | 27.07 s, [results.txt:1146](../../saw/results.txt#L1146) |
| (65, 3) | default | 16.77 s, [results.txt:1169](../../saw/results.txt#L1169) |
| (0, 0) | `SAW_LONG=1` | 872.07 s, [results-long.txt:1255](../../saw/results-long.txt#L1255) |
| (32, 32) | `SAW_LONG=1` | 18.86 s, [results-long.txt:1268](../../saw/results-long.txt#L1268) |
| (64, 3) | `SAW_LONG=1` | 23.83 s, [results-long.txt:1281](../../saw/results-long.txt#L1281) |
| (100, 32) | `SAW_LONG=1` | 19.19 s, [results-long.txt:1304](../../saw/results-long.txt#L1304) |

The prelude instances HMAC uses are also proved on their own: `Join` at
keys of 0, 32, 64, 65 and 100 bytes and `Repeat` at `[64][8]`
([results.txt:1213-1218](../../saw/results.txt#L1213-L1218)). Two
negative controls show the HMAC proofs can fail: a version of
`HMAC_SHA256` with the key reversed, and of the spec's `HMAC_init` with
the key reversed, are both refuted with counterexamples
([results.txt:1224](../../saw/results.txt#L1224),
[1229](../../saw/results.txt#L1229)).

These SAW records were made at commit `82b10e6`
([results.txt:9](../../saw/results.txt#L9)). The HMAC and SHA-2 sources
and NSA's Cryptol are unchanged between that commit and `6210b99`.

### What is proved for all inputs, and what is not

- **For all inputs (gnatprove):** the executable `HMAC_SHA256` and
  `Init_Key` equal the SPARK spec layer's `HMAC` (at λ = 256) and
  `HMAC_init` on the bits, for every key below `2 ** 61` bytes and every
  text below `Max_Text` bytes. So does `Final` after `Init` and any
  sequence of `Update` calls, through `Lemma_Update` and `Lemma_Final`.
- **At fixed lengths (SAW):** the executable `HMAC_SHA256`, and the ghost
  spec's `HMAC` and `HMAC_init`, equal NSA's Cryptol at the (key, text)
  lengths listed above, for all key and text contents at those lengths.
- **By testing (FFI):** the spec layer and the executables agree with
  NSA's Cryptol on random contents at the lengths the properties list,
  and on RFC 4231's known answers.
- **By reading:** that the spec layer says the same thing as `Main.cry`
  for every length. This page sets the two side by side for that reason.
- **Not covered:** λ below 256 is not used by the implementation, and is
  not proved by SAW ([saw.md](../saw.md)). The spec's `HMAC` accepts any
  `Lambda`, and RFC 4231 case 5 (truncated to 128 bits) is checked by FFI
  only by truncating the full MAC.

## Where spec and implementation are not one-to-one

The board pairs each Cryptol declaration with one spec entity and one
implementation entity
([spark/scripts/board-rows.txt:153-160](../../scripts/board-rows.txt#L153-L160)):
`HMAC` with `HMAC.SHA256.HMAC` and `SHA256_Impl.HMAC_SHA256`, and
`HMAC_init` with `HMAC.SHA256.HMAC_init` and `SHA256_Impl.Init_Key`. The
section ["Where spec and implementation are not one-to-one"](../proving.md#where-spec-and-implementation-are-not-one-to-one) lists
no HMAC row. The differences are of representation:

- The implementation works on bytes and fixes λ at 256; the spec works on
  bits and takes λ as an argument.
- The incremental `Init`/`Update`/`Final` has no Cryptol counterpart. It
  computes the same function as `HMAC_SHA256` (which is built from it),
  so it adds no row.
- The implementation hashes through `SHA2.SHA256_Stream` rather than
  through the spec's `Hash`; SHA-256's own proof (`Lemma_Final`,
  `Lemma_Hash_Bytes`) ties the two.
- `opad` and `ipad` are local definitions in Cryptol and functions in the
  SPARK spec; the implementation computes them as `Xor_Pad (K0, 16#5C#)`
  and `Xor_Pad (K0, 16#36#)` on bytes.
