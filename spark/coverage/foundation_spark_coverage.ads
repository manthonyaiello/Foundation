--  The coverage dump (#49): in the coverage build of the FFI library only
--  (foundation_spark_ffi.gpr with FOUNDATION_SPARK_FFI_BUILD=coverage, as
--  scripts/check-coverage.sh builds it), never in the crate, the proof or
--  the FFI check.
--
--  Cryptol loads the library through foreign and has no Ada main, so
--  gnatcov's atexit and main-end triggers, which it inserts into mains,
--  have nowhere to go. This unit's elaboration (the library elaborates
--  itself when it is loaded) registers Dump with the C library's atexit;
--  gnatcov instrument --dump-trigger=manual replaces the pragma in Dump
--  with the call that writes the coverage buffers to a source trace. Each
--  cryptol process therefore writes its own trace when it exits.

package Foundation_Spark_Coverage with
  Elaborate_Body
is

   --  Write the coverage buffers of every unit of interest to a source
   --  trace file (in the directory GNATCOV_TRACE_FILE names, when it ends
   --  with a slash). Registered with atexit at elaboration. Uninstrumented,
   --  it does nothing.
   procedure Dump with
     Convention => C;

end Foundation_Spark_Coverage;
