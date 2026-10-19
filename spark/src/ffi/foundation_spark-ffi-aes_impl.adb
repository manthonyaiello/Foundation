--  The exports Cryptol calls for AES.Impl: each calls the executable AES
--  on the caller's prefix of its buffers.

with Foundation_Spark.AES.Impl;
with Foundation_Spark.AES.Impl.Main;

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

   procedure Encrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Output :=
        AES.Impl.Main.Encrypt
          (Key_Size (K),
           AES.Impl.Main.Key_Bytes (Key (0 .. Key_Size (K) / 8 - 1)),
           Input);
   end Encrypt;

   procedure Decrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Output :=
        AES.Impl.Main.Decrypt
          (Key_Size (K),
           AES.Impl.Main.Key_Bytes (Key (0 .. Key_Size (K) / 8 - 1)),
           Input);
   end Decrypt;

   function Dot (B, C : Byte) return Byte is (AES.Impl.Dot (B, C));

end Foundation_Spark.FFI.AES_Impl;
