--  The Secure Hash Algorithm 2 (SHA-2) [FIPS-PUB-180-4 Sections 6.2 and
--  6.4], mirroring the parameterized module algorithms/SHA2/Main.cry. Its
--  `parameter` block (Main.cry:11) becomes this generic's formals, in the
--  same order, plus the types Cryptol does not need to name: the word type
--  `[w]` and the sequences of words `[n][w]`. SHA256 instantiates it as
--  SHA256.cry instantiates the Cryptol.
--
--  This unit holds the compression function `step` (Main.cry:67) and its
--  local definitions, and `hash` (Main.cry:55) over bit sequences with
--  its local types `k` and `N` as functions of the message length. It
--  also holds Preprocessing.cry's `pad` and `parse`, at the `{m, w}` that
--  `hash` applies them at: in the Cryptol they are polymorphic in `w`,
--  and here `w`, and the word type `parse` produces, are this generic's.
--
--  The Cryptol's type constraints are checked for each instance:
--  Digest_Size and Word_Size are positive by subtype; pragmas
--  Compile_Time_Error reject an instance that breaks `8 * w >= d` or gives
--  a Word that is not `[w]`; and K and H0, whose bounds the compiler
--  cannot see, carry assertions that gnatprove proves at the instance's
--  elaboration (K is `[Klen][w]` and H0 is `[8][w]`, both from 0).
--
--  @formal Digest_Size Cryptol's `type d`, the number of bits in a message
--  digest (Main.cry:16).
--  @formal Word_Size Cryptol's `type w`, the number of bits in a word
--  (Main.cry:22, [FIPS-PUB-180-4 Section 2.2.1]).
--  @formal Word A word, Cryptol's `[w]`. Its modulus must be
--  2 ** Word_Size.
--  @formal Word_Vector A sequence of words, Cryptol's `[n][w]`, indexed
--  from 0.
--  @formal Klen Cryptol's `type Klen`, the number of elements of K and of
--  the message schedule W (Main.cry:30).
--  @formal K Cryptol's `K : [Klen][w]`, the SHA-2 constants (Main.cry:34).
--  Its bounds must be 0 .. Klen - 1.
--  @formal H0 Cryptol's `H0 : [8][w]`, the initial hash value
--  (Main.cry:37, [FIPS-PUB-180-4 Section 5.3]). Its bounds must be 0 .. 7.
--  @formal SIGMA_0 Cryptol's `SIGMA_0 : [w] -> [w]` (Main.cry:40,
--  [FIPS-PUB-180-4 Section 4.1]).
--  @formal SIGMA_1 Cryptol's `SIGMA_1 : [w] -> [w]` (Main.cry:41).
--  @formal Small_Sigma_0 Cryptol's `sigma_0 : [w] -> [w]` (Main.cry:42),
--  renamed because Ada identifiers are not case-sensitive.
--  @formal Small_Sigma_1 Cryptol's `sigma_1 : [w] -> [w]` (Main.cry:43),
--  renamed because Ada identifiers are not case-sensitive.

with Foundation_Spark.SHA2.Functions;

generic
   Digest_Size : Positive;
   Word_Size : Positive;
   type Word is mod <>;
   type Word_Vector is array (Natural range <>) of Word;
   Klen : Natural;
   K : Word_Vector;
   H0 : Word_Vector;
   with function SIGMA_0 (X : Word) return Word;
   with function SIGMA_1 (X : Word) return Word;
   with function Small_Sigma_0 (X : Word) return Word;
   with function Small_Sigma_1 (X : Word) return Word;
package Foundation_Spark.SHA2.Main with
  SPARK_Mode
