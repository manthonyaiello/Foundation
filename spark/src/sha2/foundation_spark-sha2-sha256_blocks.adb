package body Foundation_Spark.SHA2.SHA256_Blocks with
  SPARK_Mode
is

   use SHA256_Bytes;

   use type Interfaces.Unsigned_32;

   --------------------
   -- Lemma_Step_Ext --
   --------------------

   procedure Lemma_Step_Ext (H1, H2 : SHA256.Hash_Value; B1, B2 : SHA256.Block)
   is
   begin
      Lemma_Foldl_Step3_Ext (B1, B2, H1, H2, 64);
   end Lemma_Step_Ext;

   ---------------------
   -- Lemma_Block_Ext --
   ---------------------

   procedure Lemma_Block_Ext
     (M1 : Byte_Array; F1 : Offset; M2 : Byte_Array; F2 : Offset) is
   begin
      pragma Assert
        (for all J in 0 .. 15 =>
           M1 (F1 + 4 * Offset (J)) = M2 (F2 + 4 * Offset (J))
           and then M1 (F1 + 4 * Offset (J) + 1)
                    = M2 (F2 + 4 * Offset (J) + 1)
           and then M1 (F1 + 4 * Offset (J) + 2)
                    = M2 (F2 + 4 * Offset (J) + 2)
           and then M1 (F1 + 4 * Offset (J) + 3)
                    = M2 (F2 + 4 * Offset (J) + 3));
   end Lemma_Block_Ext;

   --------------------
   -- Lemma_Fold_Ext --
   --------------------

   procedure Lemma_Fold_Ext
     (H1, H2 : SHA256.Hash_Value;
      M1     : Byte_Array;
      F1     : Offset;
      M2     : Byte_Array;
      F2     : Offset;
      K      : Bit_Index)
   is
   begin
      if K > 0 then
         Lemma_Fold_Ext (H1, H2, M1, F1, M2, F2, K - 1);
         Lemma_Block_Ext
           (M1, F1 + 64 * Offset (K - 1), M2, F2 + 64 * Offset (K - 1));
         Lemma_Step_Ext
           (Fold_Blocks (H1, M1, F1, K - 1),
            Fold_Blocks (H2, M2, F2, K - 1),
            Block_From (M1, F1 + 64 * Offset (K - 1)),
            Block_From (M2, F2 + 64 * Offset (K - 1)));
      end if;
   end Lemma_Fold_Ext;

   ----------------------
   -- Lemma_Fold_Split --
   ----------------------

   procedure Lemma_Fold_Split
     (H : SHA256.Hash_Value;
      M : Byte_Array;
      F : Offset;
      A : Bit_Index;
      B : Bit_Index)
   is
   begin
      if B > 0 then
         Lemma_Fold_Split (H, M, F, A, B - 1);
         pragma Assert
           (F + 64 * Offset (A + B - 1)
            = (F + 64 * Offset (A)) + 64 * Offset (B - 1));
         Lemma_Step_Ext
           (Fold_Blocks (H, M, F, A + B - 1),
            Fold_Blocks
              (Fold_Blocks (H, M, F, A), M, F + 64 * Offset (A), B - 1),
            Block_From (M, F + 64 * Offset (A + B - 1)),
            Block_From
              (M, (F + 64 * Offset (A)) + 64 * Offset (B - 1)));
      end if;
   end Lemma_Fold_Split;

   -----------------------
   -- Lemma_Foldl_Parse --
   -----------------------

   procedure Lemma_Foldl_Parse
     (H : SHA256.Hash_Value; P : Byte_Array; Nb, N : Bit_Index)
   is
   begin
      if N > 0 then
         Lemma_Foldl_Parse (H, P, Nb, N - 1);
         pragma Assert
           (Parse_Bytes (P, Nb) (N - 1)
            = Block_From (P, 64 * Offset (N - 1)));
         Lemma_Step_Ext
           (SHA256.Foldl_Step (H, Parse_Bytes (P, Nb), N - 1),
            Fold_Blocks (H, P, 0, N - 1),
            Parse_Bytes (P, Nb) (N - 1),
            Block_From (P, 64 * Offset (N - 1)));
      end if;
   end Lemma_Foldl_Parse;

   -----------------------
   -- Lemma_Block_Parse --
   -----------------------

   procedure Lemma_Block_Parse (M : Byte_Array; F : Offset) is
      S : constant Byte_Array := M (F .. F + 63);
      P : constant Bits := Bits_Of (S);
   begin
      for J in 0 .. 15 loop
         for K in 0 .. 3 loop
            for T in 0 .. 7 loop
               pragma Assert
                 ((32 * Bit_Index (J) + 8 * Bit_Index (K) + Bit_Index (T)) / 8
                  = 4 * Bit_Index (J) + Bit_Index (K));
               pragma Assert
                 ((32 * Bit_Index (J) + 8 * Bit_Index (K) + Bit_Index (T))
                  mod 8 = Bit_Index (T));
               pragma Assert
                 (P (32 * Bit_Index (J) + 8 * Bit_Index (K) + Bit_Index (T))
                  = Byte_Bit (S (F + 4 * Offset (J) + Offset (K)), T));
               pragma Loop_Invariant
                 (for all T2 in 0 .. T =>
                    P (32 * Bit_Index (J) + 8 * Bit_Index (K)
                       + Bit_Index (T2))
                    = Byte_Bit (S (F + 4 * Offset (J) + Offset (K)), T2));
            end loop;
            pragma Loop_Invariant
              (for all K2 in 0 .. K =>
                 (for all T in 0 .. 7 =>
                    P (32 * Bit_Index (J) + 8 * Bit_Index (K2)
                       + Bit_Index (T))
                    = Byte_Bit (S (F + 4 * Offset (J) + Offset (K2)), T)));
         end loop;
         Lemma_Word_Of_Bytes (P, 32 * Bit_Index (J), S, F + 4 * Offset (J));
         pragma Assert
           (SHA256.Parse (P, 1) (0) (J)
            = SHA256.Word_Of (P, 32 * Bit_Index (J), 32));
         pragma Assert
           (Word_At (S, F + 4 * Offset (J))
            = Word_At (M, F + 4 * Offset (J)));
         pragma Loop_Invariant
           (for all J2 in 0 .. J =>
              Block_From (M, F) (J2) = SHA256.Parse (P, 1) (0) (J2));
      end loop;
   end Lemma_Block_Parse;

end Foundation_Spark.SHA2.SHA256_Blocks;
