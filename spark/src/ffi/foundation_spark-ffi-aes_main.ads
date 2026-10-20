--  The ghost shims for algorithms/AES/Main.cry: the spec's Encrypt and
--  Decrypt, and the AES128, AES192 and AES256 instances of each, exported
--  with Cryptol's C calling convention (Foundation_Spark.FFI.AES_Types).
--  They are checked by spark/cryptol/SPARK/AES/Main.cry.
--
--  Main.cry's Encrypt and Decrypt take a [k] key and a [128] block, and
--  Cryptol's C calling convention cannot pass either (spark/README.md,
--  "Passing bit sequences"). So the Cryptol side passes them as bytes,
--  split key : [k / 8][8] and split in : [16][8], and joins the result; the
--  shims turn the bytes into the spec's bit sequences (Join_Key, and the
--  spec's own Join_Block) and its result back into bytes (the spec's
--  Split_Block). Both conversions are Cryptol's big-endian split and join,
--  and the FFI check runs them with the spec function.
--
--  Encrypt and Decrypt take Cryptol's {k} as K and serve all three key
--  sizes; the AES<n>_ shims are the instances, at a fixed key size.
--
--  Ghost, because the spec layer is; AES_Main_Exports gives each the name
--  Cryptol looks up (see Foundation_Spark.FFI).

with Interfaces.C;
with Foundation_Spark.AES.Spec.Main;
with Foundation_Spark.AES.Spec.Types;
with Foundation_Spark.FFI.AES_Types;

package Foundation_Spark.FFI.AES_Main with
  SPARK_Mode,
  Ghost
