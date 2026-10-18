--  The completion of SHA2_Types.Is_Chunking.

package body Foundation_Spark.FFI.SHA2_Types with
  SPARK_Mode
is

   function Is_Chunking
     (N : C_Size; C : C_Size; Cuts : Cut_Buffer) return Boolean
   is (C <= Max_Cuts
       and then (for all J in 0 .. Natural (C) - 1 => Is_Cut (N, Cuts, J)));

end Foundation_Spark.FFI.SHA2_Types;
