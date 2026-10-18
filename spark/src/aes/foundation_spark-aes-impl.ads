--  The AES implementation layer [FIPS-PUB-197 Sections 5.1 to 5.3]:
--  executable AES on bytes, proved equal to the spec layer
--  (Foundation_Spark.AES.Spec). The key schedule is expanded into a
--  Round_Keys, and one block is encrypted or decrypted in place, a round
--  at a time, with loops.
--
--  Key sizes. Following the campaign's decision, one unconstrained
--  implementation serves k = 128, 192 and 256, with the key size K as an
--  explicit parameter and Is_Key_Words or the bounds of a Round_Keys as
--  the precondition, as in the spec layer. No generic per key size is
--  needed.
--
--  Every subprogram's postcondition states equality with the spec-layer
--  function it implements. The arithmetic of MixColumns and InvMixColumns
--  is xTimes alone, proved against GF28.cry's (•) by Lemmas.Lemma_Dot. The
--  round loops are proved against Cipher.cry's foldl by the
--  Lemmas.Lemma_Foldl_*_Snoc lemmas.

with Interfaces;
with Foundation_Spark.AES.Spec.Cipher;
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
   is (Interfaces.Shift_Left (B, 1) xor (if B >= 16#80# then 16#1b# else 0))
   with Post => X_Times'Result = Spec.GF28.xTimes (B);
   --  B • 0x02, by a shift and a conditional reduction.
   --  @param B The byte.
   --  @return GF28.cry's xTimes B.

   function Dot (B, C : Byte) return Byte
   with Post => Dot'Result = Spec.GF28.Dot (B, C);
   --  Multiplication in GF(2^8) of any two bytes, by a carry-less product
   --  and a long division, each a loop over bits. The ciphers do not call
   --  it: they multiply by MixColumns' constants with X_Times.
   --  @param B The first factor.
   --  @param C The second factor.
   --  @return GF28.cry's B • C.

   S_Box : constant Byte_Table :=
     [16#63#, 16#7c#, 16#77#, 16#7b#, 16#f2#, 16#6b#, 16#6f#, 16#c5#,
      16#30#, 16#01#, 16#67#, 16#2b#, 16#fe#, 16#d7#, 16#ab#, 16#76#,
      16#ca#, 16#82#, 16#c9#, 16#7d#, 16#fa#, 16#59#, 16#47#, 16#f0#,
      16#ad#, 16#d4#, 16#a2#, 16#af#, 16#9c#, 16#a4#, 16#72#, 16#c0#,
      16#b7#, 16#fd#, 16#93#, 16#26#, 16#36#, 16#3f#, 16#f7#, 16#cc#,
      16#34#, 16#a5#, 16#e5#, 16#f1#, 16#71#, 16#d8#, 16#31#, 16#15#,
      16#04#, 16#c7#, 16#23#, 16#c3#, 16#18#, 16#96#, 16#05#, 16#9a#,
      16#07#, 16#12#, 16#80#, 16#e2#, 16#eb#, 16#27#, 16#b2#, 16#75#,
      16#09#, 16#83#, 16#2c#, 16#1a#, 16#1b#, 16#6e#, 16#5a#, 16#a0#,
      16#52#, 16#3b#, 16#d6#, 16#b3#, 16#29#, 16#e3#, 16#2f#, 16#84#,
      16#53#, 16#d1#, 16#00#, 16#ed#, 16#20#, 16#fc#, 16#b1#, 16#5b#,
      16#6a#, 16#cb#, 16#be#, 16#39#, 16#4a#, 16#4c#, 16#58#, 16#cf#,
      16#d0#, 16#ef#, 16#aa#, 16#fb#, 16#43#, 16#4d#, 16#33#, 16#85#,
      16#45#, 16#f9#, 16#02#, 16#7f#, 16#50#, 16#3c#, 16#9f#, 16#a8#,
      16#51#, 16#a3#, 16#40#, 16#8f#, 16#92#, 16#9d#, 16#38#, 16#f5#,
      16#bc#, 16#b6#, 16#da#, 16#21#, 16#10#, 16#ff#, 16#f3#, 16#d2#,
      16#cd#, 16#0c#, 16#13#, 16#ec#, 16#5f#, 16#97#, 16#44#, 16#17#,
      16#c4#, 16#a7#, 16#7e#, 16#3d#, 16#64#, 16#5d#, 16#19#, 16#73#,
      16#60#, 16#81#, 16#4f#, 16#dc#, 16#22#, 16#2a#, 16#90#, 16#88#,
      16#46#, 16#ee#, 16#b8#, 16#14#, 16#de#, 16#5e#, 16#0b#, 16#db#,
      16#e0#, 16#32#, 16#3a#, 16#0a#, 16#49#, 16#06#, 16#24#, 16#5c#,
      16#c2#, 16#d3#, 16#ac#, 16#62#, 16#91#, 16#95#, 16#e4#, 16#79#,
      16#e7#, 16#c8#, 16#37#, 16#6d#, 16#8d#, 16#d5#, 16#4e#, 16#a9#,
      16#6c#, 16#56#, 16#f4#, 16#ea#, 16#65#, 16#7a#, 16#ae#, 16#08#,
      16#ba#, 16#78#, 16#25#, 16#2e#, 16#1c#, 16#a6#, 16#b4#, 16#c6#,
      16#e8#, 16#dd#, 16#74#, 16#1f#, 16#4b#, 16#bd#, 16#8b#, 16#8a#,
      16#70#, 16#3e#, 16#b5#, 16#66#, 16#48#, 16#03#, 16#f6#, 16#0e#,
      16#61#, 16#35#, 16#57#, 16#b9#, 16#86#, 16#c1#, 16#1d#, 16#9e#,
      16#e1#, 16#f8#, 16#98#, 16#11#, 16#69#, 16#d9#, 16#8e#, 16#94#,
      16#9b#, 16#1e#, 16#87#, 16#e9#, 16#ce#, 16#55#, 16#28#, 16#df#,
      16#8c#, 16#a1#, 16#89#, 16#0d#, 16#bf#, 16#e6#, 16#42#, 16#68#,
      16#41#, 16#99#, 16#2d#, 16#0f#, 16#b0#, 16#54#, 16#bb#, 16#16#];
   --  The S-box as an executable table [FIPS-PUB-197 Table 4]. The spec's
   --  SBox.SBox is ghost, so the implementation has its own copy, proved
   --  equal to it entry for entry through Sub_Byte's postcondition.

   Inv_S_Box : constant Byte_Table :=
     [16#52#, 16#09#, 16#6a#, 16#d5#, 16#30#, 16#36#, 16#a5#, 16#38#,
      16#bf#, 16#40#, 16#a3#, 16#9e#, 16#81#, 16#f3#, 16#d7#, 16#fb#,
      16#7c#, 16#e3#, 16#39#, 16#82#, 16#9b#, 16#2f#, 16#ff#, 16#87#,
      16#34#, 16#8e#, 16#43#, 16#44#, 16#c4#, 16#de#, 16#e9#, 16#cb#,
      16#54#, 16#7b#, 16#94#, 16#32#, 16#a6#, 16#c2#, 16#23#, 16#3d#,
      16#ee#, 16#4c#, 16#95#, 16#0b#, 16#42#, 16#fa#, 16#c3#, 16#4e#,
      16#08#, 16#2e#, 16#a1#, 16#66#, 16#28#, 16#d9#, 16#24#, 16#b2#,
      16#76#, 16#5b#, 16#a2#, 16#49#, 16#6d#, 16#8b#, 16#d1#, 16#25#,
      16#72#, 16#f8#, 16#f6#, 16#64#, 16#86#, 16#68#, 16#98#, 16#16#,
      16#d4#, 16#a4#, 16#5c#, 16#cc#, 16#5d#, 16#65#, 16#b6#, 16#92#,
      16#6c#, 16#70#, 16#48#, 16#50#, 16#fd#, 16#ed#, 16#b9#, 16#da#,
      16#5e#, 16#15#, 16#46#, 16#57#, 16#a7#, 16#8d#, 16#9d#, 16#84#,
      16#90#, 16#d8#, 16#ab#, 16#00#, 16#8c#, 16#bc#, 16#d3#, 16#0a#,
      16#f7#, 16#e4#, 16#58#, 16#05#, 16#b8#, 16#b3#, 16#45#, 16#06#,
      16#d0#, 16#2c#, 16#1e#, 16#8f#, 16#ca#, 16#3f#, 16#0f#, 16#02#,
      16#c1#, 16#af#, 16#bd#, 16#03#, 16#01#, 16#13#, 16#8a#, 16#6b#,
      16#3a#, 16#91#, 16#11#, 16#41#, 16#4f#, 16#67#, 16#dc#, 16#ea#,
      16#97#, 16#f2#, 16#cf#, 16#ce#, 16#f0#, 16#b4#, 16#e6#, 16#73#,
      16#96#, 16#ac#, 16#74#, 16#22#, 16#e7#, 16#ad#, 16#35#, 16#85#,
      16#e2#, 16#f9#, 16#37#, 16#e8#, 16#1c#, 16#75#, 16#df#, 16#6e#,
      16#47#, 16#f1#, 16#1a#, 16#71#, 16#1d#, 16#29#, 16#c5#, 16#89#,
      16#6f#, 16#b7#, 16#62#, 16#0e#, 16#aa#, 16#18#, 16#be#, 16#1b#,
      16#fc#, 16#56#, 16#3e#, 16#4b#, 16#c6#, 16#d2#, 16#79#, 16#20#,
      16#9a#, 16#db#, 16#c0#, 16#fe#, 16#78#, 16#cd#, 16#5a#, 16#f4#,
      16#1f#, 16#dd#, 16#a8#, 16#33#, 16#88#, 16#07#, 16#c7#, 16#31#,
      16#b1#, 16#12#, 16#10#, 16#59#, 16#27#, 16#80#, 16#ec#, 16#5f#,
      16#60#, 16#51#, 16#7f#, 16#a9#, 16#19#, 16#b5#, 16#4a#, 16#0d#,
      16#2d#, 16#e5#, 16#7a#, 16#9f#, 16#93#, 16#c9#, 16#9c#, 16#ef#,
      16#a0#, 16#e0#, 16#3b#, 16#4d#, 16#ae#, 16#2a#, 16#f5#, 16#b0#,
      16#c8#, 16#eb#, 16#bb#, 16#3c#, 16#83#, 16#53#, 16#99#, 16#61#,
      16#17#, 16#2b#, 16#04#, 16#7e#, 16#ba#, 16#77#, 16#d6#, 16#26#,
      16#e1#, 16#69#, 16#14#, 16#63#, 16#55#, 16#21#, 16#0c#, 16#7d#];
   --  The inverse S-box as an executable table [FIPS-PUB-197 Table 6], the
   --  implementation's copy of the ghost SBox.InvSBox, proved equal to it
   --  through Inv_Sub_Byte's postcondition.

   function Sub_Byte (B : Byte) return Byte
   with Post => Sub_Byte'Result = Spec.SBox.SBox (B);
   --  The S-box applied to one byte, a lookup in S_Box.
   --  @param B The byte.
   --  @return SBox.cry's SBox @ B.

   function Inv_Sub_Byte (B : Byte) return Byte
   with Post => Inv_Sub_Byte'Result = Spec.SBox.InvSBox (B);
   --  The inverse S-box applied to one byte, a lookup in Inv_S_Box.
   --  @param B The byte.
   --  @return SBox.cry's InvSBox @ B.

   function Sub_Word (A : AESWord) return AESWord
   is [Sub_Byte (A (0)), Sub_Byte (A (1)), Sub_Byte (A (2)), Sub_Byte (A (3))]
   with Post => Sub_Word'Result = Spec.KeyExpansion.SubWord (A);
   --  The S-box applied to each byte of a word.
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

   procedure Expand_Key (K : Natural; Key : Key_Words; W : out Round_Keys)
   with
     Pre  => Is_Key_Words (K, Key)
             and then W'First = 0 and then W'Length = Nr (K) + 1,
     Post => W = Spec.KeyExpansion.KeyExpansion (K, Key);
   --  The key schedule [FIPS-PUB-197 Section 5.2]: the 4 * (Nr (K) + 1)
   --  words of the expanded key, computed in one loop, each from the word
   --  Nk (K) before it and the word just before it, then regrouped into
   --  Nr (K) + 1 round keys.
   --  @param K The key size in bits: 128, 192 or 256.
   --  @param Key The cipher key as Nk (K) words.
   --  @param W The round keys, Nr (K) + 1 of them from index 0.

   procedure Sub_Bytes (State : in out Block)
   with Post => State = Spec.Cipher.SubBytes (State'Old);
   --  SubBytes in place: the S-box applied to each byte of the state.
   --  @param State The state.

   procedure Inv_Sub_Bytes (State : in out Block)
   with Post => State = Spec.Cipher.InvSubBytes (State'Old);
   --  InvSubBytes in place: the inverse S-box applied to each byte.
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

   procedure Encrypt_Block (K : Natural; W : Round_Keys; State : in out Block)
   with
     Pre  => Is_Round_Keys (K, W),
     Post => State = Spec.Cipher.Cipher (K, W, State'Old);
   --  AES encryption of one block in place [FIPS-PUB-197 Section 5.1]:
   --  AddRoundKey by W (0), Nr (K) - 1 rounds by W (1) to W (Nr (K) - 1),
   --  and the final round without MixColumns by W (Nr (K)).
   --  @param K The key size in bits: 128, 192 or 256.
   --  @param W The round keys, from Expand_Key.
   --  @param State The plaintext block on entry, the ciphertext on exit.

   procedure Decrypt_Block (K : Natural; W : Round_Keys; State : in out Block)
   with
     Pre  => Is_Round_Keys (K, W),
     Post => State = Spec.Cipher.InvCipher (K, W, State'Old);
   --  AES decryption of one block in place [FIPS-PUB-197 Section 5.3]:
   --  AddRoundKey by W (Nr (K)), Nr (K) - 1 inverse rounds by W (Nr (K) -
   --  1) down to W (1), and the final inverse round without InvMixColumns
   --  by W (0).
   --  @param K The key size in bits: 128, 192 or 256.
   --  @param W The round keys, from Expand_Key.
   --  @param State The ciphertext block on entry, the plaintext on exit.

   procedure Decrypt_Block_Prime
     (K : Natural; W : Round_Keys; State : in out Block)
   with
     Pre  => Is_Round_Keys (K, W),
     Post => State = Spec.Cipher.InvCipher_Prime (K, W, State'Old);
   --  The alternate AES decryption InvCipher' of one block in place,
   --  the rounds of Encrypt_Block undone in reverse order.
   --  @param K The key size in bits: 128, 192 or 256.
   --  @param W The round keys, from Expand_Key.
   --  @param State The ciphertext block on entry, the plaintext on exit.

end Foundation_Spark.AES.Impl;
