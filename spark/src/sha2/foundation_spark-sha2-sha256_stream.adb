with Foundation_Spark.SHA2.Functions;
with Foundation_Spark.SHA2.Preprocessing;

package body Foundation_Spark.SHA2.SHA256_Stream with
  SPARK_Mode
is

   use Interfaces;
   use SHA256_Bytes;
   use SHA256_Blocks;

   function Joined (C0 : Context; Data : Byte_Array) return Byte_Array is
     ([for I in 0 .. C0.Count mod 64 + SHA256_Bytes.Byte_Index (Data'Length)
                    - 1 =>
         (if I < C0.Count mod 64 then C0.Buf (I)
          else Data (Data'First + (I - C0.Count mod 64)))])
   with
     Ghost,
     Pre => Data'Length < SHA256_Bytes.Max_Bytes;
   --  The bytes C0 has buffered followed by Data, indexed from 0: what
   --  Update folds into C0's hash value.
   --  @param C0 The context before Update.
   --  @param Data The bytes Update consumes.
   --  @return C0's buffered bytes and then Data.

   function Models (C : Context; M : Byte_Array) return Boolean is
     (M'Length < SHA256_Bytes.Max_Bytes
      and then C.Count = SHA256_Bytes.Byte_Index (M'Length)
      and then
        C.H
        = SHA256_Blocks.Fold_Blocks
            (Preprocessing.H0_256, M, M'First, Bit_Index (M'Length / 64))
      and then
        (for all I in 0 .. SHA256_Bytes.Byte_Index (M'Length mod 64) - 1 =>
           C.Buf (I)
           = M (M'First
                + 64 * SHA256_Bytes.Byte_Index (M'Length / 64)
                + I)));
   --  The meaning of a context, on its fields.
   --  @param C The context.
   --  @param M The bytes consumed.
   --  @return Whether C is the context after M.

   function Absorbed
     (C0 : Context; Data : Byte_Array; C1 : Context) return Boolean
   is
     (C1.Count = C0.Count + SHA256_Bytes.Byte_Index (Data'Length)
      and then
        C1.H
        = SHA256_Blocks.Fold_Blocks
            (C0.H,
             Joined (C0, Data),
             0,
             Bit_Index (Joined (C0, Data)'Length / 64))
      and then
        (for all I in 0 .. SHA256_Bytes.Byte_Index
                              (Joined (C0, Data)'Length mod 64) - 1 =>
           C1.Buf (I)
           = Joined (C0, Data)
               (64 * SHA256_Bytes.Byte_Index (Joined (C0, Data)'Length / 64)
                + I)));
   --  Update's postcondition, on the fields: the bytes Update folds are
   --  Joined (C0, Data).
   --  @param C0 The context before.
   --  @param Data The bytes consumed.
   --  @param C1 The context after.
   --  @return Whether C1 is C0 after Data.

   --------------
   -- Compress --
   --------------

   procedure Compress (H : in out SHA256.Hash_Value; M : SHA256.Block) is
      Sched  : Words_32 (0 .. 63) := [others => 0];
      V      : SHA256.Hash_Value := H;
      T1, T2 : Unsigned_32;
      V_Old  : SHA256.Hash_Value := H with Ghost;
   begin
      --  The message schedule [FIPS-PUB-180-4 Section 6.2.2, Step 1], all
      --  64 words: a whole array keeps the invariant Sched (T) = W (M, T)
      --  as plain as the spec's W, where a rolling 16-word window would
      --  need the index arithmetic of its wrap-around in every round.
      Sched (0 .. 15) := M;
      for T in 16 .. 63 loop
         Sched (T) :=
           Functions.Small_Sigma_256_1 (Sched (T - 2)) + Sched (T - 7)
           + Functions.Small_Sigma_256_0 (Sched (T - 15)) + Sched (T - 16);
         pragma Assert
           (SHA256.W (M, T)
            = Functions.Small_Sigma_256_1 (SHA256.W (M, T - 2))
              + SHA256.W (M, T - 7)
              + Functions.Small_Sigma_256_0 (SHA256.W (M, T - 15))
              + SHA256.W (M, T - 16));
         pragma Loop_Invariant
           (for all S in 0 .. T => Sched (S) = SHA256.W (M, S));
      end loop;
      pragma Assert (for all S in 0 .. 63 => Sched (S) = SHA256.W (M, S));

      --  The 64 rounds [Steps 2 and 3], on the working variables V =
      --  [a, b, c, d, e, f, g, h].
      for T in 0 .. 63 loop
         V_Old := V;
         T1 :=
           V (7) + Functions.SIGMA_256_1 (V (4))
           + SHA256.Ch (V (4), V (5), V (6)) + Functions.K_256 (T)
           + Sched (T);
         T2 :=
           Functions.SIGMA_256_0 (V (0)) + SHA256.Maj (V (0), V (1), V (2));
         pragma Assert (T1 = SHA256.T1 (M, V_Old, T));
         pragma Assert (T2 = SHA256.T2 (V_Old));
         V := [T1 + T2, V (0), V (1), V (2), V (3) + T1, V (4), V (5), V (6)];
         pragma Assert
           (SHA256.Step3 (M, V_Old, T) (0)
            = SHA256.T1 (M, V_Old, T) + SHA256.T2 (V_Old)
            and then SHA256.Step3 (M, V_Old, T) (4)
                     = V_Old (3) + SHA256.T1 (M, V_Old, T));
         pragma Assert (V (0) = SHA256.Step3 (M, V_Old, T) (0));
         pragma Assert (V (1) = SHA256.Step3 (M, V_Old, T) (1));
         pragma Assert (V (2) = SHA256.Step3 (M, V_Old, T) (2));
         pragma Assert (V (3) = SHA256.Step3 (M, V_Old, T) (3));
         pragma Assert (V (4) = SHA256.Step3 (M, V_Old, T) (4));
         pragma Assert (V (5) = SHA256.Step3 (M, V_Old, T) (5));
         pragma Assert (V (6) = SHA256.Step3 (M, V_Old, T) (6));
         pragma Assert (V (7) = SHA256.Step3 (M, V_Old, T) (7));
         pragma Assert (V = SHA256.Step3 (M, V_Old, T));
         pragma Assert
           (SHA256.Step3 (M, V_Old, T)
            = SHA256.Step3 (M, SHA256.Foldl_Step3 (M, H, T), T));
         pragma Loop_Invariant (V = SHA256.Foldl_Step3 (M, H, T + 1));
      end loop;

      --  The intermediate hash value [Step 4].
      H := SHA256."+" (H, V);
   end Compress;

   ----------------
   -- Load_Block --
   ----------------

   function Load_Block (B : Byte_Array; F : Byte_Index) return SHA256.Block
   is
      R : SHA256.Block := [others => 0];
   begin
      for J in 0 .. 15 loop
         R (J) :=
           2 ** 24 * Unsigned_32 (B (F + 4 * Byte_Index (J)))
           + 2 ** 16 * Unsigned_32 (B (F + 4 * Byte_Index (J) + 1))
           + 2 ** 8 * Unsigned_32 (B (F + 4 * Byte_Index (J) + 2))
           + Unsigned_32 (B (F + 4 * Byte_Index (J) + 3));
         pragma Loop_Invariant
           (for all K in 0 .. J =>
              R (K) = Word_At (B, F + 4 * Byte_Index (K)));
      end loop;
      return R;
   end Load_Block;

   ---------------
   -- To_Digest --
   ---------------

   function To_Digest (H : SHA256.Hash_Value) return Digest is
      D : Digest := [others => 0];
   begin
      for I in Digest'Range loop
         D (I) :=
           Byte
             (Shift_Right (H (Natural (I / 4)), 24 - 8 * Natural (I mod 4))
              and 16#FF#);
         pragma Loop_Invariant
           (for all K in 0 .. I =>
              D (K) = Word_Byte (H (Natural (K / 4)), Natural (K mod 4)));
      end loop;
      return D;
   end To_Digest;

   ----------
   -- Init --
   ----------

   procedure Init (C : out Context) is
   begin
      C := (H => Preprocessing.H0_256, Buf => [others => 0], Count => 0);
   end Init;

   ------------
   -- Update --
   ------------

   procedure Update (C : in out Context; Data : Byte_Array) is
      C0   : constant Context := C with Ghost;
      Len  : constant Byte_Index := Data'Length;
      R    : constant Byte_Index := C.Count mod 64;
      H    : SHA256.Hash_Value := C.H;
      Buf  : Byte_Array (0 .. 63) := C.Buf;
      Done : Byte_Index := 0;
   begin
      --  Fill the buffer, and compress it if it is full.
      if R > 0 then
         Done := Byte_Index'Min (64 - R, Len);
         Buf (R .. R + Done - 1) := Data (Data'First .. Data'First + Done - 1);
         pragma Assert
           (for all I in 0 .. R + Done - 1 =>
              Buf (I) = Joined (C0, Data) (I));
         if R + Done = 64 then
            declare
               Blk : constant SHA256.Block := Load_Block (Buf, 0);
            begin
               Lemma_Block_Ext (Buf, 0, Joined (C0, Data), 0);
               Lemma_Step_Ext
                 (H, C0.H, Blk, Block_From (Joined (C0, Data), 0));
               Compress (H, Blk);
            end;
         end if;
      end if;

      pragma Assert (Done = Len or else (R + Done) mod 64 = 0);
      pragma Assert
        (H = Fold_Blocks
               (C0.H, Joined (C0, Data), 0, Bit_Index ((R + Done) / 64)));

      --  Compress the whole blocks of Data in place.
      while Len - Done >= 64 loop
         pragma Loop_Invariant (Done <= Len);
         pragma Loop_Invariant (Done = Len or else (R + Done) mod 64 = 0);
         pragma Loop_Invariant
           (H = Fold_Blocks
                  (C0.H, Joined (C0, Data), 0, Bit_Index ((R + Done) / 64)));
         pragma Loop_Variant (Increases => Done);
         declare
            Blk : constant SHA256.Block :=
              Load_Block (Data, Data'First + Done);
         begin
            Lemma_Block_Ext
              (Data, Data'First + Done, Joined (C0, Data), R + Done);
            Lemma_Step_Ext
              (H,
               Fold_Blocks
                 (C0.H, Joined (C0, Data), 0, Bit_Index ((R + Done) / 64)),
               Blk,
               Block_From (Joined (C0, Data), R + Done));
            Compress (H, Blk);
         end;
         Done := Done + 64;
      end loop;

      --  Buffer the rest.
      if Done < Len then
         Buf (0 .. Len - Done - 1) := Data (Data'First + Done .. Data'Last);
      end if;

      C := (H => H, Buf => Buf, Count => C.Count + Len);
   end Update;

   -----------
   -- Final --
   -----------

   function Final (C : Context) return Digest is
      R    : constant Byte_Index := C.Count mod 64;
      TB   : constant Byte_Index := (if R < 56 then 1 else 2);
      L    : constant Unsigned_64 := 8 * Unsigned_64 (C.Count);
      Last : Byte_Array (0 .. 127) := [others => 0];
      H    : SHA256.Hash_Value := C.H;
   begin
      --  Pad [FIPS-PUB-180-4 Section 5.1.1]: the buffered bytes, 0x80,
      --  zeros, and the bit length as 8 big-endian bytes.
      Last (0 .. R - 1) := C.Buf (0 .. R - 1);
      Last (R) := 16#80#;
      Last (64 * TB - 8) := Byte (Shift_Right (L, 56) and 16#FF#);
      Last (64 * TB - 7) := Byte (Shift_Right (L, 48) and 16#FF#);
      Last (64 * TB - 6) := Byte (Shift_Right (L, 40) and 16#FF#);
      Last (64 * TB - 5) := Byte (Shift_Right (L, 32) and 16#FF#);
      Last (64 * TB - 4) := Byte (Shift_Right (L, 24) and 16#FF#);
      Last (64 * TB - 3) := Byte (Shift_Right (L, 16) and 16#FF#);
      Last (64 * TB - 2) := Byte (Shift_Right (L, 8) and 16#FF#);
      Last (64 * TB - 1) := Byte (Shift_Right (L, 0) and 16#FF#);
      pragma Assert (TB = Byte_Index (Tail_Blocks (C)));
      pragma Assert (for all I in 0 .. R - 1 => Last (I) = C.Buf (I));
      pragma Assert (Last (R) = 16#80#);
      pragma Assert (for all I in R + 1 .. 64 * TB - 9 => Last (I) = 0);
      pragma Assert
        (Last (64 * TB - 8) = Length_Byte (L, 0)
         and then Last (64 * TB - 7) = Length_Byte (L, 1)
         and then Last (64 * TB - 6) = Length_Byte (L, 2)
         and then Last (64 * TB - 5) = Length_Byte (L, 3)
         and then Last (64 * TB - 4) = Length_Byte (L, 4)
         and then Last (64 * TB - 3) = Length_Byte (L, 5)
         and then Last (64 * TB - 2) = Length_Byte (L, 6)
         and then Last (64 * TB - 1) = Length_Byte (L, 7));
      pragma Assert
        (for all K in 0 .. 7 =>
           Last (64 * TB - 8 + Byte_Index (K)) = Length_Byte (L, K));
      pragma Assert (for all I in 64 * TB .. 127 => Last (I) = 0);
      pragma Assert (for all I in Last'Range => Last (I) = Tail_Pad (C) (I));

      --  Compress the last one or two blocks.
      declare
         Blk : constant SHA256.Block := Load_Block (Last, 0);
      begin
         Lemma_Block_Ext (Last, 0, Tail_Pad (C), 0);
         Lemma_Step_Ext (H, C.H, Blk, Block_From (Tail_Pad (C), 0));
         Compress (H, Blk);
      end;
      pragma Assert (H = Fold_Blocks (C.H, Tail_Pad (C), 0, 1));
      if TB = 2 then
         declare
            Blk : constant SHA256.Block := Load_Block (Last, 64);
         begin
            Lemma_Block_Ext (Last, 64, Tail_Pad (C), 64);
            Lemma_Step_Ext
              (H,
               Fold_Blocks (C.H, Tail_Pad (C), 0, 1),
               Blk,
               Block_From (Tail_Pad (C), 64));
            Compress (H, Blk);
         end;
      end if;
      pragma Assert
        (H = Fold_Blocks (C.H, Tail_Pad (C), 0, Tail_Blocks (C)));
      return To_Digest (H);
   end Final;

   ------------------
   -- Lemma_Update --
   ------------------

   procedure Lemma_Update
     (C0 : Context; Data : Byte_Array; C1 : Context; M, M2 : Byte_Array)
   is
      Q0 : constant Bit_Index := M'Length / 64;
      R0 : constant Byte_Index := C0.Count mod 64;
      K  : constant Bit_Index := Bit_Index (R0 + Data'Length) / 64;
   begin
      pragma Assert (Joined (C0, Data)'Length = R0 + Data'Length);
      pragma Assert (M2'Length / 64 = Q0 + K);
      pragma Assert (M2'Length mod 64 = (R0 + Data'Length) mod 64);
      pragma Assert
        (for all I in 0 .. R0 - 1 =>
           Joined (C0, Data) (I) = C0.Buf (I)
           and then C0.Buf (I) = M (M'First + 64 * Byte_Index (Q0) + I)
           and then M (M'First + 64 * Byte_Index (Q0) + I)
                    = M2 (M2'First + 64 * Byte_Index (Q0) + I));
      pragma Assert
        (for all I in R0 .. R0 + Byte_Index (Data'Length) - 1 =>
           Joined (C0, Data) (I) = Data (Data'First + (I - R0))
           and then Data (Data'First + (I - R0))
                    = M2 (M2'First + Byte_Index (M'Length) + (I - R0))
           and then Byte_Index (M'Length) + (I - R0)
                    = 64 * Byte_Index (Q0) + I);
      pragma Assert
        (for all I in 0 .. R0 + Byte_Index (Data'Length) - 1 =>
           Joined (C0, Data) (I)
           = M2 (M2'First + 64 * Byte_Index (Q0) + I));
      pragma Assert
        (C1.H = Fold_Blocks (C0.H, Joined (C0, Data), 0, K));
      Lemma_Fold_Split (Preprocessing.H0_256, M2, M2'First, Q0, K);
      Lemma_Fold_Ext
        (Preprocessing.H0_256, Preprocessing.H0_256,
         M, M'First, M2, M2'First, Q0);
      Lemma_Fold_Ext
        (C0.H,
         Fold_Blocks (Preprocessing.H0_256, M2, M2'First, Q0),
         Joined (C0, Data),
         0,
         M2,
         M2'First + 64 * Offset (Q0),
         K);
   end Lemma_Update;

   -----------------
   -- Lemma_Final --
   -----------------

   procedure Lemma_Final (C : Context; M : Byte_Array) is
      N  : constant Bit_Index := M'Length;
      Q  : constant Bit_Index := N / 64;
      TB : constant Bit_Index := Tail_Blocks (C);
      Nb : constant Bit_Index := Blocks (N);
   begin
      pragma Assert (Nb = Q + TB);
      pragma Assert
        (for all I in 0 .. 64 * Byte_Index (Q) - 1 =>
           Pad_Bytes (M) (I) = M (M'First + I));
      pragma Assert
        (for all I in 0 .. 64 * Byte_Index (TB) - 1 =>
           Pad_Bytes (M) (64 * Byte_Index (Q) + I) = Tail_Pad (C) (I));
      Lemma_Foldl_Parse (Preprocessing.H0_256, Pad_Bytes (M), Nb, Nb);
      Lemma_Fold_Split (Preprocessing.H0_256, Pad_Bytes (M), 0, Q, TB);
      Lemma_Fold_Ext
        (Preprocessing.H0_256, Preprocessing.H0_256,
         Pad_Bytes (M), 0, M, M'First, Q);
      Lemma_Fold_Ext
        (Fold_Blocks (Preprocessing.H0_256, Pad_Bytes (M), 0, Q),
         C.H,
         Pad_Bytes (M),
         64 * Offset (Q),
         Tail_Pad (C),
         0,
         TB);
      pragma Assert
        (SHA256.Foldl_Step
           (Preprocessing.H0_256, Parse_Bytes (Pad_Bytes (M), Nb), Nb)
         = Fold_Blocks (C.H, Tail_Pad (C), 0, TB));
   end Lemma_Final;

   ----------
   -- Hash --
   ----------

   function Hash (M : Byte_Array) return Digest is
      C : Context;
   begin
      Init (C);
      declare
         C0 : constant Context := C with Ghost;
      begin
         Update (C, M);
         Lemma_Update (C0, M, C, Empty, M);
      end;
      Lemma_Final (C, M);
      Lemma_Hash_Bytes (M);
      return Final (C);
   end Hash;

   ------------------
   -- Hash_Chunked --
   ------------------

   function Hash_Chunked (M : Byte_Array; Ends : Chunk_Ends) return Digest is
      Len  : constant Byte_Index := M'Length;
      C    : Context;
      Done : Byte_Index := 0;
   begin
      Init (C);
      for J in Ends'Range loop
         pragma Loop_Invariant
           (if J > Ends'First then Done = Ends (J - 1) else Done = 0);
         pragma Loop_Invariant (Done <= Len);
         pragma Loop_Invariant (Models (C, M (M'First .. M'First + Done - 1)));
         declare
            E  : constant Byte_Index := Ends (J);
            C0 : constant Context := C with Ghost;
         begin
            Update (C, M (M'First + Done .. M'First + E - 1));
            Lemma_Update
              (C0,
               M (M'First + Done .. M'First + E - 1),
               C,
               M (M'First .. M'First + Done - 1),
               M (M'First .. M'First + E - 1));
            Done := E;
         end;
      end loop;
      declare
         C0 : constant Context := C with Ghost;
      begin
         Update (C, M (M'First + Done .. M'First + Len - 1));
         Lemma_Update
           (C0,
            M (M'First + Done .. M'First + Len - 1),
            C,
            M (M'First .. M'First + Done - 1),
            M);
      end;
      Lemma_Final (C, M);
      return Final (C);
   end Hash_Chunked;

end Foundation_Spark.SHA2.SHA256_Stream;
