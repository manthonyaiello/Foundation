--  The bridge from the generic {k} functions (AES_K, instantiated as
--  AES128, AES192 and AES256) to an implementation that is flexible in the
--  key size: one ghost dispatcher per {k} function, which selects the
--  instance by a run-time K. Main.cry's
--  split (split key), which depends on k, has one too (Split_Key), so that
--  Encrypt's and Decrypt's postconditions state their bodies.
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
with Foundation_Spark.AES.Spec.Main;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.AES.Spec.Dispatch with
  SPARK_Mode,
  Pure,
  Ghost
is

   use Types;
   use Spec.KeyExpansion;
   use Spec.Cipher;

   use type Types.Byte;
   use type Main.Bits;

   procedure Lemma_Key_Size (K : Natural)
   with
     Post =>
       (K in Key_Size)
       = (K mod 64 = 0 and then K / 64 >= 2 and then K / 64 <= 4);
   --  The values that Types.Key_Size lists, 128 | 192 | 256, are those that
   --  Types.cry's type constraint Key k = (fin k, k % 64 == 0,
   --  k / 64 >= 2, k / 64 <= 4) allows, stated here clause for clause.
   --  Fin k holds of any Natural.
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

   function Round_Key (K : Key_Size; Key : Key_Words; R : Natural)
     return Block
   is (Join ([for J in AESWord_Index => W (K, Key, 4 * R + J)]))
   with Pre => Is_Key_Words (K, Key) and then R <= Nr (K);
   --  Round key R of KeyExpansion.cry's split (split (join (join w))):
   --  Join of w @ (4 * R) to w @ (4 * R + 3). A function of its own
   --  because GNAT 16.1, compiling assertions (the FFI build), rejects
   --  this aggregate inside KeyExpansion's quantified postcondition ("R
   --  is undefined").
   --  @param K The key size in bits.
   --  @param Key The cipher key as Nk (K) words.
   --  @param R The round, 0 .. Nr (K).
   --  @return The round key.

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
            KeyExpansion'Result (R) = Round_Key (K, Key, R));
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

   function InvCipher
     (K : Key_Size; W : Round_Keys; Input : Block) return Block
   is (case K is
         when 128 => AES128.InvCipher (W, Input),
         when 192 => AES192.InvCipher (W, Input),
         when 256 => AES256.InvCipher (W, Input))
   with
     Pre  => Is_Round_Keys (K, W),
     Post =>
       InvCipher'Result
       = AddRoundKey (InvSubBytes (InvShiftRows
                        (Foldl_InvRound
                           (AddRoundKey (Input, W (Nr (K))),
                            Reverse_Keys (W (1 .. Nr (K) - 1))))),
                      W (0));
   --  Cipher.cry's InvCipher`{k} at k = K: the instance's InvCipher. The
   --  postcondition is its body, uniformly in K.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param W The Nr (K) + 1 round keys.
   --  @param Input The ciphertext block.
   --  @return The plaintext block.

   function InvCipher_Prime
     (K : Key_Size; W : Round_Keys; Input : Block) return Block
   is (case K is
         when 128 => AES128.InvCipher_Prime (W, Input),
         when 192 => AES192.InvCipher_Prime (W, Input),
         when 256 => AES256.InvCipher_Prime (W, Input))
   with
     Pre  => Is_Round_Keys (K, W),
     Post =>
       InvCipher_Prime'Result
       = AddRoundKey
           (Foldl_InvRound_Prime
              (InvSubBytes (InvShiftRows (AddRoundKey (Input, W (Nr (K))))),
               Reverse_Keys (W (1 .. Nr (K) - 1))),
            W (0));
   --  Cipher.cry's InvCipher'`{k} at k = K: the instance's
   --  InvCipher_Prime. The postcondition is its body, uniformly in K.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param W The Nr (K) + 1 round keys.
   --  @param Input The ciphertext block.
   --  @return The plaintext block.

   function Split_Key (K : Key_Size; Key : Main.Bits) return Key_Words
   is (case K is
         when 128 => AES128.Split_Key (Key),
         when 192 => AES192.Split_Key (Key),
         when 256 => AES256.Split_Key (Key))
   with
     Pre  => Main.Is_Key_Bits (K, Key),
     Post =>
       Is_Key_Words (K, Split_Key'Result)
       and then
         (for all J in 0 .. Nk (K) - 1 =>
            (for all I in AESWord_Index =>
               Split_Key'Result (J) (I)
               = Main.Byte_At (Key, Main.Bit_Index (32 * J + 8 * I))));
   --  Main.cry's split (split key) at k = K: the instance's Split_Key. The
   --  postcondition is its body, uniformly in K.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Key The key as K bits.
   --  @return The key as Nk (K) words.

   function Encrypt
     (K : Key_Size; Key : Main.Bits; Input : Main.Block_Bits)
      return Main.Block_Bits
   is (case K is
         when 128 => AES128.Encrypt (Key, Input),
         when 192 => AES192.Encrypt (Key, Input),
         when 256 => AES256.Encrypt (Key, Input))
   with
     Pre  => Main.Is_Key_Bits (K, Key),
     Post =>
       Encrypt'Result
       = Main.Join_Block
           (Cipher (K, KeyExpansion (K, Split_Key (K, Key)),
                    Main.Split_Block (Input)));
   --  Main.cry's AES`{k}.Encrypt at k = K: the instance's Encrypt. The
   --  postcondition is its body, uniformly in K.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Key The key as K bits.
   --  @param Input The plaintext block as 128 bits.
   --  @return The ciphertext block as 128 bits.

   function Decrypt
     (K : Key_Size; Key : Main.Bits; Input : Main.Block_Bits)
      return Main.Block_Bits
   is (case K is
         when 128 => AES128.Decrypt (Key, Input),
         when 192 => AES192.Decrypt (Key, Input),
         when 256 => AES256.Decrypt (Key, Input))
   with
     Pre  => Main.Is_Key_Bits (K, Key),
     Post =>
       Decrypt'Result
       = Main.Join_Block
           (InvCipher (K, KeyExpansion (K, Split_Key (K, Key)),
                       Main.Split_Block (Input)));
   --  Main.cry's AES`{k}.Decrypt at k = K: the instance's Decrypt. The
   --  postcondition is its body, uniformly in K.
   --  @param K The key size in bits, the Cryptol's k.
   --  @param Key The key as K bits.
   --  @param Input The ciphertext block as 128 bits.
   --  @return The plaintext block as 128 bits.

end Foundation_Spark.AES.Spec.Dispatch;
