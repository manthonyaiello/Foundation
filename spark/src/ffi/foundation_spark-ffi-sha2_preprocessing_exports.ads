--  The exports Cryptol calls for algorithms/SHA2/Preprocessing.cry:
--  spark_<Name> for each ghost shim in SHA2_Preprocessing, the names that
--  spark/cryptol/SPARK/SHA2/Preprocessing.cry declares foreign.
--  Each calls its shim through an Import of the shim's link name,
--  Ghost_Link_Prefix & its External_Name (see Foundation_Spark.FFI and
--  AES_GF28_Exports). Each Ghost_<Name> Import has Global => null, which
--  is what the shim's own (proved) Global is: it reads no state; and
--  Always_Terminates, since the shim is one call of a spec function,
--  whose recursion gnatprove proves terminates (Subprogram_Variant), or a
--  loop over a bounded range.

with Foundation_Spark.FFI.SHA2_Types;
with Foundation_Spark.SHA2.SHA256;

package Foundation_Spark.FFI.SHA2_Preprocessing_Exports with
  SPARK_Mode
is

   use Foundation_Spark.FFI.SHA2_Types;

   procedure Ghost_H0_256 (Output : out SHA2.SHA256.Hash_Value)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_H0_256",
     Global        => null,
     Always_Terminates;
   --  The ghost shim SHA2_Preprocessing.H0_256, by its link name.
   --  @param Output The initial hash value, written through Cryptol's output
   --  pointer.

   procedure H0_256 (Output : out SHA2.SHA256.Hash_Value)
   with
     Export,
     Convention    => C,
     External_Name => "spark_H0_256";
   --  Cryptol's foreign spark_H0_256 :
   --  () -> [8][32].
   --  Calls Ghost_H0_256.
   --  @param Output The initial hash value, written through Cryptol's output
   --  pointer.

   procedure Ghost_Pad
     (L : C_Size;
      M : Byte_Buffer;
      Output : in out Byte_Buffer)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_pad",
     Global        => null,
     Always_Terminates;
   --  The ghost shim SHA2_Preprocessing.Pad, by its link name.
   --  @param L The message length in bits, Cryptol's {l}.
   --  @param M The message as bytes (the first L /^ 8).
   --  @param Output The padded message as bytes: the first 64 * N (L) are
   --  written.

   procedure Pad (L : C_Size; M : Byte_Buffer; Output : in out Byte_Buffer)
   with
     Export,
     Convention    => C,
     External_Name => "spark_pad";
   --  Cryptol's foreign spark_pad :
   --  {l} (fin l, 64 >= width l) =>
   --  [l /^ 8][8] -> [64 * ((65 + l) /^ 512)][8].
   --  Calls Ghost_Pad.
   --  @param L The message length in bits, Cryptol's {l}.
   --  @param M The message as bytes (the first L /^ 8).
   --  @param Output The padded message as bytes: the first 64 * N (L) are
   --  written.

   procedure Ghost_Parse
     (N : C_Size;
      P : Byte_Buffer;
      Output : in out Block_Buffer)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_parse",
     Global        => null,
     Always_Terminates;
   --  The ghost shim SHA2_Preprocessing.Parse, by its link name.
   --  @param N The number of blocks, Cryptol's {N}.
   --  @param P The padded message as bytes (the first 64 * N).
   --  @param Output The blocks: the first N are written.

   procedure Parse (N : C_Size; P : Byte_Buffer; Output : in out Block_Buffer)
   with
     Export,
     Convention    => C,
     External_Name => "spark_parse";
   --  Cryptol's foreign spark_parse :
   --  {N} (fin N) => [N * 64][8] -> [N][16][32].
   --  Calls Ghost_Parse.
   --  @param N The number of blocks, Cryptol's {N}.
   --  @param P The padded message as bytes (the first 64 * N).
   --  @param Output The blocks: the first N are written.

end Foundation_Spark.FFI.SHA2_Preprocessing_Exports;
