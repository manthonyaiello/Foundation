--  Secure Hash Algorithm notation [FIPS-PUB-180-4 Section 3.2], mirroring
--  algorithms/SHA2/Notation.cry: the shift and rotate operations that
--  Functions.cry builds the SHA-2 logical functions from.
--
--  In the Cryptol, SHR and ROTR take the type parameters `{n, w}`. Here
--  those are this generic's formals, so an instance holds the Cryptol's
--  SHR`{n} and ROTR`{n} at one word size. The constraint `n < w` and the
--  requirement that Word be `[w]` are checked when the generic is
--  instantiated, by pragmas Compile_Time_Error, as Cryptol checks them
--  when it instantiates the type parameters.
--
--  Not mirrored, because SHA-256 does not use it: ROTL (SHA-1). The
--  Cryptol's examples and properties (hexDigitIs4Bits to ROTRAsROTL) are
--  statements about the notation, not functions to mirror.
--
--  @formal N Cryptol's `n`, the shift or rotation amount, below Word_Size.
--  @formal Word_Size Cryptol's `w`, the number of bits in a word.
--  @formal Word Cryptol's `Word w`, that is `[w]`: its modulus must be
--  2 ** Word_Size.

generic
   N : Natural;
   Word_Size : Positive;
   type Word is mod <>;
package Foundation_Spark.SHA2.Notation with
  SPARK_Mode,
  Pure
is

   pragma Compile_Time_Error
     (N >= Word_Size, "Notation.cry requires n < w");
   pragma Compile_Time_Error
     (Word'Modulus /= 2 ** Word_Size,
      "Notation.cry: Word must be [w], that is mod 2 ** Word_Size");

   function SHR (X : Word) return Word is (X / 2 ** N);
   --  The right shift operation, Cryptol's `SHR x = x >> `n`
   --  (Notation.cry:60, [FIPS-PUB-180-4 Section 3.2]). A right shift by
   --  n of a w-bit word is division by 2 ** n.
   --  @param X The word to shift.
   --  @return X shifted right by N bits, with zeros shifted in.

   function ROTR (X : Word) return Word is
     (X / 2 ** N or X * 2 ** (Word_Size - N));
   --  The rotate right (circular right shift) operation, Cryptol's
   --  `ROTR x = x >>> `n` (Notation.cry:67, [FIPS-PUB-180-4 Section
   --  3.2]). Stated as FIPS defines it, and as Cryptol's
   --  `ROTRIsRightCircularShift` (Notation.cry:107) proves it equal to
   --  `>>>`: `(x >> `n) || (x << `(w - n))`. A left shift by w - n is a
   --  multiplication by 2 ** (w - n) modulo 2 ** w.
   --  @param X The word to rotate.
   --  @return X rotated right by N bits.

end Foundation_Spark.SHA2.Notation;
