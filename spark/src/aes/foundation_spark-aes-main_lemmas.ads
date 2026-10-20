--  Lemmas that AES.Impl.Main's Encrypt and Decrypt are proved with: the
--  bytes-to-bits layer between the implementation and Main.cry's Encrypt
--  and Decrypt, and the congruence of the spec's KeyExpansion, Cipher and
--  InvCipher. They are not in the Cryptol: each states a property that the
--  Cryptol evaluates and SPARK has to prove, as AES.Lemmas does.
--
--  Congruence. Ada's = on arrays is componentwise, not the provers'
--  equality, so the spec's functions are not known to agree on equal
--  arrays until they are unfolded (see AES.Lemmas and the *_Eq lemmas of
--  Spec.Properties). Main.cry's Encrypt applies KeyExpansion to split
--  (split key) and Cipher to split in, while the implementation applies
--  them to the words and the block it holds: equal arrays, but other
--  objects. The *_Eq lemmas here state, once per function, that equal
--  arguments give equal results.

with Foundation_Spark.AES.Impl.Main;
with Foundation_Spark.AES.Spec.Cipher;
with Foundation_Spark.AES.Spec.Dispatch;
with Foundation_Spark.AES.Spec.KeyExpansion;
with Foundation_Spark.AES.Spec.Main;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.AES.Main_Lemmas with
  SPARK_Mode,
  Pure,
  Ghost
is

   use Spec.Types;
   use Spec.Cipher;

   use type Spec.Types.Byte;

   procedure Lemma_Split_Join_Key (K : Natural; Key : Impl.Main.Key_Bytes)
   with
     Pre  => Impl.Main.Is_Key_Bytes (K, Key),
     Post =>
       Spec.Main.Is_Key_Bits (K, Impl.Main.Join_Key (Key))
       and then
         (for all J in 0 .. Nk (K) - 1 =>
            (for all I in AESWord_Index =>
               Spec.Main.Split_Key (K, Impl.Main.Join_Key (Key)) (J) (I)
               = Key (4 * J + I)));
   --  Main.cry's split (split key) of the key's bits is the key's bytes,
   --  four to a word: Cryptol's split at [k] -> [Nk k][4][8] undoes its
   --  join at [k / 8][8] -> [k].
   --  @param K The key size in bits.
   --  @param Key The key, K / 8 bytes.

   procedure Lemma_W_Eq (K : Natural; A, B : Key_Words; I : Natural)
   with
     Pre                =>
       Is_Key_Words (K, A) and then Is_Key_Words (K, B) and then A = B
       and then I < Spec.KeyExpansion.Words (K),
     Post               =>
       (for all J in 0 .. I =>
          Spec.Dispatch.W (K, A, J) = Spec.Dispatch.W (K, B, J)),
     Subprogram_Variant => (Decreases => I);
   --  KeyExpansion.cry's w of equal keys is equal, up to word I. By
   --  induction on I.
   --  @param K The key size in bits.
   --  @param A A key.
   --  @param B A key equal to A.
   --  @param I The last index of w compared.

   procedure Lemma_KeyExpansion_Eq (K : Natural; A, B : Key_Words)
   with
     Pre  => Is_Key_Words (K, A) and then Is_Key_Words (K, B) and then A = B,
     Post =>
       Spec.Dispatch.KeyExpansion (K, A)
       = Spec.Dispatch.KeyExpansion (K, B);
   --  KeyExpansion maps equal keys to equal round keys.
   --  @param K The key size in bits.
   --  @param A A key.
   --  @param B A key equal to A.

   procedure Lemma_Round_Key_Eq (A : Block; K1, K2 : Block)
   with
     Pre  => K1 = K2,
     Post => Round (A, K1) = Round (A, K2);
   --  Round maps equal round keys to equal states.
   --  @param A The state.
   --  @param K1 A round key.
   --  @param K2 A round key equal to K1.

   procedure Lemma_Foldl_Round_Eq (A, B : Block; Xs, Ys : Round_Keys)
   with
     Pre                => A = B and then Xs = Ys,
     Post               => Foldl_Round (A, Xs) = Foldl_Round (B, Ys),
     Subprogram_Variant => (Decreases => Xs'Length);
   --  foldl Round maps equal states and equal lists of round keys (equal
   --  as Ada arrays: same length and components, whatever their bounds)
   --  to equal states.
   --  @param A An initial state.
   --  @param B An initial state equal to A.
   --  @param Xs Round keys.
   --  @param Ys Round keys equal to Xs.

   procedure Lemma_Cipher_Eq (K : Natural; V, W : Round_Keys; A, B : Block)
   with
     Pre  =>
       Is_Round_Keys (K, V) and then Is_Round_Keys (K, W)
       and then V = W and then A = B,
     Post => Spec.Dispatch.Cipher (K, V, A) = Spec.Dispatch.Cipher (K, W, B);
   --  Cipher maps equal round keys and equal blocks to equal blocks.
   --  @param K The key size in bits.
   --  @param V Round keys.
   --  @param W Round keys equal to V.
   --  @param A A block.
   --  @param B A block equal to A.

   procedure Lemma_InvCipher_Eq (K : Natural; V, W : Round_Keys; A, B : Block)
   with
     Pre  =>
       Is_Round_Keys (K, V) and then Is_Round_Keys (K, W)
       and then V = W and then A = B,
     Post => InvCipher (K, V, A) = InvCipher (K, W, B);
   --  InvCipher maps equal round keys and equal blocks to equal blocks.
   --  @param K The key size in bits.
   --  @param V Round keys.
   --  @param W Round keys equal to V.
   --  @param A A block.
   --  @param B A block equal to A.

end Foundation_Spark.AES.Main_Lemmas;
