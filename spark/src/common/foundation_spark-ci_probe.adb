--  CI demonstration unit for issue #3. Removed before the PR's final head.

package body Foundation_Spark.CI_Probe with
  SPARK_Mode
is

   function Halve (X : Natural) return Natural is (X / 2);

   function Count_Up (N : Natural) return Natural is
      R : Natural := 0;
   begin
      for I in 1 .. N loop
         R := R + 1;
         pragma Loop_Invariant (R = I);
      end loop;
      return R;
   end Count_Up;

   function Check (X : Integer) return Integer is
   begin
      pragma Assert (X > 0);
      return X;
   end Check;

end Foundation_Spark.CI_Probe;
