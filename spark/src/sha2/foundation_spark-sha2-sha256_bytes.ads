--  The byte-level refinement of SHA-256 [FIPS-PUB-180-4 Sections 5.1.1,
--  5.2.1 and 6.2]: messages and digests as bytes, as every C library sees
--  them, proved equal to the SHA256 instance of the spec layer's bit-level
--  `hash` (algorithms/SHA2/Main.cry:55). This is a representation change,
--  so it is not part of the spec layer, which mirrors the Cryptol.
--
--  A byte is read most significant bit first (Bits_Of), as Cryptol's
--  `join : [n][8] -> [8 * n]` does. The padding is the byte string FIPS
--  180-4 describes for a whole number of bytes: 0x80, zero bytes, and the
--  bit length as 8 big-endian bytes (Pad_Bytes). Words are read from it
--  four bytes at a time, big-endian (Parse_Bytes). Hash_Bytes folds the
--  spec's Step over those blocks from H0 and writes the digest's words out
--  big-endian. Lemma_Hash_Bytes proves `Bits_Of (Hash_Bytes (M)) =
--  SHA256.Hash (Bits_Of (M))`.
--
--  Everything here is ghost: Step, the compression, is ghost in the spec
--  layer, and the executable compression and its streaming interface are
--  SHA256_Stream's. This unit is what SHA256_Stream refines to, at the level of bytes and
--  words, with no bit sequences left in its statements.
--
--  The padding lemma Lemma_Pad is stated for a message of any bit length,
--  not just a whole number of bytes, so that a FinalBits (RFC 6234's
--  trailing partial byte) needs no new lemma about Pad.
--
--  Specific to SHA-256 rather than in the generic Main: the byte layout
--  depends on the word size (4 bytes to a word and an 8-byte length at
--  w = 32), and with Main's formals fixed the provers see concrete
--  bit-vector shifts instead of powers of a formal modulus.

with Interfaces;
with Foundation_Spark.SHA2.Preprocessing;
with Foundation_Spark.SHA2.SHA256;

package Foundation_Spark.SHA2.SHA256_Bytes with
  SPARK_Mode
