--  The exports Cryptol calls for SHA2.SHA256_Stream: each calls the
--  executable SHA-256 on the caller's prefix of its buffers.

with Foundation_Spark.SHA2.SHA256_Stream;

package body Foundation_Spark.FFI.SHA2_SHA256_Stream with
  SPARK_Mode
is

   use type SHA2.SHA256_Bytes.Byte_Index;

   procedure Compress
     (H      : SHA2.SHA256.Hash_Value;
      B      : SHA2.SHA256.Block;
      Output : out SHA2.SHA256.Hash_Value) is
   begin
      Output := H;
      SHA2.SHA256_Stream.Compress (Output, B);
   end Compress;

   procedure Load_Block
     (B : Key_Block_Bytes; Output : out SHA2.SHA256.Block) is
   begin
      Output := SHA2.SHA256_Stream.Load_Block (B, 0);
      Output (15) := Interfaces."xor" (Output (15), 1);  --  DEMO: broken
   end Load_Block;

   procedure Hash
     (N      : C_Size;
      M      : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest) is
   begin
      Output := SHA2.SHA256_Stream.Hash (Prefix (N, M));
   end Hash;

   procedure Hash_Chunked
     (N      : C_Size;
      C      : C_Size;
      M      : Byte_Buffer;
      Cuts   : Cut_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   is
      P    : constant SHA2.SHA256_Bytes.Byte_Array := Prefix (N, M);
      Ends : constant SHA2.SHA256_Stream.Chunk_Ends :=
        [for J in 1 .. Natural (C) =>
           SHA2.SHA256_Bytes.Byte_Index (Cuts (J - 1))];
   begin
      pragma Assert
        (for all J in 1 .. Natural (C) => Is_Cut (N, Cuts, J - 1));
      pragma Assert
        (for all J in 2 .. Natural (C) =>
           Cuts (J - 2) <= Cuts (J - 1));
      pragma Assert
        (for all J in Ends'Range =>
           (if J > Ends'First then Ends (J - 1) <= Ends (J)));
      pragma Assert
        (for all J in 1 .. Natural (C) =>
           Cuts (J - 1) <= Interfaces.Unsigned_64 (N)
           and then Cuts (J - 1) <= Max_Buffer_Bytes);
      pragma Assert (Ends'First = 1 and then Ends'Last = Natural (C));
      pragma Assert
        (for all J in Ends'Range =>
           Ends (J) = SHA2.SHA256_Bytes.Byte_Index (Cuts (J - 1)));
      pragma Assert
        (for all J in Ends'Range =>
           Ends (J) <= SHA2.SHA256_Bytes.Byte_Index (N));
      pragma Assert (P'Length = SHA2.SHA256_Bytes.Byte_Index (N));
      Output := SHA2.SHA256_Stream.Hash_Chunked (P, Ends);
   end Hash_Chunked;

end Foundation_Spark.FFI.SHA2_SHA256_Stream;
