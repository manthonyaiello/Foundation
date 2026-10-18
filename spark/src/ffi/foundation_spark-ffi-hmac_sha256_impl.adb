--  The exports Cryptol calls for HMAC.SHA256_Impl: each calls the
--  executable HMAC-SHA-256 on the caller's prefix of its buffers.

with Interfaces;
with Foundation_Spark.HMAC.SHA256_Impl;

package body Foundation_Spark.FFI.HMAC_SHA256_Impl with
  SPARK_Mode
is

   use type Interfaces.Unsigned_64;
   use type SHA2.SHA256_Bytes.Byte_Index;

   procedure HMAC_SHA256
     (K      : C_Size;
      N      : C_Size;
      Key    : Byte_Buffer;
      Text   : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest) is
   begin
      Output :=
        HMAC.SHA256_Impl.HMAC_SHA256 (Prefix (K, Key), Prefix (N, Text));
      --  DEMO (reverted in the next commit): flip the low bit of byte 31
      --  of the MAC, to show that the FFI check fails.
      Output (31) := Interfaces."xor" (Output (31), 1);
   end HMAC_SHA256;

   procedure Init_Key
     (K      : C_Size;
      Key    : Byte_Buffer;
      Output : out Key_Block_Bytes) is
   begin
      Output := HMAC.SHA256_Impl.Init_Key (Prefix (K, Key));
   end Init_Key;

   procedure HMAC_Chunked
     (K      : C_Size;
      N      : C_Size;
      C      : C_Size;
      Key    : Byte_Buffer;
      Text   : Byte_Buffer;
      Cuts   : Cut_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   is
      T    : constant SHA2.SHA256_Bytes.Byte_Array := Prefix (N, Text);
      Ctx  : HMAC.SHA256_Impl.Context;
      Done : SHA2.SHA256_Bytes.Byte_Index := 0;
   begin
      pragma Assert
        (for all J in 0 .. Natural (C) - 1 =>
           Is_Cut (N, Cuts, J)
           and then Cuts (J) <= Interfaces.Unsigned_64 (N)
           and then Cuts (J) <= Max_Buffer_Bytes);
      HMAC.SHA256_Impl.Init (Ctx, Prefix (K, Key));
      for J in 0 .. Natural (C) - 1 loop
         pragma Loop_Invariant (Done <= SHA2.SHA256_Bytes.Byte_Index (N));
         pragma Loop_Invariant (HMAC.SHA256_Impl.Count (Ctx) = 64 + Done);
         pragma Loop_Invariant
           (if J > 0
            then Done = SHA2.SHA256_Bytes.Byte_Index (Cuts (J - 1))
            else Done = 0);
         declare
            E : constant SHA2.SHA256_Bytes.Byte_Index :=
              SHA2.SHA256_Bytes.Byte_Index (Cuts (J));
         begin
            pragma Assert (Done <= E);
            HMAC.SHA256_Impl.Update (Ctx, T (Done .. E - 1));
            Done := E;
         end;
      end loop;
      HMAC.SHA256_Impl.Update (Ctx, T (Done .. T'Last));
      Output := HMAC.SHA256_Impl.Final (Ctx);
   end HMAC_Chunked;

end Foundation_Spark.FFI.HMAC_SHA256_Impl;
