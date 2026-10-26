--  The benchmark clock: the same monotonic clock that Rust's
--  std::time::Instant reads on each system, so the two harnesses time with
--  one source: clock_gettime_nsec_np (CLOCK_UPTIME_RAW) on macOS
--  (os-darwin/), clock_gettime (CLOCK_MONOTONIC) on Linux (os-linux/).

with Interfaces;

package Perf_Clock is

   function Now return Interfaces.Unsigned_64;
   --  The monotonic clock.
   --  @return The time in nanoseconds since an arbitrary origin.

end Perf_Clock;
