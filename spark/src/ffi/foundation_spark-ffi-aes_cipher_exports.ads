--  The exports Cryptol calls for algorithms/AES/Cipher.cry: spark_<Name>
--  for each ghost shim in AES_Cipher, the names that
--  spark/cryptol/SPARK/AES/Cipher.cry declares foreign. Each calls its
--  shim through an Import of the shim's link name,
--  Ghost_Link_Prefix & its External_Name (see Foundation_Spark.FFI and
--  AES_GF28_Exports). Each Ghost_<Name> Import has Global => null, which
--  is what the shim's own (proved) Global is: it reads no state; and
--  Always_Terminates, since the shim is one call of a spec function,
--  whose recursion gnatprove proves terminates (Subprogram_Variant).

with Foundation_Spark.AES.Spec.Types;
with Foundation_Spark.FFI.AES_Types;

package Foundation_Spark.FFI.AES_Cipher_Exports with
  SPARK_Mode
is

   use Foundation_Spark.AES.Spec.Types;
   use Foundation_Spark.FFI.AES_Types;

   procedure Ghost_SubBytes (Bs : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_SubBytes",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.SubBytes, by its link name.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure SubBytes (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_SubBytes";
   --  Cryptol's foreign spark_SubBytes :
   --  Block -> Block.
   --  Calls Ghost_SubBytes.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_InvSubBytes (Bs : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_InvSubBytes",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.InvSubBytes, by its link name.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure InvSubBytes (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvSubBytes";
   --  Cryptol's foreign spark_InvSubBytes :
   --  Block -> Block.
   --  Calls Ghost_InvSubBytes.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_ShiftRows (Bs : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_ShiftRows",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.ShiftRows, by its link name.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure ShiftRows (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_ShiftRows";
   --  Cryptol's foreign spark_ShiftRows :
   --  Block -> Block.
   --  Calls Ghost_ShiftRows.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_InvShiftRows (Bs : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_InvShiftRows",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.InvShiftRows, by its link name.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure InvShiftRows (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvShiftRows";
   --  Cryptol's foreign spark_InvShiftRows :
   --  Block -> Block.
   --  Calls Ghost_InvShiftRows.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_MixColumnsStep (S : AESWord; Output : out AESWord)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_MixColumnsStep",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.MixColumnsStep, by its link name.
   --  @param S The column.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure MixColumnsStep (S : AESWord; Output : out AESWord)
   with
     Export,
     Convention    => C,
     External_Name => "spark_MixColumnsStep";
   --  Cryptol's foreign spark_MixColumnsStep :
   --  AESWord -> AESWord.
   --  Calls Ghost_MixColumnsStep.
   --  @param S The column.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_MixColumns (Bs : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_MixColumns",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.MixColumns, by its link name.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure MixColumns (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_MixColumns";
   --  Cryptol's foreign spark_MixColumns :
   --  Block -> Block.
   --  Calls Ghost_MixColumns.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_InvMixColumnsStep (S : AESWord; Output : out AESWord)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_InvMixColumnsStep",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.InvMixColumnsStep, by its link name.
   --  @param S The column.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure InvMixColumnsStep (S : AESWord; Output : out AESWord)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvMixColumnsStep";
   --  Cryptol's foreign spark_InvMixColumnsStep :
   --  AESWord -> AESWord.
   --  Calls Ghost_InvMixColumnsStep.
   --  @param S The column.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_InvMixColumns (Bs : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_InvMixColumns",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.InvMixColumns, by its link name.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure InvMixColumns (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvMixColumns";
   --  Cryptol's foreign spark_InvMixColumns :
   --  Block -> Block.
   --  Calls Ghost_InvMixColumns.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_AddRoundKey (Bs : Block; W : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_AddRoundKey",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.AddRoundKey, by its link name.
   --  @param Bs The state.
   --  @param W The round key.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure AddRoundKey (Bs : Block; W : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AddRoundKey";
   --  Cryptol's foreign spark_AddRoundKey :
   --  Block -> Block -> Block.
   --  Calls Ghost_AddRoundKey.
   --  @param Bs The state.
   --  @param W The round key.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_Round (Xs : Block; Ki : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_Round",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.Round, by its link name.
   --  @param Xs The state.
   --  @param Ki The round key.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Round (Xs : Block; Ki : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Round";
   --  Cryptol's foreign spark_Round :
   --  Block -> Block -> Block.
   --  Calls Ghost_Round.
   --  @param Xs The state.
   --  @param Ki The round key.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_InvRound (Xs : Block; Ki : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_InvRound",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.InvRound, by its link name.
   --  @param Xs The state.
   --  @param Ki The round key.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure InvRound (Xs : Block; Ki : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvRound";
   --  Cryptol's foreign spark_InvRound :
   --  Block -> Block -> Block.
   --  Calls Ghost_InvRound.
   --  @param Xs The state.
   --  @param Ki The round key.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_InvRound_Prime (Xs : Block; Ki : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_InvRound_Prime",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.InvRound_Prime, by its link name.
   --  @param Xs The state.
   --  @param Ki The round key.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure InvRound_Prime (Xs : Block; Ki : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvRound_Prime";
   --  Cryptol's foreign spark_InvRound_Prime :
   --  Block -> Block -> Block.
   --  Calls Ghost_InvRound_Prime.
   --  @param Xs The state.
   --  @param Ki The round key.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_Cipher
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_Cipher",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.Cipher, by its link name.
   --  @param K The key size, Cryptol's {k}.
   --  @param W The round keys (the first Nr (K) + 1 blocks).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Cipher
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Cipher";
   --  Cryptol's foreign spark_Cipher :
   --  {k} (Key k) => [Nr k + 1]Block -> Block -> Block.
   --  Calls Ghost_Cipher.
   --  @param K The key size, Cryptol's {k}.
   --  @param W The round keys (the first Nr (K) + 1 blocks).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_InvCipher
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_InvCipher",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.InvCipher, by its link name.
   --  @param K The key size, Cryptol's {k}.
   --  @param W The round keys (the first Nr (K) + 1 blocks).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure InvCipher
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvCipher";
   --  Cryptol's foreign spark_InvCipher :
   --  {k} (Key k) => [Nr k + 1]Block -> Block -> Block.
   --  Calls Ghost_InvCipher.
   --  @param K The key size, Cryptol's {k}.
   --  @param W The round keys (the first Nr (K) + 1 blocks).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_InvCipher_Prime
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_InvCipher_Prime",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_Cipher.InvCipher_Prime, by its link name.
   --  @param K The key size, Cryptol's {k}.
   --  @param W The round keys (the first Nr (K) + 1 blocks).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure InvCipher_Prime
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvCipher_Prime";
   --  Cryptol's foreign spark_InvCipher_Prime :
   --  {k} (Key k) => [Nr k + 1]Block -> Block -> Block.
   --  Calls Ghost_InvCipher_Prime.
   --  @param K The key size, Cryptol's {k}.
   --  @param W The round keys (the first Nr (K) + 1 blocks).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

end Foundation_Spark.FFI.AES_Cipher_Exports;
