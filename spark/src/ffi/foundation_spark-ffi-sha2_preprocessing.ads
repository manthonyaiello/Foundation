--  The ghost shims for algorithms/SHA2/Preprocessing.cry at SHA-256: the
--  initial hash value H0_256, and pad and parse at SHA-256's {m, w} =
--  {512, 32} (the spec states them in the generic Main, so these call the
--  SHA2.SHA256 instance's Pad and Parse), exported with Cryptol's C calling
--  convention. They are checked by
--  spark/cryptol/SPARK/SHA2/Preprocessing.cry.
--
--  pad takes an [l] of any length, which Cryptol's C calling convention
--  cannot pass: the Cryptol side passes split (M # zero) : [l /^ 8][8]
--  with l as a size_t, and the shim takes the first l bits back
--  (SHA2_Types.Join_Bits). The padded message, a whole number of 512-bit
--  blocks, comes back as bytes (SHA2_Types.Byte_At), which the Cryptol side
--  joins. parse takes the padded message the same way, as [N * 64][8], and
--  returns [N][16][32] as N * 16 words.
--
--  Ghost, because the spec layer is; SHA2_Preprocessing_Exports gives each
--  the name Cryptol looks up (see Foundation_Spark.FFI).

with Interfaces.C;
with Foundation_Spark.FFI.SHA2_Types;
with Foundation_Spark.SHA2.Preprocessing;
with Foundation_Spark.SHA2.SHA256;
with Foundation_Spark.SHA2.SHA256_Bytes;

package Foundation_Spark.FFI.SHA2_Preprocessing with
  SPARK_Mode,
  Ghost
is

   use type SHA2.Words_32;
   use type SHA2.Bit_Index;
   use type SHA2.SHA256_Bytes.Byte_Index;
   use type SHA2.SHA256_Bytes.Byte;
   use type Interfaces.C.size_t;
   use Foundation_Spark.FFI.SHA2_Types;

   procedure H0_256 (Output : out SHA2.SHA256.Hash_Value)
   with
     Export,
     Convention    => C,
     External_Name => "spark_H0_256",
     Post          => Output = SHA2.Preprocessing.H0_256;
   --  Preprocessing.cry's H0_256 : [8][32], as the spec states it. Cryptol
   --  declares it as a function of () so that it can be foreign.
   --  @param Output The initial hash value, written through Cryptol's output
   --  pointer.

   Max_Pad_Bits : constant := 8 * (Max_Buffer_Bytes - 128);
   --  The longest message Pad takes: its padding, at most 576 more bits,
   --  must fit in a Byte_Buffer.

   function Padded (L : C_Size; M : Byte_Buffer) return Bits is
     (SHA2.SHA256.Pad (Join_Bits (L, M)))
   with
     Pre => L <= Max_Pad_Bits;
   --  The spec's Pad, at SHA-256, of the first L bits of M.
   --  @param L The message length in bits, Cryptol's {l}.
   --  @param M The message as bytes.
   --  @return The padded message, indexed from 0.

   function Padded_Bytes
     (L : C_Size) return SHA2.SHA256_Bytes.Byte_Index
   is (64 * SHA2.SHA256_Bytes.Byte_Index (SHA2.SHA256.N (Bit_Index (L))))
   with
     Pre  => L <= Max_Pad_Bits,
     Post => Padded_Bytes'Result <= Max_Buffer_Bytes;
   --  The length in bytes of the padding of an [l], 64 * N (l): N (l)
   --  blocks of 64 bytes.
   --  @param L The message length in bits, Cryptol's {l}.
   --  @return The number of bytes Pad writes.

   procedure Pad (L : C_Size; M : Byte_Buffer; Output : in out Byte_Buffer)
   with
     Export,
     Convention    => C,
     External_Name => "spark_pad",
     Pre           => L <= Max_Pad_Bits,
     Post          =>
       Padded (L, M)'Length = 512 * SHA2.SHA256.N (Bit_Index (L))
       and then
         (for all I in 0 .. Padded_Bytes (L) - 1 =>
            Output (I) = Byte_At (Padded (L, M), I));
   --  Preprocessing.cry's pad`{512, 32, l}, as the spec's SHA256.Pad
   --  states it, over bytes.
   --  @param L The message length in bits, Cryptol's {l}.
   --  @param M The message as bytes: the first L /^ 8 are read.
   --  @param Output The padded message as bytes: its first 64 * N (L) bytes
   --  are written, through Cryptol's output pointer.

   procedure Parse (N : C_Size; P : Byte_Buffer; Output : in out Block_Buffer)
   with
     Export,
     Convention    => C,
     External_Name => "spark_parse",
     Pre           => N <= Max_Buffer_Blocks,
     Post          =>
       (for all I in 0 .. Bit_Index (N) - 1 =>
          Output (I)
          = SHA2.SHA256.Parse (Join_Bits (512 * N, P), Bit_Index (N)) (I));
   --  Preprocessing.cry's parse`{32, N}, as the spec's SHA256.Parse states
   --  it, over bytes.
   --  @param N The number of blocks, Cryptol's {N}.
   --  @param P The padded message as bytes: the first 64 * N are read.
   --  @param Output The N blocks, written through Cryptol's output pointer.

end Foundation_Spark.FFI.SHA2_Preprocessing;
