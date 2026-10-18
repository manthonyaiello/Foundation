--  The key schedule, mirroring algorithms/AES/KeyExpansion.cry
--  [FIPS-PUB-197 Section 5.2]: Rcon, RotWord, SubWord and KeyExpansion.
--
--  KeyExpansion.cry defines the expanded key w as a self-referential
--  sequence: w @ i is defined from w @ (i - Nk) and w @ (i - 1). Here w
--  is the recursive function W (K, Key, I), whose Subprogram_Variant is
--  I. Following the campaign's decision on key sizes, one unconstrained
--  definition covers k = 128, 192 and 256: the key size K is an explicit
--  parameter in the place of the Cryptol's type application `{k}, and
--  Types.Is_Key_Words (K, Key) states the typing key : [Nk k]AESWord under
--  Key k.

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

   function Words (K : Natural) return Positive
   is (4 * (Nr (K) + 1))
   with Pre => Types.Key (K);
   --  The length of KeyExpansion.cry's w : [4 * (Nr k + 1)]AESWord: 44,
   --  52 or 60.
   --  @param K The key size in bits.
   --  @return 4 * (Nr (K) + 1).

   function W (K : Natural; Key : Key_Words; I : Natural) return AESWord
   is (if I < Nk (K) then Key (I)
       elsif I mod Nk (K) = 0
       then W (K, Key, I - Nk (K))
            xor SubWord (RotWord (W (K, Key, I - 1)))
            xor Rcon (I / Nk (K))
       elsif I mod Nk (K) = 4 and then Nk (K) > 6
       then W (K, Key, I - Nk (K)) xor SubWord (W (K, Key, I - 1))
       else W (K, Key, I - Nk (K)) xor W (K, Key, I - 1))
   with
     Pre                => Is_Key_Words (K, Key) and then I < Words (K),
     Subprogram_Variant => (Decreases => I);
   --  KeyExpansion.cry: the element w @ i of the expanded key in
   --  KeyExpansion's where clause, case for case: key @ i for i < Nk;
   --  w @ (i - Nk) ^ SubWord (RotWord (w @ (i - 1))) ^ Rcon @ (i / Nk) when
   --  i % Nk == 0; w @ (i - Nk) ^ SubWord (w @ (i - 1)) when i % Nk == 4
   --  and Nk > 6; and w @ (i - Nk) ^ w @ (i - 1) otherwise [FIPS-PUB-197
   --  Section 5.2, Figure 11]. The variant is I: each case reads w at
   --  smaller indices only.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Key The cipher key, the Cryptol's key : [Nk k]AESWord.
   --  @param I The index of the word, below 4 * (Nr (K) + 1).
   --  @return w @ I.

   function KeyExpansion (K : Natural; Key : Key_Words) return Round_Keys
   is [for R in 0 .. Nr (K) => Join ([for J in AESWord_Index =>
                                        W (K, Key, 4 * R + J)])]
   with
     Pre  => Is_Key_Words (K, Key),
     Post => Is_Round_Keys (K, KeyExpansion'Result);
   --  KeyExpansion.cry: KeyExpansion : {k} (Key k) => [Nk k]AESWord ->
   --  [Nr k + 1]Block, KeyExpansion key = split (split (join (join w)))
   --  [FIPS-PUB-197 Section 5.2]. The split and join regroup the
   --  4 * (Nr k + 1) words of w into Nr k + 1 blocks of four consecutive
   --  words: round key R is Join of w @ (4 * R) to w @ (4 * R + 3), in
   --  order.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Key The cipher key as Nk (K) words.
   --  @return The Nr (K) + 1 round keys.

end Foundation_Spark.AES.Spec.KeyExpansion;
