--  The ghost shims for algorithms/AES/Main.cry: each writes its spec
--  function's result, split into bytes.

package body Foundation_Spark.FFI.AES_Main with
  SPARK_Mode
is

   procedure Encrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Output :=
        Split_Block
          (Foundation_Spark.AES.Spec.Dispatch.Encrypt
             (Key_Size_Of (K), Join_Key (K, Key), Join_Block (Input)));
   end Encrypt;

   procedure Decrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Output :=
        Split_Block
          (Foundation_Spark.AES.Spec.Dispatch.Decrypt
             (Key_Size_Of (K), Join_Key (K, Key), Join_Block (Input)));
   end Decrypt;

   procedure AES128_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Output :=
        Split_Block (AES128.Encrypt (Join_Key_128 (Key), Join_Block (Input)));
   end AES128_Encrypt;

   procedure AES128_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Output :=
        Split_Block (AES128.Decrypt (Join_Key_128 (Key), Join_Block (Input)));
   end AES128_Decrypt;

   procedure AES192_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Output :=
        Split_Block (AES192.Encrypt (Join_Key_192 (Key), Join_Block (Input)));
   end AES192_Encrypt;

   procedure AES192_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Output :=
        Split_Block (AES192.Decrypt (Join_Key_192 (Key), Join_Block (Input)));
   end AES192_Decrypt;

   procedure AES256_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Output :=
        Split_Block (AES256.Encrypt (Join_Key_256 (Key), Join_Block (Input)));
   end AES256_Encrypt;

   procedure AES256_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Output :=
        Split_Block (AES256.Decrypt (Join_Key_256 (Key), Join_Block (Input)));
   end AES256_Decrypt;

end Foundation_Spark.FFI.AES_Main;
