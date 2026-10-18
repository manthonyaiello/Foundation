--  The Secure Hash Algorithm functions and constants [FIPS-PUB-180-4
--  Section 4], mirroring algorithms/SHA2/Functions.cry for SHA-256: the
--  logical functions Ch and Maj, the SHA-224/256 functions SIGMA_256_0/1
--  and sigma_256_0/1 [FIPS-PUB-180-4 Section 4.1.2], and the constants
--  K_256 [FIPS-PUB-180-4 Section 4.2.2].
--
--  Ch and Maj are polymorphic in the Cryptol, so they are generic over the
--  word type here. Ada identifiers are not case-sensitive, so Cryptol's
--  lower-case sigma_256_0/1 (FIPS's small sigma) are Small_Sigma_256_0/1
--  here, and the upper-case SIGMA_256_0/1 keep their Cryptol names.
--
--  Not mirrored, because SHA-256 does not use them: Parity, the SHA-1
--  sequences f and K_SHA1, and the SHA-384/512 functions and K_512.

with Interfaces; use Interfaces;
with Foundation_Spark.SHA2.Notation;

package Foundation_Spark.SHA2.Functions with
  SPARK_Mode,
  Pure
is

   --  Functions.cry's logical functions Ch and Maj, which are polymorphic
   --  in the Cryptol, at one word type. Main instantiates it at its `[w]`.
   --  @formal Word The word type, `[w]` at the use in Main.cry.
   generic
      type Word is mod <>;
   package Logical is

      function Ch (X, Y, Z : Word) return Word is
        ((X and Y) xor ((not X) and Z));
      --  The choose function, Cryptol's
      --  `Ch (x, y, z) = (x && y) ^ (~x && z)` (Functions.cry:13,
      --  [FIPS-PUB-180-4 Section 4.1]).
      --  @param X Chooses, bit by bit, between Y (where X is 1) and Z.
      --  @param Y The bits chosen where X is 1.
      --  @param Z The bits chosen where X is 0.
      --  @return The bitwise choice of Y and Z by X.

      function Maj (X, Y, Z : Word) return Word is
        ((X and Y) xor (X and Z) xor (Y and Z));
      --  The majority vote function, Cryptol's
      --  `Maj (x, y, z) = (x && y) ^ (x && z) ^ (y && z)`
      --  (Functions.cry:23, [FIPS-PUB-180-4 Section 4.1]).
      --  @param X The first voter.
      --  @param Y The second voter.
      --  @param Z The third voter.
      --  @return The bitwise majority of X, Y and Z.

   end Logical;

   package By_2 is new Notation (2, 32, Unsigned_32);
   --  Notation.cry at `{n, w} = {2, 32}`: Cryptol's `ROTR`{2}` on `[32]`
   --  is By_2.ROTR, used by SIGMA_256_0.

   package By_13 is new Notation (13, 32, Unsigned_32);
   --  Notation.cry at `{n, w} = {13, 32}`: Cryptol's `ROTR`{13}` on `[32]`
   --  is By_13.ROTR, used by SIGMA_256_0.

   package By_22 is new Notation (22, 32, Unsigned_32);
   --  Notation.cry at `{n, w} = {22, 32}`: Cryptol's `ROTR`{22}` on `[32]`
   --  is By_22.ROTR, used by SIGMA_256_0.

   package By_6 is new Notation (6, 32, Unsigned_32);
   --  Notation.cry at `{n, w} = {6, 32}`: Cryptol's `ROTR`{6}` on `[32]`
   --  is By_6.ROTR, used by SIGMA_256_1.

   package By_11 is new Notation (11, 32, Unsigned_32);
   --  Notation.cry at `{n, w} = {11, 32}`: Cryptol's `ROTR`{11}` on `[32]`
   --  is By_11.ROTR, used by SIGMA_256_1.

   package By_25 is new Notation (25, 32, Unsigned_32);
   --  Notation.cry at `{n, w} = {25, 32}`: Cryptol's `ROTR`{25}` on `[32]`
   --  is By_25.ROTR, used by SIGMA_256_1.

   package By_7 is new Notation (7, 32, Unsigned_32);
   --  Notation.cry at `{n, w} = {7, 32}`: Cryptol's `ROTR`{7}` on `[32]`
   --  is By_7.ROTR, used by Small_Sigma_256_0.

   package By_18 is new Notation (18, 32, Unsigned_32);
   --  Notation.cry at `{n, w} = {18, 32}`: Cryptol's `ROTR`{18}` on `[32]`
   --  is By_18.ROTR, used by Small_Sigma_256_0.

   package By_3 is new Notation (3, 32, Unsigned_32);
   --  Notation.cry at `{n, w} = {3, 32}`: Cryptol's `SHR`{3}` on `[32]`
   --  is By_3.SHR, used by Small_Sigma_256_0.

   package By_17 is new Notation (17, 32, Unsigned_32);
   --  Notation.cry at `{n, w} = {17, 32}`: Cryptol's `ROTR`{17}` on `[32]`
   --  is By_17.ROTR, used by Small_Sigma_256_1.

   package By_19 is new Notation (19, 32, Unsigned_32);
   --  Notation.cry at `{n, w} = {19, 32}`: Cryptol's `ROTR`{19}` on `[32]`
   --  is By_19.ROTR, used by Small_Sigma_256_1.

   package By_10 is new Notation (10, 32, Unsigned_32);
   --  Notation.cry at `{n, w} = {10, 32}`: Cryptol's `SHR`{10}` on `[32]`
   --  is By_10.SHR, used by Small_Sigma_256_1.

   function SIGMA_256_0 (X : Unsigned_32) return Unsigned_32 is
     (By_2.ROTR (X) xor By_13.ROTR (X) xor By_22.ROTR (X));
   --  Cryptol's `SIGMA_256_0 x = ROTR`{ 2} x ^ ROTR`{13} x ^ ROTR`{22} x`
   --  (Functions.cry:26, [FIPS-PUB-180-4 Section 4.1.2], capital sigma
   --  0).
   --  @param X The word.
   --  @return SIGMA_256_0 of X.

   function SIGMA_256_1 (X : Unsigned_32) return Unsigned_32 is
     (By_6.ROTR (X) xor By_11.ROTR (X) xor By_25.ROTR (X));
   --  Cryptol's `SIGMA_256_1 x = ROTR`{ 6} x ^ ROTR`{11} x ^ ROTR`{25} x`
   --  (Functions.cry:27, [FIPS-PUB-180-4 Section 4.1.2], capital sigma
   --  1).
   --  @param X The word.
   --  @return SIGMA_256_1 of X.

   function Small_Sigma_256_0 (X : Unsigned_32) return Unsigned_32 is
     (By_7.ROTR (X) xor By_18.ROTR (X) xor By_3.SHR (X));
   --  Cryptol's `sigma_256_0 x = ROTR`{ 7} x ^ ROTR`{18} x ^ SHR`{ 3} x`
   --  (Functions.cry:28, [FIPS-PUB-180-4 Section 4.1.2], small sigma 0).
   --  @param X The word.
   --  @return sigma_256_0 of X.

   function Small_Sigma_256_1 (X : Unsigned_32) return Unsigned_32 is
     (By_17.ROTR (X) xor By_19.ROTR (X) xor By_10.SHR (X));
   --  Cryptol's `sigma_256_1 x = ROTR`{17} x ^ ROTR`{19} x ^ SHR`{10} x`
   --  (Functions.cry:29, [FIPS-PUB-180-4 Section 4.1.2], small sigma 1).
   --  @param X The word.
   --  @return sigma_256_1 of X.

   K_256 : constant Words_32 (0 .. 63) :=
     [16#428a2f98#, 16#71374491#, 16#b5c0fbcf#, 16#e9b5dba5#,
      16#3956c25b#, 16#59f111f1#, 16#923f82a4#, 16#ab1c5ed5#,
      16#d807aa98#, 16#12835b01#, 16#243185be#, 16#550c7dc3#,
      16#72be5d74#, 16#80deb1fe#, 16#9bdc06a7#, 16#c19bf174#,
      16#e49b69c1#, 16#efbe4786#, 16#0fc19dc6#, 16#240ca1cc#,
      16#2de92c6f#, 16#4a7484aa#, 16#5cb0a9dc#, 16#76f988da#,
      16#983e5152#, 16#a831c66d#, 16#b00327c8#, 16#bf597fc7#,
      16#c6e00bf3#, 16#d5a79147#, 16#06ca6351#, 16#14292967#,
      16#27b70a85#, 16#2e1b2138#, 16#4d2c6dfc#, 16#53380d13#,
      16#650a7354#, 16#766a0abb#, 16#81c2c92e#, 16#92722c85#,
      16#a2bfe8a1#, 16#a81a664b#, 16#c24b8b70#, 16#c76c51a3#,
      16#d192e819#, 16#d6990624#, 16#f40e3585#, 16#106aa070#,
      16#19a4c116#, 16#1e376c08#, 16#2748774c#, 16#34b0bcb5#,
      16#391c0cb3#, 16#4ed8aa4a#, 16#5b9cca4f#, 16#682e6ff3#,
      16#748f82ee#, 16#78a5636f#, 16#84c87814#, 16#8cc70208#,
      16#90befffa#, 16#a4506ceb#, 16#bef9a3f7#, 16#c67178f2#];
   --  The SHA-224/256 constants, Cryptol's `K_256 : [64][32]`
   --  (Functions.cry:57, [FIPS-PUB-180-4 Section 4.2.2]): the first 32
   --  bits of the fractional parts of the cube roots of the first 64
   --  primes.

end Foundation_Spark.SHA2.Functions;
