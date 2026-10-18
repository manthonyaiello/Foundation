--  The AES block cipher over bit vectors, mirroring algorithms/AES/Main.cry
--  [FIPS-PUB-197 Section 5]: the record AES`{k} of Encrypt and Decrypt, and
--  its instances AES128, AES192 and AES256.
--
--  Main.cry's Encrypt and Decrypt take a key [k] and a block [128] as bit
--  sequences. Following the campaign's decision on bit sequences, a bit
--  sequence is a ghost Boolean array (Bits) with a 128-bit integer index,
--  and Cryptol's join and split between [128] and Block, and between [k]
--  and [Nk k]AESWord, are stated here over it. Cryptol sequences are
--  big-endian: bit 0 of a [8] is the most significant bit of the Byte, and
--  byte 0 of a [128] is its first eight bits.
--
--  The record AES`{k} has no SPARK counterpart: AES`{k}.Encrypt is
--  Encrypt (K, ...) with the key size K explicit, as for Cipher, and
--  AES128.Encrypt is AES128.Encrypt, a nested package that fixes K.
--  Main.cry's property EncryptInverts (M1.5) is not stated here.

with Foundation_Spark.AES.Spec.Cipher;
with Foundation_Spark.AES.Spec.KeyExpansion;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.AES.Spec.Main with
  SPARK_Mode,
  Pure,
  Ghost
is

   use Types;

   use type Types.Byte;

   type Bit_Index is range 0 .. 2 ** 127 - 1;
   --  The index of a bit sequence: a 128-bit integer, per the campaign's
   --  decision on bit sequences, so that the length of any sequence below
   --  2 ** 64 bits, and arithmetic on its indices, cannot overflow.

   type Bits is array (Bit_Index range <>) of Boolean;
   --  A Cryptol bit sequence [n], indexed from 0 as Cryptol's @ indexes
   --  it. Element 0 is the Cryptol's first (most significant) bit.

   subtype Block_Bits is Bits (0 .. 127);
   --  Main.cry's [128], a block as a bit vector: the in and the result of
   --  Encrypt and Decrypt.

   function Is_Key_Bits (K : Natural; Key : Bits) return Boolean
   is (Types.Key (K) and then Key'First = 0
       and then Key'Last = Bit_Index (K - 1));
   --  The typing key : [k] under the constraint Key k, with Cryptol's
   --  zero-based indexing.
   --  @param K The key size in bits.
   --  @param Key The key bits.
   --  @return Whether K is a key size and Key has K bits from index 0.

   function Byte_At (Bs : Bits; From : Bit_Index) return Byte
   is ((if Bs (From) then 16#80# else 0)
       or (if Bs (From + 1) then 16#40# else 0)
       or (if Bs (From + 2) then 16#20# else 0)
       or (if Bs (From + 3) then 16#10# else 0)
       or (if Bs (From + 4) then 16#08# else 0)
       or (if Bs (From + 5) then 16#04# else 0)
       or (if Bs (From + 6) then 16#02# else 0)
       or (if Bs (From + 7) then 16#01# else 0))
   with Pre => Bs'Last >= 7 and then From >= Bs'First
               and then From <= Bs'Last - 7;
   --  The [8] at bits From .. From + 7 of Bs as a Byte, big-endian: the
   --  element type of Cryptol's split at [n * 8] -> [n][8], which takes
   --  byte J of the result from bits 8 * J .. 8 * J + 7.
   --  @param Bs The bit sequence.
   --  @param From The index of the byte's first (most significant) bit.
   --  @return The eight bits as a Byte.

   function Bit_Of (B : Byte; J : Natural) return Boolean
   is ((B and 2 ** (7 - J)) /= 0)
   with Pre => J <= 7;
   --  Bit J of a [8], big-endian: bit 0 is the most significant. The
   --  element type of Cryptol's join at [n][8] -> [n * 8], which places
   --  byte I at bits 8 * I .. 8 * I + 7.
   --  @param B The byte.
   --  @param J The bit's position in the Cryptol [8], 0 .. 7.
   --  @return Bit J of B.

   function Split_Block (Bs : Block_Bits) return Block
   is [for I in Block_Index => Byte_At (Bs, Bit_Index (8 * I))];
   --  Main.cry: split in, Cryptol's split at [128] -> [16][8] = Block.
   --  Byte I is bits 8 * I .. 8 * I + 7.
   --  @param Bs The block as 128 bits.
   --  @return The block as 16 bytes.

   function Join_Block (B : Block) return Block_Bits
   is [for N in Block_Bits'Range =>
         Bit_Of (B (Natural (N / 8)), Natural (N mod 8))];
   --  Main.cry: join (Cipher`{k} ...), Cryptol's join at Block = [16][8]
   --  -> [128], the inverse of Split_Block. Bit N is bit N mod 8 of byte
   --  N / 8.
   --  @param B The block as 16 bytes.
   --  @return The block as 128 bits.

   function Split_Key (K : Natural; Key : Bits) return Key_Words
   is [for J in 0 .. Nk (K) - 1 => [for I in AESWord_Index => Byte_At
                                      (Key, Bit_Index (32 * J + 8 * I))]]
   with
     Pre  => Is_Key_Bits (K, Key),
     Post => Is_Key_Words (K, Split_Key'Result);
   --  Main.cry: split (split key), Cryptol's split twice at [k] ->
   --  [Nk k][32] -> [Nk k][4][8] = [Nk k]AESWord. Byte I of word J is
   --  bits 32 * J + 8 * I .. 32 * J + 8 * I + 7.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Key The key as K bits.
   --  @return The key as Nk (K) words.

   function Encrypt (K : Natural; Key : Bits; Input : Block_Bits)
     return Block_Bits
   is (Join_Block
         (Cipher.Cipher
            (K, KeyExpansion.KeyExpansion (K, Split_Key (K, Key)),
             Split_Block (Input))))
   with Pre => Is_Key_Bits (K, Key);
   --  Main.cry: AES`{k}.Encrypt : [k] -> [128] -> [128], Encrypt key in =
   --  join (Cipher`{k} (KeyExpansion`{k} (split (split key))) (split in))
   --  [FIPS-PUB-197 Section 5]. The Cryptol's in is Input: in is an Ada
   --  reserved word.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Key The key as K bits.
   --  @param Input The plaintext block as 128 bits.
   --  @return The ciphertext block as 128 bits.

   function Decrypt (K : Natural; Key : Bits; Input : Block_Bits)
     return Block_Bits
   is (Join_Block
         (Cipher.InvCipher
            (K, KeyExpansion.KeyExpansion (K, Split_Key (K, Key)),
             Split_Block (Input))))
   with Pre => Is_Key_Bits (K, Key);
   --  Main.cry: AES`{k}.Decrypt : [k] -> [128] -> [128], Decrypt key in =
   --  join (InvCipher`{k} (KeyExpansion`{k} (split (split key))) (split
   --  in)) [FIPS-PUB-197 Section 5].
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Key The key as K bits.
   --  @param Input The ciphertext block as 128 bits.
   --  @return The plaintext block as 128 bits.

   package AES128 is
      --  Main.cry: AES128 = AES`{128}, the AES-128 block cipher
      --  [FIPS-PUB-197 Section 5].

      subtype Key_Bits is Bits (0 .. 127);
      --  The key type [128] of AES`{128}.

      function Encrypt (Key : Key_Bits; Input : Block_Bits) return Block_Bits
      is (Main.Encrypt (128, Key, Input));
      --  Main.cry: AES128.Encrypt, AES`{128}.Encrypt.
      --  @param Key The 128-bit key.
      --  @param Input The plaintext block.
      --  @return The ciphertext block.

      function Decrypt (Key : Key_Bits; Input : Block_Bits) return Block_Bits
      is (Main.Decrypt (128, Key, Input));
      --  Main.cry: AES128.Decrypt, AES`{128}.Decrypt.
      --  @param Key The 128-bit key.
      --  @param Input The ciphertext block.
      --  @return The plaintext block.

   end AES128;

   package AES192 is
      --  Main.cry: AES192 = AES`{192}, the AES-192 block cipher
      --  [FIPS-PUB-197 Section 5].

      subtype Key_Bits is Bits (0 .. 191);
      --  The key type [192] of AES`{192}.

      function Encrypt (Key : Key_Bits; Input : Block_Bits) return Block_Bits
      is (Main.Encrypt (192, Key, Input));
      --  Main.cry: AES192.Encrypt, AES`{192}.Encrypt.
      --  @param Key The 192-bit key.
      --  @param Input The plaintext block.
      --  @return The ciphertext block.

      function Decrypt (Key : Key_Bits; Input : Block_Bits) return Block_Bits
      is (Main.Decrypt (192, Key, Input));
      --  Main.cry: AES192.Decrypt, AES`{192}.Decrypt.
      --  @param Key The 192-bit key.
      --  @param Input The ciphertext block.
      --  @return The plaintext block.

   end AES192;

   package AES256 is
      --  Main.cry: AES256 = AES`{256}, the AES-256 block cipher
      --  [FIPS-PUB-197 Section 5].

      subtype Key_Bits is Bits (0 .. 255);
      --  The key type [256] of AES`{256}.

      function Encrypt (Key : Key_Bits; Input : Block_Bits) return Block_Bits
      is (Main.Encrypt (256, Key, Input));
      --  Main.cry: AES256.Encrypt, AES`{256}.Encrypt.
      --  @param Key The 256-bit key.
      --  @param Input The plaintext block.
      --  @return The ciphertext block.

      function Decrypt (Key : Key_Bits; Input : Block_Bits) return Block_Bits
      is (Main.Decrypt (256, Key, Input));
      --  Main.cry: AES256.Decrypt, AES`{256}.Decrypt.
      --  @param Key The 256-bit key.
      --  @param Input The ciphertext block.
      --  @return The plaintext block.

   end AES256;

end Foundation_Spark.AES.Spec.Main;
