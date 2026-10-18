pragma SPARK_Mode (On);

with Foundation_Spark.HMAC.Main;
with Foundation_Spark.SHA2.SHA256;

package Foundation_Spark.HMAC.SHA256 is new Foundation_Spark.HMAC.Main
  (B          => 64,
   L          => 32,
   Max_Length => Foundation_Spark.SHA2.SHA256.Max_Length,
   Hk         => Foundation_Spark.SHA2.SHA256.Hash,
   Hn         => Foundation_Spark.SHA2.SHA256.Hash,
   HL         => Foundation_Spark.SHA2.SHA256.Hash);
--  HMAC-SHA-256 [FIPS-PUB-198-1, FIPS-PUB-180-4 Section 6.2]: Main
--  instantiated as packaging/Hash.cry's `HMAC` (Hash.cry:71) instantiates
--  algorithms/HMAC/Main.cry's for algorithms/SHA2/SHA256.cry: B =
--  BlockSize / 8 = 64, L = DigestSize / 8 = 32, and Hk, Hn and HL all the
--  SHA-256 `hash` (Main.cry:55 of algorithms/SHA2), whose message bound
--  2 ** 64 is Hash.cry's 2 ^^ UpperLimit at SHA256.cry's UpperLimit = 64.
