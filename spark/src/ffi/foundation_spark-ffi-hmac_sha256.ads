--  The ghost shims for algorithms/HMAC/Main.cry at SHA-256, as
--  packaging/Hash.cry instantiates it in algorithms/SHA2/SHA256.cry (the
--  spec's HMAC.SHA256 instance): HMAC at lambda = 256, and HMAC_init,
--  exported with Cryptol's C calling convention. They are checked by
--  spark/cryptol/SPARK/HMAC/SHA256.cry.
--
--  The key is [k][8], k as a size_t. The text is an [n] of any length,
--  which Cryptol's C calling convention cannot pass: the Cryptol side
--  passes split (text # zero) : [n /^ 8][8] with n as a size_t, and the
--  shim takes the first n bits back (SHA2_Types.Join_Bits), so the spec is
--  checked at text lengths that are not whole bytes too. The [256] MAC
--  comes back as [32][8], and HMAC_init's [512] as [64][8].
--
--  Ghost, because the spec layer is; HMAC_SHA256_Exports gives each the
--  name Cryptol looks up (see Foundation_Spark.FFI).

with Interfaces;
with Interfaces.C;
with Foundation_Spark.FFI.SHA2_Types;
with Foundation_Spark.HMAC.SHA256;
with Foundation_Spark.SHA2.SHA256_Bytes;

package Foundation_Spark.FFI.HMAC_SHA256 with
  SPARK_Mode,
  Ghost
is

   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;
   use type Foundation_Spark.HMAC.Byte_Index;
   use type SHA2.SHA256_Bytes.Byte_Array;
   use type SHA2.SHA256_Bytes.Byte_Index;
   use Foundation_Spark.FFI.SHA2_Types;

   subtype Key_Index is Foundation_Spark.HMAC.Byte_Index;
   --  The spec's index of a key (HMAC.Byte_Index).

   subtype Key_Bytes is Foundation_Spark.HMAC.Bytes;
   --  The spec's key type, Cryptol's [k][8] (HMAC.Bytes).

   function Key_Of (K : C_Size; Key : Byte_Buffer) return Key_Bytes is
     ([for I in 0 .. Key_Index (K) - 1 =>
         Key (SHA2.SHA256_Bytes.Byte_Index (I))])
   with
     Pre  => K <= Max_Buffer_Bytes,
     Post => Key_Of'Result'First = 0
             and then Key_Of'Result'Length = Key_Index (K);
   --  The caller's [k][8] as the spec's key type: the first K bytes of
   --  Key.
   --  @param K The key length in bytes, Cryptol's {k}.
   --  @param Key The C buffer.
   --  @return The K bytes, indexed from 0.

   procedure HMAC
     (K      : C_Size;
      N      : C_Size;
      Key    : Byte_Buffer;
      Text   : Byte_Buffer;
      Output : out SHA2.SHA256_Bytes.Digest)
   with
     Export,
     Convention    => C,
     External_Name => "spark_HMAC",
     Pre           => K <= Max_Buffer_Bytes and then N <= 8 * Max_Buffer_Bytes,
     Post          =>
       Output
       = Split_Digest
           (Foundation_Spark.HMAC.SHA256.HMAC
              (Key_Of (K, Key), Join_Bits (N, Text), 256));
   --  Main.cry's HMAC at SHA-256 and lambda = 256 (SHA256::HMAC), as the
   --  spec's HMAC.SHA256.HMAC states it, with the key, text and MAC passed
   --  as bytes.
   --  @param K The key length in bytes, Cryptol's {k}.
   --  @param N The text length in bits, Cryptol's {n}.
   --  @param Key The key: the first K bytes are read.
   --  @param Text The text as bytes: the first N /^ 8 are read.
   --  @param Output The MAC, written through Cryptol's output pointer.

   procedure HMAC_init
     (K      : C_Size;
      Key    : Byte_Buffer;
      Output : out Key_Block_Bytes)
   with
     Export,
     Convention    => C,
     External_Name => "spark_HMAC_init",
     Pre           => K <= Max_Buffer_Bytes,
     Post          =>
       (for all I in Key_Block_Bytes'Range =>
          Output (I)
          = Byte_At
              (Foundation_Spark.HMAC.SHA256.HMAC_init (Key_Of (K, Key)), I));
   --  Main.cry's HMAC_init at SHA-256 (B = 64, L = 32, Hk = SHA256::hash),
   --  as the spec's HMAC.SHA256.HMAC_init states it: the key K0, as bytes.
   --  @param K The key length in bytes, Cryptol's {k}.
   --  @param Key The key: the first K bytes are read.
   --  @param Output K0, written through Cryptol's output pointer.

end Foundation_Spark.FFI.HMAC_SHA256;
