--  Multiplication in GF(2^8), mirroring algorithms/AES/GF28.cry
--  [FIPS-PUB-197 Section 4.2].
--
--  GF28.cry defines (•) as pmod (pmult b c) m, with Cryptol's primitive
--  polynomial product pmult and remainder pmod over GF(2). Pmult and Pmod
--  state those two primitives at the types GF28.cry uses them at, each as
--  a recursive fold over the bits of its argument, most significant first,
--  as Cryptol orders bits. Ada has no operator named •, so (•) is Dot.

with Interfaces;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.AES.Spec.GF28 with
  SPARK_Mode,
  Pure,
  Ghost
is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;

   subtype Byte is Types.Byte;
   --  A byte, the Cryptol [8].

   subtype Poly is Interfaces.Unsigned_16;
   --  A polynomial over GF(2) of degree below 16, as its coefficient bits:
   --  bit I (from the least significant) is the coefficient of x^^I. It
   --  holds pmult's [15] product and pmod's [9] modulus.

   subtype Bit_Index is Natural range 0 .. 7;
   --  The indices of the bits of a Byte.

   function Bit (B : Byte; I : Bit_Index) return Boolean
   is ((Interfaces.Shift_Right (B, 7 - I) and 1) = 1);
   --  Cryptol's b @ i on a [8]. Cryptol is big-endian, so bit 0 is the
   --  most significant.
   --  @param B The byte.
   --  @param I The Cryptol index of the bit.
   --  @return Whether that bit is set.

   function Head (B : Byte) return Boolean
   is (Bit (B, 0));
   --  Cryptol's head b on a [8]: its most significant bit.
   --  @param B The byte.
   --  @return Whether its most significant bit is set.

   subtype Product_Index is Natural range 0 .. 14;
   --  The indices of the bits of a [15] product.

   function Product_Bit (X : Poly; I : Product_Index) return Boolean
   is ((Interfaces.Shift_Right (X, 14 - I) and 1) = 1);
   --  Cryptol's x @ i on a [15], held in the low 15 bits of a Poly.
   --  @param X The product.
   --  @param I The Cryptol index of the bit (0 is the coefficient of
   --  x^^14).
   --  @return Whether that bit is set.

   function Pmult_Fold (B, C : Byte; N : Natural) return Poly
   is (if N = 0 then 0
       else Interfaces.Shift_Left (Pmult_Fold (B, C, N - 1), 1)
            xor (if Bit (C, N - 1) then Poly (B) else 0))
   with
     Pre                => N <= 8,
     Subprogram_Variant => (Decreases => N);
   --  The first N steps of pmult b c: the product of B with the leading N
   --  bits of C, accumulated by shift and exclusive-or, most significant
   --  bit of C first.
   --  @param B The multiplicand.
   --  @param C The multiplier.
   --  @param N How many bits of C, from the most significant, to use.
   --  @return The partial product.

   function Pmult (B, C : Byte) return Poly
   is (Pmult_Fold (B, C, 8));
   --  Cryptol's pmult at type [8] -> [8] -> [15]: the product of B and C
   --  as polynomials over GF(2).
   --  @param B The first factor.
   --  @param C The second factor.
   --  @return Their product, of degree at most 14.

   function Reduce (R : Poly; Y : Poly) return Byte
   is (if R >= 256 then Byte (R xor Y) else Byte (R))
   with Pre => R < 512 and then Y in 256 .. 511;
   --  One step of the remainder: R has degree at most 8 and Y exactly 8,
   --  so subtracting Y when the x^^8 coefficient of R is set leaves a
   --  remainder of degree at most 7.
   --  @param R The partial remainder, of degree at most 8.
   --  @param Y The modulus, of degree 8.
   --  @return R mod Y.

   function Pmod_Fold (X : Poly; Y : Poly; N : Natural) return Byte
   is (if N = 0 then 0
       else Reduce
              (Interfaces.Shift_Left (Poly (Pmod_Fold (X, Y, N - 1)), 1)
               or (if Product_Bit (X, N - 1) then 1 else 0),
               Y))
   with
     Pre                => N <= 15 and then Y in 256 .. 511,
     Subprogram_Variant => (Decreases => N);
   --  The first N steps of pmod x y: the remainder modulo Y of the leading
   --  N bits of the [15] X, by long division, most significant bit first.
   --  @param X The dividend, a [15].
   --  @param Y The modulus, of degree 8.
   --  @param N How many bits of X, from the most significant, to use.
   --  @return The remainder of those bits modulo Y.

   function Pmod (X : Poly; Y : Poly) return Byte
   is (Pmod_Fold (X, Y, 15))
   with Pre => Y in 256 .. 511;
   --  Cryptol's pmod at type [15] -> [9] -> [8]: the remainder of X
   --  modulo Y as polynomials over GF(2). The precondition is that Y has
   --  degree exactly 8, which GF28.cry's m does.
   --  @param X The dividend, a [15].
   --  @param Y The modulus, a [9] of degree 8.
   --  @return X mod Y.

   M : constant Poly := 16#11B#;
   --  GF28.cry, in (•): m = <| x^^8 + x^^4 + x^^3 + x + 1 |>, the AES
   --  polynomial [FIPS-PUB-197 Section 4.2].

   function Dot (B, C : Byte) return Byte
   is (Pmod (Pmult (B, C), M));
   --  GF28.cry: (•) b c = pmod (pmult b c) m. Multiplication in GF(2^8)
   --  [FIPS-PUB-197 Section 4.2].
   --  @param B The first factor.
   --  @param C The second factor.
   --  @return B • C.

   function xTimes (B : Byte) return Byte
   is (Interfaces.Shift_Left (B, 1) xor (if Head (B) then 16#1b# else 16#00#));
   --  GF28.cry: xTimes b = b << 1 ^ (if head b then 0x1b else 0x00). The
   --  product B • 0x02 [FIPS-PUB-197 Section 4.2].
   --  @param B The byte.
   --  @return B • 0x02.

end Foundation_Spark.AES.Spec.GF28;
