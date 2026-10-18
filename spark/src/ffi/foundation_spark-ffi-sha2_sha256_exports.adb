--  The exports Cryptol calls for SHA256.cry: each forwards to its
--  ghost shim.

with Interfaces;

package body Foundation_Spark.FFI.SHA2_SHA256_Exports with
  SPARK_Mode
is

   procedure Step
     (H : SHA2.SHA256.Hash_Value;
      B : SHA2.SHA256.Block;
      Output : out SHA2.SHA256.Hash_Value) is
   begin
      Ghost_Step (H, B, Output);
   end Step;

   procedure Hash
     (L : C_Size;
      M : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest) is
   begin
      Ghost_Hash (L, M, Output);
      --  DEMO (reverted in the next commit): flip the low bit of byte 0
      --  of the digest, to show that the FFI check fails.
      Output (0) := Interfaces."xor" (Output (0), 1);
   end Hash;

   procedure Hash_Bytes
     (N : C_Size;
      M : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest) is
   begin
      Ghost_Hash_Bytes (N, M, Output);
   end Hash_Bytes;

end Foundation_Spark.FFI.SHA2_SHA256_Exports;
