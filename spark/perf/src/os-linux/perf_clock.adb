--  Linux: clock_gettime (CLOCK_MONOTONIC), which Rust's Instant reads on
--  Linux.

with Interfaces.C;

package body Perf_Clock is

   use type Interfaces.C.long;

   CLOCK_MONOTONIC : constant := 1;
   --  <linux/time.h>.

   type Timespec is record
      Tv_Sec  : Interfaces.C.long;
      Tv_Nsec : Interfaces.C.long;
   end record
   with Convention => C;
   --  struct timespec on the 64-bit Linux ABIs.

   function Clock_Gettime
     (Clock_Id : Interfaces.C.int; Tp : access Timespec) return Interfaces.C.int
   with Import, Convention => C, External_Name => "clock_gettime";
   --  Read a clock.
   --  @param Clock_Id The clock.
   --  @param Tp Where to store its time.
   --  @return 0 on success.

   function Now return Interfaces.Unsigned_64 is
      T  : aliased Timespec := (0, 0);
      Rc : constant Interfaces.C.int := Clock_Gettime (CLOCK_MONOTONIC, T'Access);
      pragma Unreferenced (Rc);
   begin
      return Interfaces.Unsigned_64 (T.Tv_Sec * 1_000_000_000 + T.Tv_Nsec);
   end Now;

end Perf_Clock;
