--  The ghost shims for algorithms/SHA2/Functions.cry, at SHA-256's word
--  size: the logical functions Ch and Maj at [32] (the spec's instance in
--  SHA2.SHA256, Logical), SIGMA_256_0/1, sigma_256_0/1 (Small_Sigma_256_0/1
--  here) and the constants K_256, exported with Cryptol's C calling
--  convention. They are checked by spark/cryptol/SPARK/SHA2/Functions.cry.
--
--  A [32] is a uint32_t; K_256's [64][32] is written through a pointer to
--  64 words.
--
--  Ghost, as the AES shims are, so that every SHA-2 shim reaches the spec
--  the same way; SHA2_Functions_Exports gives each the name Cryptol looks
--  up (see Foundation_Spark.FFI).

with Interfaces;
with Foundation_Spark.FFI.SHA2_Types;
with Foundation_Spark.SHA2.Functions;
with Foundation_Spark.SHA2.SHA256;

package Foundation_Spark.FFI.SHA2_Functions with
  SPARK_Mode,
  Ghost
is

   use type Interfaces.Unsigned_32;
   use type SHA2.Words_32;
   use Foundation_Spark.FFI.SHA2_Types;

   subtype C_Word is Interfaces.Unsigned_32;
   --  A Cryptol [32] in the C calling convention: uint32_t.

   function Ch (X, Y, Z : C_Word) return C_Word
   with
     Export,
     Convention    => C,
     External_Name => "spark_Ch",
     Post          => Ch'Result = SHA2.SHA256.Ch (X, Y, Z);
   --  Functions.cry's Ch at [32], as the spec's SHA256 instance states it.
   --  @param X The chooser.
   --  @param Y The bits chosen where X is 1.
   --  @param Z The bits chosen where X is 0.
   --  @return The spec's Ch (X, Y, Z).

   function Maj (X, Y, Z : C_Word) return C_Word
   with
     Export,
     Convention    => C,
     External_Name => "spark_Maj",
     Post          => Maj'Result = SHA2.SHA256.Maj (X, Y, Z);
   --  Functions.cry's Maj at [32], as the spec's SHA256 instance states it.
   --  @param X The first voter.
   --  @param Y The second voter.
   --  @param Z The third voter.
   --  @return The spec's Maj (X, Y, Z).

   function SIGMA_256_0 (X : C_Word) return C_Word
   with
     Export,
     Convention    => C,
     External_Name => "spark_SIGMA_256_0",
     Post          => SIGMA_256_0'Result = SHA2.Functions.SIGMA_256_0 (X);
   --  Functions.cry's SIGMA_256_0, as the spec states it.
   --  @param X The word.
   --  @return The spec's SIGMA_256_0 (X).

   function SIGMA_256_1 (X : C_Word) return C_Word
   with
     Export,
     Convention    => C,
     External_Name => "spark_SIGMA_256_1",
     Post          => SIGMA_256_1'Result = SHA2.Functions.SIGMA_256_1 (X);
   --  Functions.cry's SIGMA_256_1, as the spec states it.
   --  @param X The word.
   --  @return The spec's SIGMA_256_1 (X).

   function Small_Sigma_256_0 (X : C_Word) return C_Word
   with
     Export,
     Convention    => C,
     External_Name => "spark_sigma_256_0",
     Post          =>
       Small_Sigma_256_0'Result = SHA2.Functions.Small_Sigma_256_0 (X);
   --  Functions.cry's sigma_256_0, the spec's Small_Sigma_256_0.
   --  @param X The word.
   --  @return The spec's Small_Sigma_256_0 (X).

   function Small_Sigma_256_1 (X : C_Word) return C_Word
   with
     Export,
     Convention    => C,
     External_Name => "spark_sigma_256_1",
     Post          =>
       Small_Sigma_256_1'Result = SHA2.Functions.Small_Sigma_256_1 (X);
   --  Functions.cry's sigma_256_1, the spec's Small_Sigma_256_1.
   --  @param X The word.
   --  @return The spec's Small_Sigma_256_1 (X).

   procedure K_256 (Output : out K_Table)
   with
     Export,
     Convention    => C,
     External_Name => "spark_K_256",
     Post          => Output = SHA2.Functions.K_256;
   --  Functions.cry's K_256 : [64][32], as the spec states it. Cryptol
   --  declares it as a function of () so that it can be foreign.
   --  @param Output The 64 constants, written through Cryptol's output
   --  pointer.

end Foundation_Spark.FFI.SHA2_Functions;
