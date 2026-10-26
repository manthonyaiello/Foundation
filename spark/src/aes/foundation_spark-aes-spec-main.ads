--  The bit sequences of algorithms/AES/Main.cry [FIPS-PUB-197 Section 5]:
--  the types and the conversions that Main.cry's Encrypt and Decrypt
--  apply, which have no {k}.
--
--  Main.cry's Encrypt and Decrypt take a key [k] and a block [128] as bit
--  sequences. As throughout the spec layer, a bit
--  sequence is a ghost Boolean array (Bits) with an integer index wide
--  enough for AES's longest, a 256-bit key, and Cryptol's join and split
--  between [128] and Block are stated here over it. Cryptol sequences are
--  big-endian: bit 0 of a [8] is the most significant bit of the Byte, and
--  byte 0 of a [128] is its first eight bits.
--
--  Main.cry's record AES`{k} of Encrypt and Decrypt is the generic AES_K:
--  AES`{k}.Encrypt is AES_K's Encrypt, and Main.cry's
--  AES128 = AES`{128} is the instance Spec.AES128, so AES128.Encrypt is
--  Spec.AES128.Encrypt, as in the Cryptol. The split of a key [k] into
--  [Nk k]AESWord depends on k, so it is there too (AES_K.Split_Key).
--  Main.cry's property EncryptInverts is in Spec.Properties.
--
--  Cryptol's join and split between bytes and bits, and @ on a byte, come
--  from the Cryptol prelude in SPARK (Foundation_Spark.Cryptol): the
--  instance Byte_Bits of Join_Split at [8].

with Interfaces;
with Foundation_Spark.Cryptol.Join_Split;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.AES.Spec.Main with
  SPARK_Mode,
  Pure,
  Ghost
is

   use Types;

   use type Types.Byte;

   type Bit_Index is range 0 .. 256;
   --  The index, or the length, of an AES bit sequence. The longest is a
   --  key [k] at k = 256 (Main.cry's Key k: k is 128, 192 or 256), so its
   --  indices are 0 .. 255 and its length 256; a block [128] is shorter.
   --  Arithmetic on indices (From + 7 in Byte_At, 8 * Key'Length - 1 in
   --  Impl.Main.Join_Key) is proved free of overflow in this range and in
   --  Bit_Index'Base. Unlike SHA-2's Bit_Index (Foundation_Spark.SHA2),
   --  which must hold message lengths past 2 ** 64, AES needs no wider
   --  type. And 256 needs nine bits, so no value is held in 8 bits, where
   --  LLVM, whose getelementptr indices are signed, would read 255 as
   --  -1.

   type Bits is array (Bit_Index range <>) of Boolean;
   --  A Cryptol bit sequence [n], indexed from 0 as Cryptol's @ indexes
   --  it. Element 0 is the Cryptol's first (most significant) bit.

   subtype Block_Bits is Bits (0 .. 127);
   --  Main.cry's [128], a block as a bit vector: the in and the result of
   --  Encrypt and Decrypt.

   function Is_Key_Bits (K : Key_Size; Key : Bits) return Boolean
   is (Key'First = 0 and then Key'Last = Bit_Index (K - 1));
   --  The typing key : [k], with Cryptol's zero-based indexing, for a key
   --  size K that is not static: the precondition of the dispatchers
   --  Dispatch.Encrypt and Dispatch.Decrypt. (In AES_K, where K is
   --  static, it is the subtype Key_Bits.)
   --  @param K The key size in bits.
   --  @param Key The key bits.
   --  @return Whether Key has K bits from index 0.

   subtype Byte_Index is Natural range 0 .. 31;
   --  The indices of a sequence of bytes: at most 32 bytes, the 256 bits
   --  of the longest AES bit sequence, so that its length in bits is a
   --  Bit_Index.

   type Bytes is array (Byte_Index range <>) of Byte;
   --  A sequence of bytes, Cryptol's [n][8], the word side of Byte_Bits.

   package Byte_Bits is new Cryptol.Join_Split
     (Word        => Byte,
      Width       => 8,
      Shift_Right => Interfaces.Shift_Right,
      Word_Index  => Byte_Index,
      Words       => Bytes,
      Bit_Index   => Bit_Index,
      Bits        => Bits);
   --  The prelude's join, split and @ between bytes [8] and AES's bits.

   function Byte_At (Bs : Bits; From : Bit_Index) return Byte
   is (Byte_Bits.Value (Bs, From, 8))
   with Pre => Bs'Last >= 7 and then From >= Bs'First
               and then From <= Bs'Last - 7;
   --  The [8] at bits From .. From + 7 of Bs as a Byte, big-endian: the
   --  element type of Cryptol's split at [n * 8] -> [n][8], which takes
   --  byte J of the result from bits 8 * J .. 8 * J + 7. The prelude's
   --  Join_Split.Value.
   --  @param Bs The bit sequence.
   --  @param From The index of the byte's first (most significant) bit.
   --  @return The eight bits as a Byte.

   function Bit_Of (B : Byte; J : Natural) return Boolean
   is (Byte_Bits.Word_Bits.Bit (B, J))
   with Pre => J <= 7;
   --  Bit J of a [8], big-endian: bit 0 is the most significant. The
   --  element type of Cryptol's join at [n][8] -> [n * 8], which places
   --  byte I at bits 8 * I .. 8 * I + 7. The prelude's @ on a word.
   --  @param B The byte.
   --  @param J The bit's position in the Cryptol [8], 0 .. 7.
   --  @return Bit J of B.

   function Split_Block (Bs : Block_Bits) return Block
   is [for I in Block_Index => Byte_Bits.Split_At (Bs, Bit_Index (I))];
   --  Main.cry: split in, Cryptol's split at [128] -> [16][8] = Block:
   --  byte I is word I of the prelude's Split_At, bits 8 * I .. 8 * I + 7.
   --  @param Bs The block as 128 bits.
   --  @return The block as 16 bytes.

   function Join_Block (B : Block) return Block_Bits
   is (Byte_Bits.Join (Bytes (B)));
   --  Main.cry: join (Cipher`{k} ...), Cryptol's join at Block = [16][8]
   --  -> [128], the inverse of Split_Block: the prelude's Join. Bit N is
   --  bit N mod 8 of byte N / 8.
   --  @param B The block as 16 bytes.
   --  @return The block as 128 bits.

end Foundation_Spark.AES.Spec.Main;
