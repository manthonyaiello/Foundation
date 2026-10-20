pragma SPARK_Mode (On);

with Foundation_Spark.AES.Spec.AES_K;

package Foundation_Spark.AES.Spec.AES192 is new
  Foundation_Spark.AES.Spec.AES_K (K => 192);
--  The {k} functions at k = 192: KeyExpansion`{192} and Cipher`{192}, as
--  Main.cry's AES192 = AES`{192} applies them [FIPS-PUB-197 Section 5].
