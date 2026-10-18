--  The round transformations of algorithms/AES/Cipher.cry
--  [FIPS-PUB-197 Sections 5.1 and 5.3]: SubBytes, ShiftRows,
--  MixColumnsStep, MixColumns, AddRoundKey, their inverses, Round,
--  InvRound and InvRound', and the ciphers Cipher, InvCipher and
--  InvCipher'.
--
--  Cipher.cry's properties (M1.5) are not stated here. Ada has no primes
--  in names, so InvRound' is InvRound_Prime and InvCipher' is
--  InvCipher_Prime.
--
--  Cipher.cry's foldl over the middle round keys is a recursive ghost
--  fold per round function (Foldl_Round, Foldl_InvRound,
--  Foldl_InvRound_Prime), each stated as the Cryptol prelude's foldl:
--  foldl f z [] = z and foldl f z ([x] # xs) = foldl f (f z x) xs.
--
--  Cipher.cry's argument pattern [w0] # ws # [wr] over the round keys
--  w : [Nr k + 1]Block is index arithmetic on a Round_Keys W with
--  Is_Round_Keys (K, W), so W'First = 0 and W'Last = Nr (K): w0 is W (0),
--  ws is the slice W (1 .. Nr (K) - 1), and wr is W (Nr (K)). Following
--  the campaign's decision on key sizes, the key size K is an explicit
--  parameter in the place of the Cryptol's type application `{k}.

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

   function SubBytes (Bs : Block) return Block
   is [for I in Block_Index => SBox.SBox (Bs (I))];
   --  Cipher.cry: SubBytes bs = SBox @@ bs [FIPS-PUB-197 Section 5.1.1].
   --  @param Bs The state.
   --  @return The state with the S-box applied to each byte.

   function InvSubBytes (Bs : Block) return Block
   is [for I in Block_Index => SBox.InvSBox (Bs (I))];
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
   is [for I in Block_Index => Bs (ShiftRows_Indices (I))];
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
   is [for I in Block_Index => Bs (InvShiftRows_Indices (I))];
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

   function Foldl_Round (Z : Block; Xs : Round_Keys) return Block
   is (if Xs'Length = 0 then Z
       else Foldl_Round (Round (Z, Xs (Xs'First)),
                         Xs (Xs'First + 1 .. Xs'Last)))
   with Subprogram_Variant => (Decreases => Xs'Length);
   --  Cipher.cry: foldl Round, the fold in Cipher's state_rounds = foldl
   --  Round state_initial ws. As the prelude's foldl: Z when Xs is empty,
   --  and otherwise the fold of the rest of Xs from Round (Z, x) for its
   --  first element x.
   --  @param Z The initial state.
   --  @param Xs The round keys to apply, in order.
   --  @return The state after one Round per element of Xs.

   function Foldl_InvRound (Z : Block; Xs : Round_Keys) return Block
   is (if Xs'Length = 0 then Z
       else Foldl_InvRound (InvRound (Z, Xs (Xs'First)),
                            Xs (Xs'First + 1 .. Xs'Last)))
   with Subprogram_Variant => (Decreases => Xs'Length);
   --  Cipher.cry: foldl InvRound, the fold in InvCipher's state_rounds =
   --  foldl InvRound state_initial (reverse ws), stated as Foldl_Round.
   --  @param Z The initial state.
   --  @param Xs The round keys to apply, in order.
   --  @return The state after one InvRound per element of Xs.

   function Foldl_InvRound_Prime (Z : Block; Xs : Round_Keys) return Block
   is (if Xs'Length = 0 then Z
       else Foldl_InvRound_Prime (InvRound_Prime (Z, Xs (Xs'First)),
                                  Xs (Xs'First + 1 .. Xs'Last)))
   with Subprogram_Variant => (Decreases => Xs'Length);
   --  Cipher.cry: foldl InvRound', the fold in InvCipher''s state_rounds
   --  = foldl InvRound' state_initial (reverse ws), stated as Foldl_Round.
   --  @param Z The initial state.
   --  @param Xs The round keys to apply, in order.
   --  @return The state after one InvRound' per element of Xs.

   function Reverse_Keys (Xs : Round_Keys) return Round_Keys
   is [for I in Xs'Range => Xs (Xs'First + Xs'Last - I)];
   --  Cryptol's reverse at type [n]Block -> [n]Block, as InvCipher and
   --  InvCipher' apply it to ws. Reverse is an Ada reserved word. The
   --  result has the bounds of Xs.
   --  @param Xs The round keys.
   --  @return Xs in reverse order.

   function Cipher (K : Natural; W : Round_Keys; Input : Block) return Block
   is (AddRoundKey (ShiftRows (SubBytes
                      (Foldl_Round (AddRoundKey (Input, W (0)),
                                    W (1 .. Nr (K) - 1)))),
                    W (Nr (K))))
   with Pre => Is_Round_Keys (K, W);
   --  Cipher.cry: Cipher : {k} (Key k) => [Nr k + 1]Block -> Block ->
   --  Block, AES encryption [FIPS-PUB-197 Section 5.1]. NSA declares it
   --  foreign, with Rust behind it. This mirrors its Cryptol body,
   --  Cipher ([w0] # ws # [wr]) in = state_final, where
   --  state_initial = AddRoundKey in w0,
   --  state_rounds = foldl Round state_initial ws, and
   --  state_final = AddRoundKey (ShiftRows (SubBytes state_rounds)) wr,
   --  with w0 = W (0), ws = W (1 .. Nr (K) - 1) and wr = W (Nr (K)). The
   --  Cryptol's in is Input: in is an Ada reserved word.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param W The Nr (K) + 1 round keys, from KeyExpansion.
   --  @param Input The plaintext block.
   --  @return The ciphertext block.

   function InvCipher
     (K : Natural; W : Round_Keys; Input : Block) return Block
   is (AddRoundKey (InvSubBytes (InvShiftRows
                      (Foldl_InvRound (AddRoundKey (Input, W (Nr (K))),
                                       Reverse_Keys (W (1 .. Nr (K) - 1))))),
                    W (0)))
   with Pre => Is_Round_Keys (K, W);
   --  Cipher.cry: InvCipher : {k} (Key k) => [Nr k + 1]Block -> Block ->
   --  Block, AES decryption [FIPS-PUB-197 Section 5.3]. NSA declares it
   --  foreign, with Rust behind it. This mirrors its Cryptol body,
   --  InvCipher ([w0] # ws # [wr]) in = state_final, where
   --  state_initial = AddRoundKey in wr,
   --  state_rounds = foldl InvRound state_initial (reverse ws), and
   --  state_final = AddRoundKey (InvSubBytes (InvShiftRows state_rounds))
   --  w0, with w0, ws and wr as in Cipher.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param W The Nr (K) + 1 round keys, from KeyExpansion.
   --  @param Input The ciphertext block.
   --  @return The plaintext block.

   function InvCipher_Prime
     (K : Natural; W : Round_Keys; Input : Block) return Block
   is (AddRoundKey
         (Foldl_InvRound_Prime
            (InvSubBytes (InvShiftRows (AddRoundKey (Input, W (Nr (K))))),
             Reverse_Keys (W (1 .. Nr (K) - 1))),
          W (0)))
   with Pre => Is_Round_Keys (K, W);
   --  Cipher.cry: InvCipher' : {k} (Key k) => [Nr k + 1]Block -> Block ->
   --  Block, the alternate decryption that is more obviously the inverse
   --  of Cipher [FIPS-PUB-197 Section 5.3]: InvCipher' ([w0] # ws # [wr])
   --  in = state_final, where
   --  state_initial = InvSubBytes (InvShiftRows (AddRoundKey in wr)),
   --  state_rounds = foldl InvRound' state_initial (reverse ws), and
   --  state_final = AddRoundKey state_rounds w0, with w0, ws and wr as in
   --  Cipher.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param W The Nr (K) + 1 round keys, from KeyExpansion.
   --  @param Input The ciphertext block.
   --  @return The plaintext block.

end Foundation_Spark.AES.Spec.Cipher;
