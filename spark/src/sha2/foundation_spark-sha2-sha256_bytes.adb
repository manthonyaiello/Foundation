package body Foundation_Spark.SHA2.SHA256_Bytes with
  SPARK_Mode
is

   use Interfaces;

   -------------------
   -- Lemma_To_Bits --
   -------------------

   procedure Lemma_To_Bits (V : Unsigned_64; W : Natural) is
   begin
      if W > 0 then
         Lemma_To_Bits (V / 2, W - 1);
         pragma Assert (Bit_Index (V) / 2 = Bit_Index (V / 2));
         pragma Assert ((V mod 2 = 1) = ((V and 1) = 1));
         pragma Assert (Bit_Index (V) mod 2 = Bit_Index (V mod 2));
         pragma Assert (V / 2 = Shift_Right (V, 1));
         pragma Assert
           (for all I in 0 .. Bit_Index (W) - 2 =>
              Shift_Right (Shift_Right (V, 1), W - 2 - Natural (I))
              = Shift_Right (V, W - 1 - Natural (I)));
         pragma Assert
           (for all I in 0 .. Bit_Index (W) - 2 =>
              Shift_Right (V / 2, W - 2 - Natural (I))
              = Shift_Right (V, W - 1 - Natural (I)));
      end if;
   end Lemma_To_Bits;

   ---------------
   -- Lemma_Pad --
   ---------------

   procedure Lemma_Pad (M : Bits) is
   begin
      Lemma_To_Bits (Unsigned_64 (M'Length), 64);
   end Lemma_Pad;

   ---------------------
   -- Lemma_Pad_Bytes --
   ---------------------

   procedure Lemma_Pad_Bytes_Bits (M : Byte_Array) is
      N_Bytes : constant Bit_Index := M'Length;
      Q       : constant Bit_Index := (N_Bytes + 72) / 64;
   begin
      pragma Assert
        (64 * Q <= N_Bytes + 72 and then N_Bytes + 72 < 64 * Q + 64);
      pragma Assert
        (512 * Q <= 8 * N_Bytes + 576
         and then 8 * N_Bytes + 576 < 512 * Q + 512);
      pragma Assert (SHA256.N (8 * N_Bytes) = Q);
      Lemma_Pad (Bits_Of (M));
      Lemma_Length_Bits (8 * Unsigned_64 (N_Bytes));
      pragma Assert
        (Unsigned_64 (Bits_Of (M)'Length) = 8 * Unsigned_64 (N_Bytes));

      --  The message's bytes.
      pragma Assert
        (for all B in 0 .. Byte_Index (N_Bytes) - 1 =>
           (for all T in 0 .. 7 =>
              SHA256.Pad (Bits_Of (M)) (8 * Bit_Index (B) + Bit_Index (T))
              = Byte_Bit (Pad_Bytes (M) (B), T)));

      --  The byte 0x80.
      pragma Assert (Byte_Bit (16#80#, 0));
      pragma Assert (for all T in 1 .. 7 => not Byte_Bit (16#80#, T));
      pragma Assert (SHA256.Pad (Bits_Of (M)) (8 * N_Bytes));
      pragma Assert
        (for all T in 1 .. 7 =>
           not SHA256.Pad (Bits_Of (M)) (8 * N_Bytes + Bit_Index (T)));
      pragma Assert (Pad_Bytes (M) (Byte_Index (N_Bytes)) = 16#80#);
      pragma Assert
        (for all T in 0 .. 7 =>
           SHA256.Pad (Bits_Of (M)) (8 * N_Bytes + Bit_Index (T))
           = Byte_Bit (Pad_Bytes (M) (Byte_Index (N_Bytes)), T));

      --  The zero bytes.
      pragma Assert
        (for all B in Byte_Index (N_Bytes) + 1 .. Byte_Index (64 * Q - 9) =>
           (for all T in 0 .. 7 =>
              SHA256.Pad (Bits_Of (M)) (8 * Bit_Index (B) + Bit_Index (T))
              = Byte_Bit (Pad_Bytes (M) (B), T)));

      --  The length.
      pragma Assert
        (for all B in Byte_Index (64 * Q - 8) .. Byte_Index (64 * Q - 1) =>
           Pad_Bytes (M) (B)
           = Length_Byte
               (8 * Unsigned_64 (N_Bytes),
                Natural (B - Byte_Index (64 * Q - 8))));
      pragma Assert
        (for all B in Byte_Index (64 * Q - 8) .. Byte_Index (64 * Q - 1) =>
           (for all T in 0 .. 7 =>
              SHA256.Pad (Bits_Of (M)) (8 * Bit_Index (B) + Bit_Index (T))
              = Byte_Bit (Pad_Bytes (M) (B), T)));
   end Lemma_Pad_Bytes_Bits;

   -----------------------
   -- Lemma_Length_Bits --
   -----------------------

   procedure Lemma_Length_Bits (L : Unsigned_64) is null;

   ---------------------
   -- Lemma_Pad_Bytes --
   ---------------------

   procedure Lemma_Pad_Bytes (M : Byte_Array) is
   begin
      Lemma_Pad_Bytes_Bits (M);
      pragma Assert
        (for all I in 0 .. 8 * Bit_Index (Pad_Bytes (M)'Length) - 1 =>
           Bits_Of (Pad_Bytes (M)) (I)
           = Byte_Bit (Pad_Bytes (M) (Byte_Index (I / 8)), Natural (I mod 8)));
      pragma Assert
        (for all I in 0 .. 8 * Bit_Index (Pad_Bytes (M)'Length) - 1 =>
           SHA256.Pad (Bits_Of (M)) (I)
           = SHA256.Pad (Bits_Of (M))
               (8 * Bit_Index (Byte_Index (I / 8))
                + Bit_Index (Natural (I mod 8))));
      pragma Assert
        (for all I in SHA256.Pad (Bits_Of (M))'Range =>
           Bits_Of (Pad_Bytes (M)) (I) = SHA256.Pad (Bits_Of (M)) (I));
   end Lemma_Pad_Bytes;

   ------------------------
   -- Lemma_Word_Of_Byte --
   ------------------------

   procedure Lemma_Word_Of_Byte
     (P : Bits; S : Bit_Index; A : Natural; X : Byte)
   is
      function B (T : Natural) return Unsigned_32 is
        (if Byte_Bit (X, T) then 1 else 0)
      with Pre => T < 8;
   begin
      pragma Assert (Unsigned_32 (X)
                     = 128 * B (0) + 64 * B (1) + 32 * B (2) + 16 * B (3)
                       + 8 * B (4) + 4 * B (5) + 2 * B (6) + B (7));
      pragma Assert
        (for all T in 0 .. 7 =>
           SHA256.Word_Of (P, S, A + T + 1)
           = 2 * SHA256.Word_Of (P, S, A + T) + B (T));
   end Lemma_Word_Of_Byte;

   -------------------------
   -- Lemma_Word_Of_Bytes --
   -------------------------

   procedure Lemma_Word_Of_Bytes
     (P : Bits; S : Bit_Index; Q : Byte_Array; F : Byte_Index) is
   begin
      Lemma_Word_Of_Byte (P, S, 0, Q (F));
      Lemma_Word_Of_Byte (P, S, 8, Q (F + 1));
      Lemma_Word_Of_Byte (P, S, 16, Q (F + 2));
      Lemma_Word_Of_Byte (P, S, 24, Q (F + 3));
   end Lemma_Word_Of_Bytes;

   -----------------------
   -- Lemma_Parse_Bytes --
   -----------------------

   procedure Lemma_Parse_Bytes (M : Byte_Array) is
      Nb : constant Bit_Index := Blocks (M'Length);
   begin
      Lemma_Pad_Bytes_Bits (M);
      for I in 0 .. Nb - 1 loop
         for J in 0 .. 15 loop
            Lemma_Word_Of_Bytes
              (SHA256.Pad (Bits_Of (M)),
               (16 * I + Bit_Index (J)) * 32,
               Pad_Bytes (M),
               Byte_Index (64 * I) + 4 * Byte_Index (J));
            pragma Assert
              (Parse_Bytes (Pad_Bytes (M), Nb) (I) (J)
               = Word_At
                   (Pad_Bytes (M), Byte_Index (64 * I) + 4 * Byte_Index (J)));
            pragma Assert
              (SHA256.Parse (SHA256.Pad (Bits_Of (M)), Nb) (I) (J)
               = SHA256.Word_Of
                   (SHA256.Pad (Bits_Of (M)),
                    (16 * I + Bit_Index (J)) * 32,
                    32));
            pragma Loop_Invariant
              (for all J2 in 0 .. J =>
                 Parse_Bytes (Pad_Bytes (M), Nb) (I) (J2)
                 = SHA256.Parse (SHA256.Pad (Bits_Of (M)), Nb) (I) (J2));
         end loop;
         pragma Loop_Invariant
           (for all I2 in 0 .. I =>
              (for all J in 0 .. 15 =>
                 Parse_Bytes (Pad_Bytes (M), Nb) (I2) (J)
                 = SHA256.Parse (SHA256.Pad (Bits_Of (M)), Nb) (I2) (J)));
      end loop;
   end Lemma_Parse_Bytes;

   ------------------------
   -- Lemma_Digest_Bytes --
   ------------------------

   procedure Lemma_Word_Bits (X : Unsigned_32) is null;

   procedure Lemma_Digest_Bytes (H : SHA256.Hash_Value) is
   begin
      for K in H'Range loop
         Lemma_Word_Bits (H (K));
         pragma Loop_Invariant
           (for all K2 in 0 .. K =>
              (for all J in 0 .. 31 =>
                 SHA256.Bit (H (K2), J)
                 = Byte_Bit (Word_Byte (H (K2), J / 8), J mod 8)));
      end loop;
      pragma Assert
        (for all I in Bit_Index range 0 .. 255 =>
           Bits_Of (Digest_Bytes (H)) (I)
           = Byte_Bit
               (Word_Byte (H (Natural (I / 32)), Natural (I mod 32) / 8),
                Natural (I mod 32) mod 8));
      pragma Assert
        (for all I in Bit_Index range 0 .. 255 =>
           Bits_Of (Digest_Bytes (H)) (I) = SHA256.Join (H) (I));
   end Lemma_Digest_Bytes;

   -----------------
   -- Lemma_W_Ext --
   -----------------

   procedure Lemma_W_Ext (M1, M2 : SHA256.Block) is
   begin
      for T in 0 .. 63 loop
         pragma Loop_Invariant
           (for all T2 in 0 .. T => SHA256.W (M1, T2) = SHA256.W (M2, T2));
      end loop;
   end Lemma_W_Ext;

   ---------------------------
   -- Lemma_Foldl_Step3_Ext --
   ---------------------------

   procedure Lemma_Foldl_Step3_Ext
     (M1, M2 : SHA256.Block; H1, H2 : SHA256.Hash_Value; N : Natural) is
   begin
      if N > 0 then
         Lemma_Foldl_Step3_Ext (M1, M2, H1, H2, N - 1);
         Lemma_W_Ext (M1, M2);
      end if;
   end Lemma_Foldl_Step3_Ext;

   --------------------------
   -- Lemma_Foldl_Step_Ext --
   --------------------------

   procedure Lemma_Foldl_Step_Ext
     (H : SHA256.Hash_Value; Ms1, Ms2 : SHA256.Block_Vector; N : Bit_Index)
   is
   begin
      if N > 0 then
         Lemma_Foldl_Step_Ext (H, Ms1, Ms2, N - 1);
         Lemma_Foldl_Step3_Ext
           (Ms1 (N - 1), Ms2 (N - 1),
            SHA256.Foldl_Step (H, Ms1, N - 1),
            SHA256.Foldl_Step (H, Ms2, N - 1),
            64);
      end if;
   end Lemma_Foldl_Step_Ext;

   ----------------------
   -- Lemma_Hash_Bytes --
   ----------------------

   procedure Lemma_Hash_Bytes (M : Byte_Array) is
      Nb    : constant Bit_Index := Blocks (M'Length);
      Bytes : constant SHA256.Block_Vector :=
        Parse_Bytes (Pad_Bytes (M), Nb);
      Spec  : constant SHA256.Block_Vector :=
        SHA256.Parse (SHA256.Pad (Bits_Of (M)), Nb);
      H1    : constant SHA256.Hash_Value :=
        SHA256.Foldl_Step (Preprocessing.H0_256, Bytes, Nb);
      H2    : constant SHA256.Hash_Value :=
        SHA256.Foldl_Step (Preprocessing.H0_256, Spec, Nb);
   begin
      Lemma_Parse_Bytes (M);
      pragma Assert (for all I in 0 .. Nb - 1 => Bytes (I) = Spec (I));
      Lemma_Foldl_Step_Ext (Preprocessing.H0_256, Bytes, Spec, Nb);
      pragma Assert (H1 = H2);
      pragma Assert
        (SHA256.Hash (Bits_Of (M)) = SHA256.Join (H2) (0 .. 255));
      pragma Assert
        (for all I in Bit_Index range 0 .. 255 =>
           SHA256.Join (H1) (I) = SHA256.Join (H2) (I));
      Lemma_Digest_Bytes (H1);
      pragma Assert (Hash_Bytes (M) = Digest_Bytes (H1));
   end Lemma_Hash_Bytes;

end Foundation_Spark.SHA2.SHA256_Bytes;
