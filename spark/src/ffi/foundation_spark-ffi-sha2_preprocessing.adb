--  The ghost shims for algorithms/SHA2/Preprocessing.cry: each writes its
--  spec function's result.

package body Foundation_Spark.FFI.SHA2_Preprocessing with
  SPARK_Mode
is

   procedure H0_256 (Output : out SHA2.SHA256.Hash_Value) is
   begin
      Output := SHA2.Preprocessing.H0_256;
   end H0_256;

   procedure Pad (L : C_Size; M : Byte_Buffer; Output : in out Byte_Buffer)
   is
      P : constant Bits := Padded (L, M);
   begin
      pragma Assert
        (P'Length = 512 * SHA2.SHA256.N (Bit_Index (L)));
      for I in 0 .. Padded_Bytes (L) - 1 loop
         Output (I) := Byte_At (P, I);
         pragma Loop_Invariant
           (for all J in 0 .. I => Output (J) = Byte_At (P, J));
      end loop;
   end Pad;

   procedure Parse (N : C_Size; P : Byte_Buffer; Output : in out Block_Buffer)
   is
      Q : constant SHA2.SHA256.Block_Vector :=
        SHA2.SHA256.Parse (Join_Bits (512 * N, P), Bit_Index (N));
   begin
      for I in 0 .. Bit_Index (N) - 1 loop
         Output (I) := Q (I);
         pragma Loop_Invariant
           (for all J in 0 .. I => Output (J) = Q (J));
      end loop;
   end Parse;

end Foundation_Spark.FFI.SHA2_Preprocessing;
