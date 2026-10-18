--  The SHA-256 implementation [FIPS-PUB-180-4 Sections 5 and 6.2]:
--  executable SPARK, proved equal to the byte-level refinement
--  SHA256_Bytes.Hash_Bytes, and through SHA256_Bytes.Lemma_Hash_Bytes to
--  the spec layer's `hash` (algorithms/SHA2/Main.cry:55) on the message's
--  bits.
--
--  Compress is the compression function in place, proved equal to the
--  spec's Step (Main.cry:67). Hash is the one-shot hash. Init, Update and
--  Final are the streaming interface over a Context: the hash value so
--  far, a 64-byte buffer, and the number of bytes consumed.
--
--  What a context means. Models (C, M) says that C is the context after
--  consuming exactly the bytes M: its count is M's length, its hash value
--  is Step folded from H0 over M's whole blocks, and its buffer holds the
--  bytes after them. Init models the empty message. Update's
--  postcondition (Absorbed) relates the new context to the old one and
--  the data, and Lemma_Update turns that into Models (C, M & Data). Final
--  pads the buffered bytes and compresses the last one or two blocks, and
--  Lemma_Final proves `Final (C) = Hash_Bytes (M)` whenever Models (C, M).
--  So for any chunking of a message, Final after Init and an Update per
--  chunk is Hash_Bytes of the message, by induction on the chunks with
--  Models as the invariant (Hash_Chunked states this for the chunks of
--  one array).
--
--  The lemmas take the message as a ghost argument because a context does
--  not hold it, and SPARK has no ghost record components or ghost
--  parameters of executable subprograms.
--
--  Nothing executable here calls ghost code: Step, Hash_Bytes and the
--  folds of SHA256_Blocks appear only in contracts, assertions and
--  lemmas.

with Interfaces;
with Foundation_Spark.SHA2.SHA256;
with Foundation_Spark.SHA2.SHA256_Blocks;
with Foundation_Spark.SHA2.SHA256_Bytes;

package Foundation_Spark.SHA2.SHA256_Stream with
  SPARK_Mode
