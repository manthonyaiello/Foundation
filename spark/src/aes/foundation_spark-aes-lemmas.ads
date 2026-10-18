--  Lemmas about the AES spec layer that the implementation layer
--  (Foundation_Spark.AES.Impl) is proved with. They are not in the Cryptol:
--  each states a property of a spec-layer function that the Cryptol
--  evaluates and SPARK has to prove, and each is a ghost procedure whose
--  postcondition is the property.
--
--  GF(2^8). The spec's Dot is GF28.cry's pmod (pmult b c) m, stated as two
--  recursive folds over bits. The implementation multiplies by the
--  constants of MixColumns and InvMixColumns with xTimes alone. Lemma_Dot
--  connects the two for any constant below 16: Pm gives pmult's closed
--  form (Lemma_Pmult_Fold), the remainder is the dividend itself while the
--  dividend has degree below 8 (Lemma_Pmod_Small), and the last three
--  reduction steps are left to the provers' bit-vector reasoning.
--
--  Folds. Cipher.cry's foldl consumes the round keys from the front, and
--  the implementation's loops apply one round at a time, so its invariant
--  needs the fold over a prefix extended by one key at the back. The
--  Lemma_Foldl_*_Snoc lemmas state that, one per round function.

with Interfaces;
with Foundation_Spark.AES.Spec.Cipher;
with Foundation_Spark.AES.Spec.GF28;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.AES.Lemmas with
  SPARK_Mode,
  Pure,
  Ghost
