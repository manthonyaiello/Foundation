--  macOS: clock_gettime_nsec_np (CLOCK_UPTIME_RAW), the mach_absolute_time
--  clock in nanoseconds, which Rust's Instant reads on macOS.

with Interfaces.C;

package body Perf_Clock is

   CLOCK_UPTIME_RAW : constant := 8;
   --  <time.h>: _CLOCK_UPTIME_RAW.

   function Clock_Gettime_Nsec_Np
     (Clock_Id : Interfaces.C.int) return Interfaces.Unsigned_64
   with Import, Convention => C, External_Name => "clock_gettime_nsec_np";
   --  The clock's time.
   --  @param Clock_Id The clock.
   --  @return Its time in nanoseconds.

   function Now return Interfaces.Unsigned_64 is
     (Clock_Gettime_Nsec_Np (CLOCK_UPTIME_RAW));

end Perf_Clock;
