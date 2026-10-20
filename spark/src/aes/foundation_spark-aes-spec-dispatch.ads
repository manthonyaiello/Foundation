--  The bridge from the generic {k} functions (AES_K, instantiated as
--  AES128, AES192 and AES256) to an implementation that is flexible in the
--  key size: one ghost dispatcher per {k} function, which selects the
--  instance by a run-time K. Spike #74.
--
--  These are not in the Cryptol. Cryptol resolves {k} at the type level;
--  Ada has no type-level numbers, so the implementation, which serves all
--  three key sizes with one body, names its spec through a K-indexed
--  selection of the three instances. Each dispatcher's postcondition (or,
--  for the recursive W, the lemma Lemma_W) states the Cryptol body
--  uniformly in K. It is proved once per key size, so the three-way split
--  happens here, and only here: the dispatchers' clients reason about one
--  formula and never case on K.

with Foundation_Spark.AES.Spec.AES128;
with Foundation_Spark.AES.Spec.AES192;
with Foundation_Spark.AES.Spec.AES256;
with Foundation_Spark.AES.Spec.Cipher;
with Foundation_Spark.AES.Spec.KeyExpansion;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.AES.Spec.Dispatch with
  SPARK_Mode,
  Pure,
  Ghost
is

   use Types;
   use Spec.KeyExpansion;
   use Spec.Cipher;

   procedure Lemma_Key_Size (K : Natural)
   with Post => Key (K) = (K in Key_Size);
   --  The values that Key_Size lists are those that Types.cry's Key k
   --  allows, clause for clause (Types.Key).
   --  @param K A key size in bits.

   function W (K : Key_Size; Key : Key_Words; I : Natural) return AESWord
   is (case K is
         when 128 => AES128.W (Key, I),
         when 192 => AES192.W (Key, I),
         when 256 => AES256.W (Key, I))
   with Pre => Is_Key_Words (K, Key) and then I < Words (K);
   --  KeyExpansion.cry's w @ I at key size K: the instance's W.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Key The cipher key as Nk (K) words.
   --  @param I The index of the word, below 4 * (Nr (K) + 1).
   --  @return AES<K>.W (Key, I).

   procedure Lemma_W (K : Key_Size; Key : Key_Words; I : Natural)
   with
     Pre  => Is_Key_Words (K, Key) and then I < Words (K),
     Post =>
       W (K, Key, I)
       = (if I < Nk (K) then Key (I)
          elsif I mod Nk (K) = 0
          then W (K, Key, I - Nk (K))
               xor SubWord (RotWord (W (K, Key, I - 1)))
               xor Rcon (I / Nk (K))
          elsif I mod Nk (K) = 4 and then Nk (K) > 6
          then W (K, Key, I - Nk (K)) xor SubWord (W (K, Key, I - 1))
          else W (K, Key, I - Nk (K)) xor W (K, Key, I - 1));
   --  KeyExpansion.cry's definition of w @ I, uniformly in K: the
   --  instances' W, unfolded once, through the dispatcher.
   --  @param K The key size in bits.
   --  @param Key The cipher key as Nk (K) words.
   --  @param I The index of the word.

   function KeyExpansion (K : Key_Size; Key : Key_Words) return Round_Keys
   is (case K is
         when 128 => AES128.KeyExpansion (Key),
         when 192 => AES192.KeyExpansion (Key),
         when 256 => AES256.KeyExpansion (Key))
   with
     Pre  => Is_Key_Words (K, Key),
     Post =>
       Is_Round_Keys (K, KeyExpansion'Result)
       and then
         (for all R in 0 .. Nr (K) =>
            KeyExpansion'Result (R)
            = Join ([for J in AESWord_Index => W (K, Key, 4 * R + J)]));
   --  KeyExpansion.cry's KeyExpansion`{k} at k = K: the instance's
   --  KeyExpansion. The postcondition is its body, uniformly in K.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Key The cipher key as Nk (K) words.
   --  @return The Nr (K) + 1 round keys.

   function Cipher (K : Key_Size; W : Round_Keys; Input : Block) return Block
   is (case K is
         when 128 => AES128.Cipher (W, Input),
         when 192 => AES192.Cipher (W, Input),
         when 256 => AES256.Cipher (W, Input))
   with
     Pre  => Is_Round_Keys (K, W),
     Post =>
       Cipher'Result
       = AddRoundKey (ShiftRows (SubBytes
                        (Foldl_Round (AddRoundKey (Input, W (0)),
                                      W (1 .. Nr (K) - 1)))),
                      W (Nr (K)));
   --  Cipher.cry's Cipher`{k} at k = K: the instance's Cipher. The
   --  postcondition is its body, uniformly in K.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param W The Nr (K) + 1 round keys.
   --  @param Input The plaintext block.
   --  @return The ciphertext block.

end Foundation_Spark.AES.Spec.Dispatch;
