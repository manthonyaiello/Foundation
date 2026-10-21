--  The round transformations of algorithms/AES/Cipher.cry
--  [FIPS-PUB-197 Sections 5.1 and 5.3]: SubBytes, ShiftRows,
--  MixColumnsStep, MixColumns, AddRoundKey, their inverses, Round,
--  InvRound and InvRound', the folds of the rounds, and reverse: everything
--  of Cipher.cry that has no {k}, proved once. Its {k} functions, Cipher,
--  InvCipher and InvCipher', are in the generic AES_K, one instance per
--  key size (issue #80).
--
--  Cipher.cry's properties (M1.5) are not stated here. Ada has no primes
--  in names, so InvRound' is InvRound_Prime.
--
--  Cryptol's built-ins come from the Cryptol prelude in SPARK
--  (Foundation_Spark.Cryptol, #75), instantiated here at AES's types:
--  * @@ in SubBytes, InvSubBytes, ShiftRows and InvShiftRows is
--    Bulk_Indexing's Bulk_Index;
--  * foldl over the middle round keys, one fold per round function
--    (Foldl_Round, Foldl_InvRound, Foldl_InvRound_Prime), is Folds' Foldl.
--    Its lists of round keys are Round_Keys of any length, as foldl takes
--    any [n]. The prelude's fold recurses from the last element, as the
--    implementation's loops run (see Folds);
--  * reverse, in InvCipher and InvCipher', stays inline (Reverse_Keys
--    says why).

with Foundation_Spark.Cryptol.Bulk_Indexing;
with Foundation_Spark.Cryptol.Folds;
with Foundation_Spark.AES.Spec.GF28;
with Foundation_Spark.AES.Spec.SBox;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.AES.Spec.Cipher with
  SPARK_Mode,
  Pure,
  Ghost
is

   use Types;

   use type Types.Byte;

   function Dot (B, C : Byte) return Byte renames GF28.Dot;
   --  Cipher.cry imports (•) from GF28.cry: import algorithms::AES::GF28
   --  ((•)).
   --  @param B The first factor.
   --  @param C The second factor.
   --  @return B • C.

   type Permutation is array (Block_Index) of Block_Index;
   --  A list of 16 indices into a Block, the right operand of Cryptol's
   --  @@ in ShiftRows and InvShiftRows.

   package Table_Indexing is new Cryptol.Bulk_Indexing
     (Index     => Byte,
      Element   => Byte,
      Seq       => Byte_Table,
      Out_Index => Block_Index,
      Indices   => Block,
      Out_Seq   => Block);
   --  The prelude's @@ on an S-box [256][8], indexed by the 16 bytes of a
   --  block: SBox @@ bs.

   package Block_Indexing is new Cryptol.Bulk_Indexing
     (Index     => Block_Index,
      Element   => Byte,
      Seq       => Block,
      Out_Index => Block_Index,
      Indices   => Permutation,
      Out_Seq   => Block);
   --  The prelude's @@ on a block, indexed by a Permutation: bs @@ [0, 5,
   --  10, ...].

   function SubBytes (Bs : Block) return Block
   is (Table_Indexing.Bulk_Index (SBox.SBox, Bs));
   --  Cipher.cry: SubBytes bs = SBox @@ bs [FIPS-PUB-197 Section 5.1.1].
   --  @param Bs The state.
   --  @return The state with the S-box applied to each byte.

   function InvSubBytes (Bs : Block) return Block
   is (Table_Indexing.Bulk_Index (SBox.InvSBox, Bs));
   --  Cipher.cry: InvSubBytes bs = InvSBox @@ bs [FIPS-PUB-197 Section
   --  5.3.2].
   --  @param Bs The state.
   --  @return The state with the inverse S-box applied to each byte.

   ShiftRows_Indices : constant Permutation :=
     [0, 5, 10, 15,
      4, 9, 14, 3,
      8, 13, 2, 7,
      12, 1, 6, 11];
   --  The index list of Cipher.cry's ShiftRows: bs @@ [0, 5, 10, 15, ...].

   function ShiftRows (Bs : Block) return Block
   is (Block_Indexing.Bulk_Index (Bs, ShiftRows_Indices));
   --  Cipher.cry: ShiftRows bs = bs @@ [0, 5, 10, 15, 4, 9, 14, 3, 8, 13,
   --  2, 7, 12, 1, 6, 11], ShiftRows as a permutation of the bytes of the
   --  block [FIPS-PUB-197 Section 5.1.2].
   --  @param Bs The state.
   --  @return The state with its rows shifted.

   InvShiftRows_Indices : constant Permutation :=
     [0, 13, 10, 7,
      4, 1, 14, 11,
      8, 5, 2, 15,
      12, 9, 6, 3];
   --  The index list of Cipher.cry's InvShiftRows: bs @@ [0, 13, 10, 7,
   --  ...].

   function InvShiftRows (Bs : Block) return Block
   is (Block_Indexing.Bulk_Index (Bs, InvShiftRows_Indices));
   --  Cipher.cry: InvShiftRows bs = bs @@ [0, 13, 10, 7, 4, 1, 14, 11, 8,
   --  5, 2, 15, 12, 9, 6, 3] [FIPS-PUB-197 Section 5.3.1].
   --  @param Bs The state.
   --  @return The state with its rows shifted back.

   function MixColumnsStep (S : AESWord) return AESWord
   is [Dot (16#02#, S (0)) xor Dot (16#03#, S (1)) xor S (2) xor S (3),
       S (0) xor Dot (16#02#, S (1)) xor Dot (16#03#, S (2)) xor S (3),
       S (0) xor S (1) xor Dot (16#02#, S (2)) xor Dot (16#03#, S (3)),
       Dot (16#03#, S (0)) xor S (1) xor S (2) xor Dot (16#02#, S (3))];
   --  Cipher.cry: MixColumnsStep [s0, s1, s2, s3], one column of
   --  MixColumns [FIPS-PUB-197 Section 5.1.3].
   --  @param S The column [s0, s1, s2, s3].
   --  @return The mixed column.

   function MixColumns (Bs : Block) return Block
   is (Join ([for J in AESWord_Index => MixColumnsStep (Split (Bs) (J))]));
   --  Cipher.cry: MixColumns bs = join (map MixColumnsStep (split bs))
   --  [FIPS-PUB-197 Section 5.1.3].
   --  @param Bs The state.
   --  @return The state with each column mixed.

   function InvMixColumnsStep (S : AESWord) return AESWord
   is [Dot (16#0e#, S (0)) xor Dot (16#0b#, S (1))
         xor Dot (16#0d#, S (2)) xor Dot (16#09#, S (3)),
       Dot (16#09#, S (0)) xor Dot (16#0e#, S (1))
         xor Dot (16#0b#, S (2)) xor Dot (16#0d#, S (3)),
       Dot (16#0d#, S (0)) xor Dot (16#09#, S (1))
         xor Dot (16#0e#, S (2)) xor Dot (16#0b#, S (3)),
       Dot (16#0b#, S (0)) xor Dot (16#0d#, S (1))
         xor Dot (16#09#, S (2)) xor Dot (16#0e#, S (3))];
   --  Cipher.cry: InvMixColumnsStep [s0, s1, s2, s3], one column of
   --  InvMixColumns [FIPS-PUB-197 Section 5.3.3].
   --  @param S The column [s0, s1, s2, s3].
   --  @return The unmixed column.

   function InvMixColumns (Bs : Block) return Block
   is (Join ([for J in AESWord_Index => InvMixColumnsStep (Split (Bs) (J))]));
   --  Cipher.cry: InvMixColumns bs = join (map InvMixColumnsStep (split
   --  bs)) [FIPS-PUB-197 Section 5.3.3].
   --  @param Bs The state.
   --  @return The state with each column unmixed.

   function AddRoundKey (Bs : Block; W : Block) return Block
   is [for I in Block_Index => Bs (I) xor W (I)];
   --  Cipher.cry: AddRoundKey bs w = bs ^ w [FIPS-PUB-197 Section 5.1.4].
   --  @param Bs The state.
   --  @param W The round key.
   --  @return The state with the round key added.

   function Round (Xs : Block; Ki : Block) return Block
   is (AddRoundKey (MixColumns (ShiftRows (SubBytes (Xs))), Ki));
   --  Cipher.cry: Round xs ki = AddRoundKey (MixColumns (ShiftRows
   --  (SubBytes xs))) ki. One round of encryption [FIPS-PUB-197 Section
   --  5.1].
   --  @param Xs The state.
   --  @param Ki The round key.
   --  @return The state after the round.

   function InvRound (Xs : Block; Ki : Block) return Block
   is (InvMixColumns (AddRoundKey (InvSubBytes (InvShiftRows (Xs)), Ki)));
   --  Cipher.cry: InvRound xs ki = InvMixColumns (AddRoundKey (InvSubBytes
   --  (InvShiftRows xs)) ki). One round of decryption [FIPS-PUB-197
   --  Section 5.3].
   --  @param Xs The state.
   --  @param Ki The round key.
   --  @return The state after the round.

   function InvRound_Prime (Xs : Block; Ki : Block) return Block
   is (InvSubBytes (InvShiftRows (InvMixColumns (AddRoundKey (Xs, Ki)))));
   --  Cipher.cry: InvRound' xs ki = InvSubBytes (InvShiftRows
   --  (InvMixColumns (AddRoundKey xs ki))), the round that is a proper
   --  inverse of Round.
   --  @param Xs The state.
   --  @param Ki The round key.
   --  @return The state after the round.

   package Round_Folds is new Cryptol.Folds
     (Acc     => Block,
      Index   => Round_Key_Index,
      Element => Block,
      Seq     => Round_Keys,
      F       => Round);
   --  The prelude's foldl over round keys, with Round as its function.

   package InvRound_Folds is new Cryptol.Folds
     (Acc     => Block,
      Index   => Round_Key_Index,
      Element => Block,
      Seq     => Round_Keys,
      F       => InvRound);
   --  The prelude's foldl over round keys, with InvRound as its function.

   package InvRound_Prime_Folds is new Cryptol.Folds
     (Acc     => Block,
      Index   => Round_Key_Index,
      Element => Block,
      Seq     => Round_Keys,
      F       => InvRound_Prime);
   --  The prelude's foldl over round keys, with InvRound' as its function.

   function Foldl_Round (Z : Block; Xs : Round_Keys) return Block
   is (Round_Folds.Foldl (Z, Xs));
   --  Cipher.cry: foldl Round, the fold in Cipher's state_rounds = foldl
   --  Round state_initial ws, as the prelude's Folds.Foldl.
   --  @param Z The initial state.
   --  @param Xs The round keys to apply, in order.
   --  @return The state after one Round per element of Xs.

   function Foldl_InvRound (Z : Block; Xs : Round_Keys) return Block
   is (InvRound_Folds.Foldl (Z, Xs));
   --  Cipher.cry: foldl InvRound, the fold in InvCipher's state_rounds =
   --  foldl InvRound state_initial (reverse ws), as the prelude's
   --  Folds.Foldl.
   --  @param Z The initial state.
   --  @param Xs The round keys to apply, in order.
   --  @return The state after one InvRound per element of Xs.

   function Foldl_InvRound_Prime (Z : Block; Xs : Round_Keys) return Block
   is (InvRound_Prime_Folds.Foldl (Z, Xs));
   --  Cipher.cry: foldl InvRound', the fold in InvCipher''s state_rounds
   --  = foldl InvRound' state_initial (reverse ws), as the prelude's
   --  Folds.Foldl.
   --  @param Z The initial state.
   --  @param Xs The round keys to apply, in order.
   --  @return The state after one InvRound' per element of Xs.

   function Reverse_Keys (Xs : Round_Keys) return Round_Keys
   is [for I in Xs'Range => Xs (Xs'First + Xs'Last - I)];
   --  Cryptol's reverse at type [n]Block -> [n]Block, as InvCipher and
   --  InvCipher' apply it to ws. Reverse is an Ada reserved word. The
   --  result has the bounds of Xs. Stated inline, as the prelude's
   --  Sequences.Reverse_Of states it (element I is element Xs'Last - (I -
   --  Xs'First)), not through an instance: through one, Impl's
   --  Decrypt_Block_Prime loses an assertion (RK (J) = W (Nr (K) - J)) to
   --  a timeout at level 2 (#75).
   --  @param Xs The round keys.
   --  @return Xs in reverse order.

end Foundation_Spark.AES.Spec.Cipher;
