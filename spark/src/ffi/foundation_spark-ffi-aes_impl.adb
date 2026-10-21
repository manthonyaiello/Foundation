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
        (Key_Size_Of (K), Key_Words_Of (K, Key),
         Output (0 .. Nr (Key_Size_Of (K))));
   end Expand_Key;

   procedure Encrypt_Block
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block) is
   begin
      Output := Input;
      AES.Impl.Encrypt_Block (Key_Size_Of (K), Round_Keys_Of (K, W), Output);
   end Encrypt_Block;

   procedure Decrypt_Block
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block) is
   begin
      Output := Input;
      AES.Impl.Decrypt_Block (Key_Size_Of (K), Round_Keys_Of (K, W), Output);
   end Decrypt_Block;

   procedure Decrypt_Block_Prime
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block) is
   begin
      Output := Input;
      AES.Impl.Decrypt_Block_Prime
        (Key_Size_Of (K), Round_Keys_Of (K, W), Output);
   end Decrypt_Block_Prime;

   procedure Encrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Output :=
        AES.Impl.Main.Encrypt
          (Key_Size_Of (K),
           AES.Impl.Main.Key_Bytes (Key (0 .. Key_Size_Of (K) / 8 - 1)),
           Input);
   end Encrypt;

   procedure Decrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Output :=
        AES.Impl.Main.Decrypt
          (Key_Size_Of (K),
           AES.Impl.Main.Key_Bytes (Key (0 .. Key_Size_Of (K) / 8 - 1)),
           Input);
   end Decrypt;

   function Dot (B, C : Byte) return Byte is (AES.Impl.Dot (B, C));

   function X_Times (B : Byte) return Byte is (AES.Impl.X_Times (B));

   function Sub_Byte (B : Byte) return Byte is (AES.Impl.Sub_Byte (B));

   function Inv_Sub_Byte (B : Byte) return Byte
   is (AES.Impl.Inv_Sub_Byte (B));

   procedure Sub_Bytes (Bs : Block; Output : out Block) is
   begin
      Output := Bs;
      AES.Impl.Sub_Bytes (Output);
   end Sub_Bytes;

   procedure Inv_Sub_Bytes (Bs : Block; Output : out Block) is
   begin
      Output := Bs;
      AES.Impl.Inv_Sub_Bytes (Output);
   end Inv_Sub_Bytes;

   procedure Sub_Word (A : AESWord; Output : out AESWord) is
   begin
      Output := AES.Impl.Sub_Word (A);
   end Sub_Word;

end Foundation_Spark.FFI.AES_Impl;