is

   pragma Compile_Time_Error
     (8 * Word_Size < Digest_Size, "Main.cry requires 8 * w >= d");
   pragma Compile_Time_Error
     (Word'Modulus /= 2 ** Word_Size,
      "Main.cry: Word must be [w], that is mod 2 ** Word_Size");
   pragma Assert (K'First = 0 and then K'Last = Klen - 1);
   pragma Assert (H0'First = 0 and then H0'Last = 7);

   subtype Hash_Value is Word_Vector (0 .. 7);
   --  A hash value, Cryptol's `[8][w]` (the type of `H` in `step`).

   subtype Block is Word_Vector (0 .. 15);
   --  A message block, Cryptol's `[16][w]` (the type of `M` in `step`).

   package Logical is new Functions.Logical (Word);
   --  Functions.cry's Ch and Maj at `[w]`, as Main.cry uses them.

   function Ch (X, Y, Z : Word) return Word renames Logical.Ch;
   --  Functions.cry's `Ch` at `[w]`.
   --  @param X Chooses, bit by bit, between Y (where X is 1) and Z.
   --  @param Y The bits chosen where X is 1.
   --  @param Z The bits chosen where X is 0.
   --  @return The bitwise choice of Y and Z by X.

   function Maj (X, Y, Z : Word) return Word renames Logical.Maj;
   --  Functions.cry's `Maj` at `[w]`.
   --  @param X The first voter.
   --  @param Y The second voter.
   --  @param Z The third voter.
   --  @return The bitwise majority of X, Y and Z.

   function W (M : Block; T : Natural) return Word is
     (if T <= 15 then M (T)
      else Small_Sigma_1 (W (M, T - 2)) + W (M, T - 7)
           + Small_Sigma_0 (W (M, T - 15)) + W (M, T - 16))
   with
     Ghost,
     Pre                => T < Klen,
     Subprogram_Variant => (Decreases => T);
   --  The message schedule, `step`'s local `W : [Klen][w]` (Main.cry:70,
   --  Step 1 of [FIPS-PUB-180-4 Sections 6.2.2 and 6.4.2]):
   --  `W@t = if t <= 15 then M @ t else sigma_1 (W@(t-2)) + W@(t-7) +
   --  sigma_0 (W@(t-15)) + W@(t-16)`. The Cryptol sequence is defined by
   --  recursion on its own elements; here it is a recursive function of
   --  the index, and of the block M that the Cryptol closes over.
   --  @param M The message block, `step`'s `M`.
   --  @param T The index `t`, below Klen.
   --  @return `W@t`.

   function T1
     (M : Block; Vars : Hash_Value; T : Natural) return Word
   is
     (Vars (7) + SIGMA_1 (Vars (4)) + Ch (Vars (4), Vars (5), Vars (6))
      + K (T) + W (M, T))
   with
     Ghost,
     Pre => T < Klen;
   --  `step3`'s local `T1 = h + SIGMA_1 e + Ch (e, f, g) + K@t + W@t`
   --  (Main.cry:87, Step 3 of [FIPS-PUB-180-4 Sections 6.2.2 and 6.4.2]),
   --  where `[a, b, c, d, e, f, g, h]` is Vars: h is Vars (7), and e, f, g
   --  are Vars (4), Vars (5), Vars (6).
   --  @param M The message block, `step`'s `M`, for W.
   --  @param Vars The working variables `[a, b, c, d, e, f, g, h]`.
   --  @param T The round `t`, below Klen.
   --  @return `T1` at round T.

   function T2 (Vars : Hash_Value) return Word is
     (SIGMA_0 (Vars (0)) + Maj (Vars (0), Vars (1), Vars (2)))
   with Ghost;
   --  `step3`'s local `T2 = SIGMA_0 a + Maj (a, b, c)` (Main.cry:88, Step
   --  3 of [FIPS-PUB-180-4 Sections 6.2.2 and 6.4.2]), where a, b, c are
   --  Vars (0), Vars (1), Vars (2).
   --  @param Vars The working variables `[a, b, c, d, e, f, g, h]`.
   --  @return `T2`.

   function Step3
     (M : Block; Vars : Hash_Value; T : Natural) return Hash_Value
   is
     ([T1 (M, Vars, T) + T2 (Vars),
       Vars (0),
       Vars (1),
       Vars (2),
       Vars (3) + T1 (M, Vars, T),
       Vars (4),
       Vars (5),
       Vars (6)])
   with
     Ghost,
     Pre => T < Klen;
   --  One round of the compression, `step`'s local `step3`
   --  (Main.cry:75, Step 3 of [FIPS-PUB-180-4 Sections 6.2.2 and 6.4.2]):
   --  `step3 [a, b, c, d, e, f, g, h] t = [T1 + T2, a, b, c, d + T1, e, f,
   --  g]`. The Cryptol names the working variables by a pattern; here
   --  they are Vars (0) to Vars (7), and T1 and T2, local to the Cryptol,
   --  are the functions above. The block M, which the Cryptol closes over
   --  through W, is an explicit parameter.
   --  @param M The message block, `step`'s `M`.
   --  @param Vars The working variables `[a, b, c, d, e, f, g, h]`.
   --  @param T The round `t`, below Klen.
   --  @return The working variables after round T.

   function Foldl_Step3
     (M : Block; H : Hash_Value; N : Natural) return Hash_Value
   is
     (if N = 0 then H
      else Step3 (M, Foldl_Step3 (M, H, N - 1), N - 1))
   with
     Ghost,
     Pre                => N <= Klen,
     Subprogram_Variant => (Decreases => N);
   --  `foldl step3 H [0 ..< N]`, the left fold of Step3 over the first N
   --  rounds. At N = Klen it is `step`'s `H'` (Main.cry:74, Steps 2 and 3
   --  of [FIPS-PUB-180-4 Sections 6.2.2 and 6.4.2]). By the definition of
   --  `foldl`, folding over `[0 ..< N]` is folding over `[0 ..< N - 1]`
   --  and then applying step3 at N - 1.
   --  @param M The message block, which Step3 needs for W.
   --  @param H The initial working variables, `step`'s `H`.
   --  @param N The number of rounds folded, at most Klen.
   --  @return `foldl step3 H [0 ..< N]`.

   function "+" (Left, Right : Hash_Value) return Hash_Value is
     ([for I in Hash_Value'Range => Left (I) + Right (I)]);
   --  Cryptol's `+` on `[8][w]`, as `step` uses it: element-wise, each
   --  word modulo 2 ** w.
   --  @param Left The first hash value.
   --  @param Right The second hash value.
   --  @return The element-wise sum.

   function Step (H : Hash_Value; M : Block) return Hash_Value is
     (H + Foldl_Step3 (M, H, Klen))
   with Ghost;
   --  The compression function, Cryptol's `step H M = H + H'`
   --  (Main.cry:67, Step 4 of [FIPS-PUB-180-4 Sections 6.2.2 and 6.4.2]),
   --  where `H' = foldl step3 H [0 ..< Klen]`.
   --  @param H The hash value before this block.
   --  @param M The message block.
   --  @return The hash value after this block.

   type Block_Vector is array (Bit_Index range <>) of Block;
   --  A sequence of message blocks, Cryptol's `[N][16][w]` (the type of
   --  `parse`'s result, Preprocessing.cry:50, and of `hash`'s `M'`),
   --  indexed from 0.

   Block_Size : constant Bit_Index := 16 * Bit_Index (Word_Size);
   --  The number of bits in a message block, Cryptol's `type m = w * 16`
   --  (Main.cry:48, [FIPS-PUB-180-4 Section 2.2.1]).

   Max_Length : constant Bit_Index :=
     (if Word_Size >= 32 then 2 ** 64 else 2 ** (2 * Word_Size));
   --  The bound on message lengths: `hash` admits `l` with
   --  `width l <= 2 * w` (Main.cry:55), that is `l < 2 ** (2 * w)`, and
   --  the spec layer admits lengths below 2 ** 64 (the campaign's bit
   --  sequence decision), which is the same bound at w = 32.

   function Small_K (L : Bit_Index) return Bit_Index is
     (Ceil_Mod (L + 1 + 2 * Bit_Index (Word_Size), Block_Size))
   with
     Ghost,
     Pre => L < Max_Length;
   --  The number of zero bits in the padding, `hash`'s local
   --  `type k = (l + 1 + 2 * w) %^ m` (Main.cry:58, [FIPS-PUB-180-4
   --  Section 5.1.1]), as a function of the message length. Named
   --  Small_K because Ada identifiers are not case-sensitive and K is the
   --  constants.
   --  @param L The message length `l`, in bits.
   --  @return `k`.

   function N (L : Bit_Index) return Bit_Index is
     (Ceil_Div (L + 1 + 2 * Bit_Index (Word_Size), Block_Size))
   with
     Ghost,
     Pre => L < Max_Length;
   --  The number of blocks in the padded message, `hash`'s local
   --  `type N = (l + 1 + 2 * w) /^ m` (Main.cry:59, [FIPS-PUB-180-4
   --  Section 5.2.1]), as a function of the message length.
   --  @param L The message length `l`, in bits.
   --  @return `N`.

   function Zero (Count : Bit_Index) return Bits is
     ([for I in 0 .. Count - 1 => False])
   with Ghost;
   --  Cryptol's `zero` at type `[k]`, as `pad` uses it
   --  (Preprocessing.cry:23): Count zero bits.
   --  @param Count The number of bits, `k`.
   --  @return Count bits, all 0, indexed from 0.

   function Pad (M : Bits) return Bits is
     (M
      & [True]
      & Zero (Small_K (M'Length))
      & To_Bits (M'Length, 2 * Bit_Index (Word_Size)))
   with
     Ghost,
     Pre => M'First = 0 and then M'Length < Max_Length;
   --  The padding, Cryptol's `pad`{m, w, l, k}` as `hash` applies it
   --  (Preprocessing.cry:14, [FIPS-PUB-180-4 Section 5.1]):
   --  `pad M = M # 0b1 # zero # (`l : [2 * w])`, with m = Block_Size, l
   --  the length of M and k = Small_K (l). The result has
   --  `l + 1 + k + 2 * w` bits, that is N (l) blocks.
   --  @param M The message, `[l]`, indexed from 0.
   --  @return The padded message, indexed from 0.

   function Word_Of
     (P : Bits; First : Bit_Index; Count : Natural) return Word
   is
     (if Count = 0 then 0
      else 2 * Word_Of (P, First, Count - 1)
           + (if P (First + Bit_Index (Count) - 1) then 1 else 0))
   with
     Ghost,
     Pre                =>
       Count <= Word_Size
       and then First >= P'First
       and then First + Bit_Index (Count) - 1 <= P'Last,
     Subprogram_Variant => (Decreases => Count);
   --  The Count bits of P from First, read as a number most significant
   --  bit first. At Count = w it is the word `[w]` that Cryptol's
   --  `split`{N * 16, w}` cuts from P at First (Preprocessing.cry:51):
   --  in Cryptol a word is its bits, so the conversion has no name there.
   --  @param P The bits.
   --  @param First The position of the first (most significant) bit.
   --  @param Count The number of bits read, at most w.
   --  @return The value of P (First .. First + Count - 1).

   function Parse_Block (P : Bits; I : Bit_Index) return Block is
     ([for J in 0 .. 15 =>
         Word_Of
           (P, (16 * I + Bit_Index (J)) * Bit_Index (Word_Size), Word_Size)])
   with
     Ghost,
     Pre => P'First = 0
            and then I < Bit_Index'Last / Block_Size
            and then (I + 1) * Block_Size <= P'Length;
   --  Block I of `parse`{w, N} P` (Preprocessing.cry:51): the 16 words of
   --  `split`{N * 16, w} P` from word 16 * I, which the outer
   --  `split`{N, 16}` groups as block I. Word J is the w bits of P from
   --  (16 * I + J) * w.
   --  @param P The padded message, indexed from 0.
   --  @param I The block's index, below N.
   --  @return Block I of P.

   function Parse (P : Bits; N : Bit_Index) return Block_Vector is
     ([for I in 0 .. N - 1 => Parse_Block (P, I)])
   with
     Ghost,
     Pre => P'First = 0
            and then N <= Bit_Index'Last / Block_Size
            and then P'Length = N * Block_Size;
   --  The parsing of a padded message into blocks, Cryptol's
   --  `parse`{w, N}` (Preprocessing.cry:47, [FIPS-PUB-180-4 Section
   --  5.2]): `parse M = split`{N, 16} (split`{N * 16, w} M)`. The inner
   --  split cuts P into N * 16 words of w bits and the outer groups them
   --  16 to a block, so block I is Parse_Block (P, I).
   --  @param P The padded message, `[N * 16 * w]`, indexed from 0.
   --  @param N The number of blocks, Cryptol's `N`.
   --  @return The N blocks, indexed from 0.

   function Foldl_Step
     (H : Hash_Value; Ms : Block_Vector; N : Bit_Index) return Hash_Value
   is
     (if N = 0 then H
      else Step (Foldl_Step (H, Ms, N - 1), Ms (N - 1)))
   with
     Ghost,
     Pre                => Ms'First = 0 and then N <= Ms'Last + 1,
     Subprogram_Variant => (Decreases => N);
   --  `foldl step H (take`{N} Ms)`, the left fold of Step over the first
   --  N blocks. At N = Ms'Length it is `hash`'s `H = foldl step H0 M'`
   --  (Main.cry:61, [FIPS-PUB-180-4 Sections 6.2 and 6.4]). As
   --  Foldl_Step3 does for the rounds, it folds the first N - 1 blocks
   --  and then applies step to block N - 1.
   --  @param H The initial hash value.
   --  @param Ms The message blocks, indexed from 0.
   --  @param N The number of blocks folded.
   --  @return The hash value after the first N blocks.

   function Bit (X : Word; J : Natural) return Boolean is
     ((X / 2 ** (Word_Size - 1 - J)) mod 2 = 1)
   with
     Ghost,
     Pre => J < Word_Size;
   --  Bit J of a word, Cryptol's `x @ j` on `[w]`: most significant bit
   --  first, so bit J has weight 2 ** (w - 1 - J).
   --  @param X The word.
   --  @param J The bit's position, below w.
   --  @return Whether that bit is 1.

   function Join (H : Hash_Value) return Bits is
     ([for I in 0 .. 8 * Bit_Index (Word_Size) - 1 =>
         Bit (H (Natural (I / Bit_Index (Word_Size))),
              Natural (I mod Bit_Index (Word_Size)))])
   with Ghost;
   --  Cryptol's `join` on `[8][w]`, as `hash` applies it (Main.cry:56):
   --  the 8 words' bits in order, so bit I is bit I mod w of word I / w.
   --  @param H The hash value.
   --  @return Its 8 * w bits, indexed from 0.

   function Hash (M : Bits) return Bits is
     (Join
        (Foldl_Step
           (H0, Parse (Pad (M), N (M'Length)), N (M'Length)))
        (0 .. Bit_Index (Digest_Size) - 1))
   with
     Ghost,
     Pre => M'First = 0 and then M'Length < Max_Length;
   --  SHA-2, Cryptol's `hash M = take (join H)` (Main.cry:55,
   --  [FIPS-PUB-180-4 Sections 6.2 and 6.4]), where
   --  `M' = parse`{w, N} (pad`{m, w, l, k} M)` and
   --  `H = foldl step H0 M'`: the message is padded, parsed into N (l)
   --  blocks, and folded through Step from H0, and the digest is the
   --  first d bits of the result.
   --  @param M The message, `[l]` with l below Max_Length, indexed
   --  from 0.
   --  @return The d-bit message digest, indexed from 0.

end Foundation_Spark.SHA2.Main;
