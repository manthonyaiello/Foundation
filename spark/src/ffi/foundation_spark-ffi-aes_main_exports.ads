--  The exports Cryptol calls for algorithms/AES/Main.cry: spark_<Name>
--  for each ghost shim in AES_Main, the names that
--  spark/cryptol/SPARK/AES/Main.cry declares foreign. Each calls its
--  shim through an Import of the shim's link name,
--  Ghost_Link_Prefix & its External_Name (see Foundation_Spark.FFI and
--  AES_GF28_Exports). Each Ghost_<Name> Import has Global => null, which
--  is what the shim's own (proved) Global is: it reads no state.

with Foundation_Spark.AES.Spec.Types;
with Foundation_Spark.FFI.AES_Types;

package Foundation_Spark.FFI.AES_Main_Exports with
  SPARK_Mode
is

   use Foundation_Spark.AES.Spec.Types;
   use Foundation_Spark.FFI.AES_Types;

   procedure Ghost_Encrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_Encrypt",
     Global        => null;
   --  The ghost shim AES_Main.Encrypt, by its link name.
   --  @param K The key size, Cryptol's {k}.
   --  @param Key The key as bytes (the first K / 8).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Encrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Encrypt";
   --  Cryptol's foreign spark_Encrypt :
   --  {k} (Key k) => [k / 8][8] -> [16][8] -> [16][8].
   --  Calls Ghost_Encrypt.
   --  @param K The key size, Cryptol's {k}.
   --  @param Key The key as bytes (the first K / 8).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_Decrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_Decrypt",
     Global        => null;
   --  The ghost shim AES_Main.Decrypt, by its link name.
   --  @param K The key size, Cryptol's {k}.
   --  @param Key The key as bytes (the first K / 8).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Decrypt
     (K : C_Size; Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Decrypt";
   --  Cryptol's foreign spark_Decrypt :
   --  {k} (Key k) => [k / 8][8] -> [16][8] -> [16][8].
   --  Calls Ghost_Decrypt.
   --  @param K The key size, Cryptol's {k}.
   --  @param Key The key as bytes (the first K / 8).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_AES128_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_AES128_Encrypt",
     Global        => null;
   --  The ghost shim AES_Main.AES128_Encrypt, by its link name.
   --  @param Key The key as bytes (the first 16).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure AES128_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AES128_Encrypt";
   --  Cryptol's foreign spark_AES128_Encrypt :
   --  [16][8] -> [16][8] -> [16][8].
   --  Calls Ghost_AES128_Encrypt.
   --  @param Key The key as bytes (the first 16).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_AES128_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_AES128_Decrypt",
     Global        => null;
   --  The ghost shim AES_Main.AES128_Decrypt, by its link name.
   --  @param Key The key as bytes (the first 16).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure AES128_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AES128_Decrypt";
   --  Cryptol's foreign spark_AES128_Decrypt :
   --  [16][8] -> [16][8] -> [16][8].
   --  Calls Ghost_AES128_Decrypt.
   --  @param Key The key as bytes (the first 16).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_AES192_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_AES192_Encrypt",
     Global        => null;
   --  The ghost shim AES_Main.AES192_Encrypt, by its link name.
   --  @param Key The key as bytes (the first 24).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure AES192_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AES192_Encrypt";
   --  Cryptol's foreign spark_AES192_Encrypt :
   --  [24][8] -> [16][8] -> [16][8].
   --  Calls Ghost_AES192_Encrypt.
   --  @param Key The key as bytes (the first 24).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_AES192_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_AES192_Decrypt",
     Global        => null;
   --  The ghost shim AES_Main.AES192_Decrypt, by its link name.
   --  @param Key The key as bytes (the first 24).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure AES192_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AES192_Decrypt";
   --  Cryptol's foreign spark_AES192_Decrypt :
   --  [24][8] -> [16][8] -> [16][8].
   --  Calls Ghost_AES192_Decrypt.
   --  @param Key The key as bytes (the first 24).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_AES256_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_AES256_Encrypt",
     Global        => null;
   --  The ghost shim AES_Main.AES256_Encrypt, by its link name.
   --  @param Key The key as bytes (the first 32).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure AES256_Encrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AES256_Encrypt";
   --  Cryptol's foreign spark_AES256_Encrypt :
   --  [32][8] -> [16][8] -> [16][8].
   --  Calls Ghost_AES256_Encrypt.
   --  @param Key The key as bytes (the first 32).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_AES256_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_AES256_Decrypt",
     Global        => null;
   --  The ghost shim AES_Main.AES256_Decrypt, by its link name.
   --  @param Key The key as bytes (the first 32).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure AES256_Decrypt
     (Key : Key_Bytes; Input : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_AES256_Decrypt";
   --  Cryptol's foreign spark_AES256_Decrypt :
   --  [32][8] -> [16][8] -> [16][8].
   --  Calls Ghost_AES256_Decrypt.
   --  @param Key The key as bytes (the first 32).
   --  @param Input The block.
   --  @param Output The result, written through Cryptol's output pointer.

end Foundation_Spark.FFI.AES_Main_Exports;
