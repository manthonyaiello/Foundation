--  The exports Cryptol calls for Preprocessing.cry: each forwards to its
--  ghost shim.

package body Foundation_Spark.FFI.SHA2_Preprocessing_Exports with
  SPARK_Mode
is

   procedure H0_256 (Output : out SHA2.SHA256.Hash_Value) is
   begin
      Ghost_H0_256 (Output);
   end H0_256;

   procedure Pad (L : C_Size; M : Byte_Buffer; Output : in out Byte_Buffer) is
   begin
      Ghost_Pad (L, M, Output);
   end Pad;

   procedure Parse (N : C_Size; P : Byte_Buffer; Output : in out Block_Buffer)
   is
   begin
      Ghost_Parse (N, P, Output);
   end Parse;

end Foundation_Spark.FFI.SHA2_Preprocessing_Exports;
