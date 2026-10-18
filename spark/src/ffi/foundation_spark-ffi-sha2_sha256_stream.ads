--  The exports Cryptol calls for the executable SHA-256,
--  SHA2.SHA256_Stream: the compression Compress (step), the one-shot
--  Hash, and Init, Update for each chunk of a chunking, and Final
--  (SHA256_Stream.Hash_Chunked). They are checked against SHA256.cry's
--  step (Main.cry's, at its parameters) and hash (SHA256::hash) by
--  spark/cryptol/SPARK/SHA2/SHA256.cry. Load_Block, the parse of one
--  block, is checked against Preprocessing.cry's parse by
--  spark/cryptol/SPARK/SHA2/Preprocessing.cry.
--
--  The implementation is not ghost, so these need no ghost shim: they call
--  it directly, and their names are the ones Cryptol looks up. A message
--  is [n][8] (n as a size_t, then a pointer to its bytes) and a chunking is
--  [c][64], the ends of its chunks (c as a size_t, then a pointer to c
--  64-bit words); both are typed at their maximum (SHA2_Types) and only
--  the caller's prefix is read.

with Interfaces.C;
with Interfaces;
with Foundation_Spark.FFI.SHA2_Types;
with Foundation_Spark.SHA2.SHA256;
with Foundation_Spark.SHA2.SHA256_Bytes;

package Foundation_Spark.FFI.SHA2_SHA256_Stream with
  SPARK_Mode
is

   use type Interfaces.Unsigned_64;
   use type Interfaces.C.size_t;
   use Foundation_Spark.FFI.SHA2_Types;

   procedure Compress
     (H      : SHA2.SHA256.Hash_Value;
      B      : SHA2.SHA256.Block;
      Output : out SHA2.SHA256.Hash_Value)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Compress";
   --  Cryptol's foreign spark_Compress : [8][32] -> [16][32] -> [8][32].
   --  The executable SHA256_Stream.Compress, proved equal to the spec's
   --  SHA256.Step, applied to a copy of H.
   --  @param H The hash value.
   --  @param B The message block.
   --  @param Output The next hash value, written through Cryptol's output
   --  pointer.

   procedure Load_Block
     (B : Key_Block_Bytes; Output : out SHA2.SHA256.Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Load_Block";
   --  Cryptol's foreign spark_Load_Block : [64][8] -> [16][32]. The
   --  executable SHA256_Stream.Load_Block of B, proved equal to the spec's
   --  Parse of B's bits at N = 1.
   --  @param B The 64 bytes of a block.
   --  @param Output The block's 16 words, written through Cryptol's output
   --  pointer.

   procedure Hash
     (N      : C_Size;
      M      : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Stream_Hash",
     Pre           => N <= Max_Buffer_Bytes;
   --  Cryptol's foreign spark_Stream_Hash :
   --  {n} (fin n, 61 >= width n) => [n][8] -> [32][8]. The executable
   --  SHA256_Stream.Hash (Init, one Update, Final) of the first N bytes
   --  of M.
   --  @param N The message length in bytes, Cryptol's {n}.
   --  @param M The message: the first N bytes are read.
   --  @param Output The digest, written through Cryptol's output pointer.

   procedure Hash_Chunked
     (N      : C_Size;
      C      : C_Size;
      M      : Byte_Buffer;
      Cuts   : Cut_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Stream_Hash_Chunked",
     Pre           => N <= Max_Buffer_Bytes and then Is_Chunking (N, C, Cuts);
   --  Cryptol's foreign spark_Stream_Hash_Chunked :
   --  {n, c} (fin n, 61 >= width n, fin c, 64 >= c) =>
   --  [n][8] -> [c][64] -> [32][8]. The executable SHA256_Stream's Init,
   --  then Update on each chunk of the first N bytes of M as Cuts cuts
   --  them (the last chunk running to N), then Final: that is
   --  SHA256_Stream.Hash_Chunked.
   --  @param N The message length in bytes, Cryptol's {n}.
   --  @param C The number of cut points, Cryptol's {c}.
   --  @param M The message: the first N bytes are read.
   --  @param Cuts The ends of the chunks: the first C are read.
   --  @param Output The digest, written through Cryptol's output pointer.

end Foundation_Spark.FFI.SHA2_SHA256_Stream;
