--  Cryptol's index operator on a word, `(@) : {n, a, ix} (Integral ix) =>
--  [n]a -> ix -> a` (Cryptol.cry:900, a primitive) at `a = Bit`, for a word
--  `[w]` held in a modular type. "The zero-based index of the element to
--  select" (Cryptol.cry:897), with element 0 the most significant bit
--  (Cryptol.cry:796, see Foundation_Spark.Cryptol): bit J of a [w] has
--  weight 2 ** (w - 1 - J).
--
--  The word may be held in a modular type wider than w (AES holds the
--  [15] product of pmult in an Unsigned_16); its value is then below
--  2 ** w, and the bits above w are not Cryptol's.
--
--  @formal Word The modular type the word is held in.
--  @formal Width Cryptol's `n` (here `w`), the number of bits in the word.
--  @formal Shift_Right The right shift of Word, Cryptol's `>>` on [w]:
--  Interfaces.Shift_Right for an Interfaces type, or division by a power
--  of 2.

generic
   type Word is mod <>;
   Width : Natural;
   with function Shift_Right (Value : Word; Amount : Natural) return Word;
package Foundation_Spark.Cryptol.Words with
  SPARK_Mode,
  Pure
is

   pragma Compile_Time_Error
     (2 ** Width > Word'Modulus, "a [w] must fit in Word");

   function Bit (X : Word; J : Natural) return Boolean is
     ((Shift_Right (X, Width - 1 - J) and 1) = 1)
   with Pre => J < Width;
   --  Cryptol's `x @ j` on a [w]: the bit of weight 2 ** (w - 1 - J),
   --  most significant first.
   --  @param X The word.
   --  @param J The bit's index, below w.
   --  @return Whether that bit is 1.

   function Head (X : Word) return Boolean is
     (Bit (X, 0))
   with Pre => Width > 0;
   --  Cryptol's `head x` on a [w], by its Cryptol body `head xs = xs @ (0
   --  : [8])` (Cryptol.cry:855): its most significant bit. Cryptol types
   --  it [1 + n], so w is at least 1.
   --  @param X The word.
   --  @return Whether its most significant bit is 1.

end Foundation_Spark.Cryptol.Words;
