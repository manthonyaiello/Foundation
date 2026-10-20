--  The properties that algorithms/AES states about itself, proved of the
--  spec layer: GF28.cry's GF28MultiplicationCorrect, SBox.cry's
--  SBoxCorrect and SBoxInverts, Cipher.cry's SubBytesInverts,
--  ShiftRowsInverts, MixColumnsStepInverts, MixColumnsInverts,
--  AddRoundKeyInvolution, RoundInverts, InvCipherEquivalence,
--  CipherInverts and CipherInverts', and Main.cry's EncryptInverts.
--  SBoxCorrect is proved entry by entry, by evaluation, in
--  Foundation_Spark.AES.Spec.SBox.SBox_Entries, a child of SBox so that its
--  slow proof depends on nothing else of the spec layer (issue #70).
--
--  Each property is a ghost procedure named as the Cryptol property, whose
--  postcondition is the property's body and whose parameters are its
--  arguments. Where the Cryptol is polymorphic in the key size k under Key
--  k, the procedure takes K explicitly and requires the typing of its
--  arguments, as the spec layer does. The other procedures are the lemmas
--  the properties are proved with.
--
--  Ada's = on arrays is componentwise, not the provers' equality, so a
--  function applied to two equal arrays is not known to give equal results
--  until it is unfolded. The *_Eq lemmas here, and those of
--  Foundation_Spark.AES.Lemmas, state that once per function.

with Interfaces;
with Foundation_Spark.AES.Spec.Cipher;
with Foundation_Spark.AES.Spec.GF28;
with Foundation_Spark.AES.Spec.Main;
with Foundation_Spark.AES.Spec.SBox;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.AES.Spec.Properties with
  SPARK_Mode,
  Pure,
  Ghost
is

   use Types;
   use Cipher;

   use type Types.Byte;
   use type Interfaces.Unsigned_16;
   use type Main.Bits;

   ----------
   -- GF28 --
   ----------

   function Foldl_Mult (B, C : Byte; N : Natural) return Byte
   is (if N = 0 then 16#00#
       else GF28.xTimes (Foldl_Mult (B, C, N - 1))
            xor (if GF28.Bit (B, N - 1) then C else 16#00#))
   with
     Pre                => N <= 8,
     Subprogram_Variant => (Decreases => N);
   --  GF28.cry, GF28MultiplicationCorrect: the first N steps of
   --  foldl (\a bi -> xTimes a ^ if bi then c else 0x00) 0x00 b, the fold
   --  over the bits bi of B, most significant first, as Cryptol orders
   --  them.
   --  @param B The byte whose bits are folded over.
   --  @param C The other factor.
   --  @param N How many bits of B, from the most significant, to use.
   --  @return The accumulator after N steps.

   procedure GF28MultiplicationCorrect (B, C : Byte)
   with
     Post => GF28.xTimes (B) = GF28.Dot (B, 2)
             and then GF28.Dot (B, C) = Foldl_Mult (B, C, 8);
   --  GF28.cry: property GF28MultiplicationCorrect b c = xTimes b == b • 2
   --  /\ b • c == foldl (\a bi -> xTimes a ^ if bi then c else 0x00) 0x00
   --  b [FIPS-PUB-197 Section 4.2].
   --  @param B The Cryptol's b.
   --  @param C The Cryptol's c.

   ----------
   -- SBox --
   ----------

   procedure SBoxCorrect
   with Post => (for all B in Types.Byte => SBox.Affine (B) = SBox.SBox (B));
   --  SBox.cry: property SBoxCorrect = [ affine b | b <- [0..255] ] ==
   --  SBox [FIPS-PUB-197 Section 5.1.1]: entry B of the S-box is affine B.

   procedure SBoxInverts (B : Byte)
   with Post => SBox.InvSBox (SBox.SBox (B)) = B;
   --  SBox.cry: property SBoxInverts b = InvSBox @ (SBox @ b) == b.
   --  @param B The Cryptol's b.

   ------------
   -- Cipher --
   ------------

   procedure SubBytesInverts (Bs : Block)
   with Post => InvSubBytes (SubBytes (Bs)) = Bs;
   --  Cipher.cry: property SubBytesInverts bs = InvSubBytes (SubBytes bs)
   --  == bs.
   --  @param Bs The Cryptol's bs.

   procedure ShiftRowsInverts (Xs : Block)
   with Post => InvShiftRows (ShiftRows (Xs)) = Xs;
   --  Cipher.cry: property ShiftRowsInverts xs = InvShiftRows (ShiftRows
   --  xs) == xs.
   --  @param Xs The Cryptol's xs.

   procedure MixColumnsStepInverts (B : AESWord)
   with Post => InvMixColumnsStep (MixColumnsStep (B)) = B;
   --  Cipher.cry: property MixColumnsStepInverts b = InvMixColumnsStep
   --  (MixColumnsStep b) == b.
   --  @param B The Cryptol's b.

   procedure MixColumnsInverts (Bs : Block)
   with Post => InvMixColumns (MixColumns (Bs)) = Bs;
   --  Cipher.cry: property MixColumnsInverts bs = InvMixColumns
   --  (MixColumns bs) == bs.
   --  @param Bs The Cryptol's bs.

   procedure AddRoundKeyInvolution (Bs : Block; W : Block)
   with Post => AddRoundKey (AddRoundKey (Bs, W), W) = Bs;
   --  Cipher.cry: property AddRoundKeyInvolution bs w = AddRoundKey
   --  (AddRoundKey bs w) w == bs.
   --  @param Bs The Cryptol's bs.
   --  @param W The Cryptol's w.

   procedure RoundInverts (Xs : Block; Ki : Block)
   with Post => InvRound_Prime (Round (Xs, Ki), Ki) = Xs;
   --  Cipher.cry: property RoundInverts xs ki = InvRound' (Round xs ki) ki
   --  == xs.
   --  @param Xs The Cryptol's xs.
   --  @param Ki The Cryptol's ki.

   procedure InvCipherEquivalence (K : Natural; Ws : Round_Keys; State : Block)
   with
     Pre  => Is_Round_Keys (K, Ws),
     Post => InvCipher (K, Ws, State) = InvCipher_Prime (K, Ws, State);
   --  Cipher.cry: property InvCipherEquivalence ws state = InvCipher`{k}
   --  ws state == InvCipher'`{k} ws state, for {k} (Key k) and
   --  ws : [Nr k + 1]Block.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Ws The Cryptol's ws.
   --  @param State The Cryptol's state.

   procedure CipherInverts_Prime
     (K : Natural; Ws : Round_Keys; State : Block)
   with
     Pre  => Is_Round_Keys (K, Ws),
     Post => InvCipher_Prime (K, Ws, Cipher.Cipher (K, Ws, State)) = State;
   --  Cipher.cry: property CipherInverts' ws state = InvCipher'`{k} ws
   --  (Cipher`{k} ws state) == state, for {k} (Key k) and
   --  ws : [Nr k + 1]Block. CipherInverts is proved from it.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Ws The Cryptol's ws.
   --  @param State The Cryptol's state.

   procedure CipherInverts (K : Natural; Ws : Round_Keys; State : Block)
   with
     Pre  => Is_Round_Keys (K, Ws),
     Post => InvCipher (K, Ws, Cipher.Cipher (K, Ws, State)) = State;
   --  Cipher.cry: property CipherInverts ws state = InvCipher`{k} ws
   --  (Cipher`{k} ws state) == state, for {k} (Key k) and
   --  ws : [Nr k + 1]Block.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Ws The Cryptol's ws.
   --  @param State The Cryptol's state.

   ----------
   -- Main --
   ----------

   procedure EncryptInverts
     (K : Natural; Key : Main.Bits; Input : Main.Block_Bits)
   with
     Pre  => Main.Is_Key_Bits (K, Key),
     Post => Main.Decrypt (K, Key, Main.Encrypt (K, Key, Input)) = Input;
   --  Main.cry: property EncryptInverts key in = AES`{k}.Decrypt key
   --  (AES`{k}.Encrypt key in) == in, for {k} (Key k) and key : [k]. The
   --  Cryptol's in is Input: in is an Ada reserved word.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Key The Cryptol's key.
   --  @param Input The Cryptol's in.

   -------------------------------
   -- Lemmas the above rest on --
   -------------------------------

   subtype Poly is GF28.Poly;
   --  A polynomial over GF(2) of degree below 16, as in GF28.

   function Pmod (X : Poly) return Byte
   is (GF28.Pmod (X, GF28.M));
   --  GF28.cry's pmod x m, the remainder modulo the AES polynomial.
   --  @param X The dividend, a [15].
   --  @return X mod m.

   procedure Lemma_Pmod_Xor (X, Y : Poly; N : Natural)
   with
     Pre                => N <= 15 and then X < 2 ** 15 and then Y < 2 ** 15,
     Post               =>
       GF28.Pmod_Fold (X xor Y, GF28.M, N)
       = (GF28.Pmod_Fold (X, GF28.M, N) xor GF28.Pmod_Fold (Y, GF28.M, N)),
     Subprogram_Variant => (Decreases => N);
   --  The remainder is linear: the first N steps of pmod (x ^ y) m are
   --  those of pmod x m and pmod y m, added.
   --  @param X A dividend.
   --  @param Y A dividend.
   --  @param N The number of steps.

   procedure Lemma_Pmod_Shift (X : Poly; N : Natural)
   with
     Pre                => N <= 14 and then X < 2 ** 14,
     Post               =>
       GF28.Pmod_Fold (Interfaces.Shift_Left (X, 1), GF28.M, N)
       = GF28.Pmod_Fold (X, GF28.M, N + 1),
     Subprogram_Variant => (Decreases => N);
   --  The first N bits of x * x, as a [15], are the first N + 1 bits of
   --  x, whose first bit is 0, so their remainders agree.
   --  @param X The dividend, of degree below 14.
   --  @param N The number of steps.

   procedure Lemma_Pmod_Times_X (X : Poly)
   with
     Pre  => X < 2 ** 14,
     Post => Pmod (Interfaces.Shift_Left (X, 1)) = GF28.xTimes (Pmod (X));
   --  pmod (x * x) m is xTimes (pmod x m).
   --  @param X The dividend, of degree below 14.

   procedure Lemma_Pmult_Bound (X, Y : Byte; N : Natural)
   with
     Pre                => N <= 8,
     Post               => GF28.Pmult_Fold (X, Y, N) < 2 ** (7 + N),
     Subprogram_Variant => (Decreases => N);
   --  After N steps, pmult's partial product has degree below 7 + N.
   --  @param X The multiplicand.
   --  @param Y The multiplier.
   --  @param N The number of steps.

   procedure Lemma_Pmod_Pmult_Fold (Y, X : Byte; N : Natural)
   with
     Pre                => N <= 8,
     Post               =>
       Pmod (GF28.Pmult_Fold (X, Y, N)) = Foldl_Mult (Y, X, N),
     Subprogram_Variant => (Decreases => N);
   --  The remainder of the product of X with the first N bits of Y is the
   --  first N steps of GF28MultiplicationCorrect's fold over Y.
   --  @param Y The byte whose bits are folded over.
   --  @param X The other factor.
   --  @param N The number of steps.

   procedure Lemma_Pmult_Commutes (X, Y : Byte)
   with Post => GF28.Pmult (X, Y) = GF28.Pmult (Y, X);
   --  pmult is commutative.
   --  @param X A factor.
   --  @param Y A factor.

   procedure Lemma_xTimes_Xor (A, B : Byte)
   with
     Post => GF28.xTimes (A xor B) = (GF28.xTimes (A) xor GF28.xTimes (B));
   --  xTimes is linear.
   --  @param A A byte.
   --  @param B A byte.

   procedure Lemma_Dot_Xor (K, A, B : Byte)
   with
     Pre  => K < 16,
     Post => GF28.Dot (K, A xor B) = (GF28.Dot (K, A) xor GF28.Dot (K, B));
   --  (•) by a constant below 16 is linear.
   --  @param K The constant.
   --  @param A A byte.
   --  @param B A byte.

   procedure Lemma_Dot_Xor4 (K, A, B, C, D : Byte)
   with
     Pre  => K < 16,
     Post => GF28.Dot (K, A xor B xor C xor D)
             = (GF28.Dot (K, A) xor GF28.Dot (K, B) xor GF28.Dot (K, C)
                xor GF28.Dot (K, D));
   --  Lemma_Dot_Xor for four terms.
   --  @param K The constant.
   --  @param A A byte.
   --  @param B A byte.
   --  @param C A byte.
   --  @param D A byte.

   procedure Lemma_Coefficients (X : Byte)
   with
     Post =>
       (GF28.Dot (16#0e#, GF28.Dot (16#02#, X)) xor GF28.Dot (16#0b#, X)
        xor GF28.Dot (16#0d#, X) xor GF28.Dot (16#09#, GF28.Dot (16#03#, X)))
       = X
       and then
       (GF28.Dot (16#0e#, GF28.Dot (16#03#, X))
        xor GF28.Dot (16#0b#, GF28.Dot (16#02#, X))
        xor GF28.Dot (16#0d#, X) xor GF28.Dot (16#09#, X))
       = 0
       and then
       (GF28.Dot (16#0e#, X) xor GF28.Dot (16#0b#, GF28.Dot (16#03#, X))
        xor GF28.Dot (16#0d#, GF28.Dot (16#02#, X)) xor GF28.Dot (16#09#, X))
       = 0
       and then
       (GF28.Dot (16#0e#, X) xor GF28.Dot (16#0b#, X)
        xor GF28.Dot (16#0d#, GF28.Dot (16#03#, X))
        xor GF28.Dot (16#09#, GF28.Dot (16#02#, X)))
       = 0;
   --  The entries of the product of InvMixColumns' matrix, rows rotated
   --  from [0x0e, 0x0b, 0x0d, 0x09], with MixColumns' matrix, rows
   --  rotated from [0x02, 0x03, 0x01, 0x01]: the circulant identity
   --  matrix, applied to X. The four conjuncts are the entries at
   --  distance 0, 1, 2 and 3 from the diagonal.
   --  @param X The byte the entries multiply.

   procedure Lemma_InvRound_Key_Eq (A : Block; K1, K2 : Block)
   with
     Pre  => K1 = K2,
     Post => InvRound (A, K1) = InvRound (A, K2);
   --  InvRound maps equal round keys to equal states.
   --  @param A The state.
   --  @param K1 A round key.
   --  @param K2 A round key equal to K1.

   procedure Lemma_InvRound_Prime_Key_Eq (A : Block; K1, K2 : Block)
   with
     Pre  => K1 = K2,
     Post => InvRound_Prime (A, K1) = InvRound_Prime (A, K2);
   --  InvRound' maps equal round keys to equal states.
   --  @param A The state.
   --  @param K1 A round key.
   --  @param K2 A round key equal to K1.

   procedure Lemma_Foldl_InvRound_Eq (A, B : Block; Xs, Ys : Round_Keys)
   with
     Pre                => A = B and then Xs = Ys,
     Post               => Foldl_InvRound (A, Xs) = Foldl_InvRound (B, Ys),
     Subprogram_Variant => (Decreases => Xs'Length);
   --  foldl InvRound maps equal states and equal lists of round keys
   --  (equal as Ada arrays: same length and components, whatever their
   --  bounds) to equal states.
   --  @param A An initial state.
   --  @param B An initial state equal to A.
   --  @param Xs Round keys.
   --  @param Ys Round keys equal to Xs.

   procedure Lemma_Foldl_InvRound_Prime_Eq
     (A, B : Block; Xs, Ys : Round_Keys)
   with
     Pre                => A = B and then Xs = Ys,
     Post               =>
       Foldl_InvRound_Prime (A, Xs) = Foldl_InvRound_Prime (B, Ys),
     Subprogram_Variant => (Decreases => Xs'Length);
   --  foldl InvRound' maps equal states and equal lists of round keys to
   --  equal states, as Lemma_Foldl_InvRound_Eq.
   --  @param A An initial state.
   --  @param B An initial state equal to A.
   --  @param Xs Round keys.
   --  @param Ys Round keys equal to Xs.

   procedure Lemma_Foldl_Equivalence (Z : Block; Xs : Round_Keys)
   with
     Post               =>
       Foldl_InvRound_Prime (InvSubBytes (InvShiftRows (Z)), Xs)
       = InvSubBytes (InvShiftRows (Foldl_InvRound (Z, Xs))),
     Subprogram_Variant => (Decreases => Xs'Length);
   --  foldl InvRound' from InvSubBytes (InvShiftRows z) is InvSubBytes
   --  (InvShiftRows) of foldl InvRound from z: InvRound' is InvRound with
   --  InvSubBytes and InvShiftRows moved from its front to its back.
   --  @param Z The initial state of foldl InvRound.
   --  @param Xs The round keys.

   procedure Lemma_Foldl_Inverts (Z : Block; Xs : Round_Keys)
   with
     Post               =>
       Foldl_InvRound_Prime (Foldl_Round (Z, Xs), Reverse_Keys (Xs)) = Z,
     Subprogram_Variant => (Decreases => Xs'Length);
   --  foldl InvRound' over the reversed round keys undoes foldl Round.
   --  @param Z The initial state of foldl Round.
   --  @param Xs The round keys.

   procedure Lemma_Split_Join_Block (B : Block)
   with Post => Main.Split_Block (Main.Join_Block (B)) = B;
   --  Cryptol's split at [128] -> [16][8] undoes its join at [16][8] ->
   --  [128].
   --  @param B The block.

   procedure Lemma_InvCipher_Eq (K : Natural; Ws : Round_Keys; A, B : Block)
   with
     Pre  => Is_Round_Keys (K, Ws) and then A = B,
     Post => InvCipher (K, Ws, A) = InvCipher (K, Ws, B);
   --  InvCipher maps equal blocks to equal blocks.
   --  @param K The key size in bits.
   --  @param Ws The round keys.
   --  @param A A block.
   --  @param B A block equal to A.

end Foundation_Spark.AES.Spec.Properties;
