--  Secure Hash Algorithm preprocessing [FIPS-PUB-180-4 Section 5],
--  mirroring algorithms/SHA2/Preprocessing.cry. For now only the SHA-256
--  initial hash value; pad and parse come with M2.2 (#15), and the other
--  initial hash values are not used by SHA-256.

package Foundation_Spark.SHA2.Preprocessing with
  SPARK_Mode,
  Pure
is

   H0_256 : constant Words_32 (0 .. 7) :=
     [16#6a09e667#,
      16#bb67ae85#,
      16#3c6ef372#,
      16#a54ff53a#,
      16#510e527f#,
      16#9b05688c#,
      16#1f83d9ab#,
      16#5be0cd19#];
   --  The SHA-256 initial hash value, Cryptol's `H0_256 : [8][32]`
   --  (Preprocessing.cry:81, [FIPS-PUB-180-4 Section 5.3.3]).

end Foundation_Spark.SHA2.Preprocessing;
