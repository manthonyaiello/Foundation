--  The keyed-Hash Message Authentication Code (HMAC) [FIPS-PUB-198-1],
--  mirroring algorithms/HMAC/Main.cry. The spec layer is the generic Main
--  (Main.cry, parameterized by the hash functions as the Cryptol's `HMAC`
--  takes them as arguments), and its instance for SHA-256, SHA256, which
--  instantiates it as packaging/Hash.cry's `HMAC` does for
--  algorithms/SHA2/SHA256.cry.
--
--  This package holds what Main.cry takes from Cryptol's prelude at the
--  types HMAC uses it: byte sequences `[k][8]`, their `join`, `repeat` and
--  `zero`. Messages, keys after `join` and digests are SHA2's bit sequences
--  (SHA2.Bits), the same type the hash functions take and return.

with Interfaces;
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

   function Byte_Bit (X : Byte; J : Natural) return Boolean is
     ((Interfaces.Shift_Right (X, 7 - J) and 1) = 1)
   with
     Ghost,
     Pre => J < 8;
   --  Bit J of a byte, Cryptol's `x @ j` on `[8]`: most significant bit
   --  first, so bit J has weight 2 ** (7 - J).
   --  @param X The byte.
   --  @param J The bit's position, below 8.
   --  @return Whether that bit is 1.

   function Join (K : Bytes) return SHA2.Bits is
     ([for I in 0 .. 8 * SHA2.Bit_Index (K'Length) - 1 =>
         Byte_Bit (K (K'First + Byte_Index (I / 8)), Natural (I mod 8))])
   with
     Ghost,
     Post => Join'Result'First = 0
             and then Join'Result'Length = 8 * SHA2.Bit_Index (K'Length);
   --  Cryptol's `join : [k][8] -> [k * 8]`, as Main.cry applies it to the
   --  key (Main.cry:63 to :65) and to the pads (Main.cry:46 and :47):
   --  each byte's bits in order, most significant first, so bit I is bit
   --  I mod 8 of byte I / 8.
   --  @param K The bytes.
   --  @return Their 8 * K'Length bits, indexed from 0.

   function Repeat (Count : Byte_Index; X : Byte) return Bytes is
     ([for I in 0 .. Count - 1 => X])
   with
     Ghost,
     Post => Repeat'Result'First = 0 and then Repeat'Result'Length = Count;
   --  Cryptol's `repeat`{Count} X` at `[Count][8]`, as Main.cry builds the
   --  pads (Main.cry:46 and :47): Count copies of the byte X.
   --  @param Count The number of bytes.
   --  @param X The byte repeated.
   --  @return Count copies of X, indexed from 0.

   function Zero (Count : SHA2.Bit_Index) return SHA2.Bits is
     ([for I in 0 .. Count - 1 => False])
   with
     Ghost,
     Post => Zero'Result'First = 0 and then Zero'Result'Length = Count;
   --  Cryptol's `zero` at type `[Count]`, as HMAC_init pads the key with it
   --  (Main.cry:64 and :65): Count zero bits.
   --  @param Count The number of bits.
   --  @return Count bits, all 0, indexed from 0.

end Foundation_Spark.HMAC;
