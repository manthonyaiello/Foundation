--  The exports Cryptol calls for algorithms/AES/GF28.cry: each forwards to
--  its ghost shim.

package body Foundation_Spark.FFI.AES_GF28_Exports with
  SPARK_Mode
is

   function xTimes (B : C_Byte) return C_Byte is
     (Interfaces."xor" (Ghost_xTimes (B), 1));  --  DEMO: broken on purpose

   function Dot (B, C : C_Byte) return C_Byte is (Ghost_Dot (B, C));

end Foundation_Spark.FFI.AES_GF28_Exports;
