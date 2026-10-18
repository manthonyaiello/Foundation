--  The exports Cryptol calls for algorithms/SHA2/Functions.cry: spark_<Name>
--  for each ghost shim in SHA2_Functions, the names that
--  spark/cryptol/SPARK/SHA2/Functions.cry declares foreign.
--  Each calls its shim through an Import of the shim's link name,
--  Ghost_Link_Prefix & its External_Name (see Foundation_Spark.FFI and
--  AES_GF28_Exports). Each Ghost_<Name> Import has Global => null, which
--  is what the shim's own (proved) Global is: it reads no state; and
--  Always_Terminates, since the shim is one call of a spec function,
--  whose recursion gnatprove proves terminates (Subprogram_Variant), or a
--  loop over a bounded range.

with Interfaces;
with Foundation_Spark.FFI.SHA2_Types;

package Foundation_Spark.FFI.SHA2_Functions_Exports with
  SPARK_Mode
is

   use Foundation_Spark.FFI.SHA2_Types;

   subtype C_Word is Interfaces.Unsigned_32;
   --  A Cryptol [32] in the C calling convention: uint32_t.

   function Ghost_Ch (X : C_Word; Y : C_Word; Z : C_Word) return C_Word
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_Ch",
     Global        => null;
   --  The ghost shim SHA2_Functions.Ch, by its link name.
   --  @param X The chooser.
   --  @param Y The bits chosen where X is 1.
   --  @param Z The bits chosen where X is 0.
   --  @return The shim's result.

   function Ch (X : C_Word; Y : C_Word; Z : C_Word) return C_Word
   with
     Export,
     Convention    => C,
     External_Name => "spark_Ch";
   --  Cryptol's foreign spark_Ch :
   --  [32] -> [32] -> [32] -> [32].
   --  Calls Ghost_Ch.
   --  @param X The chooser.
   --  @param Y The bits chosen where X is 1.
   --  @param Z The bits chosen where X is 0.
   --  @return The shim's result.

   function Ghost_Maj (X : C_Word; Y : C_Word; Z : C_Word) return C_Word
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_Maj",
     Global        => null;
   --  The ghost shim SHA2_Functions.Maj, by its link name.
   --  @param X The first voter.
   --  @param Y The second voter.
   --  @param Z The third voter.
   --  @return The shim's result.

   function Maj (X : C_Word; Y : C_Word; Z : C_Word) return C_Word
   with
     Export,
     Convention    => C,
     External_Name => "spark_Maj";
   --  Cryptol's foreign spark_Maj :
   --  [32] -> [32] -> [32] -> [32].
   --  Calls Ghost_Maj.
   --  @param X The first voter.
   --  @param Y The second voter.
   --  @param Z The third voter.
   --  @return The shim's result.

   function Ghost_SIGMA_256_0 (X : C_Word) return C_Word
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_SIGMA_256_0",
     Global        => null;
   --  The ghost shim SHA2_Functions.SIGMA_256_0, by its link name.
   --  @param X The word.
   --  @return The shim's result.

   function SIGMA_256_0 (X : C_Word) return C_Word
   with
     Export,
     Convention    => C,
     External_Name => "spark_SIGMA_256_0";
   --  Cryptol's foreign spark_SIGMA_256_0 :
   --  [32] -> [32].
   --  Calls Ghost_SIGMA_256_0.
   --  @param X The word.
   --  @return The shim's result.

   function Ghost_SIGMA_256_1 (X : C_Word) return C_Word
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_SIGMA_256_1",
     Global        => null;
   --  The ghost shim SHA2_Functions.SIGMA_256_1, by its link name.
   --  @param X The word.
   --  @return The shim's result.

   function SIGMA_256_1 (X : C_Word) return C_Word
   with
     Export,
     Convention    => C,
     External_Name => "spark_SIGMA_256_1";
   --  Cryptol's foreign spark_SIGMA_256_1 :
   --  [32] -> [32].
   --  Calls Ghost_SIGMA_256_1.
   --  @param X The word.
   --  @return The shim's result.

   function Ghost_Small_Sigma_256_0 (X : C_Word) return C_Word
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_sigma_256_0",
     Global        => null;
   --  The ghost shim SHA2_Functions.Small_Sigma_256_0, by its link name.
   --  @param X The word.
   --  @return The shim's result.

   function Small_Sigma_256_0 (X : C_Word) return C_Word
   with
     Export,
     Convention    => C,
     External_Name => "spark_sigma_256_0";
   --  Cryptol's foreign spark_sigma_256_0 :
   --  [32] -> [32].
   --  Calls Ghost_Small_Sigma_256_0.
   --  @param X The word.
   --  @return The shim's result.

   function Ghost_Small_Sigma_256_1 (X : C_Word) return C_Word
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_sigma_256_1",
     Global        => null;
   --  The ghost shim SHA2_Functions.Small_Sigma_256_1, by its link name.
   --  @param X The word.
   --  @return The shim's result.

   function Small_Sigma_256_1 (X : C_Word) return C_Word
   with
     Export,
     Convention    => C,
     External_Name => "spark_sigma_256_1";
   --  Cryptol's foreign spark_sigma_256_1 :
   --  [32] -> [32].
   --  Calls Ghost_Small_Sigma_256_1.
   --  @param X The word.
   --  @return The shim's result.

   procedure Ghost_K_256 (Output : out K_Table)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_K_256",
     Global        => null,
     Always_Terminates;
   --  The ghost shim SHA2_Functions.K_256, by its link name.
   --  @param Output The 64 constants, written through Cryptol's output
   --  pointer.

   procedure K_256 (Output : out K_Table)
   with
     Export,
     Convention    => C,
     External_Name => "spark_K_256";
   --  Cryptol's foreign spark_K_256 :
   --  () -> [64][32].
   --  Calls Ghost_K_256.
   --  @param Output The 64 constants, written through Cryptol's output
   --  pointer.

end Foundation_Spark.FFI.SHA2_Functions_Exports;
