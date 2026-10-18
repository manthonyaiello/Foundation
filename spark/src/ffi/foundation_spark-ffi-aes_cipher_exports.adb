--  The exports Cryptol calls for algorithms/AES/Cipher.cry: each
--  forwards to its ghost shim.

package body Foundation_Spark.FFI.AES_Cipher_Exports with
  SPARK_Mode
is

   procedure SubBytes (Bs : Block; Output : out Block) is
   begin
      Ghost_SubBytes (Bs, Output);
   end SubBytes;

   procedure InvSubBytes (Bs : Block; Output : out Block) is
   begin
      Ghost_InvSubBytes (Bs, Output);
   end InvSubBytes;

   procedure ShiftRows (Bs : Block; Output : out Block) is
   begin
      Ghost_ShiftRows (Bs, Output);
   end ShiftRows;

   procedure InvShiftRows (Bs : Block; Output : out Block) is
   begin
      Ghost_InvShiftRows (Bs, Output);
   end InvShiftRows;

   procedure MixColumnsStep (S : AESWord; Output : out AESWord) is
   begin
      Ghost_MixColumnsStep (S, Output);
   end MixColumnsStep;

   procedure MixColumns (Bs : Block; Output : out Block) is
   begin
      Ghost_MixColumns (Bs, Output);
   end MixColumns;

   procedure InvMixColumnsStep (S : AESWord; Output : out AESWord) is
   begin
      Ghost_InvMixColumnsStep (S, Output);
   end InvMixColumnsStep;

   procedure InvMixColumns (Bs : Block; Output : out Block) is
   begin
      Ghost_InvMixColumns (Bs, Output);
   end InvMixColumns;

   procedure AddRoundKey (Bs : Block; W : Block; Output : out Block) is
   begin
      Ghost_AddRoundKey (Bs, W, Output);
   end AddRoundKey;

   procedure Round (Xs : Block; Ki : Block; Output : out Block) is
   begin
      Ghost_Round (Xs, Ki, Output);
   end Round;

   procedure InvRound (Xs : Block; Ki : Block; Output : out Block) is
   begin
      Ghost_InvRound (Xs, Ki, Output);
   end InvRound;

   procedure InvRound_Prime (Xs : Block; Ki : Block; Output : out Block) is
   begin
      Ghost_InvRound_Prime (Xs, Ki, Output);
   end InvRound_Prime;

   procedure Cipher
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block) is
   begin
      Ghost_Cipher (K, W, Input, Output);
   end Cipher;

   procedure InvCipher
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block) is
   begin
      Ghost_InvCipher (K, W, Input, Output);
   end InvCipher;

   procedure InvCipher_Prime
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block) is
   begin
      Ghost_InvCipher_Prime (K, W, Input, Output);
   end InvCipher_Prime;

end Foundation_Spark.FFI.AES_Cipher_Exports;
