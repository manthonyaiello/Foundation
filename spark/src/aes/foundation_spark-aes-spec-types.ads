--  The types AES is stated in, mirroring algorithms/AES/Types.cry
--  [FIPS-PUB-197 Sections 2.1, 2.3 and 5].
--
--  Key-size polymorphism. The Cryptol is
--  polymorphic in the key size k under the constraint Key k
--  ({k} (Key k) => ...). The SPARK states it as the Cryptol does:
--  * The constraint Key k is the subtype Key_Size. Its predicate lists
--    the values, 128 | 192 | 256, rather than Types.cry's clauses, because
--    it must be a Static_Predicate (below); Dispatch.Lemma_Key_Size proves
--    the list equal to the clauses.
--  * The {k} functions (KeyExpansion, Cipher, InvCipher, InvCipher' and
--    Main.cry's Encrypt and Decrypt) are the generic Spec.AES_K, whose
--    formal K : Key_Size is the Cryptol's k. Its instances AES128, AES192
--    and AES256 are the Cryptol's AES128 = AES`{128} and so on. In them,
--    [Nk k]AESWord and [Nr k + 1]Block are constrained subtypes of the
--    unconstrained Key_Words and Round_Keys below, so the functions take
--    the Cryptol's arguments and no precondition.
--  * Everything without a {k} is not generic and is proved once.
--  * The implementation stays flexible in the key size: one body serves
--    all three, with K : Key_Size as an explicit parameter and the typing
--    of its arrays as Is_Key_Words or Is_Round_Keys preconditions (a
--    subtype cannot relate an array's length to another parameter). Its
--    postconditions name the instances through the ghost dispatchers of
--    Spec.Dispatch (case K is when 128 => AES128.Cipher (W, Input), ...),
--    whose postconditions state the Cryptol bodies uniformly in K. Cryptol's
--    FFI passes {k} as a leading size_t, so the explicit K is also the
--    shape of the exported functions.
--  Key_Size is a Static_Predicate, not a Dynamic_Predicate with Types.cry's
--  clauses (which a static predicate cannot state: no mod, RM 3.2.4),
--  because a Pure instance needs static bounds for its subtypes
--  ("non-static constant in preelaborated unit", RM 10.2.1), and only a
--  static subtype makes the formal K static in an instance. It also makes
--  a case over K complete without others. Nk and Nr are Static functions
--  (Ada 2022) for the same reason; a static function has no Pre, so the
--  constraint is their parameter's subtype. The generic was weighed and
--  declined earlier on 2026-10-20 on the belief that proof time would
--  triple; a measurement found no change in wall-clock.
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

   subtype Key_Size is Natural
   with Static_Predicate => Key_Size in 128 | 192 | 256;
   --  Types.cry: type constraint Key k = (fin k, k % 64 == 0,
   --  k / 64 >= 2, k / 64 <= 4), as a subtype: the standard key sizes 128,
   --  192 and 256 [FIPS-PUB-197 Sections 1, 5 and 6.1]. Fin k holds of any
   --  Natural. It is the type of the formal K of the generic AES_K, and of
   --  every K that stands for the Cryptol's k. The predicate lists the values that Key k allows, and
   --  Dispatch.Lemma_Key_Size proves the list equal to Key k's clauses,
   --  clause for clause; why it is a list is in the header.

   function Nk (K : Key_Size) return Positive
   is (K / 32)
   with Static;
   --  Types.cry: type Nk k = k / 32. The number of 32-bit words in the
   --  key: 4, 6 or 8 [FIPS-PUB-197 Sections 2.3 and 5]. Static (Ada 2022),
   --  so that Nk (K) of a generic's formal K is a static bound; a static
   --  function cannot have a Pre, so the constraint Key k is K's subtype.
   --  @param K The key size in bits.
   --  @return K / 32.

   function Nr (K : Key_Size) return Positive
   is (Nk (K) + 6)
   with Static;
   --  Types.cry: type Nr k = Nk k + 6. The number of rounds: 10, 12 or 14
   --  [FIPS-PUB-197 Sections 2.3 and 5].
   --  @param K The key size in bits.
   --  @return Nk (K) + 6.

   Max_Nk : constant := 8;
   --  Nk (256), the largest Nk that Key_Size allows.

   Max_Nr : constant := 14;
   --  Nr (256), the largest Nr that Key_Size allows.

   subtype Key_Word_Index is Natural range 0 .. Max_Nk - 1;
   --  The indices a Key_Words array may use.

   type Key_Words is array (Key_Word_Index range <>) of AESWord;
   --  The Cryptol [Nk k]AESWord, the cipher key as words (the input of
   --  KeyExpansion.cry's KeyExpansion). Its length is fixed by K through
   --  Is_Key_Words.

   function Is_Key_Words (K : Key_Size; W : Key_Words) return Boolean
   is (W'First = 0 and then W'Length = Nk (K));
   --  The typing W : [Nk k]AESWord, with Cryptol's zero-based indexing, for
   --  a K that is not static (in AES_K it is the subtype Key_Words).
   --  @param K The key size in bits.
   --  @param W The key words.
   --  @return Whether W has Nk (K) words from index 0.

   subtype Round_Key_Index is Natural range 0 .. Max_Nr;
   --  The indices a Round_Keys array may use.

   type Round_Keys is array (Round_Key_Index range <>) of Block;
   --  The Cryptol [Nr k + 1]Block, the key schedule (the output of
   --  KeyExpansion and the first argument of Cipher.cry's Cipher and
   --  InvCipher). Its length is fixed by K through Is_Round_Keys.

   function Is_Round_Keys (K : Key_Size; W : Round_Keys) return Boolean
   is (W'First = 0 and then W'Length = Nr (K) + 1);
   --  The typing W : [Nr k + 1]Block, with Cryptol's zero-based indexing,
   --  for a K that is not static (in AES_K it is the subtype Round_Keys).
   --  @param K The key size in bits.
   --  @param W The round keys.
   --  @return Whether W has Nr (K) + 1 blocks from index 0.

end Foundation_Spark.AES.Spec.Types;
