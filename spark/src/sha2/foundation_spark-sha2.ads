--  The Secure Hash Algorithm 2 (SHA-2) family [FIPS-PUB-180-4], mirroring
--  algorithms/SHA2/. The spec layer is one child per Cryptol module:
--  Notation (Notation.cry), Functions (Functions.cry), Preprocessing
--  (Preprocessing.cry) and the generic Main (Main.cry), instantiated for
--  SHA-256 as SHA256 (SHA256.cry).

with Interfaces;

package Foundation_Spark.SHA2 with
  SPARK_Mode,
  Pure
is

   type Words_32 is array (Natural range <>) of Interfaces.Unsigned_32;
   --  A sequence of 32-bit words, Cryptol's `[n][32]`, indexed from 0 as
   --  Cryptol's `@` is. The actual for Main's Word_Vector in the SHA-256
   --  instance, and the type of K_256 and H0_256.

end Foundation_Spark.SHA2;
