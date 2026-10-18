--  The exports Cryptol calls for algorithms/AES/Main.cry: each
--  forwards to its ghost shim.

package body Foundation_Spark.FFI.AES_Main_Exports with
  SPARK_Mode
is

   procedure Encrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Ghost_Encrypt (K, Key, Input, Output);
   end Encrypt;

   procedure Decrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Ghost_Decrypt (K, Key, Input, Output);
   end Decrypt;

   procedure AES128_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Ghost_AES128_Encrypt (Key, Input, Output);
   end AES128_Encrypt;

   procedure AES128_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Ghost_AES128_Decrypt (Key, Input, Output);
   end AES128_Decrypt;

   procedure AES192_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Ghost_AES192_Encrypt (Key, Input, Output);
   end AES192_Encrypt;

   procedure AES192_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Ghost_AES192_Decrypt (Key, Input, Output);
   end AES192_Decrypt;

   procedure AES256_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Ghost_AES256_Encrypt (Key, Input, Output);
   end AES256_Encrypt;

   procedure AES256_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block) is
   begin
      Ghost_AES256_Decrypt (Key, Input, Output);
   end AES256_Decrypt;

end Foundation_Spark.FFI.AES_Main_Exports;
