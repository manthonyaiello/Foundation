--  The ghost shims for the Cryptol prelude in SPARK (Foundation_Spark.Cryptol,
--  #75): instances of its generics, exported with Cryptol's C calling
--  convention and checked against Cryptol's built-ins by
--  spark/cryptol/SPARK/Prelude.cry.
--
--  Where a spec layer instantiates a generic, the shim calls that instance:
--  SHA2.Sequences_Of_Bits and SHA2.Lengths, the SHA-256 instance's
--  Word_Sequences, and HMAC's Byte_Words and Byte_Sequences. The rest are
--  instantiated here at the types AES uses the built-in at: foldl over
--  bytes, @@ on a block and on a byte table, pmult at [8] x [8] and
--  [9] x [9], pmod at [15] mod [9], pdiv at [8] / [8] and [9] / [9].
--
--  A fold takes a function, which C cannot pass, so the folds here fold
--  fixed ones, Step and Step_E, which Prelude.cry states again in Cryptol.
--  A polynomial result is returned in the C word that holds the SPARK
--  word (uint16_t or uint32_t), whole, and the Cryptol side compares it
--  with the built-in's result zero-extended, so a SPARK result with a bit
--  above the built-in's width fails the check.
--
--  Ghost, because the prelude is; Prelude_Exports gives each the name
--  Cryptol looks up (see Foundation_Spark.FFI).

with Interfaces;
with Interfaces.C;
with Foundation_Spark.Cryptol.Bulk_Indexing;
with Foundation_Spark.Cryptol.Enumeration_Folds;
with Foundation_Spark.Cryptol.Folds;
with Foundation_Spark.Cryptol.Join_Split;
with Foundation_Spark.Cryptol.Polynomial_Products;
with Foundation_Spark.Cryptol.Polynomial_Quotients;
with Foundation_Spark.Cryptol.Polynomial_Remainders;
with Foundation_Spark.Cryptol.Words;
with Foundation_Spark.HMAC;
with Foundation_Spark.SHA2;
with Foundation_Spark.SHA2.SHA256;

package Foundation_Spark.FFI.Prelude with
  SPARK_Mode,
  Ghost
is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Interfaces.C.size_t;
   use type SHA2.Bit_Index;
   use type HMAC.Bytes;

   subtype C_Size is Interfaces.C.size_t;
   --  A Cryptol numeric type parameter in the C calling convention: size_t.

   subtype Byte is Interfaces.Unsigned_8;
   --  A Cryptol [8] (or a [k] with k <= 8, or a Bit) in C: uint8_t.

   subtype Word_16 is Interfaces.Unsigned_16;
   --  A Cryptol [k] with 8 < k <= 16 in C: uint16_t.

   subtype Word_32 is Interfaces.Unsigned_32;
   --  A Cryptol [k] with 16 < k <= 32 in C: uint32_t.

   subtype Word_64 is Interfaces.Unsigned_64;
   --  A Cryptol [k] with 32 < k <= 64 in C: uint64_t.

   type Byte_Array is array (Natural range <>) of Byte;
   --  A sequence of bytes, Cryptol's [n][8], for the fold over a sequence.

   subtype Fold_Buffer is Byte_Array (0 .. 15);
   --  The C buffer of the [n][8] folded, typed at 16 bytes. Only the first
   --  n are the caller's.

   function Step (Z, X : Byte) return Byte is (3 * Z + X);
   --  The function folded over a sequence, Prelude.cry's f z x = 3 * z +
   --  x, whose result depends on the order of the elements.
   --  @param Z The accumulator.
   --  @param X The element.
   --  @return 3 * Z + X, modulo 256.

   package Byte_Folds is new Cryptol.Folds
     (Acc => Byte, Index => Natural, Element => Byte, Seq => Byte_Array,
      F   => Step);
   --  The prelude's foldl over bytes, folding Step.

   subtype Byte_Value is Natural range 0 .. 255;
   --  The elements of the enumerations folded: Cryptol's [from ..< to] at
   --  type [8].

   function Step_E (E, Z : Byte; X : Byte_Value) return Byte is
     (3 * Z + E * Byte (X));
   --  The function folded over an enumeration, Prelude.cry's fe e z x =
   --  3 * z + e * x, closed over E.
   --  @param E The value the function closes over.
   --  @param Z The accumulator.
   --  @param X The element.
   --  @return 3 * Z + E * X, modulo 256.

   package Byte_Enumeration_Folds is new Cryptol.Enumeration_Folds
     (Env => Byte, Acc => Byte, Index => Byte_Value, F => Step_E);
   --  The prelude's foldl over an enumeration of bytes, folding Step_E.

   package Bits_15 is new Cryptol.Words
     (Word_16, 15, Interfaces.Shift_Right);
   --  The prelude's @ on a [15] held in a 16-bit word, as AES holds the
   --  product of pmult at [8] x [8].

   type Words_64 is array (Natural range <>) of Word_64;
   --  A sequence of [64] words, for the Join_Split instance at [64].

   package Words_64_Bits is new Cryptol.Join_Split
     (Word        => Word_64,
      Width       => 64,
      Shift_Right => Interfaces.Shift_Right,
      Word_Index  => Natural,
      Words       => Words_64,
      Bit_Index   => SHA2.Bit_Index,
      Bits        => SHA2.Bits);
   --  The prelude's @ and Value at [64]: the shims pass a [64] to and from
   --  bits with it.

   subtype Nibble is Byte range 0 .. 15;
   --  An index into a block, Cryptol's [4], held in a uint8_t.

   type Block is array (Nibble) of Byte;
   --  A [16][8], as AES's block is.

   type Nibbles is array (Nibble) of Nibble;
   --  A [16][4], the indices ShiftRows's @@ takes.

   type Table is array (Byte) of Byte;
   --  A [256][8] indexed by a byte, as AES's S-box is.

   package Block_Bulk_Indexing is new Cryptol.Bulk_Indexing
     (Index   => Nibble,
      Element => Byte,
      Seq     => Block,
      Out_Index => Nibble,
      Indices => Nibbles,
      Out_Seq => Block);
   --  The prelude's @@ on a block, at indices [16][4].

   package Table_Bulk_Indexing is new Cryptol.Bulk_Indexing
     (Index   => Byte,
      Element => Byte,
      Seq     => Table,
      Out_Index => Nibble,
      Indices => Block,
      Out_Seq => Block);
   --  The prelude's @@ on a table indexed by bytes, at indices [16][8].

   package Pmult_7_7 is new Cryptol.Polynomial_Products
     (Word_16, 7, 7, Interfaces.Shift_Right);
   --  The prelude's pmult at {u, v} = {7, 7}: [8] -> [8] -> [15].

   package Pmult_8_8 is new Cryptol.Polynomial_Products
     (Word_32, 8, 8, Interfaces.Shift_Right);
   --  The prelude's pmult at {u, v} = {8, 8}: [9] -> [9] -> [17].

   package Pmod_15_8 is new Cryptol.Polynomial_Remainders
     (Word_16, 15, 8, Interfaces.Shift_Right);
   --  The prelude's pmod at {u, v} = {15, 8}: [15] -> [9] -> [8].

   package Pdiv_8_8 is new Cryptol.Polynomial_Quotients
     (Word_16, 8, 8, Interfaces.Shift_Right);
   --  The prelude's pdiv at {u, v} = {8, 8}: [8] -> [8] -> [8].

   package Pdiv_9_9 is new Cryptol.Polynomial_Quotients
     (Word_16, 9, 9, Interfaces.Shift_Right);
   --  The prelude's pdiv at {u, v} = {9, 9}: [9] -> [9] -> [9].

   function Bit_Byte (B : Boolean) return Byte is (if B then 1 else 0);
   --  A Bit as Cryptol's C calling convention passes it: 1 or 0.
   --  @param B The bit.
   --  @return 1 for True, 0 for False.

   subtype Bit_Index_64 is SHA2.Bit_Index range 0 .. 63;
   --  The indices of the bits of a [64].

   function Bits_Of_64 (X : Word_64) return SHA2.Bits is
     ([for I in Bit_Index_64'Range =>
         Words_64_Bits.Word_Bits.Bit (X, Natural (I))])
   with
     Post =>
       Bits_Of_64'Result'First = 0 and then Bits_Of_64'Result'Length = 64;
   --  The bits of a [64], most significant first, by the prelude's @.
   --  @param X The word.
   --  @return Its 64 bits, indexed from 0.

   function Foldl (N : C_Size; Z : Byte; Xs : Fold_Buffer) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_foldl",
     Pre           => N <= 16,
     Post          =>
       Foldl'Result = Byte_Folds.Foldl (Z, Xs (0 .. Natural (N) - 1));
   --  Cryptol's foldl f z xs at [n][8], by the prelude's Folds.
   --  @param N The number of elements, Cryptol's {n}.
   --  @param Z The initial accumulator.
   --  @param Xs The elements: the first N are read.
   --  @return The fold.

   function Foldl_Enumeration (From, To : C_Size; E, Z : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_foldl_enumeration",
     Pre           => From <= To and then To <= 256,
     Post          =>
       Foldl_Enumeration'Result
       = Byte_Enumeration_Folds.Foldl (E, Z, Integer (From), Integer (To));
   --  Cryptol's foldl (fe e) z [from ..< to], by the prelude's
   --  Enumeration_Folds.
   --  @param From The enumeration's first element, Cryptol's {from}.
   --  @param To Its exclusive bound, Cryptol's {to}.
   --  @param E The value the function closes over.
   --  @param Z The initial accumulator.
   --  @return The fold.

   function Bit_8 (X, J : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_bit_8",
     Pre           => J < 8,
     Post          =>
       Bit_8'Result
       = Bit_Byte (HMAC.Byte_Words.Word_Bits.Bit (X, Natural (J)));
   --  Cryptol's x @ j at [8], by HMAC's instance of the prelude's Words.
   --  @param X The byte.
   --  @param J The bit's index, a [3].
   --  @return The bit, as 1 or 0.

   function Head_8 (X : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_head_8",
     Post          =>
       Head_8'Result = Bit_Byte (HMAC.Byte_Words.Word_Bits.Head (X));
   --  Cryptol's head x at [8], by HMAC's instance of the prelude's Words.
   --  @param X The byte.
   --  @return Its most significant bit, as 1 or 0.

   function Bit_32 (X : Word_32; J : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_bit_32",
     Pre           => J < 32,
     Post          =>
       Bit_32'Result
       = Bit_Byte
           (SHA2.SHA256.Word_Sequences.Word_Bits.Bit (X, Natural (J)));
   --  Cryptol's x @ j at [32], by the SHA-256 instance of the prelude's
   --  Words.
   --  @param X The word.
   --  @param J The bit's index, a [5].
   --  @return The bit, as 1 or 0.

   function Bit_15 (X : Word_16; J : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_bit_15",
     Pre           => J < 15,
     Post          => Bit_15'Result = Bit_Byte (Bits_15.Bit (X, Natural (J)));
   --  Cryptol's x @ j at a [15] held in a 16-bit word.
   --  @param X The word, below 2 ** 15.
   --  @param J The bit's index, a [4] below 15.
   --  @return The bit, as 1 or 0.

   subtype Four_Bytes is HMAC.Bytes (0 .. 3);
   --  The C buffer of a [4][8].

   function Join_Bytes (Xs : Four_Bytes) return Word_32
   with
     Export,
     Convention    => C,
     External_Name => "spark_join_bytes",
     Post          =>
       HMAC.Byte_Words.Join (Xs)'Length = 32
       and then Join_Bytes'Result
                = SHA2.SHA256.Word_Sequences.Value
                    (HMAC.Byte_Words.Join (Xs), 0, 32);
   --  Cryptol's join at [4][8] -> [32], by HMAC's instance of the prelude's
   --  Join_Split, read back as a [32] by the SHA-256 instance's Value.
   --  @param Xs The four bytes.
   --  @return Their 32 bits as a word.

   subtype Two_Words is SHA2.Words_32 (0 .. 1);
   --  The C buffer of a [2][32].

   procedure Split_Word (X : Word_64; Output : out Two_Words)
   with
     Export,
     Convention    => C,
     External_Name => "spark_split_word",
     Post          =>
       (for all K in 0 .. 1 =>
          Output (K)
          = SHA2.SHA256.Word_Sequences.Split_At
              (Bits_Of_64 (X), SHA2.Bit_Index (K)));
   --  Cryptol's split at [64] -> [2][32], by the SHA-256 instance of the
   --  prelude's Join_Split.
   --  @param X The word, whose bits are split.
   --  @param Output The two words, written through Cryptol's output
   --  pointer.

   subtype Eight_Bytes is HMAC.Bytes (0 .. 7);
   --  The C buffer of an [8][8].

   procedure Join_Words (Ws : Two_Words; Output : out Eight_Bytes)
   with
     Export,
     Convention    => C,
     External_Name => "spark_join_words",
     Post          =>
       SHA2.SHA256.Word_Sequences.Join (Ws)'Length = 64
       and then
         (for all K in HMAC.Byte_Index range 0 .. 7 =>
            Output (K)
            = HMAC.Byte_Words.Split_At
                (SHA2.SHA256.Word_Sequences.Join (Ws), SHA2.Bit_Index (K)));
   --  Cryptol's join at [2][32] -> [64], by the SHA-256 instance of the
   --  prelude's Join_Split, split back into bytes by HMAC's instance.
   --  @param Ws The two words.
   --  @param Output Their 64 bits as eight bytes, written through Cryptol's
   --  output pointer.

   function Zero_64 return Word_64
   with
     Export,
     Convention    => C,
     External_Name => "spark_zero_64",
     Post          =>
       Zero_64'Result
       = Words_64_Bits.Value (SHA2.Sequences_Of_Bits.Zero (64), 0, 64);
   --  Cryptol's zero at [64], by SHA-2's instance of the prelude's
   --  Bit_Sequences, read back as a [64].
   --  @return The 64 zero bits as a word.

   function Literal_64 (X : Word_64) return Word_64
   with
     Export,
     Convention    => C,
     External_Name => "spark_literal_64",
     Post          =>
       Literal_64'Result
       = Words_64_Bits.Value
           (SHA2.Sequences_Of_Bits.Literal (SHA2.Bit_Index (X), 64), 0, 64);
   --  Cryptol's literal `x : [64], by SHA-2's instance of the prelude's
   --  Bit_Sequences, read back as a [64].
   --  @param X The value.
   --  @return The literal's 64 bits as a word.

   procedure Repeat_4 (X : Byte; Output : out Four_Bytes)
   with
     Export,
     Convention    => C,
     External_Name => "spark_repeat_4",
     Post          => Output = HMAC.Byte_Sequences.Repeat (4, X);
   --  Cryptol's repeat`{4} x at [8], by HMAC's instance of the prelude's
   --  Sequences.
   --  @param X The byte.
   --  @param Output Four copies of X, written through Cryptol's output
   --  pointer.

   subtype Six_Bytes is HMAC.Bytes (0 .. 5);
   --  The C buffer of a [6][8].

   procedure Reverse_6 (Xs : Six_Bytes; Output : out Six_Bytes)
   with
     Export,
     Convention    => C,
     External_Name => "spark_reverse_6",
     Post          => Output = HMAC.Byte_Sequences.Reverse_Of (Xs);
   --  Cryptol's reverse at [6][8], by HMAC's instance of the prelude's
   --  Sequences.
   --  @param Xs The bytes.
   --  @param Output Xs in reverse order, written through Cryptol's output
   --  pointer.

   procedure Bulk_Index_Block (Xs : Block; Ixs : Nibbles; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_bulk_index_block",
     Post          => Output = Block_Bulk_Indexing.Bulk_Index (Xs, Ixs);
   --  Cryptol's xs @@ is at [16][8] and [16][4].
   --  @param Xs The block.
   --  @param Ixs The indices.
   --  @param Output The bytes of Xs at Ixs, written through Cryptol's
   --  output pointer.

   procedure Bulk_Index_Table (T : Table; Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_bulk_index_table",
     Post          => Output = Table_Bulk_Indexing.Bulk_Index (T, Bs);
   --  Cryptol's t @@ bs at [256][8] and [16][8].
   --  @param T The table.
   --  @param Bs The indices, bytes.
   --  @param Output The entries of T at Bs, written through Cryptol's
   --  output pointer.

   function Ceil_Div (M, N : C_Size) return Word_64
   with
     Export,
     Convention    => C,
     External_Name => "spark_ceil_div",
     Pre           => N >= 1 and then M < 2 ** 62 and then N < 2 ** 62,
     Post          =>
       SHA2.Lengths.Ceil_Div (SHA2.Bit_Index (M), SHA2.Bit_Index (N))
       < 2 ** 64
       and then Ceil_Div'Result
                = Word_64
                    (SHA2.Lengths.Ceil_Div
                       (SHA2.Bit_Index (M), SHA2.Bit_Index (N)));
   --  Cryptol's m /^ n, by SHA-2's instance of the prelude's Numeric.
   --  @param M Cryptol's {m}.
   --  @param N Cryptol's {n}, at least 1.
   --  @return M /^ N.

   function Ceil_Mod (M, N : C_Size) return Word_64
   with
     Export,
     Convention    => C,
     External_Name => "spark_ceil_mod",
     Pre           => N >= 1 and then M < 2 ** 62 and then N < 2 ** 62,
     Post          =>
       SHA2.Lengths.Ceil_Mod (SHA2.Bit_Index (M), SHA2.Bit_Index (N))
       in 0 .. 2 ** 64 - 1
       and then Ceil_Mod'Result
                = Word_64
                    (SHA2.Lengths.Ceil_Mod
                       (SHA2.Bit_Index (M), SHA2.Bit_Index (N)));
   --  Cryptol's m %^ n, by SHA-2's instance of the prelude's Numeric.
   --  @param M Cryptol's {m}.
   --  @param N Cryptol's {n}, at least 1.
   --  @return M %^ N.

   function Pmult_8 (X, Y : Byte) return Word_16
   with
     Export,
     Convention    => C,
     External_Name => "spark_pmult_8",
     Post          =>
       Pmult_8'Result
       = Pmult_7_7.Pmult (Word_16 (X), Word_16 (Y));
   --  Cryptol's pmult at [8] -> [8] -> [15], returned whole as a uint16_t.
   --  @param X The first factor.
   --  @param Y The second factor.
   --  @return Their product.

   function Pmult_9 (X, Y : Word_16) return Word_32
   with
     Export,
     Convention    => C,
     External_Name => "spark_pmult_9",
     Pre           => X < 2 ** 9 and then Y < 2 ** 9,
     Post          =>
       Pmult_9'Result
       = Pmult_8_8.Pmult (Word_32 (X), Word_32 (Y));
   --  Cryptol's pmult at [9] -> [9] -> [17], returned whole as a uint32_t.
   --  @param X The first factor, a [9].
   --  @param Y The second factor, a [9].
   --  @return Their product.

   function Pmod_15 (X, M : Word_16) return Word_16
   with
     Export,
     Convention    => C,
     External_Name => "spark_pmod_15",
     Pre           => X < 2 ** 15 and then M < 2 ** 9 and then M /= 0,
     Post          => Pmod_15'Result = Pmod_15_8.Pmod (X, M);
   --  Cryptol's pmod at [15] -> [9] -> [8], returned whole as a uint16_t.
   --  @param X The dividend, a [15].
   --  @param M The modulus, a nonzero [9].
   --  @return X mod M.

   function Pdiv_8 (X, Y : Byte) return Word_16
   with
     Export,
     Convention    => C,
     External_Name => "spark_pdiv_8",
     Pre           => Y /= 0,
     Post          =>
       Pdiv_8'Result
       = Pdiv_8_8.Pdiv (Word_16 (X), Word_16 (Y));
   --  Cryptol's pdiv at [8] -> [8] -> [8], returned whole as a uint16_t.
   --  @param X The dividend.
   --  @param Y The divisor, not zero.
   --  @return X divided by Y.

   function Pdiv_9 (X, Y : Word_16) return Word_16
   with
     Export,
     Convention    => C,
     External_Name => "spark_pdiv_9",
     Pre           => X < 2 ** 9 and then Y < 2 ** 9 and then Y /= 0,
     Post          => Pdiv_9'Result = Pdiv_9_9.Pdiv (X, Y);
   --  Cryptol's pdiv at [9] -> [9] -> [9], returned whole as a uint16_t.
   --  @param X The dividend, a [9].
   --  @param Y The divisor, a nonzero [9].
   --  @return X divided by Y.

end Foundation_Spark.FFI.Prelude;
