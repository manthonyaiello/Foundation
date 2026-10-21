pragma SPARK_Mode (On);

with Foundation_Spark.AES.Spec.AES_K;

package Foundation_Spark.AES.Spec.AES128 is new
  Foundation_Spark.AES.Spec.AES_K (K => 128) with Pure;
--  Main.cry: AES128 = AES`{128}, the AES-128 block cipher [FIPS-PUB-197
--  Section 5]: Encrypt and Decrypt at k = 128, with the {k} functions they
--  apply, KeyExpansion`{128}, Cipher`{128}, InvCipher`{128} and
--  InvCipher'`{128}.
