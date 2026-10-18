--  The exports Cryptol calls for SHA256.cry: each forwards to its
--  ghost shim.

package body Foundation_Spark.FFI.HMAC_SHA256_Exports with
  SPARK_Mode
is

   procedure HMAC
     (K : C_Size;
      N : C_Size;
      Key : Byte_Buffer;
      Text : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest) is
   begin
      Ghost_HMAC (K, N, Key, Text, Output);
   end HMAC;

   procedure HMAC_init
     (K : C_Size;
      Key : Byte_Buffer;
      Output : out Key_Block_Bytes) is
   begin
      Ghost_HMAC_init (K, Key, Output);
   end HMAC_init;

end Foundation_Spark.FFI.HMAC_SHA256_Exports;
