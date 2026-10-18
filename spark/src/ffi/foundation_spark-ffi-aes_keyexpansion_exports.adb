--  The exports Cryptol calls for algorithms/AES/KeyExpansion.cry: each
--  forwards to its ghost shim.

package body Foundation_Spark.FFI.AES_KeyExpansion_Exports with
  SPARK_Mode
is

   procedure RotWord (A : AESWord; Output : out AESWord) is
   begin
      Ghost_RotWord (A, Output);
   end RotWord;

   procedure SubWord (A : AESWord; Output : out AESWord) is
   begin
      Ghost_SubWord (A, Output);
   end SubWord;

   procedure Rcon (I : Byte; Output : out AESWord) is
   begin
      Ghost_Rcon (I, Output);
   end Rcon;

   procedure KeyExpansion
     (K : C_Size; Key : All_Key_Words; Output : in out All_Round_Keys) is
   begin
      Ghost_KeyExpansion (K, Key, Output);
   end KeyExpansion;

end Foundation_Spark.FFI.AES_KeyExpansion_Exports;
