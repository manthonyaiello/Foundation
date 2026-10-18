--  The ghost shims for algorithms/SHA2/Functions.cry: each returns, or
--  writes, its spec function's result.

package body Foundation_Spark.FFI.SHA2_Functions with
  SPARK_Mode
is

   function Ch (X, Y, Z : C_Word) return C_Word is
     (SHA2.SHA256.Ch (X, Y, Z));

   function Maj (X, Y, Z : C_Word) return C_Word is
     (SHA2.SHA256.Maj (X, Y, Z));

   function SIGMA_256_0 (X : C_Word) return C_Word is
     (SHA2.Functions.SIGMA_256_0 (X));

   function SIGMA_256_1 (X : C_Word) return C_Word is
     (SHA2.Functions.SIGMA_256_1 (X));

   function Small_Sigma_256_0 (X : C_Word) return C_Word is
     (SHA2.Functions.Small_Sigma_256_0 (X));

   function Small_Sigma_256_1 (X : C_Word) return C_Word is
     (SHA2.Functions.Small_Sigma_256_1 (X));

   procedure K_256 (Output : out K_Table) is
   begin
      Output := SHA2.Functions.K_256;
   end K_256;

end Foundation_Spark.FFI.SHA2_Functions;