is

   use type Interfaces.Unsigned_8;
   use type SHA256_Bytes.Byte_Index;
   use type SHA256_Bytes.Byte_Array;
   use type Interfaces.Unsigned_64;

   subtype Byte_Array is SHA256_Bytes.Byte_Array;
   --  A sequence of bytes, as SHA256_Bytes declares it.

   subtype Digest is SHA256_Bytes.Digest;
   --  A 32-byte SHA-256 digest, as SHA256_Bytes declares it.

   procedure Compress (H : in out SHA256.Hash_Value; M : SHA256.Block) with
     Post => H = SHA256.Step (H'Old, M);
   --  The compression function [FIPS-PUB-180-4 Section 6.2.2], in place:
   --  the message schedule into a 64-word array, 64 rounds over the
   --  working variables, and the sum with H. Proved equal to Main.cry's
   --  `step H M` (Main.cry:67).
   --  @param H The hash value before the block, and after it on return.
   --  @param M The message block.

   function Load_Block
     (B : Byte_Array; F : SHA256_Bytes.Byte_Index) return SHA256.Block
   with
     Pre  => B'Length >= 64 and then F >= B'First and then F <= B'Last - 63,
     Post =>
       Load_Block'Result = SHA256_Blocks.Block_From (B, F)
       and then
         Load_Block'Result
         = SHA256.Parse (SHA256_Bytes.Bits_Of (B (F .. F + 63)), 1) (0);
   --  The 64 bytes of B from F as a message block, each word read
   --  big-endian [FIPS-PUB-180-4 Sections 3.1 and 5.2.1]. It is the
   --  executable `parse` (Preprocessing.cry:47), one block at a time: the
   --  block is the spec's Parse of the 64 bytes' bits, with N = 1
   --  (SHA256_Blocks.Lemma_Block_Parse). Update and Final parse each block
   --  with it as they reach it, since a streaming hash never holds the
   --  whole padded message that `parse` takes.
   --  @param B The bytes.
   --  @param F The position of the block's first byte.
   --  @return The block.

   function To_Digest (H : SHA256.Hash_Value) return Digest with
     Post => To_Digest'Result = SHA256_Bytes.Digest_Bytes (H);
   --  A hash value written as 32 bytes, each word big-endian
   --  [FIPS-PUB-180-4 Section 6.2.2].
   --  @param H The hash value.
   --  @return Its bytes.

   type Context is private;
   --  The state of a streaming SHA-256 computation: the hash value after
   --  the whole blocks consumed, the bytes consumed since, and the number
   --  of bytes consumed. Models states its meaning.

   function Count (C : Context) return SHA256_Bytes.Byte_Index;
   --  The number of bytes C has consumed.
   --  @param C The context.
   --  @return The number of bytes consumed since Init.

   function Models (C : Context; M : Byte_Array) return Boolean with
     Ghost;
   --  Whether C is the context after consuming exactly the bytes of M:
   --  M has fewer than Max_Bytes bytes and C has counted them; C's hash
   --  value is Step folded from H0 over M's M'Length / 64 whole blocks
   --  (SHA256_Blocks.Fold_Blocks); and C's buffer holds M's last
   --  M'Length mod 64 bytes, the ones after those blocks.
   --  @param C The context.
   --  @param M The bytes consumed, from any M'First.
   --  @return Whether C is the context after M.

   Empty : constant Byte_Array (1 .. 0) := [others => 0] with
     Ghost;
   --  The empty message, which a context models after Init.

   function Absorbed
     (C0 : Context; Data : Byte_Array; C1 : Context) return Boolean
   with
     Ghost,
     Pre => Data'Length < SHA256_Bytes.Max_Bytes;
   --  Whether C1 is C0 after consuming Data: C1 has counted Data's bytes
   --  on top of C0's, and C1's hash value and buffer are C0's hash value
   --  with Step folded over the whole blocks, and the bytes left over, of
   --  C0's buffered bytes followed by Data. Update's postcondition, stated
   --  without the message, which a context does not hold.
   --  @param C0 The context before.
   --  @param Data The bytes consumed.
   --  @param C1 The context after.
   --  @return Whether C1 is C0 after Data.

   procedure Init (C : out Context) with
     Post => Models (C, Empty) and then Count (C) = 0;
   --  Start a SHA-256 computation [FIPS-PUB-180-4 Section 5.3.3]: the
   --  hash value H0, nothing consumed.
   --  @param C The context, which then models the empty message.

   procedure Update (C : in out Context; Data : Byte_Array) with
     Pre  =>
       Count (C) < SHA256_Bytes.Max_Bytes
       and then Data'Length < SHA256_Bytes.Max_Bytes - Count (C),
     Post =>
       Absorbed (C'Old, Data, C)
       and then Count (C) = Count (C'Old) + Data'Length;
   --  Consume Data: fill the buffer and compress it once full, compress
   --  each whole block of Data in place, and buffer the rest. The total
   --  stays below Max_Bytes (2 ** 64 bits). Lemma_Update gives
   --  Models (C, M & Data) from Models (C'Old, M).
   --  @param C The context.
   --  @param Data The bytes to consume, from any Data'First.

   function Finished (C : Context; D : Digest) return Boolean with
     Ghost,
     Pre => Count (C) < SHA256_Bytes.Max_Bytes;
   --  Whether D is the digest of C: C's hash value with Step folded over
   --  the one or two blocks of C's buffered bytes padded as the end of a
   --  message of Count (C) bytes, written big-endian. Final's
   --  postcondition, stated without the message.
   --  @param C The context.
   --  @param D The digest.
   --  @return Whether D is the digest of C.

   function Final (C : Context) return Digest with
     Pre  => Count (C) < SHA256_Bytes.Max_Bytes,
     Post => Finished (C, Final'Result);
   --  The digest of the bytes C has consumed [FIPS-PUB-180-4 Sections
   --  5.1.1 and 6.2]: pad the buffered bytes (0x80, zeros, and the bit
   --  length as 8 big-endian bytes) to one block, or two when fewer than
   --  9 bytes of the block are free, compress them, and write the hash
   --  value big-endian. Lemma_Final proves it Hash_Bytes of the message C
   --  models. C is not changed.
   --  @param C The context.
   --  @return The digest.

   procedure Lemma_Update
     (C0 : Context; Data : Byte_Array; C1 : Context; M, M2 : Byte_Array)
   with
     Ghost,
     Pre  =>
       Data'Length < SHA256_Bytes.Max_Bytes
       and then M2'Length < SHA256_Bytes.Max_Bytes
       and then Models (C0, M)
       and then Absorbed (C0, Data, C1)
       and then M2'Length = M'Length + Data'Length
       and then
         (for all I in 0 .. SHA256_Bytes.Byte_Index (M'Length) - 1 =>
            M2 (M2'First + I) = M (M'First + I))
       and then
         (for all I in 0 .. SHA256_Bytes.Byte_Index (Data'Length) - 1 =>
            M2 (M2'First + SHA256_Bytes.Byte_Index (M'Length) + I)
            = Data (Data'First + I)),
     Post => Models (C1, M2);
   --  Update preserves the meaning of a context: if C0 models M and C1 is
   --  C0 after Data, then C1 models M2, the bytes of M followed by those
   --  of Data. The proof cuts M2's fold at M's last whole block
   --  (Lemma_Fold_Split) and compares each part with what C0 and C1 hold
   --  (Lemma_Fold_Ext).
   --  @param C0 The context before Update.
   --  @param Data The bytes Update consumed.
   --  @param C1 The context after Update.
   --  @param M The bytes C0 models.
   --  @param M2 M followed by Data, from any M2'First.

   procedure Lemma_Final (C : Context; M : Byte_Array) with
     Ghost,
     Pre  => Models (C, M),
     Post => Count (C) < SHA256_Bytes.Max_Bytes
             and then Final (C) = SHA256_Bytes.Hash_Bytes (M);
   --  Final computes Hash_Bytes: if C models M, the digest of C is
   --  Hash_Bytes (M). The proof reads the padded message's last one or
   --  two blocks as the padded buffer, and its blocks before them as the
   --  ones folded into C's hash value (Lemma_Foldl_Parse,
   --  Lemma_Fold_Split, Lemma_Fold_Ext).
   --  @param C The context.
   --  @param M The bytes C models.

   function Hash (M : Byte_Array) return Digest with
     Pre  => M'Length < SHA256_Bytes.Max_Bytes,
     Post =>
       Hash'Result = SHA256_Bytes.Hash_Bytes (M)
       and then SHA256_Bytes.Bits_Of (Hash'Result)
                = SHA256.Hash (SHA256_Bytes.Bits_Of (M));
   --  SHA-256 of a message of whole bytes, in one call: Init, one Update,
   --  Final. Proved equal to Hash_Bytes, and so to the spec's `hash`
   --  (Main.cry:55) on the message's bits.
   --  @param M The message, below Max_Bytes bytes, from any M'First.
   --  @return The 32-byte digest.

   type Chunk_Ends is array (Positive range <>) of SHA256_Bytes.Byte_Index;
   --  Where each chunk of a message ends: chunk J is the bytes after the
   --  end of chunk J - 1 (or from the message's first byte) up to and
   --  including byte Ends (J) - 1, counted from 0.

   function Hash_Chunked (M : Byte_Array; Ends : Chunk_Ends) return Digest
   with
     Pre  =>
       M'Length < SHA256_Bytes.Max_Bytes
       and then
         (for all J in Ends'Range =>
            Ends (J) <= SHA256_Bytes.Byte_Index (M'Length)
            and then (if J > Ends'First then Ends (J - 1) <= Ends (J))),
     Post => Hash_Chunked'Result = SHA256_Bytes.Hash_Bytes (M);
   --  SHA-256 of M fed to Update in chunks: Init, an Update for each
   --  chunk Ends describes, one more for the bytes after the last, and
   --  Final. Proved equal to Hash_Bytes (M) for every chunking, which is
   --  the streaming theorem `Final (Update* (Init, chunks)) = Hash_Bytes
   --  (concatenation of chunks)` for the chunks of one array.
   --  @param M The message, below Max_Bytes bytes, from any M'First.
   --  @param Ends The chunks' ends, nondecreasing, at most M'Length.
   --  @return The 32-byte digest.

private

   type Context is record
      H     : SHA256.Hash_Value;
      Buf   : Byte_Array (0 .. 63);
      Count : SHA256_Bytes.Byte_Index;
   end record;
   --  The state of a streaming computation.
   --  @field H The hash value after the whole blocks consumed.
   --  @field Buf The bytes consumed since: the first Count mod 64.
   --  @field Count The number of bytes consumed.

   function Count (C : Context) return SHA256_Bytes.Byte_Index is (C.Count);
   --  The count field.
   --  @param C The context.
   --  @return C.Count.

   function Tail_Blocks (C : Context) return Bit_Index is
     (Bit_Index (C.Count mod 64 + 72) / 64)
   with Ghost;
   --  The number of blocks the padding of C's buffered bytes takes: 1, or
   --  2 when fewer than 9 bytes of the block are free.
   --  @param C The context.
   --  @return 1 or 2.

   function Tail_Pad (C : Context) return Byte_Array is
     ([for I in 0 .. 127 =>
         (if I < C.Count mod 64 then C.Buf (I)
          elsif I = C.Count mod 64 then 16#80#
          elsif I < 64 * SHA256_Bytes.Byte_Index (Tail_Blocks (C)) - 8 then 0
          elsif I < 64 * SHA256_Bytes.Byte_Index (Tail_Blocks (C))
          then
            SHA256_Bytes.Length_Byte
              (8 * Interfaces.Unsigned_64 (C.Count),
               Natural
                 (I - (64 * SHA256_Bytes.Byte_Index (Tail_Blocks (C)) - 8)))
          else 0)])
   with
     Ghost,
     Pre => C.Count < SHA256_Bytes.Max_Bytes;
   --  The last Tail_Blocks (C) blocks of the padded message, as Pad_Bytes
   --  ends a message of C.Count bytes: the buffered bytes, 0x80, zeros,
   --  and the bit length as 8 big-endian bytes; zeros after them.
   --  @param C The context.
   --  @return 128 bytes, indexed from 0.

   function Finished (C : Context; D : Digest) return Boolean is
     (D
      = SHA256_Bytes.Digest_Bytes
          (SHA256_Blocks.Fold_Blocks (C.H, Tail_Pad (C), 0, Tail_Blocks (C))));
   --  Final's postcondition, on the fields: Step folded from C.H over the
   --  Tail_Blocks (C) blocks of Tail_Pad (C).
   --  @param C The context.
   --  @param D The digest.
   --  @return Whether D is the digest of C.

end Foundation_Spark.SHA2.SHA256_Stream;
