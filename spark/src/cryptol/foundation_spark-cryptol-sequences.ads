--  Cryptol's sequence built-ins that rearrange or replicate elements of
--  any type, over a sequence of variable length:
--
--  * `reverse : {n, a} (fin n) => [n]a -> [n]a` (Cryptol.cry:828, a
--    primitive), which "reverses the elements in a sequence";
--  * `repeat : {n, a} a -> [n]a` (Cryptol.cry:1215), by its Cryptol body
--    `repeat x = [ x | _ <- zero : [n] ]`: n copies of x.
--
--  @formal Index The index type of a sequence.
--  @formal Element The elements, Cryptol's `a`.
--  @formal Seq A sequence of elements, Cryptol's `[n]a`.

generic
   type Index is range <>;
   type Element is private;
   type Seq is array (Index range <>) of Element;
package Foundation_Spark.Cryptol.Sequences with
  SPARK_Mode,
  Pure
is

   function Reverse_Of (Xs : Seq) return Seq is
     ([for I in Xs'Range => Xs (Xs'Last - (I - Xs'First))])
   with
     Post => Reverse_Of'Result'First = Xs'First
             and then Reverse_Of'Result'Last = Xs'Last;
   --  Cryptol's `reverse xs`: element I is element n - 1 - I of Xs,
   --  counted from Xs'First. Reverse is an Ada reserved word. The result
   --  has the bounds of Xs.
   --  @param Xs The sequence.
   --  @return Xs in reverse order.

   function Repeat (Count : Index; X : Element) return Seq is
     ([for I in 0 .. Count - 1 => X])
   with
     Pre  => Count >= 0 and then Index'First <= 0,
     Post => Repeat'Result'First = 0 and then Repeat'Result'Length = Count;
   --  Cryptol's `` repeat`{Count} x ``: Count copies of X.
   --  @param Count The number of copies, Cryptol's `n`.
   --  @param X The element, Cryptol's `x`.
   --  @return Count copies of X, indexed from 0.

end Foundation_Spark.Cryptol.Sequences;
