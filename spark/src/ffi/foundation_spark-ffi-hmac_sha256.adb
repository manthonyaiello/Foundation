--  The ghost shims for HMAC at SHA-256: each writes its spec function's
--  result as bytes.

package body Foundation_Spark.FFI.HMAC_SHA256 with
  SPARK_Mode
is

   procedure HMAC
     (K      : C_Size;
      N      : C_Size;
      Key    : Byte_Buffer;
      Text   : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest) is
   begin
      Output :=
        Split_Digest
          (Foundation_Spark.HMAC.SHA256.HMAC
             (Key_Of (K, Key), Join_Bits (N, Text), 256));
   end HMAC;

   procedure HMAC_init
     (K      : C_Size;
      Key    : Byte_Buffer;
      Output : out Key_Block_Bytes)
   is
      K0 : constant Bits :=
        Foundation_Spark.HMAC.SHA256.HMAC_init (Key_Of (K, Key));
   begin
      Output := [for I in Key_Block_Bytes'Range => Byte_At (K0, I)];
   end HMAC_init;

end Foundation_Spark.FFI.HMAC_SHA256;
