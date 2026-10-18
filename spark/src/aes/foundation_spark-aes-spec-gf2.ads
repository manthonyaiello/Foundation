--  The polynomial arithmetic over GF(2) that algorithms/AES/SBox.cry
--  imports from shared/algebra/Polynomial/GF2.cry (inverse, through pgcd),
--  stated at the types SBox.cry uses it at: inverse a p with a : [8] and
--  p : [9], so pgcd works on polynomials of type [9] [FIPS-PUB-197 Section
--  4.4].
--
--  As in GF28, a polynomial is held as its coefficient bits in an
--  unsigned integer: bit I (from the least significant) is the coefficient
--  of x^^I. Cryptol's primitives pmult and pdiv have no Cryptol body. Pmult
--  states pmult at [9] -> [9] -> [17] as the sum of the shifted copies of
--  its second factor, and Pdiv states pdiv at [9] -> [9] -> [9] as long
--  division, a recursive fold over the bits of the dividend, most
--  significant first, as GF28's Pmod_Fold is for pmod.

with Interfaces;

package Foundation_Spark.AES.Spec.GF2 with
  SPARK_Mode,
  Pure,
  Ghost
is

   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Byte is Interfaces.Unsigned_8;
   --  A byte, the Cryptol [8].

   subtype Poly is Interfaces.Unsigned_16;
   --  A polynomial over GF(2), as its coefficient bits. GF2.cry's pgcd
   --  works at type [9] here, held in the low nine bits.

   subtype Product is Interfaces.Unsigned_32;
   --  A product of two [9]: pmult's [17], held in the low 17 bits.

   function Is_Poly9 (X : Poly) return Boolean
   is (X < 2 ** 9);
   --  Whether X is a [9].
   --  @param X The polynomial.
   --  @return Whether its degree is below 9.

   function Term (X : Poly; I : Natural; Y : Poly) return Product
   is (if (Interfaces.Shift_Right (X, I) and 1) = 1
       then Interfaces.Shift_Left (Product (Y), I)
       else 0)
   with Pre => I <= 8;
   --  One term of pmult x y: Y * x^^I when the coefficient of x^^I in X is
   --  set.
   --  @param X The first factor.
   --  @param I The degree of the term of X.
   --  @param Y The second factor.
   --  @return Y * x^^I if that coefficient of X is 1, and 0 otherwise.

   function Pmult (X, Y : Poly) return Product
   is (Term (X, 0, Y) xor Term (X, 1, Y) xor Term (X, 2, Y)
       xor Term (X, 3, Y) xor Term (X, 4, Y) xor Term (X, 5, Y)
       xor Term (X, 6, Y) xor Term (X, 7, Y) xor Term (X, 8, Y))
   with
     Pre  => Is_Poly9 (X) and then Is_Poly9 (Y),
     Post => Pmult'Result < 2 ** 17;
   --  Cryptol's pmult at type [9] -> [9] -> [17], GF2.cry's (^*): the
   --  product of X and Y as polynomials over GF(2).
   --  @param X The first factor.
   --  @param Y The second factor.
   --  @return Their product, of degree at most 16.

   function Pdeg (P : Poly) return Integer
   is (if P >= 2 ** 8 then 8
       elsif P >= 2 ** 7 then 7
       elsif P >= 2 ** 6 then 6
       elsif P >= 2 ** 5 then 5
       elsif P >= 2 ** 4 then 4
       elsif P >= 2 ** 3 then 3
       elsif P >= 2 ** 2 then 2
       elsif P >= 2 ** 1 then 1
       elsif P >= 2 ** 0 then 0
       else -1)
   with Pre => Is_Poly9 (P);
   --  GF2.cry: pdeg p = toInteger (lg2 ((0b0 # p) + 1)) - 1, the degree of
   --  P, at type [9]: the position of its highest set bit, and -1 for 0.
   --  @param P The polynomial.
   --  @return Its degree.

   function Lead (Y : Poly) return Poly
   is (Interfaces.Shift_Left (1, Pdeg (Y)))
   with
     Pre  => Is_Poly9 (Y) and then Y /= 0,
     Post => Lead'Result <= Y and then Y < 2 * Lead'Result;
   --  The leading term x^^(pdeg y) of a nonzero Y.
   --  @param Y The polynomial.
   --  @return x^^(pdeg y).

   function Bit (X : Poly; I : Natural) return Poly
   is (Interfaces.Shift_Right (X, 8 - I) and 1)
   with Pre => I <= 8;
   --  Cryptol's x @ i on a [9], as 0 or 1. Cryptol is big-endian, so bit
   --  0 is the coefficient of x^^8.
   --  @param X The polynomial.
   --  @param I The Cryptol index of the bit.
   --  @return That coefficient.

   function Reduce (T, Y : Poly) return Poly
   is (if T >= Lead (Y) then T xor Y else T)
   with
     Pre  => Is_Poly9 (Y) and then Y /= 0 and then T < 2 * Lead (Y),
     Post => Reduce'Result < Lead (Y);
   --  One step of long division: T has degree at most pdeg y, so
   --  subtracting Y when the coefficient of x^^(pdeg y) in T is set leaves
   --  a remainder of degree below pdeg y.
   --  @param T The partial remainder.
   --  @param Y The divisor.
   --  @return T mod Y.

   function Pmod_Fold (X, Y : Poly; N : Natural) return Poly
   is (if N = 0 then 0
       else Reduce
              (Interfaces.Shift_Left (Pmod_Fold (X, Y, N - 1), 1)
               or Bit (X, N - 1),
               Y))
   with
     Pre                => N <= 9 and then Is_Poly9 (X)
                           and then Is_Poly9 (Y) and then Y /= 0,
     Post               => Pmod_Fold'Result < Lead (Y),
     Subprogram_Variant => (Decreases => N);
   --  The remainder modulo Y of the leading N bits of the [9] X, by long
   --  division, most significant bit first: the remainder that goes with
   --  Pdiv_Fold's quotient.
   --  @param X The dividend.
   --  @param Y The divisor.
   --  @param N How many bits of X, from the most significant, to use.
   --  @return The remainder of those bits modulo Y.

   function Pdiv_Fold (X, Y : Poly; N : Natural) return Poly
   is (if N = 0 then 0
       else Interfaces.Shift_Left (Pdiv_Fold (X, Y, N - 1), 1)
            or (if (Interfaces.Shift_Left (Pmod_Fold (X, Y, N - 1), 1)
                    or Bit (X, N - 1)) >= Lead (Y)
                then 1 else 0))
   with
     Pre                => N <= 9 and then Is_Poly9 (X)
                           and then Is_Poly9 (Y) and then Y /= 0,
     Post               =>
       Pdiv_Fold'Result < 2 ** N
       and then (Pmult (Pdiv_Fold'Result, Y)
                 xor Product (Pmod_Fold (X, Y, N)))
                = Product (Interfaces.Shift_Right (X, 9 - N)),
     Subprogram_Variant => (Decreases => N);
   --  The quotient by Y of the leading N bits of the [9] X, by long
   --  division, most significant bit first: one quotient bit per step,
   --  set when the step subtracts Y.
   --  @param X The dividend.
   --  @param Y The divisor.
   --  @param N How many bits of X, from the most significant, to use.
   --  @return The quotient of those bits by Y.

   function Pdiv (X, Y : Poly) return Poly
   is (Pdiv_Fold (X, Y, 9))
   with Pre => Is_Poly9 (X) and then Is_Poly9 (Y) and then Y /= 0;
   --  Cryptol's pdiv at type [9] -> [9] -> [9], GF2.cry's (^/): the
   --  quotient of X by Y as polynomials over GF(2). Cryptol's pdiv by 0 is
   --  an error, so Y /= 0 is a precondition.
   --  @param X The dividend.
   --  @param Y The divisor.
   --  @return The quotient.

   function Sub_Mult (X, X1, Q : Poly) return Poly
   is (Poly ((Product (X) xor Pmult (Q, X1)) and (2 ** 9 - 1)))
   with
     Pre  => Is_Poly9 (X) and then Is_Poly9 (X1) and then Is_Poly9 (Q),
     Post => Is_Poly9 (Sub_Mult'Result);
   --  GF2.cry, in pgcd's inner: x ^. x' = drop (zext x ^ q ^* x'), at
   --  type [9]: X - Q * X1, truncated to its low nine coefficients.
   --  @param X The Cryptol's x.
   --  @param X1 The Cryptol's x'.
   --  @param Q The quotient q of the step.
   --  @return The low nine coefficients of X - Q * X1.

   type Poly_State is array (0 .. 5) of Poly;
   --  GF2.cry, in pgcd: type State = [6]Poly, the state
   --  [r, s, t, r', s', t'] of the extended Euclidean algorithm.

   function Is_State (S : Poly_State) return Boolean
   is (for all I in Poly_State'Range => Is_Poly9 (S (I)));
   --  Whether every polynomial of S is a [9].
   --  @param S The state.
   --  @return Whether S is a [6][9].

   function Inner_Next (S : Poly_State; Q : Poly) return Poly_State
   is [S (3), S (4), S (5),
       Sub_Mult (S (0), S (3), Q), Sub_Mult (S (1), S (4), Q),
       Sub_Mult (S (2), S (5), Q)]
   with
     Pre  => Is_State (S) and then Is_Poly9 (Q),
     Post => Is_State (Inner_Next'Result);
   --  GF2.cry, in pgcd's inner: [r', s', t', r'', s'', t''], where
   --  [r'', s'', t''] = zipWith (^.) [r, s, t] [r', s', t'] for the
   --  quotient q.
   --  @param S The state [r, s, t, r', s', t'].
   --  @param Q The quotient q = r ^/ r'.
   --  @return The next state.

   function Inner_Step (S : Poly_State) return Poly_State
   is (Inner_Next (S, Pdiv (S (0), S (3))))
   with
     Pre  => Is_State (S) and then S (3) /= 0,
     Post => Is_State (Inner_Step'Result)
             and then Inner_Step'Result (3) < Lead (S (3));
   --  GF2.cry, in pgcd's inner: the recursive step, with q = r ^/ r'. The
   --  new r' is the remainder of r by r', of degree below r''s.
   --  @param S The state [r, s, t, r', s', t'], with r' nonzero.
   --  @return The next state.

   function Inner (S : Poly_State) return Poly_State
   is (if S (3) = 0 then S else Inner (Inner_Step (S)))
   with
     Pre                => Is_State (S),
     Post               => Is_State (Inner'Result),
     Subprogram_Variant => (Decreases => S (3));
   --  GF2.cry, in pgcd: inner [r, s, t, r', s', t'] = if r' == <| 0 |>
   --  then [r, s, t, r', s', t'] else inner [r', s', t', r'', s'', t''].
   --  @param S The state.
   --  @return The final state, whose r is the GCD.

   type Pgcd_Result is array (0 .. 4) of Poly;
   --  GF2.cry: the [5][1 + max wa wb] that pgcd returns,
   --  [g, u, v, a', b'].

   function Pgcd (A : Byte; B : Poly) return Pgcd_Result
   is [Inner ([Poly (A), 1, 0, B, 0, 1]) (0),
       Inner ([Poly (A), 1, 0, B, 0, 1]) (1),
       Inner ([Poly (A), 1, 0, B, 0, 1]) (2),
       Inner ([Poly (A), 1, 0, B, 0, 1]) (5),
       Inner ([Poly (A), 1, 0, B, 0, 1]) (4)]
   with Pre => Is_Poly9 (B);
   --  GF2.cry: pgcd a b = [g, u, v, a', b'], where [g, u, v, _, b', a'] =
   --  inner [zext a, <| 1 |>, <| 0 |>, zext b, <| 0 |>, <| 1 |>], at
   --  wa = 7 and wb = 8 (a : [8], b : [9]), so Poly = [9].
   --  @param A The first polynomial, a [8].
   --  @param B The second polynomial, a [9].
   --  @return [g, u, v, a', b'].

   function Inverse (A : Byte; P : Poly) return Byte
   is (Byte (Pgcd (A, P) (1) and (2 ** 8 - 1)))
   with Pre => Is_Poly9 (P);
   --  GF2.cry: inverse a p = tail (pgcd`{wb=v} a p @ 1), at u = 7 and
   --  v = 8 (a : [8], p : [9], result [8]): the multiplicative inverse of
   --  A modulo P, by the extended Euclidean algorithm. tail of the [9] u
   --  drops its leading coefficient, that of x^^8.
   --  @param A The polynomial to invert, a [8].
   --  @param P The modulus, a [9].
   --  @return The low eight coefficients of the Bezout coefficient u.

end Foundation_Spark.AES.Spec.GF2;
