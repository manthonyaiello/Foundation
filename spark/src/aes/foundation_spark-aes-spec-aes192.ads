pragma SPARK_Mode (On);

with Foundation_Spark.AES.Spec.AES_K;

package Foundation_Spark.AES.Spec.AES192 is new
  Foundation_Spark.AES.Spec.AES_K (K => 192) with Pure;
--  Main.cry: AES192 = AES`{192}, the AES-192 block cipher [FIPS-PUB-197
--  Section 5]: Encrypt and Decrypt at k = 192, with the {k} functions they
--  apply, KeyExpansion`{192}, Cipher`{192}, InvCipher`{192} and
--  InvCipher'`{192}.