is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;

   subtype Byte is Spec.Types.Byte;
   --  A byte, the Cryptol [8].

   subtype Poly is Spec.GF28.Poly;
   --  A polynomial over GF(2) of degree below 16, as in GF28.

   function Term (B : Byte; Bit : Natural; D : Byte) return Poly
   is (if (B and Interfaces.Shift_Left (1, Bit)) /= 0
       then Interfaces.Shift_Left (Poly (D), Bit)
       else 0)
   with Pre => Bit <= 7;
   --  One term of the carry-less product of B and D: D shifted by Bit when
   --  bit Bit of B (from the least significant) is set.
   --  @param B The first factor.
   --  @param Bit The position of the bit of B.
   --  @param D The second factor.
   --  @return D * x^^Bit if that bit of B is set, and 0 otherwise.

   function Pm (B, D : Byte) return Poly
   is (Term (B, 0, D) xor Term (B, 1, D) xor Term (B, 2, D)
       xor Term (B, 3, D) xor Term (B, 4, D) xor Term (B, 5, D)
       xor Term (B, 6, D) xor Term (B, 7, D));
   --  The carry-less product of B and D as polynomials over GF(2), in
   --  closed form: the exclusive-or of D * x^^I over the bits I set in B.
   --  @param B The first factor.
   --  @param D The second factor.
   --  @return The product, of degree at most 14.

   procedure Lemma_Pmult_Fold (B, C : Byte; N : Natural)
   with
     Pre                => N <= 8,
     Post               =>
       Spec.GF28.Pmult_Fold (B, C, N)
       = Pm (B, Interfaces.Shift_Right (C, 8 - N)),
     Subprogram_Variant => (Decreases => N);
   --  GF28's pmult fold after N steps is the closed-form product of B with
   --  the leading N bits of C.
   --  @param B The multiplicand.
   --  @param C The multiplier.
   --  @param N The number of steps.

   procedure Lemma_Pmod_Small (X, Y : Poly; N : Natural)
   with
     Pre                => N <= 15 and then Y in 256 .. 511
                           and then X < 2 ** 15
                           and then Interfaces.Shift_Right (X, 15 - N) < 256,
     Post               =>
       Spec.GF28.Pmod_Fold (X, Y, N)
       = Byte (Interfaces.Shift_Right (X, 15 - N)),
     Subprogram_Variant => (Decreases => N);
   --  GF28's pmod fold leaves the leading N bits of X unreduced while they
   --  have degree below 8.
   --  @param X The dividend, a [15].
   --  @param Y The modulus, of degree 8.
   --  @param N The number of steps.

   function xTimes (B : Byte) return Byte renames Spec.GF28.xTimes;
   --  GF28.cry's xTimes.
   --  @param B The byte.
   --  @return B • 0x02.

   function By_xTimes (B, C : Byte) return Byte
   is ((if (B and 1) /= 0 then C else 0)
       xor (if (B and 2) /= 0 then xTimes (C) else 0)
       xor (if (B and 4) /= 0 then xTimes (xTimes (C)) else 0)
       xor (if (B and 8) /= 0 then xTimes (xTimes (xTimes (C))) else 0))
   with Pre => B < 16;
   --  The product B • C for a B below 16, computed with xTimes alone: the
   --  exclusive-or of C • x^^I over the bits I set in B.
   --  @param B The constant factor, below 16.
   --  @param C The other factor.
   --  @return B • C.

   procedure Lemma_Dot (B, C : Byte)
   with
     Pre  => B < 16,
     Post => Spec.GF28.Dot (B, C) = By_xTimes (B, C);
   --  GF28.cry's (•) by a constant below 16 is the exclusive-or of xTimes
   --  powers that By_xTimes computes.
   --  @param B The constant factor.
   --  @param C The other factor.

   use Spec.Types;
   use Spec.Cipher;

   procedure Lemma_MixColumns_Eq (A, B : Block)
   with
     Pre  => A = B,
     Post => MixColumns (A) = MixColumns (B);
   --  MixColumns maps equal states to equal states. Ada's = on arrays is
   --  componentwise, not the provers' equality, so a function of an array
   --  is not known to agree on equal arguments until its definition is
   --  unfolded componentwise. This lemma does that once for MixColumns.
   --  @param A A state.
   --  @param B A state equal to A.

   procedure Lemma_InvMixColumns_Eq (A, B : Block)
   with
     Pre  => A = B,
     Post => InvMixColumns (A) = InvMixColumns (B);
   --  InvMixColumns maps equal states to equal states, as
   --  Lemma_MixColumns_Eq.
   --  @param A A state.
   --  @param B A state equal to A.

   procedure Lemma_Round_Eq (A, B : Block; Ki : Block)
   with
     Pre  => A = B,
     Post => Round (A, Ki) = Round (B, Ki);
   --  Round maps equal states to equal states.
   --  @param A A state.
   --  @param B A state equal to A.
   --  @param Ki The round key.

   procedure Lemma_InvRound_Eq (A, B : Block; Ki : Block)
   with
     Pre  => A = B,
     Post => InvRound (A, Ki) = InvRound (B, Ki);
   --  InvRound maps equal states to equal states.
   --  @param A A state.
   --  @param B A state equal to A.
   --  @param Ki The round key.

   procedure Lemma_InvRound_Prime_Eq (A, B : Block; Ki : Block)
   with
     Pre  => A = B,
     Post => InvRound_Prime (A, Ki) = InvRound_Prime (B, Ki);
   --  InvRound' maps equal states to equal states.
   --  @param A A state.
   --  @param B A state equal to A.
   --  @param Ki The round key.

   procedure Lemma_Foldl_Round_Snoc (Z : Block; Xs : Round_Keys)
   with
     Pre                => Xs'Length > 0,
     Post               =>
       Foldl_Round (Z, Xs)
       = Round (Foldl_Round (Z, Xs (Xs'First .. Xs'Last - 1)), Xs (Xs'Last)),
     Subprogram_Variant => (Decreases => Xs'Length);
   --  Cipher.cry's foldl Round over a non-empty list of round keys is one
   --  Round, by its last key, after the fold over the others.
   --  @param Z The initial state.
   --  @param Xs The round keys.

   procedure Lemma_Foldl_InvRound_Snoc (Z : Block; Xs : Round_Keys)
   with
     Pre                => Xs'Length > 0,
     Post               =>
       Foldl_InvRound (Z, Xs)
       = InvRound (Foldl_InvRound (Z, Xs (Xs'First .. Xs'Last - 1)),
                   Xs (Xs'Last)),
     Subprogram_Variant => (Decreases => Xs'Length);
   --  Cipher.cry's foldl InvRound over a non-empty list of round keys is
   --  one InvRound, by its last key, after the fold over the others.
   --  @param Z The initial state.
   --  @param Xs The round keys.

   procedure Lemma_Foldl_InvRound_Prime_Snoc (Z : Block; Xs : Round_Keys)
   with
     Pre                => Xs'Length > 0,
     Post               =>
       Foldl_InvRound_Prime (Z, Xs)
       = InvRound_Prime
           (Foldl_InvRound_Prime (Z, Xs (Xs'First .. Xs'Last - 1)),
            Xs (Xs'Last)),
     Subprogram_Variant => (Decreases => Xs'Length);
   --  Cipher.cry's foldl InvRound' over a non-empty list of round keys is
   --  one InvRound', by its last key, after the fold over the others.
   --  @param Z The initial state.
   --  @param Xs The round keys.

end Foundation_Spark.AES.Lemmas;
