--  A Cryptol prelude in SPARK: the Cryptol built-ins that the spec
--  layers use, each stated once, under its Cryptol name, as a ghost
--  generic. A spec unit instantiates a child at its own types and calls the
--  instance where the Cryptol calls the built-in, so the translation from
--  Cryptol's built-in to SPARK is reviewed here, once, and not at each use.
--
--  The source of each statement. Cryptol 3.6.0's prelude (lib/Cryptol.cry)
--  declares most of these as `primitive`, with a type and a one-line
--  comment but no Cryptol body: foldl (Cryptol.cry:1146), join (:815),
--  split (:822), reverse (:828), @ (:900), zero (:304), pmult (:1005),
--  pdiv (:1010), pmod (:1015), and the type operators /^ (:135) and %^
--  (:141). Those are stated from their documented meaning, which each
--  child cites: the prelude's comment and example, Cryptol's reference
--  manual (docs/RefMan) and docs/CryptolPrims.md. Two have Cryptol bodies,
--  @@ (Cryptol.cry:906) and repeat (:1215), and are stated by them.
--
--  Bit order. Cryptol's sequences are indexed from 0, and a word [w] is a
--  sequence of bits whose element 0 is the most significant: `#` puts "the
--  most-significant bits in the left argument" (Cryptol.cry:796), and a
--  polynomial literal <| ... |> is the word whose bit of weight 2 ^^ i is
--  the coefficient of x ^^ i (RefMan BasicSyntax.rst:352). Words and
--  Join_Split hold that convention for words held in modular types.
--
--  What is not imposed. The spec layers keep their own types: each child
--  is generic over the index, element and array types it works on, so AES's
--  narrow bit index and SHA-2's 128-bit one both instantiate it, and
--  AES's bytes stay Unsigned_8 with a Cryptol-order bit accessor.
--
--  Each child's functions are expression functions, so a caller's proof
--  sees through an instance to its definition as it saw through the inline
--  definition the instance replaced. Each is checked against Cryptol's
--  built-in through the FFI (spark/cryptol/SPARK/Prelude.cry).

package Foundation_Spark.Cryptol with
  SPARK_Mode,
  Pure,
  Ghost
is
end Foundation_Spark.Cryptol;
