--  The {k} functions of algorithms/AES, generic in the key size as the
--  Cryptol is polymorphic in it: {k} (Key k) => ... Spike #74 makes two of
--  them generic, KeyExpansion (KeyExpansion.cry) and Cipher (Cipher.cry);
--  InvCipher and InvCipher' stay in Spec.Cipher with an explicit K.
--
--  The formal K is the Cryptol's k, and its subtype Types.Key_Size is the
--  constraint Key k. The Cryptol's [Nk k]AESWord and [Nr k + 1]Block are
--  the subtypes Key_Words and Round_Keys below: the lengths are in the
--  types, so KeyExpansion and Cipher take the Cryptol's arguments and no
--  precondition. The instances AES128, AES192 and AES256 are the Cryptol's
--  type applications `{128}, `{192} and `{256}; Spec.Dispatch selects one
--  by a run-time K, for the implementation, which stays flexible in K.
--
--  Everything without a {k} (Round, the S-boxes, GF(2^8), RotWord, SubWord,
--  Rcon) stays in its non-generic unit and is proved once.
--
--  @formal K The key size in bits, the Cryptol's k: 128, 192 or 256.

with Foundation_Spark.AES.Spec.Cipher;
with Foundation_Spark.AES.Spec.KeyExpansion;
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

end Foundation_Spark.AES.Spec.AES_K;
