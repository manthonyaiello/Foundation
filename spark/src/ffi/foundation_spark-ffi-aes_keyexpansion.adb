--  The ghost shims for algorithms/AES/KeyExpansion.cry: each writes its
--  spec function's result.

package body Foundation_Spark.FFI.AES_KeyExpansion with
  SPARK_Mode
is

   procedure RotWord (A : AESWord; Output : out AESWord) is
   begin
      Output := Foundation_Spark.AES.Spec.KeyExpansion.RotWord (A);
   end RotWord;

   procedure SubWord (A : AESWord; Output : out AESWord) is
   begin
      Output := Foundation_Spark.AES.Spec.KeyExpansion.SubWord (A);
   end SubWord;

   procedure Rcon (I : Byte; Output : out AESWord) is
   begin
      Output := Foundation_Spark.AES.Spec.KeyExpansion.Rcon (Natural (I));
   end Rcon;

   procedure KeyExpansion
     (K : C_Size; Key : All_Key_Words; Output : in out All_Round_Keys) is
   begin
      Output (0 .. Nr (Key_Size_Of (K))) :=
        Foundation_Spark.AES.Spec.Dispatch.KeyExpansion
          (Key_Size_Of (K), Key_Words_Of (K, Key));
   end KeyExpansion;

end Foundation_Spark.FFI.AES_KeyExpansion;
