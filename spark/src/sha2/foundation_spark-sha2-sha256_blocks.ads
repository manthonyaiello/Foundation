--  Folding SHA-256's compression over the 64-byte blocks of a byte array,
--  for the streaming implementation (SHA256_Stream). The byte-level
--  refinement (SHA256_Bytes) states SHA-256 as Main.cry's
--  `foldl step H0` (Main.cry:61) over the blocks that Parse_Bytes reads
--  from the whole padded message. A streaming hash never holds that
--  message: it compresses each block as soon as it has one, so it needs
--  the fold over any run of whole blocks of any byte array, starting at
--  any byte and from any hash value, and the facts that let such folds
--  be cut, glued and compared:
--
--  * Lemma_Fold_Split: folding A + B blocks is folding A blocks and then
--    B more from the hash value reached (the fold-append lemma);
--  * Lemma_Fold_Ext: folds over equal bytes from equal hash values are
--    equal;
--  * Lemma_Foldl_Parse: Fold_Blocks over a padded message is the
--    Foldl_Step over Parse_Bytes that Hash_Bytes is stated with.
--
--  The extensionality lemmas are needed because Ada's array "=" is not
--  the provers' logical equality: equal arguments give equal results of
--  Step only through Step's definition (SHA256_Bytes.Lemma_Foldl_Step3_Ext).
--
--  Everything here is ghost. This is not part of the spec layer, which
--  mirrors the Cryptol: it is proof scaffolding for the implementation.

with Interfaces;
with Foundation_Spark.SHA2.SHA256;
with Foundation_Spark.SHA2.SHA256_Bytes;

package Foundation_Spark.SHA2.SHA256_Blocks with
  SPARK_Mode,
  Ghost
