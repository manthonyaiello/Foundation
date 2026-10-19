--  The completion of Foundation_Spark_Coverage: the dump, and its
--  registration with atexit.

with Interfaces.C;

package body Foundation_Spark_Coverage is

   --  A C function pointer to a parameterless procedure, as atexit takes.
   type Exit_Handler is access procedure with
     Convention => C;

   --  The C library's atexit (3). A handler registered from a shared
   --  library runs at exit, or when the library is unloaded.
   function Atexit (Handler : Exit_Handler) return Interfaces.C.int with
     Import, Convention => C, External_Name => "atexit";

   procedure Dump is
   begin
      pragma Annotate (Xcov, Dump_Buffers);
      null;
   end Dump;

   --  Atexit's status: zero when Dump was registered. Nonzero leaves the
   --  process without a trace, which check-coverage.sh reports as a run
   --  that wrote none.
   Registered : constant Interfaces.C.int := Atexit (Dump'Access) with
     Unreferenced;

end Foundation_Spark_Coverage;
