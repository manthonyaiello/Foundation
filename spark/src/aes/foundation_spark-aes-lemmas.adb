package body Foundation_Spark.AES.Lemmas with
  SPARK_Mode
is

   procedure Lemma_Pmult_Fold (B, C : Byte; N : Natural) is
   begin
      if N > 0 then
         Lemma_Pmult_Fold (B, C, N - 1);
      end if;
   end Lemma_Pmult_Fold;

   procedure Lemma_Pmod_Small (X, Y : Poly; N : Natural) is
   begin
      if N > 0 then
         Lemma_Pmod_Small (X, Y, N - 1);
      end if;
   end Lemma_Pmod_Small;

   procedure Lemma_Dot (B, C : Byte) is
      X : constant Poly := Spec.GF28.Pmult (B, C);
   begin
      Lemma_Pmult_Fold (B, C, 8);
      pragma Assert (X = Pm (B, C));
      pragma Assert (X < 2 ** 11);
      Lemma_Pmod_Small (X, Spec.GF28.M, 12);
   end Lemma_Dot;

   procedure Lemma_MixColumns_Eq (A, B : Block) is
   begin
      pragma Assert (Split (A) = Split (B));
   end Lemma_MixColumns_Eq;

   procedure Lemma_InvMixColumns_Eq (A, B : Block) is
   begin
      pragma Assert (Split (A) = Split (B));
   end Lemma_InvMixColumns_Eq;

   procedure Lemma_Round_Eq (A, B : Block; Ki : Block) is
   begin
      pragma Assert (ShiftRows (SubBytes (A)) = ShiftRows (SubBytes (B)));
      Lemma_MixColumns_Eq (ShiftRows (SubBytes (A)), ShiftRows (SubBytes (B)));
      pragma Assert (Round (A, Ki) = Round (B, Ki));
   end Lemma_Round_Eq;

   procedure Lemma_InvRound_Eq (A, B : Block; Ki : Block) is
   begin
      pragma Assert
        (AddRoundKey (InvSubBytes (InvShiftRows (A)), Ki)
         = AddRoundKey (InvSubBytes (InvShiftRows (B)), Ki));
      Lemma_InvMixColumns_Eq
        (AddRoundKey (InvSubBytes (InvShiftRows (A)), Ki),
         AddRoundKey (InvSubBytes (InvShiftRows (B)), Ki));
   end Lemma_InvRound_Eq;

   procedure Lemma_InvRound_Prime_Eq (A, B : Block; Ki : Block) is
   begin
      pragma Assert (AddRoundKey (A, Ki) = AddRoundKey (B, Ki));
      Lemma_InvMixColumns_Eq (AddRoundKey (A, Ki), AddRoundKey (B, Ki));
   end Lemma_InvRound_Prime_Eq;

   procedure Lemma_Foldl_Round_Take_Eq
     (A, B : Block; Xs, Ys : Round_Keys; N : Natural) is
   begin
      if N > 0 then
         Lemma_Foldl_Round_Take_Eq (A, B, Xs, Ys, N - 1);
         declare
            S : constant Block := Round_Folds.Foldl_Take (B, Ys, N - 1);
            T : constant Block := MixColumns (ShiftRows (SubBytes (S)));
         begin
            Lemma_Round_Eq
              (Round_Folds.Foldl_Take (A, Xs, N - 1), S,
               Xs (Xs'First + (N - 1)));
            pragma Assert
              (AddRoundKey (T, Xs (Xs'First + (N - 1)))
               = AddRoundKey (T, Ys (Ys'First + (N - 1))));
         end;
      end if;
   end Lemma_Foldl_Round_Take_Eq;

   procedure Lemma_Foldl_InvRound_Take_Eq
     (A, B : Block; Xs, Ys : Round_Keys; N : Natural) is
   begin
      if N > 0 then
         Lemma_Foldl_InvRound_Take_Eq (A, B, Xs, Ys, N - 1);
         declare
            S : constant Block := InvRound_Folds.Foldl_Take (B, Ys, N - 1);
            T : constant Block := InvSubBytes (InvShiftRows (S));
         begin
            Lemma_InvRound_Eq
              (InvRound_Folds.Foldl_Take (A, Xs, N - 1), S,
               Xs (Xs'First + (N - 1)));
            pragma Assert
              (AddRoundKey (T, Xs (Xs'First + (N - 1)))
               = AddRoundKey (T, Ys (Ys'First + (N - 1))));
            Lemma_InvMixColumns_Eq
              (AddRoundKey (T, Xs (Xs'First + (N - 1))),
               AddRoundKey (T, Ys (Ys'First + (N - 1))));
         end;
      end if;
   end Lemma_Foldl_InvRound_Take_Eq;

   procedure Lemma_Foldl_InvRound_Prime_Take_Eq
     (A, B : Block; Xs, Ys : Round_Keys; N : Natural) is
   begin
      if N > 0 then
         Lemma_Foldl_InvRound_Prime_Take_Eq (A, B, Xs, Ys, N - 1);
         declare
            S : constant Block :=
              InvRound_Prime_Folds.Foldl_Take (B, Ys, N - 1);
         begin
            Lemma_InvRound_Prime_Eq
              (InvRound_Prime_Folds.Foldl_Take (A, Xs, N - 1), S,
               Xs (Xs'First + (N - 1)));
            pragma Assert
              (AddRoundKey (S, Xs (Xs'First + (N - 1)))
               = AddRoundKey (S, Ys (Ys'First + (N - 1))));
            Lemma_InvMixColumns_Eq
              (AddRoundKey (S, Xs (Xs'First + (N - 1))),
               AddRoundKey (S, Ys (Ys'First + (N - 1))));
         end;
      end if;
   end Lemma_Foldl_InvRound_Prime_Take_Eq;

   procedure Lemma_Foldl_Round_Snoc (Z : Block; Xs : Round_Keys) is
      Init : constant Round_Keys := Xs (Xs'First .. Xs'Last - 1);
   begin
      Lemma_Foldl_Round_Take_Eq (Z, Z, Xs, Init, Init'Length);
      Lemma_Round_Eq
        (Round_Folds.Foldl_Take (Z, Xs, Init'Length), Foldl_Round (Z, Init),
         Xs (Xs'Last));
   end Lemma_Foldl_Round_Snoc;

   procedure Lemma_Foldl_InvRound_Snoc (Z : Block; Xs : Round_Keys) is
      Init : constant Round_Keys := Xs (Xs'First .. Xs'Last - 1);
   begin
      Lemma_Foldl_InvRound_Take_Eq (Z, Z, Xs, Init, Init'Length);
      Lemma_InvRound_Eq
        (InvRound_Folds.Foldl_Take (Z, Xs, Init'Length),
         Foldl_InvRound (Z, Init), Xs (Xs'Last));
   end Lemma_Foldl_InvRound_Snoc;

   procedure Lemma_Foldl_InvRound_Prime_Snoc (Z : Block; Xs : Round_Keys) is
      Init : constant Round_Keys := Xs (Xs'First .. Xs'Last - 1);
   begin
      Lemma_Foldl_InvRound_Prime_Take_Eq (Z, Z, Xs, Init, Init'Length);
      Lemma_InvRound_Prime_Eq
        (InvRound_Prime_Folds.Foldl_Take (Z, Xs, Init'Length),
         Foldl_InvRound_Prime (Z, Init), Xs (Xs'Last));
   end Lemma_Foldl_InvRound_Prime_Snoc;

end Foundation_Spark.AES.Lemmas;
