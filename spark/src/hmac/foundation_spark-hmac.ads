--  The keyed-Hash Message Authentication Code (HMAC) [FIPS-PUB-198-1],
--  mirroring algorithms/HMAC/Main.cry. The spec layer is the generic Main
--  (Main.cry, parameterized by the hash functions as the Cryptol's `HMAC`
--  takes them as arguments), and its instance for SHA-256, SHA256, which
--  instantiates it as packaging/Hash.cry's `HMAC` does for
--  algorithms/SHA2/SHA256.cry.
--
--  This package holds what Main.cry takes from Cryptol's prelude at the
--  types HMAC uses it: byte sequences `[k][8]`, their `join`, `repeat` and
--  `zero`, each an instance of the Cryptol prelude in SPARK
--  (Foundation_Spark.Cryptol) at these types. Messages, keys after `join`
--  and digests are SHA2's bit sequences (SHA2.Bits), the same type the
--  hash functions take and return.

with Interfaces;
with Foundation_Spark.Cryptol.Join_Split;
with Foundation_Spark.Cryptol.Sequences;
with Foundation_Spark.SHA2;

package Foundation_Spark.HMAC with
  SPARK_Mode,
  Pure
is

   use type Interfaces.Unsigned_8;
   use type SHA2.Bit_Index;

   subtype Byte is Interfaces.Unsigned_8;
   --  A byte, Cryptol's `[8]`.

   type Byte_Index is range 0 .. 2 ** 62;
   --  A position in, or a length of, a byte sequence: the values of
   --  Main.cry's `k`, the key's length in bytes. A key that is hashed
   --  has fewer than 2 ** 61 bytes (its 8 * k bits are a message for the
   --  hash, below SHA2's 2 ** 64), and the bound leaves the base type
   --  room for a length (Last + 1) and its 8 * Length bits.

   type Bytes is array (Byte_Index range <>) of Byte;
   --  A sequence of bytes, Cryptol's `[k][8]` (the type of HMAC's key
   --  `K`), indexed from 0 as Cryptol's `@` is.

   package Byte_Words is new Cryptol.Join_Split
     (Word        => Byte,
      Width       => 8,
      Shift_Right => Interfaces.Shift_Right,
      Word_Index  => Byte_Index,
      Words       => Bytes,
      Bit_Index   => SHA2.Bit_Index,
      Bits        => SHA2.Bits);
   --  The prelude's `@` and `join` between bytes [8] and bits.

   package Byte_Sequences is new Cryptol.Sequences
     (Index => Byte_Index, Element => Byte, Seq => Bytes);
   --  The prelude's `repeat` at byte sequences.

   function Byte_Bit (X : Byte; J : Natural) return Boolean is
     (Byte_Words.Word_Bits.Bit (X, J))
   with
     Ghost,
     Pre => J < 8;
   --  Bit J of a byte, Cryptol's `x @ j` on `[8]`, as the prelude's
   --  Words.Bit states it: most significant bit first, so bit J has
   --  weight 2 ** (7 - J).
   --  @param X The byte.
   --  @param J The bit's position, below 8.
   --  @return Whether that bit is 1.

   function Join (K : Bytes) return SHA2.Bits is
     (Byte_Words.Join (K))
   with
     Ghost,
     Post => Join'Result'First = 0
             and then Join'Result'Length = 8 * SHA2.Bit_Index (K'Length);
   --  Cryptol's `join : [k][8] -> [k * 8]`, as Main.cry applies it to the
   --  key (Main.cry:63 to :65) and to the pads (Main.cry:46 and :47), as
   --  the prelude's Join_Split.Join states it: each byte's bits in order,
   --  most significant first, so bit I is bit I mod 8 of byte I / 8.
   --  Through the instance, SHA256_Impl.Lemma_Update needs its prefix
   --  reasoning stated apart (Lemma_Prefix_Extends there says why).
   --  @param K The bytes.
   --  @return Their 8 * K'Length bits, indexed from 0.

   function Repeat (Count : Byte_Index; X : Byte) return Bytes is
     (Byte_Sequences.Repeat (Count, X))
   with
     Ghost,
     Post => Repeat'Result'First = 0 and then Repeat'Result'Length = Count;
   --  Cryptol's `repeat`{Count} X` at `[Count][8]`, as Main.cry builds the
   --  pads (Main.cry:46 and :47), as the prelude's Sequences.Repeat states
   --  it: Count copies of the byte X.
   --  @param Count The number of bytes.
   --  @param X The byte repeated.
   --  @return Count copies of X, indexed from 0.

   function Zero (Count : SHA2.Bit_Index) return SHA2.Bits is
     (SHA2.Sequences_Of_Bits.Zero (Count))
   with
     Ghost,
     Post => Zero'Result'First = 0 and then Zero'Result'Length = Count;
   --  Cryptol's `zero` at type `[Count]`, as HMAC_init pads the key with it
   --  (Main.cry:64 and :65), as the prelude's Bit_Sequences.Zero states
   --  it: Count zero bits.
   --  @param Count The number of bits.
   --  @return Count bits, all 0, indexed from 0.

end Foundation_Spark.HMAC;
