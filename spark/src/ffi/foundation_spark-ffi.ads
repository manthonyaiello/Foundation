--  The FFI harness: SPARK spec-layer functions exported through C so
--  that Cryptol can call them by foreign, and properties in spark/cryptol/
--  can compare them with the NSA Cryptol they mirror.
--
--  The spec layer is ghost, and exporting a ghost function takes two
--  units per Cryptol module (spark/README.md, "The FFI harness"):
--
--  * a ghost shim unit (AES_GF28): ghost functions, Convention C,
--    External_Name => "spark_<Name>", each calling the spec function. A
--    ghost unit is the only place a ghost function can be called from.
--    Compiled with ghost code enabled, GNAT 16.1 links every ghost
--    entity under the name Ghost_Link_Prefix & its external name, so
--    "spark_xTimes" is linked as "___ghost_spark_xTimes";
--  * an export unit (AES_GF28_Exports): ordinary functions, Convention C,
--    External_Name => "spark_<Name>", the name Cryptol looks up, each
--    calling the ghost shim through an Import of its prefixed name.
--
--  Both are built only into the FFI library (foundation_spark_ffi.gpr),
--  which compiles with ghost code and assertions enabled. In the proof
--  build (foundation_spark.gpr) ghost code is ignored and the shims are
--  proved like any unit.

package Foundation_Spark.FFI with
  SPARK_Mode,
  Pure
is

   Ghost_Link_Prefix : constant String := "___ghost_";
   --  The prefix GNAT 16.1 puts on the link name of every ghost entity
   --  compiled with ghost code enabled, External_Name and Link_Name
   --  included. The export units import the ghost shims under it. If a
   --  later GNAT drops or changes it, the FFI library fails to link
   --  (foundation_spark_ffi.gpr links it with --no-undefined), rather
   --  than load and fail at the first call.

end Foundation_Spark.FFI;