is

   use type Interfaces.Unsigned_8;
   use type SHA256_Bytes.Byte_Index;

   Max_Blocks : constant := 2 ** 56;
   --  A bound on the number of blocks folded, above any message's:
   --  Max_Bytes / 64 = 2 ** 55, plus the padding's blocks. It keeps byte
   --  offsets of blocks within Byte_Index.

   subtype Offset is SHA256_Bytes.Byte_Index'Base;
   --  A byte position that may be one past the last byte of an array
   --  ending at Byte_Index'Last: where a fold of no blocks starts.

   function Fits
     (M : SHA256_Bytes.Byte_Array; F : Offset; K : Bit_Index) return Boolean
   is
     (K <= Max_Blocks
      and then F >= M'First
      and then F <= M'First + Offset (M'Length)
      and then 64 * Offset (K) <= M'First + Offset (M'Length) - F);
   --  Whether K whole blocks of M start at byte F.
   --  @param M The bytes.
   --  @param F The position of the first block's first byte.
   --  @param K The number of blocks.
   --  @return Whether bytes F .. F + 64 * K - 1 are all in M.

   function Block_From (M : SHA256_Bytes.Byte_Array; F : Offset)
     return SHA256.Block
   is ([for J in 0 .. 15 =>
         SHA256_Bytes.Word_At (M, F + 4 * SHA256_Bytes.Byte_Index (J))])
   with
     Pre => M'Length >= 64 and then F >= M'First and then F <= M'Last - 63;
   --  The 64 bytes of M from F as a message block [FIPS-PUB-180-4 Section
   --  5.2.1]: word J is the big-endian word at byte F + 4 * J, as
   --  SHA256_Bytes.Block_At reads block I from byte 64 * I.
   --  @param M The bytes.
   --  @param F The position of the block's first byte.
   --  @return The block.

   function Fold_Blocks
     (H : SHA256.Hash_Value;
      M : SHA256_Bytes.Byte_Array;
      F : Offset;
      K : Bit_Index) return SHA256.Hash_Value
   is
     (if K = 0 then H
      else
        SHA256.Step
          (Fold_Blocks (H, M, F, K - 1),
           Block_From (M, F + 64 * Offset (K - 1))))
   with
     Pre                => Fits (M, F, K),
     Subprogram_Variant => (Decreases => K);
   --  `foldl step H` (Main.cry:61) over the K blocks of M from byte F: the
   --  first K - 1 of them folded, then Step on block K - 1, which starts
   --  at byte F + 64 * (K - 1).
   --  @param H The initial hash value.
   --  @param M The bytes.
   --  @param F The position of the first block's first byte.
   --  @param K The number of blocks folded.
   --  @return The hash value after the K blocks.

   procedure Lemma_Step_Ext (H1, H2 : SHA256.Hash_Value; B1, B2 : SHA256.Block)
   with
     Pre  => H1 = H2 and then B1 = B2,
     Post => SHA256.Step (H1, B1) = SHA256.Step (H2, B2);
   --  Step, Main.cry's `step` (Main.cry:67), of equal hash values and
   --  equal blocks is equal.
   --  @param H1 A hash value.
   --  @param H2 A hash value equal to H1.
   --  @param B1 A block.
   --  @param B2 A block equal to B1.

   procedure Lemma_Block_Ext
     (M1 : SHA256_Bytes.Byte_Array;
      F1 : Offset;
      M2 : SHA256_Bytes.Byte_Array;
      F2 : Offset)
   with
     Pre  =>
       M1'Length >= 64
       and then F1 >= M1'First
       and then F1 <= M1'Last - 63
       and then M2'Length >= 64
       and then F2 >= M2'First
       and then F2 <= M2'Last - 63
       and then (for all I in 0 .. 63 =>
                   M1 (F1 + Offset (I)) = M2 (F2 + Offset (I))),
     Post => Block_From (M1, F1) = Block_From (M2, F2);
   --  The blocks read from 64 equal bytes are equal, wherever the bytes
   --  sit in their arrays.
   --  @param M1 The first bytes.
   --  @param F1 The position of the block in M1.
   --  @param M2 The second bytes.
   --  @param F2 The position of the block in M2.

   procedure Lemma_Fold_Ext
     (H1, H2 : SHA256.Hash_Value;
      M1     : SHA256_Bytes.Byte_Array;
      F1     : Offset;
      M2     : SHA256_Bytes.Byte_Array;
      F2     : Offset;
      K      : Bit_Index)
   with
     Pre                =>
       H1 = H2
       and then Fits (M1, F1, K)
       and then Fits (M2, F2, K)
       and then
         (for all I in 0 .. 64 * Offset (K) - 1 =>
            M1 (F1 + I) = M2 (F2 + I)),
     Post               =>
       Fold_Blocks (H1, M1, F1, K) = Fold_Blocks (H2, M2, F2, K),
     Subprogram_Variant => (Decreases => K);
   --  Folds over K blocks of equal bytes, from equal hash values, are
   --  equal, wherever the bytes sit in their arrays. By induction on K,
   --  with Lemma_Step_Ext for each block.
   --  @param H1 A hash value.
   --  @param H2 A hash value equal to H1.
   --  @param M1 The first bytes.
   --  @param F1 The position of the first block in M1.
   --  @param M2 The second bytes.
   --  @param F2 The position of the first block in M2.
   --  @param K The number of blocks folded.

   procedure Lemma_Fold_Split
     (H : SHA256.Hash_Value;
      M : SHA256_Bytes.Byte_Array;
      F : Offset;
      A : Bit_Index;
      B : Bit_Index)
   with
     Pre                =>
       A <= Max_Blocks
       and then B <= Max_Blocks
       and then Fits (M, F, A + B),
     Post               =>
       Fold_Blocks (H, M, F, A + B)
       = Fold_Blocks
           (Fold_Blocks (H, M, F, A),
            M,
            F + 64 * Offset (A),
            B),
     Subprogram_Variant => (Decreases => B);
   --  The fold-append lemma: folding the first A + B blocks from F is
   --  folding the first A and then the B after them, from the hash value
   --  the first A reach. By induction on B: B = 0 is the definition, and
   --  each further block is one more Step on both sides.
   --  @param H The initial hash value.
   --  @param M The bytes.
   --  @param F The position of the first block's first byte.
   --  @param A The number of blocks folded first.
   --  @param B The number of blocks folded after them.

   procedure Lemma_Foldl_Parse
     (H : SHA256.Hash_Value; P : SHA256_Bytes.Byte_Array; Nb, N : Bit_Index)
   with
     Pre                =>
       P'First = 0
       and then Nb <= Max_Blocks
       and then P'Length = 64 * Nb
       and then N <= Nb,
     Post               =>
       SHA256.Foldl_Step (H, SHA256_Bytes.Parse_Bytes (P, Nb), N)
       = Fold_Blocks (H, P, 0, N),
     Subprogram_Variant => (Decreases => N);
   --  Folding Step over the first N blocks of Parse_Bytes (P, Nb), as
   --  Hash_Bytes does, is Fold_Blocks over the first N blocks of P's
   --  bytes. By induction on N.
   --  @param H The initial hash value.
   --  @param P The padded message, 64 * Nb bytes, indexed from 0.
   --  @param Nb The number of blocks in P.
   --  @param N The number of blocks folded.

   procedure Lemma_Block_Parse (M : SHA256_Bytes.Byte_Array; F : Offset)
   with
     Pre  => M'Length >= 64 and then F >= M'First and then F <= M'Last - 63,
     Post =>
       Block_From (M, F)
       = SHA256.Parse (SHA256_Bytes.Bits_Of (M (F .. F + 63)), 1) (0);
   --  The 64 bytes of M from F, read as a block, are Preprocessing.cry's
   --  `parse`{32, 1}` (Preprocessing.cry:47) of their bits: word J of the
   --  block is the 32 bits that `split` cuts at 32 * J. Block_From is
   --  `parse` one block at a time, on bytes.
   --  @param M The bytes.
   --  @param F The position of the block's first byte.

end Foundation_Spark.SHA2.SHA256_Blocks;
