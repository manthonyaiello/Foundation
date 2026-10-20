--  The {k} functions of algorithms/AES, generic in the key size as the
--  Cryptol is polymorphic in it: {k} (Key k) => ... They are
--  KeyExpansion (KeyExpansion.cry), Cipher, InvCipher and InvCipher'
--  (Cipher.cry), and Main.cry's AES`{k}, the record of Encrypt and
--  Decrypt (issue #80, from spike #74).
--
--  The formal K is the Cryptol's k, and its subtype Types.Key_Size is the
--  constraint Key k. The Cryptol's [Nk k]AESWord, [Nr k + 1]Block and [k]
--  are the subtypes Key_Words, Round_Keys and Key_Bits below: the lengths
--  are in the types, so each function takes the Cryptol's arguments and
--  has no precondition. The instances AES128, AES192 and AES256 are the
--  Cryptol's type applications `{128}, `{192} and `{256}, and Main.cry's
--  AES128 = AES`{128} is the instance AES128: AES128.Encrypt is
--  Main.cry's AES128.Encrypt. Spec.Dispatch selects an instance by a
--  run-time K, for the implementation, which stays flexible in K.
--
--  Everything without a {k} (Round, the S-boxes, GF(2^8), RotWord, SubWord,
--  Rcon, the folds, Main.cry's split and join of a block) stays in its
--  non-generic unit and is proved once.
--
--  @formal K The key size in bits, the Cryptol's k: 128, 192 or 256.

with Foundation_Spark.AES.Spec.Cipher;
with Foundation_Spark.AES.Spec.KeyExpansion;
with Foundation_Spark.AES.Spec.Main;
with Foundation_Spark.AES.Spec.Types;

generic
   K : Types.Key_Size;
package Foundation_Spark.AES.Spec.AES_K with
  SPARK_Mode,
  Pure,
  Ghost
is

   use Types;
   use KeyExpansion;
   use Spec.Cipher;
   use Main;

   Nk : constant Positive := Types.Nk (K);
   --  KeyExpansion.cry: Nk = `(Nk k), the number of words in the key.
   --  A static constant: GNAT 16.1 crashes (sem_type.adb:825) on a call
   --  of the static function Types.Nk inside an expression function of an
   --  instance, so the bodies below read this constant instead.

   Nr : constant Positive := Types.Nr (K);
   --  Types.cry: Nr k, the number of rounds, as a static constant (see Nk).

   subtype Key_Words is Types.Key_Words (0 .. Nk - 1);
   --  Types.cry's [Nk k]AESWord at this k: the cipher key as words.

   subtype Round_Keys is Types.Round_Keys (0 .. Nr);
   --  Types.cry's [Nr k + 1]Block at this k: the key schedule.

   subtype Word_Index is Natural range 0 .. 4 * (Nr + 1) - 1;
   --  KeyExpansion.cry's i <- [0 ..< 4 * (Nr k + 1)], the indices of w.

   function W (Key : Key_Words; I : Word_Index) return AESWord
   is (if I < Nk then Key (I)
       elsif I mod Nk = 0
       then W (Key, I - Nk) xor SubWord (RotWord (W (Key, I - 1)))
            xor Rcon (I / Nk)
       elsif I mod Nk = 4 and then Nk > 6
       then W (Key, I - Nk) xor SubWord (W (Key, I - 1))
       else W (Key, I - Nk) xor W (Key, I - 1))
   with Subprogram_Variant => (Decreases => I);
   --  KeyExpansion.cry: the element w @ i of the expanded key in
   --  KeyExpansion's where clause, case for case: key @ i for i < Nk;
   --  w @ (i - Nk) ^ SubWord (RotWord (w @ (i - 1))) ^ Rcon @ (i / Nk) when
   --  i % Nk == 0; w @ (i - Nk) ^ SubWord (w @ (i - 1)) when i % Nk == 4
   --  and Nk > 6; and w @ (i - Nk) ^ w @ (i - 1) otherwise [FIPS-PUB-197
   --  Section 5.2, Figure 11]. The self-referential sequence w is a
   --  recursive function whose variant is I: each case reads w at smaller
   --  indices only.
   --  @param Key The cipher key, the Cryptol's key : [Nk k]AESWord.
   --  @param I The index of the word.
   --  @return w @ I.

   function KeyExpansion (Key : Key_Words) return Round_Keys
   is [for R in 0 .. Nr => Join ([for J in AESWord_Index =>
                                        W (Key, 4 * R + J)])];
   --  KeyExpansion.cry: KeyExpansion : {k} (Key k) => [Nk k]AESWord ->
   --  [Nr k + 1]Block, KeyExpansion key = split (split (join (join w)))
   --  [FIPS-PUB-197 Section 5.2]. The split and join regroup the
   --  4 * (Nr k + 1) words of w into Nr k + 1 blocks of four consecutive
   --  words: round key R is Join of w @ (4 * R) to w @ (4 * R + 3), in
   --  order.
   --  @param Key The cipher key as Nk words.
   --  @return The Nr + 1 round keys.

   function Cipher (W : Round_Keys; Input : Block) return Block
   is (AddRoundKey (ShiftRows (SubBytes
                      (Foldl_Round (AddRoundKey (Input, W (0)),
                                    W (1 .. Nr - 1)))),
                    W (Nr)));
   --  Cipher.cry: Cipher : {k} (Key k) => [Nr k + 1]Block -> Block ->
   --  Block, AES encryption [FIPS-PUB-197 Section 5.1]. NSA declares it
   --  foreign, with Rust behind it. This mirrors its Cryptol body,
   --  Cipher ([w0] # ws # [wr]) in = state_final, where
   --  state_initial = AddRoundKey in w0,
   --  state_rounds = foldl Round state_initial ws, and
   --  state_final = AddRoundKey (ShiftRows (SubBytes state_rounds)) wr,
   --  with w0 = W (0), ws = W (1 .. Nr - 1) and wr = W (Nr). The
   --  Cryptol's in is Input: in is an Ada reserved word.
   --  @param W The Nr + 1 round keys, the Cryptol's [Nr k + 1]Block.
   --  @param Input The plaintext block.
   --  @return The ciphertext block.

   function InvCipher (W : Round_Keys; Input : Block) return Block
   is (AddRoundKey (InvSubBytes (InvShiftRows
                      (Foldl_InvRound (AddRoundKey (Input, W (Nr)),
                                       Reverse_Keys (W (1 .. Nr - 1))))),
                    W (0)));
   --  Cipher.cry: InvCipher : {k} (Key k) => [Nr k + 1]Block -> Block ->
   --  Block, AES decryption [FIPS-PUB-197 Section 5.3]. NSA declares it
   --  foreign, with Rust behind it. This mirrors its Cryptol body,
   --  InvCipher ([w0] # ws # [wr]) in = state_final, where
   --  state_initial = AddRoundKey in wr,
   --  state_rounds = foldl InvRound state_initial (reverse ws), and
   --  state_final = AddRoundKey (InvSubBytes (InvShiftRows state_rounds))
   --  w0, with w0 = W (0), ws = W (1 .. Nr - 1) and wr = W (Nr).
   --  @param W The Nr + 1 round keys, the Cryptol's [Nr k + 1]Block.
   --  @param Input The ciphertext block.
   --  @return The plaintext block.

   function InvCipher_Prime (W : Round_Keys; Input : Block) return Block
   is (AddRoundKey
         (Foldl_InvRound_Prime
            (InvSubBytes (InvShiftRows (AddRoundKey (Input, W (Nr)))),
             Reverse_Keys (W (1 .. Nr - 1))),
          W (0)));
   --  Cipher.cry: InvCipher' : {k} (Key k) => [Nr k + 1]Block -> Block ->
   --  Block, the alternate decryption that is more obviously the inverse
   --  of Cipher [FIPS-PUB-197 Section 5.3]: InvCipher' ([w0] # ws # [wr])
   --  in = state_final, where
   --  state_initial = InvSubBytes (InvShiftRows (AddRoundKey in wr)),
   --  state_rounds = foldl InvRound' state_initial (reverse ws), and
   --  state_final = AddRoundKey state_rounds w0, with w0, ws and wr as in
   --  Cipher. Ada has no primes in names.
   --  @param W The Nr + 1 round keys, the Cryptol's [Nr k + 1]Block.
   --  @param Input The ciphertext block.
   --  @return The plaintext block.

   subtype Key_Bits is Bits (0 .. Bit_Index (K - 1));
   --  Main.cry's [k] at this k: the key of Encrypt and Decrypt, as bits.

   function Split_Key (Key : Key_Bits) return Key_Words
   is [for J in 0 .. Nk - 1 => [for I in AESWord_Index => Byte_At
                                  (Key, Bit_Index (32 * J + 8 * I))]];
   --  Main.cry: split (split key), Cryptol's split twice at [k] ->
   --  [Nk k][32] -> [Nk k][4][8] = [Nk k]AESWord. Byte I of word J is
   --  bits 32 * J + 8 * I .. 32 * J + 8 * I + 7.
   --  @param Key The key as K bits.
   --  @return The key as Nk words.

   function Encrypt (Key : Key_Bits; Input : Block_Bits) return Block_Bits
   is (Join_Block (Cipher (KeyExpansion (Split_Key (Key)),
                           Split_Block (Input))));
   --  Main.cry: AES`{k}.Encrypt : [k] -> [128] -> [128], Encrypt key in =
   --  join (Cipher`{k} (KeyExpansion`{k} (split (split key))) (split in))
   --  [FIPS-PUB-197 Section 5]. The Cryptol's in is Input: in is an Ada
   --  reserved word.
   --  @param Key The key as K bits.
   --  @param Input The plaintext block as 128 bits.
   --  @return The ciphertext block as 128 bits.

   function Decrypt (Key : Key_Bits; Input : Block_Bits) return Block_Bits
   is (Join_Block (InvCipher (KeyExpansion (Split_Key (Key)),
                              Split_Block (Input))));
   --  Main.cry: AES`{k}.Decrypt : [k] -> [128] -> [128], Decrypt key in =
   --  join (InvCipher`{k} (KeyExpansion`{k} (split (split key))) (split
   --  in)) [FIPS-PUB-197 Section 5].
   --  @param Key The key as K bits.
   --  @param Input The ciphertext block as 128 bits.
   --  @return The plaintext block as 128 bits.

end Foundation_Spark.AES.Spec.AES_K;
