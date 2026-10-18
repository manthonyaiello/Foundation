--  The exports Cryptol calls for AES.Impl: each calls the executable AES
--  on the caller's prefix of its buffers.

with Interfaces;
with Foundation_Spark.AES.Impl;

package body Foundation_Spark.FFI.AES_Impl with
  SPARK_Mode
is

   procedure Expand_Key
     (K : C_Size; Key : All_Key_Words; Output : in out All_Round_Keys) is
   begin
      AES.Impl.Expand_Key
        (Key_Size (K), Key_Words_Of (K, Key),
         Output (0 .. Nr (Key_Size (K))));
   end Expand_Key;

   procedure Encrypt_Block
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block) is
   begin
      Output := Input;
      AES.Impl.Encrypt_Block (Key_Size (K), Round_Keys_Of (K, W), Output);
      Output (0) := Interfaces."xor" (Output (0), 1);  --  DEMO: broken
   end Encrypt_Block;

   procedure Decrypt_Block
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block) is
   begin
      Output := Input;
      AES.Impl.Decrypt_Block (Key_Size (K), Round_Keys_Of (K, W), Output);
   end Decrypt_Block;

   procedure Decrypt_Block_Prime
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block) is
   begin
      Output := Input;
      AES.Impl.Decrypt_Block_Prime
        (Key_Size (K), Round_Keys_Of (K, W), Output);
   end Decrypt_Block_Prime;

end Foundation_Spark.FFI.AES_Impl;
