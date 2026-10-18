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

end Foundation_Spark.HMAC.SHA256_Impl;
