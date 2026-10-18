--  The executable AES block cipher on bytes, the implementation of
--  algorithms/AES/Main.cry's AES`{k}.Encrypt and Decrypt [FIPS-PUB-197
--  Section 5]: the key schedule (Impl.Expand_Key) of the key's words, then
--  one block encrypted (Impl.Encrypt_Block) or decrypted
--  (Impl.Decrypt_Block).
--
--  Main.cry's Encrypt and Decrypt take a key [k] and a block [128] as bit
--  sequences, which the spec layer (Spec.Main) states over ghost Bits. The
--  implementation stops at bytes: a key is its k / 8 bytes (Key_Bytes) and
--  a block its 16 (Types.Block), and each postcondition says that the
--  bits of the result are the spec's Encrypt or Decrypt of the bits of the
--  key and the block, with Cryptol's join (Join_Key, Spec.Main.Join_Block)
--  between the two. This is a representation change, so it is not part of
--  the spec layer.
--
--  Key sizes. As in Impl, one unconstrained implementation serves k = 128,
--  192 and 256, with the key size K as an explicit parameter and
--  Is_Key_Bytes as the precondition.
--
--  Nothing executable here calls ghost code: Join_Key and the spec appear
--  only in contracts, and the proof's lemmas (AES.Main_Lemmas) only in
--  ghost statements.

with Foundation_Spark.AES.Spec.Main;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.AES.Impl.Main with
  SPARK_Mode,
  Pure
is

   use type Spec.Main.Bit_Index;
   use type Spec.Main.Bits;

   subtype Key_Byte_Index is Natural range 0 .. 31;
   --  The indices a Key_Bytes may use: k / 8 is at most 32.

   type Key_Bytes is array (Key_Byte_Index range <>) of Byte;
   --  A cipher key as bytes, the Cryptol [k / 8][8]: Main.cry's key : [k]
   --  as split cuts it, byte 0 first. Its length is fixed by K through
   --  Is_Key_Bytes.

   function Is_Key_Bytes (K : Natural; Key : Key_Bytes) return Boolean
   is (Spec.Types.Key (K) and then Key'First = 0
       and then Key'Length = K / 8);
   --  The typing key : [k / 8][8] under the constraint Key k, with
   --  Cryptol's zero-based indexing.
   --  @param K The key size in bits.
   --  @param Key The key bytes.
   --  @return Whether K is a key size and Key has K / 8 bytes from index 0.

   function Join_Key (Key : Key_Bytes) return Spec.Main.Bits
   is [for N in 0 .. 8 * Spec.Main.Bit_Index (Key'Length) - 1 =>
         Spec.Main.Bit_Of (Key (Natural (N / 8)), Natural (N mod 8))]
   with
     Ghost,
     Pre => Key'First = 0;
   --  Cryptol's join at type [k / 8][8] -> [k], the key's bits: bit N is
   --  bit N mod 8 of byte N / 8, most significant first, as
   --  Spec.Main.Join_Block joins a block.
   --  @param Key The key bytes, from index 0.
   --  @return Their 8 * Key'Length bits, indexed from 0.

   function Key_Words_Of (K : Natural; Key : Key_Bytes) return Key_Words
   with
     Pre  => Is_Key_Bytes (K, Key),
     Post =>
       Is_Key_Words (K, Key_Words_Of'Result)
       and then
         (for all J in 0 .. Nk (K) - 1 =>
            (for all I in AESWord_Index =>
               Key_Words_Of'Result (J) (I) = Key (4 * J + I)));
   --  The key's bytes as Nk (K) words, four bytes to a word: Main.cry's
   --  split (split key) at [k] -> [Nk k][4][8], on bytes.
   --  @param K The key size in bits: 128, 192 or 256.
   --  @param Key The key, K / 8 bytes.
   --  @return The key words.

   function Encrypt (K : Natural; Key : Key_Bytes; Input : Block)
     return Block
   with
     Pre  => Is_Key_Bytes (K, Key),
     Post =>
       Spec.Main.Join_Block (Encrypt'Result)
       = Spec.Main.Encrypt (K, Join_Key (Key), Spec.Main.Join_Block (Input));
   --  AES encryption of one block [FIPS-PUB-197 Section 5.1]: Expand_Key
   --  of the key's words, then Encrypt_Block. Proved equal, on the bits,
   --  to Main.cry's AES`{k}.Encrypt.
   --  @param K The key size in bits: 128, 192 or 256.
   --  @param Key The key, K / 8 bytes.
   --  @param Input The plaintext block.
   --  @return The ciphertext block.

   function Decrypt (K : Natural; Key : Key_Bytes; Input : Block)
     return Block
   with
     Pre  => Is_Key_Bytes (K, Key),
     Post =>
       Spec.Main.Join_Block (Decrypt'Result)
       = Spec.Main.Decrypt (K, Join_Key (Key), Spec.Main.Join_Block (Input));
   --  AES decryption of one block [FIPS-PUB-197 Section 5.3]: Expand_Key
   --  of the key's words, then Decrypt_Block. Proved equal, on the bits,
   --  to Main.cry's AES`{k}.Decrypt.
   --  @param K The key size in bits: 128, 192 or 256.
   --  @param Key The key, K / 8 bytes.
   --  @param Input The ciphertext block.
   --  @return The plaintext block.

end Foundation_Spark.AES.Impl.Main;
