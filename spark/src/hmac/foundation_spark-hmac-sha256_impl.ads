--  The executable HMAC-SHA-256 [FIPS-PUB-198-1 Section 4], over bytes,
--  proved equal to the spec layer's HMAC.SHA256.HMAC (algorithms/HMAC/
--  Main.cry's `HMAC`, instantiated by packaging/Hash.cry at SHA-256) on
--  the bits of its key, text and MAC. This is a representation change
--  (bytes for bits, streaming for whole-message hashing), so it is not
--  part of the spec layer, which mirrors the Cryptol.
--
--  The MAC is computed with M2.4's streaming SHA-256 (SHA2.SHA256_Stream)
--  as FIPS 198-1 describes it: the key is brought to one 64-byte block
--  K0 (Init_Key, Steps 1 to 3), an inner context hashes K0 xor ipad and
--  then the text (Steps 4 to 6), and an outer context hashes K0 xor opad
--  and then the inner digest (Steps 7 to 9). The text is never copied:
--  the inner context consumes it in place.
--
--  The proof composes SHA256_Stream's streaming theorem (Lemma_Update and
--  Lemma_Final: the contexts compute Hash_Bytes of what they were fed),
--  #35's Lemma_Hash_Bytes (Hash_Bytes is SHA256.Hash on the bits), and
--  extensionality: Ada's array "=" is not the provers' equality, so
--  SHA256.Hash of two bit sequences that are "=" is shown "=" by a lemma
--  in the body.

with Foundation_Spark.HMAC.SHA256;
with Foundation_Spark.SHA2.SHA256_Bytes;
with Foundation_Spark.SHA2.SHA256_Stream;

package Foundation_Spark.HMAC.SHA256_Impl with
  SPARK_Mode
