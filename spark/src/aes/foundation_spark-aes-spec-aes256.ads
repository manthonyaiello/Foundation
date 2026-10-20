pragma SPARK_Mode (On);

with Foundation_Spark.AES.Spec.AES_K;

package Foundation_Spark.AES.Spec.AES256 is new
  Foundation_Spark.AES.Spec.AES_K (K => 256);
--  The {k} functions at k = 256: KeyExpansion`{256} and Cipher`{256}, as
--  Main.cry's AES256 = AES`{256} applies them [FIPS-PUB-197 Section 5].
