--  The exports Cryptol calls for algorithms/HMAC/Main.cry at SHA-256
--  (packaging/Hash.cry's HMAC in algorithms/SHA2/SHA256.cry): spark_<Name>
--  for each ghost shim in HMAC_SHA256, the names that
--  spark/cryptol/SPARK/HMAC/SHA256.cry declares foreign.
--  Each calls its shim through an Import of the shim's link name,
--  Ghost_Link_Prefix & its External_Name (see Foundation_Spark.FFI and
--  AES_GF28_Exports). Each Ghost_<Name> Import has Global => null, which
--  is what the shim's own (proved) Global is: it reads no state; and
--  Always_Terminates, since the shim is one call of a spec function,
--  whose recursion gnatprove proves terminates (Subprogram_Variant), or a
--  loop over a bounded range.

with Foundation_Spark.FFI.SHA2_Types;
with Foundation_Spark.SHA2.SHA256_Bytes;

package Foundation_Spark.FFI.HMAC_SHA256_Exports with
  SPARK_Mode
is

   use Foundation_Spark.FFI.SHA2_Types;

   procedure Ghost_HMAC
     (K : C_Size;
      N : C_Size;
      Key : Byte_Buffer;
      Text : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_HMAC",
     Global        => null,
     Always_Terminates;
   --  The ghost shim HMAC_SHA256.HMAC, by its link name.
   --  @param K The key length in bytes, Cryptol's {k}.
   --  @param N The text length in bits, Cryptol's {n}.
   --  @param Key The key (the first K bytes).
   --  @param Text The text as bytes (the first N /^ 8).
   --  @param Output The digest, written through Cryptol's output pointer.

   procedure HMAC
     (K : C_Size;
      N : C_Size;
      Key : Byte_Buffer;
      Text : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   with
     Export,
     Convention    => C,
     External_Name => "spark_HMAC";
   --  Cryptol's foreign spark_HMAC :
   --  {k, n} (fin k, 61 >= width k, fin n, 64 >= width n) =>
   --  [k][8] -> [n /^ 8][8] -> [32][8].
   --  Calls Ghost_HMAC.
   --  @param K The key length in bytes, Cryptol's {k}.
   --  @param N The text length in bits, Cryptol's {n}.
   --  @param Key The key (the first K bytes).
   --  @param Text The text as bytes (the first N /^ 8).
   --  @param Output The digest, written through Cryptol's output pointer.

   procedure Ghost_HMAC_init
     (K : C_Size;
      Key : Byte_Buffer;
      Output : out Key_Block_Bytes)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_HMAC_init",
     Global        => null,
     Always_Terminates;
   --  The ghost shim HMAC_SHA256.HMAC_init, by its link name.
   --  @param K The key length in bytes, Cryptol's {k}.
   --  @param Key The key (the first K bytes).
   --  @param Output K0 as 64 bytes, written through Cryptol's output pointer.

   procedure HMAC_init
     (K : C_Size;
      Key : Byte_Buffer;
      Output : out Key_Block_Bytes)
   with
     Export,
     Convention    => C,
     External_Name => "spark_HMAC_init";
   --  Cryptol's foreign spark_HMAC_init :
   --  {k} (fin k, 61 >= width k) => [k][8] -> [64][8].
   --  Calls Ghost_HMAC_init.
   --  @param K The key length in bytes, Cryptol's {k}.
   --  @param Key The key (the first K bytes).
   --  @param Output K0 as 64 bytes, written through Cryptol's output pointer.

end Foundation_Spark.FFI.HMAC_SHA256_Exports;
