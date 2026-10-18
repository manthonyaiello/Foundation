--  CI demonstration unit for issue #3. Removed before the PR's final head.

package body Foundation_Spark.CI_Probe with
  SPARK_Mode
is

   function Halve (X : Natural) return Natural is (X / 2);

   function Count_Up (N : Natural) return Natural is
      R : Natural := 0;
   begin
      pragma Assume (N < 1_000);
      for I in 1 .. N loop
         R := R + 1;
         pragma Loop_Invariant (R = I);
      end loop;
      return R;
   end Count_Up;

end Foundation_Spark.CI_Probe;
