--  CI demonstration unit for issue #3. Removed before the PR's final head.

package Foundation_Spark.CI_Probe with
  SPARK_Mode
is

   function Halve (X : Natural) return Natural
   with Post => Halve'Result <= X;
   --  Return half of X, rounded down.
   --  @param X The value to halve.
   --  @return X / 2.

   function Count_Up (N : Natural) return Natural
   with Post => Count_Up'Result = N;
   --  Count from zero up to N, one step at a time.
   --  @param N How far to count.
   --  @return N.

   function Undocumented (X : Integer) return Integer is (X);

end Foundation_Spark.CI_Probe;
