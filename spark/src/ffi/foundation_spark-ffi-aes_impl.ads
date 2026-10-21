--  The exports Cryptol calls for the executable AES, AES.Impl: the key
--  schedule Expand_Key, and Encrypt_Block, Decrypt_Block and
--  Decrypt_Block_Prime of one block, AES.Impl.Main's Encrypt and
--  Decrypt of a key and a block, the multiplication Dot, and the
--  constant-time leaves of issue #50 (X_Times, Sub_Byte, Inv_Sub_Byte,
--  Sub_Bytes, Inv_Sub_Bytes, Sub_Word). They are checked against
--  KeyExpansion.cry's KeyExpansion and SubWord and Cipher.cry's Cipher,
--  InvCipher, InvCipher', SubBytes and InvSubBytes by spark/cryptol/SPARK/
--  AES/KeyExpansion.cry and spark/cryptol/SPARK/AES/Cipher.cry, against
--  Main.cry's Encrypt and Decrypt by spark/cryptol/SPARK/AES/Main.cry,
--  against GF28.cry's (•) and xTimes by spark/cryptol/SPARK/AES/GF28.cry,
--  and against SBox.cry's SBox and InvSBox by spark/cryptol/SPARK/AES/
--  SBox.cry.
--
--  The implementation is not ghost, so these need no ghost shim: they call
--  it directly, and their names are the ones Cryptol looks up. They take
--  the C shapes of the spec layer's shims (Foundation_Spark.FFI.AES_Types):
--  Cryptol's {k} as K, a [Nk k]AESWord key typed at Max_Nk words and a
--  [Nr k + 1]Block schedule typed at Max_Nr + 1 blocks, of which only the
--  first Nk (K) or Nr (K) + 1 are read or written, and a Block result
--  written through the pointer Cryptol passes after the arguments.
--  foundation_spark_ffi.gpr builds this unit and AES.Impl as a client
--  would, with ghost code and assertions ignored.

with Foundation_Spark.AES.Spec.Types;
with Foundation_Spark.FFI.AES_Types;

package Foundation_Spark.FFI.AES_Impl with
  SPARK_Mode
