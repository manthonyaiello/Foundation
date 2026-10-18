--  The C shapes of the SHA-2 and HMAC arguments, shared by the SHA-2 and
--  HMAC shim and export units, as FFI.AES_Types is for AES.
--
--  Cryptol's C calling convention passes a numeric type parameter {l} as a
--  leading size_t, a word of at most 64 bits as uint8_t .. uint64_t, and a
--  sequence of such words ([n][8], [n][32], and nested sequences
--  flattened) as a pointer to its elements; a result of a sequence type is
--  written through a pointer passed after the arguments. An Ada array
--  parameter of a Convention C subprogram is passed by reference, as a
--  pointer to its first component.
--
--  It cannot pass an arbitrary bit sequence [l] (spark/README.md, "Passing
--  bit sequences"), so a message is passed as bytes, [l /^ 8][8], with l
--  as the leading size_t, and the shims join them back into bits. The
--  length of such a buffer depends on l, so the parameter is typed at a
--  fixed maximum (Byte_Buffer, Block_Buffer, Cut_Buffer) and the shims
--  read, or write, only the caller's prefix, which their preconditions
--  bound. Those preconditions are checked at run time in the -gnata FFI
--  library.
--
--  Not ghost: the export units, and the executable SHA-256 and HMAC
--  exports, use these types too.

with Interfaces.C;
with Foundation_Spark.SHA2.SHA256;
with Foundation_Spark.SHA2.SHA256_Bytes;

package Foundation_Spark.FFI.SHA2_Types with
  SPARK_Mode
is

   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;
   use type SHA2.SHA256_Bytes.Byte_Index;
   use type Interfaces.Unsigned_64;
   use type SHA2.Bit_Index;

   subtype C_Size is Interfaces.C.size_t;
   --  A Cryptol numeric type parameter in the C calling convention: size_t.

   subtype Bit_Index is SHA2.Bit_Index;
   --  A position in, or a length of, a bit sequence (SHA2.Bit_Index).

   subtype Bits is SHA2.Bits;
   --  A bit sequence, Cryptol's [l] (SHA2.Bits).

   subtype K_Table is SHA2.Words_32 (0 .. 63);
   --  The C buffer of a [64][32], SHA-256's constants K_256.

   Max_Buffer_Bytes : constant := 2 ** 24;
   --  The most bytes a message buffer may hold across the FFI: the
   --  properties pass at most a few thousand. It bounds Byte_Buffer.

   subtype Buffer_Index is
     SHA2.SHA256_Bytes.Byte_Index range 0 .. Max_Buffer_Bytes - 1;
   --  The indices of a Byte_Buffer.

   subtype Byte_Buffer is SHA2.SHA256_Bytes.Byte_Array (Buffer_Index);
   --  The C buffer of a [n][8], typed at Max_Buffer_Bytes bytes. Only the
   --  first n are the caller's.

   Max_Buffer_Blocks : constant := Max_Buffer_Bytes / 64;
   --  The most 16-word blocks a Block_Buffer may hold.

   subtype Block_Buffer_Index is Bit_Index range 0 .. Max_Buffer_Blocks - 1;
   --  The indices of a Block_Buffer.

   subtype Block_Buffer is SHA2.SHA256.Block_Vector (Block_Buffer_Index);
   --  The C buffer of a [N][16][32], typed at Max_Buffer_Blocks blocks.
   --  Only the first N are the caller's.

   Max_Cuts : constant := 64;
   --  The most cut points a chunking may have.

   subtype Cut_Index is Natural range 0 .. Max_Cuts - 1;
   --  The indices of a Cut_Buffer.

   type Cut_Buffer is array (Cut_Index) of Interfaces.Unsigned_64;
   --  The C buffer of a [c][64], the ends of the chunks a message is cut
   --  into, typed at Max_Cuts. Only the first c are the caller's.

   function Prefix
     (N : C_Size; M : Byte_Buffer) return SHA2.SHA256_Bytes.Byte_Array
   is (M (0 .. SHA2.SHA256_Bytes.Byte_Index (N) - 1))
   with
     Pre  => N <= Max_Buffer_Bytes,
     Post =>
       Prefix'Result'First = 0
       and then Prefix'Result'Length = SHA2.SHA256_Bytes.Byte_Index (N);
   --  The caller's [n][8]: the first N bytes of M.
   --  @param N The number of bytes, Cryptol's {n}.
   --  @param M The C buffer.
   --  @return M (0 .. N - 1).

   function Join_Bits (L : C_Size; M : Byte_Buffer) return Bits is
     ([for I in 0 .. Bit_Index (L) - 1 =>
         SHA2.SHA256_Bytes.Byte_Bit
           (M (SHA2.SHA256_Bytes.Byte_Index (I / 8)), Natural (I mod 8))])
   with
     Ghost,
     Pre  => L <= 8 * Max_Buffer_Bytes,
     Post => Join_Bits'Result'First = 0
             and then Join_Bits'Result'Length = Bit_Index (L);
   --  The caller's [l], passed as [l /^ 8][8]: the first L bits of the
   --  bytes of M, each byte most significant bit first. On the Cryptol side
   --  the message is split (M # zero) into bytes, so this is Cryptol's
   --  take`{l} (join bytes), and gives back M.
   --  @param L The number of bits, Cryptol's {l}.
   --  @param M The C buffer.
   --  @return The L bits, indexed from 0.

   function Byte_At
     (B : Bits; I : SHA2.SHA256_Bytes.Byte_Index) return SHA2.SHA256_Bytes.Byte
   is
     ((if B (8 * Bit_Index (I)) then 128 else 0)
      + (if B (8 * Bit_Index (I) + 1) then 64 else 0)
      + (if B (8 * Bit_Index (I) + 2) then 32 else 0)
      + (if B (8 * Bit_Index (I) + 3) then 16 else 0)
      + (if B (8 * Bit_Index (I) + 4) then 8 else 0)
      + (if B (8 * Bit_Index (I) + 5) then 4 else 0)
      + (if B (8 * Bit_Index (I) + 6) then 2 else 0)
      + (if B (8 * Bit_Index (I) + 7) then 1 else 0))
   with
     Ghost,
     Pre => B'First = 0
            and then I < SHA2.SHA256_Bytes.Max_Bytes
            and then 8 * Bit_Index (I) + 7 <= B'Last;
   --  Byte I of a bit sequence, Cryptol's split : [8 * n] -> [n][8] at
   --  byte I: bits 8 I .. 8 I + 7 of B, the first the most significant.
   --  @param B The bits, indexed from 0.
   --  @param I The byte's index.
   --  @return The byte.

   function Split_Digest (D : Bits) return SHA2.SHA256_Bytes.Digest is
     ([for I in SHA2.SHA256_Bytes.Digest'Range => Byte_At (D, I)])
   with
     Ghost,
     Pre => D'First = 0 and then D'Length = 256;
   --  A 256-bit digest as 32 bytes, Cryptol's split : [256] -> [32][8].
   --  @param D The digest's bits, indexed from 0.
   --  @return Its bytes.

   function Is_Cut
     (N : C_Size; Cuts : Cut_Buffer; J : Cut_Index) return Boolean
   is (Cuts (J) <= Interfaces.Unsigned_64 (N)
       and then (if J > 0 then Cuts (J - 1) <= Cuts (J)));
   --  Whether cut point J of Cuts may end a chunk of a message of N bytes:
   --  it is at most N, and not before the cut point preceding it.
   --  @param N The message length in bytes.
   --  @param Cuts The C buffer of cut points.
   --  @param J The cut point's index.
   --  @return Whether cut point J is in order and within the message.

   function Is_Chunking
     (N : C_Size; C : C_Size; Cuts : Cut_Buffer) return Boolean
   with
     Post =>
       Is_Chunking'Result
       = (C <= Max_Cuts
          and then
            (for all J in 0 .. Natural (C) - 1 => Is_Cut (N, Cuts, J)));
   --  Whether the first C words of Cuts are the ends of a chunking of a
   --  message of N bytes: at most Max_Cuts of them, none beyond N, and in
   --  order. Chunk J is the bytes from the previous end (0 for the first)
   --  up to Cuts (J), and a last chunk runs to N; any of them may be
   --  empty. The Cryptol side reduces its random cut points mod N + 1 and
   --  sorts them, so this holds at every call. Its Post is its
   --  definition: gnatdoc 26 crashes on it as an expression function.
   --  @param N The message length in bytes.
   --  @param C The number of cut points.
   --  @param Cuts The C buffer of cut points.
   --  @return Whether they make a chunking.

end Foundation_Spark.FFI.SHA2_Types;
