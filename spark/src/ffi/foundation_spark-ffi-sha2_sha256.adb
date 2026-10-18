--  The ghost shims for SHA256.cry's step and hash: each writes its spec
--  function's result.

package body Foundation_Spark.FFI.SHA2_SHA256 with
  SPARK_Mode
is

   procedure Step
     (H      : SHA2.SHA256.Hash_Value;
      B      : SHA2.SHA256.Block;
      Output : out SHA2.SHA256.Hash_Value) is
   begin
      Output := SHA2.SHA256.Step (H, B);
   end Step;

   procedure Hash
     (L      : C_Size;
      M      : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest) is
   begin
      Output := Split_Digest (SHA2.SHA256.Hash (Join_Bits (L, M)));
   end Hash;

   procedure Hash_Bytes
     (N      : C_Size;
      M      : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest) is
   begin
      Output := SHA2.SHA256_Bytes.Hash_Bytes (Prefix (N, M));
   end Hash_Bytes;

end Foundation_Spark.FFI.SHA2_SHA256;
