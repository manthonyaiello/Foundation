pragma SPARK_Mode (On);

with Foundation_Spark.AES.Spec.AES_K;

package Foundation_Spark.AES.Spec.AES128 is new
  Foundation_Spark.AES.Spec.AES_K (K => 128);
--  The {k} functions at k = 128: KeyExpansion`{128} and Cipher`{128}, as
--  Main.cry's AES128 = AES`{128} applies them [FIPS-PUB-197 Section 5].
