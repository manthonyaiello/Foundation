--  Cryptol's join and split between a sequence of words and its bits:
--  `join : {parts, each, a} (fin each) => [parts][each]a -> [parts *
--  each]a` (Cryptol.cry:815) and `split : {parts, each, a} (fin each) =>
--  [parts * each]a -> [parts][each]a` (Cryptol.cry:822), both primitives,
--  at `each = w` and `a = Bit`, with each word [w] held in a modular type.
--  The prelude documents them as inverses: join "concatenates a list of
--  sequences", and split "splits a sequence into 'parts' groups with 'each'
--  elements". So bit I of `join xs` is bit I mod w of word I / w, and word
--  K of `split p` is the w bits of p from K * w, read most significant
--  first (Words).
--
--  In Cryptol a word is its bits, so cutting w bits out of a sequence and
--  having a word are the same thing. Here a word is a number, and Value is
--  the conversion that has no name in the Cryptol: the Count bits from
--  First, as a number, by the recursion `value of the first Count bits =
--  2 * value of the first Count - 1 bits + the last bit`.
--
--  @formal Word The modular type each word is held in.
--  @formal Width Cryptol's `each`, the number of bits in a word, w.
--  @formal Shift_Right The right shift of Word (see Words).
--  @formal Word_Index The index type of a sequence of words.
--  @formal Words A sequence of words, Cryptol's `[parts][w]`.
--  @formal Bit_Index The index type of a bit sequence.
--  @formal Bits A bit sequence, Cryptol's `[parts * w]`.

with Foundation_Spark.Cryptol.Words;

generic
   type Word is mod <>;
   Width : Positive;
   with function Shift_Right (Value : Word; Amount : Natural) return Word;
   type Word_Index is range <>;
   type Words is array (Word_Index range <>) of Word;
   type Bit_Index is range <>;
   type Bits is array (Bit_Index range <>) of Boolean;
package Foundation_Spark.Cryptol.Join_Split with
  SPARK_Mode,
  Pure
is

   package Word_Bits is new Cryptol.Words (Word, Width, Shift_Right);
   --  Cryptol's `@` on a word [w], most significant bit first.

   function Join (Xs : Words) return Bits is
     ([for I in 0 .. Bit_Index (Xs'Length) * Bit_Index (Width) - 1 =>
         Word_Bits.Bit
           (Xs (Xs'First + Word_Index (I / Bit_Index (Width))),
            Natural (I mod Bit_Index (Width)))])
   with
     Pre  => Xs'Length <= Bit_Index'Last / Bit_Index (Width),
     Post => Join'Result'First = Bit_Index'(0)
             and then Join'Result'Last
                      = Bit_Index (Xs'Length) * Bit_Index (Width) - 1;
   --  Cryptol's `join xs` at [parts][w] -> [parts * w]: the words' bits in
   --  order, so bit I is bit I mod w of word I / w.
   --  @param Xs The words, with any bounds.
   --  @return Their bits, indexed from 0 as Cryptol's are.

   function Value
     (P : Bits; First : Bit_Index; Count : Natural) return Word
   is
     (if Count = 0 then 0
      else 2 * Value (P, First, Count - 1)
           + (if P (First + Bit_Index (Count) - 1) then 1 else 0))
   with
     Pre                =>
       Count <= Width
       and then First >= P'First
       and then First + Bit_Index (Count) - 1 <= P'Last,
     Subprogram_Variant => (Decreases => Count);
   --  The Count bits of P from First as a number, most significant first:
   --  at Count = w, the word that a [w] of bits is in Cryptol.
   --  @param P The bits.
   --  @param First The index of the first (most significant) bit.
   --  @param Count The number of bits read, at most w.
   --  @return The value of P (First .. First + Count - 1).

   function Split_At (P : Bits; K : Bit_Index) return Word is
     (Value (P, K * Bit_Index (Width), Width))
   with
     Pre => P'First = 0
            and then K >= 0
            and then K < Bit_Index'Last / Bit_Index (Width)
            and then (K + 1) * Bit_Index (Width) <= P'Length;
   --  Word K of Cryptol's `split p` at [parts * w] -> [parts][w]: the w
   --  bits of P from K * w.
   --  @param P The bits, `[parts * w]`, indexed from 0 as Cryptol's are.
   --  @param K The word's index, below parts.
   --  @return Word K.

end Foundation_Spark.Cryptol.Join_Split;
