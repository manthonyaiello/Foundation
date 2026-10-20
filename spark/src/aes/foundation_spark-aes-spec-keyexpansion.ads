--  The key schedule's helpers, mirroring algorithms/AES/KeyExpansion.cry
--  [FIPS-PUB-197 Section 5.2]: Rcon, RotWord and SubWord, which have no
--  {k}. KeyExpansion itself, KeyExpansion : {k} (Key k) => ..., is in the
--  generic AES_K (issue #80), one instance per key size.

with Foundation_Spark.AES.Spec.SBox;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.AES.Spec.KeyExpansion with
  SPARK_Mode,
  Pure,
  Ghost
is

   use Types;

   use type Types.Byte;

   function "xor" (A, B : AESWord) return AESWord
   is [for I in AESWord_Index => A (I) xor B (I)];
   --  Cryptol's ^ at type AESWord: the bytewise exclusive-or, as
   --  KeyExpansion.cry uses it on words.
   --  @param A The first word.
   --  @param B The second word.
   --  @return A ^ B.

   subtype Rcon_Index is Natural range 1 .. 10;
   --  The indices of Rcon that KeyExpansion reads. KeyExpansion.cry's Rcon
   --  is a [11]AESWord whose element 0 is undefined. Here the table has no
   --  element 0, so a read of Rcon @ 0 is a failed index check that the
   --  proof rules out, where the Cryptol would raise undefined.

   type Rcon_Table is array (Rcon_Index) of AESWord;
   --  The type of Rcon: KeyExpansion.cry's [11]AESWord without its
   --  undefined element 0.

   Rcon : constant Rcon_Table :=
     [[16#01#, 16#00#, 16#00#, 16#00#],
      [16#02#, 16#00#, 16#00#, 16#00#],
      [16#04#, 16#00#, 16#00#, 16#00#],
      [16#08#, 16#00#, 16#00#, 16#00#],
      [16#10#, 16#00#, 16#00#, 16#00#],
      [16#20#, 16#00#, 16#00#, 16#00#],
      [16#40#, 16#00#, 16#00#, 16#00#],
      [16#80#, 16#00#, 16#00#, 16#00#],
      [16#1b#, 16#00#, 16#00#, 16#00#],
      [16#36#, 16#00#, 16#00#, 16#00#]];
   --  KeyExpansion.cry: Rcon : [11]AESWord, the round constants
   --  [FIPS-PUB-197 Sections 2.1 and 5.2], elements 1 to 10, entry for
   --  entry.

   function RotWord (A : AESWord) return AESWord
   is [A (1), A (2), A (3), A (0)];
   --  KeyExpansion.cry: RotWord [a0, a1, a2, a3] = [a1, a2, a3, a0], the
   --  cyclic permutation of a word [FIPS-PUB-197 Section 5.2].
   --  @param A The word [a0, a1, a2, a3].
   --  @return The word [a1, a2, a3, a0].

   function SubWord (A : AESWord) return AESWord
   is [SBox.SBox (A (0)), SBox.SBox (A (1)),
       SBox.SBox (A (2)), SBox.SBox (A (3))];
   --  KeyExpansion.cry: SubWord [a0, a1, a2, a3] = [SBox @ a0, SBox @ a1,
   --  SBox @ a2, SBox @ a3], the S-box applied to each byte of a word
   --  [FIPS-PUB-197 Section 5.2].
   --  @param A The word [a0, a1, a2, a3].
   --  @return The word with the S-box applied to each byte.

   function Words (K : Key_Size) return Positive
   is (4 * (Nr (K) + 1));
   --  The length of KeyExpansion.cry's w : [4 * (Nr k + 1)]AESWord: 44,
   --  52 or 60.
   --  @param K The key size in bits.
   --  @return 4 * (Nr (K) + 1).

end Foundation_Spark.AES.Spec.KeyExpansion;
