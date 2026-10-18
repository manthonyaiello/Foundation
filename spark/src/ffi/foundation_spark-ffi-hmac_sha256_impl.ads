--  The exports Cryptol calls for the executable HMAC-SHA-256,
--  HMAC.SHA256_Impl: the one-shot HMAC_SHA256, Init_Key (K0), and the
--  incremental Init, Update for each chunk of a chunking, and Final. They
--  are checked against SHA256.cry's HMAC (SHA256::HMAC) by
--  spark/cryptol/SPARK/HMAC/SHA256.cry.
--
--  The implementation is not ghost, so these need no ghost shim: they call
--  it directly, and their names are the ones Cryptol looks up. A key or a
--  text is [n][8] (n as a size_t, then a pointer to its bytes) and a
--  chunking is [c][64], the ends of its chunks (c as a size_t, then a
--  pointer to c 64-bit words); each is typed at its maximum (SHA2_Types)
--  and only the caller's prefix is read. foundation_spark_ffi.gpr builds
--  this unit and SHA256_Impl as a client would, with ghost code and
--  assertions ignored.

with Interfaces.C;
with Foundation_Spark.FFI.SHA2_Types;
with Foundation_Spark.SHA2.SHA256_Bytes;

package Foundation_Spark.FFI.HMAC_SHA256_Impl with
  SPARK_Mode
is

   use type Interfaces.C.size_t;
   use Foundation_Spark.FFI.SHA2_Types;

   procedure HMAC_SHA256
     (K      : C_Size;
      N      : C_Size;
      Key    : Byte_Buffer;
      Text   : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   with
     Export,
     Convention    => C,
     External_Name => "spark_HMAC_SHA256",
     Pre           => K <= Max_Buffer_Bytes and then N <= Max_Buffer_Bytes;
   --  Cryptol's foreign spark_HMAC_SHA256 :
   --  {k, n} (fin k, fin n, ...) => [k][8] -> [n][8] -> [32][8]. The
   --  executable SHA256_Impl.HMAC_SHA256 of the first K bytes of Key and
   --  the first N bytes of Text.
   --  @param K The key length in bytes, Cryptol's {k}.
   --  @param N The text length in bytes, Cryptol's {n}.
   --  @param Key The key: the first K bytes are read.
   --  @param Text The text: the first N bytes are read.
   --  @param Output The MAC, written through Cryptol's output pointer.

   procedure Init_Key
     (K      : C_Size;
      Key    : Byte_Buffer;
      Output : out Key_Block_Bytes)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Init_Key",
     Pre           => K <= Max_Buffer_Bytes;
   --  Cryptol's foreign spark_Init_Key :
   --  {k} (fin k, ...) => [k][8] -> [64][8]. The executable
   --  SHA256_Impl.Init_Key, K0, of the first K bytes of Key.
   --  @param K The key length in bytes, Cryptol's {k}.
   --  @param Key The key: the first K bytes are read.
   --  @param Output K0, written through Cryptol's output pointer.

   procedure HMAC_Chunked
     (K      : C_Size;
      N      : C_Size;
      C      : C_Size;
      Key    : Byte_Buffer;
      Text   : Byte_Buffer;
      Cuts   : Cut_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   with
     Export,
     Convention    => C,
     External_Name => "spark_HMAC_SHA256_Chunked",
     Pre           =>
       K <= Max_Buffer_Bytes
       and then N <= Max_Buffer_Bytes
       and then Is_Chunking (N, C, Cuts);
   --  Cryptol's foreign spark_HMAC_SHA256_Chunked :
   --  {k, n, c} (fin k, fin n, fin c, 64 >= c, ...) =>
   --  [k][8] -> [n][8] -> [c][64] -> [32][8]. The executable SHA256_Impl's
   --  Init with the first K bytes of Key, then Update on each chunk of the
   --  first N bytes of Text as Cuts cuts them (a last chunk running to N),
   --  then Final.
   --  @param K The key length in bytes, Cryptol's {k}.
   --  @param N The text length in bytes, Cryptol's {n}.
   --  @param C The number of cut points, Cryptol's {c}.
   --  @param Key The key: the first K bytes are read.
   --  @param Text The text: the first N bytes are read.
   --  @param Cuts The ends of the chunks: the first C are read.
   --  @param Output The MAC, written through Cryptol's output pointer.

end Foundation_Spark.FFI.HMAC_SHA256_Impl;