is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   subtype Byte is Interfaces.Unsigned_8;
   --  A byte, Cryptol's `[8]`.

   type Byte_Index is range 0 .. 2 ** 62;
   --  A position in, or a length of, a byte sequence. Messages are below
   --  Max_Bytes; the bound leaves room for the padding of the longest.

   type Byte_Array is array (Byte_Index range <>) of Byte;
   --  A sequence of bytes, Cryptol's `[n][8]`.

   Max_Bytes : constant := 2 ** 61;
   --  The bound on message lengths in bytes: Main's Max_Length (2 ** 64
   --  bits) divided by 8.

   subtype Digest is Byte_Array (0 .. 31);
   --  A SHA-256 message digest, 256 bits as 32 bytes.

   function Byte_Bit (B : Byte; J : Natural) return Boolean is
     ((Interfaces.Shift_Right (B, 7 - J) and 1) = 1)
   with
     Ghost,
     Pre => J < 8;
   --  Bit J of a byte, Cryptol's `b @ j` on `[8]`: most significant bit
   --  first.
   --  @param B The byte.
   --  @param J The bit's position, below 8.
   --  @return Whether that bit is 1.

   function Bits_Of (M : Byte_Array) return Bits is
     ([for I in 0 .. 8 * Bit_Index (M'Length) - 1 =>
         Byte_Bit (M (M'First + Byte_Index (I / 8)), Natural (I mod 8))])
   with
     Ghost,
     Pre => M'Length <= Max_Bytes + 72;
   --  The bits of a byte sequence, Cryptol's `join` on `[n][8]`: each
   --  byte's bits in order, most significant first, so bit I is bit
   --  I mod 8 of byte I / 8.
   --  @param M The bytes.
   --  @return Their 8 * M'Length bits, indexed from 0.

   function Blocks (Count : Bit_Index) return Bit_Index is
     ((Count + 72) / 64)
   with
     Ghost,
     Pre => Count < Max_Bytes;
   --  The number of 64-byte blocks in the padding of a message of Count
   --  bytes: the least n with 64 * n >= Count + 9 (the message, the 0x80
   --  byte and the 8-byte length). It is Main's N (8 * Count).
   --  @param Count The message length, in bytes.
   --  @return The number of blocks.

   function Length_Byte (L : Interfaces.Unsigned_64; J : Natural) return Byte
   is
     (Byte (Interfaces.Shift_Right (L, 56 - 8 * J) and 16#FF#))
   with
     Ghost,
     Pre => J < 8;
   --  Byte J of L written as 8 bytes, big-endian: byte 0 is the most
   --  significant.
   --  @param L The number written.
   --  @param J The byte's position, below 8.
   --  @return Byte J of L.

   function Padded_Byte (M : Byte_Array; I : Bit_Index) return Byte is
     (if I < M'Length then M (M'First + Byte_Index (I))
      elsif I = M'Length then 16#80#
      elsif I < 64 * Blocks (M'Length) - 8 then 0
      else Length_Byte
             (8 * Interfaces.Unsigned_64 (M'Length),
              Natural (I - (64 * Blocks (M'Length) - 8))))
   with
     Ghost,
     Pre => M'Length < Max_Bytes and then I < 64 * Blocks (M'Length);
   --  Byte I of the padded message [FIPS-PUB-180-4 Section 5.1.1] for a
   --  message M of n whole bytes: M, the byte 0x80 (a 1 bit and seven of
   --  the zeros), zero bytes up to 8 short of a whole block, and the bit
   --  length 8 * n as 8 big-endian bytes.
   --  @param M The message.
   --  @param I The position in the padded message.
   --  @return Byte I of the padded message.

   function Pad_Bytes (M : Byte_Array) return Byte_Array is
     ([for I in 0 .. Byte_Index (64 * Blocks (M'Length)) - 1 =>
         Padded_Byte (M, Bit_Index (I))])
   with
     Ghost,
     Pre => M'Length < Max_Bytes;
   --  The padded message, byte by byte (Padded_Byte): Preprocessing.cry's
   --  `pad` (Preprocessing.cry:14) for a whole number of bytes. Proved
   --  equal to Pad on the bits by Lemma_Pad_Bytes.
   --  @param M The message.
   --  @return The padded message, Blocks (M'Length) * 64 bytes, indexed
   --  from 0.

   function Word_At
     (P : Byte_Array; F : Byte_Index) return Interfaces.Unsigned_32
   is
     (2 ** 24 * Interfaces.Unsigned_32 (P (F))
      + 2 ** 16 * Interfaces.Unsigned_32 (P (F + 1))
      + 2 ** 8 * Interfaces.Unsigned_32 (P (F + 2))
      + Interfaces.Unsigned_32 (P (F + 3)))
   with
     Ghost,
     Pre => F >= P'First and then F + 3 <= P'Last;
   --  The four bytes of P from F read as a word, big-endian [FIPS-PUB-180-4
   --  Section 3.1]: P (F) is the most significant.
   --  @param P The bytes.
   --  @param F The position of the word's first byte.
   --  @return The word.

   function Block_At (P : Byte_Array; I : Bit_Index) return SHA256.Block is
     ([for J in 0 .. 15 =>
         Word_At (P, Byte_Index (64 * I) + 4 * Byte_Index (J))])
   with
     Ghost,
     Pre =>
       P'First = 0 and then I < 2 ** 62 and then 64 * (I + 1) <= P'Length;
   --  Block I of a padded message as 16 big-endian words: word J is read
   --  from byte 64 * I + 4 * J.
   --  @param P The padded message, indexed from 0.
   --  @param I The block's index.
   --  @return Block I.

   function Parse_Bytes (P : Byte_Array; N : Bit_Index)
     return SHA256.Block_Vector
   is ([for I in 0 .. N - 1 => Block_At (P, I)])
   with
     Ghost,
     Pre => P'First = 0 and then N <= 2 ** 62 and then P'Length = 64 * N;
   --  The padded message's N blocks [FIPS-PUB-180-4 Section 5.2.1], read
   --  as words from bytes: Preprocessing.cry's `parse`
   --  (Preprocessing.cry:47), proved equal to Parse on the bits by
   --  Lemma_Parse_Bytes.
   --  @param P The padded message, 64 * N bytes, indexed from 0.
   --  @param N The number of blocks.
   --  @return The N blocks, indexed from 0.

   function Word_Byte (X : Interfaces.Unsigned_32; J : Natural) return Byte
   is
     (Byte (Interfaces.Shift_Right (X, 24 - 8 * J) and 16#FF#))
   with
     Ghost,
     Pre => J < 4;
   --  Byte J of a word written as 4 bytes, big-endian [FIPS-PUB-180-4
   --  Section 3.1]: byte 0 is the most significant.
   --  @param X The word.
   --  @param J The byte's position, below 4.
   --  @return Byte J of X.

   function Digest_Bytes (H : SHA256.Hash_Value) return Digest is
     ([for I in Digest'Range =>
         Word_Byte (H (Natural (I / 4)), Natural (I mod 4))])
   with Ghost;
   --  A hash value written as 32 bytes, each word big-endian: Main.cry's
   --  `take (join H)` (Main.cry:56) at d = 256 = 8 * w, as bytes.
   --  @param H The hash value.
   --  @return Its bytes.

   function Hash_Bytes (M : Byte_Array) return Digest is
     (Digest_Bytes
        (SHA256.Foldl_Step
           (Preprocessing.H0_256,
            Parse_Bytes (Pad_Bytes (M), Blocks (M'Length)),
            Blocks (M'Length))))
   with
     Ghost,
     Pre => M'Length < Max_Bytes;
   --  SHA-256 of a message of whole bytes, at the level of bytes and
   --  words [FIPS-PUB-180-4 Section 6.2]: pad to bytes, read the blocks'
   --  words big-endian, fold the spec's Step over them from H0, and write
   --  the result big-endian. Lemma_Hash_Bytes proves it equal to
   --  SHA256.Hash on the message's bits.
   --  @param M The message, below Max_Bytes bytes.
   --  @return The 32-byte digest.

   procedure Lemma_To_Bits (V : Interfaces.Unsigned_64; W : Natural) with
     Ghost,
     Pre                => W <= 64,
     Subprogram_Variant => (Decreases => W),
     Post =>
       (for all I in 0 .. Bit_Index (W) - 1 =>
          To_Bits (Bit_Index (V), Bit_Index (W)) (I)
          = ((Interfaces.Shift_Right (V, W - 1 - Natural (I)) and 1) = 1));
   --  To_Bits (Preprocessing.cry:23's literal `(`l : [2 * w])`), bit by
   --  bit: bit I of V in W bits is bit W - 1 - I of V, counting from the
   --  least significant. Proved by induction on W.
   --  @param V The number.
   --  @param W The width, at most 64.

   procedure Lemma_Pad (M : Bits) with
     Ghost,
     Pre  => M'First = 0 and then M'Length < SHA256.Max_Length,
     Post =>
       SHA256.Pad (M)'First = 0
       and then SHA256.Pad (M)'Length = 512 * SHA256.N (M'Length)
       and then
         (for all I in SHA256.Pad (M)'Range =>
            SHA256.Pad (M) (I)
            = (if I < M'Length then M (I)
               elsif I = M'Length then True
               elsif I < 512 * SHA256.N (M'Length) - 64 then False
               else
                 (Interfaces.Shift_Right
                    (Interfaces.Unsigned_64 (M'Length),
                     Natural (512 * SHA256.N (M'Length) - 1 - I))
                  and 1) = 1));
   --  The padding of a message of any bit length l [FIPS-PUB-180-4 Section
   --  5.1.1], Preprocessing.cry's `pad` (Preprocessing.cry:14), bit by
   --  bit: the padded message has N (l) blocks; its bits are M's, then a 1
   --  at l, then 0s up to 64 bits short of the end, and then l as 64 bits,
   --  most significant first. Stated for general l, not only l = 8 * n,
   --  so that the trailing partial byte of a FinalBits needs no new lemma.
   --  @param M The message, `[l]`, indexed from 0.

   procedure Lemma_Length_Bits (L : Interfaces.Unsigned_64) with
     Ghost,
     Post =>
       (for all J in 0 .. 7 =>
          (for all T in 0 .. 7 =>
             Byte_Bit (Length_Byte (L, J), T)
             = ((Interfaces.Shift_Right (L, 63 - 8 * J - T) and 1) = 1)));
   --  Bit T of byte J of L written big-endian is bit 8 * J + T of L in 64
   --  bits, most significant first.
   --  @param L The number.

   procedure Lemma_Pad_Bytes_Bits (M : Byte_Array) with
     Ghost,
     Pre  => M'Length < Max_Bytes,
     Post =>
       SHA256.N (8 * Bit_Index (M'Length)) = Blocks (M'Length)
       and then SHA256.Pad (Bits_Of (M))'Length = 8 * Pad_Bytes (M)'Length
       and then
         (for all B in Pad_Bytes (M)'Range =>
            (for all T in 0 .. 7 =>
               SHA256.Pad (Bits_Of (M)) (8 * Bit_Index (B) + Bit_Index (T))
               = Byte_Bit (Pad_Bytes (M) (B), T)));
   --  The byte-level padding is the bit-level `pad` for l = 8 * n, byte by
   --  byte: bit T of padded byte B is bit 8 * B + T of Pad on the
   --  message's bits, and N (8 * n) = Blocks (n). Proved from Lemma_Pad
   --  by cases on the part of the padding that byte B falls in.
   --  @param M The message, below Max_Bytes bytes.

   procedure Lemma_Pad_Bytes (M : Byte_Array) with
     Ghost,
     Pre  => M'Length < Max_Bytes,
     Post =>
       SHA256.N (8 * Bit_Index (M'Length)) = Blocks (M'Length)
       and then Bits_Of (Pad_Bytes (M)) = SHA256.Pad (Bits_Of (M))
       and then
         (for all B in Pad_Bytes (M)'Range =>
            (for all T in 0 .. 7 =>
               SHA256.Pad (Bits_Of (M)) (8 * Bit_Index (B) + Bit_Index (T))
               = Byte_Bit (Pad_Bytes (M) (B), T)));
   --  The byte-level padding is the bit-level `pad` for l = 8 * n: the
   --  bits of Pad_Bytes (M) are Pad of the bits of M, and both have
   --  Blocks (n) = N (8 * n) blocks.
   --  @param M The message, below Max_Bytes bytes.

   procedure Lemma_Word_Of_Byte
     (P : Bits; S : Bit_Index; A : Natural; X : Byte)
   with
     Ghost,
     Pre  =>
       A <= 24
       and then S >= P'First
       and then S + Bit_Index (A) + 7 <= P'Last
       and then
         (for all T in 0 .. 7 =>
            P (S + Bit_Index (A) + Bit_Index (T)) = Byte_Bit (X, T)),
     Post =>
       SHA256.Word_Of (P, S, A + 8)
       = 2 ** 8 * SHA256.Word_Of (P, S, A) + Interfaces.Unsigned_32 (X);
   --  Reading 8 more bits that are the byte X appends X to the word read
   --  so far: Main's Word_Of (the conversion in `parse`'s `split`) over
   --  A + 8 bits is the value over A bits, shifted left 8, plus X.
   --  @param P The bits.
   --  @param S The position of the word's first bit.
   --  @param A The number of bits read before X, at most 24.
   --  @param X The byte that P holds at S + A .. S + A + 7.

   procedure Lemma_Word_Of_Bytes
     (P : Bits; S : Bit_Index; Q : Byte_Array; F : Byte_Index)
   with
     Ghost,
     Pre  =>
       S >= P'First
       and then S + 31 <= P'Last
       and then F >= Q'First
       and then F + 3 <= Q'Last
       and then
         (for all K in 0 .. 3 =>
            (for all T in 0 .. 7 =>
               P (S + 8 * Bit_Index (K) + Bit_Index (T))
               = Byte_Bit (Q (F + Byte_Index (K)), T))),
     Post => SHA256.Word_Of (P, S, 32) = Word_At (Q, F);
   --  The 32 bits of P from S, read as Word_Of reads them, are the
   --  big-endian word of the 4 bytes of Q from F, when those bits are
   --  those bytes' bits.
   --  @param P The bits.
   --  @param S The position of the word's first bit.
   --  @param Q The bytes.
   --  @param F The position of the word's first byte.

   procedure Lemma_Parse_Bytes (M : Byte_Array) with
     Ghost,
     Pre  => M'Length < Max_Bytes,
     Post =>
       SHA256.N (8 * Bit_Index (M'Length)) = Blocks (M'Length)
       and then
         (for all I in 0 .. Blocks (M'Length) - 1 =>
            (for all J in 0 .. 15 =>
               Parse_Bytes (Pad_Bytes (M), Blocks (M'Length)) (I) (J)
               = SHA256.Parse
                   (SHA256.Pad (Bits_Of (M)), Blocks (M'Length)) (I) (J)));
   --  The byte-level parse of the byte-level padding is `parse` of `pad`
   --  (Preprocessing.cry:47 and :14) on the message's bits, word by word:
   --  word J of block I, read big-endian from bytes, is the 32 bits that
   --  `split` cuts at (16 * I + J) * 32.
   --  @param M The message, below Max_Bytes bytes.

   procedure Lemma_Word_Bits (X : Interfaces.Unsigned_32) with
     Ghost,
     Post =>
       (for all J in 0 .. 31 =>
          SHA256.Bit (X, J) = Byte_Bit (Word_Byte (X, J / 8), J mod 8));
   --  Bit J of a word, as Main.cry's `join` reads it (Main's Bit), is bit
   --  J mod 8 of its big-endian byte J / 8.
   --  @param X The word.

   procedure Lemma_Digest_Bytes (H : SHA256.Hash_Value) with
     Ghost,
     Post => Bits_Of (Digest_Bytes (H)) = SHA256.Join (H) (0 .. 255);
   --  The digest bytes are Main.cry's `take (join H)` (Main.cry:56) at
   --  d = 256: bit I of the bytes is bit I mod 32 of word I / 32.
   --  @param H The hash value.

   procedure Lemma_W_Ext (M1, M2 : SHA256.Block) with
     Ghost,
     Pre  => M1 = M2,
     Post => (for all T in 0 .. 63 => SHA256.W (M1, T) = SHA256.W (M2, T));
   --  The message schedule `W` (Main.cry:70) of equal blocks is equal.
   --  Array equality is not the provers' logical equality, so equal
   --  arguments give equal results only by induction over the definition.
   --  @param M1 A message block.
   --  @param M2 A message block equal to M1.

   procedure Lemma_Foldl_Step3_Ext
     (M1, M2 : SHA256.Block; H1, H2 : SHA256.Hash_Value; N : Natural)
   with
     Ghost,
     Pre                => M1 = M2 and then H1 = H2 and then N <= 64,
     Post               =>
       SHA256.Foldl_Step3 (M1, H1, N) = SHA256.Foldl_Step3 (M2, H2, N),
     Subprogram_Variant => (Decreases => N);
   --  The fold of the rounds `foldl step3 H [0 ..< N]` (Main.cry:74) over
   --  equal blocks from equal hash values is equal. By induction on N.
   --  @param M1 A message block.
   --  @param M2 A message block equal to M1.
   --  @param H1 A hash value.
   --  @param H2 A hash value equal to H1.
   --  @param N The number of rounds, at most 64.

   procedure Lemma_Foldl_Step_Ext
     (H : SHA256.Hash_Value; Ms1, Ms2 : SHA256.Block_Vector; N : Bit_Index)
   with
     Ghost,
     Pre                =>
       Ms1'First = 0
       and then Ms2'First = 0
       and then N <= Ms1'Last + 1
       and then N <= Ms2'Last + 1
       and then (for all I in 0 .. N - 1 => Ms1 (I) = Ms2 (I)),
     Post               =>
       SHA256.Foldl_Step (H, Ms1, N) = SHA256.Foldl_Step (H, Ms2, N),
     Subprogram_Variant => (Decreases => N);
   --  `foldl step H` (Main.cry:61) over two block sequences whose first N
   --  blocks are equal is equal. By induction on N, with
   --  Lemma_Foldl_Step3_Ext for each block's `step`.
   --  @param H The initial hash value.
   --  @param Ms1 A block sequence, indexed from 0.
   --  @param Ms2 A block sequence equal to Ms1 in its first N blocks.
   --  @param N The number of blocks folded.

   procedure Lemma_Hash_Bytes (M : Byte_Array) with
     Ghost,
     Pre  => M'Length < Max_Bytes,
     Post => Bits_Of (Hash_Bytes (M)) = SHA256.Hash (Bits_Of (M));
   --  The byte-level refinement: SHA-256 over bytes is Main.cry's `hash`
   --  (Main.cry:55) over the message's bits, for every message of whole
   --  bytes.
   --  @param M The message, below Max_Bytes bytes.

end Foundation_Spark.SHA2.SHA256_Bytes;
