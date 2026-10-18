--  The ghost shims for algorithms/SHA2/Main.cry at SHA256.cry's parameters
--  (the spec's SHA2.SHA256 instance): step and hash, and hash over whole
--  bytes as the byte-level refinement SHA256_Bytes.Hash_Bytes states it,
--  exported with Cryptol's C calling convention. They are checked by
--  spark/cryptol/SPARK/SHA2/SHA256.cry.
--
--  step's [8][32] and [16][32] are pointers to 8 and 16 words. hash takes
--  an [l] of any length, which Cryptol's C calling convention cannot pass:
--  the Cryptol side passes split (M # zero) : [l /^ 8][8] with l as a
--  size_t, and the shim takes the first l bits back (SHA2_Types.Join_Bits),
--  so the bit-level spec is checked at every l, not only whole bytes. The
--  [256] digest comes back as [32][8] (SHA2_Types.Split_Digest). Hash_Bytes
--  takes [n][8], n as a size_t.
--
--  Ghost, because the spec layer, and Hash_Bytes, are;
--  SHA2_SHA256_Exports gives each the name Cryptol looks up (see
--  Foundation_Spark.FFI).

with Interfaces.C;
with Foundation_Spark.FFI.SHA2_Types;
with Foundation_Spark.SHA2.SHA256;
with Foundation_Spark.SHA2.SHA256_Bytes;

package Foundation_Spark.FFI.SHA2_SHA256 with
  SPARK_Mode,
  Ghost
is

   use type SHA2.Words_32;
   use type SHA2.SHA256_Bytes.Byte_Array;
   use type Interfaces.C.size_t;
   use Foundation_Spark.FFI.SHA2_Types;

   procedure Step
     (H      : SHA2.SHA256.Hash_Value;
      B      : SHA2.SHA256.Block;
      Output : out SHA2.SHA256.Hash_Value)
   with
     Export,
     Convention    => C,
     External_Name => "spark_step",
     Post          => Output = SHA2.SHA256.Step (H, B);
   --  Main.cry's step at SHA256.cry's parameters, as the spec's
   --  SHA256.Step states it.
   --  @param H The hash value.
   --  @param B The message block.
   --  @param Output The next hash value, written through Cryptol's output
   --  pointer.

   procedure Hash
     (L      : C_Size;
      M      : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   with
     Export,
     Convention    => C,
     External_Name => "spark_hash",
     Pre           => L <= 8 * Max_Buffer_Bytes,
     Post          =>
       Output = Split_Digest (SHA2.SHA256.Hash (Join_Bits (L, M)));
   --  Main.cry's hash at SHA256.cry's parameters (SHA256::hash), as the
   --  spec's SHA256.Hash states it over bits, with the message and digest
   --  passed as bytes.
   --  @param L The message length in bits, Cryptol's {l}.
   --  @param M The message as bytes: the first L /^ 8 are read.
   --  @param Output The digest, written through Cryptol's output pointer.

   procedure Hash_Bytes
     (N      : C_Size;
      M      : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Hash_Bytes",
     Pre           => N <= Max_Buffer_Bytes,
     Post          =>
       Output = SHA2.SHA256_Bytes.Hash_Bytes (Prefix (N, M));
   --  SHA256::hash over whole bytes, as the byte-level refinement
   --  SHA256_Bytes.Hash_Bytes states it.
   --  @param N The message length in bytes, Cryptol's {n}.
   --  @param M The message: the first N bytes are read.
   --  @param Output The digest, written through Cryptol's output pointer.

end Foundation_Spark.FFI.SHA2_SHA256;
