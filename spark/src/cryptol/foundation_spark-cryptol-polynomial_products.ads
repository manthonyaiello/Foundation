--  Cryptol's product of polynomials over GF(2), `pmult : {u, v} (fin u,
--  fin v) => [1 + u] -> [1 + v] -> [1 + u + v]` (Cryptol.cry:1005, a
--  primitive that "performs multiplication of polynomials over GF(2)";
--  docs/CryptolPrims.md, "GF(2) polynomials").
--
--  A word is a polynomial by its bits: the bit of weight 2 ** i is the
--  coefficient of x ^^ i, as Cryptol's polynomial literals are (RefMan
--  BasicSyntax.rst:352, `<| x^^4 + x^^3 + x |>` is 0b11010). Addition of
--  polynomials over GF(2) is exclusive or, and multiplication by x is a
--  shift left, so the product is the long multiplication by Y's bits, most
--  significant first: Products (X, Y, N) is X times the leading N bits of
--  Y, and the next bit doubles it (one more power of x) and adds X if the
--  bit is set.
--
--  The words are held in one modular type, Poly, wide enough for the
--  product: an instance with 1 + u + v bits or more than Poly holds is
--  rejected when it is instantiated.
--
--  @formal Poly The modular type the polynomials are held in.
--  @formal U Cryptol's `u`: the first factor is a [1 + u].
--  @formal V Cryptol's `v`: the second factor is a [1 + v].
--  @formal Shift_Right The right shift of Poly (see Words).

with Foundation_Spark.Cryptol.Words;

generic
   type Poly is mod <>;
   U : Natural;
   V : Natural;
   with function Shift_Right (Value : Poly; Amount : Natural) return Poly;
package Foundation_Spark.Cryptol.Polynomial_Products with
  SPARK_Mode,
  Pure
is

   pragma Compile_Time_Error
     (2 ** (1 + U + V) >= Poly'Modulus,
      "pmult's [1 + u + v] must fit in Poly, with a bit to spare");

   package Second_Factor is new Cryptol.Words (Poly, 1 + V, Shift_Right);
   --  Cryptol's `@` on the second factor, a [1 + v].

   function Products (X, Y : Poly; N : Natural) return Poly is
     (if N = 0 then 0
      else 2 * Products (X, Y, N - 1)
           xor (if Second_Factor.Bit (Y, N - 1) then X else 0))
   with
     Pre                => N <= 1 + V,
     Subprogram_Variant => (Decreases => N);
   --  X times the leading N bits of Y (the polynomial they make, read as
   --  an N-bit word), by long multiplication, most significant bit first.
   --  @param X The first factor.
   --  @param Y The second factor.
   --  @param N How many bits of Y, from the most significant, to use.
   --  @return The partial product.

   function Pmult (X, Y : Poly) return Poly is
     (Products (X, Y, 1 + V))
   with Pre => X < 2 ** (1 + U) and then Y < 2 ** (1 + V);
   --  Cryptol's `pmult x y`: the product of X and Y as polynomials over
   --  GF(2), of degree at most u + v.
   --  @param X The first factor, a [1 + u].
   --  @param Y The second factor, a [1 + v].
   --  @return Their product, a [1 + u + v].

end Foundation_Spark.Cryptol.Polynomial_Products;
