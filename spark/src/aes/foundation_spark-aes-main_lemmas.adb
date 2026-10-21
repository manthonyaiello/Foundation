with Foundation_Spark.AES.Lemmas;
with Foundation_Spark.AES.Spec.Properties;

package body Foundation_Spark.AES.Main_Lemmas with
  SPARK_Mode
is

   use Spec.KeyExpansion;
   use Spec.Dispatch;

   --------------------------
   -- Lemma_Split_Join_Key --
   --------------------------

   procedure Lemma_Split_Join_Key (K : Key_Size; Key : Impl.Main.Key_Bytes)
   is
      Bs : constant Spec.Main.Bits := Impl.Main.Join_Key (Key);
   begin
      pragma Assert (8 * (K / 8) = K);
      pragma Assert (Spec.Main.Is_Key_Bits (K, Bs));
      for J in 0 .. Nk (K) - 1 loop
         for I in AESWord_Index loop
            pragma Assert
              (for all T in 0 .. 7 =>
                 Bs (Spec.Main.Bit_Index (32 * J + 8 * I + T))
                 = Spec.Main.Bit_Of (Key (4 * J + I), T));
            pragma Assert
              (Spec.Main.Byte_At (Bs, Spec.Main.Bit_Index (32 * J + 8 * I))
               = Key (4 * J + I));
            pragma Loop_Invariant
              (for all I2 in 0 .. I =>
                 Spec.Dispatch.Split_Key (K, Bs) (J) (I2) = Key (4 * J + I2));
         end loop;
         pragma Loop_Invariant
           (for all J2 in 0 .. J =>
              (for all I in AESWord_Index =>
                 Spec.Dispatch.Split_Key (K, Bs) (J2) (I) = Key (4 * J2 + I)));
      end loop;
   end Lemma_Split_Join_Key;

   ----------------
   -- Lemma_W_Eq --
   ----------------

   procedure Lemma_W_Eq (K : Key_Size; A, B : Key_Words; I : Natural) is
   begin
      if I > 0 then
         Lemma_W_Eq (K, A, B, I - 1);
      end if;
      Lemma_W (K, A, I);
      Lemma_W (K, B, I);
      if I < Nk (K) then
         pragma Assert (A (I) = B (I));
      else
         pragma Assert (W (K, A, I - Nk (K)) = W (K, B, I - Nk (K)));
         pragma Assert (W (K, A, I - 1) = W (K, B, I - 1));
      end if;
      pragma Assert (W (K, A, I) = W (K, B, I));
   end Lemma_W_Eq;

   ---------------------------
   -- Lemma_KeyExpansion_Eq --
   ---------------------------

   procedure Lemma_KeyExpansion_Eq (K : Key_Size; A, B : Key_Words) is
   begin
      Lemma_W_Eq (K, A, B, Words (K) - 1);
      for R in 0 .. Nr (K) loop
         pragma Assert
           (for all J in AESWord_Index =>
              W (K, A, 4 * R + J) = W (K, B, 4 * R + J));
         pragma Assert
           (KeyExpansion (K, A) (R) = KeyExpansion (K, B) (R));
         pragma Loop_Invariant
           (for all R2 in 0 .. R =>
              KeyExpansion (K, A) (R2) = KeyExpansion (K, B) (R2));
      end loop;
   end Lemma_KeyExpansion_Eq;

   ------------------------
   -- Lemma_Round_Key_Eq --
   ------------------------

   procedure Lemma_Round_Key_Eq (A : Block; K1, K2 : Block) is
      S : constant Block := MixColumns (ShiftRows (SubBytes (A)));
   begin
      pragma Assert (AddRoundKey (S, K1) = AddRoundKey (S, K2));
   end Lemma_Round_Key_Eq;

   --------------------------
   -- Lemma_Foldl_Round_Eq --
   --------------------------

   procedure Lemma_Foldl_Round_Eq (A, B : Block; Xs, Ys : Round_Keys) is
   begin
      Lemmas.Lemma_Foldl_Round_Take_Eq (A, B, Xs, Ys, Xs'Length);
   end Lemma_Foldl_Round_Eq;

   ---------------------
   -- Lemma_Cipher_Eq --
   ---------------------

   procedure Lemma_Cipher_Eq (K : Key_Size; V, W : Round_Keys; A, B : Block)
   is
      S1 : constant Block := AddRoundKey (A, V (0));
      S2 : constant Block := AddRoundKey (B, W (0));
   begin
      pragma Assert (V (0) = W (0));
      pragma Assert (S1 = S2);
      pragma Assert (V (1 .. Nr (K) - 1) = W (1 .. Nr (K) - 1));
      Lemma_Foldl_Round_Eq (S1, S2, V (1 .. Nr (K) - 1), W (1 .. Nr (K) - 1));
      pragma Assert (V (Nr (K)) = W (Nr (K)));
      pragma Assert
        (ShiftRows (SubBytes (Foldl_Round (S1, V (1 .. Nr (K) - 1))))
         = ShiftRows (SubBytes (Foldl_Round (S2, W (1 .. Nr (K) - 1)))));
   end Lemma_Cipher_Eq;

   ------------------------
   -- Lemma_InvCipher_Eq --
   ------------------------

   procedure Lemma_InvCipher_Eq (K : Key_Size; V, W : Round_Keys; A, B : Block)
   is
      S1 : constant Block := AddRoundKey (A, V (Nr (K)));
      S2 : constant Block := AddRoundKey (B, W (Nr (K)));
      R1 : constant Round_Keys := Reverse_Keys (V (1 .. Nr (K) - 1));
      R2 : constant Round_Keys := Reverse_Keys (W (1 .. Nr (K) - 1));
   begin
      pragma Assert (V (Nr (K)) = W (Nr (K)));
      pragma Assert (S1 = S2);
      pragma Assert (R1 = R2);
      Spec.Properties.Lemma_Foldl_InvRound_Eq (S1, S2, R1, R2);
      pragma Assert (V (0) = W (0));
      pragma Assert
        (InvSubBytes (InvShiftRows (Foldl_InvRound (S1, R1)))
         = InvSubBytes (InvShiftRows (Foldl_InvRound (S2, R2))));
   end Lemma_InvCipher_Eq;

end Foundation_Spark.AES.Main_Lemmas;
