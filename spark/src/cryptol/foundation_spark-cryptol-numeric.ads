--  Cryptol's ceiling division and modulus on numeric types, the type
--  operators `m /^ n` (Cryptol.cry:135, "divide numeric types, rounding
--  up") and `m %^ n` (Cryptol.cry:141, "how much we need to add to make a
--  proper multiple of the second argument"), both with `(fin n, n >= 1)`.
--  Cryptol computes them on types; a spec layer that has a type parameter
--  as a value (a length) computes them on values, here. Ada has no
--  operators /^ and %^, so they are Ceil_Div and Ceil_Mod.
--
--  @formal Num The integers the type-level naturals are held in.

generic
   type Num is range <>;
package Foundation_Spark.Cryptol.Numeric with
  SPARK_Mode,
  Pure
is

   pragma Compile_Time_Error
     (Num'First < 0, "Cryptol's numeric types are naturals");

   function Ceil_Div (A, B : Num) return Num is
     ((A + (B - 1)) / B)
   with Pre => B > 0 and then A <= Num'Last - B;
   --  Cryptol's `a /^ b`: the least n with n * b >= a.
   --  @param A The dividend, a natural.
   --  @param B The divisor, positive.
   --  @return A divided by B, rounded up.

   function Ceil_Mod (A, B : Num) return Num is
     (Ceil_Div (A, B) * B - A)
   with Pre => B > 0 and then A <= Num'Last - B;
   --  Cryptol's `a %^ b`: `b * (a /^ b) - a`, the distance from A up to
   --  the next multiple of B.
   --  @param A The dividend, a natural.
   --  @param B The divisor, positive.
   --  @return What A lacks of a multiple of B.

end Foundation_Spark.Cryptol.Numeric;
