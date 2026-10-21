--  The AES implementation layer [FIPS-PUB-197 Sections 5.1 to 5.3]:
--  executable AES on bytes, proved equal to the spec layer
--  (Foundation_Spark.AES.Spec). The key schedule is expanded into a
--  Round_Keys, and one block is encrypted or decrypted in place, a round
--  at a time, with loops.
--
--  Key sizes. One unconstrained implementation serves k = 128, 192 and
--  256, with the key size K : Key_Size as an explicit parameter and
--  Is_Key_Words or Is_Round_Keys as the precondition: no executable code is
--  tripled. The spec's {k} functions are generic in the key size
--  (Spec.AES_K, issue #80), and the postconditions name them through the
--  ghost dispatchers Spec.Dispatch.KeyExpansion, Cipher, InvCipher and
--  InvCipher_Prime, which select the instance by K.
--
--  Every subprogram's postcondition states equality with the spec-layer
--  function it implements. The arithmetic of MixColumns and InvMixColumns
--  is xTimes alone, proved against GF28.cry's (•) by Lemmas.Lemma_Dot. The
--  round loops are proved against Cipher.cry's foldl by the
--  Lemmas.Lemma_Foldl_*_Snoc lemmas.

with Interfaces;
with Foundation_Spark.AES.Spec.Cipher;
with Foundation_Spark.AES.Spec.Dispatch;
with Foundation_Spark.AES.Spec.GF28;
with Foundation_Spark.AES.Spec.KeyExpansion;
with Foundation_Spark.AES.Spec.SBox;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.AES.Impl with
  SPARK_Mode,
  Pure
is

   use Spec.Types;

   use type Interfaces.Unsigned_8;

   function X_Times (B : Byte) return Byte
   is (Interfaces.Shift_Left (B, 1)
       xor (16#1b# and (0 - Interfaces.Shift_Right (B, 7))))
   with Post => X_Times'Result = Spec.GF28.xTimes (B);
   --  B • 0x02, by a shift and a reduction under a mask: 0 - (B >> 7) is
   --  all ones when B's top bit is set and zero otherwise, so that no
   --  branch depends on B (README "Constant time").
   --  @param B The byte.
   --  @return GF28.cry's xTimes B.

   function Dot (B, C : Byte) return Byte
   with Post => Dot'Result = Spec.GF28.Dot (B, C);
   --  Multiplication in GF(2^8) of any two bytes, by a carry-less product
   --  and a long division, each a loop over bits, with masks in place of
   --  branches on the bits of B, C or the remainder. The ciphers do not
   --  call it: they multiply by MixColumns' constants with X_Times.
   --  @param B The first factor.
   --  @param C The second factor.
   --  @return GF28.cry's B • C.

   function Sub_Byte (B : Byte) return Byte
   with Post => Sub_Byte'Result = Spec.SBox.SBox (B);
   --  The S-box applied to one byte, computed by the bitsliced circuit
   --  of the body (Boyar and Peralta's), without a table: no memory
   --  address depends on B (README "Constant time").
   --  @param B The byte.
   --  @return SBox.cry's SBox @ B.

   function Inv_Sub_Byte (B : Byte) return Byte
   with Post => Inv_Sub_Byte'Result = Spec.SBox.InvSBox (B);
   --  The inverse S-box applied to one byte, by the same circuit between
   --  two inverse affine maps, without a table.
   --  @param B The byte.
   --  @return SBox.cry's InvSBox @ B.

   function Sub_Word (A : AESWord) return AESWord
   with Post => Sub_Word'Result = Spec.KeyExpansion.SubWord (A);
   --  The S-box applied to each byte of a word, the four bytes through one
   --  evaluation of Sub_Byte's circuit.
   --  @param A The word.
   --  @return KeyExpansion.cry's SubWord A.

   function Rot_Word (A : AESWord) return AESWord
   is [A (1), A (2), A (3), A (0)]
   with Post => Rot_Word'Result = Spec.KeyExpansion.RotWord (A);
   --  The cyclic permutation of a word.
   --  @param A The word [a0, a1, a2, a3].
   --  @return KeyExpansion.cry's RotWord A, [a1, a2, a3, a0].

   function Xor_Word (A, B : AESWord) return AESWord
   is [for I in AESWord_Index => A (I) xor B (I)]
   with Post => Xor_Word'Result = Spec.KeyExpansion."xor" (A, B);
   --  The bytewise exclusive-or of two words.
   --  @param A The first word.
   --  @param B The second word.
   --  @return A ^ B, as KeyExpansion.cry uses ^ on words.

   subtype Rcon_Index is Natural range 1 .. 10;
   --  The indices of the round constants that the key schedule reads,
   --  as KeyExpansion.Rcon_Index.

   function Rcon (I : Rcon_Index) return AESWord
   is [(case I is
          when 1 => 16#01#, when 2 => 16#02#, when 3 => 16#04#,
          when 4 => 16#08#, when 5 => 16#10#, when 6 => 16#20#,
          when 7 => 16#40#, when 8 => 16#80#, when 9 => 16#1b#,
          when 10 => 16#36#),
       0, 0, 0]
   with Post => Rcon'Result = Spec.KeyExpansion.Rcon (I);
   --  The round constant I [FIPS-PUB-197 Section 5.2], its first byte by
   --  a case on I and the rest zero.
   --  @param I The index, 1 .. 10.
   --  @return KeyExpansion.cry's Rcon @ I.

   procedure Expand_Key (K : Key_Size; Key : Key_Words; W : out Round_Keys)
   with
     Pre  => Is_Key_Words (K, Key)
             and then W'First = 0 and then W'Length = Nr (K) + 1,
     Post => W = Spec.Dispatch.KeyExpansion (K, Key);
   --  The key schedule [FIPS-PUB-197 Section 5.2]: the 4 * (Nr (K) + 1)
   --  words of the expanded key, computed in one loop, each from the word
   --  Nk (K) before it and the word just before it, then regrouped into
   --  Nr (K) + 1 round keys.
   --  @param K The key size in bits: 128, 192 or 256.
   --  @param Key The cipher key as Nk (K) words.
   --  @param W The round keys, Nr (K) + 1 of them from index 0.

   procedure Sub_Bytes (State : in out Block)
   with Post => State = Spec.Cipher.SubBytes (State'Old);
   --  SubBytes in place: the S-box applied to each byte of the state, by
   --  two evaluations of Sub_Byte's circuit on eight bytes each.
   --  @param State The state.

   procedure Inv_Sub_Bytes (State : in out Block)
   with Post => State = Spec.Cipher.InvSubBytes (State'Old);
   --  InvSubBytes in place: the inverse S-box applied to each byte, by
   --  two evaluations of Inv_Sub_Byte's circuit on eight bytes each.
   --  @param State The state.

   procedure Shift_Rows (State : in out Block)
   with Post => State = Spec.Cipher.ShiftRows (State'Old);
   --  ShiftRows in place: row R of the state rotated left by R.
   --  @param State The state.

   procedure Inv_Shift_Rows (State : in out Block)
   with Post => State = Spec.Cipher.InvShiftRows (State'Old);
   --  InvShiftRows in place: row R of the state rotated right by R.
   --  @param State The state.

   function Mix_Column (S : AESWord) return AESWord
   with Post => Mix_Column'Result = Spec.Cipher.MixColumnsStep (S);
   --  One column of MixColumns, with X_Times for the products by 0x02 and
   --  0x03.
   --  @param S The column.
   --  @return Cipher.cry's MixColumnsStep S.

   function Inv_Mix_Column (S : AESWord) return AESWord
   with Post => Inv_Mix_Column'Result = Spec.Cipher.InvMixColumnsStep (S);
   --  One column of InvMixColumns, with X_Times for the products by 0x09,
   --  0x0b, 0x0d and 0x0e.
   --  @param S The column.
   --  @return Cipher.cry's InvMixColumnsStep S.

   procedure Mix_Columns (State : in out Block)
   with Post => State = Spec.Cipher.MixColumns (State'Old);
   --  MixColumns in place, a column at a time.
   --  @param State The state.

   procedure Inv_Mix_Columns (State : in out Block)
   with Post => State = Spec.Cipher.InvMixColumns (State'Old);
   --  InvMixColumns in place, a column at a time.
   --  @param State The state.

   procedure Add_Round_Key (State : in out Block; Key : Block)
   with Post => State = Spec.Cipher.AddRoundKey (State'Old, Key);
   --  AddRoundKey in place: the round key added to the state.
   --  @param State The state.
   --  @param Key The round key.

   procedure Round (State : in out Block; Key : Block)
   with Post => State = Spec.Cipher.Round (State'Old, Key);
   --  One round of encryption in place.
   --  @param State The state.
   --  @param Key The round key.

   procedure Inv_Round (State : in out Block; Key : Block)
   with Post => State = Spec.Cipher.InvRound (State'Old, Key);
   --  One round of decryption in place.
   --  @param State The state.
   --  @param Key The round key.

   procedure Inv_Round_Prime (State : in out Block; Key : Block)
   with Post => State = Spec.Cipher.InvRound_Prime (State'Old, Key);
   --  One round of the alternate decryption InvCipher' in place.
   --  @param State The state.
   --  @param Key The round key.

   procedure Encrypt_Block (K : Key_Size; W : Round_Keys; State : in out Block)
   with
     Pre  => Is_Round_Keys (K, W),
     Post => State = Spec.Dispatch.Cipher (K, W, State'Old);
   --  AES encryption of one block in place [FIPS-PUB-197 Section 5.1]:
   --  AddRoundKey by W (0), Nr (K) - 1 rounds by W (1) to W (Nr (K) - 1),
   --  and the final round without MixColumns by W (Nr (K)).
   --  @param K The key size in bits: 128, 192 or 256.
   --  @param W The round keys, from Expand_Key.
   --  @param State The plaintext block on entry, the ciphertext on exit.

   procedure Decrypt_Block (K : Key_Size; W : Round_Keys; State : in out Block)
   with
     Pre  => Is_Round_Keys (K, W),
     Post => State = Spec.Dispatch.InvCipher (K, W, State'Old);
   --  AES decryption of one block in place [FIPS-PUB-197 Section 5.3]:
   --  AddRoundKey by W (Nr (K)), Nr (K) - 1 inverse rounds by W (Nr (K) -
   --  1) down to W (1), and the final inverse round without InvMixColumns
   --  by W (0).
   --  @param K The key size in bits: 128, 192 or 256.
   --  @param W The round keys, from Expand_Key.
   --  @param State The ciphertext block on entry, the plaintext on exit.

   procedure Decrypt_Block_Prime
     (K : Key_Size; W : Round_Keys; State : in out Block)
   with
     Pre  => Is_Round_Keys (K, W),
     Post => State = Spec.Dispatch.InvCipher_Prime (K, W, State'Old);
   --  The alternate AES decryption InvCipher' of one block in place,
   --  the rounds of Encrypt_Block undone in reverse order.
   --  @param K The key size in bits: 128, 192 or 256.
   --  @param W The round keys, from Expand_Key.
   --  @param State The ciphertext block on entry, the plaintext on exit.

end Foundation_Spark.AES.Impl;
