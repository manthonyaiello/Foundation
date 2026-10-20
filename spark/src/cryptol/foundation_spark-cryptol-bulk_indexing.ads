--  Cryptol's bulk index operator `(@@) : {n, k, ix, a} (Integral ix) =>
--  [n]a -> [k]ix -> [k]a` (Cryptol.cry:906), by its Cryptol body
--  `xs @@ is = [ xs @ i | i <- is ]`: element J of the result is the
--  element of Xs at index J of Is.
--
--  Over sequences of fixed length, as AES uses it on a block (ShiftRows,
--  `bs @@ [0, 5, 10, ...]`) and on a table indexed by bytes (SubBytes,
--  `SBox @@ bs`). Ada has no operator @@, so the function is Bulk_Index.
--
--  @formal Index The indices of Xs, Cryptol's `ix` (and `n` its range).
--  @formal Element The elements, Cryptol's `a`.
--  @formal Seq The sequence indexed, Cryptol's `[n]a`.
--  @formal Out_Index The indices of the index sequence and the result
--  (`k` their range).
--  @formal Indices The index sequence, Cryptol's `[k]ix`.
--  @formal Out_Seq The result, Cryptol's `[k]a`.

generic
   type Index is (<>);
   type Element is private;
   type Seq is array (Index) of Element;
   type Out_Index is (<>);
   type Indices is array (Out_Index) of Index;
   type Out_Seq is array (Out_Index) of Element;
package Foundation_Spark.Cryptol.Bulk_Indexing with
  SPARK_Mode,
  Pure
is

   function Bulk_Index (Xs : Seq; Ixs : Indices) return Out_Seq is
     ([for J in Out_Index => Xs (Ixs (J))]);
   --  Cryptol's `xs @@ is` (`is` is an Ada reserved word, so the index
   --  sequence is Ixs).
   --  @param Xs The sequence indexed.
   --  @param Ixs The indices, in the order the result takes them.
   --  @return The elements of Xs at Is.

end Foundation_Spark.Cryptol.Bulk_Indexing;
