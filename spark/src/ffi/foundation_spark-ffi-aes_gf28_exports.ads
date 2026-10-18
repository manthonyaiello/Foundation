--  The exports Cryptol calls for algorithms/AES/GF28.cry: spark_xTimes
--  and spark_Dot, the names spark/cryptol/SPARK/AES/GF28.cry declares
--  foreign.
--
--  Not ghost, so GNAT links them under their External_Name. Each calls
--  its ghost shim in AES_GF28 through an Import of the shim's link name,
--  Ghost_Link_Prefix & its External_Name (see Foundation_Spark.FFI): a
--  non-ghost unit cannot name a ghost function, but it can call a symbol.

with Interfaces;

package Foundation_Spark.FFI.AES_GF28_Exports with
  SPARK_Mode
is

   subtype C_Byte is Interfaces.Unsigned_8;
   --  A Cryptol [8] in the C calling convention: uint8_t.

   function Ghost_xTimes (B : C_Byte) return C_Byte
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_xTimes",
     Global        => null;
   --  The ghost shim AES_GF28.xTimes, by its link name. Global => null
   --  states what the shim's own (proved) Global is: it reads no state.
   --  @param B The byte.
   --  @return The spec's xTimes (B).

   function Ghost_Dot (B, C : C_Byte) return C_Byte
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_Dot",
     Global        => null;
   --  The ghost shim AES_GF28.Dot, by its link name. Global => null, as
   --  for Ghost_xTimes.
   --  @param B The first factor.
   --  @param C The second factor.
   --  @return The spec's Dot (B, C).

   function xTimes (B : C_Byte) return C_Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_xTimes";
   --  Cryptol's foreign spark_xTimes : [8] -> [8].
   --  @param B The byte.
   --  @return Ghost_xTimes (B).

   function Dot (B, C : C_Byte) return C_Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_Dot";
   --  Cryptol's foreign spark_Dot : [8] -> [8] -> [8].
   --  @param B The first factor.
   --  @param C The second factor.
   --  @return Ghost_Dot (B, C).

end Foundation_Spark.FFI.AES_GF28_Exports;
