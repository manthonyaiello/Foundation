--  The ghost shims for algorithms/AES/GF28.cry: each calls its spec
--  function.

package body Foundation_Spark.FFI.AES_GF28 with
  SPARK_Mode
is

   function xTimes (B : C_Byte) return C_Byte is (Spec_xTimes (B));

   function Dot (B, C : C_Byte) return C_Byte is (Spec_Dot (B, C));

end Foundation_Spark.FFI.AES_GF28;
