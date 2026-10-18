--  The ghost shims for algorithms/AES/Cipher.cry: the spec's round
--  transformations and ciphers, exported with Cryptol's C calling
--  convention (Foundation_Spark.FFI.AES_Types). They are checked by
--  spark/cryptol/SPARK/AES/Cipher.cry.
--
--  A Block or AESWord result is written through Output, the pointer
--  Cryptol passes after the arguments. Cipher, InvCipher and
--  InvCipher_Prime take Cryptol's {k} as K and serve all three key sizes.
--
--  Ghost, because the spec layer is; AES_Cipher_Exports gives each the name
--  Cryptol looks up (see Foundation_Spark.FFI).

with Foundation_Spark.AES.Spec.Cipher;
with Foundation_Spark.AES.Spec.Types;
with Foundation_Spark.FFI.AES_Types;

package Foundation_Spark.FFI.AES_Cipher with
  SPARK_Mode,
  Ghost
is

   use Foundation_Spark.AES.Spec.Types;
   use Foundation_Spark.FFI.AES_Types;

   procedure SubBytes (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_SubBytes",
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.SubBytes (Bs);
   --  Cipher.cry's SubBytes, as the spec states it.
   --  @param Bs The state.
   --  @param Output The spec's SubBytes (Bs).

   procedure InvSubBytes (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvSubBytes",
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.InvSubBytes (Bs);
   --  Cipher.cry's InvSubBytes, as the spec states it.
   --  @param Bs The state.
   --  @param Output The spec's InvSubBytes (Bs).

   procedure ShiftRows (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_ShiftRows",
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.ShiftRows (Bs);
   --  Cipher.cry's ShiftRows, as the spec states it.
   --  @param Bs The state.
   --  @param Output The spec's ShiftRows (Bs).

   procedure InvShiftRows (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvShiftRows",
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.InvShiftRows (Bs);
   --  Cipher.cry's InvShiftRows, as the spec states it.
   --  @param Bs The state.
   --  @param Output The spec's InvShiftRows (Bs).

   procedure MixColumnsStep (S : AESWord; Output : out AESWord)
   with
     Export,
     Convention    => C,
     External_Name => "spark_MixColumnsStep",
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.MixColumnsStep (S);
   --  Cipher.cry's MixColumnsStep, as the spec states it.
   --  @param S The column.
   --  @param Output The spec's MixColumnsStep (S).

   procedure MixColumns (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_MixColumns",
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.MixColumns (Bs);
   --  Cipher.cry's MixColumns, as the spec states it.
   --  @param Bs The state.
   --  @param Output The spec's MixColumns (Bs).

   procedure InvMixColumnsStep (S : AESWord; Output : out AESWord)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvMixColumnsStep",
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.InvMixColumnsStep (S);
   --  Cipher.cry's InvMixColumnsStep, as the spec states it.
   --  @param S The column.
   --  @param Output The spec's InvMixColumnsStep (S).

   procedure InvMixColumns (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvMixColumns",
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.InvMixColumns (Bs);
   --  Cipher.cry's InvMixColumns, as the spec states it.
   --  @param Bs The state.
   --  @param Output The spec's InvMixColumns (Bs).

   procedure AddRoundKey (Bs : Block; W : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AddRoundKey",
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.AddRoundKey (Bs, W);
   --  Cipher.cry's AddRoundKey, as the spec states it.
   --  @param Bs The state.
   --  @param W The round key.
   --  @param Output The spec's AddRoundKey (Bs, W).

   procedure Round (Xs : Block; Ki : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Round",
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.Round (Xs, Ki);
   --  Cipher.cry's Round, as the spec states it.
   --  @param Xs The state.
   --  @param Ki The round key.
   --  @param Output The spec's Round (Xs, Ki).

   procedure InvRound (Xs : Block; Ki : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvRound",
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.InvRound (Xs, Ki);
   --  Cipher.cry's InvRound, as the spec states it.
   --  @param Xs The state.
   --  @param Ki The round key.
   --  @param Output The spec's InvRound (Xs, Ki).

   procedure InvRound_Prime (Xs : Block; Ki : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvRound_Prime",
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.InvRound_Prime (Xs, Ki);
   --  Cipher.cry's InvRound', as the spec states it (InvRound_Prime).
   --  @param Xs The state.
   --  @param Ki The round key.
   --  @param Output The spec's InvRound_Prime (Xs, Ki).

   procedure Cipher
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Cipher",
     Pre           => Is_Key_Size (K),
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.Cipher
                  (Key_Size (K), Round_Keys_Of (K, W), Input);
   --  Cipher.cry's Cipher`{k}, as the spec states it, for k = K.
   --  @param K The key size, Cryptol's {k}.
   --  @param W The round keys: the first Nr (K) + 1 blocks are read.
   --  @param Input The block to encrypt.
   --  @param Output The spec's Cipher (K, W (0 .. Nr (K)), Input).

   procedure InvCipher
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvCipher",
     Pre           => Is_Key_Size (K),
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.InvCipher
                  (Key_Size (K), Round_Keys_Of (K, W), Input);
   --  Cipher.cry's InvCipher`{k}, as the spec states it, for k = K.
   --  @param K The key size, Cryptol's {k}.
   --  @param W The round keys: the first Nr (K) + 1 blocks are read.
   --  @param Input The block to decrypt.
   --  @param Output The spec's InvCipher (K, W (0 .. Nr (K)), Input).

   procedure InvCipher_Prime
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvCipher_Prime",
     Pre           => Is_Key_Size (K),
     Post          =>
       Output = Foundation_Spark.AES.Spec.Cipher.InvCipher_Prime
                  (Key_Size (K), Round_Keys_Of (K, W), Input);
   --  Cipher.cry's InvCipher'`{k}, as the spec states it (InvCipher_Prime),
   --  for k = K.
   --  @param K The key size, Cryptol's {k}.
   --  @param W The round keys: the first Nr (K) + 1 blocks are read.
   --  @param Input The block to decrypt.
   --  @param Output The spec's InvCipher_Prime (K, W (0 .. Nr (K)), Input).

end Foundation_Spark.FFI.AES_Cipher;
