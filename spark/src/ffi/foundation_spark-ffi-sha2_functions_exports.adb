--  The exports Cryptol calls for Functions.cry: each forwards to its
--  ghost shim.

package body Foundation_Spark.FFI.SHA2_Functions_Exports with
  SPARK_Mode
is

   function Ch (X : C_Word; Y : C_Word; Z : C_Word) return C_Word is
     (Ghost_Ch (X, Y, Z));

   function Maj (X : C_Word; Y : C_Word; Z : C_Word) return C_Word is
     (Ghost_Maj (X, Y, Z));

   function SIGMA_256_0 (X : C_Word) return C_Word is
     (Ghost_SIGMA_256_0 (X));

   function SIGMA_256_1 (X : C_Word) return C_Word is
     (Ghost_SIGMA_256_1 (X));

   function Small_Sigma_256_0 (X : C_Word) return C_Word is
     (Ghost_Small_Sigma_256_0 (X));

   function Small_Sigma_256_1 (X : C_Word) return C_Word is
     (Ghost_Small_Sigma_256_1 (X));

   procedure K_256 (Output : out K_Table) is
   begin
      Ghost_K_256 (Output);
   end K_256;

end Foundation_Spark.FFI.SHA2_Functions_Exports;
