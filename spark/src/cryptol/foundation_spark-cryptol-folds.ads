--  Cryptol's left fold over a sequence, `foldl : {n, a, b} (fin n) =>
--  (a -> b -> a) -> a -> [n]b -> a` (Cryptol.cry:1146). It is a primitive,
--  with no Cryptol body; the prelude documents it by example, `foldl (+) 0
--  [1,2,3] = ((0 + 1) + 2) + 3`: the function is applied to the
--  accumulator and each element in turn, from the first, so the outermost
--  application is to the last element. Foldl_Take states that by
--  recursion on the number of elements folded, `foldl f z (take`{N} xs) =
--  f (foldl f z (take`{N - 1} xs)) (xs @ (N - 1))`, and Foldl is the fold
--  of the whole sequence.
--
--  The recursion runs from the last element because that is how the
--  implementation layer runs a fold, one element at a time in a loop: its
--  invariant after N elements is the fold of the first N, and the next
--  step is the definition. The equivalent recursion from the first
--  element, `foldl f z ([x] # xs) = foldl f (f z x) xs`, is a theorem
--  about this one; nothing in the spec layers needs it yet.
--
--  For a fold whose function closes over other values, as SHA-2's step3
--  closes over the block, see Enumeration_Folds.
--
--  @formal Acc The accumulator, Cryptol's `a`.
--  @formal Index The index type of the sequence.
--  @formal Element The elements, Cryptol's `b`.
--  @formal Seq A sequence of elements, Cryptol's `[n]b`.
--  @formal F The function folded, Cryptol's `f : a -> b -> a`, with its
--  arguments in Cryptol's order: the accumulator, then the element.

generic
   type Acc is private;
   type Index is range <>;
   type Element is private;
   type Seq is array (Index range <>) of Element;
   with function F (Z : Acc; X : Element) return Acc;
package Foundation_Spark.Cryptol.Folds with
  SPARK_Mode,
  Pure
is

   function Foldl_Take (Z : Acc; Xs : Seq; N : Index'Base) return Acc is
     (if N <= 0 then Z
      else F (Foldl_Take (Z, Xs, N - 1), Xs (Xs'First + (N - 1))))
   with
     Pre                => N <= Xs'Length,
     Subprogram_Variant => (Decreases => N);
   --  Cryptol's `foldl f z (take`{N} xs)`: Z when N is 0, and otherwise F
   --  applied to the fold of the first N - 1 elements and element N - 1.
   --  @param Z The initial accumulator, Cryptol's `z`.
   --  @param Xs The sequence, Cryptol's `xs`, with any bounds.
   --  @param N The number of elements folded, from the first.
   --  @return The accumulator after F has been applied to each of the
   --  first N elements of Xs, in order.

   function Foldl (Z : Acc; Xs : Seq) return Acc is
     (Foldl_Take (Z, Xs, Xs'Length))
   with Pre => Xs'Length <= Index'Base'Last;
   --  Cryptol's `foldl f z xs`: the fold of every element of Xs.
   --  @param Z The initial accumulator, Cryptol's `z`.
   --  @param Xs The sequence, Cryptol's `xs`, with any bounds.
   --  @return The accumulator after F has been applied to each element of
   --  Xs, in order.

end Foundation_Spark.Cryptol.Folds;
