--  The types AES is stated in, mirroring algorithms/AES/Types.cry
--  [FIPS-PUB-197 Sections 2.1, 2.3 and 5].
--
--  Key-size polymorphism. The Cryptol is polymorphic in the key size k
--  under the constraint Key k ({k} (Key k) => ...). Following the
--  campaign's decision, the SPARK states it with unconstrained arrays
--  (Key_Words for [Nk k]AESWord, Round_Keys for [Nr k + 1]Block) and the
--  constraint as a precondition: a subprogram that the Cryptol types
--  {k} (Key k) => takes the key size K as an explicit Natural parameter,
--  in the place of the Cryptol's type application, and requires
--  Is_Key_Words (K, ...) or Is_Round_Keys (K, ...). Cryptol's FFI passes
--  a numeric type parameter as a leading size_t argument, so the explicit
--  K is also the shape of the exported function.
--
--  This unit is not ghost: the implementation layer uses the same types.

with Interfaces;

package Foundation_Spark.AES.Spec.Types with
  SPARK_Mode,
  Pure
is

   subtype Byte is Interfaces.Unsigned_8;
   --  A byte, the Cryptol [8]. Cryptol bit sequences are big-endian:
   --  bit 0 of a [8] (its head) is the most significant bit of the Byte.

   type Byte_Table is array (Byte) of Byte;
   --  A table of 256 bytes indexed by a byte, the Cryptol [256][8] of the
   --  S-boxes (SBox.cry), read with @.

   subtype Block_Index is Natural range 0 .. 15;
   --  The indices of a Block.

   type Block is array (Block_Index) of Byte;
   --  Types.cry: type Block = [16][8]. The input, output, State and Round
   --  Key [FIPS-PUB-197 Section 2.1].

   subtype AESWord_Index is Natural range 0 .. 3;
   --  The indices of an AESWord, and of the columns of a Block.

   type AESWord is array (AESWord_Index) of Byte;
   --  Types.cry: type AESWord = [4][8], a 32-bit word as four bytes
   --  [FIPS-PUB-197 Section 2.1].

   type Columns is array (AESWord_Index) of AESWord;
   --  A Block split into its four columns, the Cryptol [4]AESWord that
   --  split : Block -> [4]AESWord returns (Cipher.cry, MixColumns).

   function Split (Bs : Block) return Columns
   is [for J in AESWord_Index => [for I in AESWord_Index => Bs (4 * J + I)]];
   --  Cryptol's split at type Block -> [4]AESWord: column J is bytes
   --  4 * J .. 4 * J + 3.
   --  @param Bs The block to split.
   --  @return Its four columns, in order.

   function Join (Ws : Columns) return Block
   is [for I in Block_Index => Ws (I / 4) (I mod 4)];
   --  Cryptol's join at type [4]AESWord -> Block, the inverse of Split.
   --  @param Ws The four columns.
   --  @return Their concatenation.

   function Key (K : Natural) return Boolean
   is (K mod 64 = 0 and then K / 64 >= 2 and then K / 64 <= 4);
   --  Types.cry: type constraint Key k = (fin k, k % 64 == 0,
   --  k / 64 >= 2, k / 64 <= 4). The standard key sizes 128, 192 and 256
   --  [FIPS-PUB-197 Sections 1, 5 and 6.1]. Fin k holds of any Natural.
   --  @param K A key size in bits.
   --  @return Whether K is 128, 192 or 256.

   function Nk (K : Natural) return Positive
   is (K / 32)
   with Pre => Key (K);
   --  Types.cry: type Nk k = k / 32. The number of 32-bit words in the
   --  key: 4, 6 or 8 [FIPS-PUB-197 Sections 2.3 and 5].
   --  @param K The key size in bits.
   --  @return K / 32.

   function Nr (K : Natural) return Positive
   is (Nk (K) + 6)
   with Pre => Key (K);
   --  Types.cry: type Nr k = Nk k + 6. The number of rounds: 10, 12 or 14
   --  [FIPS-PUB-197 Sections 2.3 and 5].
   --  @param K The key size in bits.
   --  @return Nk (K) + 6.

   Max_Nk : constant := 8;
   --  Nk (256), the largest Nk that Key allows.

   Max_Nr : constant := 14;
   --  Nr (256), the largest Nr that Key allows.

   subtype Key_Word_Index is Natural range 0 .. Max_Nk - 1;
   --  The indices a Key_Words array may use.

   type Key_Words is array (Key_Word_Index range <>) of AESWord;
   --  The Cryptol [Nk k]AESWord, the cipher key as words (the input of
   --  KeyExpansion.cry's KeyExpansion). Its length is fixed by K through
   --  Is_Key_Words.

   function Is_Key_Words (K : Natural; W : Key_Words) return Boolean
   is (Key (K) and then W'First = 0 and then W'Length = Nk (K));
   --  The typing W : [Nk k]AESWord under the constraint Key k, with
   --  Cryptol's zero-based indexing.
   --  @param K The key size in bits.
   --  @param W The key words.
   --  @return Whether K is a key size and W has Nk (K) words from index 0.

   subtype Round_Key_Index is Natural range 0 .. Max_Nr;
   --  The indices a Round_Keys array may use.

   type Round_Keys is array (Round_Key_Index range <>) of Block;
   --  The Cryptol [Nr k + 1]Block, the key schedule (the output of
   --  KeyExpansion and the first argument of Cipher.cry's Cipher and
   --  InvCipher). Its length is fixed by K through Is_Round_Keys.

   function Is_Round_Keys (K : Natural; W : Round_Keys) return Boolean
   is (Key (K) and then W'First = 0 and then W'Length = Nr (K) + 1);
   --  The typing W : [Nr k + 1]Block under the constraint Key k, with
   --  Cryptol's zero-based indexing.
   --  @param K The key size in bits.
   --  @param W The round keys.
   --  @return Whether K is a key size and W has Nr (K) + 1 blocks from
   --  index 0.

end Foundation_Spark.AES.Spec.Types;
