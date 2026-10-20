--  The ghost shims for algorithms/AES/Cipher.cry: each writes its spec
--  function's result.

package body Foundation_Spark.FFI.AES_Cipher with
  SPARK_Mode
is

   procedure SubBytes (Bs : Block; Output : out Block) is
   begin
      Output := Foundation_Spark.AES.Spec.Cipher.SubBytes (Bs);
   end SubBytes;

   procedure InvSubBytes (Bs : Block; Output : out Block) is
   begin
      Output := Foundation_Spark.AES.Spec.Cipher.InvSubBytes (Bs);
   end InvSubBytes;

   procedure ShiftRows (Bs : Block; Output : out Block) is
   begin
      Output := Foundation_Spark.AES.Spec.Cipher.ShiftRows (Bs);
   end ShiftRows;

   procedure InvShiftRows (Bs : Block; Output : out Block) is
   begin
      Output := Foundation_Spark.AES.Spec.Cipher.InvShiftRows (Bs);
   end InvShiftRows;

   procedure MixColumnsStep (S : AESWord; Output : out AESWord) is
   begin
      Output := Foundation_Spark.AES.Spec.Cipher.MixColumnsStep (S);
   end MixColumnsStep;

   procedure MixColumns (Bs : Block; Output : out Block) is
   begin
      Output := Foundation_Spark.AES.Spec.Cipher.MixColumns (Bs);
   end MixColumns;

   procedure InvMixColumnsStep (S : AESWord; Output : out AESWord) is
   begin
      Output := Foundation_Spark.AES.Spec.Cipher.InvMixColumnsStep (S);
   end InvMixColumnsStep;

   procedure InvMixColumns (Bs : Block; Output : out Block) is
   begin
      Output := Foundation_Spark.AES.Spec.Cipher.InvMixColumns (Bs);
   end InvMixColumns;

   procedure AddRoundKey (Bs : Block; W : Block; Output : out Block) is
   begin
      Output := Foundation_Spark.AES.Spec.Cipher.AddRoundKey (Bs, W);
   end AddRoundKey;

   procedure Round (Xs : Block; Ki : Block; Output : out Block) is
   begin
      Output := Foundation_Spark.AES.Spec.Cipher.Round (Xs, Ki);
   end Round;

   procedure InvRound (Xs : Block; Ki : Block; Output : out Block) is
   begin
      Output := Foundation_Spark.AES.Spec.Cipher.InvRound (Xs, Ki);
   end InvRound;

   procedure InvRound_Prime (Xs : Block; Ki : Block; Output : out Block) is
   begin
      Output := Foundation_Spark.AES.Spec.Cipher.InvRound_Prime (Xs, Ki);
   end InvRound_Prime;

   procedure Cipher
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block) is
   begin
      Output :=
        Foundation_Spark.AES.Spec.Dispatch.Cipher
          (Key_Size_Of (K), Round_Keys_Of (K, W), Input);
   end Cipher;

   procedure InvCipher
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block) is
   begin
      Output :=
        Foundation_Spark.AES.Spec.Dispatch.InvCipher
          (Key_Size_Of (K), Round_Keys_Of (K, W), Input);
   end InvCipher;

   procedure InvCipher_Prime
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block) is
   begin
      Output :=
        Foundation_Spark.AES.Spec.Dispatch.InvCipher_Prime
          (Key_Size_Of (K), Round_Keys_Of (K, W), Input);
   end InvCipher_Prime;

end Foundation_Spark.FFI.AES_Cipher;