is

   use type SHA2.Bits;
   use type SHA2.SHA256_Bytes.Byte_Index;

   subtype Byte_Array is SHA2.SHA256_Bytes.Byte_Array;
   --  The bytes of a key, a text or a MAC, as SHA2.SHA256_Stream takes
   --  and returns them.

   subtype Digest is SHA2.SHA256_Bytes.Digest;
   --  A full HMAC-SHA-256 MAC, 32 bytes (λ = 256 bits).

   subtype Key_Block is Byte_Array (0 .. 63);
   --  A key brought to SHA-256's block size B = 64 bytes: FIPS 198-1's
   --  K0, Main.cry's `HMAC_init Hk K`.

   Max_Text : constant := SHA2.SHA256_Bytes.Max_Bytes - 64;
   --  The bound on a text's length in bytes: a text has fewer than
   --  Max_Text bytes. It is Main.cry's `n < 2 ^^ B - 8 * B` (Main.cry:31)
   --  at B = 64, in bytes, and also what keeps the inner hash's message
   --  (64 + n bytes) below SHA-256's 2 ** 61 bytes.

   function To_Bytes (M : Byte_Array) return Bytes is
     ([for I in 0 .. Byte_Index (M'Length) - 1 =>
         M (M'First + SHA2.SHA256_Bytes.Byte_Index (I))])
   with
     Ghost,
     Pre  => M'Length <= SHA2.SHA256_Bytes.Max_Bytes,
     Post => To_Bytes'Result'First = 0
             and then To_Bytes'Result'Length = M'Length;
   --  A byte array as the spec layer's `[k][8]` (HMAC.Bytes), indexed
   --  from 0: the same bytes in the same order.
   --  @param M The bytes.
   --  @return M's bytes, indexed from 0.

   function Init_Key (Key : Byte_Array) return Key_Block with
     Pre  => Key'Length < SHA2.SHA256_Bytes.Max_Bytes,
     Post =>
       SHA2.SHA256_Bytes.Bits_Of (Init_Key'Result)
       = HMAC.SHA256.HMAC_init (To_Bytes (Key));
   --  The key preprocessing, Steps 1 to 3 of [FIPS-PUB-198-1 Section 4]:
   --  a key of 64 bytes is K0 as it is, a longer key is hashed with
   --  SHA-256 and its 32-byte digest padded with zeros, and a shorter key
   --  is padded with zeros. Proved equal, on the bits, to the spec's
   --  HMAC_init (Main.cry:56).
   --  @param Key The key, of any length below 2 ** 61 bytes.
   --  @return K0, the key as one 64-byte block.

   function HMAC_SHA256 (Key : Byte_Array; Text : Byte_Array) return Digest
   with
     Pre  =>
       Key'Length < SHA2.SHA256_Bytes.Max_Bytes
       and then Text'Length < Max_Text,
     Post =>
       SHA2.SHA256_Bytes.Bits_Of (HMAC_SHA256'Result)
       = HMAC.SHA256.HMAC
           (To_Bytes (Key), SHA2.SHA256_Bytes.Bits_Of (Text), 256);
   --  HMAC-SHA-256 [FIPS-PUB-198-1 Section 4] with the full 256-bit MAC,
   --  through two streaming SHA-256 contexts: the inner one hashes
   --  K0 xor ipad and then Text, the outer one K0 xor opad and then the
   --  inner digest. Proved equal, on the bits, to the spec's HMAC
   --  (Main.cry:40) at λ = 256, packaging/Hash.cry's `HMAC` (Hash.cry:71)
   --  at SHA-256.
   --  @param Key The key, of any length below 2 ** 61 bytes.
   --  @param Text The message, of fewer than Max_Text bytes.
   --  @return The 32-byte MAC.

   --  The incremental interface: Init with the key, Update with the text
   --  in any number of pieces, and Final. As in SHA2.SHA256_Stream, a
   --  context does not hold its key or text (GNAT 16 has no ghost record
   --  components), so Init and Update are specified on contexts, and the
   --  ghost lemmas Lemma_Update and Lemma_Final carry the key and the text
   --  to the spec: call Lemma_Update after each Update, and Lemma_Final
   --  before Final.

   type Context is private;
   --  An HMAC-SHA-256 computation in progress: the inner SHA-256 context,
   --  fed K0 xor ipad and the text so far, and K0 xor opad for Final.

   function Count (C : Context) return SHA2.SHA256_Bytes.Byte_Index;
   --  The number of bytes the inner hash has absorbed: the 64 of K0 xor
   --  ipad, and then the text's.
   --  @param C The context.
   --  @return Its byte count.

   function Models
     (C : Context; Key : Byte_Array; M : Byte_Array) return Boolean
   with
     Ghost,
     Pre => Key'Length < SHA2.SHA256_Bytes.Max_Bytes;
   --  C is HMAC-SHA-256 under Key after the text M: its inner hash has
   --  absorbed K0 xor ipad and then M, and it holds K0 xor opad.
   --  @param C The context.
   --  @param Key The key.
   --  @param M The text absorbed so far.
   --  @return Whether C is that computation.

   function Absorbed
     (C0 : Context; Data : Byte_Array; C1 : Context) return Boolean
   with
     Ghost,
     Pre => Data'Length < SHA2.SHA256_Bytes.Max_Bytes;
   --  C1 is C0 after the bytes Data.
   --  @param C0 The context before.
   --  @param Data The bytes absorbed.
   --  @param C1 The context after.
   --  @return Whether C1 is C0 after Data.

   procedure Init (C : out Context; Key : Byte_Array) with
     Pre  => Key'Length < SHA2.SHA256_Bytes.Max_Bytes,
     Post =>
       Models (C, Key, SHA2.SHA256_Stream.Empty) and then Count (C) = 64;
   --  Starts HMAC-SHA-256 under Key: K0 (Init_Key), and an inner SHA-256
   --  context fed K0 xor ipad.
   --  @param C The context started.
   --  @param Key The key, of any length below 2 ** 61 bytes.

   procedure Update (C : in out Context; Data : Byte_Array) with
     Pre  =>
       Count (C) < SHA2.SHA256_Bytes.Max_Bytes
       and then Data'Length < SHA2.SHA256_Bytes.Max_Bytes - Count (C),
     Post =>
       Absorbed (C'Old, Data, C)
       and then Count (C) = Count (C'Old) + Data'Length;
   --  Absorbs the next bytes of the text.
   --  @param C The context.
   --  @param Data The bytes.

   function Finished (C : Context; D : Digest) return Boolean with
     Ghost,
     Pre => Count (C) < SHA2.SHA256_Bytes.Max_Bytes;
   --  D is the outer hash of C: SHA-256 of C's K0 xor opad followed by
   --  the digest of C's inner context.
   --  @param C The context.
   --  @param D A digest.
   --  @return Whether D is C's outer hash.

   function Final (C : Context) return Digest with
     Pre  => Count (C) < SHA2.SHA256_Bytes.Max_Bytes,
     Post => Finished (C, Final'Result);
   --  The MAC of the text absorbed so far: the outer SHA-256 of K0 xor
   --  opad and the inner digest. C is not changed.
   --  @param C The context.
   --  @return The 32-byte MAC.

   procedure Lemma_Update
     (C0   : Context;
      Data : Byte_Array;
      C1   : Context;
      Key  : Byte_Array;
      M    : Byte_Array;
      M2   : Byte_Array)
   with
     Ghost,
     Pre  =>
       Key'Length < SHA2.SHA256_Bytes.Max_Bytes
       and then Data'Length < SHA2.SHA256_Bytes.Max_Bytes
       and then M2'Length < Max_Text
       and then Models (C0, Key, M)
       and then Absorbed (C0, Data, C1)
       and then M2'Length = M'Length + Data'Length
       and then
         (for all I in 0 .. SHA2.SHA256_Bytes.Byte_Index (M'Length) - 1 =>
            M2 (M2'First + I) = M (M'First + I))
       and then
         (for all I in 0 .. SHA2.SHA256_Bytes.Byte_Index (Data'Length) - 1 =>
            M2 (M2'First + SHA2.SHA256_Bytes.Byte_Index (M'Length) + I)
            = Data (Data'First + I)),
     Post => Models (C1, Key, M2);
   --  Update extends the text: a context for M, after Data, is one for
   --  M2, which is M then Data.
   --  @param C0 The context before Update.
   --  @param Data The bytes Update absorbed.
   --  @param C1 The context after.
   --  @param Key The key.
   --  @param M The text before.
   --  @param M2 M then Data.

   procedure Lemma_Final (C : Context; Key : Byte_Array; M : Byte_Array) with
     Ghost,
     Pre  =>
       Key'Length < SHA2.SHA256_Bytes.Max_Bytes and then Models (C, Key, M),
     Post =>
       M'Length < Max_Text
       and then Count (C) < SHA2.SHA256_Bytes.Max_Bytes
       and then
         SHA2.SHA256_Bytes.Bits_Of (Final (C))
         = HMAC.SHA256.HMAC
             (To_Bytes (Key), SHA2.SHA256_Bytes.Bits_Of (M), 256);
   --  Final of a context for Key and M is the spec's HMAC of them, on
   --  the bits, at λ = 256.
   --  @param C The context.
   --  @param Key The key.
   --  @param M The text it has absorbed.

private

   type Context is record
      Inner : SHA2.SHA256_Stream.Context;
      O_Pad : Key_Block;
   end record;
   --  The inner SHA-256 context, and K0 xor opad for the outer hash.
   --  @field Inner The inner hash, fed K0 xor ipad and then the text.
   --  @field O_Pad K0 xor opad.

   function Count (C : Context) return SHA2.SHA256_Bytes.Byte_Index is
     (SHA2.SHA256_Stream.Count (C.Inner));

end Foundation_Spark.HMAC.SHA256_Impl;
