--  The keyed-Hash Message Authentication Code (HMAC) [FIPS-PUB-198-1
--  Section 4], mirroring algorithms/HMAC/Main.cry. The Cryptol's `HMAC`
--  (Main.cry:26) takes its hash functions `Hk`, `Hn` and `HL` as arguments
--  and the sizes `B` and `L` as type parameters. Ada has no function
--  arguments, so they are this generic's formals, in the same order; the
--  per-call sizes `k` (the key's length), `n` (the text's) and `λ` (the
--  output's) stay per call. SHA256 instantiates it as packaging/Hash.cry's
--  `HMAC` (Hash.cry:71) does, with every hash the one SHA-256 `hash`.
--
--  Cryptol gives `Hk`, `Hn` and `HL` the input types `[k * 8]`,
--  `[B * 8 + n]` and `[(B + L) * 8]`, and leaves it to the caller to have
--  hash functions of those types: packaging/Hash.cry does so with its
--  `UpperLimit` constraints (Hash.cry:74 to :76). Here a hash takes any
--  bit sequence below Max_Length, the bound on its message length, and
--  the preconditions of HMAC and HMAC_init carry those constraints. Every
--  hash returns `[L * 8]`, which is the formals' postcondition.
--
--  The Cryptol's other type constraints are checked for each instance:
--  pragmas Compile_Time_Error reject an instance that breaks
--  `2 ^^ B >= 8 * B` (Main.cry:29) or `L <= B` (Main.cry:32), and
--  HMAC's precondition states `λ <= L * 8` and `n < 2 ^^ B - 8 * B`.
--
--  @formal B Cryptol's `B`, the block size of the hash's input in bytes
--  (Main.cry:15).
--  @formal L Cryptol's `L`, the size of the hash's output in bytes
--  (Main.cry:18).
--  @formal Max_Length The hash functions' bound on their message length
--  in bits: they accept a message M with M'Length < Max_Length.
--  packaging/Hash.cry's `UpperLimit` (Hash.cry:28) as a length,
--  2 ^^ UpperLimit.
--  @formal Hk Cryptol's `Hk : [k * 8] -> [L * 8]` (Main.cry:34), the hash
--  of a long key.
--  @formal Hn Cryptol's `Hn : [B * 8 + n] -> [L * 8]` (Main.cry:35), the
--  inner hash.
--  @formal HL Cryptol's `HL : [(B + L) * 8] -> [L * 8]` (Main.cry:36), the
--  outer hash.

generic
   B : Positive;
   L : Natural;
   Max_Length : SHA2.Bit_Index;
   with function Hk (M : SHA2.Bits) return SHA2.Bits
   with
     Ghost,
     Pre  => M'First = 0 and then M'Length < Max_Length,
     Post => Hk'Result'First = 0
             and then Hk'Result'Length = 8 * SHA2.Bit_Index (L);
   with function Hn (M : SHA2.Bits) return SHA2.Bits
   with
     Ghost,
     Pre  => M'First = 0 and then M'Length < Max_Length,
     Post => Hn'Result'First = 0
             and then Hn'Result'Length = 8 * SHA2.Bit_Index (L);
   with function HL (M : SHA2.Bits) return SHA2.Bits
   with
     Ghost,
     Pre  => M'First = 0 and then M'Length < Max_Length,
     Post => HL'Result'First = 0
             and then HL'Result'Length = 8 * SHA2.Bit_Index (L);
package Foundation_Spark.HMAC.Main with
  SPARK_Mode
is

   use type SHA2.Bits;

   pragma Compile_Time_Error
     (B < 6, "Main.cry requires 2 ^^ B >= 8 * B, that is B >= 6");
   pragma Compile_Time_Error (L > B, "Main.cry requires L <= B");

   function Text_Limit return SHA2.Bit_Index is
     (if B >= 126 then SHA2.Bit_Index'Last
      else 2 ** B - 8 * SHA2.Bit_Index (B))
   with Ghost;
   --  Cryptol's `2 ^^ B - 8 * B`, the bound on the text's length `n`
   --  (Main.cry:31, [FIPS-PUB-198-1 Section 2.3]). For B of 126 or more
   --  it exceeds every SHA2.Bit_Index, and Bit_Index'Last stands for it: a
   --  text that long cannot be hashed anyway (Max_Length).
   --  @return The bound on the text's length.

   function Opad return SHA2.Bits is
     (Join (Repeat (Byte_Index (B), 16#5C#)))
   with
     Ghost,
     Post => Opad'Result'First = 0
             and then Opad'Result'Length = 8 * SHA2.Bit_Index (B);
   --  HMAC's local `opad = join (repeat`{B} 0x5C)` (Main.cry:46,
   --  [FIPS-PUB-198-1 Section 2.3]), the outer pad: B bytes 0x5C.
   --  @return The B * 8 bits of the outer pad.

   function Ipad return SHA2.Bits is
     (Join (Repeat (Byte_Index (B), 16#36#)))
   with
     Ghost,
     Post => Ipad'Result'First = 0
             and then Ipad'Result'Length = 8 * SHA2.Bit_Index (B);
   --  HMAC's local `ipad = join (repeat`{B} 0x36)` (Main.cry:47,
   --  [FIPS-PUB-198-1 Section 2.3]), the inner pad: B bytes 0x36.
   --  @return The B * 8 bits of the inner pad.

   function HMAC_init (K : Bytes) return SHA2.Bits is
     (if K'Length = Byte_Index (B) then Join (K)
      elsif K'Length > Byte_Index (B)
      then Hk (Join (K)) & Zero (8 * SHA2.Bit_Index (B - L))
      else Join (K)
           & Zero (8 * (SHA2.Bit_Index (B) - SHA2.Bit_Index (K'Length))))
   with
     Ghost,
     Pre  =>
       K'Length <= Byte_Index (B)
       or else 8 * SHA2.Bit_Index (K'Length) < Max_Length,
     Post =>
       HMAC_init'Result'First = 0
       and then HMAC_init'Result'Length = 8 * SHA2.Bit_Index (B);
   --  The key preprocessing, Cryptol's `HMAC_init Hk K` (Main.cry:56,
   --  Steps 1 to 3 of [FIPS-PUB-198-1 Section 4 Table 1]), private in
   --  Main.cry and public here because HMAC.SHA256_Impl is proved against it. By
   --  cases on the key's length k: a key of B bytes is its bits
   --  (`join K`); a longer key is hashed with Hk and the L-byte digest is
   --  padded with zeros to B bytes; a shorter key is padded with zeros to
   --  B bytes. The Cryptol's cases are guards `k == B`, `k > B` and
   --  `k < B`, in that order, as the if-expression's are.
   --  @param K The key, `[k][8]`. Only a longer key (k > B) is hashed, so
   --  only it must have its 8 * k bits below Max_Length, as Hk's type
   --  `[k * 8]` requires of the Cryptol's caller.
   --  @return `K0`, the key as B * 8 bits, indexed from 0.

   function HMAC
     (K : Bytes; Text : SHA2.Bits; Lambda : SHA2.Bit_Index) return SHA2.Bits
   is
     (HL ((HMAC_init (K) xor Opad)
          & Hn ((HMAC_init (K) xor Ipad) & Text))
        (0 .. Lambda - 1))
   with
     Ghost,
     Pre  =>
       (K'Length <= Byte_Index (B)
        or else 8 * SHA2.Bit_Index (K'Length) < Max_Length)
       and then Text'First = 0
       and then Text'Length < Text_Limit
       and then 8 * SHA2.Bit_Index (B) + Text'Length < Max_Length
       and then 8 * (SHA2.Bit_Index (B) + SHA2.Bit_Index (L)) < Max_Length
       and then Lambda <= 8 * SHA2.Bit_Index (L),
     Post =>
       HMAC'Result'First = 0 and then HMAC'Result'Length = Lambda;
   --  HMAC, Cryptol's `HMAC Hk Hn HL K text` (Main.cry:40,
   --  [FIPS-PUB-198-1 Section 4]):
   --  `take (HL ((K0 ^ opad) # (Hn ((K0 ^ ipad) # text))))`, where
   --  `K0 = HMAC_init Hk K`. Cryptol's `^` on bits is Ada's `xor` on
   --  Boolean arrays, `#` is `&`, and `take` is the slice of the first
   --  λ bits. The local K0 is HMAC_init (K), written where the Cryptol
   --  names it.
   --  The precondition is the Cryptol's constraints, `λ <= L * 8` and
   --  `n < 2 ^^ B - 8 * B` (Main.cry:28 and :31), with what the hashes'
   --  types ask of the caller: Hk's `[k * 8]` (for a long key), Hn's
   --  `[B * 8 + n]` and HL's `[(B + L) * 8]`, each a message below
   --  Max_Length, as packaging/Hash.cry's `UpperLimit` constraints state
   --  them (Hash.cry:74 to :76). At SHA-256, B = 64 and Max_Length =
   --  2 ** 64, and `n < 2 ^^ 64 - 512` is the same bound as
   --  `512 + n < 2 ** 64`.
   --  @param K The key, `[k][8]`.
   --  @param Text The message, `[n]`, indexed from 0.
   --  @param Lambda Cryptol's `λ`, the number of (leftmost) bits of the
   --  MAC returned, at most L * 8 ([FIPS-PUB-198-1 Section 5]).
   --  @return The first Lambda bits of the MAC, indexed from 0.

end Foundation_Spark.HMAC.Main;
