--  The exports Cryptol calls for algorithms/AES/SBox.cry: spark_SBox and
--  spark_InvSBox, the names spark/cryptol/SPARK/AES/SBox.cry declares
--  foreign. Each calls its ghost shim in AES_SBox through an Import of the
--  shim's link name (see Foundation_Spark.FFI and AES_GF28_Exports).

with Interfaces;

package Foundation_Spark.FFI.AES_SBox_Exports with
  SPARK_Mode
is

   subtype C_Byte is Interfaces.Unsigned_8;
   --  A Cryptol [8] in the C calling convention: uint8_t.

   function Ghost_SBox (B : C_Byte) return C_Byte
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_SBox",
     Global        => null;
   --  The ghost shim AES_SBox.SBox, by its link name. Global => null
   --  states what the shim's own (proved) Global is: it reads no state.
   --  @param B The byte.
   --  @return The spec's SBox (B).

   function Ghost_InvSBox (B : C_Byte) return C_Byte
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_InvSBox",
     Global        => null;
   --  The ghost shim AES_SBox.InvSBox, by its link name. Global => null,
   --  as for Ghost_SBox.
   --  @param B The byte.
   --  @return The spec's InvSBox (B).

   function SBox (B : C_Byte) return C_Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_SBox";
   --  Cryptol's foreign spark_SBox : [8] -> [8].
   --  @param B The byte.
   --  @return Ghost_SBox (B).

   function InvSBox (B : C_Byte) return C_Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvSBox";
   --  Cryptol's foreign spark_InvSBox : [8] -> [8].
   --  @param B The byte.
   --  @return Ghost_InvSBox (B).

end Foundation_Spark.FFI.AES_SBox_Exports;
