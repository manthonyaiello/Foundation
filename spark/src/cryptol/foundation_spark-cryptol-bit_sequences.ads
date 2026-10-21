--  Cryptol's bit sequences of a given length that are not built from
--  other sequences: `zero` at type `[n]` and a numeric literal at type
--  `[n]`.
--
--  * `zero : {a} (Zero a) => a` (Cryptol.cry:304, a primitive) "gives an
--    arbitrary shaped value whose bits are all False".
--  * A numeric literal `` `v : [n] `` (RefMan BasicSyntax.rst:349, "a = [n]
--    where n >= width v") is the n-bit word whose value is v: its bits,
--    most significant first (Cryptol.cry:796). Literal states it by
--    recursion on n: the last bit is v mod 2, and the bits before it are
--    v / 2 in n - 1 bits.
--
--  @formal Index The index type of a bit sequence, from 0.
--  @formal Bits A bit sequence, Cryptol's `[n]`.

generic
   type Index is range <>;
   type Bits is array (Index range <>) of Boolean;
package Foundation_Spark.Cryptol.Bit_Sequences with
  SPARK_Mode,
  Pure
is

   pragma Compile_Time_Error
     (Index'First /= 0, "Cryptol's sequences are indexed from 0");

   function Zero (Count : Index) return Bits is
     ([for I in 0 .. Count - 1 => False])
   with Post => Zero'Result'First = 0 and then Zero'Result'Length = Count;
   --  Cryptol's `zero` at type `[Count]`: Count bits, all False.
   --  @param Count The number of bits, Cryptol's `n`.
   --  @return Count zero bits, indexed from 0.

   function Literal (Value, Width : Index) return Bits is
     (if Width = 0 then []
      else Literal (Value / 2, Width - 1) & [Value mod 2 = 1])
   with
     Subprogram_Variant => (Decreases => Width),
     Post               =>
       Literal'Result'First = 0 and then Literal'Result'Length = Width;
   --  Cryptol's literal `` `Value : [Width] ``, most significant bit
   --  first. Cryptol rejects a literal that does not fit its type; here a
   --  Value of 2 ** Width or more keeps its Width low bits, and a caller
   --  that mirrors a literal requires that it fits.
   --  @param Value The number, below 2 ** Width.
   --  @param Width The number of bits, Cryptol's `n`.
   --  @return The Width-bit big-endian representation of Value, indexed
   --  from 0.

end Foundation_Spark.Cryptol.Bit_Sequences;
