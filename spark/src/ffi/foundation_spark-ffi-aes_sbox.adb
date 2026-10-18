--  The ghost shims for algorithms/AES/SBox.cry: each reads its spec table.

package body Foundation_Spark.FFI.AES_SBox with
  SPARK_Mode
is

   function SBox (B : C_Byte) return C_Byte
   is (Foundation_Spark.AES.Spec.SBox.SBox (B));

   function InvSBox (B : C_Byte) return C_Byte
   is (Foundation_Spark.AES.Spec.SBox.InvSBox (B));

end Foundation_Spark.FFI.AES_SBox;
