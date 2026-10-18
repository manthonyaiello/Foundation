--  The ghost shims for algorithms/AES/SBox.cry: the spec tables SBox and
--  InvSBox, read at a byte and exported with Cryptol's C calling
--  convention (a [8] is a uint8_t, passed and returned by value). They are
--  checked by spark/cryptol/SPARK/AES/SBox.cry.
--
--  Ghost, because the spec layer is; AES_SBox_Exports gives each the name
--  Cryptol looks up (see Foundation_Spark.FFI).

with Interfaces;
with Foundation_Spark.AES.Spec.SBox;

package Foundation_Spark.FFI.AES_SBox with
  SPARK_Mode,
  Ghost
is

   use type Interfaces.Unsigned_8;

   subtype C_Byte is Interfaces.Unsigned_8;
   --  A Cryptol [8] in the C calling convention: uint8_t.

   function SBox (B : C_Byte) return C_Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_SBox",
     Post          => SBox'Result = Foundation_Spark.AES.Spec.SBox.SBox (B);
   --  SBox.cry's SBox @ b, as the spec states it.
   --  @param B The byte to substitute.
   --  @return The spec's SBox (B).

   function InvSBox (B : C_Byte) return C_Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_InvSBox",
     Post          =>
       InvSBox'Result = Foundation_Spark.AES.Spec.SBox.InvSBox (B);
   --  SBox.cry's InvSBox @ b, as the spec states it.
   --  @param B The byte to substitute.
   --  @return The spec's InvSBox (B).

end Foundation_Spark.FFI.AES_SBox;
