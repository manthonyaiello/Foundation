--  The exports Cryptol calls for the SHA-256 instance of
--  algorithms/SHA2/Main.cry and its byte-level refinement: spark_<Name> for
--  each ghost shim in SHA2_SHA256, the names that
--  spark/cryptol/SPARK/SHA2/SHA256.cry declares foreign.
--  Each calls its shim through an Import of the shim's link name,
--  Ghost_Link_Prefix & its External_Name (see Foundation_Spark.FFI and
--  AES_GF28_Exports). Each Ghost_<Name> Import has Global => null, which
--  is what the shim's own (proved) Global is: it reads no state; and
--  Always_Terminates, since the shim is one call of a spec function,
--  whose recursion gnatprove proves terminates (Subprogram_Variant), or a
--  loop over a bounded range.

with Foundation_Spark.FFI.SHA2_Types;
with Foundation_Spark.SHA2.SHA256;
with Foundation_Spark.SHA2.SHA256_Bytes;

package Foundation_Spark.FFI.SHA2_SHA256_Exports with
  SPARK_Mode
is

   use Foundation_Spark.FFI.SHA2_Types;

   procedure Ghost_Step
     (H : SHA2.SHA256.Hash_Value;
      B : SHA2.SHA256.Block;
      Output : out SHA2.SHA256.Hash_Value)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_step",
     Global        => null,
     Always_Terminates;
   --  The ghost shim SHA2_SHA256.Step, by its link name.
   --  @param H The hash value.
   --  @param B The message block.
   --  @param Output The next hash value, written through Cryptol's output
   --  pointer.

   procedure Step
     (H : SHA2.SHA256.Hash_Value;
      B : SHA2.SHA256.Block;
      Output : out SHA2.SHA256.Hash_Value)
   with
     Export,
     Convention    => C,
     External_Name => "spark_step";
   --  Cryptol's foreign spark_step :
   --  [8][32] -> [16][32] -> [8][32].
   --  Calls Ghost_Step.
   --  @param H The hash value.
   --  @param B The message block.
   --  @param Output The next hash value, written through Cryptol's output
   --  pointer.

   procedure Ghost_Hash
     (L : C_Size;
      M : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_hash",
     Global        => null,
     Always_Terminates;
   --  The ghost shim SHA2_SHA256.Hash, by its link name.
   --  @param L The message length in bits, Cryptol's {l}.
   --  @param M The message as bytes (the first L /^ 8).
   --  @param Output The digest, written through Cryptol's output pointer.

   procedure Hash
     (L : C_Size;
      M : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   with
     Export,
     Convention    => C,
     External_Name => "spark_hash";
   --  Cryptol's foreign spark_hash :
   --  {l} (fin l, 64 >= width l) => [l /^ 8][8] -> [32][8].
   --  Calls Ghost_Hash.
   --  @param L The message length in bits, Cryptol's {l}.
   --  @param M The message as bytes (the first L /^ 8).
   --  @param Output The digest, written through Cryptol's output pointer.

   procedure Ghost_Hash_Bytes
     (N : C_Size;
      M : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_Hash_Bytes",
     Global        => null,
     Always_Terminates;
   --  The ghost shim SHA2_SHA256.Hash_Bytes, by its link name.
   --  @param N The message length in bytes, Cryptol's {n}.
   --  @param M The message (the first N bytes).
   --  @param Output The digest, written through Cryptol's output pointer.

   procedure Hash_Bytes
     (N : C_Size;
      M : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Hash_Bytes";
   --  Cryptol's foreign spark_Hash_Bytes :
   --  {n} (fin n, 61 >= width n) => [n][8] -> [32][8].
   --  Calls Ghost_Hash_Bytes.
   --  @param N The message length in bytes, Cryptol's {n}.
   --  @param M The message (the first N bytes).
   --  @param Output The digest, written through Cryptol's output pointer.

end Foundation_Spark.FFI.SHA2_SHA256_Exports;
