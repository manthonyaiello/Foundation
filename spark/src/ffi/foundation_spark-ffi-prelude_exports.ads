--  The exports Cryptol calls for the Cryptol prelude in SPARK:
--  spark_<Name> for each ghost shim in FFI.Prelude, the names that
--  spark/cryptol/SPARK/Prelude.cry declares foreign.
--  Each calls its shim through an Import of the shim's link name,
--  Ghost_Link_Prefix & its External_Name (see Foundation_Spark.FFI and
--  AES_GF28_Exports). Each Ghost_<Name> Import has Global => null, which
--  is what the shim's own (proved) Global is: it reads no state; and
--  Always_Terminates, since the shim is one call of an instance of the
--  prelude, whose recursion gnatprove proves terminates
--  (Subprogram_Variant).

with Interfaces;
with Interfaces.C;
with Foundation_Spark.HMAC;
with Foundation_Spark.SHA2;

package Foundation_Spark.FFI.Prelude_Exports with
  SPARK_Mode
is

   subtype C_Size is Interfaces.C.size_t;
   --  A Cryptol numeric type parameter in the C calling convention: size_t.

   subtype Byte is Interfaces.Unsigned_8;
   --  A Cryptol [8] (or a [k] with k <= 8) in C: uint8_t.

   subtype Word_16 is Interfaces.Unsigned_16;
   --  A Cryptol [k] with 8 < k <= 16 in C: uint16_t.

   subtype Word_32 is Interfaces.Unsigned_32;
   --  A Cryptol [k] with 16 < k <= 32 in C: uint32_t.

   subtype Word_64 is Interfaces.Unsigned_64;
   --  A Cryptol [k] with 32 < k <= 64 in C: uint64_t.

   type Fold_Buffer is array (0 .. 15) of Byte;
   --  The C buffer of the [n][8] folded (FFI.Prelude.Fold_Buffer).

   subtype Four_Bytes is HMAC.Bytes (0 .. 3);
   --  The C buffer of a [4][8].

   subtype Six_Bytes is HMAC.Bytes (0 .. 5);
   --  The C buffer of a [6][8].

   subtype Eight_Bytes is HMAC.Bytes (0 .. 7);
   --  The C buffer of an [8][8].

   subtype Two_Words is SHA2.Words_32 (0 .. 1);
   --  The C buffer of a [2][32].

   type Block is array (Byte range 0 .. 15) of Byte;
   --  The C buffer of a [16][8], or of a [16][4] (FFI.Prelude.Block and
   --  Nibbles).

   type Table is array (Byte) of Byte;
   --  The C buffer of a [256][8] (FFI.Prelude.Table).

   function Ghost_Foldl (N : C_Size; Z : Byte; Xs : Fold_Buffer) return Byte
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_foldl",
     Global        => null;
   --  The ghost shim FFI.Prelude.Foldl, by its link name.
   --  @param N The number of elements, Cryptol's {n}.
   --  @param Z The initial accumulator.
   --  @param Xs The elements: the first N are read.
   --  @return The fold.

   function Foldl (N : C_Size; Z : Byte; Xs : Fold_Buffer) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_foldl";
   --  Cryptol's foreign spark_foldl :
   --  {n} (fin n, n <= 16) => [8] -> [n][8] -> [8].
   --  Calls Ghost_Foldl.
   --  @param N The number of elements, Cryptol's {n}.
   --  @param Z The initial accumulator.
   --  @param Xs The elements: the first N are read.
   --  @return The fold.

   function Ghost_Foldl_Enumeration
     (From, To : C_Size; E, Z : Byte) return Byte
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_foldl_enumeration",
     Global        => null;
   --  The ghost shim FFI.Prelude.Foldl_Enumeration, by its link name.
   --  @param From The enumeration's first element, Cryptol's {from}.
   --  @param To Its exclusive bound, Cryptol's {to}.
   --  @param E The value the function closes over.
   --  @param Z The initial accumulator.
   --  @return The fold.

   function Foldl_Enumeration (From, To : C_Size; E, Z : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_foldl_enumeration";
   --  Cryptol's foreign spark_foldl_enumeration :
   --  {from, to} (fin from, fin to, to <= 256) => [8] -> [8] -> [8].
   --  Calls Ghost_Foldl_Enumeration.
   --  @param From The enumeration's first element, Cryptol's {from}.
   --  @param To Its exclusive bound, Cryptol's {to}.
   --  @param E The value the function closes over.
   --  @param Z The initial accumulator.
   --  @return The fold.

   function Ghost_Bit_8 (X, J : Byte) return Byte
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_bit_8",
     Global        => null;
   --  The ghost shim FFI.Prelude.Bit_8, by its link name.
   --  @param X The byte.
   --  @param J The bit's index.
   --  @return The bit, as 1 or 0.

   function Bit_8 (X, J : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_bit_8";
   --  Cryptol's foreign spark_bit_8 : [8] -> [3] -> [8].
   --  Calls Ghost_Bit_8.
   --  @param X The byte.
   --  @param J The bit's index.
   --  @return The bit, as 1 or 0.

   function Ghost_Head_8 (X : Byte) return Byte
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_head_8",
     Global        => null;
   --  The ghost shim FFI.Prelude.Head_8, by its link name.
   --  @param X The byte.
   --  @return Its most significant bit, as 1 or 0.

   function Head_8 (X : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_head_8";
   --  Cryptol's foreign spark_head_8 : [8] -> [8].
   --  Calls Ghost_Head_8.
   --  @param X The byte.
   --  @return Its most significant bit, as 1 or 0.

   function Ghost_Bit_32 (X : Word_32; J : Byte) return Byte
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_bit_32",
     Global        => null;
   --  The ghost shim FFI.Prelude.Bit_32, by its link name.
   --  @param X The word.
   --  @param J The bit's index.
   --  @return The bit, as 1 or 0.

   function Bit_32 (X : Word_32; J : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_bit_32";
   --  Cryptol's foreign spark_bit_32 : [32] -> [5] -> [8].
   --  Calls Ghost_Bit_32.
   --  @param X The word.
   --  @param J The bit's index.
   --  @return The bit, as 1 or 0.

   function Ghost_Bit_15 (X : Word_16; J : Byte) return Byte
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_bit_15",
     Global        => null;
   --  The ghost shim FFI.Prelude.Bit_15, by its link name.
   --  @param X The word.
   --  @param J The bit's index.
   --  @return The bit, as 1 or 0.

   function Bit_15 (X : Word_16; J : Byte) return Byte
   with
     Export,
     Convention    => C,
     External_Name => "spark_bit_15";
   --  Cryptol's foreign spark_bit_15 : [15] -> [4] -> [8].
   --  Calls Ghost_Bit_15.
   --  @param X The word.
   --  @param J The bit's index.
   --  @return The bit, as 1 or 0.

   function Ghost_Join_Bytes (Xs : Four_Bytes) return Word_32
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_join_bytes",
     Global        => null;
   --  The ghost shim FFI.Prelude.Join_Bytes, by its link name.
   --  @param Xs The four bytes.
   --  @return Their 32 bits as a word.

   function Join_Bytes (Xs : Four_Bytes) return Word_32
   with
     Export,
     Convention    => C,
     External_Name => "spark_join_bytes";
   --  Cryptol's foreign spark_join_bytes : [4][8] -> [32].
   --  Calls Ghost_Join_Bytes.
   --  @param Xs The four bytes.
   --  @return Their 32 bits as a word.

   procedure Ghost_Split_Word (X : Word_64; Output : out Two_Words)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_split_word",
     Global        => null,
     Always_Terminates;
   --  The ghost shim FFI.Prelude.Split_Word, by its link name.
   --  @param X The word.
   --  @param Output Its two halves.

   procedure Split_Word (X : Word_64; Output : out Two_Words)
   with
     Export,
     Convention    => C,
     External_Name => "spark_split_word";
   --  Cryptol's foreign spark_split_word : [64] -> [2][32].
   --  Calls Ghost_Split_Word.
   --  @param X The word.
   --  @param Output Its two halves.

   procedure Ghost_Join_Words (Ws : Two_Words; Output : out Eight_Bytes)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_join_words",
     Global        => null,
     Always_Terminates;
   --  The ghost shim FFI.Prelude.Join_Words, by its link name.
   --  @param Ws The two words.
   --  @param Output Their bits as eight bytes.

   procedure Join_Words (Ws : Two_Words; Output : out Eight_Bytes)
   with
     Export,
     Convention    => C,
     External_Name => "spark_join_words";
   --  Cryptol's foreign spark_join_words : [2][32] -> [8][8].
   --  Calls Ghost_Join_Words.
   --  @param Ws The two words.
   --  @param Output Their bits as eight bytes.

   function Ghost_Zero_64 return Word_64
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_zero_64",
     Global        => null;
   --  The ghost shim FFI.Prelude.Zero_64, by its link name.
   --  @return The 64 zero bits as a word.

   function Zero_64 return Word_64
   with
     Export,
     Convention    => C,
     External_Name => "spark_zero_64";
   --  Cryptol's foreign spark_zero_64 : () -> [64].
   --  Calls Ghost_Zero_64.
   --  @return The 64 zero bits as a word.

   function Ghost_Literal_64 (X : Word_64) return Word_64
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_literal_64",
     Global        => null;
   --  The ghost shim FFI.Prelude.Literal_64, by its link name.
   --  @param X The value.
   --  @return The literal's bits as a word.

   function Literal_64 (X : Word_64) return Word_64
   with
     Export,
     Convention    => C,
     External_Name => "spark_literal_64";
   --  Cryptol's foreign spark_literal_64 : [64] -> [64].
   --  Calls Ghost_Literal_64.
   --  @param X The value.
   --  @return The literal's bits as a word.

   procedure Ghost_Repeat_4 (X : Byte; Output : out Four_Bytes)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_repeat_4",
     Global        => null,
     Always_Terminates;
   --  The ghost shim FFI.Prelude.Repeat_4, by its link name.
   --  @param X The byte.
   --  @param Output Four copies of X.

   procedure Repeat_4 (X : Byte; Output : out Four_Bytes)
   with
     Export,
     Convention    => C,
     External_Name => "spark_repeat_4";
   --  Cryptol's foreign spark_repeat_4 : [8] -> [4][8].
   --  Calls Ghost_Repeat_4.
   --  @param X The byte.
   --  @param Output Four copies of X.

   procedure Ghost_Reverse_6 (Xs : Six_Bytes; Output : out Six_Bytes)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_reverse_6",
     Global        => null,
     Always_Terminates;
   --  The ghost shim FFI.Prelude.Reverse_6, by its link name.
   --  @param Xs The bytes.
   --  @param Output Xs in reverse order.

   procedure Reverse_6 (Xs : Six_Bytes; Output : out Six_Bytes)
   with
     Export,
     Convention    => C,
     External_Name => "spark_reverse_6";
   --  Cryptol's foreign spark_reverse_6 : [6][8] -> [6][8].
   --  Calls Ghost_Reverse_6.
   --  @param Xs The bytes.
   --  @param Output Xs in reverse order.

   procedure Ghost_Bulk_Index_Block
     (Xs : Block; Ixs : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_bulk_index_block",
     Global        => null,
     Always_Terminates;
   --  The ghost shim FFI.Prelude.Bulk_Index_Block, by its link name.
   --  @param Xs The block.
   --  @param Ixs The indices, each below 16.
   --  @param Output The bytes of Xs at Ixs.

   procedure Bulk_Index_Block (Xs : Block; Ixs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_bulk_index_block";
   --  Cryptol's foreign spark_bulk_index_block :
   --  [16][8] -> [16][4] -> [16][8].
   --  Calls Ghost_Bulk_Index_Block.
   --  @param Xs The block.
   --  @param Ixs The indices, each below 16.
   --  @param Output The bytes of Xs at Ixs.

   procedure Ghost_Bulk_Index_Table
     (T : Table; Bs : Block; Output : out Block)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_bulk_index_table",
     Global        => null,
     Always_Terminates;
   --  The ghost shim FFI.Prelude.Bulk_Index_Table, by its link name.
   --  @param T The table.
   --  @param Bs The indices.
   --  @param Output The entries of T at Bs.

   procedure Bulk_Index_Table (T : Table; Bs : Block; Output : out Block)
   with
     Export,
     Convention    => C,
     External_Name => "spark_bulk_index_table";
   --  Cryptol's foreign spark_bulk_index_table :
   --  [256][8] -> [16][8] -> [16][8].
   --  Calls Ghost_Bulk_Index_Table.
   --  @param T The table.
   --  @param Bs The indices.
   --  @param Output The entries of T at Bs.

   function Ghost_Ceil_Div (M, N : C_Size) return Word_64
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_ceil_div",
     Global        => null;
   --  The ghost shim FFI.Prelude.Ceil_Div, by its link name.
   --  @param M Cryptol's {m}.
   --  @param N Cryptol's {n}.
   --  @return M /^ N.

   function Ceil_Div (M, N : C_Size) return Word_64
   with
     Export,
     Convention    => C,
     External_Name => "spark_ceil_div";
   --  Cryptol's foreign spark_ceil_div :
   --  {m, n} (fin m, fin n, n >= 1) => () -> [64].
   --  Calls Ghost_Ceil_Div.
   --  @param M Cryptol's {m}.
   --  @param N Cryptol's {n}.
   --  @return M /^ N.

   function Ghost_Ceil_Mod (M, N : C_Size) return Word_64
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_ceil_mod",
     Global        => null;
   --  The ghost shim FFI.Prelude.Ceil_Mod, by its link name.
   --  @param M Cryptol's {m}.
   --  @param N Cryptol's {n}.
   --  @return M %^ N.

   function Ceil_Mod (M, N : C_Size) return Word_64
   with
     Export,
     Convention    => C,
     External_Name => "spark_ceil_mod";
   --  Cryptol's foreign spark_ceil_mod :
   --  {m, n} (fin m, fin n, n >= 1) => () -> [64].
   --  Calls Ghost_Ceil_Mod.
   --  @param M Cryptol's {m}.
   --  @param N Cryptol's {n}.
   --  @return M %^ N.

   function Ghost_Pmult_8 (X, Y : Byte) return Word_16
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_pmult_8",
     Global        => null;
   --  The ghost shim FFI.Prelude.Pmult_8, by its link name.
   --  @param X The first factor.
   --  @param Y The second factor.
   --  @return Their product.

   function Pmult_8 (X, Y : Byte) return Word_16
   with
     Export,
     Convention    => C,
     External_Name => "spark_pmult_8";
   --  Cryptol's foreign spark_pmult_8 : [8] -> [8] -> [16], the [15]
   --  product returned whole.
   --  Calls Ghost_Pmult_8.
   --  @param X The first factor.
   --  @param Y The second factor.
   --  @return Their product.

   function Ghost_Pmult_9 (X, Y : Word_16) return Word_32
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_pmult_9",
     Global        => null;
   --  The ghost shim FFI.Prelude.Pmult_9, by its link name.
   --  @param X The first factor.
   --  @param Y The second factor.
   --  @return Their product.

   function Pmult_9 (X, Y : Word_16) return Word_32
   with
     Export,
     Convention    => C,
     External_Name => "spark_pmult_9";
   --  Cryptol's foreign spark_pmult_9 : [9] -> [9] -> [32], the [17]
   --  product returned whole.
   --  Calls Ghost_Pmult_9.
   --  @param X The first factor.
   --  @param Y The second factor.
   --  @return Their product.

   function Ghost_Pmod_15 (X, M : Word_16) return Word_16
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_pmod_15",
     Global        => null;
   --  The ghost shim FFI.Prelude.Pmod_15, by its link name.
   --  @param X The dividend.
   --  @param M The modulus.
   --  @return X mod M.

   function Pmod_15 (X, M : Word_16) return Word_16
   with
     Export,
     Convention    => C,
     External_Name => "spark_pmod_15";
   --  Cryptol's foreign spark_pmod_15 : [15] -> [9] -> [16], the [8]
   --  remainder returned whole.
   --  Calls Ghost_Pmod_15.
   --  @param X The dividend.
   --  @param M The modulus.
   --  @return X mod M.

   function Ghost_Pdiv_8 (X, Y : Byte) return Word_16
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_pdiv_8",
     Global        => null;
   --  The ghost shim FFI.Prelude.Pdiv_8, by its link name.
   --  @param X The dividend.
   --  @param Y The divisor.
   --  @return X divided by Y.

   function Pdiv_8 (X, Y : Byte) return Word_16
   with
     Export,
     Convention    => C,
     External_Name => "spark_pdiv_8";
   --  Cryptol's foreign spark_pdiv_8 : [8] -> [8] -> [16], the [8]
   --  quotient returned whole.
   --  Calls Ghost_Pdiv_8.
   --  @param X The dividend.
   --  @param Y The divisor.
   --  @return X divided by Y.

   function Ghost_Pdiv_9 (X, Y : Word_16) return Word_16
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_pdiv_9",
     Global        => null;
   --  The ghost shim FFI.Prelude.Pdiv_9, by its link name.
   --  @param X The dividend.
   --  @param Y The divisor.
   --  @return X divided by Y.

   function Pdiv_9 (X, Y : Word_16) return Word_16
   with
     Export,
     Convention    => C,
     External_Name => "spark_pdiv_9";
   --  Cryptol's foreign spark_pdiv_9 : [9] -> [9] -> [16], the [9]
   --  quotient returned whole.
   --  Calls Ghost_Pdiv_9.
   --  @param X The dividend.
   --  @param Y The divisor.
   --  @return X divided by Y.

end Foundation_Spark.FFI.Prelude_Exports;