is

   use Foundation_Spark.AES.Spec.Main;
   use Foundation_Spark.AES.Spec.Types;
   use Foundation_Spark.FFI.AES_Types;

   use type Interfaces.C.size_t;

   function Join_Key_128 (Key : Key_Bytes) return AES128.Key_Bits
   is [for N in AES128.Key_Bits'Range =>
         Bit_Of (Key (Natural (N / 8)), Natural (N mod 8))];
   --  Cryptol's join at type [16][8] -> [128], on the first 16 bytes of
   --  Key: bit N is bit N mod 8 of byte N / 8, most significant first.
   --  @param Key The key bytes.
   --  @return Their 128 bits.

   function Join_Key_192 (Key : Key_Bytes) return AES192.Key_Bits
   is [for N in AES192.Key_Bits'Range =>
         Bit_Of (Key (Natural (N / 8)), Natural (N mod 8))];
   --  Cryptol's join at type [24][8] -> [192], on the first 24 bytes of
   --  Key, as Join_Key_128.
   --  @param Key The key bytes.
   --  @return Their 192 bits.

   function Join_Key_256 (Key : Key_Bytes) return AES256.Key_Bits
   is [for N in AES256.Key_Bits'Range =>
         Bit_Of (Key (Natural (N / 8)), Natural (N mod 8))];
   --  Cryptol's join at type [32][8] -> [256], on the 32 bytes of Key, as
   --  Join_Key_128.
   --  @param Key The key bytes.
   --  @return Their 256 bits.

   function Join_Key (K : C_Size; Key : Key_Bytes) return Bits
   is (if K = 128 then Join_Key_128 (Key)
       elsif K = 192 then Join_Key_192 (Key)
       else Join_Key_256 (Key))
   with
     Pre  => Is_Key_Size (K),
     Post => Is_Key_Bits (Key_Size_Of (K), Join_Key'Result);
   --  Cryptol's join at type [k / 8][8] -> [k], for k = K, on the first
   --  K / 8 bytes of Key.
   --  @param K The key size, Cryptol's {k}.
   --  @param Key The key bytes.
   --  @return The K bits of the key.

   procedure Encrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Encrypt",
     Pre           => Is_Key_Size (K),
     Post          =>
       Output = Split_Block
                  (Foundation_Spark.AES.Spec.Main.Encrypt
                     (Key_Size_Of (K), Join_Key (K, Key), Join_Block (Input)));
   --  Main.cry's AES`{k}.Encrypt, as the spec states it, for k = K, over
   --  bytes.
   --  @param K The key size, Cryptol's {k}.
   --  @param Key The key, split into bytes: the first K / 8 are read.
   --  @param Input The plaintext block, split into bytes.
   --  @param Output The spec's Encrypt of the joined key and block, split
   --  into bytes.

   procedure Decrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Decrypt",
     Pre           => Is_Key_Size (K),
     Post          =>
       Output = Split_Block
                  (Foundation_Spark.AES.Spec.Main.Decrypt
                     (Key_Size_Of (K), Join_Key (K, Key), Join_Block (Input)));
   --  Main.cry's AES`{k}.Decrypt, as the spec states it, for k = K, over
   --  bytes.
   --  @param K The key size, Cryptol's {k}.
   --  @param Key The key, split into bytes: the first K / 8 are read.
   --  @param Input The ciphertext block, split into bytes.
   --  @param Output The spec's Decrypt of the joined key and block, split
   --  into bytes.

   procedure AES128_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AES128_Encrypt",
     Post          =>
       Output = Split_Block
                  (AES128.Encrypt (Join_Key_128 (Key), Join_Block (Input)));
   --  Main.cry's AES128.Encrypt, as the spec states it, over bytes.
   --  @param Key The key, split into bytes: the first 16 are read.
   --  @param Input The plaintext block, split into bytes.
   --  @param Output The spec's AES128.Encrypt, split into bytes.

   procedure AES128_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AES128_Decrypt",
     Post          =>
       Output = Split_Block
                  (AES128.Decrypt (Join_Key_128 (Key), Join_Block (Input)));
   --  Main.cry's AES128.Decrypt, as the spec states it, over bytes.
   --  @param Key The key, split into bytes: the first 16 are read.
   --  @param Input The ciphertext block, split into bytes.
   --  @param Output The spec's AES128.Decrypt, split into bytes.

   procedure AES192_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AES192_Encrypt",
     Post          =>
       Output = Split_Block
                  (AES192.Encrypt (Join_Key_192 (Key), Join_Block (Input)));
   --  Main.cry's AES192.Encrypt, as the spec states it, over bytes.
   --  @param Key The key, split into bytes: the first 24 are read.
   --  @param Input The plaintext block, split into bytes.
   --  @param Output The spec's AES192.Encrypt, split into bytes.

   procedure AES192_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AES192_Decrypt",
     Post          =>
       Output = Split_Block
                  (AES192.Decrypt (Join_Key_192 (Key), Join_Block (Input)));
   --  Main.cry's AES192.Decrypt, as the spec states it, over bytes.
   --  @param Key The key, split into bytes: the first 24 are read.
   --  @param Input The ciphertext block, split into bytes.
   --  @param Output The spec's AES192.Decrypt, split into bytes.

   procedure AES256_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AES256_Encrypt",
     Post          =>
       Output = Split_Block
                  (AES256.Encrypt (Join_Key_256 (Key), Join_Block (Input)));
   --  Main.cry's AES256.Encrypt, as the spec states it, over bytes.
   --  @param Key The key, split into bytes: all 32 are read.
   --  @param Input The plaintext block, split into bytes.
   --  @param Output The spec's AES256.Encrypt, split into bytes.

   procedure AES256_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AES256_Decrypt",
     Post          =>
       Output = Split_Block
                  (AES256.Decrypt (Join_Key_256 (Key), Join_Block (Input)));
   --  Main.cry's AES256.Decrypt, as the spec states it, over bytes.
   --  @param Key The key, split into bytes: all 32 are read.
   --  @param Input The ciphertext block, split into bytes.
   --  @param Output The spec's AES256.Decrypt, split into bytes.

end Foundation_Spark.FFI.AES_Main;
