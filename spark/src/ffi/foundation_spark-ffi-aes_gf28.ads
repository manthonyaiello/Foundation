--  The ghost shims for algorithms/AES/GF28.cry: the spec functions xTimes
--  and (•), exported with Cryptol's C calling convention (a [8] is a
--  uint8_t, passed and returned by value). They are checked by
--  spark/cryptol/SPARK/AES/GF28.cry.
--
--  Ghost, because the spec layer is: only ghost code can call it. GNAT
--  therefore links each one under Ghost_Link_Prefix & its External_Name,
--  and AES_GF28_Exports gives it the name Cryptol looks up (see
--  Foundation_Spark.FFI).
--
--  Spec_xTimes and Spec_Dot name the spec functions the shims call. They
--  rename the stand-in Foundation_Spark.FFI.GF28 until M1.1's
--  Foundation_Spark.AES.Spec.GF28 is on the stack; pointing the shims at
--  that unit changes the with clause and the two renamings. (A package
--  renaming would make it one line, but gnatdoc 26 cannot document one.)

with Interfaces;
with Foundation_Spark.FFI.GF28;

package Foundation_Spark.FFI.AES_GF28 with
  SPARK_Mode,
  Ghost
is

   use type Interfaces.Unsigned_8;

   subtype C_Byte is Interfaces.Unsigned_8;
   --  A Cryptol [8] in the C calling convention: uint8_t.

   function Spec_xTimes (B : C_Byte) return C_Byte
     renames Foundation_Spark.FFI.GF28.xTimes;
   --  The spec function exported as spark_xTimes: GF28.cry's xTimes.
   --  @param B The byte.
   --  @return B • 0x02.

   function Spec_Dot (B, C : C_Byte) return C_Byte
     renames Foundation_Spark.FFI.GF28.Dot;
   --  The spec function exported as spark_Dot: GF28.cry's (•).
   --  @param B The first factor.
   --  @param C The second factor.
   --  @return B • C.

   function xTimes (B : C_Byte) return C_Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_xTimes",
     Post          => xTimes'Result = Spec_xTimes (B);
   --  GF28.cry's xTimes, as the spec states it.
   --  @param B The byte.
   --  @return Spec_xTimes (B).

   function Dot (B, C : C_Byte) return C_Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_Dot",
     Post          => Dot'Result = Spec_Dot (B, C);
   --  GF28.cry's (•), as the spec states it (Dot).
   --  @param B The first factor.
   --  @param C The second factor.
   --  @return Spec_Dot (B, C).

end Foundation_Spark.FFI.AES_GF28;
