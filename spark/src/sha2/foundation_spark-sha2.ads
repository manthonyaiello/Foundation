--  The Secure Hash Algorithm 2 (SHA-2) family [FIPS-PUB-180-4], mirroring
--  algorithms/SHA2/. The spec layer is one child per Cryptol module:
--  Notation (Notation.cry), Functions (Functions.cry), Preprocessing
--  (Preprocessing.cry) and the generic Main (Main.cry), instantiated for
--  SHA-256 as SHA256 (SHA256.cry).

with Interfaces;
with Foundation_Spark.Cryptol.Bit_Sequences;

package Foundation_Spark.SHA2 with
  SPARK_Mode,
  Pure
is

   type Words_32 is array (Natural range <>) of Interfaces.Unsigned_32;
   --  A sequence of 32-bit words, Cryptol's `[n][32]`, indexed from 0 as
   --  Cryptol's `@` is. The actual for Main's Word_Vector in the SHA-256
   --  instance, and the type of K_256 and H0_256.

   type Bit_Index is range 0 .. 2 ** 126;
   --  A position in, or a length of, a bit sequence: the values of
   --  Cryptol's type-level naturals `l`, `k` and `N` in `hash`
   --  (Main.cry:55). A 128-bit integer: messages are below 2 ** 64 bits
   --  (`width l <= 2 * w` at w = 32), and padding adds at most one block
   --  and a length field to that. The bound leaves the base type room for
   --  a length (Last + 1) without overflow.

   type Bits is array (Bit_Index range <>) of Boolean;
   --  A bit sequence, Cryptol's `[l]`, indexed from 0 as Cryptol's `@`
   --  is: element 0 is the first (most significant) bit. Used only in
   --  ghost code, the spec layer's messages and digests.

   package Sequences_Of_Bits is new Cryptol.Bit_Sequences (Bit_Index, Bits);
   --  The prelude's `zero` and numeric literals at the bit sequences [l].

   function Ceil_Div (A, B : Bit_Index) return Bit_Index is
     ((A + (B - 1)) / B)
   with
     Ghost,
     Pre => B > 0 and then A <= Bit_Index'Last - B;
   --  Cryptol's ceiling division `a /^ b` on naturals, as Main.cry:59
   --  uses it for `type N`: the least n with n * b >= a. The same
   --  statement as the prelude's Numeric.Ceil_Div, kept inline (#75): as
   --  a call of a Numeric instance, SHA256_Bytes' Lemma_Pad_Bytes_Bits
   --  lost its proof at level 2.
   --  @param A The dividend.
   --  @param B The divisor, positive.
   --  @return A divided by B, rounded up.

   function Ceil_Mod (A, B : Bit_Index) return Bit_Index is
     (Ceil_Div (A, B) * B - A)
   with
     Ghost,
     Pre => B > 0 and then A <= Bit_Index'Last - B;
   --  Cryptol's ceiling modulus `a %^ b` on naturals, as Main.cry:58 uses
   --  it for `type k`: `b * (a /^ b) - a`, the distance from A up to the
   --  next multiple of B. Kept inline, as Ceil_Div is.
   --  @param A The dividend.
   --  @param B The divisor, positive.
   --  @return What A lacks of a multiple of B.

   function To_Bits (Value, Width : Bit_Index) return Bits is
     (Sequences_Of_Bits.Literal (Value, Width))
   with
     Ghost,
     Post =>
       To_Bits'Result'First = 0 and then To_Bits'Result'Length = Width;
   --  A natural number as a Width-bit sequence, Cryptol's literal
   --  `(`value : [width])`, as Preprocessing.cry:23 writes the message
   --  length `(`l : [2 * w])`: most significant bit first. The prelude's
   --  Bit_Sequences.Literal states it, by recursion on the width: the
   --  last bit is Value mod 2, and the bits before it are Value / 2 in
   --  Width - 1 bits. Cryptol rejects a literal that does not fit its
   --  type; here a Value of 2 ** Width or more keeps its Width low bits,
   --  and callers (Main's Pad) require that it fits.
   --  @param Value The number, below 2 ** Width.
   --  @param Width The number of bits.
   --  @return The Width-bit big-endian representation of Value, indexed
   --  from 0.

end Foundation_Spark.SHA2;
