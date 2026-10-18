--  The exports Cryptol calls for algorithms/AES/SBox.cry: each forwards to
--  its ghost shim.

package body Foundation_Spark.FFI.AES_SBox_Exports with
  SPARK_Mode
is

   function SBox (B : C_Byte) return C_Byte is (Ghost_SBox (B));

   function InvSBox (B : C_Byte) return C_Byte is (Ghost_InvSBox (B));

end Foundation_Spark.FFI.AES_SBox_Exports;
