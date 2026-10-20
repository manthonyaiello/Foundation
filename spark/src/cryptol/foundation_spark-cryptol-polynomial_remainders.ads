--  Cryptol's remainder of polynomials over GF(2), `pmod : {u, v} (fin u,
--  fin v) => [u] -> [1 + v] -> [v]` (Cryptol.cry:1015, a primitive that
--  "performs modulus of polynomials over GF(2)"; docs/CryptolPrims.md,
--  "GF(2) polynomials"). Words are polynomials by their bits, as in
--  Polynomial_Products.
--
--  Stated as long division over the bits of the dividend, most
--  significant first: the remainder of the leading N bits is the
--  remainder of the leading N - 1 bits times x, plus bit N - 1, reduced
--  once by the modulus. A partial remainder has degree below the
--  modulus's, so after the shift it has degree at most the modulus's, and
--  one subtraction (exclusive or) of the modulus, when its coefficient of
--  x ^^ (pdeg m) is set, brings it back below. Top (M) is that leading
--  term, x ^^ (pdeg m). Cryptol reports "division by 0" for a zero
--  modulus, so M /= 0 is a precondition.
--
--  @formal Poly The modular type the polynomials are held in.
--  @formal U Cryptol's `u`: the dividend is a [u].
--  @formal V Cryptol's `v`: the modulus is a [1 + v] and the remainder a
--  [v].
--  @formal Shift_Right The right shift of Poly (see Words).

with Foundation_Spark.Cryptol.Words;

generic
   type Poly is mod <>;
   U : Natural;
   V : Natural;
   with function Shift_Right (Value : Poly; Amount : Natural) return Poly;
package Foundation_Spark.Cryptol.Polynomial_Remainders with
  SPARK_Mode,
  Pure
is

   pragma Compile_Time_Error
     (2 ** U >= Poly'Modulus or else 2 ** (1 + V) >= Poly'Modulus,
      "pmod's [u] and [1 + v] must fit in Poly, with a bit to spare");

   package Dividend is new Cryptol.Words (Poly, U, Shift_Right);
   --  Cryptol's `@` on the dividend, a [u].

   function Top (M : Poly) return Poly is
     (if M <= 1 then M else 2 * Top (M / 2))
   with Subprogram_Variant => (Decreases => M);
   --  The leading term of a polynomial, x ^^ (pdeg m): the largest power
   --  of 2 not above M (0 for M = 0).
   --  @param M The polynomial.
   --  @return Its leading term.

   function Reduce (T, M : Poly) return Poly is
     (if T >= Top (M) then T xor M else T);
   --  One step of the long division: T, of degree at most pdeg m, less M
   --  when its coefficient of x ^^ (pdeg m) is set.
   --  @param T The partial remainder after the shift.
   --  @param M The modulus.
   --  @return T reduced below the degree of M.

   function Remainders (X, M : Poly; N : Natural) return Poly is
     (if N = 0 then 0
      else Reduce
             (2 * Remainders (X, M, N - 1)
              + (if Dividend.Bit (X, N - 1) then 1 else 0),
              M))
   with
     Pre                => N <= U,
     Subprogram_Variant => (Decreases => N);
   --  The remainder modulo M of the leading N bits of the [u] X (the
   --  polynomial they make, read as an N-bit word).
   --  @param X The dividend.
   --  @param M The modulus.
   --  @param N How many bits of X, from the most significant, to use.
   --  @return The remainder of those bits modulo M.

   function Pmod (X, M : Poly) return Poly is
     (Remainders (X, M, U))
   with Pre => X < 2 ** U and then M < 2 ** (1 + V) and then M /= 0;
   --  Cryptol's `pmod x m`: the remainder of X modulo M as polynomials over
   --  GF(2), of degree below M's.
   --  @param X The dividend, a [u].
   --  @param M The modulus, a [1 + v], not zero.
   --  @return X mod M, a [v].

end Foundation_Spark.Cryptol.Polynomial_Remainders;
