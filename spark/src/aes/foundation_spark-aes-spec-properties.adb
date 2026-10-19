with Foundation_Spark.AES.Lemmas;
with Foundation_Spark.AES.Spec.KeyExpansion;
with Foundation_Spark.AES.Spec.Properties.SBox_Entries;

package body Foundation_Spark.AES.Spec.Properties with
  SPARK_Mode
is

   -------------------------------
   -- GF28MultiplicationCorrect --
   -------------------------------

   --  GF28MultiplicationCorrect's two conjuncts are proved apart, each in a
   --  lemma of its own, so that the provers never unfold Dot, Pmult_Fold,
   --  Pmod_Fold and Foldl_Mult for both at once: together, the one
   --  postcondition ran out of time on x86_64 (PR #46).

   procedure Lemma_xTimes_Dot (B : Byte)
   with Post => GF28.xTimes (B) = GF28.Dot (B, 2);
   --  GF28MultiplicationCorrect's first conjunct: xTimes b == b • 2. The
   --  fold over the bits of 2 is 0 for six steps, then B, then xTimes B.
   --  @param B The Cryptol's b.

   procedure Lemma_Dot_Foldl (B, C : Byte)
   with Post => GF28.Dot (B, C) = Foldl_Mult (B, C, 8);
   --  GF28MultiplicationCorrect's second conjunct: b • c is the fold over
   --  the bits of b.
   --  @param B The Cryptol's b.
   --  @param C The Cryptol's c.

   procedure Lemma_xTimes_Dot (B : Byte) is
   begin
      Lemma_Pmod_Pmult_Fold (2, B, 8);
      pragma Assert (GF28.Dot (B, 2) = Foldl_Mult (2, B, 8));
      pragma Assert (Foldl_Mult (2, B, 6) = 0);
      pragma Assert (Foldl_Mult (2, B, 7) = B);
   end Lemma_xTimes_Dot;

   procedure Lemma_Dot_Foldl (B, C : Byte) is
   begin
      Lemma_Pmult_Commutes (B, C);
      Lemma_Pmod_Pmult_Fold (B, C, 8);
      pragma Assert (GF28.Dot (B, C) = Pmod (GF28.Pmult_Fold (C, B, 8)));
   end Lemma_Dot_Foldl;

   procedure GF28MultiplicationCorrect (B, C : Byte) is
   begin
      Lemma_xTimes_Dot (B);
      Lemma_Dot_Foldl (B, C);
   end GF28MultiplicationCorrect;

   -----------------
   -- SBoxCorrect --
   -----------------

   procedure SBoxCorrect is
   begin
      for B in Types.Byte loop
         SBox_Entries.Lemma_SBox_Entry (B);
         pragma Loop_Invariant
           (for all X in 0 .. B => SBox.Affine (X) = SBox.SBox (X));
      end loop;
   end SBoxCorrect;

   -----------------
   -- SBoxInverts --
   -----------------

   procedure SBoxInverts (B : Byte) is
   begin
      null;
   end SBoxInverts;

   ---------------------
   -- SubBytesInverts --
   ---------------------

   procedure SubBytesInverts (Bs : Block) is
   begin
      for I in Block_Index loop
         SBoxInverts (Bs (I));
         pragma Loop_Invariant
           (for all J in 0 .. I =>
              SBox.InvSBox (SBox.SBox (Bs (J))) = Bs (J));
      end loop;
   end SubBytesInverts;

   ----------------------
   -- ShiftRowsInverts --
   ----------------------

   procedure ShiftRowsInverts (Xs : Block) is
   begin
      null;
   end ShiftRowsInverts;

   ---------------------------
   -- MixColumnsStepInverts --
   ---------------------------

   procedure MixColumnsStepInverts (B : AESWord) is
   begin
      Lemma_Dot_Xor4
        (16#0e#, GF28.Dot (16#02#, B (0)), GF28.Dot (16#03#, B (1)),
         B (2), B (3));
      Lemma_Dot_Xor4
        (16#0b#, B (0), GF28.Dot (16#02#, B (1)),
         GF28.Dot (16#03#, B (2)), B (3));
      Lemma_Dot_Xor4
        (16#0d#, B (0), B (1),
         GF28.Dot (16#02#, B (2)), GF28.Dot (16#03#, B (3)));
      Lemma_Dot_Xor4
        (16#09#, GF28.Dot (16#03#, B (0)), B (1),
         B (2), GF28.Dot (16#02#, B (3)));
      Lemma_Dot_Xor4
        (16#09#, GF28.Dot (16#02#, B (0)), GF28.Dot (16#03#, B (1)),
         B (2), B (3));
      Lemma_Dot_Xor4
        (16#0e#, B (0), GF28.Dot (16#02#, B (1)),
         GF28.Dot (16#03#, B (2)), B (3));
      Lemma_Dot_Xor4
        (16#0b#, B (0), B (1),
         GF28.Dot (16#02#, B (2)), GF28.Dot (16#03#, B (3)));
      Lemma_Dot_Xor4
        (16#0d#, GF28.Dot (16#03#, B (0)), B (1),
         B (2), GF28.Dot (16#02#, B (3)));
      Lemma_Dot_Xor4
        (16#0d#, GF28.Dot (16#02#, B (0)), GF28.Dot (16#03#, B (1)),
         B (2), B (3));
      Lemma_Dot_Xor4
        (16#09#, B (0), GF28.Dot (16#02#, B (1)),
         GF28.Dot (16#03#, B (2)), B (3));
      Lemma_Dot_Xor4
        (16#0e#, B (0), B (1),
         GF28.Dot (16#02#, B (2)), GF28.Dot (16#03#, B (3)));
      Lemma_Dot_Xor4
        (16#0b#, GF28.Dot (16#03#, B (0)), B (1),
         B (2), GF28.Dot (16#02#, B (3)));
      Lemma_Dot_Xor4
        (16#0b#, GF28.Dot (16#02#, B (0)), GF28.Dot (16#03#, B (1)),
         B (2), B (3));
      Lemma_Dot_Xor4
        (16#0d#, B (0), GF28.Dot (16#02#, B (1)),
         GF28.Dot (16#03#, B (2)), B (3));
      Lemma_Dot_Xor4
        (16#09#, B (0), B (1),
         GF28.Dot (16#02#, B (2)), GF28.Dot (16#03#, B (3)));
      Lemma_Dot_Xor4
        (16#0e#, GF28.Dot (16#03#, B (0)), B (1),
         B (2), GF28.Dot (16#02#, B (3)));
      Lemma_Coefficients (B (0));
      Lemma_Coefficients (B (1));
      Lemma_Coefficients (B (2));
      Lemma_Coefficients (B (3));
      pragma Assert (InvMixColumnsStep (MixColumnsStep (B)) (0) = B (0));
      pragma Assert (InvMixColumnsStep (MixColumnsStep (B)) (1) = B (1));
      pragma Assert (InvMixColumnsStep (MixColumnsStep (B)) (2) = B (2));
      pragma Assert (InvMixColumnsStep (MixColumnsStep (B)) (3) = B (3));
   end MixColumnsStepInverts;

   -----------------------
   -- MixColumnsInverts --
   -----------------------

   procedure MixColumnsInverts (Bs : Block) is
      Cols : constant Columns := Split (Bs);
      Mixed : constant Columns :=
        [for J in AESWord_Index => MixColumnsStep (Cols (J))];
   begin
      for J in AESWord_Index loop
         MixColumnsStepInverts (Cols (J));
         pragma Loop_Invariant
           (for all L in 0 .. J =>
              InvMixColumnsStep (MixColumnsStep (Cols (L))) = Cols (L));
      end loop;
      pragma Assert (MixColumns (Bs) = Join (Mixed));
      pragma Assert (Split (MixColumns (Bs)) = Mixed);
   end MixColumnsInverts;

   ---------------------------
   -- AddRoundKeyInvolution --
   ---------------------------

   procedure AddRoundKeyInvolution (Bs : Block; W : Block) is
   begin
      null;
   end AddRoundKeyInvolution;

   ------------------
   -- RoundInverts --
   ------------------

   procedure RoundInverts (Xs : Block; Ki : Block) is
      S1 : constant Block := ShiftRows (SubBytes (Xs));
      S2 : constant Block := MixColumns (S1);
   begin
      AddRoundKeyInvolution (S2, Ki);
      Lemmas.Lemma_InvMixColumns_Eq (AddRoundKey (Round (Xs, Ki), Ki), S2);
      MixColumnsInverts (S1);
      ShiftRowsInverts (SubBytes (Xs));
      SubBytesInverts (Xs);
   end RoundInverts;

   --------------------
   -- Lemma_Pmod_Xor --
   --------------------

   procedure Lemma_Pmod_Xor (X, Y : Poly; N : Natural) is
   begin
      if N > 0 then
         Lemma_Pmod_Xor (X, Y, N - 1);
      end if;
   end Lemma_Pmod_Xor;

   ----------------------
   -- Lemma_Pmod_Shift --
   ----------------------

   procedure Lemma_Pmod_Shift (X : Poly; N : Natural) is
   begin
      if N > 0 then
         Lemma_Pmod_Shift (X, N - 1);
         pragma Assert
           (GF28.Product_Bit (Interfaces.Shift_Left (X, 1), N - 1)
            = GF28.Product_Bit (X, N));
      else
         pragma Assert (not GF28.Product_Bit (X, 0));
      end if;
   end Lemma_Pmod_Shift;

   ------------------------
   -- Lemma_Pmod_Times_X --
   ------------------------

   procedure Lemma_Pmod_Times_X (X : Poly) is
   begin
      Lemma_Pmod_Shift (X, 14);
      pragma Assert
        (not GF28.Product_Bit (Interfaces.Shift_Left (X, 1), 14));
   end Lemma_Pmod_Times_X;

   -----------------------
   -- Lemma_Pmult_Bound --
   -----------------------

   procedure Lemma_Pmult_Bound (X, Y : Byte; N : Natural) is
   begin
      if N > 0 then
         Lemma_Pmult_Bound (X, Y, N - 1);
      end if;
   end Lemma_Pmult_Bound;

   ---------------------------
   -- Lemma_Pmod_Pmult_Fold --
   ---------------------------

   procedure Lemma_Pmod_Pmult_Fold (Y, X : Byte; N : Natural) is
   begin
      if N > 0 then
         declare
            P : constant Poly := GF28.Pmult_Fold (X, Y, N - 1);
            T : constant Poly :=
              (if GF28.Bit (Y, N - 1) then Poly (X) else 0);
         begin
            Lemma_Pmod_Pmult_Fold (Y, X, N - 1);
            Lemma_Pmult_Bound (X, Y, N - 1);
            pragma Assert
              (GF28.Pmult_Fold (X, Y, N)
               = (Interfaces.Shift_Left (P, 1) xor T));
            Lemma_Pmod_Xor (Interfaces.Shift_Left (P, 1), T, 15);
            Lemma_Pmod_Times_X (P);
            Lemmas.Lemma_Pmod_Small (T, GF28.M, 15);
         end;
      else
         Lemmas.Lemma_Pmod_Small (0, GF28.M, 15);
      end if;
   end Lemma_Pmod_Pmult_Fold;

   --------------------------
   -- Lemma_Pmult_Commutes --
   --------------------------

   procedure Lemma_Pmult_Commutes (X, Y : Byte) is
   begin
      Lemmas.Lemma_Pmult_Fold (X, Y, 8);
      Lemmas.Lemma_Pmult_Fold (Y, X, 8);
   end Lemma_Pmult_Commutes;

   ----------------------
   -- Lemma_xTimes_Xor --
   ----------------------

   procedure Lemma_xTimes_Xor (A, B : Byte) is null;

   -------------------
   -- Lemma_Dot_Xor --
   -------------------

   procedure Lemma_Dot_Xor (K, A, B : Byte) is
      use GF28;
   begin
      Lemmas.Lemma_Dot (K, A);
      Lemmas.Lemma_Dot (K, B);
      Lemmas.Lemma_Dot (K, A xor B);
      Lemma_xTimes_Xor (A, B);
      Lemma_xTimes_Xor (xTimes (A), xTimes (B));
      Lemma_xTimes_Xor (xTimes (xTimes (A)), xTimes (xTimes (B)));
   end Lemma_Dot_Xor;

   --------------------
   -- Lemma_Dot_Xor4 --
   --------------------

   procedure Lemma_Dot_Xor4 (K, A, B, C, D : Byte) is
   begin
      Lemma_Dot_Xor (K, A xor B xor C, D);
      Lemma_Dot_Xor (K, A xor B, C);
      Lemma_Dot_Xor (K, A, B);
   end Lemma_Dot_Xor4;

   ------------------------
   -- Lemma_Coefficients --
   ------------------------

   procedure Lemma_Coefficients (X : Byte) is
      use GF28;
   begin
      Lemmas.Lemma_Dot (16#02#, X);
      Lemmas.Lemma_Dot (16#03#, X);
      Lemmas.Lemma_Dot (16#09#, X);
      Lemmas.Lemma_Dot (16#0b#, X);
      Lemmas.Lemma_Dot (16#0d#, X);
      Lemmas.Lemma_Dot (16#0e#, X);
      Lemmas.Lemma_Dot (16#09#, GF28.Dot (16#02#, X));
      Lemmas.Lemma_Dot (16#09#, GF28.Dot (16#03#, X));
      Lemmas.Lemma_Dot (16#0b#, GF28.Dot (16#02#, X));
      Lemmas.Lemma_Dot (16#0b#, GF28.Dot (16#03#, X));
      Lemmas.Lemma_Dot (16#0d#, GF28.Dot (16#02#, X));
      Lemmas.Lemma_Dot (16#0d#, GF28.Dot (16#03#, X));
      Lemmas.Lemma_Dot (16#0e#, GF28.Dot (16#02#, X));
      Lemmas.Lemma_Dot (16#0e#, GF28.Dot (16#03#, X));
      Lemma_xTimes_Xor (X, xTimes (X));
      Lemma_xTimes_Xor (xTimes (X), xTimes (xTimes (X)));
      Lemma_xTimes_Xor (xTimes (xTimes (X)), xTimes (xTimes (xTimes (X))));
   end Lemma_Coefficients;

   --------------------
   -- Lemma_Inner_Eq --
   --------------------

   procedure Lemma_Inner_Eq (A, B : GF2.Poly_State) is
   begin
      if A (3) /= 0 then
         pragma Assert (GF2.Inner_Step (A) = GF2.Inner_Step (B));
         Lemma_Inner_Eq (GF2.Inner_Step (A), GF2.Inner_Step (B));
      end if;
   end Lemma_Inner_Eq;

   ----------------
   -- Lemma_Step --
   ----------------

   procedure Lemma_Step (S, T, F : GF2.Poly_State) is
   begin
      Lemma_Inner_Eq (GF2.Inner_Step (S), T);
      pragma Assert (GF2.Inner (GF2.Inner_Step (S)) = F);
   end Lemma_Step;

   ---------------------------
   -- Lemma_InvRound_Key_Eq --
   ---------------------------

   procedure Lemma_InvRound_Key_Eq (A : Block; K1, K2 : Block) is
      S : constant Block := InvSubBytes (InvShiftRows (A));
   begin
      pragma Assert (AddRoundKey (S, K1) = AddRoundKey (S, K2));
      Lemmas.Lemma_InvMixColumns_Eq (AddRoundKey (S, K1), AddRoundKey (S, K2));
   end Lemma_InvRound_Key_Eq;

   ---------------------------------
   -- Lemma_InvRound_Prime_Key_Eq --
   ---------------------------------

   procedure Lemma_InvRound_Prime_Key_Eq (A : Block; K1, K2 : Block) is
   begin
      pragma Assert (AddRoundKey (A, K1) = AddRoundKey (A, K2));
      Lemmas.Lemma_InvMixColumns_Eq (AddRoundKey (A, K1), AddRoundKey (A, K2));
   end Lemma_InvRound_Prime_Key_Eq;

   -----------------------------
   -- Lemma_Foldl_InvRound_Eq --
   -----------------------------

   procedure Lemma_Foldl_InvRound_Eq (A, B : Block; Xs, Ys : Round_Keys) is
   begin
      if Xs'Length > 0 then
         Lemmas.Lemma_InvRound_Eq (A, B, Xs (Xs'First));
         Lemma_InvRound_Key_Eq (B, Xs (Xs'First), Ys (Ys'First));
         pragma Assert
           (Xs (Xs'First + 1 .. Xs'Last) = Ys (Ys'First + 1 .. Ys'Last));
         Lemma_Foldl_InvRound_Eq
           (InvRound (A, Xs (Xs'First)), InvRound (B, Ys (Ys'First)),
            Xs (Xs'First + 1 .. Xs'Last), Ys (Ys'First + 1 .. Ys'Last));
      end if;
   end Lemma_Foldl_InvRound_Eq;

   -----------------------------------
   -- Lemma_Foldl_InvRound_Prime_Eq --
   -----------------------------------

   procedure Lemma_Foldl_InvRound_Prime_Eq
     (A, B : Block; Xs, Ys : Round_Keys) is
   begin
      if Xs'Length > 0 then
         Lemmas.Lemma_InvRound_Prime_Eq (A, B, Xs (Xs'First));
         Lemma_InvRound_Prime_Key_Eq (B, Xs (Xs'First), Ys (Ys'First));
         pragma Assert
           (Xs (Xs'First + 1 .. Xs'Last) = Ys (Ys'First + 1 .. Ys'Last));
         Lemma_Foldl_InvRound_Prime_Eq
           (InvRound_Prime (A, Xs (Xs'First)),
            InvRound_Prime (B, Ys (Ys'First)),
            Xs (Xs'First + 1 .. Xs'Last), Ys (Ys'First + 1 .. Ys'Last));
      end if;
   end Lemma_Foldl_InvRound_Prime_Eq;

   -----------------------------
   -- Lemma_Foldl_Equivalence --
   -----------------------------

   procedure Lemma_Foldl_Equivalence (Z : Block; Xs : Round_Keys) is
   begin
      if Xs'Length > 0 then
         Lemma_Foldl_Equivalence
           (InvRound (Z, Xs (Xs'First)), Xs (Xs'First + 1 .. Xs'Last));
         Lemma_Foldl_InvRound_Prime_Eq
           (InvRound_Prime (InvSubBytes (InvShiftRows (Z)), Xs (Xs'First)),
            InvSubBytes (InvShiftRows (InvRound (Z, Xs (Xs'First)))),
            Xs (Xs'First + 1 .. Xs'Last), Xs (Xs'First + 1 .. Xs'Last));
      end if;
   end Lemma_Foldl_Equivalence;

   --------------------------
   -- InvCipherEquivalence --
   --------------------------

   procedure InvCipherEquivalence
     (K : Natural; Ws : Round_Keys; State : Block)
   is
      Rev : constant Round_Keys := Reverse_Keys (Ws (1 .. Nr (K) - 1));
      S0  : constant Block := AddRoundKey (State, Ws (Nr (K)));
   begin
      Lemma_Foldl_Equivalence (S0, Rev);
   end InvCipherEquivalence;

   -------------------------
   -- Lemma_Foldl_Inverts --
   -------------------------

   procedure Lemma_Foldl_Inverts (Z : Block; Xs : Round_Keys) is
   begin
      if Xs'Length > 0 then
         declare
            Init : constant Round_Keys := Xs (Xs'First .. Xs'Last - 1);
            X    : constant Block := Xs (Xs'Last);
            F    : constant Block := Foldl_Round (Z, Init);
            Rev  : constant Round_Keys := Reverse_Keys (Xs);
         begin
            Lemma_Foldl_Inverts (Z, Init);
            Lemmas.Lemma_Foldl_Round_Snoc (Z, Xs);
            pragma Assert (Foldl_Round (Z, Xs) = Round (F, X));
            pragma Assert (Rev (Rev'First) = X);
            RoundInverts (F, X);
            Lemmas.Lemma_InvRound_Prime_Eq
              (Foldl_Round (Z, Xs), Round (F, X), X);
            pragma Assert
              (Rev (Rev'First + 1 .. Rev'Last) = Reverse_Keys (Init));
            Lemma_Foldl_InvRound_Prime_Eq
              (InvRound_Prime (Foldl_Round (Z, Xs), X), F,
               Rev (Rev'First + 1 .. Rev'Last), Reverse_Keys (Init));
         end;
      end if;
   end Lemma_Foldl_Inverts;

   -------------------------
   -- CipherInverts_Prime --
   -------------------------

   procedure CipherInverts_Prime
     (K : Natural; Ws : Round_Keys; State : Block)
   is
      Mid : constant Round_Keys := Ws (1 .. Nr (K) - 1);
      F   : constant Block :=
        Foldl_Round (AddRoundKey (State, Ws (0)), Mid);
      C   : constant Block := Cipher.Cipher (K, Ws, State);
      S1  : constant Block := ShiftRows (SubBytes (F));
   begin
      pragma Assert (C = AddRoundKey (S1, Ws (Nr (K))));
      AddRoundKeyInvolution (S1, Ws (Nr (K)));
      pragma Assert (AddRoundKey (C, Ws (Nr (K))) = S1);
      ShiftRowsInverts (SubBytes (F));
      SubBytesInverts (F);
      pragma Assert
        (InvSubBytes (InvShiftRows (AddRoundKey (C, Ws (Nr (K))))) = F);
      Lemma_Foldl_Inverts (AddRoundKey (State, Ws (0)), Mid);
      Lemma_Foldl_InvRound_Prime_Eq
        (InvSubBytes (InvShiftRows (AddRoundKey (C, Ws (Nr (K))))), F,
         Reverse_Keys (Mid), Reverse_Keys (Mid));
      AddRoundKeyInvolution (State, Ws (0));
   end CipherInverts_Prime;

   -------------------
   -- CipherInverts --
   -------------------

   procedure CipherInverts (K : Natural; Ws : Round_Keys; State : Block) is
   begin
      InvCipherEquivalence (K, Ws, Cipher.Cipher (K, Ws, State));
      CipherInverts_Prime (K, Ws, State);
   end CipherInverts;

   ------------------------
   -- Lemma_InvCipher_Eq --
   ------------------------

   ----------------------------
   -- Lemma_Split_Join_Block --
   ----------------------------

   procedure Lemma_Split_Join_Block (B : Block) is
      Bs : constant Main.Block_Bits := Main.Join_Block (B);
   begin
      for I in Block_Index loop
         pragma Assert
           (for all J in 0 .. 7 =>
              Bs (Main.Bit_Index (8 * I + J)) = Main.Bit_Of (B (I), J));
         pragma Assert (Main.Byte_At (Bs, Main.Bit_Index (8 * I)) = B (I));
         pragma Loop_Invariant
           (for all L in 0 .. I =>
              Main.Byte_At (Bs, Main.Bit_Index (8 * L)) = B (L));
      end loop;
   end Lemma_Split_Join_Block;

   procedure Lemma_InvCipher_Eq (K : Natural; Ws : Round_Keys; A, B : Block)
   is
      Rev : constant Round_Keys := Reverse_Keys (Ws (1 .. Nr (K) - 1));
   begin
      Lemma_Foldl_InvRound_Eq
        (AddRoundKey (A, Ws (Nr (K))), AddRoundKey (B, Ws (Nr (K))),
         Rev, Rev);
   end Lemma_InvCipher_Eq;

   --------------------
   -- EncryptInverts --
   --------------------

   procedure EncryptInverts
     (K : Natural; Key : Main.Bits; Input : Main.Block_Bits)
   is
      W  : constant Round_Keys :=
        KeyExpansion.KeyExpansion (K, Main.Split_Key (K, Key));
      P  : constant Block := Main.Split_Block (Input);
      C  : constant Block := Cipher.Cipher (K, W, P);
   begin
      Lemma_Split_Join_Block (C);
      Lemma_InvCipher_Eq (K, W, Main.Split_Block (Main.Join_Block (C)), C);
      CipherInverts (K, W, P);
      pragma Assert (Main.Join_Block (P) = Input);
   end EncryptInverts;

end Foundation_Spark.AES.Spec.Properties;
