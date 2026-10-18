pragma SPARK_Mode (On);

with Interfaces;
with Foundation_Spark.SHA2.Functions;
with Foundation_Spark.SHA2.Main;
with Foundation_Spark.SHA2.Preprocessing;

package Foundation_Spark.SHA2.SHA256 is new Foundation_Spark.SHA2.Main
  (Digest_Size   => 256,
   Word_Size     => 32,
   Word          => Interfaces.Unsigned_32,
   Word_Vector   => Words_32,
   Klen          => 64,
   K             => Functions.K_256,
   H0            => Preprocessing.H0_256,
   SIGMA_0       => Functions.SIGMA_256_0,
   SIGMA_1       => Functions.SIGMA_256_1,
   Small_Sigma_0 => Functions.Small_Sigma_256_0,
   Small_Sigma_1 => Functions.Small_Sigma_256_1);
--  The Secure Hash Algorithm with a digest size of 256 bits (SHA-256)
--  [FIPS-PUB-180-4 Section 6.2]: Main instantiated as
--  algorithms/SHA2/SHA256.cry instantiates SHA2::Main (SHA256.cry:19),
--  with d = 256, w = 32, Klen = 64, H0 = H0_256, K = K_256, and the
--  SHA-224/256 SIGMA and sigma functions.
