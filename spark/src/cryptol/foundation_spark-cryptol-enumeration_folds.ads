--  Cryptol's left fold (Cryptol.cry:1146, see Folds) over an enumeration
--  `[From ..< To]` (RefMan BasicTypes.rst:169, the exclusive-bound
--  enumeration), with a function that closes over a value E: Cryptol's
--  `foldl f z [From ..< To]` where `f` is a local definition that mentions
--  E, as `step`'s local step3 mentions the block M (algorithms/SHA2/
--  Main.cry:75).
--
--  Two representation choices, neither of which changes the meaning:
--
--  * Ada's generic formal functions are not closures, so the value the
--    Cryptol function closes over is F's first argument, E, which the fold
--    passes along unchanged. F (E, Z, X) is Cryptol's `f z x`.
--  * The enumeration is given by its bounds, not built as an array: its
--    last element is To - 1 and the elements before it are `[From ..< To
--    - 1]`.
--
--  As in Folds, the recursion is from the last element, as the prelude's
--  example `((0 + 1) + 2) + 3` reads: `foldl f z [From ..< To] = f (foldl f
--  z [From ..< To - 1]) (To - 1)`, and Z when the enumeration is empty.
--
--  @formal Env The value the Cryptol function closes over.
--  @formal Acc The accumulator, Cryptol's `a`.
--  @formal Index The elements of the enumeration. F is applied only to
--  values of Index, so an F with a precondition on its element is
--  instantiated with the subtype that precondition allows.
--  @formal F The function folded, Cryptol's `f : a -> b -> a` with the
--  value it closes over made explicit: F (E, Z, X) is `f z x`.

generic
   type Env (<>) is private;
   type Acc is private;
   type Index is range <>;
   with function F (E : Env; Z : Acc; X : Index) return Acc;
package Foundation_Spark.Cryptol.Enumeration_Folds with
  SPARK_Mode,
  Pure
is

   function Foldl
     (E : Env; Z : Acc; From, To : Index'Base) return Acc
   is
     (if To <= From then Z else F (E, Foldl (E, Z, From, To - 1), To - 1))
   with
     Pre                =>
       From >= Index'First and then (To <= From or else To - 1 <= Index'Last),
     Subprogram_Variant => (Decreases => To);
   --  Cryptol's `foldl f z [From ..< To]`, with f closed over E: Z when
   --  the enumeration is empty, and otherwise F applied to the fold of
   --  `[From ..< To - 1]` and To - 1.
   --  @param E The value the Cryptol function closes over.
   --  @param Z The initial accumulator, Cryptol's `z`.
   --  @param From The first element of the enumeration.
   --  @param To The enumeration's exclusive bound.
   --  @return The accumulator after F has been applied to each of From ..
   --  To - 1, in order.

end Foundation_Spark.Cryptol.Enumeration_Folds;