is

   use Foundation_Spark.AES.Spec.Types;
   use Foundation_Spark.FFI.AES_Types;

   procedure Expand_Key
     (K : C_Size; Key : All_Key_Words; Output : in out All_Round_Keys)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Expand_Key",
     Pre           => Is_Key_Size (K);
   --  Cryptol's foreign spark_Expand_Key :
   --  {k} (Key k) => [Nk k]AESWord -> [Nr k + 1]Block. The executable
   --  AES.Impl.Expand_Key, proved equal to the spec's KeyExpansion, of the
   --  first Nk (K) words of Key, into the first Nr (K) + 1 blocks of
   --  Output; the rest of Output is not written (hence in out).
   --  @param K The key size, Cryptol's {k}.
   --  @param Key The key words: the first Nk (K) are read.
   --  @param Output The round keys, in its first Nr (K) + 1 blocks.

   procedure Encrypt_Block
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Encrypt_Block",
     Pre           => Is_Key_Size (K);
   --  Cryptol's foreign spark_Encrypt_Block :
   --  {k} (Key k) => [Nr k + 1]Block -> Block -> Block. The executable
   --  AES.Impl.Encrypt_Block, proved equal to the spec's Cipher, under the
   --  first Nr (K) + 1 blocks of W, applied to a copy of Input.
   --  @param K The key size, Cryptol's {k}.
   --  @param W The round keys: the first Nr (K) + 1 are read.
   --  @param Input The plaintext block.
   --  @param Output The ciphertext block, written through Cryptol's output
   --  pointer.

   procedure Decrypt_Block
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Decrypt_Block",
     Pre           => Is_Key_Size (K);
   --  Cryptol's foreign spark_Decrypt_Block :
   --  {k} (Key k) => [Nr k + 1]Block -> Block -> Block. The executable
   --  AES.Impl.Decrypt_Block, proved equal to the spec's InvCipher, under
   --  the first Nr (K) + 1 blocks of W, applied to a copy of Input.
   --  @param K The key size, Cryptol's {k}.
   --  @param W The round keys: the first Nr (K) + 1 are read.
   --  @param Input The ciphertext block.
   --  @param Output The plaintext block, written through Cryptol's output
   --  pointer.

   procedure Decrypt_Block_Prime
     (K : C_Size; W : All_Round_Keys; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Decrypt_Block_Prime",
     Pre           => Is_Key_Size (K);
   --  Cryptol's foreign spark_Decrypt_Block_Prime :
   --  {k} (Key k) => [Nr k + 1]Block -> Block -> Block. The executable
   --  AES.Impl.Decrypt_Block_Prime, proved equal to the spec's InvCipher',
   --  under the first Nr (K) + 1 blocks of W, applied to a copy of Input.
   --  @param K The key size, Cryptol's {k}.
   --  @param W The round keys: the first Nr (K) + 1 are read.
   --  @param Input The ciphertext block.
   --  @param Output The plaintext block, written through Cryptol's output
   --  pointer.

   procedure Encrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Impl_Encrypt",
     Pre           => Is_Key_Size (K);
   --  Cryptol's foreign spark_Impl_Encrypt :
   --  {k} (Key k) => [k / 8][8] -> [16][8] -> [16][8]. The executable
   --  AES.Impl.Main.Encrypt, proved equal on the bits to Main.cry's
   --  AES`{k}.Encrypt, under the first K / 8 bytes of Key.
   --  @param K The key size, Cryptol's {k}.
   --  @param Key The key bytes: the first K / 8 are read.
   --  @param Input The plaintext block.
   --  @param Output The ciphertext block, written through Cryptol's output
   --  pointer.

   procedure Decrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Impl_Decrypt",
     Pre           => Is_Key_Size (K);
   --  Cryptol's foreign spark_Impl_Decrypt :
   --  {k} (Key k) => [k / 8][8] -> [16][8] -> [16][8]. The executable
   --  AES.Impl.Main.Decrypt, proved equal on the bits to Main.cry's
   --  AES`{k}.Decrypt, under the first K / 8 bytes of Key.
   --  @param K The key size, Cryptol's {k}.
   --  @param Key The key bytes: the first K / 8 are read.
   --  @param Input The ciphertext block.
   --  @param Output The plaintext block, written through Cryptol's output
   --  pointer.

   function Dot (B, C : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_Impl_Dot";
   --  Cryptol's foreign spark_Impl_Dot : [8] -> [8] -> [8]. The executable
   --  AES.Impl.Dot, proved equal to the spec's Dot. The ciphers do not call
   --  it (they multiply by X_Times), so no other property runs it: the
   --  coverage of the FFI properties (#49) found it never executed.
   --  @param B The first factor.
   --  @param C The second factor.
   --  @return AES.Impl.Dot (B, C).

   function X_Times (B : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_Impl_xTimes";
   --  Cryptol's foreign spark_Impl_xTimes : [8] -> [8]. The executable
   --  AES.Impl.X_Times (masked, issue #50), proved equal to the spec's
   --  xTimes.
   --  @param B The byte.
   --  @return AES.Impl.X_Times (B).

   function Sub_Byte (B : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_Impl_SBox";
   --  Cryptol's foreign spark_Impl_SBox : [8] -> [8]. The executable
   --  AES.Impl.Sub_Byte (the bitsliced circuit, issue #50), proved equal
   --  to the spec's SBox table.
   --  @param B The byte.
   --  @return AES.Impl.Sub_Byte (B).

   function Inv_Sub_Byte (B : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_Impl_InvSBox";
   --  Cryptol's foreign spark_Impl_InvSBox : [8] -> [8]. The executable
   --  AES.Impl.Inv_Sub_Byte (issue #50), proved equal to the spec's
   --  InvSBox table.
   --  @param B The byte.
   --  @return AES.Impl.Inv_Sub_Byte (B).

   procedure Sub_Bytes (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Impl_SubBytes";
   --  Cryptol's foreign spark_Impl_SubBytes : Block -> Block. The
   --  executable AES.Impl.Sub_Bytes (the circuit on two words of eight
   --  lanes, issue #50), proved equal to the spec's SubBytes, applied to a
   --  copy of Bs.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Inv_Sub_Bytes (Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Impl_InvSubBytes";
   --  Cryptol's foreign spark_Impl_InvSubBytes : Block -> Block. The
   --  executable AES.Impl.Inv_Sub_Bytes (issue #50), proved equal to the
   --  spec's InvSubBytes, applied to a copy of Bs.
   --  @param Bs The state.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Sub_Word (A : AESWord; Output : out AESWord)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Impl_SubWord";
   --  Cryptol's foreign spark_Impl_SubWord : AESWord -> AESWord. The
   --  executable AES.Impl.Sub_Word (four lanes of the circuit, issue
   --  #50), proved equal to the spec's SubWord.
   --  @param A The word.
   --  @param Output The result, written through Cryptol's output pointer.

end Foundation_Spark.FFI.AES_Impl;
