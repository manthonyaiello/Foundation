--  Cryptol's quotient of polynomials over GF(2), `pdiv : {u, v} (fin u,
--  fin v) => [u] -> [v] -> [u]` (Cryptol.cry:1010, a primitive that
--  "performs division of polynomials over GF(2)"; docs/CryptolPrims.md,
--  "GF(2) polynomials"). Words are polynomials by their bits, as in
--  Polynomial_Products.
--
--  Stated as the long division of Polynomial_Remainders, which this
--  instantiates for its divisor, a [v] = [1 + (v - 1)]: each step adds one
--  quotient bit, set when the step subtracts the divisor. Cryptol reports
--  "division by 0" for a zero divisor, so Y /= 0 is a precondition, and a
--  [0] divisor can only be zero, so v is at least 1.
--
--  @formal Poly The modular type the polynomials are held in.
--  @formal U Cryptol's `u`: the dividend and the quotient are [u].
--  @formal V Cryptol's `v`: the divisor is a [v].
--  @formal Shift_Right The right shift of Poly (see Words).

with Foundation_Spark.Cryptol.Polynomial_Remainders;

generic
   type Poly is mod <>;
   U : Natural;
   V : Positive;
   with function Shift_Right (Value : Poly; Amount : Natural) return Poly;
package Foundation_Spark.Cryptol.Polynomial_Quotients with
  SPARK_Mode,
  Pure
is

   package Division is new Cryptol.Polynomial_Remainders
     (Poly, U, V - 1, Shift_Right);
   --  The long division by a [v], whose remainders the quotient follows.

   function Quotients (X, Y : Poly; N : Natural) return Poly is
     (if N = 0 then 0
      else 2 * Quotients (X, Y, N - 1)
           + (if 2 * Division.Remainders (X, Y, N - 1)
                 + (if Division.Dividend.Bit (X, N - 1) then 1 else 0)
                 >= Division.Top (Y)
              then 1 else 0))
   with
     Pre                => N <= U,
     Subprogram_Variant => (Decreases => N);
   --  The quotient by Y of the leading N bits of the [u] X: one bit per
   --  step of Division.Remainders, set when that step subtracts Y.
   --  @param X The dividend.
   --  @param Y The divisor.
   --  @param N How many bits of X, from the most significant, to use.
   --  @return The quotient of those bits by Y.

   function Pdiv (X, Y : Poly) return Poly is
     (Quotients (X, Y, U))
   with Pre => X < 2 ** U and then Y < 2 ** V and then Y /= 0;
   --  Cryptol's `pdiv x y`: the quotient of X by Y as polynomials over
   --  GF(2).
   --  @param X The dividend, a [u].
   --  @param Y The divisor, a [v], not zero.
   --  @return X divided by Y, a [u].

end Foundation_Spark.Cryptol.Polynomial_Quotients;
