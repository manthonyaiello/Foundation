pragma SPARK_Mode (On);

with Foundation_Spark.AES.Spec.AES_K;

package Foundation_Spark.AES.Spec.AES256 is new
  Foundation_Spark.AES.Spec.AES_K (K => 256);
--  Main.cry: AES256 = AES`{256}, the AES-256 block cipher [FIPS-PUB-197
--  Section 5]: Encrypt and Decrypt at k = 256, with the {k} functions they
--  apply, KeyExpansion`{256}, Cipher`{256}, InvCipher`{256} and
--  InvCipher'`{256}.
